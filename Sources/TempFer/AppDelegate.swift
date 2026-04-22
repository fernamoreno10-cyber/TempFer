import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var reader: TempReader?
    private var timer: Timer?

    private var cpuItem:       NSMenuItem!
    private var batteryItem:   NSMenuItem!
    private var ssdItem:       NSMenuItem!
    private var allTempsItem:  NSMenuItem!
    private var topProcsItem:  NSMenuItem!
    private var loginItem:     NSMenuItem!
    private var colorItem:     NSMenuItem!

    private var colorEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "colorEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "colorEnabled") }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        guard let r = TempReader.make() else {
            NSAlert.show("TempFer", "No se pudo acceder a los sensores.")
            NSApp.terminate(nil)
            return
        }
        reader = r
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        cpuItem     = NSMenuItem(title: "CPU: —", action: nil, keyEquivalent: "")
        batteryItem = NSMenuItem(title: "Batería: —", action: nil, keyEquivalent: "")
        ssdItem     = NSMenuItem(title: "SSD: —", action: nil, keyEquivalent: "")
        cpuItem.isEnabled     = false
        batteryItem.isEnabled = false
        ssdItem.isEnabled     = false

        menu.addItem(cpuItem)
        menu.addItem(batteryItem)
        menu.addItem(ssdItem)
        menu.addItem(.separator())

        topProcsItem = NSMenuItem(title: "Top procesos", action: nil, keyEquivalent: "")
        topProcsItem.submenu = NSMenu()
        menu.addItem(topProcsItem)

        allTempsItem = NSMenuItem(title: "Todos los sensores", action: nil, keyEquivalent: "")
        allTempsItem.submenu = NSMenu()
        menu.addItem(allTempsItem)
        menu.addItem(.separator())

        colorItem = NSMenuItem(
            title: colorItemTitle(),
            action: #selector(toggleColor),
            keyEquivalent: "c"
        )
        colorItem.target = self
        menu.addItem(colorItem)

        loginItem = NSMenuItem(
            title: loginItemTitle(),
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Update

    private func update() {
        guard let reader else { return }
        let s = reader.summary()

        if s.cpu > 0 {
            let tempStr = " \(String(format: "%.0f°", s.cpu))"
            if colorEnabled {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: tempColor(s.cpu),
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                ]
                statusItem.button?.attributedTitle = NSAttributedString(string: tempStr, attributes: attrs)
            } else {
                statusItem.button?.attributedTitle = NSAttributedString(string: "")
                statusItem.button?.title = tempStr
            }
        } else {
            statusItem.button?.title = " —"
        }
        statusItem.button?.image = thermometerIcon(celsius: s.cpu)
        statusItem.button?.imagePosition = .imageLeft

        cpuItem.title     = "CPU:     \(format(s.cpu))   \(tempLabel(s.cpu))"
        batteryItem.title = "Batería: \(s.battery.map { format($0) } ?? "—")"
        ssdItem.title     = "SSD:     \(s.ssd.map { format($0) } ?? "—")"

        // Top processes by CPU
        let procMenu = NSMenu()
        let procs = ProcessMonitor.topByCPU(limit: 6)
        if procs.isEmpty {
            let ni = NSMenuItem(title: "Sin datos", action: nil, keyEquivalent: "")
            ni.isEnabled = false
            procMenu.addItem(ni)
        } else {
            for p in procs {
                let cpuStr = String(format: "%5.1f%%", p.cpu)
                let memStr = p.mem >= 1024
                    ? String(format: "%.1f GB", p.mem / 1024)
                    : String(format: "%.0f MB", p.mem)
                let item = NSMenuItem(
                    title: "\(cpuStr) CPU  \(memStr) RAM   \(p.name)",
                    action: nil, keyEquivalent: ""
                )
                item.isEnabled = false
                // Color red if >30% CPU
                if p.cpu > 30 {
                    item.attributedTitle = NSAttributedString(
                        string: item.title,
                        attributes: [.foregroundColor: NSColor.systemRed]
                    )
                } else if p.cpu > 10 {
                    item.attributedTitle = NSAttributedString(
                        string: item.title,
                        attributes: [.foregroundColor: NSColor.systemOrange]
                    )
                }
                procMenu.addItem(item)
            }
        }
        topProcsItem.submenu = procMenu

        // All sensors
        let allMenu = NSMenu()
        for r in reader.readAll().sorted(by: { $0.celsius > $1.celsius }) {
            let item = NSMenuItem(title: "\(r.name):  \(format(r.celsius))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            allMenu.addItem(item)
        }
        allTempsItem.submenu = allMenu
    }

    // MARK: - Temperature helpers

    private func tempColor(_ c: Double) -> NSColor {
        switch c {
        case ..<50:  return NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1) // green
        case ..<70:  return NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1) // yellow
        case ..<85:  return NSColor(red: 1.00, green: 0.50, blue: 0.00, alpha: 1) // orange
        default:     return NSColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1) // red
        }
    }

    private func tempLabel(_ c: Double) -> String {
        switch c {
        case ..<50:  return "✦ Óptima"
        case ..<70:  return "◆ Normal"
        case ..<85:  return "▲ Alta"
        default:     return "⚠ Crítica"
        }
    }

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

    private func format(_ c: Double) -> String { String(format: "%.1f°C", c) }

    // MARK: - Color toggle

    @objc private func toggleColor() {
        colorEnabled = !colorEnabled
        colorItem.title = colorItemTitle()
        update()
    }

    private func colorItemTitle() -> String {
        colorEnabled ? "✓ Color por temperatura" : "  Color por temperatura"
    }

    // MARK: - Login item

    @objc private func toggleLoginItem() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            NSAlert.show("TempFer", "Error al cambiar inicio automático: \(error.localizedDescription)")
        }
        loginItem.title = loginItemTitle()
    }

    private func loginItemTitle() -> String {
        SMAppService.mainApp.status == .enabled
            ? "✓ Iniciar con el Mac"
            : "  Iniciar con el Mac"
    }
}

private extension NSAlert {
    static func show(_ title: String, _ msg: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.runModal()
    }
}
