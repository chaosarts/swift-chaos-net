//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

/// A middleware layer between an API definition and the transport layer of the
/// application.
///
/// `ApiClient` handles concerns that belong to neither the transport engine nor the API definition itself:
/// - Building a `URLRequest` from an ``ApiRequest`` and a base URL.
/// - Running the request through the transport engine.
/// - Driving a delegate-based lifecycle that covers response validation, retry, and redirect logic.
/// - Decoding response data into the caller's expected type.
///
/// ## Why `final class`
///
/// `ApiClient` is a reference type so that it can be shared across API definitions and injected as a dependency
/// without copying configuration state. It is `final` because subclassing is not a supported extension point — use
/// ``ApiClientDelegate`` and ``ApiClientTransportEngine`` to customize behavior instead.
///
/// ## Sendability
///
/// The class conforms to `Sendable`. All stored properties (`delegate`, `transportEngine`, `configuration`) are
/// immutable (`let`) and their types conform to `Sendable`, so thread safety is guaranteed by construction.
public final class ApiClient: Sendable {
    // swiftlint:disable:next weak_delegate
    /// The delegate that handles business-level decisions the client itself is not responsible for.
    ///
    /// The delegate decides whether to accept, reject, or redirect a response and whether a failed request should be
    /// retried. It can also inject additional parameters and headers before a request is sent. See
    /// ``ApiClientDelegate`` for the full set of hooks.
    public let delegate: ApiClientDelegate?

    /// The object that performs the actual network request.
    ///
    /// The transport engine abstracts the underlying networking implementation (e.g. `URLSession`).
    private let transportEngine: ApiClientTransportEngine

    private let configuration: Configuration

    /// The default decoder used to decode response data.
    ///
    /// Individual requests can supply their own decoder via the `decoder` parameter.
    public var decoder: ApiPayloadDecoder {
        configuration.decoder
    }

    /// The default encoder used to encode request payloads.
    ///
    /// Individual requests can supply their own encoder via ``ApiRequest/withPayload(_:encoder:)``.
    public var encoder: ApiPayloadEncoder {
        configuration.encoder
    }

    /// The maximum number of retries the client will attempt before throwing
    /// ``ApiClientError/maxRetryCountExceeded(_:_:)``.
    ///
    /// Acts as a safety net in case the delegate keeps returning ``ApiErrorPolicy/retry``.
    public var maxRetryCount: Int {
        configuration.maxRetryCount
    }

    /// The maximum number of redirects the client will follow before throwing
    /// ``ApiClientError/maxRedirectCountExceeded(_:_:)``.
    public var maxRedirectCount: Int {
        configuration.maxRedirectCount
    }

    /// The default cache policy forwarded from the transport engine's configuration.
    public var cachePolicy: URLRequest.CachePolicy {
        transportEngine.cachePolicy
    }

    /// The default request timeout forwarded from the transport engine's configuration.
    public var timeoutInterval: TimeInterval {
        transportEngine.timeoutInterval
    }

    public var httpCookieStorage: HTTPCookieStorage? {
        transportEngine.httpCookieStorage
    }

    public init(
        delegate: ApiClientDelegate? = nil,
        transportEngine: ApiClientTransportEngine,
        configuration: Configuration = .default,
    ) {
        self.delegate = delegate
        self.transportEngine = transportEngine
        self.configuration = configuration
    }

    // MARK: Request Methods

    /// Sends a request through the full delegate lifecycle and decodes the response with a custom closure.
    ///
    /// - Parameters:
    ///   - type: The expected result type (used only for generic inference).
    ///   - request: The API request to send.
    ///   - baseURL: An optional base URL that overrides ``baseURL``.
    ///   - decode: A closure that transforms the raw ``ApiResponse`` into `D`.
    /// - Returns: The decoded value of type `D`.
    @discardableResult
    public func data<D>(
        _: D.Type,
        fromRequest request: ApiRequest,
        relativeTo baseURL: URL? = nil,
        decodedBy decode: @escaping (ApiResponse) throws -> D,
    ) async throws -> D {
        let apiResponse = try await withLifecycle(request: request, relativeTo: baseURL) { urlRequest in
            try await transportEngine.data(for: urlRequest)
        }

        do {
            return try decode(apiResponse)
        } catch let error as ApiClientError {
            throw error
        } catch {
            throw ApiClientError.decodingError(error)
        }
    }

