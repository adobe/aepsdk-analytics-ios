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

class AnalyticsTimer {

    private let LOG_TAG = "AnalyticsTimer"

    /// `DispatchWorkItem` use to wait for `acquisition` data before executing task.
    private var referrerDispatchWorkItem: DispatchWorkItem?

    /// `DispatchWorkItem` use to wait for `lifecycle` data before executing task.
    private var lifecycleDispatchWorkItem: DispatchWorkItem?

    private var dispatchQueue: DispatchQueue

    init(dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
    }

    /// Schedules the referrer task after *timeout*
    func startReferrerTimer(timeout: TimeInterval, task: @escaping () -> Void) {
        if self.referrerDispatchWorkItem != nil {
            Log.warning(label: self.LOG_TAG, "Referrer timer is already running.")
            return
        }

        let dispatchItem = DispatchWorkItem { [weak self] in
            task()
            self?.referrerDispatchWorkItem = nil
        }

        self.referrerDispatchWorkItem = dispatchItem
        self.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + timeout, execute: dispatchItem)
    }

    /// Cancels the referrer timer and sets referrorDispatchItem to nil.
    func cancelReferrerTimer() {
        referrerDispatchWorkItem?.cancel()
        referrerDispatchWorkItem = nil
    }

    /// Schedules the lifecycle task after *timeout* 
    func startLifecycleTimer(timeout: TimeInterval, task: @escaping () -> Void) {
        if self.lifecycleDispatchWorkItem != nil {
            Log.warning(label: self.LOG_TAG, "Lifecycle timer is already running.")
            return
        }

        let dispatchItem = DispatchWorkItem { [weak self] in
            task()
            self?.lifecycleDispatchWorkItem = nil
        }

        self.lifecycleDispatchWorkItem = dispatchItem
        self.dispatchQueue.asyncAfter(deadline: DispatchTime.now() + timeout, execute: dispatchItem)
    }

    /// Cancels the lifecycle timer and sets lifecycleDispatchItem to nil.
    func cancelLifecycleTimer() {
        lifecycleDispatchWorkItem?.cancel()
        lifecycleDispatchWorkItem = nil
    }

    /// Verifies if the lifecycle timer is running.
    /// - Returns `True` if lifecycle timer is running
    func isLifecycleTimerRunning() -> Bool {
        return lifecycleDispatchWorkItem != nil
    }

    /// Verifies if the referrer timer is running.
    /// - Returns `True` if referrer timer is running
    func isReferrerTimerRunning() -> Bool {
        return referrerDispatchWorkItem != nil
    }
}
