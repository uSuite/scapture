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

.PHONY: build test test-common coverage poc clean version

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

# make poc ARGS="use poc-demo-vm-stop", make poc ARGS=shot
poc:
	@scripts/poc.sh $(ARGS)

clean:
	rm -rf .build build

version:
	@echo $(VERSION)
