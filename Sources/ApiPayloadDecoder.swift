//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

public protocol ApiPayloadDecoder: Sendable {
    func decode<D: Decodable>(_ type: D.Type, from data: Data) throws -> D
}

extension JSONDecoder: ApiPayloadDecoder {}
