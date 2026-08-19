//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public struct FormDataSerializer: Sendable {
    public init() {}

    public func queryData(_ value: some Encodable, options: Options = .none) throws -> Data? {
        try queryData(jsonObject(object: value), options: options)
    }

    public func queryString(_ value: some Encodable, options: Options = .none) throws -> String? {
        try queryString(jsonObject(object: value), options: options)
    }

    public func queryItems(_ value: some Encodable, options: Options = .none) throws -> [URLQueryItem] {
        try queryItems(jsonObject(object: value), options: options)
    }

    public func queryData(_ value: Any, options: Options = .none) -> Data? {
        queryString(value, options: options)?.data(using: .utf8)
    }

    public func queryString(_ value: Any, options: Options = .none) -> String? {
        var components = URLComponents()
        components.queryItems = queryItems(value, options: options)
        return components.query
    }

    public func queryItems(_ value: Any, options: Options = .none) -> [URLQueryItem] {
        if let dictionary = value as? [String: Any] {
            dictionary.flatMap { key, value in
                queryItems(value, forKey: key, options: options)
            }
        } else {
            []
        }
    }

    public func queryData(_ value: Any?, forKey key: String, options: Options = .none) -> Data? {
        queryString(value, forKey: key, options: options)?.data(using: .utf8)
    }

    public func queryString(_ value: Any?, forKey key: String, options: Options = .none) -> String? {
        var components = URLComponents()
        components.queryItems = queryItems(value, forKey: key, options: options)
        return components.query
    }

    public func queryItems(_ value: Any?, forKey key: String, options: Options) -> [URLQueryItem] {
        switch value {
        case let dictionary as [String: Any?]:
            return dictionary.flatMap { nestedKey, nestedValue in
                queryItems(nestedValue, forKey: "\(key)[\(nestedKey)]", options: options)
            }
        case let array as [Any?]:
            return array.flatMap { nestedValue in
                if options.contains(.arrayBrackets) {
                    queryItems(nestedValue, forKey: "\(key)[]", options: options)
                } else {
                    queryItems(nestedValue, forKey: key, options: options)
                }
            }
        case let string as String:
            return [URLQueryItem(name: key, value: string)]
        case let number as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                let value = options.contains(.numericBool) ? "\(number)" : number.boolValue.description
                return [URLQueryItem(name: key, value: value)]
            } else {
                return [URLQueryItem(name: key, value: "\(number)")]
            }
        case .none:
            return [URLQueryItem(name: key, value: nil)]
        default:
            return []
        }
    }

    private func jsonObject(object: some Encodable, options: JSONSerialization.ReadingOptions = []) throws -> Any {
        let data = try JSONEncoder().encode(object)
        return try JSONSerialization.jsonObject(with: data, options: options)
    }

    public struct Options: OptionSet, Sendable, ExpressibleByIntegerLiteral {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public init(integerLiteral value: IntegerLiteralType) {
            self.init(rawValue: value)
        }

        public static let none: Self = .init(rawValue: 0)
        public static let arrayBrackets: Self = .init(rawValue: 1 << 0)
        public static let numericBool: Self = .init(rawValue: 1 << 1)
    }
}
