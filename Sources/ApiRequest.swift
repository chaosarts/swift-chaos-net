//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public struct ApiRequest: Sendable, Equatable {
    private static let headerValuesSeparator: String = ","
    public var action: ApiAction
    public var endpoint: ApiEndpoint
    public var parameters: [URLQueryItem]
    public var rawHeaders: [String: [String]]
    public var payload: Data?
    public var cachePolicy: URLRequest.CachePolicy?
    public var timeoutInterval: TimeInterval?

    var redirectCount: Int = 0

    var retryCount: Int = 0

    public var headers: [String: String] {
        get { rawHeaders.mapValues(Self.headerValueString) }
        set { rawHeaders = newValue.mapValues(Self.headerValues) }
    }

    public init(
        action: ApiAction = .get,
        endpoint: ApiEndpoint,
        parameters: [URLQueryItem] = [],
        rawHeaders: [String: [String]] = [:],
        payload: Data? = nil,
        cachePolicy: URLRequest.CachePolicy? = nil,
        timeoutInterval: TimeInterval? = nil,
    ) {
        self.action = action
        self.endpoint = endpoint
        self.parameters = parameters
        self.rawHeaders = rawHeaders
        self.payload = payload
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }

    // MARK: Primitive modification

    public consuming func action(_ action: ApiAction) -> ApiRequest {
        self.action = action
        return self
    }

    public consuming func endpoint(_ endpoint: ApiEndpoint) -> ApiRequest {
        self.endpoint = endpoint
        return self
    }

    public consuming func cachePolicy(_ cachePolicy: URLRequest.CachePolicy?) -> ApiRequest {
        self.cachePolicy = cachePolicy
        return self
    }

    public consuming func timeoutInterval(_ timeoutInterval: TimeInterval?) -> ApiRequest {
        self.timeoutInterval = timeoutInterval
        return self
    }

    consuming func redirect(to url: URL) -> ApiRequest {
        redirectCount += 1
        return endpoint(ApiEndpoint(rawValue: url.absoluteString))
    }

    consuming func retry() -> ApiRequest {
        retryCount += 1
        return self
    }

    // MARK: Parameter modification

    public consuming func parameters(_ parameters: [URLQueryItem], merge: Bool = true) -> ApiRequest {
        if merge {
            self.parameters.append(contentsOf: parameters)
        } else {
            self.parameters = parameters
        }
        return self
    }

    public consuming func parameters(_ parameters: URLQueryItem..., merge _: Bool = true) -> ApiRequest {
        self.parameters(parameters)
    }

    public consuming func parameter(
        _ name: some StringProtocol,
        value: (some StringProtocol)? = nil as String?,
        merge: Bool = true,
    ) -> ApiRequest {
        parameters([URLQueryItem(name: String(name), value: value.map { String($0) })], merge: merge)
    }

    public consuming func parameter(
        _ name: ApiParameterName,
        value: (some StringProtocol)? = nil as String?,
        merge: Bool = true,
    ) -> ApiRequest {
        parameter(name.rawValue, value: value, merge: merge)
    }

    // MARK: Header modification

    public consuming func header<C: Collection>(
        _ name: some StringProtocol,
        values: C,
        merge: ([String], [String]) -> [String],
    ) -> ApiRequest where C.Element: StringProtocol {
        let key = transformedHeaderKey(name)
        let values = values.flatMap { Self.headerValues(from: $0) }

        if let existing = rawHeaders[key] {
            rawHeaders[key] = merge(existing, values)
        } else {
            rawHeaders[key] = values
        }
        return self
    }

    public consuming func header<C: Collection>(
        _ name: some StringProtocol,
        values: C,
        strategy: MergeStrategy = .override,
    ) -> ApiRequest where C.Element: StringProtocol {
        header(name, values: values) { lhs, rhs in
            switch strategy {
            case .override:
                rhs
            case .ignore:
                lhs
            case .merge:
                lhs + rhs
            }
        }
    }

    public consuming func header(
        _ name: some StringProtocol,
        value: some StringProtocol,
        strategy: MergeStrategy = .override,
    ) -> ApiRequest {
        header(name, values: [value], strategy: strategy)
    }

    public consuming func headers<C: Collection>(
        _ headers: [some StringProtocol: C],
        strategy: MergeStrategy = .override,
    ) -> ApiRequest where C.Element: StringProtocol {
        // NOTE(FD): Need to use reduce here and always returning self as partial results due to consuming functions.
        // Compiler will complain when consuming function header(_:value:) is called within classic for-loop, which
        // invalidates self after the first call.
        headers.reduce(self) { partialResult, element in
            partialResult.header(element.key, values: element.value, strategy: strategy)
        }
    }

    public consuming func headers(
        _ headers: [some StringProtocol: some StringProtocol],
        strategy: MergeStrategy = .override,
    ) -> ApiRequest {
        headers.reduce(self) { partialResult, element in
            partialResult.header(String(element.key), value: element.value, strategy: strategy)
        }
    }

    public consuming func header<C: Collection>(
        _ name: ApiHeaderName,
        values: C,
        merge: ([String], [String]) -> [String],
    ) -> ApiRequest where C.Element: StringProtocol {
        header(name.rawValue, values: values, merge: merge)
    }

    public consuming func header<C: Collection>(
        _ name: ApiHeaderName,
        values: C,
        strategy: MergeStrategy = .override,
    ) -> ApiRequest where C.Element: StringProtocol {
        header(name.rawValue, values: values, strategy: strategy)
    }

    public consuming func header(
        _ name: ApiHeaderName,
        value: some StringProtocol,
        strategy: MergeStrategy = .override,
    ) -> ApiRequest {
        header(name.rawValue, values: [value], strategy: strategy)
    }

    public consuming func headers<C: Collection>(
        _ headers: [ApiHeaderName: C],
        strategy: MergeStrategy = .override,
    ) -> ApiRequest where C.Element: StringProtocol {
        // NOTE(FD): Need to use reduce here and always returning self as partial results due to consuming functions.
        // Compiler will complain when consuming function header(_:value:) is called within classic for-loop, which
        // invalidates self after the first call.
        headers.reduce(self) { partialResult, element in
            partialResult.header(element.key.rawValue, values: element.value, strategy: strategy)
        }
    }

    public consuming func headers(
        _ headers: [ApiHeaderName: some StringProtocol],
        strategy: MergeStrategy = .override,
    ) -> ApiRequest {
        headers.reduce(self) { partialResult, element in
            partialResult.header(element.key.rawValue, value: element.value, strategy: strategy)
        }
    }

    // MARK: Payload modification

    public consuming func payload(_ payload: Data?, contentType: String?) -> ApiRequest {
        self.payload = payload
        headers[ApiHeaderName.contentType.rawValue] = contentType
        return self
    }

    public consuming func payload<Payload>(
        _ payload: Payload?,
        encodedBy encode: (Payload) throws -> (Data, contentType: String),
    ) rethrows -> ApiRequest {
        let result = if let payload {
            try encode(payload)
        } else {
            nil as (data: Data, contentType: String)?
        }

        return self.payload(result?.data, contentType: result?.contentType)
    }

    public consuming func payload(_ payload: (some Encodable)?, encoder: ApiPayloadEncoder) throws -> ApiRequest {
        try self.payload(payload) { payload in
            try (encoder.encode(payload), encoder.mimeType)
        }
    }

    // MARK: Convenient Header Manipulation

    public static func headerValues(from value: some StringProtocol) -> [String] {
        value.description.split(separator: headerValuesSeparator).compactMap { value in
            let value = value.trimmingCharacters(in: .whitespaces)
            return if value.isEmpty {
                nil
            } else {
                value
            }
        }
    }

    public static func headerValueString(for values: [String]) -> String {
        values.joined(separator: headerValuesSeparator)
    }

    public func transformedHeaderKey(_ key: some StringProtocol) -> String {
        let key = String(key)
        return rawHeaders.keys.first { $0.lowercased() == key.lowercased() } ?? key
    }

    public enum MergeStrategy: Sendable {
        case override
        case ignore
        case merge
    }
}
