import Foundation
import Darwin

enum BridgeServiceError: Error, CustomStringConvertible {
    case templateMissing(URL)
    case launchctlFailed(args: [String], exitCode: Int32, output: String)

    var description: String {
        switch self {
        case .templateMissing(let url):
            return "plist template not found at \(url.path)"
        case .launchctlFailed(let args, let code, let output):
            return "launchctl \(args.joined(separator: " ")) failed (\(code))\n\(output)"
        }
    }
}

/// The launchd-truth probe the menu uses to decide Start/Stop enablement.
/// Extracted as a protocol so `ServiceStatePoller` can be tested without
/// shelling out to `launchctl`.
protocol ServiceLoadedProbe: AnyObject {
    func isLoaded() -> Bool
}

final class BridgeService: ServiceLoadedProbe {
    private let settings: AppSettings
    private let label: String
    private let launchctlPath: String

    init(settings: AppSettings = .shared,
         label: String = AppSettings.serviceLabel,
         launchctlPath: String = "/bin/launchctl") {
        self.settings = settings
        self.label = label
        self.launchctlPath = launchctlPath
    }

    static func serviceTarget(label: String) -> String {
        "gui/\(getuid())/\(label)"
    }

    private var serviceTarget: String { Self.serviceTarget(label: label) }
    private var bootstrapDomain: String { "gui/\(getuid())" }

    var isPlistInstalled: Bool {
        FileManager.default.fileExists(atPath: settings.installedPlistURL.path)
    }

    /// Reads the bridge's template plist, rewrites the absolute paths from
    /// current settings, and writes the result to ~/Library/LaunchAgents.
    func installPlist() throws {
        let templateURL = settings.plistTemplateURL
        guard FileManager.default.fileExists(atPath: templateURL.path) else {
            throw BridgeServiceError.templateMissing(templateURL)
        }
        let templateData = try Data(contentsOf: templateURL)
        let subs = PlistTemplate.Substitutions(
            venvBinary: settings.venvBinaryURL,
            envFile: settings.envFileURL,
            workingDirectory: settings.bridgeRepoURL,
            stdoutLog: settings.stdoutLogURL,
            stderrLog: settings.stderrLogURL
        )
        let rewritten = try PlistTemplate.rewrite(template: templateData, with: subs)
        let destDir = settings.installedPlistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: destDir, withIntermediateDirectories: true
        )
        try rewritten.write(to: settings.installedPlistURL, options: .atomic)
    }

    /// Removes the installed plist (after best-effort bootout).
    func uninstallPlist() throws {
        _ = try? bootout()
        if FileManager.default.fileExists(atPath: settings.installedPlistURL.path) {
            try FileManager.default.removeItem(at: settings.installedPlistURL)
        }
    }

    @discardableResult
    func bootstrap() throws -> String {
        try launchctl("bootstrap", bootstrapDomain, settings.installedPlistURL.path)
    }

    @discardableResult
    func bootout() throws -> String {
        try launchctl("bootout", serviceTarget)
    }

    @discardableResult
    func kickstart() throws -> String {
        try launchctl("kickstart", "-k", serviceTarget)
    }

    /// True if the service is currently registered with launchd.
    func isLoaded() -> Bool {
        do {
            _ = try launchctl("print", serviceTarget)
            return true
        } catch {
            return false
        }
    }

    /// Ensure the plist exists, then bootstrap (idempotent: a second
    /// bootstrap on an already-loaded service surfaces as a no-op).
    func start() throws {
        if !isPlistInstalled {
            try installPlist()
        }
        if isLoaded() {
            try kickstart()
        } else {
            try bootstrap()
        }
    }

    func stop() throws {
        try bootout()
    }

    @discardableResult
    private func launchctl(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchctlPath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        if process.terminationStatus != 0 {
            throw BridgeServiceError.launchctlFailed(
                args: args,
                exitCode: process.terminationStatus,
                output: output
            )
        }
        return output
    }
}
