/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import AEPServices

class AnalyticsMigrator {
    private static let LOG_TAG = "AnalyticsMigrator"

    private static var userDefaults: UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    /// Migrate analytics data from v4 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted analytics data
    private static func migrateFromV4(dataStore: NamedCollectionDataStore) {
        Log.trace(label: LOG_TAG, "Migration started for Analytics data from v4")

        let userDefaults = self.userDefaults

        if let aid = userDefaults.string(forKey: AnalyticsConstants.V4Migration.AID) {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.AID, value: aid)
        }
        if let vid = userDefaults.string(forKey: AnalyticsConstants.V4Migration.VID) {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.VID, value: vid)
        }

        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.AID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.IGNORE_AID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.AID_SYNCED)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.VID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.LAST_TIMESTAMP)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_ID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_STAMP)

        Log.trace(label: LOG_TAG, "Migration successful for Analytics data from v4")
    }

    /// Migrate analytics data from v5 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted analytics data
    private static func migrateFromV5(dataStore: NamedCollectionDataStore) {
        Log.trace(label: LOG_TAG, "Migration started for Analytics data from v5")

        let userDefaults = self.userDefaults

        if let aid = userDefaults.string(forKey: AnalyticsConstants.V5Migration.AID) {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.AID, value: aid)
        }
        if let vid = userDefaults.string(forKey: AnalyticsConstants.V5Migration.VID) {
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.VID, value: vid)
        }

        userDefaults.removeObject(forKey: AnalyticsConstants.V5Migration.AID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V5Migration.IGNORE_AID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V5Migration.VID)
        userDefaults.removeObject(forKey: AnalyticsConstants.V5Migration.MOST_RECENT_HIT_TIMESTAMP)

        Log.trace(label: LOG_TAG, "Migration successful for Analytics data from v5")

        if let identityVid = userDefaults.string(forKey: AnalyticsConstants.V5Migration.IDENTITY_VID), !identityVid.isEmpty {
            Log.trace(label: LOG_TAG, "Migration started for visitor identifier from Identity to Analytics.")

            // Don't override vid if already read from analytics extension
            if !dataStore.contains(key: AnalyticsConstants.DataStoreKeys.VID) {
                dataStore.set(key: AnalyticsConstants.DataStoreKeys.VID, value: identityVid)
            }

            userDefaults.removeObject(forKey: AnalyticsConstants.V5Migration.IDENTITY_VID)
            Log.trace(label: LOG_TAG, "Migration successful for visitor identifier from Identity to Analytics.")
        }
    }

    /// Migrate analytics data from v4 & v5 local storage
    /// - Parameters:
    ///   - dataStore: DataStore to store persisted analytics data
    static func migrateLocalStorage(dataStore: NamedCollectionDataStore) {
        if !dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED) {
            migrateFromV4(dataStore: dataStore)
            migrateFromV5(dataStore: dataStore)
            dataStore.set(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED, value: true)
        }
    }
}
