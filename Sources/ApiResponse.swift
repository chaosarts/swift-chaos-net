//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

/// NOTE (FD): Revisit and consider to turn enum into protocol or seperate responses into different types
public enum ApiResponse: Equatable, Sendable {
    case data(Data, HTTPURLResponse)
    case download(URL, HTTPURLResponse)
    case upload(Data, HTTPURLResponse)

    public var httpURLResponse: HTTPURLResponse {
        switch self {
        case let .data(_, response), let .download(_, response), let .upload(_, response):
            response
        }
    }

    public var data: Data? {
        switch self {
        case let .data(data, _), let .upload(data, _):
            data
        default:
            nil
        }
    }

    public var url: URL? {
        switch self {
        case let .download(url, _):
            url
        default:
            nil
        }
    }

    public func withData(_ data: Data) -> ApiResponse {
        switch self {
        case let .data(_, response):
            .data(data, response)
        case let .upload(_, response):
            .upload(data, response)
        case .download:
            self
        }
    }
}
