import AppKit

enum FolderPicker {
    /// Presents a modal NSOpenPanel for choosing a single directory.
    /// Returns the chosen URL, or nil if the user cancels. Falls back to the
    /// home directory when `startingAt` is nil or an empty/unset path.
    static func pickDirectory(startingAt: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = resolvedStart(startingAt)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func resolvedStart(_ url: URL?) -> URL {
        if let url = url, !url.path.trimmingCharacters(in: .whitespaces).isEmpty,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
