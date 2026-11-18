export EXTENSION_NAME = AEPAnalytics
PROJECT_NAME = $(EXTENSION_NAME)
SCHEME_NAME_XCFRAMEWORK = AEPAnalytics

CURR_DIR := ${CURDIR}
IOS_SIMULATOR_ARCHIVE_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/Products/Library/Frameworks/
IOS_SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/dSYMs/
IOS_ARCHIVE_PATH = $(CURR_DIR)/build/ios.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios.xcarchive/dSYMs/
TVOS_SIMULATOR_ARCHIVE_PATH = $(CURR_DIR)/build/tvos_simulator.xcarchive/Products/Library/Frameworks/
TVOS_SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/tvos_simulator.xcarchive/dSYMs/
TVOS_ARCHIVE_PATH = $(CURR_DIR)/build/tvos.xcarchive/Products/Library/Frameworks/
TVOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/tvos.xcarchive/dSYMs/

TEST_APP_IOS_SCHEME = TestAppiOS
TEST_APP_TVOS_SCHEME = TestApptvOS

# CI variables - using values with defaults. Set defaults to values that are most useful for local development.
IOS_DEVICE_NAME ?= iPhone 18 Pro
# If OS version is not specified, uses the first device name match in the list of available simulators
IOS_VERSION ?=
ifeq ($(strip $(IOS_VERSION)),)
	IOS_DESTINATION = "platform=iOS Simulator,name=$(IOS_DEVICE_NAME)"
else
	IOS_DESTINATION = "platform=iOS Simulator,name=$(IOS_DEVICE_NAME),OS=$(IOS_VERSION)"
endif

TVOS_DEVICE_NAME ?= Apple TV 4K (3rd generation)
# If OS version is not specified, uses the first device name match in the list of available simulators
TVOS_VERSION ?=
ifeq ($(strip $(TVOS_VERSION)),)
	TVOS_DESTINATION = "platform=tvOS Simulator,name=$(TVOS_DEVICE_NAME)"
else
	TVOS_DESTINATION = "platform=tvOS Simulator,name=$(TVOS_DEVICE_NAME),OS=$(TVOS_VERSION)"
endif

pod-repo-update:
	pod repo update

# pod repo update may fail if there is no repo (issue fixed in v1.8.4). Use pod install --repo-update instead
pod-install:
	pod install --repo-update

ci-pod-install:
	bundle exec pod install --repo-update

pod-update: pod-repo-update
	pod update

open:
	open $(PROJECT_NAME).xcworkspace

test: unit-test-ios functional-test-ios unit-test-tvos functional-test-tvos

test-ios: unit-test-ios functional-test-ios

test-tvos: unit-test-tvos functional-test-tvos

