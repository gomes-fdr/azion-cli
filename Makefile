PATH := /usr/local/go/bin:$(PATH)
SHELL := env PATH=$(PATH) /bin/bash
GO := $(shell which go)
NAME := azion

GOPATH ?= $(shell $(GO) env GOPATH)
GOBIN ?= $(GOPATH)/bin
GOSEC ?= $(GOBIN)/gosec
GOLINT ?= $(GOBIN)/golint
GOFMT ?= $(GOBIN)/gofmt
RELOAD ?= $(GOBIN)/CompileDaemon
BUILD_DEBUG_VERSION ?= false

# Version Info
BIN_VERSION=$(shell git describe --tags)
LDFLAGS=-X github.com/aziontech/azion-cli/cmd.BinVersion=$(BIN_VERSION)

.PHONY : deps
deps: ## verify projects dependencies
	@ $(GO) env -w GOPRIVATE=github.com/aziontech/*
	@ $(GO) mod verify
	@ $(GO) mod tidy

.PHONY: lint
lint: get-lint-deps ## running GoLint
	@ $(GOBIN)/golangci-lint run ./...

.PHONY: get-lint-deps
get-lint-deps:
	@if [ ! -x $(GOBIN)/golangci-lint ]; then\
		curl -sfL \
		https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOBIN) v1.31.0 ;\
	fi

.PHONY: sec
sec: get-gosec-deps ## running GoSec
	@ -$(GOSEC) ./...

.PHONY: get-gosec-deps
get-gosec-deps:
	@ cd $(GOPATH); \
		$(GO) get -u github.com/securego/gosec/cmd/gosec
		
.PHONY : build
build: ## build application code
	@ $(GO) version
	@ $(GO) build -ldflags '$(LDFLAGS)' -o ./bin/$(NAME)

.PHONY : cross-build
cross-build: ## cross-compile for all platforms/architectures. Use the env BUILD_DEBUG_VERSION=true for building debug binaries as well
	@ $(GO) version
	set -ex;\
	while read spec; \
	do\
		distro=$$(echo $${spec} | cut -d/ -f1);\
		goarch=$$(echo $${spec} | cut -d/ -f2);\
		arch=$$(echo $${goarch} | sed 's/386/x86_32/g; s/amd64/x86_64/g; s/arm$$/arm32/g;');\
		mkdir -p dist/$$distro/$$arch;\
		env CGO_ENABLED=0 GOOS=$$distro GOARCH=$$goarch $(GO) build -ldflags '$(LDFLAGS) $(LDFLAGS_STRIP)' -o ./dist/$$distro/$$arch/$(NAME_WITH_VERSION); \
		if [ "$(BUILD_DEBUG_VERSION)" = true ]; then \
			env CGO_ENABLED=0 GOOS=$$distro GOARCH=$$goarch $(GO) build -ldflags '$(LDFLAGS)' -o ./dist/$$distro/$$arch/$(NAME_WITH_VERSION).debug; \
		fi; \
	done < BUILD
