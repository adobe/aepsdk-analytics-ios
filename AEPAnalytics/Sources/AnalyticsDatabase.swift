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

import AEPCore
import AEPServices
import Foundation

/**
 Analytics hit reordering
 If backDateSessionInfo and offlineTracking is enabled, we should send hit with previous session information / crash information before sending any hits for current session. (We get this information from `lifecycle.responseContent` event)
 Lifecycle information for current session should be attached to queued hit or as separate hit (If we have no queued hit) for every lifecycle session. (We get this information from `lifecycle.responseContent` event)
 Referrer information for current install/launch should be attached to queued hit or as separate hit (If we have no queued hit) (We get this information from `acquisition.responseContent` event)

 Given that Lifecycle, Acquisition and MobileServices extensions are optional we rely on timeouts to wait for each of the above events and reorder hits
 Any `genericTrack` request we receive before `genericLifecycle` event is processed and reported to backend. (If lifecycle extension is implemented, we recommend calling MobileCore.lifecycleStart() before any track calls.)
 After receiving `genericLifecycle` event, we wait `AnalyticsConstants.Default.LIFECYCLE_RESPONSE_WAIT_TIMEOUT` for `lifecycle.responseContent` event
 If we receive `lifecycle.responseContent` before timeout, we append lifecycle data to first waiting hit. It is sent as a separate hit if we don't have any waiting hit
 After receiving `lifecycle.responseContent` we wait for `acquisition.responseContent`. If it is install we wait for `analyticsState.launchHitDelay` and for launch we wait for `AnalyticsConstants.Default.LAUNCH_DEEPLINK_DATA_WAIT_TIMEOUT`
 If we receive `acquisition.responseContent` before timeout, we append lifecycle data to first waiting hit. It is sent as a separate hit if we don't have any waiting hit
 Any `genericTrack` request we receive when waiting for `lifecycle.responseContent` or `acquisition.responseContent` is placed in the reorder queue till we receive these events or until timeout
 */

class AnalyticsDatabase {
    enum DataType {
        case referrer
        case lifecycle
    }

    // Override this for tests.
    static var dataQueueService = ServiceProvider.shared.dataQueueService

    private let LOG_TAG = "AnalyticsDatabase"

    private var analyticsState: AnalyticsState
    private var hitQueue: HitQueuing
    private var mainQueue: DataQueue
    private var reorderQueue: DataQueue

    private var waitingForLifecycle: Bool
    private var waitingForReferrer: Bool
    private var additionalData: [String: Any]

    init?(state: AnalyticsState, processor: HitProcessing) {

        guard let reorderDataQueue = AnalyticsDatabase.dataQueueService.getDataQueue(label: AnalyticsConstants.REORDER_QUEUE_NAME) else {
            Log.error(label: self.LOG_TAG, "Failed to create Reorder Queue, Analytics Database could not be initialized")
            return nil
        }

        guard let hitDataQueue = AnalyticsDatabase.dataQueueService.getDataQueue(label: AnalyticsConstants.DATA_QUEUE_NAME) else {
            Log.error(label: self.LOG_TAG, "Failed to create Data Queue, Analytics Database could not be initialized")
            return nil
        }

        self.analyticsState = state
        self.reorderQueue = reorderDataQueue
        self.mainQueue = hitDataQueue
        self.hitQueue = PersistentHitQueue(dataQueue: hitDataQueue, processor: processor)

        self.waitingForLifecycle = false
        self.waitingForReferrer = false
        self.additionalData = [:]

        // On init, we move any hits in reorder queue to main queue. These hits remain in reorder queue if previous app launch crashed or is closed mid processing.
        moveHitsFromReorderQueue()
    }

    func waitForAdditionalData(type: DataType) {
        Log.debug(label: self.LOG_TAG, "waitForAdditionalData - \(type)")
        switch type {
        case .lifecycle:
            waitingForLifecycle = true
        case .referrer:
            waitingForReferrer = true
        }
    }

    func cancelWaitForAdditionalData(type: DataType) {
        Log.debug(label: self.LOG_TAG, "cancelWaitForAdditionalData - \(type)")
        kickWithAdditionalData(type: type, data: nil)
    }

    func kickWithAdditionalData(type: DataType, data: [String: Any]?) {
        guard waitingForAdditionalData else { return }

        Log.debug(label: self.LOG_TAG, "KickWithAdditionalData - \(type) \(String(describing: data))")
        switch type {
        case .lifecycle:
            waitingForLifecycle = false
        case .referrer:
            waitingForReferrer = false
        }

        if let data = data {
            additionalData.merge(data) { _, newValue in
                return newValue
            }
        }

        if !waitingForAdditionalData {
            Log.debug(label: self.LOG_TAG, "KickWithAdditionalData - done waiting for additional data")

            if isHitWaiting(), let firstHit = reorderQueue.peek() {
                if let appendedHit = appendAdditionalData(additionalData: additionalData, dataEntity: firstHit) {
                    mainQueue.add(dataEntity: appendedHit)
                    reorderQueue.remove()
                }
            }
            moveHitsFromReorderQueue()
            additionalData = [:]
        }
        kick(ignoreBatchLimit: false)
    }

