//
//  Created by Fu Lam Diep on 06.09.24.
//

import Foundation

extension URLQueryItem {
    public var apiParameterName: ApiParameterName {
        ApiParameterName(rawValue: name)
    }
}
