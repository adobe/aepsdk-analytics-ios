/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License")
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

enum AnalyticsConstants {
    static let EXTENSION_NAME = "com.adobe.module.analytics"
    static let FRIENDLY_NAME = "Analytics"
    static let EXTENSION_VERSION = "0.0.1"
    static let DATASTORE_NAME = EXTENSION_NAME

    enum EventDataKeys {
        static let EXTENSION_NAME = "com.adobe.module.analytics"
        static let FORCE_KICK_HITS  = "forcekick"
        static let CLEAR_HITS_QUEUE = "clearhitsqueue"
        static let ANALYTICS_ID     = "aid"
        static let GET_QUEUE_SIZE   = "getqueuesize"
        static let QUEUE_SIZE       = "queuesize"
        static let TRACK_INTERNAL   = "trackinternal"
        static let TRACK_ACTION     = "action"
        static let TRACK_STATE      = "state"
        static let CONTEXT_DATA = "contextdata"
        static let ANALYTICS_SERVER_RESPONSE = "analyticsserverresponse"
        static let VISITOR_IDENTIFIER = "vid"
        static let RULES_CONSEQUENCE_TYPE_TRACK = "an"
        static let HEADERS_RESPONSE = "headers"
        static let ETAG_HEADER = "ETag"
        static let SERVER_HEADER = "Server"
        static let CONTENT_TYPE_HEADER = "Content-Type"
        static let REQUEST_EVENT_IDENTIFIER = "requestEventIdentifier"
        static let HIT_HOST = "hitHost"
        static let HIT_URL = "hitUrl"
    }

}
