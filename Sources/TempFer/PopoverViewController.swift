import Cocoa

// MARK: - Global helpers

func tempColor(_ celsius: Double) -> NSColor {
    switch celsius {
    case ..<45:  return NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    case ..<65:  return NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1)
    case ..<82:  return NSColor(red: 1.00, green: 0.50, blue: 0.00, alpha: 1)
    default:     return NSColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1)
    }
}

func tempLabel(_ celsius: Double) -> String {
    switch celsius {
    case ..<45:  return "Óptima"
    case ..<65:  return "Normal"
    case ..<82:  return "Alta"
    default:     return "Crítica"
    }
}

func formatTemp(_ celsius: Double) -> String {
    let units = UserDefaults.standard.string(forKey: "tempUnits") ?? "C"
    if units == "F" {
        return String(format: "%.0f°F", celsius * 9/5 + 32)
    }
    return String(format: "%.0f°C", celsius)
}

// MARK: - GaugeCardView
// Draws an arc-style gauge (speedometer 220°→-40°, sweep 260°) with animated fill.

final class GaugeCardView: NSView {
    private var celsius: Double = 0
    private var color: NSColor = .systemGreen
    private var name: String   = ""
    private var status: String = ""

    private var targetFraction: CGFloat = 0
    private(set) var displayedFraction: CGFloat = 0
    private var animTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Update data

    func update(celsius c: Double, name n: String) {
        celsius        = c
        color          = c > 0 ? tempColor(c) : .tertiaryLabelColor
        name           = n
        status         = c > 0 ? tempLabel(c) : "—"
        targetFraction = c > 0 ? CGFloat(min(c / 110.0, 1.0)) : 0
        needsDisplay   = true
    }

    // MARK: Animate in (0 → targetFraction)

    func animateIn(delay: TimeInterval = 0) {
        animTimer?.invalidate()
        displayedFraction = 0
        needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let start = CACurrentMediaTime()
            let dur   = 0.55
            let t = Timer(timeInterval: 1/60, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                let p = min((CACurrentMediaTime() - start) / dur, 1.0)
                self.displayedFraction = CGFloat(1 - pow(1 - p, 3)) * self.targetFraction
                self.needsDisplay = true
                if p >= 1 { timer.invalidate(); self.animTimer = nil }
            }
            RunLoop.main.add(t, forMode: .common)
            self.animTimer = t
        }
    }

    // MARK: Draw

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let h = bounds.height

        // Card background
        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        NSColor.white.withAlphaComponent(0.06).setFill()
        bg.fill()
        NSColor.white.withAlphaComponent(0.08).setStroke()
        bg.lineWidth = 0.5
        bg.stroke()

        // Arc parameters
        let center   = CGPoint(x: w / 2, y: h * 0.59)
        let radius: CGFloat = min(w, h) * 0.29
        let lw: CGFloat     = 3
        let arcStart: CGFloat = 220
        let arcEnd: CGFloat   = -40   // = 320° (full arc end)

        // Track arc
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius,
                        startAngle: arcStart, endAngle: arcEnd, clockwise: true)
        track.lineWidth     = lw
        track.lineCapStyle  = .round
        NSColor.white.withAlphaComponent(0.10).setStroke()
        track.stroke()

        // Fill arc
        if displayedFraction > 0.001 {
            let endAngle = arcStart - 260 * displayedFraction
            let fill = NSBezierPath()
            fill.appendArc(withCenter: center, radius: radius,
                           startAngle: arcStart, endAngle: endAngle, clockwise: true)
            fill.lineWidth    = lw
            fill.lineCapStyle = .round
            color.setStroke()
            fill.stroke()

            // Glow at tip
            let tipAngle = endAngle * .pi / 180
            let tipX = center.x + radius * cos(tipAngle)
            let tipY = center.y + radius * sin(tipAngle)
            let glowRect = CGRect(x: tipX - 5, y: tipY - 5, width: 10, height: 10)
            let glow = NSBezierPath(ovalIn: glowRect)
            color.withAlphaComponent(0.35).setFill()
            glow.fill()
        }

        // Temperature number
        let tempStr = celsius > 0 ? formatTemp(celsius) : "—"
        let tempAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: h * 0.175, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        let tempAS = NSAttributedString(string: tempStr, attributes: tempAttrs)
        let ts = tempAS.size()
        tempAS.draw(at: NSPoint(x: (w - ts.width) / 2, y: center.y - ts.height / 2 - 1))

        // Sensor name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: h * 0.110, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let nameAS = NSAttributedString(string: name.uppercased(), attributes: nameAttrs)
        let ns = nameAS.size()
        nameAS.draw(at: NSPoint(x: (w - ns.width) / 2, y: h * 0.17))

        // Status label
        if celsius > 0 {
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: h * 0.095, weight: .medium),
                .foregroundColor: color.withAlphaComponent(0.88),
            ]
            let statusAS = NSAttributedString(string: status, attributes: statusAttrs)
            let ss = statusAS.size()
            statusAS.draw(at: NSPoint(x: (w - ss.width) / 2, y: h * 0.05))
        }
    }
}

