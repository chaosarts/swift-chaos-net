//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

public enum ApiResponsePolicy: Equatable, Sendable {
    case accept
    // swiftlint:disable:next identifier_name
    case redirect(to: URL)
    case reject(reason: Error)

    public static func == (lhs: ApiResponsePolicy, rhs: ApiResponsePolicy) -> Bool {
        switch (lhs, rhs) {
        case (.accept, .accept), (.redirect, .redirect), (.reject, .reject):
            true
        default:
            false
        }
    }
}
