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

@testable import AEPCore
@testable import AEPServices
@testable import AEPAnalytics
import XCTest
import Foundation

@available(tvOSApplicationExtension, unavailable)
class AnalyticsMigratorTests: XCTestCase {

    var analytics:Analytics!
    var dataStore:NamedCollectionDataStore!

    private var mockDataStore: MockDataStore {
        return ServiceProvider.shared.namedKeyValueService as! MockDataStore
    }

    private var userDefaults: UserDefaults {
        if let appGroup = ServiceProvider.shared.namedKeyValueService.getAppGroup(), !appGroup.isEmpty {
            return UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
        }

        return UserDefaults.standard
    }

    override func setUp() {
        UserDefaults.clear()

        ServiceProvider.shared.namedKeyValueService = MockDataStore()        
        dataStore = NamedCollectionDataStore(name: AnalyticsConstants.DATASTORE_NAME)
    }

    func testAnalyticsMigrationNoData() {
        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertFalse(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.AID))
        XCTAssertFalse(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.VID))
    }

    func testAnalyticsMigrationFromV4() {
        // Migrate
        userDefaults.set("aid", forKey: AnalyticsConstants.V4Migration.AID)
        userDefaults.set(true, forKey: AnalyticsConstants.V4Migration.IGNORE_AID)
        userDefaults.set("vid", forKey: AnalyticsConstants.V4Migration.VID)

        // Delete
        userDefaults.set(true, forKey: AnalyticsConstants.V4Migration.AID_SYNCED)
        userDefaults.set(100000, forKey: AnalyticsConstants.V4Migration.LAST_TIMESTAMP)
        userDefaults.set("1", forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_ID)
        userDefaults.set(100000, forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_STAMP)

        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertEqual("aid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID))

        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.IGNORE_AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.VID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.AID_SYNCED))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.LAST_TIMESTAMP))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_ID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V4Migration.CURRENT_HIT_STAMP))
    }

    func testAnalyticsMigrationFromV5() {
        // Migrate
        userDefaults.set("aid", forKey: AnalyticsConstants.V5Migration.AID)        
        userDefaults.set(true, forKey: AnalyticsConstants.V5Migration.IGNORE_AID)
        userDefaults.set("vid", forKey: AnalyticsConstants.V5Migration.VID)

        // Delete
        userDefaults.set(100000, forKey: AnalyticsConstants.V5Migration.MOST_RECENT_HIT_TIMESTAMP)

        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertEqual("aid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID))

        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.IGNORE_AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.VID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.MOST_RECENT_HIT_TIMESTAMP))
    }

    func testVIDMigrationFromIdentity() {
        // Migrate
        userDefaults.set("vid", forKey: AnalyticsConstants.V5Migration.IDENTITY_VID)

        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID))

        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.IDENTITY_VID))
    }

    func testVIDMigrationFromIdentityIfAnalyticsVIDPresent() {
        // Migrate
        userDefaults.set("vid", forKey: AnalyticsConstants.V5Migration.VID)
        userDefaults.set("ivid", forKey: AnalyticsConstants.V5Migration.IDENTITY_VID)

        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID))

        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.VID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.IDENTITY_VID))
    }

    func testAnalyticsMigrationFromV5InAppGroup() {
        mockDataStore.setAppGroup("test-app-group")

        // Migrate
        userDefaults.set("aid", forKey: AnalyticsConstants.V5Migration.AID)
        userDefaults.set(true, forKey: AnalyticsConstants.V5Migration.IGNORE_AID)
        userDefaults.set("vid", forKey: AnalyticsConstants.V5Migration.VID)

        // Delete
        userDefaults.set(100000, forKey: AnalyticsConstants.V5Migration.MOST_RECENT_HIT_TIMESTAMP)

        AnalyticsMigrator.migrateLocalStorage(dataStore: dataStore)

        XCTAssertTrue(dataStore.contains(key: AnalyticsConstants.DataStoreKeys.DATA_MIGRATED))
        XCTAssertEqual("aid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.AID))
        XCTAssertEqual("vid", dataStore.getString(key: AnalyticsConstants.DataStoreKeys.VID))

        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.IGNORE_AID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.VID))
        XCTAssertNil(userDefaults.object(forKey: AnalyticsConstants.V5Migration.MOST_RECENT_HIT_TIMESTAMP))        
    }
}
