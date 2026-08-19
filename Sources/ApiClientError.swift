//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

public enum ApiClientError: LocalizedError {
    /// An error, indicating a bad usage of the api client.
    ///
    /// This error is thrown, when transforming the ``ApiRequest`` to an ``URLRequest`` fails. This only happens, when
    /// the endpoint contains characters, that cannot be transformed to an ``URL``.
    case badUsage(Error)
    /// An error, indicating an error in the transport engine.
    ///
    /// This error is thrown, when any request method (`data`, `download` and `upload`) of the transport engine fails
    /// for some reason.
    case transportEngineError(Error)
    /// An error, that indicates, that the server response is considered a client error (normally 4xx status codes).
    ///
    /// Use this error if you want to represent 4xx responses.
    case clientError(Error)

    /// An error, that indicates, that the server response is considered a server error (normally 5xx status codes).
    ///
    /// Use this error if you want to represent 5xx responses.
    case serverError(Error)

    case unknown(Error?)

    /// An error indicating errors during decoding.
    case decodingError(Error)

    /// Indicates that the client has rejected the response and the reason is not an ``ApiClientError``
    case policyRejection(Error)

    /// Indicates that the maximum amount of redirects has been exceeded
    case maxRedirectCountExceeded(String, Int)

    /// Indicates that the maximum amount of retries has been exceeded
    case maxRetryCountExceeded(Error, Int)

    public var errorDescription: String? {
        if let underlyingError {
            underlyingError.localizedDescription
        } else if case let .maxRedirectCountExceeded(string, _) = self {
            string
        } else {
            nil
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .badUsage(error),
             let .transportEngineError(error),
             let .clientError(error),
             let .serverError(error),
             let .decodingError(error),
             let .policyRejection(error),
             let .maxRetryCountExceeded(error, _):
            error
        case let .unknown(error):
            error
        case .maxRedirectCountExceeded:
            URLError(.httpTooManyRedirects)
        }
    }
}
