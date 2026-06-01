import Foundation

/// Watches the bridge's status.json file and publishes parsed BridgeStatus
/// values. Combines DispatchSource FS events for instant updates with a
/// 2-second timer fallback (atomic temp+rename writes break a single FD watch
/// after the first delete event).
final class BridgeStatusReader {
    private var url: URL
    private let pollInterval: DispatchTimeInterval
    private let queue = DispatchQueue(label: "com.leiverkus.TalkBridgeMenubar.statusreader")

    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var lastSnapshot: BridgeStatus??

    var onUpdate: ((BridgeStatus?) -> Void)?

    init(url: URL, pollInterval: DispatchTimeInterval = .seconds(2)) {
        self.url = url
        self.pollInterval = pollInterval
    }

    deinit {
        stop()
    }

    func start() {
        queue.async { [weak self] in
            self?.startTimer()
            self?.tryAttachFSWatch()
            self?.readAndPublish()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
            self?.detachFSWatch()
        }
    }

    /// Point the reader at a new status file (e.g. when the user changes the
    /// bridge repo path in Settings). Drops the old watcher, resets the
    /// dedupe snapshot, and republishes against the new URL.
    func retarget(to newURL: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.url != newURL else { return }
            self.detachFSWatch()
            self.url = newURL
            self.lastSnapshot = nil
            self.tryAttachFSWatch()
            self.readAndPublish()
        }
    }

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        t.setEventHandler { [weak self] in
            self?.tryAttachFSWatch()
            self?.readAndPublish()
        }
        t.resume()
        timer = t
    }

    private func tryAttachFSWatch() {
        guard source == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        s.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.readAndPublish()
            // atomic rename invalidates this descriptor; detach so the next
            // timer tick reattaches against the new inode.
            let events = s.data
            if events.contains(.delete) || events.contains(.rename) {
                self.detachFSWatch()
            }
        }
        s.setCancelHandler { [fd] in
            close(fd)
        }
        s.resume()
        source = s
        fileDescriptor = fd
    }

    private func detachFSWatch() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    private func readAndPublish() {
        let status: BridgeStatus? = {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(BridgeStatus.self, from: data)
        }()
        if let last = lastSnapshot, last == status { return }
        lastSnapshot = .some(status)
        DispatchQueue.main.async { [onUpdate] in
            onUpdate?(status)
        }
    }
}
