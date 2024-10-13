all: clean
	swift build --triple arm64-apple-macosx --configuration release
	swift build --triple x86_64-apple-macosx --configuration release
	-rm .build/spmate
	lipo -create -output .build/spmate .build/arm64-apple-macosx/release/SPMate .build/x86_64-apple-macosx/release/SPMate
	cp .build/spmate ../../textmate/bin/spmate

clean:
	rm -rf .build