ADDON := Tallymaster

REQUIRED  := clean distclean debug install uninstall deploy lint
HELP_VARS := FLAVOR WOW_RETAIL_ADDON_FOLDER WOW_DIR ADDONS_DIR WOW_UI_SIM SIM_BIN

## FLAVOR: client folder: _retail_ (Midnight), _classic_ (Mists), _classic_era_ (Vanilla)
FLAVOR ?= _retail_

## WOW_RETAIL_ADDON_FOLDER: retail Interface/AddOns; its WoW folder is also searched for Classic
WOW_RETAIL_ADDON_FOLDER ?=

## WOW_DIR: World of Warcraft folder, overrides auto-detection
WOW_DIR ?=

## ADDONS_DIR: Interface/AddOns to install into; default from WOW_RETAIL_ADDON_FOLDER (retail)
ADDONS_DIR ?= $(if $(filter _retail_,$(FLAVOR)),$(WOW_RETAIL_ADDON_FOLDER))

## WOW_UI_SIM: wow-ui-sim checkout for make test
WOW_UI_SIM ?= $(HOME)/git/wow-ui-sim

## SIM_BIN: wow-sim binary for make test
SIM_BIN ?= $(WOW_UI_SIM)/target/release/wow-sim

TOCS    := $(ADDON)_Mainline.toc $(ADDON)_Mists.toc $(ADDON)_Vanilla.toc
VERSION := $(shell sed -n 's/^## Version: //p' $(ADDON)_Mainline.toc)

INSTALL_FILES := $(TOCS) embeds.xml Bindings.xml CHANGELOG.md LICENSE
INSTALL_DIRS  := Core UI Locales Skin Media
KEEP_LIBS     := LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 LibElvUIPlugin-1.0

DIST_DIR := dist
ZIP      := $(DIST_DIR)/$(ADDON)-$(VERSION).zip
SIM_DIR  := $(DIST_DIR)/sim

# expansion -> TOC suffix, client folder
FLAVOR_NAMES        := Midnight Mists Vanilla
FLAVOR_TOC_Midnight := Mainline
FLAVOR_TOC_Mists    := Mists
FLAVOR_TOC_Vanilla  := Vanilla
FLAVOR_DIR_Midnight := _retail_
FLAVOR_DIR_Mists    := _classic_
FLAVOR_DIR_Vanilla  := _classic_era_

WOW_CANDIDATES := \
	"$$PROGRAMFILES/World of Warcraft" \
	"C:/Program Files (x86)/World of Warcraft" \
	"C:/Program Files/World of Warcraft" \
	"D:/World of Warcraft" \
	"C:/Games/World of Warcraft"

# last candidate: the WoW folder three levels above WOW_RETAIL_ADDON_FOLDER (Wine)
FIND_WOW = if [ -n "$(WOW_DIR)" ]; then echo "$(WOW_DIR)"; else \
	retail_root=""; \
	if [ -n "$(WOW_RETAIL_ADDON_FOLDER)" ]; then retail_root=$$(dirname "$$(dirname "$$(dirname "$(WOW_RETAIL_ADDON_FOLDER)")")"); fi; \
	for d in $(WOW_CANDIDATES) "$$retail_root"; do if [ -n "$$d" ] && [ -d "$$d/$(FLAVOR)" ]; then echo "$$d"; break; fi; done; fi

FIND_ADDONS = if [ -n "$(ADDONS_DIR)" ]; then echo "$(ADDONS_DIR)"; else wow=$$($(FIND_WOW)); if [ -n "$$wow" ]; then echo "$$wow/$(FLAVOR)/Interface/AddOns"; fi; fi

NO_ADDONS_MSG = echo "AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER=/path/to/Interface/AddOns, or pass WOW_DIR=/path/to/World of Warcraft"

HAVE_LIBS = [ -n "$$(ls -A Libs 2>/dev/null)" ]

