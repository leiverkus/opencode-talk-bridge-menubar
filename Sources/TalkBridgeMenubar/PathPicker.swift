import AppKit

enum PathPicker {
    /// Presents a modal NSOpenPanel for choosing a single directory.
    /// Returns the chosen URL, or nil if the user cancels. Falls back to the
    /// home directory when `startingAt` is nil or an empty/unset path.
    static func pickDirectory(startingAt: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = resolvedStart(startingAt, preferParent: false)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Presents a modal NSOpenPanel for choosing a single file (e.g. the
    /// bridge console-script binary). Shows hidden files so `~/.local/bin`
    /// and friends are reachable.
    static func pickFile(startingAt: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = resolvedStart(startingAt, preferParent: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// For a file picker, start in the file's parent directory if the file
    /// itself doesn't exist yet; for a directory picker, start at the dir.
    private static func resolvedStart(_ url: URL?, preferParent: Bool) -> URL {
        guard let url = url,
              !url.path.trimmingCharacters(in: .whitespaces).isEmpty else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if preferParent {
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                return parent
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
