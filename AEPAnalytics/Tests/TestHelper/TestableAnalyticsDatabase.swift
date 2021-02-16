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
@testable import AEPIdentity
@testable import AEPAnalytics
import Foundation

class TestableAnalyticsDatabase: AnalyticsDatabase {
    var queuedHits: [String] = []
    var isWaiting = false

    override func queue(state: AnalyticsState, url: String, timestamp: TimeInterval, eventIdentifier: String, isBackdateHit: Bool) {
        queuedHits.append(url)
    }

    override func setWaiting(wait: Bool) {
        isWaiting = wait
    }

    override func isHitWaiting() -> Bool {
        return isWaiting
    }

    override func kickWithAddtionalData(data: [String: Any]?) {}

    override func forceKickHits() {}

    override func getQueueSize() -> Int {
        return queuedHits.count
    }

    override func reset() {
        queuedHits.removeAll()
    }
}
