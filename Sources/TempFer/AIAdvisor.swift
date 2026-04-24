import Foundation
import UserNotifications

// MARK: - AI Advisor

final class AIAdvisor {
    static let shared = AIAdvisor()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    var onTip: ((String) -> Void)?
    var onLoadingStart: (() -> Void)?

    private var lastTipDate: Date = .distantPast
    private var isGenerating = false

    // MARK: - UserDefaults keys

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "anthropicAPIKey") }
    }
    var aiEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "aiEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "aiEnabled") }
    }
    // 0 = never (disabled), otherwise minutes between tips
    var frequencyMinutes: Int {
        get { UserDefaults.standard.object(forKey: "tipFrequencyMinutes") as? Int ?? 60 }
        set { UserDefaults.standard.set(newValue, forKey: "tipFrequencyMinutes") }
    }
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "tipNotifications") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "tipNotifications") }
    }

    var minutesSinceLastTip: Int {
        Int(Date().timeIntervalSince(lastTipDate) / 60)
    }
    var minutesUntilNextTip: Int {
        guard frequencyMinutes > 0 else { return 0 }
        return max(0, frequencyMinutes - minutesSinceLastTip)
    }
    var scheduledTipsActive: Bool { frequencyMinutes > 0 }

    // MARK: - Context

    struct Context {
        let cpuTemp: Double
        let batteryTemp: Double?
        let ssdTemp: Double?
        let topProcesses: [ProcessLoad]
        let sessionMinutes: Int
    }

    // MARK: - Public API

    func checkScheduled(context: Context) {
        guard aiEnabled, !apiKey.isEmpty, !isGenerating else { return }
        guard frequencyMinutes > 0 else { return }
        guard minutesSinceLastTip >= frequencyMinutes else { return }
        generate(context: context)
    }

    func generateNow(context: Context) {
        guard !apiKey.isEmpty, !isGenerating else { return }
        generate(context: context)
    }

    // MARK: - Private

    private func generate(context: Context) {
        isGenerating = true
        onLoadingStart?()

        let sessionStr: String
        if context.sessionMinutes < 60 {
            sessionStr = "\(context.sessionMinutes) minutos"
        } else {
            let h = context.sessionMinutes / 60
            let m = context.sessionMinutes % 60
            sessionStr = m > 0 ? "\(h)h \(m)min" : "\(h) hora\(h == 1 ? "" : "s")"
        }

        let procsStr = context.topProcesses.prefix(4)
            .map { "\($0.name) \(Int($0.cpu))% CPU" }
            .joined(separator: ", ")

        let userMsg = """
        Estado actual del Mac:
        - CPU: \(String(format: "%.1f", context.cpuTemp))°C
        - Batería: \(context.batteryTemp.map { String(format: "%.1f°C", $0) } ?? "N/A")
        - SSD: \(context.ssdTemp.map { String(format: "%.1f°C", $0) } ?? "N/A")
        - Sesión activa: \(sessionStr)
        - Procesos activos: \(procsStr.isEmpty ? "sin datos" : procsStr)
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 120,
            "system": """
            Eres el asistente inteligente de TempFer, una app de temperatura para Mac. \
            Da UN consejo breve, cálido y útil en español basado en el estado del sistema. \
            Habla como si el Mac le hablara al usuario directamente. \
            Máximo 2 oraciones cortas. Sin markdown. Sin emojis. Solo texto claro y útil.
            """,
            "messages": [["role": "user", "content": userMsg]]
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 20

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isGenerating = false

                guard let data,
                      error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = (json["content"] as? [[String: Any]])?.first,
                      let text = content["text"] as? String
                else { return }

                let tip = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.lastTipDate = Date()
                self.onTip?(tip)
                if self.notificationsEnabled { self.sendNotification(tip) }
            }
        }.resume()
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "TempFer"
        content.body  = text
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "tempfer-tip-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
