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

import Foundation
import AEPCore
import AEPServices

/// Represents a type which contains instances variables for the Analytics extension.
struct AnalyticsProperties {
    static let CHARSET = "UTF-8"

    /// Current locale of the user
    var locale: Locale?

    /// Analytics AID (legacy)
    private var aid: String?

    /// Analytics VID (legacy)
    private var vid: String?

    /// Time in seconds when previous lifecycle session was paused.
    var lifecyclePreviousSessionPauseTimestamp: Date?

    var lifecyclePreviousPauseEventTimestamp: Date?

    /// Timestamp String contains timezone offset. All other fields in timestamp except timezone offset are set to 0.
    var timezoneOffset: String {
        return TimeZone.current.getOffsetFromGmtInMinutes()
    }

    /// Indicates if referrer timer is running.
    var referrerTimerRunning = false

    /// Indicates if lifecycle timer is running.
    var lifecycleTimerRunning = false

    /// The `DispatchQueue` use to process events in FIFO order and wait for Lifecycle and Acquisition response events.
    var dispatchQueue: DispatchQueue = DispatchQueue(label: AnalyticsConstants.FRIENDLY_NAME)

    /// Instance of `AnalyticsRequestSerializer` used for creating track request.
    var analyticsRequestSerializer = AnalyticsRequestSerializer()

    lazy var dataStore: NamedCollectionDataStore = {
        return NamedCollectionDataStore(name: AnalyticsConstants.DATASTORE_NAME)
    }()

    private var mostRecentHitTimeStampInSeconds: TimeInterval = 0

    mutating func getMostRecentHitTimestamp() -> TimeInterval {
        if mostRecentHitTimeStampInSeconds <= 0 {
            mostRecentHitTimeStampInSeconds = dataStore.getDouble(key: AnalyticsConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP_SECONDS) ?? 0
        }
        return mostRecentHitTimeStampInSeconds
    }

    mutating func setMostRecentHitTimestamp(timestampInSeconds: TimeInterval) {
        let mostRecentHitTimeStampInSeconds = getMostRecentHitTimestamp()
        if mostRecentHitTimeStampInSeconds.isLess(than: timestampInSeconds) {
            self.mostRecentHitTimeStampInSeconds = timestampInSeconds
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP_SECONDS, value: timestampInSeconds)
        }
    }

    /// `DispatchWorkItem` use to wait for `acquisition` data before executing task.
    var referrerDispatchWorkItem: DispatchWorkItem?

    /// `DispatchWorkItem` use to wait for `lifecycle` data before executing task.
    var lifecycleDispatchWorkItem: DispatchWorkItem?

    /// Indicates if an analytics id request should be ignored.
    private var ignoreAid = false

    /// Sets the value of the `ignoreAid` status in the `AnalyticsProperties` instance.
    /// The new value is persisted in the datastore.
    /// - Parameter:
    ///   - status: The value for the new `ignoreAid` status.
    mutating func setIgnoreAidStatus(status: Bool) {
        dataStore.set(key: AnalyticsConstants.DataStoreKeys.AID_IGNORE_KEY, value: status)
        self.ignoreAid = status
    }

    /// Returns the `ignoreAid` status from the `AnalyticsProperties` instance.
    /// This method attempts to find one from the DataStore first before returning the variable present in `AnalyticsProperties`.
    /// - Returns: A bool containing the `ignoreAid` status.
    mutating func getIgnoreAidStatus() -> Bool {
        // check data store to see if we can return a visitor identifier from persistence
        if let retrievedStatus = dataStore.getBool(key: AnalyticsConstants.DataStoreKeys.AID_IGNORE_KEY, fallback: nil), retrievedStatus {
            return retrievedStatus
        }
        return self.ignoreAid
    }

    /// Cancels the referrer timer. Sets referrerTimerRunning flag to false. Sets referrerTimer to nil.
    mutating func cancelReferrerTimer() {

        referrerTimerRunning = false
        referrerDispatchWorkItem?.cancel()
        referrerDispatchWorkItem = nil
    }

    /// Cancels the lifecycle timer. Sets lifecycleTimerRunning flag to false. Sets lifecycleTimer to nil.
    mutating func cancelLifecycleTimer() {

        lifecycleTimerRunning = false
        lifecycleDispatchWorkItem?.cancel()
        lifecycleDispatchWorkItem = nil
    }

    /// Verifies if the referrer or lifecycle timer are running.
    /// - Returns `True` if either of the timer is running.
    func isDatabaseWaiting() -> Bool {
        return (!(referrerDispatchWorkItem?.isCancelled ?? true) && referrerTimerRunning) || (!(lifecycleDispatchWorkItem?.isCancelled ?? true) && lifecycleTimerRunning)
    }

    /// Sets the value of the `aid` in the `AnalyticsProperties` instance.
    /// The new value is persisted in the datastore.
    /// - Parameter:
    ///   - status: The value for the new `aid`.
    mutating func setAnalyticsIdentifier(aid: String?) {
        if aid == nil {
            dataStore.remove(key: AnalyticsConstants.DataStoreKeys.AID_KEY)
            setIgnoreAidStatus(status: false)
        } else {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.AID_KEY, value: aid)
            setIgnoreAidStatus(status: true)
        }

        self.aid = aid
    }

    /// Returns the `aid` from the `AnalyticsProperties` instance.
    /// This method attempts to find one from the DataStore first before returning the variable present in `AnalyticsProperties`.
    /// - Returns: A string containing the `aid`.
    mutating func getAnalyticsIdentifier() -> String? {
        if self.aid == nil {
            // check data store to see if we can return a visitor identifier from persistence
            self.aid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID_KEY)
        }
        return self.aid
    }

    /// Sets the value of the `vid` in the `AnalyticsProperties` instance.
    /// The new value is persisted in the datastore.
    /// - Parameter:
    ///   - status: The value for the new `vid`.
    mutating func setAnalyticsVisitorIdentifier(vid: String?) {
        if vid == nil {
            dataStore.remove(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY)
        } else {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY, value: vid)
        }

        self.vid = vid
    }

    /// Returns the `vid` from the `AnalyticsProperties` instance.
    /// This method attempts to find one from the DataStore first before returning the variable present in `AnalyticsProperties`.
    /// - Returns: A string containing the `vid`.
    mutating func getVisitorIdentifier() -> String? {
        if self.vid == nil {
            // check data store to see if we can return a visitor identifier from persistence
            self.vid = (dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VISITOR_IDENTIFIER_KEY))
        }
        return self.vid
    }
}

extension TimeZone {

    /// Creates timestamp string, with all fields set as 0 except timezone offset.
    /// All fields other than timezone offset are set to 0 because backend only process timezone offset from this value.
    /// - Return: `String` Time stamp with all fields except timezone offset set to 0.
    func getOffsetFromGmtInMinutes() -> String {

        let gmtOffsetInMinutes = (secondsFromGMT() / 60) * -1
        return "00/00/0000 00:00:00 0 \(gmtOffsetInMinutes)"
    }
}
