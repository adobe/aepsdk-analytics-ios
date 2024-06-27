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

    static let EXTENSION_NAME                           = "com.adobe.module.analytics"
    static let FRIENDLY_NAME                            = "Analytics"
    static let EXTENSION_VERSION                        = "5.0.2"
    static let DATASTORE_NAME                           = EXTENSION_NAME

    static let DATA_QUEUE_NAME                           = EXTENSION_NAME
    static let REORDER_QUEUE_NAME                        = "com.adobe.module.analyticsreorderqueue"

    static let IGNORE_PAGE_NAME_VALUE                   = "lnk_o"
    static let ACTION_PREFIX                            = "AMACTION:"
    static let INTERNAL_ACTION_PREFIX                   = "ADBINTERNAL:"
    static let VAR_ESCAPE_PREFIX                        = "&&"
    static let APP_STATE_FOREGROUND                     = "foreground"
    static let APP_STATE_BACKGROUND                     = "background"
    static let AID_LENGTH                               = 33

    static let TRACK_INTERNAL_ADOBE_LINK                = "AdobeLink"
    static let SESSION_INFO_INTERNAL_ACTION_NAME        = "SessionInfo"
    static let CRASH_INTERNAL_ACTION_NAME        = "Crash"
    static let LIFECYCLE_INTERNAL_ACTION_NAME    = "Lifecycle"

    enum EventDataKeys {
        static let STATE_OWNER      = "stateowner"
        static let EXTENSION_NAME   = "com.adobe.module.analytics"
        static let FORCE_KICK_HITS  = "forcekick"
        static let CLEAR_HITS_QUEUE = "clearhitsqueue"
        static let ANALYTICS_ID     = "aid"
        static let GET_QUEUE_SIZE   = "getqueuesize"
        static let QUEUE_SIZE       = "queuesize"
        static let TRACK_INTERNAL   = "trackinternal"
        static let TRACK_ACTION     = "action"
        static let TRACK_STATE      = "state"
        static let CONTEXT_DATA     = "contextdata"
        static let ANALYTICS_SERVER_RESPONSE = "analyticsserverresponse"
        static let VISITOR_IDENTIFIER        = "vid"
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
        static let TRIGGERED_CONSEQUENCE = "triggeredconsequence"
        static let ID = "id"
        static let DETAIL = "detail"
        static let TYPE = "type"
    }

    enum ConsequenceTypes {
        static let TRACK = "an"
    }

    enum ContextDataKeys {
        static let INSTALL_EVENT_KEY = "a.InstallEvent"
        static let LAUNCH_EVENT_KEY = "a.LaunchEvent"
        static let CRASH_EVENT_KEY = "a.CrashEvent"
        static let UPGRADE_EVENT_KEY = "a.UpgradeEvent"
        static let DAILY_ENGAGED_EVENT_KEY = "a.DailyEngUserEvent"
        static let MONTHLY_ENGAGED_EVENT_KEY = "a.MonthlyEngUserEvent"
        static let INSTALL_DATE = "a.InstallDate"
        static let LAUNCHES = "a.Launches"
        static let PREVIOUS_SESSION_LENGTH = "a.PrevSessionLength"
        static let DAYS_SINCE_FIRST_LAUNCH = "a.DaysSinceFirstUse"
        static let DAYS_SINCE_LAST_LAUNCH = "a.DaysSinceLastUse"
        static let HOUR_OF_DAY = "a.HourOfDay"
        static let DAY_OF_WEEK = "a.DayOfWeek"
        static let OPERATING_SYSTEM = "a.OSVersion"
        static let APPLICATION_IDENTIFIER = "a.AppID"
        static let DAYS_SINCE_LAST_UPGRADE = "a.DaysSinceLastUpgrade"
        static let LAUNCHES_SINCE_UPGRADE = "a.LaunchesSinceUpgrade"
        static let ADVERTISING_IDENTIFIER = "a.adid"
        static let DEVICE_NAME = "a.DeviceName"
        static let DEVICE_RESOLUTION = "a.Resolution"
        static let CARRIER_NAME = "a.CarrierName"
        static let LOCALE = "a.locale"
        static let SYSTEM_LOCALE = "a.systemLocale"
        static let RUN_MODE = "a.RunMode"
        static let IGNORED_SESSION_LENGTH = "a.ignoredSessionLength"
        static let ACTION_KEY = "a.action"
        static let INTERNAL_ACTION_KEY = "a.internalaction"
        static let TIME_SINCE_LAUNCH_KEY = "a.TimeSinceLaunch"
        static let REGION_ID = "a.loc.poi.id"
        static let REGION_NAME = "a.loc.poi"
        static let EVENT_IDENTIFIER_KEY = "a.DebugEventIdentifier"
    }

    enum ContextDataValues {
        static let CRASH_EVENT = "CrashEvent"
        static let ACTION_KEY = "a.action"
        static let INTERNAL_ACTION_KEY = "a.internalaction"
    }

    enum Default {
        static let PRIVACY_STATUS: PrivacyStatus = .unknown
        static let FORWARDING_ENABLED = false
        static let OFFLINE_ENABLED = false
        static let BACKDATE_SESSION_INFO_ENABLED = false
        static let ASSURANCE_SESSION_ENABLED = false
        static let BATCH_LIMIT = 0
        static let CONNECTION_TIMEOUT = TimeInterval(5)
        static let LAUNCH_HIT_DELAY = TimeInterval.init(0)
        static let LIFECYCLE_RESPONSE_WAIT_TIMEOUT = TimeInterval.init(1)
        static let LAUNCH_DEEPLINK_DATA_WAIT_TIMEOUT = TimeInterval.init(0.5)
        static let LIFECYCLE_MAX_SESSION_LENGTH = TimeInterval.init(0)
        static let LIFECYCLE_SESSION_START_TIMESTAMP = TimeInterval.init(0)
        static let TIMESTAMP_DISABLED_WAIT_THRESHOLD_SECONDS = TimeInterval.init(60)
    }

    enum ParameterKeys {
        static let KEY_MID = "mid"
        static let KEY_BLOB = "aamb"
        static let KEY_LOCATION_HINT = "aamlh"
        static let KEY_ORG = "mcorgid"
    }

    enum DataStoreKeys {
        static let MOST_RECENT_HIT_TIMESTAMP = "mostrecenthittimestamp"
        static let AID = "aid"
        static let VID = "vid"
        static let DATA_MIGRATED = "data.migrated"
    }

    enum V4Migration {
        // Migrate
        static let AID = "ADOBEMOBILE_STOREDDEFAULTS_AID"
        static let IGNORE_AID = "ADOBEMOBILE_STOREDDEFAULTS_IGNOREAID"
        static let VID = "AOMS_AppMeasurement_StoredDefaults_VisitorID"
        // Delete
        static let AID_SYNCED = "ADOBEMOBILE_STOREDDEFAULTS_AIDSYNCED"
        static let LAST_TIMESTAMP = "ADBMobileLastTimestamp"
        static let CURRENT_HIT_ID  = "ANALYTICS_WORKER_CURRENT_ID"
        static let CURRENT_HIT_STAMP = "ANALYTICS_WORKER_CURRENT_STAMP"
    }

    enum V5Migration {
        // Migrate
        static let AID  = "Adobe.AnalyticsDataStorage.ADOBEMOBILE_STOREDDEFAULTS_AID"
        static let IGNORE_AID = "Adobe.AnalyticsDataStorage.ADOBEMOBILE_STOREDDEFAULTS_IGNOREAID"
        static let VID = "Adobe.AnalyticsDataStorage.ADOBEMOBILE_STOREDDEFAULTS_VISITOR_IDENTIFIER"
        // In some cases VID from v4 was migrated to identity datastore.
        static let IDENTITY_VID = "Adobe.visitorIDServiceDataStore.ADOBEMOBILE_VISITOR_ID"
        // Delete
        static let MOST_RECENT_HIT_TIMESTAMP = "Adobe.AnalyticsDataStorage.mostRecentHitTimestampSeconds"
    }

    enum Request {
        static let PRIVACY_MODE_KEY         = "a.privacy.mode"
        static let PRIVACY_MODE_UNKNOWN     = "unknown"
        static let IGNORE_PAGE_NAME_KEY     = "pe"
        static let ACTION_NAME_KEY          = "pev2"
        static let PAGE_NAME_KEY            = "pageName"
        static let ANALYTICS_ID_KEY         = "aid"
        static let CHARSET_KEY              = "ce"
        static let VISITOR_ID_KEY           = "vid"
        static let FORMATTED_TIMESTAMP_KEY  = "t"
        static let STRING_TIMESTAMP_KEY     = "ts"
        static let CUSTOMER_PERSPECTIVE_KEY = "cp"
        static let CONTEXT_DATA_KEY         = "c"
        static let CUSTOMER_ID_KEY          = "cid"
        static let REQUEST_STRING_PREFIX    = "ndh=1"
        static let DEBUG_API_PAYLOAD        = "&p.&debug=true&.p"
    }

    enum HttpConnection {
        static let HEADER_KEY_ACCEPT_LANGUAGE = "Accept-Language"
    }

    static let MAP_EVENT_DATA_KEYS_TO_CONTEXT_DATA_KEYS: [String: String] = [
        Identity.EventDataKeys.ADVERTISING_IDENTIFIER: ContextDataKeys.ADVERTISING_IDENTIFIER,
        Lifecycle.EventDataKeys.APP_ID: ContextDataKeys.APPLICATION_IDENTIFIER,
        Lifecycle.EventDataKeys.CARRIER_NAME: ContextDataKeys.CARRIER_NAME,
        Lifecycle.EventDataKeys.CRASH_EVENT: ContextDataKeys.CRASH_EVENT_KEY,
        Lifecycle.EventDataKeys.DAILY_ENGAGED_EVENT: ContextDataKeys.DAILY_ENGAGED_EVENT_KEY,
        Lifecycle.EventDataKeys.DAY_OF_WEEK: ContextDataKeys.DAY_OF_WEEK,
        Lifecycle.EventDataKeys.DAYS_SINCE_FIRST_LAUNCH: ContextDataKeys.DAYS_SINCE_FIRST_LAUNCH,
        Lifecycle.EventDataKeys.DAYS_SINCE_LAST_LAUNCH: ContextDataKeys.DAYS_SINCE_LAST_LAUNCH,
        Lifecycle.EventDataKeys.DAYS_SINCE_LAST_UPGRADE: ContextDataKeys.DAYS_SINCE_LAST_UPGRADE,
        Lifecycle.EventDataKeys.DEVICE_NAME: ContextDataKeys.DEVICE_NAME,
        Lifecycle.EventDataKeys.DEVICE_RESOLUTION: ContextDataKeys.DEVICE_RESOLUTION,
        Lifecycle.EventDataKeys.HOUR_OF_DAY: ContextDataKeys.HOUR_OF_DAY,
        Lifecycle.EventDataKeys.IGNORED_SESSION_LENGTH: ContextDataKeys.IGNORED_SESSION_LENGTH,
        Lifecycle.EventDataKeys.INSTALL_DATE: ContextDataKeys.INSTALL_DATE,
        Lifecycle.EventDataKeys.INSTALL_EVENT: ContextDataKeys.INSTALL_EVENT_KEY,
        Lifecycle.EventDataKeys.LAUNCH_EVENT: ContextDataKeys.LAUNCH_EVENT_KEY,
        Lifecycle.EventDataKeys.LAUNCHES: ContextDataKeys.LAUNCHES,
        Lifecycle.EventDataKeys.LAUNCHES_SINCE_UPGRADE: ContextDataKeys.LAUNCHES_SINCE_UPGRADE,
        Lifecycle.EventDataKeys.LOCALE: ContextDataKeys.LOCALE,
        Lifecycle.EventDataKeys.SYSTEM_LOCALE: ContextDataKeys.SYSTEM_LOCALE,
        Lifecycle.EventDataKeys.MONTHLY_ENGAGED_EVENT: ContextDataKeys.MONTHLY_ENGAGED_EVENT_KEY,
        Lifecycle.EventDataKeys.OPERATING_SYSTEM: ContextDataKeys.OPERATING_SYSTEM,
        Lifecycle.EventDataKeys.PREVIOUS_SESSION_LENGTH: ContextDataKeys.PREVIOUS_SESSION_LENGTH,
        Lifecycle.EventDataKeys.RUN_MODE: ContextDataKeys.RUN_MODE,
        Lifecycle.EventDataKeys.UPGRADE_EVENT: ContextDataKeys.UPGRADE_EVENT_KEY,
        Lifecycle.EventDataKeys.PREVIOUS_OS_VERSION: ContextDataKeys.OPERATING_SYSTEM,
        Lifecycle.EventDataKeys.PREVIOUS_APP_ID: ContextDataKeys.APPLICATION_IDENTIFIER
    ]

    // acquisition keys
    enum Acquisition {
        static let SHARED_STATE_NAME = "com.adobe.module.acquisition"
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
            static let VISITOR_ID_TYPE = "id_type"
            static let VISITOR_ID_ORIGIN = "id_origin"
            static let VISITOR_ID = "id"
            static let VISITOR_ID_AUTHENTICATION_STATE = "authentication_state"
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
            static let SYSTEM_LOCALE = "systemlocale"
            static let MAX_SESSION_LENGTH = "maxsessionlength"
            static let MONTHLY_ENGAGED_EVENT = "monthlyenguserevent"
            static let OPERATING_SYSTEM = "osversion"
            static let PREVIOUS_SESSION_LENGTH = "prevsessionlength"
            static let PREVIOUS_SESSION_PAUSE_TIMESTAMP = "previoussessionpausetimestampmillis"
            static let PREVIOUS_SESSION_START_TIMESTAMP = "previoussessionstarttimestampmillis"
            static let RUN_MODE = "runmode"
            static let SESSION_EVENT = "sessionevent"
            static let SESSION_START_TIMESTAMP = "starttimestampmillis"
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
            static let CONTENT_TYPE_HEADER = "Content-Type"
            static let ETAG_HEADER = "Etag"
            static let SERVER_HEADER = "Server"
            static let ENABLE_DEBUG_REQUEST  = "&p.&debug=true&.p"
        }

        enum DEFAULT {
            static let SESSION_ENABLED = false
        }
    }
}