# .pkgmeta externals -> "<path> <url>" per line
AWK_EXTERNALS := /^externals:/{e=1;next} /^[a-zA-Z]/{e=0} e&&/^  [^ \#]/{sub(/:$$/,"",$$1);p=$$1;next} e&&p&&$$1=="url:"{print p, $$2; p=""}

.DEFAULT_GOAL := help

.PHONY: help version check check-tocs luacheck lint test libs fetch-libs debug install uninstall \
	prune-libs stage dist deploy clean distclean purge

##@ General

## help: list targets and variables
help:
	@echo "$(ADDON) $(VERSION)"
	@$(foreach v,$(HELP_VARS),$(v)='$($(v))') awk -f scripts/make-help.awk $(firstword $(MAKEFILE_LIST))

## version: print the addon version
version:
	@echo "$(VERSION)"

##@ Checks

## lint: Lua syntax, TOCs, luacheck, Makefile comments (BLOCKER)
lint: check check-tocs luacheck
	@awk -v required="$(REQUIRED)" -f scripts/make-lint.awk $(firstword $(MAKEFILE_LIST))
	@awk -v required="$(REQUIRED)" -v bat=1 -f scripts/make-lint.awk Makefile.bat
	@echo "make: comments ok"

## check: syntax-check every Lua file
check:
	@files=$$(find Core UI Locales Skin -name '*.lua' | sort); \
	if command -v luac >/dev/null 2>&1; then \
		luac -p $$files && echo "luac: all files parse"; \
	elif command -v lua >/dev/null 2>&1; then \
		for f in $$files; do lua -e "assert(loadfile('$$f'))" || exit 1; done; \
		echo "lua: all files parse"; \
	else \
		echo "no lua or luac found"; exit 1; \
	fi

## check-tocs: flavor TOCs differ only in ## Interface:, every listed file exists
check-tocs:
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	ref=""; fail=0; \
	for toc in $(TOCS); do \
		grep -v '^## Interface:' "$$toc" > "$$tmp/$$toc"; \
		if [ -z "$$ref" ]; then ref="$$toc"; \
		elif ! diff -u "$$tmp/$$ref" "$$tmp/$$toc" > "$$tmp/d" 2>&1; then \
			echo "  DRIFT   $$toc differs from $$ref beyond ## Interface:"; \
			sed '1,2d; s/^/          /' "$$tmp/d"; \
			fail=1; \
		fi; \
	done; \
	if [ $$fail -eq 1 ]; then exit 1; fi; \
	echo "tocs: $(words $(TOCS)) flavors agree"
	@missing=0; \
	for f in $$(sed -n 's/\r$$//; s|\\|/|g; /^[A-Za-z].*\.\(lua\|xml\)$$/p' $(ADDON)_Mainline.toc); do \
		[ -f "$$f" ] || { echo "  MISSING $$f (listed in the TOC)"; missing=1; }; \
	done; \
	if [ $$missing -eq 1 ]; then exit 1; fi; \
	echo "tocs: every listed file exists"

## luacheck: static analysis, any warning fails
luacheck:
	@command -v luacheck >/dev/null 2>&1 || { echo "luacheck not found - install it (luarocks install luacheck)"; exit 1; }
	@luacheck --no-color -q . && echo "luacheck: no warnings"

## test: run tests/*.lua headless in wow-ui-sim against the retail Blizzard UI
test:
	@[ -x "$(SIM_BIN)" ] || { echo "wow-sim not found at $(SIM_BIN)"; \
		echo "build it: cd $(WOW_UI_SIM) && cargo build --release --no-default-features --features casc,client-retail --bin wow-sim --bin wow-cli"; \
		exit 1; }
	@$(HAVE_LIBS) || { echo "Libs/ is empty - run 'make fetch-libs' first"; exit 1; }
	@rm -rf "$(SIM_DIR)"
	@out="$(SIM_DIR)/Interface/AddOns/$(ADDON)"; mkdir -p "$$out"; \
	for d in $(INSTALL_DIRS) Libs tests; do cp -r "$$d" "$$out/"; done; \
	cp embeds.xml Bindings.xml $(ADDON)_Mainline.toc "$$out/"; \
	cp -r "$(WOW_UI_SIM)/Interface/AddOns/TestFramework" "$(SIM_DIR)/Interface/AddOns/"; \
	ln -f "$(SIM_BIN)" "$(SIM_DIR)/wow-sim" 2>/dev/null || cp "$(SIM_BIN)" "$(SIM_DIR)/wow-sim"
	@cd "$(SIM_DIR)" && env -u WOW_SIM_WOW_PATH ./wow-sim --no-saved-vars run-tests $(ADDON)

##@ Libraries

## libs: report embedded libraries missing from Libs/
libs:
	@missing=0; \
	for lib in $$(tr '\134' '/' < embeds.xml | sed -n 's|.*Libs/\([^/]*\)/.*|\1|p' | sort -u); do \
		if [ -d "Libs/$$lib" ]; then echo "  ok      Libs/$$lib"; \
		else echo "  MISSING Libs/$$lib"; missing=1; fi; \
	done; \
	if [ $$missing -eq 1 ]; then echo "run 'make fetch-libs'"; fi

## fetch-libs: download the .pkgmeta externals into Libs/ (needs svn and git)
fetch-libs:
	@command -v svn >/dev/null 2>&1 || { echo "svn not found - needed for the CurseForge externals"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "git not found - needed for LibDataBroker-1.1"; exit 1; }
	@awk '$(AWK_EXTERNALS)' .pkgmeta | while read -r path url; do \
		[ -n "$$path" ] && [ -n "$$url" ] || continue; \
		rm -rf "$$path"; \
		case "$$url" in \
			*github.com*) \
				git clone -q --depth 1 "$$url" "$$path.tmp" || exit 1; \
				rm -rf "$$path.tmp/.git"; \
				mv "$$path.tmp" "$$path";; \
			*) \
				svn export -q --force --non-interactive --trust-server-cert "$$url" "$$path" || exit 1;; \
		esac; \
		echo "  fetched $$path"; \
	done
	@sed -n '/^ignore:/,$$p' .pkgmeta | sed -n 's|^  - \(Libs/[^/]*/.*\)$$|\1|p' | while read -r p; do \
		if [ -e "$$p" ]; then echo "  dropping $$p (.pkgmeta ignores it)"; rm -rf "$$p"; fi; \
	done
	@find Libs -name .pkgmeta -delete 2>/dev/null; true
	@$(MAKE) --no-print-directory libs

