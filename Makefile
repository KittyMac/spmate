
build-release:
	# Building the XCFramework
	rm -rf ./build
	mkdir -p ./build
	
	-xcodebuild clean
	
	
	xcodebuild archive -scheme spmate -sdk iphoneos -archivePath "build/ios_devices.xcarchive" BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface
	xcodebuild archive -scheme spmate -sdk iphonesimulator -archivePath "build/ios_simulators.xcarchive" BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface
	xcodebuild archive -sdk macosx ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET=11.0 BUILD_LIBRARY_FOR_DISTRIBUTION=YES -scheme spmate -archivePath "build/macos_devices.xcarchive" SKIP_INSTALL=NO OTHER_SWIFT_FLAGS=-no-verify-emitted-module-interface
    
	xcodebuild -create-xcframework \
	  -framework build/ios_devices.xcarchive/Products/Library/Frameworks/spmate.framework \
	  -framework build/ios_simulators.xcarchive/Products/Library/Frameworks/spmate.framework \
	  -framework build/macos_devices.xcarchive/Products/Library/Frameworks/spmate.framework \
	  -output build/spmate.xcframework
    
	# Zip up spmate.xcframework
	rm -f /tmp/spmate.xcframework.zip
	cd ./build && zip -X -y -r /tmp/spmate.xcframework.zip spmate.xcframework
	
	rm -rf ./build