    public func data(fromRequest apiRequest: ApiRequest, relativeTo _: URL? = nil) async throws {
        try await data(Void.self, fromRequest: apiRequest) { _ in }
    }

    /// Sends a request through the full delegate lifecycle and decodes the response using an ``ApiPayloadDecoder``.
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode from the response body.
    ///   - request: The API request to send.
    ///   - baseURL: An optional base URL that overrides ``baseURL``.
    ///   - decoder: An optional decoder that overrides ``decoder``.
    /// - Returns: The decoded value of type `D`.
    public func data<D: Decodable>(
        _ type: D.Type = D.self,
        fromRequest request: ApiRequest,
        relativeTo baseURL: URL? = nil,
        decoder: ApiPayloadDecoder? = nil,
    ) async throws -> D {
        try await data(type, fromRequest: request, relativeTo: baseURL) { apiResponse in
            guard let data = apiResponse.data else {
                throw ApiClientError.unknown(nil)
            }

            let decoder = decoder ?? self.decoder
            return try decoder.decode(type, from: data)
        }
    }

    /// Encodes a value using the client's default ``encoder``.
    public func encode(_ value: Encodable) throws -> Data {
        try encoder.encode(value)
    }

    // MARK: Lifecycle Methods

    /// Drives the full request lifecycle: preparation, sending, response validation, retry, and redirect handling.
    ///
    /// The lifecycle steps are:
    /// 1. Resolve the base URL and enrich the request with delegate-provided parameters and headers.
    /// 2. Notify the delegate that the request is about to be sent.
    /// 3. Build a `URLRequest` and execute it via `action`.
    /// 4. Ask the delegate for a response policy (accept / reject / redirect).
    /// 5. On **accept**: let the delegate post-process the response, then return it.
    /// 6. On **redirect**: build a new request for the redirect target and recurse.
    /// 7. On **reject**: ask the delegate for an error policy (retry / fail). On retry, increment the retry counter,
    ///    notify the delegate, and recurse. On fail, notify the delegate and throw.
    // swiftlint:disable:next function_body_length
    private func withLifecycle(
        request: ApiRequest,
        relativeTo baseURL: URL?,
        perform action: (URLRequest) async throws -> ApiResponse,
    ) async throws(ApiClientError) -> ApiResponse {
        let baseURL = baseURL ?? delegate?.baseURL(self)
        var modifiedRequest = modifiedApiRequest(for: request, relativeTo: baseURL)
        await delegate?.apiClient(self, willSendRequest: modifiedRequest, relativeTo: baseURL)
        let urlRequest = try urlRequest(for: modifiedRequest, relativeTo: baseURL)

        // Sending Request

        var response: ApiResponse
        do {
            response = try await action(urlRequest)
        } catch let error as ApiClientError {
            throw error
        } catch {
            throw ApiClientError.transportEngineError(error)
        }

        // Response Processing

        let policyForResponse = delegate?.apiClient(
            self,
            policyForResponse: response,
            request: modifiedRequest,
            relativeTo: baseURL,
        ) ?? .accept

        switch policyForResponse {
        case .accept:
            response = await delegate?.apiClient(
                self,
                didReceiveResponse: response,
                for: modifiedRequest,
                relativeTo: baseURL,
            ) ?? response
            return response
        case let .redirect(to: url):
            let newRequest = request.redirect(to: url)
            guard newRequest.redirectCount <= maxRedirectCount else {
                throw ApiClientError.maxRedirectCountExceeded("Too many redirects", newRequest.redirectCount)
            }
            return try await withLifecycle(request: newRequest, relativeTo: baseURL, perform: action)
        case let .reject(reason):
            let reason = reason as? ApiClientError ?? ApiClientError.policyRejection(reason)
            let policyForResponseWithError = delegate?.apiClient(
                self,
                policyForResponse: response,
                withError: reason,
                request: modifiedRequest,
                relativeTo: baseURL,
            ) ?? .fail

            switch policyForResponseWithError {
            case .retry:
                modifiedRequest = modifiedRequest.retry()
                guard modifiedRequest.retryCount <= maxRetryCount else {
                    let error = ApiClientError.maxRetryCountExceeded(reason, maxRetryCount)
                    delegate?.apiClient(
                        self,
                        didReceiveResponse: response,
                        withError: error,
                        for: modifiedRequest,
                        relativeTo: baseURL,
                    )
                    throw error
                }
                await delegate?.apiClient(
                    self,
                    willRetry: modifiedRequest,
                    relativeTo: baseURL,
                    for: response,
                    withError: reason,
                )
                return try await withLifecycle(request: modifiedRequest, relativeTo: baseURL, perform: action)
            case .fail:
                delegate?.apiClient(
                    self,
                    didReceiveResponse: response,
                    withError: reason,
                    for: modifiedRequest,
                    relativeTo: baseURL,
                )
                throw reason
            }
        }
    }