// MARK: - ProcessRowView

final class ProcessRowView: NSView {
    private let nameLabel  = NSTextField(labelWithString: "")
    private let cpuLabel   = NSTextField(labelWithString: "")
    private let barTrack   = NSView()
    private let barFill    = CALayer()
    private var fillFrac: CGFloat = 0
    private var barColor: NSColor = .systemGreen

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .labelColor
        nameLabel.isEditable = false; nameLabel.isBordered = false; nameLabel.backgroundColor = .clear
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        cpuLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        cpuLabel.textColor = .secondaryLabelColor
        cpuLabel.isEditable = false; cpuLabel.isBordered = false; cpuLabel.backgroundColor = .clear
        cpuLabel.alignment = .right
        cpuLabel.translatesAutoresizingMaskIntoConstraints = false

        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.wantsLayer = true
        barTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        barTrack.layer?.cornerRadius = 2

        barFill.cornerRadius = 2
        barFill.backgroundColor = NSColor.systemGreen.cgColor
        barTrack.layer?.addSublayer(barFill)

        for v in [nameLabel, cpuLabel, barTrack] { addSubview(v) }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 22),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: barTrack.leadingAnchor, constant: -8),
            barTrack.widthAnchor.constraint(equalToConstant: 58),
            barTrack.heightAnchor.constraint(equalToConstant: 4),
            barTrack.centerYAnchor.constraint(equalTo: centerYAnchor),
            barTrack.trailingAnchor.constraint(equalTo: cpuLabel.leadingAnchor, constant: -6),
            cpuLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            cpuLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            cpuLabel.widthAnchor.constraint(equalToConstant: 38),
        ])
    }

    override func layout() {
        super.layout()
        let w = barTrack.bounds.width
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barFill.frame = CGRect(x: 0, y: 0, width: w * fillFrac, height: barTrack.bounds.height)
        CATransaction.commit()
    }

    func update(process p: ProcessLoad) {
        nameLabel.stringValue = p.name
        cpuLabel.stringValue  = String(format: "%.0f%%", p.cpu)
        fillFrac  = CGFloat(min(p.cpu / 100, 1.0))
        barColor  = p.cpu > 50 ? .systemRed : p.cpu > 20 ? .systemOrange : tempColor(0)
        cpuLabel.textColor = barColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barFill.backgroundColor = barColor.cgColor
        CATransaction.commit()
        needsLayout = true
    }
}

// MARK: - TipView

final class TipView: NSView {
    enum State {
        case noKey
        case loading
        case tip(String, next: String)
    }

    var onSettingsTap: (() -> Void)?
    private(set) var state: State = .noKey

    private let dot       = NSView()
    private let titleLbl  = NSTextField(labelWithString: "")
    private let bodyLbl   = NSTextField(labelWithString: "")
    private let nextLbl   = NSTextField(labelWithString: "")
    private var pulseTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        layer?.cornerRadius    = 10
        layer?.borderColor     = NSColor.white.withAlphaComponent(0.07).cgColor
        layer?.borderWidth     = 0.5

        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        addSubview(dot)

