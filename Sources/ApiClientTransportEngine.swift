//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public protocol ApiClientTransportEngine: Sendable {
    typealias ProgressAction = @Sendable (Float) -> Void

    var cachePolicy: URLRequest.CachePolicy { get }

    var timeoutInterval: TimeInterval { get }

    /// Provides the http cookie storage used by the transport engine.
    ///
    /// This cookie storage does not necessarily need to be the `.shared` one. We need to expose it in case a component
    /// such as the `ApiClientDelegate` relies on the cookie storage. Using `.shared` hard coded in an implementation
    /// of the delegate may access the wrong values if the engine is using a different storage.
    ///
    /// In addition `.shared` does not specify a QoS class on which it performs. Leading to inversion of quality.
    var httpCookieStorage: HTTPCookieStorage? { get }

    func data(for request: URLRequest) async throws -> ApiResponse

    func download(
        for request: URLRequest,
        onProgress: sending ProgressAction?,
    ) async throws -> ApiResponse

    func upload(
        for request: URLRequest,
        data: Data,
        onProgress: sending ProgressAction?,
    ) async throws -> ApiResponse
}
