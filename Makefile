export EXTENSION_NAME = AEPTarget
PROJECT_NAME = $(EXTENSION_NAME)
TARGET_NAME_XCFRAMEWORK = $(EXTENSION_NAME).xcframework
SCHEME_NAME_XCFRAMEWORK = AEPTargetXCFramework

CURR_DIR := ${CURDIR}
SIMULATOR_ARCHIVE_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/Products/Library/Frameworks/
SIMULATOR_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios_simulator.xcarchive/dSYMs/
IOS_ARCHIVE_PATH = $(CURR_DIR)/build/ios.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_DSYM_PATH = $(CURR_DIR)/build/ios.xcarchive/dSYMs/
IOS_DESTINATION = 'platform=iOS Simulator,name=iPhone 14'

lint-autocorrect:
	./Pods/SwiftLint/swiftlint --fix --format

lint:
	./Pods/SwiftLint/swiftlint lint

check-format:
	swiftformat --lint AEPTarget/Sources --swiftversion 5.1
	
format:
	swiftformat AEPTarget/Sources --swiftversion 5.1

pod-install:
	(pod install --repo-update)

ci-pod-install:
	(bundle exec pod install --repo-update)

pod-repo-update:
	(pod repo update)

install-swiftformat:
	HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftformat && brew cleanup swiftformat 

pod-update: pod-repo-update
	(pod update)

open:
	open $(PROJECT_NAME).xcworkspace
	
clean:
	(rm -rf build)

test: clean
	@echo "######################################################################"
	@echo "### Testing iOS"
	@echo "######################################################################"
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME)Tests -destination $(IOS_DESTINATION) -derivedDataPath build/out -resultBundlePath build/$(PROJECT_NAME).xcresult -enableCodeCoverage YES

archive: clean pod-install build
	xcodebuild -create-xcframework -framework $(SIMULATOR_ARCHIVE_PATH)$(EXTENSION_NAME).framework -debug-symbols $(SIMULATOR_ARCHIVE_DSYM_PATH)$(EXTENSION_NAME).framework.dSYM -framework $(IOS_ARCHIVE_PATH)$(EXTENSION_NAME).framework -debug-symbols $(IOS_ARCHIVE_DSYM_PATH)$(EXTENSION_NAME).framework.dSYM -output ./build/$(TARGET_NAME_XCFRAMEWORK)

build:
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

zip:
	cd build && zip -r -X $(PROJECT_NAME).xcframework.zip $(PROJECT_NAME).xcframework/
	swift package compute-checksum build/$(PROJECT_NAME).xcframework.zip

latest-version:
	(which jq)
	(pod spec cat AEPTarget | jq '.version' | tr -d '"')

version-podspec-local:
	(which jq)
	(pod ipc spec AEPTarget.podspec | jq '.version' | tr -d '"')

version-source-code:
	(cat ./AEPTarget/Sources/TargetConstants.swift | egrep '\s*EXTENSION_VERSION\s*=\s*\"(.*)\"' | ruby -e "puts gets.scan(/\"(.*)\"/)[0] " | tr -d '"')

# make check-version VERSION=3.0.0
check-version:
	(sh ./script/version.sh $(VERSION))

test-SPM-integration:
	(sh ./script/test-SPM.sh)

codecov:
	(./script/codecov_downloader.sh)
	(bash codecov -v -X s3 -c -D "./build/out" -J "AEPTarget")

test-podspec:
	(sh ./script/test-podspec.sh)

pod-lint:
	(pod lib lint --allow-warnings --verbose --swift-version=5.1)
