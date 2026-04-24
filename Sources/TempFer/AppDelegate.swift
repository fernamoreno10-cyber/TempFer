import Cocoa
import ServiceManagement

// MARK: - Hover detector

final class HoverView: NSView {
    var onHover: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil
        ))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true)  }
    override func mouseExited(with event: NSEvent)  { onHover?(false) }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover:    NSPopover!
    private var popoverVC:  PopoverViewController!
    private var settingsWC: SettingsWindowController?

    private var reader: TempReader?
    private var updateTimer: Timer?
    private var hoverTimer:  Timer?

    private let launchDate = Date()
    private var lastContextForAI: AIAdvisor.Context?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ note: Notification) {
        guard let r = TempReader.make() else {
            showAlert("TempFer", "No se pudo acceder a los sensores térmicos.")
            NSApp.terminate(nil)
            return
        }
        reader = r

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupPopover()
        setupButton()
        setupNotifications()

        update()
        scheduleUpdateTimer()
    }

    // MARK: - Popover

    private func setupPopover() {
        popoverVC = PopoverViewController()
        popoverVC.onSettingsTap = { [weak self] in self?.openSettings() }

        popover           = NSPopover()
        popover.contentViewController = popoverVC
        popover.behavior  = .semitransient
        popover.animates  = false
    }

    // MARK: - Status bar button

    private func setupButton() {
        guard let btn = statusItem.button else { return }
        btn.target = self
        btn.action = #selector(buttonClicked(_:))
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let hover = HoverView(frame: btn.bounds)
        hover.autoresizingMask = [.width, .height]
        btn.addSubview(hover)
        hover.onHover = { [weak self] entering in
            guard let self else { return }
            if entering {
                guard !self.popover.isShown else { return }
                self.hoverTimer?.invalidate()
                self.hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: false) { [weak self] _ in
                    self?.showPopover()
                }
            } else {
                self.hoverTimer?.invalidate()
            }
        }
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        hoverTimer?.invalidate()
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.popUpMenu(buildContextMenu())
        } else {
            popover.isShown ? popover.close() : showPopover()
        }
    }

    private func showPopover() {
        guard let btn = statusItem.button else { return }
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
    }

    // MARK: - Context menu (right-click)

    private func buildContextMenu() -> NSMenu {
        let m = NSMenu()

        let prefsItem = NSMenuItem(title: "Preferencias…", action: #selector(openSettingsAction), keyEquivalent: ",")
        prefsItem.target = self
        m.addItem(prefsItem)

        m.addItem(.separator())

        let colorItem = NSMenuItem(
            title: colorEnabled ? "✓ Color por temperatura" : "  Color por temperatura",
            action: #selector(toggleColor), keyEquivalent: "c"
        )
        colorItem.target = self
        m.addItem(colorItem)

        let loginItem = NSMenuItem(
            title: SMAppService.mainApp.status == .enabled ? "✓ Iniciar con el Mac" : "  Iniciar con el Mac",
            action: #selector(toggleLogin), keyEquivalent: ""
        )
        loginItem.target = self
        m.addItem(loginItem)

        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return m
    }

    // MARK: - Settings

    @objc private func openSettingsAction() { openSettings() }

    private func openSettings() {
        popover.close()
        if settingsWC == nil { settingsWC = SettingsWindowController() }
        settingsWC?.show()
    }

    // MARK: - Update loop

    private func scheduleUpdateTimer() {
        updateTimer?.invalidate()
        let interval = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 5
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        guard let reader else { return }
        let s     = reader.summary()
        let procs = ProcessMonitor.topByCPU(limit: 5)

        updateStatusBar(cpu: s.cpu)
        popoverVC.refresh(cpu: s.cpu, battery: s.battery, ssd: s.ssd, processes: procs)

        let ctx = AIAdvisor.Context(
            cpuTemp:      s.cpu,
            batteryTemp:  s.battery,
            ssdTemp:      s.ssd,
            topProcesses: procs,
            sessionMinutes: Int(Date().timeIntervalSince(launchDate) / 60)
        )
        lastContextForAI = ctx

        // Update tip "next in X min" if a tip is already showing
        if case .tip(let text, _) = popoverVC.tipView.state {
            let next = nextTipString()
            popoverVC.tipView.setState(.tip(text, next: next))
        }

        AIAdvisor.shared.checkScheduled(context: ctx)
    }

    private func updateStatusBar(cpu: Double) {
        let tempStr = cpu > 0 ? " \(formatTemp(cpu))" : " —"
        if colorEnabled && cpu > 0 {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: tempColor(cpu),
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]
            statusItem.button?.attributedTitle = NSAttributedString(string: tempStr, attributes: attrs)
        } else {
            statusItem.button?.attributedTitle = NSAttributedString(string: "")
            statusItem.button?.title = tempStr
        }
        statusItem.button?.image         = thermometerIcon(celsius: cpu)
        statusItem.button?.imagePosition = .imageLeft
    }

    // MARK: - AI wiring

    private func setupNotifications() {
        AIAdvisor.shared.onLoadingStart = { [weak self] in
            self?.popoverVC.tipView.setState(.loading)
        }
        AIAdvisor.shared.onTip = { [weak self] text in
            guard let self else { return }
            self.popoverVC.tipView.setState(.tip(text, next: self.nextTipString()))
            (self.settingsWC?.contentViewController as? SettingsViewController)?.tipGenerated()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: .tempferSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(testAIRequested),
                                               name: .tempferTestAI, object: nil)

        // Request notification permission
        AIAdvisor.shared.requestNotificationPermission()

        // Set initial tip state
        if AIAdvisor.shared.apiKey.isEmpty {
            popoverVC.tipView.setState(.noKey)
        }
    }

    @objc private func settingsChanged() {
        scheduleUpdateTimer()
        update()
    }

    @objc private func testAIRequested() {
        guard let ctx = lastContextForAI else { return }
        AIAdvisor.shared.generateNow(context: ctx)
    }

    private func nextTipString() -> String {
        guard AIAdvisor.shared.scheduledTipsActive else { return "manual" }
        let mins = AIAdvisor.shared.minutesUntilNextTip
        if mins <= 0 { return "pronto" }
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)min" : "\(h)h"
    }

    // MARK: - Menu actions

    private var colorEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "colorEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "colorEnabled") }
    }

    @objc private func toggleColor() {
        colorEnabled = !colorEnabled
        update()
    }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch {
            showAlert("TempFer", "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func thermometerIcon(celsius: Double) -> NSImage? {
        let name: String
        switch celsius {
        case ..<50:  name = "thermometer.low"
        case ..<75:  name = "thermometer.medium"
        default:     name = "thermometer.high"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    private func showAlert(_ title: String, _ msg: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = msg; a.runModal()
    }
}
