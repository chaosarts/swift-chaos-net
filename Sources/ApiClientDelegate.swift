//
//  Created by Fu Lam Diep on 06.09.24.
//
import Foundation

public protocol ApiClientDelegate: AnyObject, Sendable {
    // MARK: Pre Request Hooks

    /// Asks the delegate for a base url to use to resolve a request url.
    func baseURL(_ client: ApiClient) -> URL?

    /// Asks the delegate for additional parameters to add to the `ApiRequest` object.
    ///
    /// Return an array of url query items that you want to add to the request. It's the developers responsiblity to
    /// check for duplicates, if not desired.
    func apiClient(
        _ client: ApiClient,
        additionalParametersForRequest request: ApiRequest,
        relativeTo baseURL: URL?,
    ) -> [URLQueryItem]

    /// Asks the delegate for additional headers to add to the `ApiRequest` object.
    ///
    /// Returns a dictionary, where values and keys are strings. Note that keys are case sensetive, but the resulting
    /// headers for the `URLRequest` objects are normalized (e.g. "content-type" → "Content-Type") and it is unknown
    /// which value `URLSession` takes. So if you want to have a header being overwritten make sure to set the exact
    /// same key.
    func apiClient(
        _ client: ApiClient,
        additionalHeadersForRequest request: ApiRequest,
        relativeTo baseURL: URL?,
    ) -> [String: String]

    /// Tells the delegate that the client is about to send the given request.
    ///
    /// The method is async. Hence you may perform asynchrounous actions before returning (e.g. send another request
    /// in advance of the actual request).
    func apiClient(_ client: ApiClient, willSendRequest request: ApiRequest, relativeTo baseURL: URL?) async

    // MARK: Post Request Hooks

    /// Asks the delegate how to handle the response (`.allow`, `.reject`). Depending on the response the client
    /// will continue with the response process or initiates the error handling process.
    ///
    /// This will be called on any response received by the server, regardless of the content or http status code. When
    /// rejecting a response, you need to specify a reason (`Error`). If you want to express an error for 4xx http
    /// status you should specify ``.clientError`` from ``ApiClientError``. You do the same with ``.serverError``
    /// respectivly.
    func apiClient(
        _ client: ApiClient,
        policyForResponse response: ApiResponse,
        request: ApiRequest,
        relativeTo baseURL: URL?,
    ) -> ApiResponsePolicy

    /// Tells the delegate that the client has received an allowed response from the server.
    ///
    /// This method is called, when the client receives a response from the server and allowed it in
    /// ``apiClient(_:policyForResponse:request:)-3ak24``. You can perform asynchronous actions in this method, if
    /// necessary.
    func apiClient(
        _ client: ApiClient,
        didReceiveResponse response: ApiResponse,
        for request: ApiRequest,
        relativeTo baseURL: URL?,
    ) async -> ApiResponse

    /// Asks the delegate how to handle the error that occured after receiving the server response.
    ///
    /// This method is called, when the client receives a response from the server but rejected it in
    /// ``apiClient(_:policyForResponse:request:)-3ak24``.
    func apiClient(
        _ client: ApiClient,
        policyForResponse response: ApiResponse,
        withError error: ApiClientError,
        request: ApiRequest,
        relativeTo baseURL: URL?,
    ) -> ApiErrorPolicy

    /// Tells the delegate that the client is about to perform a retry for the rejected response.
    ///
    /// This method is called when ``apiClient(_:policyForResponse:withError:for:)-91qcm`` returns ``.retry``. You can
    /// perform asycnhronous actions in this method before returning.
    func apiClient(
        _ client: ApiClient,
        willRetry request: ApiRequest,
        relativeTo baseURL: URL?,
        for response: ApiResponse,
        withError error: ApiClientError,
    ) async

    /// Tells the delegate that the client received a server response, that has been rejected and
    /// ``apiClient(_:policyForResponse:withError:for:)-91qcm`` returned `.fail.`
    func apiClient(
        _ client: ApiClient,
        didReceiveResponse response: ApiResponse,
        withError error: ApiClientError,
        for request: ApiRequest,
        relativeTo baseURL: URL?,
    )
}

extension ApiClientDelegate {
    public func apiClient(
        _: ApiClient,
        additionalParametersForRequest _: ApiRequest,
        relativeTo _: URL?,
    ) -> [URLQueryItem] {
        []
    }

    public func apiClient(
        _: ApiClient,
        additionalHeadersForRequest _: ApiRequest,
        relativeTo _: URL?,
    ) -> [String: String] {
        [:]
    }

    public func apiClient(
        _: ApiClient,
        willSendRequest _: ApiRequest,
        relativeTo _: URL?,
    ) async {}

    public func apiClient(
        _: ApiClient,
        policyForResponse _: ApiResponse,
        request _: ApiRequest,
        relativeTo _: URL?,
    ) -> ApiResponsePolicy {
        .accept
    }

    public func apiClient(
        _: ApiClient,
        didReceiveResponse response: ApiResponse,
        for _: ApiRequest,
        relativeTo _: URL?,
    ) async -> ApiResponse {
        response
    }

    public func apiClient(
        _: ApiClient,
        policyForResponse _: ApiResponse,
        withError _: ApiClientError,
        request _: ApiRequest,
        relativeTo _: URL?,
    ) -> ApiErrorPolicy {
        .fail
    }

    public func apiClient(
        _: ApiClient,
        willRetry _: ApiRequest,
        relativeTo _: URL?,
        for _: ApiResponse,
        withError _: ApiClientError,
    ) async {}

    public func apiClient(
        _: ApiClient,
        didReceiveResponse _: ApiResponse,
        withError _: ApiClientError,
        for _: ApiRequest,
        relativeTo _: URL?,
    ) {}
}
