# sCapture build entry points. Every command a session needs is a target here.

VERSION := $(shell cat VERSION)
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
CLT := /Library/Developer/CommandLineTools

# Use Xcode when it is usable (licence accepted), else fall back to the
# Command Line Tools, whose Swift Testing macros need an explicit plugin path.
XCODE_OK := $(shell xcrun swift --version >/dev/null 2>&1 && echo yes)
ifeq ($(XCODE_OK),yes)
SWIFT := swift
TEST_FLAGS :=
else
SWIFT := DEVELOPER_DIR=$(CLT) swift
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(CLT)/usr/lib/swift/host/plugins/testing
endif
# Local builds take the first Apple Development certificate when there is one,
# so macOS keeps the Screen Recording and Accessibility grants across rebuilds;
# `make app SIGN_IDENTITY=-` signs ad hoc as the release does.
SIGN_IDENTITY ?= $(or $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $$2; exit }'),-)

.PHONY: build test test-common coverage app run icon smoke release poc clean version

build:
	$(SWIFT) build

# swift test does not run a dependency's tests, so the shared code's run first
# when it is checked out beside this repository; the shell PoC is checked too.
test: test-common
	$(SWIFT) test $(TEST_FLAGS)
	@zsh -n scripts/poc.sh && echo "test: scripts/poc.sh parses"

test-common:
	@if [ -f ../scommon/Package.swift ]; then $(MAKE) -C ../scommon test; else echo "test-common: no ../scommon, its tests run in its own repository"; fi

# Line coverage of the core library.
coverage:
	$(SWIFT) test $(TEST_FLAGS) --enable-code-coverage
	xcrun llvm-cov report .build/debug/SCaptureCoreTests.xctest/Contents/MacOS/SCaptureCoreTests \
		-instr-profile .build/debug/codecov/default.profdata \
		-ignore-filename-regex '(Tests|scommon|DerivedSources)/'

# An SPM build wrapped into a signed bundle by scripts/bundle.sh, the same
# path on every machine.
app:
	SWIFT="$(SWIFT)" VERSION=$(VERSION) BUILD_NUMBER=$(BUILD_NUMBER) SIGN_IDENTITY="$(SIGN_IDENTITY)" scripts/bundle.sh

run: app
	-pkill -x sCapture
	open -n build/sCapture.app

# The app icon and the README image from the brand SVGs.
icon:
	mkdir -p build
	xcrun swift scripts/make-icon.swift build/AppIcon.iconset brand/scapture-1024.png
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

# Captures a test window with two profiles and checks names and pixel sizes;
# the app needs Screen Recording.
smoke: app
	scripts/smoke.sh

# Universal, ad hoc signed app and zip in build/release/.
release:
	scripts/release.sh

# make poc ARGS="use poc-demo-vm-stop", make poc ARGS=shot
poc:
	@scripts/poc.sh $(ARGS)

clean:
	rm -rf .build build

version:
	@echo $(VERSION)
