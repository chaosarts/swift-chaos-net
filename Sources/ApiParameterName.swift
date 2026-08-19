//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

public struct ApiParameterName: RawRepresentable, Sendable, ExpressibleByStringLiteral, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}
