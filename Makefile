export EXTENSION_NAME = AEPTarget
PROJECT_NAME = $(EXTENSION_NAME)
TARGET_NAME_XCFRAMEWORK = $(EXTENSION_NAME).xcframework
SCHEME_NAME_XCFRAMEWORK = AEPTargetXCFramework

SIMULATOR_ARCHIVE_PATH = ./build/ios_simulator.xcarchive/Products/Library/Frameworks/
IOS_ARCHIVE_PATH = ./build/ios.xcarchive/Products/Library/Frameworks/

lint-autocorrect:
	swiftlint autocorrect

lint:
	swiftlint lint

check-format:
	swiftformat --lint AEPTarget/Sources --swiftversion 5.1
	
format:
	swiftformat .

pod-install:
	(pod install --repo-update)

ci-pod-install:
	(bundle exec pod install --repo-update)

pod-repo-update:
	(pod repo update)

install-swiftlint:
	HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftlint && brew cleanup swiftlint

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
	xcodebuild test -workspace $(PROJECT_NAME).xcworkspace -scheme $(PROJECT_NAME)Tests -destination 'platform=iOS Simulator,name=iPhone 11 Pro' -derivedDataPath build/out -enableCodeCoverage YES

archive:
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios.xcarchive" -sdk iphoneos -destination="iOS" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild archive -workspace $(PROJECT_NAME).xcworkspace -scheme $(SCHEME_NAME_XCFRAMEWORK) -archivePath "./build/ios_simulator.xcarchive" -sdk iphonesimulator -destination="iOS Simulator" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES
	xcodebuild -create-xcframework -framework $(SIMULATOR_ARCHIVE_PATH)$(EXTENSION_NAME).framework -framework $(IOS_ARCHIVE_PATH)$(EXTENSION_NAME).framework -output ./build/$(TARGET_NAME_XCFRAMEWORK)

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

test-podspec:
	(sh ./script/test-podspec.sh)

pod-lint:
	(pod lib lint --allow-warnings --verbose --swift-version=5.1)
