import Foundation

struct ProcessLoad {
    let name: String
    let cpu: Double   // percent
    let mem: Double   // MB
}

enum ProcessMonitor {
    static func topByCPU(limit: Int = 6) -> [ProcessLoad] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        // -A all procs, -c short name, -o fields, sorted descending by cpu
        proc.arguments = ["-Aceo", "pcpu,pmem,rss,comm", "-r"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        guard (try? proc.run()) != nil else { return [] }
        proc.waitUntilExit()

        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = raw.split(separator: "\n").dropFirst() // drop header

        var results: [ProcessLoad] = []
        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let cpu = Double(parts[0]),
                  let memPct = Double(parts[1]),
                  let rssKB = Double(parts[2])
            else { continue }

            _ = memPct
            let name = String(parts[3])
            let memMB = rssKB / 1024.0

            // Skip kernel/idle noise
            guard cpu > 0 || results.count < 3 else { continue }
            guard !name.isEmpty, name != "ps" else { continue }

            results.append(ProcessLoad(name: name, cpu: cpu, mem: memMB))
            if results.count >= limit { break }
        }
        return results
    }
}
