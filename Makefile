# sCapture build entry points. Every command a session needs is a target here;
# the Swift targets arrive with their phases.

VERSION := $(shell cat VERSION)

.PHONY: poc test version

# make poc ARGS="use poc-demo-vm-stop", make poc ARGS=shot
poc:
	@scripts/poc.sh $(ARGS)

# Until the Swift core lands, the shell PoC is the code: a zsh syntax check.
test:
	@zsh -n scripts/poc.sh && echo "test: scripts/poc.sh parses"

version:
	@echo $(VERSION)
