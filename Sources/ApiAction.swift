//
//  Created by Fu Lam Diep on 06.09.24.
//

/// Enumerates the available action for an api call.
///
/// Ultimately this is being transformed to http method of the resulting url request.
public enum ApiAction: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
}