##@ Client

## debug: same as install (Lua has no separate debug build)
debug: install

# $(ADDON).toc in the stray list: pre-1.1.0 single TOC
## install: copy the addon into the live client (FLAVOR picks the client)
install:
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$addons/$(ADDON)"; \
	echo "installing $(ADDON) $(VERSION) -> $$target"; \
	mkdir -p "$$target"; \
	for d in $(INSTALL_DIRS); do rm -rf "$$target/$$d"; cp -r "$$d" "$$target/"; done; \
	for f in $(INSTALL_FILES); do cp "$$f" "$$target/"; done; \
	if $(HAVE_LIBS); then \
		cp -r Libs/. "$$target/Libs/"; \
	elif [ ! -d "$$target/Libs" ]; then \
		echo "Libs/ is empty and none installed - run 'make fetch-libs' first"; exit 1; \
	else \
		echo "  keeping the libraries already installed in the client"; \
	fi; \
	for x in design scripts .claude .git dist README.md .gitignore .pkgmeta Makefile Makefile.bat $(ADDON).toc; do \
		if [ -e "$$target/$$x" ]; then \
			echo "  removing stray $$x"; \
			rm -rf "$$target/$$x"; \
		fi; \
	done; \
	stale=""; \
	for d in "$$target"/Libs/*/; do \
		[ -d "$$d" ] || continue; \
		name=$$(basename "$$d"); \
		case " $(KEEP_LIBS) " in *" $$name "*) ;; *) stale="$$stale $$name";; esac; \
	done; \
	if [ -n "$$stale" ]; then \
		echo "  stale libraries still installed:$$stale - run 'make prune-libs'"; \
	fi; \
	echo "done - /reload in game"

