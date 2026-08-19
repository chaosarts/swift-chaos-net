//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public struct ApiEndpoint: Sendable, RawRepresentable, Hashable, Equatable, ExpressibleByStringLiteral {
    public let rawValue: String

    public var isAbsoluteURL: Bool {
        guard let url = URL(string: rawValue) else { return false }
        return url.scheme != nil
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}
