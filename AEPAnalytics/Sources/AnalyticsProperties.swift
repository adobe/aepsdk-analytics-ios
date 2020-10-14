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

/// Represents a type which contains instances variables for the Analytics extension.
struct AnalyticsProperties {
    
    /// Current locale of the user
    var locale: Locale?
    
    /// Analytics AID (legacy)
    var aid: String?
    
    /// Analytics VID (legacy)
    var vid: String?
    
    /// Time in seconds when previous lifecycle session was paused.
    var lifecyclePreviousSessionPauseTimestamp: Date?
    
    
     /// Timestamp String contains timezone offset. All other fields in timestamp except timezone offset are set to 0.
    var timezoneOffset: String {
        return TimeZone.current.getOffsetFromGmtInMinutes()
    }
    
    /// Indicates if referrer timer is running.
    var referrerTimerRunning = false
    
    /// Indicates if lifecycle timer is running.
    var lifecycleTimerRunning = false
    
    /// Timer use to wait for acquisition data before executing task.
    var referrerTimer: Timer?
    
    /// Timer use to wait for lifecycle data before executing task.
    var lifecycleTimer: Timer?
                        
    /// Cancels the referrer timer. Sets referrerTimerRunning flag to false. Sets referrerTimer to nil.
    mutating func cancelReferrerTimer() {
                
        referrerTimerRunning = false
        if let timer = referrerTimer {
            timer.invalidate()
            referrerTimer = nil
        }
    }
    
    /// Cancels the lifecycle timer. Sets lifecycleTimerRunning flag to false. Sets lifecycleTimer to nil.
    mutating func cancelLifecycleTimer() {
        
        lifecycleTimerRunning = false
        if let timer = lifecycleTimer {
            timer.invalidate()
            lifecycleTimer = nil
        }
    }
    
    /// Verifies if the referrer or lifecycle timer are running.
    /// - Returns `True` if either of the timer is running.
    func isDatabaseWaiting() -> Bool {
        return (referrerTimer != nil && referrerTimerRunning) || (lifecycleTimer != nil && lifecycleTimerRunning)
    }
}

extension TimeZone {

    /// Creates timestamp string, with all fields set as 0 except timezone offset.
    /// All fields other than timezone offset are set to 0 because backend only process timezone offset from this value.
    /// - Return: `String` Time stamp with all fields except timezone offset set to 0.
    internal func getOffsetFromGmtInMinutes() -> String {
                                 
        let gmtOffsetInMinutes = (secondsFromGMT() / 60) * -1
        return "00/00/0000 00:00:00 0 \(gmtOffsetInMinutes)"
    }
}