## uninstall: remove the addon from the client, SavedVariables stay
uninstall:
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$addons/$(ADDON)"; \
	if [ ! -d "$$target" ]; then echo "not installed: $$target"; exit 0; fi; \
	rm -rf "$$target"; \
	echo "removed $$target"

## purge: uninstall and delete the SavedVariables
purge: uninstall
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	flavor_dir=$$(dirname "$$(dirname "$$addons")"); \
	found=0; \
	for f in "$$flavor_dir"/WTF/Account/*/SavedVariables/$(ADDON).lua*; do \
		[ -e "$$f" ] || continue; \
		echo "  deleting $$f"; rm -f "$$f"; found=1; \
	done; \
	[ $$found -eq 1 ] || echo "  no SavedVariables found"

## prune-libs: delete installed libraries embeds.xml no longer lists
prune-libs:
	@addons=$$($(FIND_ADDONS)); \
	if [ -z "$$addons" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$addons/$(ADDON)"; \
	[ -d "$$target/Libs" ] || { echo "nothing installed"; exit 0; }; \
	for d in "$$target"/Libs/*/; do \
		[ -d "$$d" ] || continue; \
		name=$$(basename "$$d"); \
		case " $(KEEP_LIBS) " in \
			*" $$name "*) ;; \
			*) echo "  removing $$name"; rm -rf "$$d";; \
		esac; \
	done; \
	echo "done"

##@ Packages

## stage: dist/<expansion>/Tallymaster per client, each with only its own TOC
stage:
	@for name in $(FLAVOR_NAMES); do rm -rf "$(DIST_DIR)/$$name"; done
	@$(HAVE_LIBS) || { echo "Libs/ is empty - run 'make fetch-libs' first"; exit 1; }
	@$(foreach name,$(FLAVOR_NAMES), \
		name="$(name)"; toc="$(FLAVOR_TOC_$(name))"; clientdir="$(FLAVOR_DIR_$(name))"; \
		out="$(DIST_DIR)/$(name)/$(ADDON)"; \
		mkdir -p "$$out"; \
		for d in $(INSTALL_DIRS) Libs; do cp -r "$$d" "$$out/"; done; \
		cp embeds.xml Bindings.xml CHANGELOG.md LICENSE "$$out/"; \
		cp "$(ADDON)_$$toc.toc" "$$out/"; \
		printf "  %-10s %-32s -> %s\n" "$$name" "$(DIST_DIR)/$(name)/$(ADDON)" \
			"$$clientdir/Interface/AddOns/"; \
	)

## dist: build dist/Tallymaster-<version>.zip with all three TOCs
dist:
	@rm -rf $(DIST_DIR)/$(ADDON); rm -f $(ZIP)
	@$(HAVE_LIBS) || { echo "Libs/ is empty - run 'make fetch-libs' first"; exit 1; }
	@command -v zip >/dev/null 2>&1 || { echo "zip not found"; exit 1; }
	@mkdir -p $(DIST_DIR)/$(ADDON)
	@for d in $(INSTALL_DIRS) Libs; do cp -r "$$d" $(DIST_DIR)/$(ADDON)/; done
	@for f in $(INSTALL_FILES); do cp "$$f" $(DIST_DIR)/$(ADDON)/; done
	@cd $(DIST_DIR) && zip -qr "$(ADDON)-$(VERSION).zip" $(ADDON)
	@rm -rf $(DIST_DIR)/$(ADDON)
	@echo "built $(ZIP)"

## deploy: none - releases are published by pushing a v* tag to GitHub
deploy:
	@echo "No deploy: a v* tag pushed to github.com/lasse-tech/tallymaster publishes the release."

## clean: remove dist/
clean:
	@rm -rf $(DIST_DIR)
	@echo "cleaned"

## distclean: clean and empty Libs/
distclean: clean
	@rm -rf Libs
	@echo "removed Libs/"