        for lbl in [titleLbl, bodyLbl, nextLbl] {
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lbl.isEditable = false; lbl.isBordered = false; lbl.backgroundColor = .clear
            addSubview(lbl)
        }
        titleLbl.font       = .systemFont(ofSize: 11, weight: .semibold)
        titleLbl.textColor  = .secondaryLabelColor

        bodyLbl.font        = .systemFont(ofSize: 12.5)
        bodyLbl.textColor   = .labelColor
        bodyLbl.maximumNumberOfLines = 4
        bodyLbl.lineBreakMode = .byWordWrapping
        bodyLbl.preferredMaxLayoutWidth = 240

        nextLbl.font        = .systemFont(ofSize: 10)
        nextLbl.textColor   = .tertiaryLabelColor

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            dot.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            titleLbl.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            titleLbl.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            titleLbl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            bodyLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 6),
            bodyLbl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bodyLbl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            nextLbl.topAnchor.constraint(equalTo: bodyLbl.bottomAnchor, constant: 5),
            nextLbl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nextLbl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        setState(.noKey)
    }

    func setState(_ s: State) {
        state = s
        stopPulse()

        switch s {
        case .noKey:
            dot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            titleLbl.stringValue = "Asistente IA"
            bodyLbl.stringValue  = "Configura tu API key de Anthropic en Preferencias para recibir consejos personalizados cada hora."
            nextLbl.stringValue  = "⚙  Abrir Preferencias"
            nextLbl.textColor    = .linkColor

        case .loading:
            dot.layer?.backgroundColor = NSColor.systemBlue.cgColor
            titleLbl.stringValue = "Analizando tu Mac…"
            bodyLbl.stringValue  = "Generando consejo personalizado."
            nextLbl.stringValue  = ""
            startPulse()

        case .tip(let text, let next):
            dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            titleLbl.stringValue = "Consejo del momento"
            bodyLbl.stringValue  = text
            nextLbl.stringValue  = "Próximo consejo en \(next)"
            nextLbl.textColor    = .tertiaryLabelColor

            // Animate text in
            bodyLbl.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                bodyLbl.animator().alphaValue = 1
            }
        }
    }

    private func startPulse() {
        var dim = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                self.dot.animator().alphaValue = dim ? 1 : 0.25
            }
            dim.toggle()
        }
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        dot.alphaValue = 1
    }

    override func mouseUp(with event: NSEvent) {
        if case .noKey = state { onSettingsTap?() }
        else if case .tip = state, nextLbl.frame.contains(convert(event.locationInWindow, from: nil)) {
            // tapping "próximo" doesn't do anything - could navigate to settings
        }
    }
    override func resetCursorRects() {
        if case .noKey = state { addCursorRect(bounds, cursor: .pointingHand) }
    }
}

// MARK: - Popover View Controller

final class PopoverViewController: NSViewController {

    private let cpuCard  = GaugeCardView(frame: .zero)
    private let batCard  = GaugeCardView(frame: .zero)
    private let ssdCard  = GaugeCardView(frame: .zero)
    private var procRows: [ProcessRowView] = []
    private let procStack = NSStackView()
    let tipView = TipView(frame: .zero)

    var onSettingsTap: (() -> Void)? {
        get { tipView.onSettingsTap }
        set { tipView.onSettingsTap = newValue }
    }

    // MARK: Load

    override func loadView() {
        let fx = NSVisualEffectView()
        fx.material    = .hudWindow
        fx.blendingMode = .behindWindow
        fx.state       = .active
        view = fx
        setupLayout()
    }

    // MARK: Layout

