//
//  Copyright © 2025 Chrono24 GmbH. All rights reserved.
//

import Foundation
import os

/// A `URLSession`-based implementation of ``ApiClientTransportEngine`` that supports
/// data requests, file downloads, and uploads with progress reporting.
///
/// ## Why `final class` instead of `actor`
///
/// An `actor` serializes all calls through its executor, meaning concurrent requests
/// (e.g. multiple ``data(for:)`` calls) would queue up and execute one at a time.
/// This transport engine must allow fully concurrent in-flight requests — the underlying
/// `URLSession` already handles its own thread safety, so actor serialization would only
/// add unnecessary bottlenecks.
///
/// ## `SessionDelegate`
///
/// `URLSession` delegate callbacks (progress reporting, redirect handling, task completion)
/// are delivered on the session's internal serial queue. A nested ``SessionDelegate`` owns
/// these delegate conformances and the mutable `progressActions` dictionary that maps each
/// task to its progress closure.
///
/// A dedicated delegate object also solves a chicken-and-egg problem: `URLSession` requires
/// its delegate at init time, but the transport engine cannot pass `self` as the delegate
/// before its own `init` has completed. By creating `SessionDelegate` first, we can hand it
/// to `URLSession(configuration:delegate:delegateQueue:)` and then store both the session
/// and the delegate as fully initialized properties.
///
/// Keeping this state in a dedicated object separates delegate concerns from the transport
/// engine's public API and makes thread-safety easier to reason about — all mutable state
/// is guarded by a single `OSAllocatedUnfairLock` inside the delegate.
///
/// HTTP redirects are intentionally suppressed by the delegate (returning `nil` from
/// `willPerformHTTPRedirection`) because redirect handling is performed at a higher level
/// by the ``ApiClientDelegate``.
public final class URLSessionTransportEngine: NSObject, ApiClientTransportEngine {
    private let urlSession: URLSession

    // swiftlint:disable:next weak_delegate
    /// A dedicated delegate for the url session.
    ///
    /// This is not the delegate of the transport engine but of the url session. The transport engine owns the delegate
    /// to increase the retain count, since delegate in general are referenced weaked in the composited component
    /// ( `URLSession`). The transport engine itself cannot be the delegate of the `URLSession`, since the delegate
    /// neeeds to be specified at creation time. At the same time the url session needs to be created at creation time
    /// of the engine.
    private let sessionDelegate: SessionDelegate

    public var configuration: URLSessionConfiguration {
        urlSession.configuration
    }

    public var cachePolicy: URLRequest.CachePolicy {
        configuration.requestCachePolicy
    }

    public var timeoutInterval: TimeInterval {
        configuration.timeoutIntervalForRequest
    }

    public var httpCookieStorage: HTTPCookieStorage? {
        configuration.httpCookieStorage
    }

    public init(configuration: URLSessionConfiguration = .default) {
        let sessionDelegate = SessionDelegate()
        urlSession = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
        self.sessionDelegate = sessionDelegate
    }

    public func data(for request: URLRequest) async throws -> ApiResponse {
        let result = try await withCheckedThrowingContinuation { continuation in
            urlSession.dataTask(with: request) { data, response, error in
                resume(data, response: response, error: error, with: continuation)
            }.resume()
        }
        return .data(result.0, result.1)
    }

