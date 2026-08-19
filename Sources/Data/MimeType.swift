//
//  MimeType.swift
//  Chaos
//
//  Created by Fu Lam Diep on 14.08.26.
//

public struct MimeType: CustomStringConvertible {
    public let type: String
    public let subtype: String

    public var description: String {
        "\(type)/\(subtype)"
    }

    public static func text(_ subtype: String) -> Self {
        MimeType(type: "text", subtype: subtype)
    }
}
