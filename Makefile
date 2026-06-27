SHELL := /bin/bash
SH_FILES := bin/squawk lib/*.sh

.DEFAULT_GOAL := help

# Development tasks only. Install/uninstall/check-deps live on the CLI itself
# (`squawk install`, `squawk uninstall`, `squawk check-deps`).

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

test: ## Run the bats test suite
	@bats test/

lint: ## shellcheck + shfmt (diff mode)
	@shellcheck $(SH_FILES)
	@shfmt -d -i 2 -ci -bn $(SH_FILES)

fmt: ## Format shell scripts with shfmt
	@shfmt -w -i 2 -ci -bn $(SH_FILES)

.PHONY: help test lint fmt
