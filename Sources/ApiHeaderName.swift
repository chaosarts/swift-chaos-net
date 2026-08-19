//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

public struct ApiHeaderName: RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}
