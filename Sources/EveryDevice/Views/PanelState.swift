import Combine

final class PanelState: ObservableObject {
    @Published var processSort: ProcessSort = .cpu
}
