NIX_FLAGS := --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
ROOT := $(shell pwd)
NIX := nix-shell $(NIX_FLAGS) $(ROOT)/shell.nix --run
SHELL := bash
.SILENT:
MODE ?= debug
FLUTTER_MODE := $(if $(filter release,$(MODE)),release,$(if $(filter profile,$(MODE)),profile,debug))
FLUTTER_FLAG := $(if $(filter debug,$(FLUTTER_MODE)),--debug,$(if $(filter profile,$(FLUTTER_MODE)),--profile,--release))
CARGO_FLAG := $(if $(filter debug,$(MODE)),,--release)

.PHONY: gui build test check

gui:
	cd flutter/rust && $(NIX) "cargo build $(CARGO_FLAG) 2>&1"
	cd flutter && $(NIX) "flutter build linux $(FLUTTER_FLAG) 2>&1"
	@echo "done"

build:
	$(NIX) "cargo build $(CARGO_FLAG) 2>&1"

test:
	$(NIX) "cargo test 2>&1"

check: build test
	@echo "all good"
