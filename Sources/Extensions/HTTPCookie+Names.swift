//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

extension HTTPCookie {
    public struct Name: RawRepresentable, Equatable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }

        public static var chronosessid: Self {
            "chronosessid"
        }

        public static var c24UserSession: Self {
            "c24-user-session"
        }
    }
}
