NIX_FLAGS := --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
ROOT      := $(shell pwd)
NIX       := nix-shell $(NIX_FLAGS) $(ROOT)/shell.nix --run

SHELL := bash
.SILENT:

# ── Build mode ──────────────────────────────────────────────────────
#   make             → debug (default)
#   make MODE=release → release
#   make MODE=profile → Flutter profile + Rust release

MODE  ?= debug
FLUTTER_MODE := $(if $(filter release,$(MODE)),release,$(if $(filter profile,$(MODE)),profile,debug))
FLUTTER_FLAG := $(if $(filter debug,$(FLUTTER_MODE)),--debug,$(if $(filter profile,$(FLUTTER_MODE)),--profile,--release))
CARGO_FLAG   := $(if $(filter debug,$(MODE)),,--release)
RUST_TARGET  := $(if $(filter debug,$(MODE)),debug,release)
SO_PATH      := flutter/rust/target/$(RUST_TARGET)/libsift_ffi.so
BUNDLE_DIR   := flutter/build/linux/x64/$(FLUTTER_MODE)/bundle

# ── Flutter GUI ────────────────────────────────────────────────────

.PHONY: gui gui-build gui-run

gui: gui-build            ## Build Flutter + Rust .so (debug by default, MODE=release)
	@echo "→ $(BUNDLE_DIR)/sift_app"

gui-build: gui-so          ## Build Flutter + Rust .so (debug by default, MODE=release)
	cd flutter && $(NIX) "flutter build linux $(FLUTTER_FLAG) 2>&1"
	@echo "→ $(BUNDLE_DIR)/sift_app"

gui-run: gui-build        ## Build and launch Flutter GUI (attach debugger)
	cd flutter && $(NIX) "flutter run -d linux $(FLUTTER_FLAG) 2>&1"

# ── Rust bridge .so ────────────────────────────────────────────────

.PHONY: gui-so
gui-so:
	cd flutter/rust && $(NIX) "cargo build $(CARGO_FLAG) 2>&1"

# ── Rust core (CLI) ────────────────────────────────────────────────

.PHONY: build test check

build:                     ## Build Rust core (debug by default, MODE=release)
	$(NIX) "cargo build $(CARGO_FLAG) 2>&1"

test:                      ## Run Rust tests
	$(NIX) "cargo test 2>&1"

check: build test          ## Build + test
	@echo "all good"

# ── Install CLI ─────────────────────────────────────────────────────

.PHONY: install

install:                   ## Install sift CLI to ~/.cargo/bin (release only)
	$(NIX) "cargo install --path . 2>&1"

# ── Clean ───────────────────────────────────────────────────────────

.PHONY: clean

clean:                     ## Clean all build artifacts
	cargo clean 2>/dev/null; cd flutter/rust && cargo clean 2>/dev/null
	rm -rf flutter/build/

# ── Help ────────────────────────────────────────────────────────────

.PHONY: help

help:                      ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  MODE=debug (default) | release | profile"
