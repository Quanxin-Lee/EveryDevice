import Foundation

public struct DeviceInfo: Sendable, Equatable {
    public var modelName: String?
    public var chipName: String?

    public init(modelName: String? = nil, chipName: String? = nil) {
        self.modelName = modelName
        self.chipName = chipName
    }

    public var displayName: String {
        let model = modelName.flatMap { $0.isEmpty ? nil : $0 }
        let chip = chipName.flatMap { $0.isEmpty ? nil : $0 }

        switch (model, chip) {
        case let (model?, chip?):
            return model == chip ? model : L10n.tr("device.displayName", model, chip)
        case let (model?, nil):
            return model
        case let (nil, chip?):
            return chip
        case (nil, nil):
            return "EveryDevice"
        }
    }
}
