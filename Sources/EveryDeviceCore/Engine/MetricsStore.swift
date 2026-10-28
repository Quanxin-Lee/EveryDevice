import Combine
import Foundation

public final class MetricsStore: ObservableObject {
    @Published public private(set) var snapshot = MetricsSnapshot()
    public private(set) var history = MetricHistory()

    public init() {}

    public func apply(_ update: MetricsUpdate) {
        if !update.isWarmup {
            history.append(update.snapshot, fresh: update.fresh)
        }
        snapshot = update.snapshot
    }

    public func resetChartData() {
        history.reset()
        objectWillChange.send()
    }
}
