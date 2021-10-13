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
class AnalyticsProperties {
    static let CHARSET = "UTF-8"

    private var dataStore: NamedCollectionDataStore

    /// Analytics AID (legacy)
    private var aid: String?

    /// Analytics VID (legacy)
    private var vid: String?

    /// Timestamp of the last hit
    private var mostRecentHitTimeStampInSeconds: TimeInterval = 0

    /// Timestamp String contains timezone offset. All other fields in timestamp except timezone offset are set to 0.
    var timezoneOffset: String {
        return TimeZone.current.getOffsetFromGmtInMinutes()
    }

    init(dataStore: NamedCollectionDataStore) {
        self.dataStore = dataStore
        self.mostRecentHitTimeStampInSeconds = dataStore.getDouble(key: AnalyticsConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP) ?? 0
        self.aid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID)
        self.vid = dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID)
    }

    func setMostRecentHitTimestamp(timestampInSeconds: TimeInterval) {
        if mostRecentHitTimeStampInSeconds.isLess(than: timestampInSeconds) {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP, value: timestampInSeconds)
            mostRecentHitTimeStampInSeconds = timestampInSeconds
        }
    }

    func getMostRecentHitTimestamp() -> TimeInterval {
        return mostRecentHitTimeStampInSeconds
    }

    /// Sets the value of the `aid` in the `AnalyticsProperties` instance.
    /// The new value is persisted in the datastore.
    /// - Parameter:
    ///   - status: The value for the new `aid`.
    func setAnalyticsIdentifier(aid: String?) {
        if (aid ?? "").isEmpty {
            dataStore.remove(key: AnalyticsConstants.DataStoreKeys.AID)
        } else {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.AID, value: aid)
        }

        self.aid = aid
    }

    /// Returns the `aid` from the `AnalyticsProperties` instance.
    /// This method attempts to find one from the DataStore first before returning the variable present in `AnalyticsProperties`.
    /// - Returns: A string containing the `aid`.
    func getAnalyticsIdentifier() -> String? {
        return aid
    }

    /// Sets the value of the `vid` in the `AnalyticsProperties` instance.
    /// The new value is persisted in the datastore.
    /// - Parameter:
    ///   - status: The value for the new `vid`.
    func setVisitorIdentifier(vid: String?) {
        if (vid ?? "").isEmpty {
            dataStore.remove(key: AnalyticsConstants.DataStoreKeys.VID)
        } else {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.VID, value: vid)
        }

        self.vid = vid
    }

    /// Returns the `vid` from the `AnalyticsProperties` instance.
    /// This method attempts to find one from the DataStore first before returning the variable present in `AnalyticsProperties`.
    /// - Returns: A string containing the `vid`.
    func getVisitorIdentifier() -> String? {
        return vid
    }

    /// Clears or resets to default values any saved identifiers or properties present in the `AnalyticsProperties` instance.
    func reset() {
        mostRecentHitTimeStampInSeconds = 0
        vid = nil
        aid = nil
        // Clear datastore
        dataStore.remove(key: AnalyticsConstants.DataStoreKeys.AID)
        dataStore.remove(key: AnalyticsConstants.DataStoreKeys.VID)
        dataStore.remove(key: AnalyticsConstants.DataStoreKeys.MOST_RECENT_HIT_TIMESTAMP)
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
