.PHONY: help build clean lint test release install

help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_.-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

build: ## Build package in debug mode
	swift build

release: ## Build package in release mode
	swift build -c release

clean: ## Clean build artifacts
	swift package clean
	rm -rf .build

test: ## Run tests
	swift test

install: release ## Install CLI to /usr/local/bin
	install .build/release/owi /usr/local/bin/owi

uninstall: ## Uninstall CLI from /usr/local/bin
	rm -f /usr/local/bin/owi

format: ## Format code (requires swift-format)
	swift format --in-place --recursive Sources Tests

lint: ## Lint code)
	swift format lint --recursive Sources Tests
