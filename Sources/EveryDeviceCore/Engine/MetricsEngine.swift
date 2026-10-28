import Foundation

public final class MetricsEngine {
    public var onUpdate: ((MetricsUpdate) -> Void)?

    private let queue = DispatchQueue(label: "com.everydevice.xxx.engine", qos: .utility)
    private let collector = SnapshotCollector()
    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval = 1

    public init() {}

    public func start(interval: TimeInterval = 1) {
        queue.async { [weak self] in
            guard let self else { return }
            self.interval = interval
            self.startTimer()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.stopTimer()
        }
    }

    public func setInterval(_ interval: TimeInterval) {
        queue.async { [weak self] in
            guard let self, interval > 0, self.interval != interval else { return }
            self.interval = interval
            guard self.timer != nil else { return }
            self.stopTimer()
            self.startTimer()
        }
    }

    public func resetBaselines() {
        queue.async { [weak self] in
            self?.collector.resetBaselines()
        }
    }

    public func setDemand(_ demand: SamplingDemand) {
        queue.async { [weak self] in
            self?.collector.demand = demand
        }
    }

    private func startTimer() {
        stopTimer()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let update = self.collector.collect()
            DispatchQueue.main.async {
                self.onUpdate?(update)
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
