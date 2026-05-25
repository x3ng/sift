NIX_FLAGS := --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
ROOT := $(shell pwd)
NIX := nix-shell $(NIX_FLAGS) $(ROOT)/shell.nix --run
SHELL := bash
.SILENT:
MODE ?= debug
FLUTTER_MODE := $(if $(filter release,$(MODE)),release,$(if $(filter profile,$(MODE)),profile,debug))
FLUTTER_FLAG := $(if $(filter debug,$(FLUTTER_MODE)),--debug,$(if $(filter profile,$(FLUTTER_MODE)),--profile,--release))
CARGO_FLAG := $(if $(filter debug,$(MODE)),,--release)

.PHONY: gui gui-run build test check install clean

gui:
	cd flutter/rust && $(NIX) "cargo build $(CARGO_FLAG) 2>&1"
	cd flutter && $(NIX) "flutter build linux $(FLUTTER_FLAG) 2>&1"

gui-run:
	cd flutter/rust && $(NIX) "cargo build $(CARGO_FLAG) 2>&1"
	cd flutter && $(NIX) "flutter run -d linux $(FLUTTER_FLAG) 2>&1"

build:
	$(NIX) "cargo build $(CARGO_FLAG) 2>&1"

test:
	$(NIX) "cargo test 2>&1"

check: build test
	@echo "all good"

install:
	$(NIX) "cargo install --path . 2>&1"

clean:
	cargo clean 2>/dev/null; cd flutter/rust && cargo clean 2>/dev/null
	rm -rf flutter/build/
