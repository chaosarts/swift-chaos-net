//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public protocol ApiPayloadEncoder: Sendable {
    var mimeType: String { get }
    func encode(_ value: some Encodable) throws -> Data
}

extension JSONEncoder: ApiPayloadEncoder {
    public var mimeType: String {
        "application/json"
    }
}
