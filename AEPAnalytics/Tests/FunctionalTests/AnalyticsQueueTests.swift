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

import XCTest
import AEPServices
@testable import AEPAnalytics
@testable import AEPCore

class AnalyticsQueueTests : AnalyticsFunctionalTestBase {
    
    override func setUp() {        
        super.setupBase()
    }
    
    func dispatchForceHitProcessing() {
        let data  = [AnalyticsConstants.EventDataKeys.FORCE_KICK_HITS: true]
        let event = Event(name: "ForceKickHits", type: EventType.analytics, source: EventSource.requestContent, data: data)
        mockRuntime.simulateComingEvent(event: event)
    }
    
    func dispatchClearQueue() {
        let data  = [AnalyticsConstants.EventDataKeys.CLEAR_HITS_QUEUE: true]
        let event = Event(name: "ForceKickHits", type: EventType.analytics, source: EventSource.requestContent, data: data)
        mockRuntime.simulateComingEvent(event: event)
    }
    
    //The queue size should return correct value when waiting for lifecycle
    func testQueueSize() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 5
        ])
        
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)
        let event2 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event2)
        
        dispatchGetQueueSize()
        waitFor(interval: 0.5)
        verifyQueueSize(size: 2)
        
        // Dispatch lifecycle start
        let lifecycleEvent = Event(name: "Lifecycle start", type: EventType.genericLifecycle, source: EventSource.requestContent, data: nil)
        mockRuntime.simulateComingEvent(event: lifecycleEvent)
        
        // This event goes to reorder queue waiting for lifeycle response
        let event3 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event3)
        
        dispatchGetQueueSize()
        waitFor(interval: 0.5)
        verifyQueueSize(size: 3)
    }
    
    // Hits should be sent irrespective of queue size when forceSendHits is called
    func testForceHitProcessing() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 5
        ])
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)
        let event2 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event2)

        mockNetworkService?.reset()
        
        dispatchForceHitProcessing()
        waitFor(interval: 0.5)
        
        // Should force send both requests
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
    }
    
    //Queue should be cleared when clearHits is called
    func testClearHits() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 5
        ])
        
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)

        dispatchClearQueue()
        dispatchGetQueueSize()
        waitFor(interval: 0.5)
        
        verifyQueueSize(size: 0)
    }
    
    //Hits should be sent when batch limit is exceeded
    func testHitsSentOverBatchLimit() {
        dispatchDefaultConfigAndIdentityStates(configData: [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 2
        ])
        
        let trackData: [String: Any] = [
            CoreConstants.Keys.ACTION : "testActionName"
        ]
        let event1 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event1)
                
        let event2 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event2)
        
        waitFor(interval: 0.5)
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
        
        let event3 = Event(name: "Generic track event", type: EventType.genericTrack, source: EventSource.requestContent, data: trackData)
        mockRuntime.simulateComingEvent(event: event3)
        
        waitFor(interval: 0.5)
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 3)
    }
}
