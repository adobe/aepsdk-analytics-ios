export EXTENSION_NAME = AEPAnalytics
PROJECT_NAME = $(EXTENSION_NAME)
SCHEME_NAME_XCFRAMEWORK = AEPAnalytics

CURR_DIR := ${CURDIR}
IOS_SIMULATOR_ARCHIVE_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/Products/Library/Frameworks/
IOS_SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/dSYMs/
IOS_ARCHIVE_PATH = $(CURR_DIR)/build/ios.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios.xcarchive/dSYMs/
TVOS_SIMULATOR_ARCHIVE_PATH = ./build/tvos_simulator.xcarchive/Products/Library/Frameworks/
TVOS_SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/tvos_simulator.xcarchive/dSYMs/
TVOS_ARCHIVE_PATH = ./build/tvos.xcarchive/Products/Library/Frameworks/
TVOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/tvos.xcarchive/dSYMs/

setup:
	(pod install)

pod-repo-update:
	(pod repo update)

# pod repo update may fail if there is no repo (issue fixed in v1.8.4). Use pod install --repo-update instead
pod-install:
	(pod install --repo-update)

pod-update: pod-repo-update
	(pod update)

open:
	open $(PROJECT_NAME).xcworkspace

test-ios:
	@echo "######################################################################"
	@echo "### Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'platform=iOS Simulator,name=iPhone 8' -derivedDataPath build/out -enableCodeCoverage YES

test-tvos:
	@echo "######################################################################"
	@echo "### Testing tvOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -destination 'platform=tvOS Simulator,name=Apple TV' -derivedDataPath build/out -enableCodeCoverage YES


archive: pod-update
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME) -archivePath "./build/tvos.xcarchive" -sdk appletvos -destination="tvOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/tvos_simulator.xcarchive" -sdk appletvsimulator -destination="tvOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework -framework $(IOS_SIMULATOR_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_SIMULATOR_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(TVOS_SIMULATOR_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(TVOS_SIMULATOR_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(IOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(IOS_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -framework $(TVOS_ARCHIVE_PATH)$(PROJECT_NAME).framework -debug-symbols $(TVOS_ARCHIVE_DSYM_PATH)$(PROJECT_NAME).framework.dSYM \
	 -output ./build/$(PROJECT_NAME).xcframework

zip:
	cd build && zip -r -X $(PROJECT_NAME).xcframework.zip $(PROJECT_NAME).xcframework /
	swift package compute-checksum build/$(PROJECT_NAME).xcframework.zip

clean:
	rm -rf ./build

lint-autocorrect:
	./Pods/SwiftLint/swiftlint autocorrect

lint:
	./Pods/SwiftLint/swiftlint lint

# release checks
check-version:
	(sh ./Script/version.sh $(VERSION))

test-SPM-integration:
	(sh ./Script/test-SPM.sh)

test-podspec:
	(sh ./Script/test-podspec.sh)

pod-lint:
	(pod lib lint --allow-warnings --verbose --swift-version=5.1)

# make bump-versions from='3\.1\.0' to=3.1.1
bump-versions:
	(LC_ALL=C find . -type f -name 'project.pbxproj' -exec sed -i '' 's/$(from)/$(to)/' {} +)
	(LC_ALL=C find . -type f -name '*.swift' -exec sed -i '' 's/$(from)/$(to)/' {} +)
	(LC_ALL=C find . -type f -name '*.podspec' -exec sed -i '' 's/$(from)/$(to)/' {} +)
