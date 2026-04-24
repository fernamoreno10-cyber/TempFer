import Cocoa
import ServiceManagement

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Preferencias de TempFer"
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = false
        win.center()
        self.init(window: win)
        win.delegate = self
        win.contentViewController = SettingsViewController()
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Settings View Controller

final class SettingsViewController: NSViewController {

    // General
    private let intervalPopup = NSPopUpButton()
    private let unitSegment   = NSSegmentedControl()
    private let colorSwitch   = makeSwitch()
    private let loginSwitch   = makeSwitch()

    // AI
    private let aiSwitch    = makeSwitch()
    private let notifSwitch = makeSwitch()
    private let apiKeyField = NSSecureTextField()
    private let showKeyBtn  = NSButton(checkboxWithTitle: "Mostrar", target: nil, action: nil)
    private let freqPopup   = NSPopUpButton()
    private let testBtn     = NSButton(title: "Generar consejo ahora", target: nil, action: nil)
    private let testStatus  = NSTextField(labelWithString: "")

    private var plainApiField: NSTextField?

    // MARK: - Load

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 390))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadValues()
    }

    // MARK: - Build UI

    private func buildUI() {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        view.addSubview(scroll)

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.alignment = .leading
        root.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false

        scroll.documentView = root

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            root.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        // ── GENERAL ─────────────────────────────
        root.addArrangedSubview(sectionHeader("GENERAL"))

        let generalBox = makeBox()
        let generalStack = innerStack()
        generalBox.addSubview(generalStack)
        pinToBox(generalStack, in: generalBox)

        // Refresh interval
        intervalPopup.addItems(withTitles: ["2 segundos", "5 segundos", "10 segundos", "30 segundos"])
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)
        generalStack.addArrangedSubview(makeRow("Actualizar cada", control: intervalPopup))

        generalStack.addArrangedSubview(makeSeparator())

        // Temp units
        unitSegment.segmentCount = 2
        unitSegment.setLabel("°C  Celsius", forSegment: 0)
        unitSegment.setLabel("°F  Fahrenheit", forSegment: 1)
        unitSegment.target = self
        unitSegment.action = #selector(unitChanged)
        generalStack.addArrangedSubview(makeRow("Unidades", control: unitSegment))

        generalStack.addArrangedSubview(makeSeparator())

        // Color por temp
        colorSwitch.target = self
        colorSwitch.action = #selector(colorChanged)
        generalStack.addArrangedSubview(makeRow("Color por temperatura", control: colorSwitch))

        generalStack.addArrangedSubview(makeSeparator())

        // Login item
        loginSwitch.target = self
        loginSwitch.action = #selector(loginChanged)
        generalStack.addArrangedSubview(makeRow("Iniciar con el Mac", control: loginSwitch))

        root.addArrangedSubview(generalBox)
        generalBox.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -48).isActive = true

        root.setCustomSpacing(6, after: sectionLabel(root))

        // ── ASISTENTE IA ─────────────────────────
        root.addArrangedSubview(sectionHeader("ASISTENTE IA"))

        let aiBox = makeBox()
        let aiStack = innerStack()
        aiBox.addSubview(aiStack)
        pinToBox(aiStack, in: aiBox)

        // Enable AI
        aiSwitch.target = self
        aiSwitch.action = #selector(aiEnabledChanged)
        aiStack.addArrangedSubview(makeRow("Activar consejos inteligentes", control: aiSwitch))

        aiStack.addArrangedSubview(makeSeparator())

        // Notifications
        notifSwitch.target = self
        notifSwitch.action = #selector(notifChanged)
        aiStack.addArrangedSubview(makeRow("Notificaciones del sistema", control: notifSwitch))

        aiStack.addArrangedSubview(makeSeparator())

        // API Key
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.placeholderString = "sk-ant-api03-..."
        apiKeyField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        apiKeyField.bezelStyle = .roundedBezel
        apiKeyField.focusRingType = .default

        showKeyBtn.translatesAutoresizingMaskIntoConstraints = false
        showKeyBtn.target = self
        showKeyBtn.action = #selector(toggleShowKey)
        showKeyBtn.font = .systemFont(ofSize: 11)

        let keyRow = makeApiKeyRow()
        aiStack.addArrangedSubview(keyRow)
        keyRow.widthAnchor.constraint(equalTo: aiStack.widthAnchor).isActive = true

        aiStack.addArrangedSubview(makeSeparator())

        // Frequency
        freqPopup.addItems(withTitles: ["Cada 15 minutos", "Cada 30 minutos", "Cada hora",
                                        "Cada 2 horas", "Cada 4 horas", "Desactivado"])
        freqPopup.target = self
        freqPopup.action = #selector(freqChanged)
        aiStack.addArrangedSubview(makeRow("Frecuencia de consejos", control: freqPopup))

        aiStack.addArrangedSubview(makeSeparator())

        // Test button
        testBtn.bezelStyle = .rounded
        testBtn.controlSize = .regular
        testBtn.target = self
        testBtn.action = #selector(testAI)
        testStatus.font = .systemFont(ofSize: 11)
        testStatus.textColor = .secondaryLabelColor

        let testRow = NSStackView(views: [testBtn, testStatus])
        testRow.spacing = 10
        testRow.translatesAutoresizingMaskIntoConstraints = false
        aiStack.addArrangedSubview(testRow)

        root.addArrangedSubview(aiBox)
        aiBox.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -48).isActive = true
    }

    // MARK: - Row builders

    private func makeApiKeyRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let lbl = NSTextField(labelWithString: "API Key de Anthropic")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        container.addSubview(lbl)

        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(apiKeyField)
        container.addSubview(showKeyBtn)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            lbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),

            apiKeyField.topAnchor.constraint(equalTo: lbl.bottomAnchor, constant: 4),
            apiKeyField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: showKeyBtn.leadingAnchor, constant: -8),
            apiKeyField.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

            showKeyBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            showKeyBtn.centerYAnchor.constraint(equalTo: apiKeyField.centerYAnchor),
        ])
        return container
    }

    private func makeRow(_ label: String, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let lbl = NSTextField(labelWithString: label)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        row.addSubview(lbl)

        control.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(control)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    // MARK: - Section helpers

    private var lastSectionLabel: NSView?

    private func sectionHeader(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        lastSectionLabel = label
        return label
    }

    private func sectionLabel(_ stack: NSStackView) -> NSView {
        return lastSectionLabel ?? stack
    }

    private func makeBox() -> NSBox {
        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.boxType = .custom
        box.borderColor = NSColor.separatorColor
        box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.4)
        box.cornerRadius = 10
        box.borderWidth = 0.5
        box.contentViewMargins = .zero
        return box
    }

    private func innerStack() -> NSStackView {
        let s = NSStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.orientation = .vertical
        s.spacing = 0
        s.alignment = .leading
        s.edgeInsets = NSEdgeInsets(top: 2, left: 14, bottom: 2, right: 14)
        return s
    }

    private func pinToBox(_ stack: NSStackView, in box: NSBox) {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: box.topAnchor),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
    }

    private func makeSeparator() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Load / Save values

    private func loadValues() {
        let ud = UserDefaults.standard

        let interval = ud.object(forKey: "refreshInterval") as? Double ?? 5
        switch interval {
        case 2:  intervalPopup.selectItem(at: 0)
        case 10: intervalPopup.selectItem(at: 2)
        case 30: intervalPopup.selectItem(at: 3)
        default: intervalPopup.selectItem(at: 1)
        }

        let units = ud.string(forKey: "tempUnits") ?? "C"
        unitSegment.selectedSegment = units == "F" ? 1 : 0

        colorSwitch.state = (ud.object(forKey: "colorEnabled") as? Bool ?? true) ? .on : .off
        loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off

        aiSwitch.state    = AIAdvisor.shared.aiEnabled ? .on : .off
        notifSwitch.state = AIAdvisor.shared.notificationsEnabled ? .on : .off
        apiKeyField.stringValue = AIAdvisor.shared.apiKey

        switch AIAdvisor.shared.frequencyMinutes {
        case 15:  freqPopup.selectItem(at: 0)
        case 30:  freqPopup.selectItem(at: 1)
        case 120: freqPopup.selectItem(at: 3)
        case 240: freqPopup.selectItem(at: 4)
        case 0:   freqPopup.selectItem(at: 5)
        default:  freqPopup.selectItem(at: 2)   // 60 min
        }
    }

    // MARK: - Actions

    @objc private func intervalChanged() {
        let vals = [2.0, 5.0, 10.0, 30.0]
        let v = vals[intervalPopup.indexOfSelectedItem]
        UserDefaults.standard.set(v, forKey: "refreshInterval")
        NotificationCenter.default.post(name: .tempferSettingsChanged, object: nil)
    }

    @objc private func unitChanged() {
        let u = unitSegment.selectedSegment == 0 ? "C" : "F"
        UserDefaults.standard.set(u, forKey: "tempUnits")
        NotificationCenter.default.post(name: .tempferSettingsChanged, object: nil)
    }

    @objc private func colorChanged() {
        UserDefaults.standard.set(colorSwitch.state == .on, forKey: "colorEnabled")
        NotificationCenter.default.post(name: .tempferSettingsChanged, object: nil)
    }

    @objc private func loginChanged() {
        let svc = SMAppService.mainApp
        do {
            if loginSwitch.state == .on { try svc.register() } else { try svc.unregister() }
        } catch {
            loginSwitch.state = svc.status == .enabled ? .on : .off
        }
    }

    @objc private func aiEnabledChanged() {
        AIAdvisor.shared.aiEnabled = aiSwitch.state == .on
    }

    @objc private func toggleShowKey(_ sender: NSButton) {
        let key = apiKeyField.stringValue
        if sender.state == .on {
            let plain = NSTextField(string: key)
            plain.translatesAutoresizingMaskIntoConstraints = false
            plain.font = apiKeyField.font
            plain.bezelStyle = .roundedBezel
            plain.placeholderString = apiKeyField.placeholderString
            plain.action = #selector(plainKeyChanged)
            plain.target = self
            apiKeyField.superview?.addSubview(plain)
            NSLayoutConstraint.activate([
                plain.topAnchor.constraint(equalTo: apiKeyField.topAnchor),
                plain.leadingAnchor.constraint(equalTo: apiKeyField.leadingAnchor),
                plain.trailingAnchor.constraint(equalTo: apiKeyField.trailingAnchor),
                plain.bottomAnchor.constraint(equalTo: apiKeyField.bottomAnchor),
            ])
            apiKeyField.isHidden = true
            plainApiField = plain
        } else {
            if let p = plainApiField {
                apiKeyField.stringValue = p.stringValue
                p.removeFromSuperview()
                plainApiField = nil
            }
            apiKeyField.isHidden = false
            saveApiKey(apiKeyField.stringValue)
        }
    }

    @objc private func plainKeyChanged(_ sender: NSTextField) {
        saveApiKey(sender.stringValue)
    }

    private func saveApiKey(_ key: String) {
        AIAdvisor.shared.apiKey = key
    }

    @objc private func notifChanged() {
        AIAdvisor.shared.notificationsEnabled = notifSwitch.state == .on
        if notifSwitch.state == .on {
            AIAdvisor.shared.requestNotificationPermission()
        }
    }

    @objc private func freqChanged() {
        let vals = [15, 30, 60, 120, 240, 0]
        AIAdvisor.shared.frequencyMinutes = vals[freqPopup.indexOfSelectedItem]
    }

    @objc private func testAI() {
        guard !AIAdvisor.shared.apiKey.isEmpty else {
            testStatus.stringValue = "Ingresa tu API key primero."
            testStatus.textColor = .systemOrange
            return
        }
        testBtn.isEnabled = false
        testStatus.stringValue = "Generando…"
        testStatus.textColor = .secondaryLabelColor
        NotificationCenter.default.post(name: .tempferTestAI, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.testBtn.isEnabled = true
        }
    }

    func tipGenerated() {
        testBtn.isEnabled = true
        testStatus.stringValue = "Consejo enviado al popover."
        testStatus.textColor = .systemGreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.testStatus.stringValue = ""
        }
    }
}

// MARK: - Helpers

private func makeSwitch() -> NSSwitch {
    let s = NSSwitch()
    s.controlSize = .small
    return s
}

extension Notification.Name {
    static let tempferSettingsChanged = Notification.Name("tempferSettingsChanged")
    static let tempferTestAI          = Notification.Name("tempferTestAI")
}