    func queue(payload: String, timestamp: TimeInterval, eventIdentifier: String, isBackdateHit: Bool) {
        Log.debug(label: self.LOG_TAG, "queueHit - \(payload) isBackdateHit:\(isBackdateHit)")

        guard let hitData = try? JSONEncoder().encode(AnalyticsHit(payload: payload, timestamp: timestamp, eventIdentifier: eventIdentifier)) else {
            Log.debug(label: self.LOG_TAG, "queueHit - Dropping Analytics hit, failed to encode AnalyticsHit")
            return
        }

        let hit = DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData)

        if isBackdateHit {
            if waitingForAdditionalData {
                Log.debug(label: self.LOG_TAG, "queueHit - Queueing backdated hit")
                mainQueue.add(dataEntity: hit)
            } else {
                Log.debug(label: self.LOG_TAG, "queueHit - Dropping backdate hit, as we have begun processing hits for current session")
            }
        } else {
            if waitingForAdditionalData {
                Log.debug(label: self.LOG_TAG, "queueHit - Queueing hit in reorder queue as we are waiting for additional data")
                reorderQueue.add(dataEntity: hit)
            } else {
                Log.debug(label: self.LOG_TAG, "queueHit - Queueing hit in main queue")
                mainQueue.add(dataEntity: hit)
            }
        }

        kick(ignoreBatchLimit: false)
    }

    func isHitWaiting() -> Bool {
        return reorderQueue.count() > 0
    }

    func getQueueSize() -> Int {
        return mainQueue.count() + reorderQueue.count()
    }

    func reset() {
        hitQueue.suspend()
        mainQueue.clear()
        reorderQueue.clear()
        additionalData = [:]
        waitingForReferrer = false
        waitingForLifecycle = false
    }

    private func appendAdditionalData(additionalData: [String: Any], dataEntity: DataEntity) -> DataEntity? {
        guard let data = dataEntity.data, let analyticsHit = try? JSONDecoder().decode(AnalyticsHit.self, from: data) else {
            Log.debug(label: self.LOG_TAG, "appendAdditionalData - Dropping Analytics hit, failed to decode AnalyticsHit")
            return nil
        }

        let payload = URL.appendContextDataToAnalyticsPayload(contextData: additionalData as? [String: String], payload: analyticsHit.payload)
        guard let hitData = try? JSONEncoder().encode(AnalyticsHit(payload: payload, timestamp: analyticsHit.timestamp, eventIdentifier: analyticsHit.eventIdentifier)) else {
            Log.debug(label: self.LOG_TAG, "appendAdditionalData - Dropping Analytics hit, failed to encode AnalyticsHit")
            return nil
        }

        return DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData)
    }

    private func moveHitsFromReorderQueue() {
        let n = reorderQueue.count()
        guard n > 0 else {
            Log.trace(label: self.LOG_TAG, "moveHitsFromReorderQueue - No hits in reorder queue")
            return
        }

        Log.trace(label: self.LOG_TAG, "moveHitsFromReorderQueue - Moving queued hits \(n) from reorder queue -> main queue")

        if let hits = reorderQueue.peek(n: n) {
            for hit in hits {
                mainQueue.add(dataEntity: hit)
            }
        }

        reorderQueue.clear()
    }

    func kick(ignoreBatchLimit: Bool) {
        Log.trace(label: self.LOG_TAG, "Kick - ignoreBatchLimit \(ignoreBatchLimit).")

        // If we have not received analytics configuration, no reason to start BG process
        if !analyticsState.isAnalyticsConfigured() {
            Log.trace(label: self.LOG_TAG, "Kick - Failed to kick database hits (Analytics is not configured).")
            return
        }

        // If privacy is not opt in, no reason to start BG process
        if !analyticsState.isOptIn() {
            Log.trace(label: self.LOG_TAG, "Kick - Failed to kick database hits (Privacy status is not opted-in).")
            return
        }

        // If offline tracking is not enabled or if we're over the batch limit, bring it online
        let count = mainQueue.count()
        let overBatchLimit = !analyticsState.offlineEnabled ||  count > analyticsState.batchLimit
        if overBatchLimit || ignoreBatchLimit {
            Log.trace(label: self.LOG_TAG, "Kick - Begin processing database hits")
            hitQueue.beginProcessing()
        }
    }

    private var waitingForAdditionalData: Bool {
        get {
            return waitingForReferrer || waitingForLifecycle
        }
    }
}
