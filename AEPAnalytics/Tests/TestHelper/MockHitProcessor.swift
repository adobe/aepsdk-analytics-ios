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

@testable import AEPServices
import Foundation

public class MockHitProcessor: HitProcessing {

    var processedEntities: [DataEntity] = []

    public var processResult: Bool = false

    public func retryInterval(for entity: DataEntity) -> TimeInterval {
        return TimeInterval(30)
    }
    public func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        if processResult {
            processedEntities.append(entity)
        }
        completion(processResult)
    }
}
