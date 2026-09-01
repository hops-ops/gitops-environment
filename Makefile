SHELL := /bin/bash

PACKAGE ?= gitops-environment
XRD_DIR := apis/gitopsenvironments
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
CONFIGURATION := $(XRD_DIR)/configuration.yaml
RENDER_TESTS := $(wildcard tests/test-*)

clean:
	rm -rf _output
	rm -rf .up
	rm -f $(CONFIGURATION)

build:
	up project build

generate-configuration:
	@set -euo pipefail; \
	hops validate generate-configuration --path . --api-path "$(XRD_DIR)"

# Keep this list synchronized with both validation workflows.
EXAMPLES := \
	examples/gitopsenvironments/import-existing.yaml:: \
	examples/gitopsenvironments/from-template.yaml:: \
	examples/gitopsenvironments/shared-preview.yaml::

render\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example --observed-resources=$$observed; \
			else \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example; \
			fi \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

validate\:all: generate-configuration
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--observed-resources=$$observed --include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			else \
				up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
					--include-full-xr --quiet | \
					crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -; \
			fi \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

.PHONY: render validate generate-configuration test build clean publish
render: ; @$(MAKE) 'render:all'
validate: ; @$(MAKE) generate-configuration 'validate:all'

render\:%:
	@up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/gitopsenvironments/$*.yaml

validate\:%: generate-configuration
	@up composition render --xrd=$(DEFINITION) $(COMPOSITION) examples/gitopsenvironments/$*.yaml \
		--include-full-xr --quiet | \
		crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

test:
	up test run $(RENDER_TESTS)

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)
