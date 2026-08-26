GO ?= go
BUILDER_VERSION ?= $(shell ./scripts/otel-version.sh)
BUILDER_BIN ?= $(CURDIR)/.tools/builder
COLLECTOR_IMAGE ?= flyr-otel-collector:dev

# The binary is compiled outside Docker, so it has to be built for the image's
# platform rather than the developer's. Without this a macOS `make image`
# produces a linux image holding a darwin binary, which fails to exec.
TARGET_OS ?= linux
TARGET_ARCH ?= $(shell $(GO) env GOARCH)

.PHONY: all install-builder build image smoke-test

all: image smoke-test

install-builder:
	@echo "Installing collector builder version $(BUILDER_VERSION)"
	GOBIN=$(dir $(BUILDER_BIN)) $(GO) install go.opentelemetry.io/collector/cmd/builder@$(BUILDER_VERSION)

build: install-builder
	CGO_ENABLED=0 GOOS=$(TARGET_OS) GOARCH=$(TARGET_ARCH) \
		$(BUILDER_BIN) --config builder-config.yaml

image: build
	docker build --platform $(TARGET_OS)/$(TARGET_ARCH) -t $(COLLECTOR_IMAGE) .

smoke-test:
	./scripts/smoke-test.sh
