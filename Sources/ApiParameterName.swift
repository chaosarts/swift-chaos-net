//
//  Created by Fu Lam Diep on 06.09.24.
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