    // MARK: Request Preparation

    /// Returns a copy of `request` enriched with delegate-provided parameters and headers.
    private func modifiedApiRequest(for request: ApiRequest, relativeTo baseURL: URL?) -> ApiRequest {
        var modifiedRequest = request
        modifiedRequest.parameters.append(
            contentsOf: delegate?.apiClient(
                self,
                additionalParametersForRequest: modifiedRequest,
                relativeTo: baseURL,
            ) ?? [],
        )
        modifiedRequest.headers.merge(
            delegate?.apiClient(
                self,
                additionalHeadersForRequest: modifiedRequest,
                relativeTo: baseURL,
            ) ?? [:],
        ) { $1 }
        return modifiedRequest
    }

    /// Transforms the given ``ApiRequest`` into an actual ``URLRequest`` relative to the given `baseURL`.
    ///
    /// This function does not inject any additional data to the resulting `URLRequest` object, but it purely transforms
    /// the api request object as is.
    public func urlRequest(for request: ApiRequest, relativeTo baseURL: URL?) throws(ApiClientError) -> URLRequest {
        guard var url = url(for: request, relativeTo: baseURL) else {
            throw ApiClientError.badUsage(URLError(.badURL))
        }

        if !request.parameters.isEmpty {
            url.append(queryItems: request.parameters)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.action.rawValue

        if !request.headers.isEmpty {
            urlRequest.allHTTPHeaderFields = request.headers
        }

        urlRequest.cachePolicy = request.cachePolicy ?? cachePolicy
        urlRequest.timeoutInterval = request.timeoutInterval ?? timeoutInterval
        urlRequest.httpBody = request.payload
        return urlRequest
    }

    public func url(for request: ApiRequest, relativeTo baseURL: URL?) -> URL? {
        URL(string: request.endpoint.rawValue, relativeTo: baseURL)
    }

    /// Encapsulates the client's codec and retry/redirect limits.
    public struct Configuration: Sendable {
        public var decoder: ApiPayloadDecoder
        public var encoder: ApiPayloadEncoder
        public var maxRetryCount: Int
        public var maxRedirectCount: Int

        public init(
            decoder: ApiPayloadDecoder = JSONDecoder(),
            encoder: ApiPayloadEncoder = JSONEncoder(),
            maxRetryCount: Int = 1,
            maxRedirectCount: Int = 10,
        ) {
            self.decoder = decoder
            self.encoder = encoder
            self.maxRetryCount = maxRetryCount
            self.maxRedirectCount = maxRedirectCount
        }

        public static var `default`: Self {
            .init()
        }
    }
}