    public func download(
        for request: URLRequest,
        onProgress: ProgressAction?,
    ) async throws -> ApiResponse {
        var taskIdentifier: Int?
        defer {
            if let taskIdentifier {
                sessionDelegate.setProgressAction(nil, forTaskWithIdentifier: taskIdentifier)
            }
        }

        let result = try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.downloadTask(with: request) { data, response, error in
                resume(data, response: response, error: error, with: continuation)
            }
            taskIdentifier = task.taskIdentifier

            sessionDelegate.setProgressAction(onProgress, forTaskWithIdentifier: task.taskIdentifier)

            task.delegate = sessionDelegate
            task.resume()
        }
        return .download(result.0, result.1)
    }

    public func upload(
        for request: URLRequest,
        data: Data,
        onProgress: ProgressAction?,
    ) async throws -> ApiResponse {
        var taskIdentifier: Int?
        defer {
            if let taskIdentifier {
                sessionDelegate.setProgressAction(nil, forTaskWithIdentifier: taskIdentifier)
            }
        }

        let result = try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.uploadTask(with: request, from: data) { data, response, error in
                resume(data, response: response, error: error, with: continuation)
            }
            taskIdentifier = task.taskIdentifier

            sessionDelegate.setProgressAction(onProgress, forTaskWithIdentifier: task.taskIdentifier)

            task.delegate = sessionDelegate
            task.resume()
        }
        return .upload(result.0, result.1)
    }

    deinit {
        urlSession.invalidateAndCancel()
    }

    /// Handles `URLSession` delegate callbacks for redirect suppression, progress reporting,
    /// and task-lifetime cleanup.
    ///
    /// Progress closures are stored in a dictionary keyed by `URLSessionTask.taskIdentifier`,
    /// protected by an `OSAllocatedUnfairLock` to guard against structural races from concurrent
    /// dictionary mutations across different tasks. The lock provides priority inheritance, so a
    /// high-QoS caller (e.g. `MainActor`) cannot be blocked by a lower-QoS delegate thread.
    final class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
        private let progressActions = OSAllocatedUnfairLock<[Int: ProgressAction]>(initialState: [:])

        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest _: URLRequest,
        ) async -> URLRequest? {
            nil
        }

        func urlSession(
            _: URLSession,
            task: URLSessionTask,
            didCompleteWithError _: (any Error)?,
        ) {
            setProgressAction(nil, forTaskWithIdentifier: task.taskIdentifier)
        }

        func urlSession(
            _: URLSession,
            task: URLSessionTask,
            didSendBodyData _: Int64,
            totalBytesSent: Int64,
            totalBytesExpectedToSend: Int64,
        ) {
            sendProgress(
                Float(totalBytesSent) / Float(totalBytesExpectedToSend),
                forTaskWithIdentifier: task.taskIdentifier,
            )
        }

        func urlSession(
            _: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo _: URL,
        ) {
            sendProgress(1, forTaskWithIdentifier: downloadTask.taskIdentifier)
        }

        func urlSession(
            _: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData _: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64,
        ) {
            sendProgress(
                Float(totalBytesWritten) / Float(totalBytesExpectedToWrite),
                forTaskWithIdentifier: downloadTask.taskIdentifier,
            )
        }

        fileprivate func setProgressAction(_ action: ProgressAction?, forTaskWithIdentifier taskIdentifier: Int) {
            progressActions.withLock { actions in
                if let action {
                    actions[taskIdentifier] = action
                } else {
                    actions.removeValue(forKey: taskIdentifier)
                }
            }
        }

        fileprivate func sendProgress(_ progress: Float, forTaskWithIdentifier taskIdentifier: Int) {
            let action = progressActions.withLock { $0[taskIdentifier] }
            action?(progress)
        }
    }
}

extension ApiClientTransportEngine where Self == URLSessionTransportEngine {
    public static func urlSession(_ configuration: URLSessionConfiguration = .default) -> Self {
        URLSessionTransportEngine(configuration: configuration)
    }

    public static var urlSession: Self {
        urlSession()
    }
}

private func resume<Payload: Sendable>(
    _ payload: Payload?,
    response: URLResponse?,
    error: Error?,
    with continuation: CheckedContinuation<(Payload, HTTPURLResponse), Error>,
) {
    if let error {
        continuation.resume(throwing: error)
        return
    }

    guard let payload, let response = response as? HTTPURLResponse else {
        continuation.resume(throwing: URLError(.badServerResponse))
        return
    }
    continuation.resume(returning: (payload, response))
}
