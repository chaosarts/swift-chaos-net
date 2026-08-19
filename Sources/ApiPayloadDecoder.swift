//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

public protocol ApiPayloadDecoder: Sendable {
    func decode<D: Decodable>(_ type: D.Type, from data: Data) throws -> D
}

extension JSONDecoder: ApiPayloadDecoder {}
