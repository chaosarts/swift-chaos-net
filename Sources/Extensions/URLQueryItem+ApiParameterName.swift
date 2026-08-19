//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation

extension URLQueryItem {
    public var apiParameterName: ApiParameterName {
        ApiParameterName(rawValue: name)
    }
}
