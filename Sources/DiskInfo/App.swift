import SwiftUI

struct Drive: Identifiable, Hashable {
    let id: String
    let model: String
    let serial: String
    let firmware: String
    let capacity: String
    let protocolName: String
    let health: String
    let temperature: String
    let percentageUsed: String
    let spare: String
    let read: String
    let written: String
    let powerOnHours: String
    let powerCycles: String
    let unsafeShutdowns: String
    let integrityErrors: String
    let errorLogEntries: String
}

@main
struct DiskInfoApp: App {
    @StateObject private var store = DiskStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 820, minHeight: 540)
        }
        .windowResizability(.contentSize)
    }
}

final class DiskStore: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var selectedID: String?
    @Published var isLoading = false
    @Published var error: String?

    func refresh() {
        isLoading = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.loadDrives()
            DispatchQueue.main.async {
                self.drives = result.drives
                if self.selectedID == nil { self.selectedID = result.drives.first?.id }
                self.error = result.error
                self.isLoading = false
            }
        }
    }

    private static func loadDrives() -> (drives: [Drive], error: String?) {
        guard let smartctl = findSmartctl() else {
            return ([], "smartctl not found. Install smartmontools with Homebrew: brew install smartmontools")
        }
        let list = run("/usr/sbin/diskutil", ["list", "physical"]) ?? ""
        let devices = list.split(separator: "\n")
            .compactMap { line -> String? in
                let text = String(line)
                guard let range = text.range(of: "/dev/disk") else { return nil }
                let tail = text[range.lowerBound...]
                let token = tail.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
                return token?.hasPrefix("/dev/disk") == true ? token : nil
            }
            .reduce(into: [String]()) { result, device in if !result.contains(device) { result.append(device) } }

        let drives = devices.map { inspect($0, smartctl: smartctl) }
        return (drives, nil)
    }

    private static func inspect(_ device: String, smartctl: String) -> Drive {
        let info = run("/usr/sbin/diskutil", ["info", device]) ?? ""
        let smart = run(smartctl, ["-a", device]) ?? ""
        func value(_ keys: [String]) -> String {
            for line in smart.split(separator: "\n") {
                let text = String(line)
                for key in keys {
                    guard let keyRange = text.range(of: key, options: .caseInsensitive) else { continue }
                    let rest = text[keyRange.upperBound...]
                    if let colon = rest.firstIndex(of: ":") {
                        let v = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        if !v.isEmpty { return v }
                    }
                }
            }
            return "—"
        }
        func infoValue(_ keys: [String]) -> String {
            for line in info.split(separator: "\n") {
                let text = String(line)
                for key in keys {
                    guard let r = text.range(of: key, options: .caseInsensitive), let colon = text[r.upperBound...].firstIndex(of: ":") else { continue }
                    let v = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !v.isEmpty { return v }
                }
            }
            return "—"
        }

        let healthRaw = value(["SMART overall-health self-assessment test result", "SMART Health Status"])
        let health = healthRaw.uppercased().contains("PASS") || healthRaw.uppercased() == "OK" ? "Healthy" : healthRaw
        return Drive(
            id: device,
            model: value(["Model Number", "Device Model", "Product"]),
            serial: value(["Serial Number"]),
            firmware: value(["Firmware Version"]),
            capacity: infoValue(["Disk Size", "Total Size"]),
            protocolName: value(["Transport protocol", "Protocol", "NVMe Version"]),
            health: health,
            temperature: value(["Temperature"]),
            percentageUsed: value(["Percentage Used"]),
            spare: value(["Available Spare"]),
            read: value(["Data Units Read"]),
            written: value(["Data Units Written"]),
            powerOnHours: value(["Power On Hours"]),
            powerCycles: value(["Power Cycles"]),
            unsafeShutdowns: value(["Unsafe Shutdowns"]),
            integrityErrors: value(["Media and Data Integrity Errors"]),
            errorLogEntries: value(["Error Information Log Entries"])
        )
    }

    private static func findSmartctl() -> String? {
        ["/opt/homebrew/bin/smartctl", "/usr/local/bin/smartctl", "/usr/bin/smartctl"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch { return nil }
    }
}

struct ContentView: View {
    @ObservedObject var store: DiskStore

    var selected: Drive? { store.drives.first(where: { $0.id == store.selectedID }) }

    var body: some View {
        NavigationSplitView {
            List(store.drives, selection: $store.selectedID) { drive in
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(drive.model).font(.headline).lineLimit(1)
                        Text(drive.id).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            .navigationTitle("Disks")
            .toolbar {
                ToolbarItem {
                    Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(store.isLoading)
                }
            }
        } detail: {
            if let drive = selected {
                DriveDetail(drive: drive)
            } else if store.isLoading {
                ProgressView("Reading disk information…")
            } else if let error = store.error {
                ContentUnavailableView("Unable to read disks", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ContentUnavailableView("No disks", systemImage: "internaldrive")
            }
        }
        .onAppear { if store.drives.isEmpty { store.refresh() } }
    }
}

struct DriveDetail: View {
    let drive: Drive

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text(drive.model).font(.largeTitle.bold())
                        Text(drive.id).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HealthBadge(text: drive.health)
                }

                GroupBox("Drive Information") {
                    Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                        Row("Capacity", drive.capacity)
                        Row("Protocol", drive.protocolName)
                        Row("Serial Number", drive.serial)
                        Row("Firmware", drive.firmware)
                        Row("Temperature", drive.temperature)
                    }
                    .padding(8)
                }

                GroupBox("Health & Usage") {
                    Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                        Row("Percentage Used", drive.percentageUsed)
                        Row("Available Spare", drive.spare)
                        Row("Data Read", drive.read)
                        Row("Data Written", drive.written)
                        Row("Power On Hours", drive.powerOnHours)
                        Row("Power Cycles", drive.powerCycles)
                        Row("Unsafe Shutdowns", drive.unsafeShutdowns)
                        Row("Integrity Errors", drive.integrityErrors)
                        Row("Error Log Entries", drive.errorLogEntries)
                    }
                    .padding(8)
                }
            }
            .padding(28)
        }
        .navigationTitle("Drive Details")
    }

    @ViewBuilder
    private func Row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
            Text(value).textSelection(.enabled)
        }
    }
}

struct HealthBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(text == "Healthy" ? Color.green.opacity(0.14) : Color.orange.opacity(0.14))
            .foregroundStyle(text == "Healthy" ? .green : .orange)
            .clipShape(Capsule())
    }
}
