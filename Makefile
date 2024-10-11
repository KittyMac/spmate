all:
	swift build --triple arm64-apple-macosx --configuration release
	swift build --triple x86_64-apple-macosx --configuration release
	-rm .build/spmate
	lipo -create -output .build/spmate .build/arm64-apple-macosx/release/spmate .build/x86_64-apple-macosx/release/spmate
	cp .build/spmate ../../textmate/bin/spmate
