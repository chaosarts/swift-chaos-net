//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

extension HTTPURLResponse {
    public var status: Status {
        switch statusCode {
        case 100 ..< 200:
            .information
        case 200 ..< 300:
            .success
        case 300 ..< 400:
            .redirection
        case 400 ..< 500:
            .clientError
        case 500 ..< 600:
            .serverError
        default:
            .unknown
        }
    }

    public var statusDescription: String {
        "\(statusCode) \(Self.localizedString(forStatusCode: statusCode))"
    }

    public enum Status {
        case information
        case success
        case redirection
        case clientError
        case serverError
        case unknown
    }
}
