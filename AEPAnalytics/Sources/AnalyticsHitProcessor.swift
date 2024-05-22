/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPServices
import Foundation

class AnalyticsHitProcessor: HitProcessing {
    private let LOG_TAG = "AnalyticsHitProcessor"

    private let dispatchQueue: DispatchQueue
    private let analyticsState: AnalyticsState
    private let responseHandler: ([String: Any]) -> Void
    private var networkService: Networking {
        return ServiceProvider.shared.networkService
    }
    private let retryInterval = TimeInterval(30)

    #if DEBUG
        var lastHitTimestamp: TimeInterval
    #else
        private var lastHitTimestamp: TimeInterval
    #endif

    /// Creates a new `AnalyticsHitProcessor` where the `responseHandler` will be invoked after each successful processing of a hit
    /// - Parameter responseHandler: a function to be invoked with the `DataEntity` for a hit and the response data for that hit
    init(dispatchQueue: DispatchQueue, state: AnalyticsState, responseHandler: @escaping ([String: Any]) -> Void) {
        self.dispatchQueue = dispatchQueue
        self.analyticsState = state
        self.responseHandler = responseHandler
        self.lastHitTimestamp = 0
    }

    // MARK: HitProcessing
    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return retryInterval
    }

    private func shouldDropHit(timestamp: TimeInterval) -> Bool {
        // If reset Identities was called, do not process the hit queued before reset identities was called.
        if timestamp < self.analyticsState.lastResetIdentitiesTimestamp {
            Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Analytics hit, resetIdentities API was called after this request.")
            return true
        }

        // If offline tracking is disabled, drop hits whose timestamp exceeds the offline disabled wait threshold
        if !self.analyticsState.offlineEnabled &&
            timestamp < (Date().timeIntervalSince1970 - AnalyticsConstants.Default.TIMESTAMP_DISABLED_WAIT_THRESHOLD_SECONDS) {
            Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Analytics hit, timestamp exceeds offline disabled wait threshold")
            return true
        }

        return false
    }

    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let data = entity.data, let analyticsHit = try? JSONDecoder().decode(AnalyticsHit.self, from: data) else {
            // Failed to convert data to hit, unrecoverable error, move to next hit
            completion(true)
            return
        }

        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }

            let eventIdentifier = analyticsHit.eventIdentifier
            var payload = analyticsHit.payload
            var timestamp = analyticsHit.timestamp

            if shouldDropHit(timestamp: timestamp) {
                completion(true)
                return
            }

            // If offline tracking is enabled, adjust timestamp for out of order hits.
            if self.analyticsState.offlineEnabled &&
                (timestamp - self.lastHitTimestamp) < 0 {

                let newTimestamp = self.lastHitTimestamp + 1
                Log.debug(label: self.LOG_TAG, "\(#function) - Adjusting out of order hit timestamp \(analyticsHit.timestamp) -> \(newTimestamp)")

                payload = self.replaceTimestampInPayload(payload: payload, oldTs: timestamp, newTs: newTimestamp)
                timestamp = newTimestamp
            }

            guard let baseUrl = URL.getAnalyticsBaseUrl(state: self.analyticsState) else {
                Log.debug(label: self.LOG_TAG, "\(#function) - Retrying Analytics hit, error generating base url.")
                completion(false)
                return
            }

            guard let url = URL(string: "\(baseUrl.absoluteString)\(Int.random(in: 0...100000000))") else {
                Log.debug(label: self.LOG_TAG, "\(#function) - Retrying Analytics hit, error generating url.")
                completion(false)
                return
            }

            if self.analyticsState.assuranceSessionActive {
                payload += AnalyticsConstants.Request.DEBUG_API_PAYLOAD
            }

            let headers = [NetworkServiceConstants.Headers.CONTENT_TYPE: NetworkServiceConstants.HeaderValues.CONTENT_TYPE_URL_ENCODED]
            let networkRequest = NetworkRequest(url: url,
                                                httpMethod: .post,
                                                connectPayload: payload,
                                                httpHeaders: headers,
                                                connectTimeout: AnalyticsConstants.Default.CONNECTION_TIMEOUT,
                                                readTimeout: AnalyticsConstants.Default.CONNECTION_TIMEOUT)

            self.networkService.connectAsync(networkRequest: networkRequest) { [weak self] connection in
                self?.handleNetworkResponse(url: url,
                                            hit: AnalyticsHit(payload: payload, timestamp: timestamp, eventIdentifier: eventIdentifier),
                                            connection: connection,
                                            completion: completion
                )
            }
        }
    }

    // MARK: Helpers

    /// Handles the network response after a hit has been sent to the server
    /// - Parameters:
    ///   - url: the url of the hit that was sent
    ///   - hit: instance of the `AnalyticsHit` that was sent
    ///   - connection: the connection returned after we make the network request
    ///   - completion: a completion block to invoke after we have handled the network response with true for success and false for failure (retry)
    private func handleNetworkResponse(url: URL, hit: AnalyticsHit, connection: HttpConnection, completion: @escaping (Bool) -> Void) {
        if connection.responseCode == 200 {
            // Hit sent successfully
            Log.debug(label: LOG_TAG, "\(#function) - Analytics hit request with url \(url.absoluteString) and payload \(hit.payload) sent successfully")

            let eventData: [String: Any] = getResponseEventData(url: url, hit: hit, connection: connection)

            dispatchQueue.async { [weak self] in
                guard let self = self else { return }

                // Dispatch response only if the hit was sent after the reset Identities was called.
                // So that we only populate UUID if the hit was sent after reset in case where AAMForwarding is enabled.
                if hit.timestamp > self.analyticsState.lastResetIdentitiesTimestamp {
                    Log.debug(label: self.LOG_TAG, "\(#function) - Dispatching Analytics hit response.")
                    self.responseHandler(eventData)
                }

                self.lastHitTimestamp = hit.timestamp
                completion(true)
            }

        } else if NetworkServiceConstants.RECOVERABLE_ERROR_CODES.contains(connection.responseCode ?? -1) {
            // retry this hit later
            Log.warning(label: LOG_TAG, "\(#function) - Retrying Analytics hit, request with url \(url.absoluteString) failed with error \(connection.error?.localizedDescription ?? "") and recoverable status code \(connection.responseCode ?? -1)")
            completion(false)
        } else {
            // handle network transport error
            if let urlError = connection.error as? URLError, urlError.isRecoverable {
                let errorMsg = "recoverable network error:(\(urlError.localizedDescription)) code:(\(urlError.errorCode))"

                Log.debug(label: LOG_TAG,
                          "\(#function) - Analytics hit failed with \(errorMsg). Will retry in \(retryInterval) seconds.")

                completion(false) // failed, but recoverable so retry
                return
            }

            // handle non-recoverable URLErrors and other non URLErrors
            let errorMsg = "failed with unrecoverable network error:(\(String(describing: connection.error?.localizedDescription))) code:(\(connection.responseCode ?? -1))"

            Log.warning(label: LOG_TAG, "\(#function) - Dropping Analytics hit, request with url \(url.absoluteString) \(errorMsg)")
            completion(true) // don't retry
            return
        }
    }

    /// Create event data for Analytics response event from server
    /// - Parameters:
    ///   - url: the url of the hit that was sent
    ///   - hit: instance of the `AnalyticsHit` that was sent
    ///   - connection: the connection returned after we make the network request
    /// - Returns: a dictionary containing the event data for the response event
    private func getResponseEventData(url: URL, hit: AnalyticsHit, connection: HttpConnection) -> [String: Any] {
        let contentType = connection.responseHttpHeader(forKey: AnalyticsConstants.Assurance.EventDataKeys.CONTENT_TYPE_HEADER)
        let eTag = connection.responseHttpHeader(forKey: AnalyticsConstants.Assurance.EventDataKeys.ETAG_HEADER)
        let serverHeader = connection.responseHttpHeader(forKey: AnalyticsConstants.Assurance.EventDataKeys.SERVER_HEADER)

        let httpHeaders = [
            AnalyticsConstants.EventDataKeys.CONTENT_TYPE_HEADER: contentType,
            AnalyticsConstants.EventDataKeys.ETAG_HEADER: eTag,
            AnalyticsConstants.EventDataKeys.SERVER_HEADER: serverHeader
        ]

        let eventData: [String: Any] = [
            AnalyticsConstants.EventDataKeys.ANALYTICS_SERVER_RESPONSE: (connection.responseString ?? ""),
            AnalyticsConstants.EventDataKeys.HEADERS_RESPONSE: httpHeaders,
            AnalyticsConstants.EventDataKeys.HIT_URL: hit.payload,
            AnalyticsConstants.EventDataKeys.HIT_HOST: url.absoluteString,
            AnalyticsConstants.EventDataKeys.REQUEST_EVENT_IDENTIFIER: hit.eventIdentifier
        ]

        return eventData
    }

    private func replaceTimestampInPayload(payload: String, oldTs: TimeInterval, newTs: TimeInterval) -> String {
        let oldTsString = "&ts=\(Int64(oldTs))"
        let newTsString = "&ts=\(Int64(newTs))"
        return payload.replacingOccurrences(of: oldTsString, with: newTsString)
    }
}
