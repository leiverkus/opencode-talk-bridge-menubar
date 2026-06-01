import Foundation

/// Periodically asks `BridgeService.isLoaded()` (which shells out to
/// `launchctl print`) and reports the answer on the main queue. Used by
/// the menu to decide Start/Stop enablement from launchd truth rather
/// than from the bridge's status.json (which may be missing, stale, or
/// describe a service that was bootstrapped without ever writing yet).
final class ServiceStatePoller {
    private let service: ServiceLoadedProbe
    private let interval: DispatchTimeInterval
    private let queue: DispatchQueue
    private let publishQueue: DispatchQueue
    private var timer: DispatchSourceTimer?
    private var lastValue: Bool?

    var onUpdate: ((Bool) -> Void)?

    init(service: ServiceLoadedProbe,
         interval: DispatchTimeInterval = .seconds(5),
         queue: DispatchQueue = DispatchQueue(
            label: "com.leiverkus.TalkBridgeMenubar.servicepoller",
            qos: .utility
         ),
         publishQueue: DispatchQueue = .main) {
        self.service = service
        self.interval = interval
        self.queue = queue
        self.publishQueue = publishQueue
    }

    deinit { stop() }

    func start() {
        queue.async { [weak self] in
            guard let self = self, self.timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now(), repeating: self.interval)
            t.setEventHandler { [weak self] in self?.tick(force: false) }
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
    /// `force: true` always publishes, even if the value is unchanged — this
    /// is what re-enables the menu buttons after a failed action that left
    /// the loaded state the same (otherwise the dedupe in `tick` would
    /// swallow the update and the buttons would stay disabled forever).
    func refresh(force: Bool = false) {
        queue.async { [weak self] in self?.tick(force: force) }
    }

    private func tick(force: Bool = false) {
        let loaded = service.isLoaded()
        if !force, lastValue == loaded { return }
        lastValue = loaded
        publishQueue.async { [onUpdate] in
            onUpdate?(loaded)
        }
    }
}
