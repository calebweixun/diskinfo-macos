import Foundation

struct DiskInfo: Sendable {
    var device: String
    var name: String?
    var model: String?
    var serial: String?
    var firmware: String?
    var protocolName: String?
    var capacity: String?
    var health: String?
    var temperature: String?
    var percentageUsed: String?
    var spare: String?
    var read: String?
    var written: String?
    var powerOnHours: String?
    var powerCycles: String?
    var unsafeShutdowns: String?
    var integrityErrors: String?
    var errorLogEntries: String?
    var smartctlError: String?
}

@main
struct DiskInfoApp {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let json = args.contains("--json")
        let verbose = args.contains("--verbose")

        guard let smartctl = findSmartctl() else {
            fputs("error: smartctl was not found. Install smartmontools with: brew install smartmontools\n", stderr)
            exit(1)
        }

        let devices = discoverDisks()
        if devices.isEmpty {
            print("No physical disks found.")
            return
        }

        let disks = devices.map { inspect(device: $0, smartctl: smartctl) }

        if json {
            printJSON(disks)
        } else {
            printHuman(disks, verbose: verbose)
        }
    }

    static func findSmartctl() -> String? {
        let candidates = [
            "/opt/homebrew/bin/smartctl",
            "/usr/local/bin/smartctl",
            "/usr/bin/smartctl"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    static func discoverDisks() -> [String] {
        let output = run("/usr/sbin/diskutil", ["list", "physical"]) ?? ""
        let regex = try! NSRegularExpression(pattern: #"(?m)^/dev/(disk\d+)\b"#)
        let range = NSRange(output.startIndex..., in: output)
        return regex.matches(in: output, range: range).compactMap {
            guard let r = Range($0.range(at: 1), in: output) else { return nil }
            return "/dev/\(output[r])"
        }
    }

    static func inspect(device: String, smartctl: String) -> DiskInfo {
        let info = run("/usr/sbin/diskutil", ["info", device]) ?? ""
        let smart = run(smartctl, ["-a", device]) ?? ""

        let model = firstValue(smart, keys: ["Model Number", "Device Model", "Product"])
            ?? firstValue(info, keys: ["Device / Media Name", "Device / Media Name:"])
        let protocolName = firstValue(smart, keys: ["Transport protocol", "Protocol", "SATA Version is", "NVMe Version"])
        let serial = firstValue(smart, keys: ["Serial Number", "Serial number"])
        let firmware = firstValue(smart, keys: ["Firmware Version", "Revision"])
        let capacity = firstValue(info, keys: ["Disk Size", "Total Size"])
            ?? firstValue(smart, keys: ["User Capacity"])

        let health = firstValue(smart, keys: [
            "SMART overall-health self-assessment test result",
            "SMART Health Status",
            "SMART overall-health"
        ])
        let temperature = firstValue(smart, keys: ["Temperature"])
        let percentageUsed = firstValue(smart, keys: ["Percentage Used"])
        let spare = firstValue(smart, keys: ["Available Spare"])
        let read = firstValue(smart, keys: ["Data Units Read"])
        let written = firstValue(smart, keys: ["Data Units Written"])
        let hours = firstValue(smart, keys: ["Power On Hours", "Power_On_Hours"])
        let cycles = firstValue(smart, keys: ["Power Cycles", "Power_Cycle_Count"])
        let unsafe = firstValue(smart, keys: ["Unsafe Shutdowns", "Unsafe_Shutdowns"])
        let integrity = firstValue(smart, keys: ["Media and Data Integrity Errors", "Media_Wearout_Indicator"])
        let errorLog = firstValue(smart, keys: ["Error Information Log Entries"])

        let smartctlError: String? = smart.isEmpty ? "smartctl returned no data" : nil

        return DiskInfo(
            device: device,
            name: firstValue(info, keys: ["Volume Name"]),
            model: model,
            serial: serial,
            firmware: firmware,
            protocolName: protocolName,
            capacity: capacity,
            health: health,
            temperature: temperature,
            percentageUsed: percentageUsed,
            spare: spare,
            read: read,
            written: written,
            powerOnHours: hours,
            powerCycles: cycles,
            unsafeShutdowns: unsafe,
            integrityErrors: integrity,
            errorLogEntries: errorLog,
            smartctlError: smartctlError
        )
    }

    static func firstValue(_ text: String, keys: [String]) -> String? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let s = String(line)
            for key in keys {
                guard let range = s.range(of: key, options: [.caseInsensitive]) else { continue }
                let remainder = s[range.upperBound...]
                if let colon = remainder.firstIndex(of: ":") {
                    let value = remainder[remainder.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty { return value }
                } else if let value = remainder.split(separator: " ").dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces).nilIfEmpty {
                    return value
                }
            }
        }
        return nil
    }

    static func run(_ executable: String, _ arguments: [String]) -> String? {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func printHuman(_ disks: [DiskInfo], verbose: Bool) {
        print("diskinfo — macOS storage information")
        print("====================================")
        print("Disks: \(disks.count)\n")

        for (index, d) in disks.enumerated() {
            print("\(index + 1). \(d.device)  \(d.model ?? "Unknown disk")")
            print("   Capacity       \(d.capacity ?? "-")")
            print("   Protocol       \(d.protocolName ?? "-")")
            print("   Serial         \(d.serial ?? "-")")
            print("   Firmware       \(d.firmware ?? "-")")
            print("   Health         \(healthDisplay(d.health))")
            print("   Temperature    \(d.temperature ?? "-")")
            print("   Used           \(d.percentageUsed ?? "-")")
            print("   Spare          \(d.spare ?? "-")")
            print("   Read           \(d.read ?? "-")")
            print("   Written        \(d.written ?? "-")")
            print("   Power On       \(d.powerOnHours ?? "-")")
            print("   Power Cycles   \(d.powerCycles ?? "-")")
            print("   Unsafe Shutdowns \(d.unsafeShutdowns ?? "-")")
            print("   Integrity Errs  \(d.integrityErrors ?? "-")")
            print("   Error Log       \(d.errorLogEntries ?? "-")")
            if verbose, let name = d.name {
                print("   Volume          \(name)")
            }
            if let error = d.smartctlError {
                print("   Warning         \(error)")
            }
            print()
        }
    }

    static func healthDisplay(_ value: String?) -> String {
        guard let value else { return "UNKNOWN" }
        if value.uppercased().contains("PASS") || value.uppercased() == "OK" { return "HEALTHY" }
        return value
    }

    static func printJSON(_ disks: [DiskInfo]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            print(String(data: try encoder.encode(disks.map { d in
                [
                    "device": d.device,
                    "name": d.name ?? "",
                    "model": d.model ?? "",
                    "serial": d.serial ?? "",
                    "firmware": d.firmware ?? "",
                    "protocol": d.protocolName ?? "",
                    "capacity": d.capacity ?? "",
                    "health": d.health ?? "",
                    "temperature": d.temperature ?? "",
                    "percentage_used": d.percentageUsed ?? "",
                    "available_spare": d.spare ?? "",
                    "data_read": d.read ?? "",
                    "data_written": d.written ?? "",
                    "power_on_hours": d.powerOnHours ?? "",
                    "power_cycles": d.powerCycles ?? "",
                    "unsafe_shutdowns": d.unsafeShutdowns ?? "",
                    "integrity_errors": d.integrityErrors ?? "",
                    "error_log_entries": d.errorLogEntries ?? ""
                ]
            })), encoding: .utf8)!)
        } catch {
            fputs("error: failed to encode JSON\n", stderr)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
