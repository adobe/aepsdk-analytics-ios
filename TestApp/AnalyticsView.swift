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

import UIKit
import SwiftUI
import AEPAnalytics
import AEPCore

#if os(iOS)
import AEPAssurance
#endif

@available(tvOSApplicationExtension, unavailable)
struct AnalyticsView: View {
    let LOG_TAG = "AnalyticsTestApp::AnalyticsView"

    // state vars
    @State private var assuranceSessionUrl: String = ""
    @State private var extensionVersion: String = ""
    @State private var trackActionVar: String = ""
    @State private var trackStateVar: String = ""
    @State private var retrievedQueueSize: String = ""
    @State private var retrievedTrackingId: String = ""
    @State private var retrievedVisitorId: String = ""
    @State private var visitorId: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: 12) {
                VStack {
                    #if os(iOS)
                    Group {
                        /// Assurance API
                        Text("Assurance API").bold()

                        TextField("aepanalytics://", text: $assuranceSessionUrl)

                        Button(action: {
                            if let url = URL(string: self.assuranceSessionUrl) {
                                Assurance.startSession(url: url)
                            }
                        }) {
                            Text("Start Session")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                    #endif
                    Group {
                        /// Core Privacy API
                        Text("Core Privacy API").bold()

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.optedOut)
                        }) {
                            Text("OptOut")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.optedIn)
                        }) {
                            Text("OptIn")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.unknown)
                        }) {
                            Text("Unknown")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                    Group {
                        /// Analytics Extension Version and Tracking API
                        Text("Analytics API").bold()

                        Button(action: {
                            extensionVersion = Analytics.extensionVersion
                        }
                        ) {
                            Text("Extension Version")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Retrieved Extension Version", text: $extensionVersion)
                            .autocapitalization(.none)

                        Button(action: {
                            MobileCore.track(action: trackActionVar as String, data: ["number": 25, "key": "testAction"])
                        }
                        ) {
                            Text("Track Action")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Action to track:", text: $trackActionVar)
                            .autocapitalization(.none)

                        Button(action: {
                            MobileCore.track(state: trackStateVar as String, data: ["number": 50, "key": "testState"])
                        }
                        ) {
                            Text("Track State")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("State to track:", text: $trackStateVar)
                            .autocapitalization(.none)
                    }
                    Group {
                        /// Analytics Queue API
                        Button(action: {
                            Analytics.getQueueSize { (queueSize, _) in
                                retrievedQueueSize = String(queueSize)
                            }
                        }
                        ) {
                            Text("Get Queue Size")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Retrieved Queue Size", text: $retrievedQueueSize)
                            .autocapitalization(.none)

                        Button(action: {
                            Analytics.sendQueuedHits()
                        }
                        ) {
                            Text("Send Queued Hits")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            Analytics.clearQueue()
                        }
                        ) {
                            Text("Clear Queue")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                    Group {
                        /// Analytics Identifier API
                        Button(action: {
                            Analytics.getTrackingIdentifier { (trackingId, _) in
                                retrievedTrackingId = trackingId ?? "No tracking identifier."
                            }
                        }
                        ) {
                            Text("Get Tracking Identifier")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Retrieved Tracking Identifier", text: $retrievedTrackingId)
                            .autocapitalization(.none)

                        Button(action: {
                            Analytics.getVisitorIdentifier { (visitorId, _) in
                                retrievedVisitorId = visitorId ?? "No visitor identifier."
                            }
                        }
                        ) {
                            Text("Get Visitor Identifier")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Retrieved Visitor Identifier", text: $retrievedVisitorId)
                            .autocapitalization(.none)

                        Button(action: {
                            Analytics.setVisitorIdentifier(visitorIdentifier: visitorId)
                        }
                        ) {
                            Text("Set Visitor Identifier")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Visitor Identifier to be set", text: $visitorId)
                            .autocapitalization(.none)
                    }
                }
            }
        }
    }
}

@available(tvOSApplicationExtension, unavailable)
struct AunalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
    }
}
