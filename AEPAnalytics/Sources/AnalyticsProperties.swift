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

/// Represents a type which contains instances variables for the Analytics extension
struct AnalyticsProperties {
    
    var locale: String?
    
    /// Analytics AID (legacy)
    var aid: String?
    
    /// Analytics VID (legacy)
    var vid: String?
    
    var lifecyclePreviousSessionPauseTimestamp: Date?
    
    /**
      Refers to a timestamp String contains timezone offset. All other fields in timestamp except timezone offset are 0.
     */
    lazy var timezoneOffset = TimeZone.current.getOffsetFromGmtInMinutes()
    
    var referrerTimerRunning = false
    
    var lifecycleTimerRunning = false
    
    var referrerTimer: Timer?
                    
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
    
    /// Return true If either referrer timer or lifecycle timer is running else return false.
    func isDatabaseWaiting() -> Bool {
        return (referrerTimer != nil && referrerTimerRunning) || (lifecycleTimer != nil && lifecycleTimerRunning)
    }
}

extension TimeZone {

    /**
     Returns all 0 timestamp string except for the timezoneOffset
     backend platform only processes timezone offset from this string.
     */
    internal func getOffsetFromGmtInMinutes() -> String {
                                 
        let gmtOffsetInMinutes = (secondsFromGMT() / 60) * -1
        return "00/00/0000 00:00:00 0 \(gmtOffsetInMinutes)"
    }
}