unit-test-ios:
	@echo "######################################################################"
	@echo "### Unit Testing iOS"
	@echo "######################################################################"
	rm -rf build/reports/iosUnitResults.xcresult
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "UnitTests" -destination $(IOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/reports/iosUnitResults.xcresult -enableCodeCoverage YES

functional-test-ios:
	@echo "######################################################################"
	@echo "### Functional Testing iOS"
	@echo "######################################################################"
	rm -rf build/reports/iosFunctionalResults.xcresult
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "FunctionalTests" -destination $(IOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/reports/iosFunctionalResults.xcresult -enableCodeCoverage YES

unit-test-tvos:
	@echo "######################################################################"
	@echo "### Unit Testing tvOS"
	@echo "######################################################################"
	rm -rf build/reports/tvosUnitResults.xcresult
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "UnitTests" -destination $(TVOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/reports/tvosUnitResults.xcresult -enableCodeCoverage YES

functional-test-tvos:
	@echo "######################################################################"
	@echo "### Functional Testing tvOS"
	@echo "######################################################################"
	rm -rf build/reports/tvosFunctionalResults.xcresult
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme "FunctionalTests" -destination $(TVOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/reports/tvosFunctionalResults.xcresult -enableCodeCoverage YES

archive: clean pod-install build-ios build-tvos
	@echo "######################################################################"
	@echo "### Generating iOS and tvOS Frameworks for $(PROJECT_NAME)"
	@echo "######################################################################"
	xcodebuild -create-xcframework -framework $(IOS_SIMULATOR_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_SIMULATOR_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(TVOS_SIMULATOR_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(TVOS_SIMULATOR_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(IOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(TVOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(TVOS_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -output ./build/$(PROJECT_NAME).xcframework

build-ios:
	@echo "######################################################################"
	@echo "### Building iOS archive"
	@echo "######################################################################"
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	
build-tvos:
	@echo "######################################################################"
	@echo "### Building tvOS archive"
	@echo "######################################################################"
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/tvos.xcarchive" -sdk appletvos -destination="tvOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/tvos_simulator.xcarchive" -sdk appletvsimulator -destination="tvOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

zip:
	cd build && zip -r -X $(PROJECT_NAME).xcframework.zip $(PROJECT_NAME).xcframework/
	swift package compute-checksum build/$(PROJECT_NAME).xcframework.zip

build-app: pod-install
	@echo "######################################################################"
	@echo "### Building $(TEST_APP_IOS_SCHEME)"
	@echo "######################################################################"
	xcodebuild clean build -workspace $(PROJECT_NAME).xcworkspace -scheme $(TEST_APP_IOS_SCHEME) -destination 'generic/platform=iOS Simulator'
	
	@echo "######################################################################"
	@echo "### Building $(TEST_APP_TVOS_SCHEME)"
	@echo "######################################################################"
	xcodebuild clean build -workspace $(PROJECT_NAME).xcworkspace -scheme $(TEST_APP_TVOS_SCHEME) -destination 'generic/platform=tvOS Simulator'


clean:
	rm -rf ./build

lint-autocorrect:
	./Pods/SwiftLint/swiftlint --fix

lint:
	./Pods/SwiftLint/swiftlint lint AEPAnalytics/Sources

# release checks
# make check-version VERSION=5.0.0
check-version:
	sh ./Script/version.sh $(VERSION)

test-SPM-integration:
	sh ./Script/test-SPM.sh

test-podspec:
	sh ./Script/test-podspec.sh

# Builds the AEPAnalytics target in Swift 6 language mode. AEPANALYTICS_SWIFT_VERSION is
# only referenced by the AEPAnalytics target, so dependency pods keep their own modes.
build-swift6:
	xcodebuild build -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'generic/platform=iOS Simulator' AEPANALYTICS_SWIFT_VERSION=6.0
	xcodebuild build -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'generic/platform=tvOS Simulator' AEPANALYTICS_SWIFT_VERSION=6.0

# Compiles a Swift 6 consumer that calls the public completion-handler APIs with
# plain closures from @MainActor code (protects the @Sendable contract). The
# consumer target is built in Swift 6 language mode; AEPAnalytics and its dependencies
# keep their own declared language modes, matching a real Swift 6 app's build.
test-swift6-consumer:
	sh ./Script/test-swift6-consumer.sh

# Compile-only build on the minimum supported toolchain (Xcode 15.3+/Swift 5.10).
build-min-toolchain:
	xcodebuild build -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'generic/platform=iOS Simulator'
	xcodebuild build -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'generic/platform=tvOS Simulator'

pod-lint:
	pod lib lint --allow-warnings --verbose --swift-version=5.10

# make bump-versions from='3\.1\.0' to=3.1.1
bump-versions:
	(LC_ALL=C find . -type f -name 'project.pbxproj' -exec sed -i '' 's/$(from)/$(to)/' {} +)
	(LC_ALL=C find . -type f -name '*.swift' -exec sed -i '' 's/$(from)/$(to)/' {} +)
	(LC_ALL=C find . -type f -name '*.podspec' -exec sed -i '' 's/$(from)/$(to)/' {} +)
