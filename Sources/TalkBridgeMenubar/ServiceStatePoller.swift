import Foundation

/// Periodically asks `BridgeService.isLoaded()` (which shells out to
/// `launchctl print`) and reports the answer on the main queue. Used by
/// the menu to decide Start/Stop enablement from launchd truth rather
/// than from the bridge's status.json (which may be missing, stale, or
/// describe a service that was bootstrapped without ever writing yet).
final class ServiceStatePoller {
    private let service: BridgeService
    private let interval: DispatchTimeInterval
    private let queue = DispatchQueue(
        label: "com.leiverkus.TalkBridgeMenubar.servicepoller",
        qos: .utility
    )
    private var timer: DispatchSourceTimer?
    private var lastValue: Bool?

    var onUpdate: ((Bool) -> Void)?

    init(service: BridgeService, interval: DispatchTimeInterval = .seconds(5)) {
        self.service = service
        self.interval = interval
    }

    deinit { stop() }

    func start() {
        queue.async { [weak self] in
            guard let self = self, self.timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now(), repeating: self.interval)
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            self.timer = t
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    /// Force a fresh check right now (e.g. after a Start/Stop action).
    func refresh() {
        queue.async { [weak self] in self?.tick() }
    }

    private func tick() {
        let loaded = service.isLoaded()
        if lastValue == loaded { return }
        lastValue = loaded
        DispatchQueue.main.async { [onUpdate] in
            onUpdate?(loaded)
        }
    }
}
