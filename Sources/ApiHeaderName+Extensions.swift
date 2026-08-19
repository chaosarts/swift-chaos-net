//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

extension ApiHeaderName {
    // MARK: Conventional Header Names

    public static var authorization: ApiHeaderName {
        "Authorization"
    }

    public static var contentType: ApiHeaderName {
        "Content-Type"
    }

    public static var acceptEncoding: ApiHeaderName {
        "Accept-Encoding"
    }

    public static var acceptLanguage: ApiHeaderName {
        "Accept-Language"
    }

    public static var userAgent: ApiHeaderName {
        "User-Agent"
    }

    public static var cookie: ApiHeaderName {
        "Cookie"
    }

    // MARK: AB Test Headers Names

    public static var abTest: ApiHeaderName {
        "x-ab-test"
    }

    public static var abTestIk: ApiHeaderName {
        "x-ab-testik"
    }

    public static var abRegister: ApiHeaderName {
        "x-ab-register"
    }

    public static var abWinner: ApiHeaderName {
        "x-ab-winner"
    }

    // MARK: AppTag related header names

    public static var appTag: ApiHeaderName {
        "app-tag"
    }

    public static var appTimeZone: ApiHeaderName {
        "app-time-zone"
    }

    public static var appTime: ApiHeaderName {
        "app-time"
    }

    public static var appNonce: ApiHeaderName {
        "app-nonce"
    }

    // MARK: Misc Header Names

    public static var osVersion: ApiHeaderName {
        "OSVersion"
    }

    public static var density: ApiHeaderName {
        "Density"
    }

    public static var doNotTrack: ApiHeaderName {
        "DNT"
    }

    public static var appType: ApiHeaderName {
        "AppType"
    }

    public static var appVersion: ApiHeaderName {
        "AppVersion"
    }

    public static var appFeatures: ApiHeaderName {
        "app-features"
    }

    public static var shippingCountry: ApiHeaderName {
        "shippingCountry"
    }

    public static var appearance: ApiHeaderName {
        "appearance"
    }
}
