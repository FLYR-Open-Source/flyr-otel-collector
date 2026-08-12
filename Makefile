GO ?= go
GOBIN ?= $(shell $(GO) env GOPATH)/bin
BUILDER_VERSION ?= $(shell grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' builder-config.yaml | head -n 1)

.PHONY: all install-builder build-builder build-builder-docker smoke-test

all: build-builder-docker smoke-test

install-builder:
	@echo "Installing collector builder version $(BUILDER_VERSION)"
	$(GO) install go.opentelemetry.io/collector/cmd/builder@$(BUILDER_VERSION)

build-builder: install-builder
	$(GOBIN)/builder --config builder-config.yaml

build-builder-docker:
	OTEL_VERSION=$(BUILDER_VERSION) docker compose -f docker-compose.smoke-test.yaml -p otel-smoke-test build collector

smoke-test:
	./scripts/smoke-test.sh