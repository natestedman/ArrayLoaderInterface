XCODE_COMMAND=$(shell { command -v xctool || command -v xcodebuild; } 2>/dev/null)
XCODE_FLAGS=-project 'ArrayLoaderInterface.xcodeproj' -scheme 'ArrayLoaderInterface'

.PHONY: all clean docs

all:
	$(XCODE_COMMAND) $(XCODE_FLAGS) build

clean:
	$(XCODE_COMMAND) $(XCODE_FLAGS) clean

docs:
	jazzy \
		--clean \
		--author "Nate Stedman" \
		--author_url "http://natestedman.com" \
		--github_url "https://github.com/natestedman/ArrayLoaderInterface" \
		--github-file-prefix "https://github.com/natestedman/ArrayLoaderInterface/tree/master" \
		--module-version "0.1.0" \
		--xcodebuild-arguments -scheme,ArrayLoaderInterface \
		--module ArrayLoaderInterface \
		--output Documentation
