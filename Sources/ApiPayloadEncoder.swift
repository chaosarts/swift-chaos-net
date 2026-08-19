//
//  Created by Fu Lam Diep on 06.09.24.
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
