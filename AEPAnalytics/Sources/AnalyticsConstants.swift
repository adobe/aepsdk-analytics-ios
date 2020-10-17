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
import AEPCore

enum AnalyticsConstants {
    static let EXTENSION_NAME = "com.adobe.module.analytics"
    static let FRIENDLY_NAME = "Analytics"
    static let EXTENSION_VERSION = "0.0.1"
    static let DATASTORE_NAME = EXTENSION_NAME
    
    enum EventDataKeys {
        static let STATE_OWNER = ""
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
        static let SHARED_STATE_NAME = ""
        static let SERVER_RESPONSE = ""
    }
    
    // acquisition keys
    enum Acquisition {
        
        static let SHARED_STATE_NAME = ""
        static let CONTEXT_DATA = "contextdata"
        static let REFERRER_DATA = "referrerdata"
        static let DATA_PUSH_MESSAGE_ID = "a.push.payloadId"
        static let DATA_LOCAL_NOTIFICATION_ID = "a.message.id"
    }
    
    // configuration keys
    enum Configuration {
        
        enum EventDataKeys {
            static let SHARED_STATE_NAME = "com.adobe.module.configuration"
            static let GLOBAL_PRIVACY = "global.privacy"
            static let MARKETING_CLOUD_ORGID_KEY = "experienceCloud.org"
            static let ANALYTICS_AAMFORWARDING = "analytics.aamForwardingEnabled"
            static let ANALYTICS_BATCH_LIMIT = "analytics.batchLimit"
            static let ANALYTICS_OFFLINE_TRACKING = "analytics.offlineEnabled"
            static let ANALYTICS_REPORT_SUITES = "analytics.rsids"
            static let ANALYTICS_SERVER = "analytics.server"
            static let ANALYTICS_LAUNCH_HIT_DELAY = "analytics.launchHitDelay"
            static let ANALYTICS_BACKDATE_PREVIOUS_SESSION = "analytics.backdatePreviousSessionInfo"
        }
    }
    
    // identity keys
    enum Identity {
        
        enum EventDataKeys {
            static let SHARED_STATE_NAME = "com.adobe.module.identity"
            static let VISITOR_ID_MID = "mid"
            static let VISITOR_ID_BLOB = "blob"
            static let VISITOR_ID_LOCATION_HINT = "locationhint"
            static let VISITOR_IDS_LIST = "visitoridslist"
            static let ADVERTISING_IDENTIFIER = "a.adid"
            static let USER_IDENTIFIER = "vid"
        }
    }
    
    // lifecycle keys
    enum Lifecycle {
        
        enum EventDataKeys {
        
        static let SHARED_STATE_NAME = "com.adobe.module.lifecycle"
        static let ADDITIONAL_CONTEXT_DATA = "additionalcontextdata"
        static let APP_ID = "appid"
        static let CARRIER_NAME = "carriername"
        static let CRASH_EVENT = "crashevent"
        static let DAILY_ENGAGED_EVENT = "dailyenguserevent"
        static let DAY_OF_WEEK = "dayofweek"
        static let DAYS_SINCE_FIRST_LAUNCH = "dayssincefirstuse"
        static let DAYS_SINCE_LAST_LAUNCH = "dayssincelastuse"
        static let DAYS_SINCE_LAST_UPGRADE = "dayssincelastupgrade"
        static let DEVICE_NAME = "devicename"
        static let DEVICE_RESOLUTION = "resolution"
        static let HOUR_OF_DAY = "hourofday"
        static let IGNORED_SESSION_LENGTH = "ignoredsessionlength"
        static let INSTALL_DATE = "installdate"
        static let INSTALL_EVENT = "installevent"
        static let LAUNCH_EVENT = "launchevent"
        static let LAUNCHES = "launches"
        static let LAUNCHES_SINCE_UPGRADE = "launchessinceupgrade"
        static let LIFECYCLE_ACTION_KEY = "action"
        static let LIFECYCLE_CONTEXT_DATA = "lifecyclecontextdata"
        static let LIFECYCLE_PAUSE = "pause"
        static let LIFECYCLE_START = "start"
        static let LOCALE = "locale"
        static let MAX_SESSION_LENGTH = "maxsessionlength"
        static let MONTHLY_ENGAGED_EVENT = "monthlyenguserevent"
        static let OPERATING_SYSTEM = "osversion"
        static let PREVIOUS_SESSION_LENGTH = "prevsessionlength"
        static let PREVIOUS_SESSION_PAUSE_TIMESTAMP = "previoussessionpausetimestampseconds"
        static let PREVIOUS_SESSION_START_TIMESTAMP = "previoussessionstarttimestampseconds"
        static let RUN_MODE = "runmode"
        static let SESSION_EVENT = "sessionevent"
        static let SESSION_START_TIMESTAMP = "starttimestampseconds"
        static let UPGRADE_EVENT = "upgradeevent"
        static let PREVIOUS_OS_VERSION = "previousosversion"
        static let PREVIOUS_APP_ID = "previousappid"
        }
    }
    
    enum Places {
        
        enum EventDataKeys {
            static let SHARED_STATE_NAME = "com.adobe.module.places"
            static let CURRENT_POI = "currentpoi"
            static let REGION_ID = "regionid"
            static let REGION_NAME = "regionname"
        }
    }
    
    enum Assurance {
        
        enum EventDataKeys {
            static let SHARED_STATE_NAME = "com.adobe.assurance"
            static let SESSION_ID = "sessionid"
        }
    }
    
    
    enum Default {
        static let DEFAULT_PRIVACY_STATUS: PrivacyStatus = .optedIn
        static let DEFAULT_FORWARDING_ENABLED = false
        static let DEFAULT_OFFLINE_ENABLED = false
        static let DEFAULT_BACKDATE_SESSION_INFO_ENABLED = false
        static let DEFAULT_BATCH_LIMIT = 0
        static let DEFAULT_LAUNCH_HIT_DELAY = Date.init()
        static let DEFAULT_LIFECYCLE_RESPONSE_WAIT_TIMEOUT = Date.init()
        static let DEFAULT_LAUNCH_DEEPLINK_DATA_WAIT_TIMEOUT = Date.init()
        static let DEFAULT_ASSURANCE_SESSION_ENABLED = false
        static let DEFAULT_LIFECYCLE_MAX_SESSION_LENGTH = Date.init()
        static let DEFAULT_LIFECYCLE_SESSION_START_TIMESTAMP = Date.init()
    }
}