    private func setupLayout() {
        let pad: CGFloat = 14

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing     = 0
        root.alignment   = .leading
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),
            view.widthAnchor.constraint(equalToConstant: 304),
        ])

        func full(_ v: NSView) { v.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true }

        // ── Header ─────────────────────────────
        let header = makeHeader()
        root.addArrangedSubview(header)
        full(header)
        root.setCustomSpacing(12, after: header)

        // ── Gauge row ──────────────────────────
        let gaugeRow = NSStackView(views: [cpuCard, batCard, ssdCard])
        gaugeRow.orientation = .horizontal
        gaugeRow.spacing     = 6
        gaugeRow.distribution = .fillEqually
        gaugeRow.translatesAutoresizingMaskIntoConstraints = false
        gaugeRow.heightAnchor.constraint(equalToConstant: 96).isActive = true

        root.addArrangedSubview(gaugeRow)
        full(gaugeRow)
        root.setCustomSpacing(12, after: gaugeRow)

        // ── Divider ────────────────────────────
        let d1 = makeDivider()
        root.addArrangedSubview(d1)
        full(d1)
        root.setCustomSpacing(8, after: d1)

        // ── Processes header ───────────────────
        let ph = sectionLabel("Procesos activos")
        root.addArrangedSubview(ph)
        root.setCustomSpacing(6, after: ph)

        // ── Process rows ───────────────────────
        procStack.orientation = .vertical
        procStack.spacing     = 2
        procStack.alignment   = .leading
        procStack.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(procStack)
        full(procStack)

        for _ in 0..<5 {
            let r = ProcessRowView()
            procRows.append(r)
            procStack.addArrangedSubview(r)
            r.widthAnchor.constraint(equalTo: procStack.widthAnchor).isActive = true
        }
        root.setCustomSpacing(12, after: procStack)

        // ── Divider ────────────────────────────
        let d2 = makeDivider()
        root.addArrangedSubview(d2)
        full(d2)
        root.setCustomSpacing(10, after: d2)

        // ── AI Tip ─────────────────────────────
        root.addArrangedSubview(tipView)
        full(tipView)
    }

    // MARK: Header

    private var settingsAction: (() -> Void)?

    private func makeHeader() -> NSView {
        let c = NSView()
        c.translatesAutoresizingMaskIntoConstraints = false
        c.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let cfg  = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) { icon.image = img }
        icon.contentTintColor = .labelColor
        c.addSubview(icon)

        let title = NSTextField(labelWithString: "TempFer")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 14, weight: .bold)
        title.textColor = .labelColor
        c.addSubview(title)

        let gear = NSButton(title: "", target: self, action: #selector(gearTapped))
        gear.translatesAutoresizingMaskIntoConstraints = false
        gear.bezelStyle    = .texturedRounded
        gear.isBordered    = false
        let gCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Preferencias")?
            .withSymbolConfiguration(gCfg) { gear.image = img }
        gear.contentTintColor = .tertiaryLabelColor
        c.addSubview(gear)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 17),
            icon.heightAnchor.constraint(equalToConstant: 17),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            title.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            gear.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            gear.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            gear.widthAnchor.constraint(equalToConstant: 22),
            gear.heightAnchor.constraint(equalToConstant: 22),
        ])
        return c
    }

    @objc private func gearTapped() { onSettingsTap?() }

    private func makeDivider() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.cgColor
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func sectionLabel(_ text: String) -> NSView {
        let lbl = NSTextField(labelWithString: text.uppercased())
        lbl.font       = .systemFont(ofSize: 10, weight: .semibold)
        lbl.textColor  = .tertiaryLabelColor
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }

    // MARK: Appear animation

    override func viewDidAppear() {
        super.viewDidAppear()
        view.alphaValue = 0
        view.layer?.transform = CATransform3DMakeTranslation(0, -6, 0)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.20)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        view.layer?.transform = CATransform3DIdentity
        CATransaction.commit()

        cpuCard.animateIn(delay: 0.04)
        batCard.animateIn(delay: 0.10)
        ssdCard.animateIn(delay: 0.16)
    }

    // MARK: Public API

    func refresh(cpu: Double, battery: Double?, ssd: Double?, processes: [ProcessLoad]) {
        cpuCard.update(celsius: cpu,           name: "CPU")
        batCard.update(celsius: battery ?? 0,  name: "Batería")
        batCard.isHidden = (battery == nil)
        ssdCard.update(celsius: ssd ?? 0,      name: "SSD")
        ssdCard.isHidden = (ssd == nil)

        for (i, row) in procRows.enumerated() {
            if i < processes.count {
                row.update(process: processes[i])
                row.isHidden = false
            } else {
                row.isHidden = true
            }
        }
    }
}
