ADDON       := Tallymaster
VERSION     := $(shell sed -n 's/^## Version: //p' $(ADDON).toc)
FLAVOR      ?= _retail_

INSTALL_FILES := $(ADDON).toc embeds.xml Bindings.xml CHANGELOG.md
INSTALL_DIRS  := Core UI Locales Skin Media
KEEP_LIBS     := LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 LibElvUIPlugin-1.0

DIST_DIR := dist
ZIP      := $(DIST_DIR)/$(ADDON)-$(VERSION).zip

WOW_CANDIDATES := \
	"$$PROGRAMFILES/World of Warcraft" \
	"C:/Program Files (x86)/World of Warcraft" \
	"C:/Program Files/World of Warcraft" \
	"D:/World of Warcraft" \
	"C:/Games/World of Warcraft"

FIND_WOW = if [ -n "$(WOW_DIR)" ]; then echo "$(WOW_DIR)"; else for d in $(WOW_CANDIDATES); do if [ -d "$$d/$(FLAVOR)" ]; then echo "$$d"; break; fi; done; fi

.DEFAULT_GOAL := help
.PHONY: help version check libs install uninstall prune-libs dist clean distclean purge

help:
	@echo "$(ADDON) $(VERSION)"
	@echo ""
	@echo "  make check        syntax-check every Lua file"
	@echo "  make libs         report which embedded libraries are missing"
	@echo "  make install      copy the addon into the live WoW client"
	@echo "  make uninstall    remove it again (SavedVariables are kept)"
	@echo "  make prune-libs   drop installed libraries embeds.xml no longer lists"
	@echo "  make dist         build $(ZIP)"
	@echo "  make clean        remove build output"
	@echo "  make distclean    clean + empty Libs/"
	@echo "  make purge        uninstall + delete SavedVariables (needs CONFIRM=yes)"
	@echo ""
	@echo "  FLAVOR=$(FLAVOR)   override with FLAVOR=_classic_era_ etc."
	@echo "  WOW_DIR           override the auto-detected WoW folder"

version:
	@echo "$(VERSION)"

check:
	@files=$$(find Core UI Locales Skin -name '*.lua' | sort); \
	if command -v luac >/dev/null 2>&1; then \
		luac -p $$files && echo "luac: all files parse"; \
	elif command -v lua >/dev/null 2>&1; then \
		for f in $$files; do lua -e "assert(loadfile('$$f'))" || exit 1; done; \
		echo "lua: all files parse"; \
	elif python -c "import lupa" >/dev/null 2>&1; then \
		python -c "import io,glob,sys,lupa; m=getattr(lupa,'luajit21',None) or getattr(lupa,'lua51',None) or lupa; L=m.LuaRuntime(); ld=L.eval('function(s,n) local f,e=load(s,n) if f then return true,0 end return false,tostring(e) end'); fs=sorted(glob.glob('Core/*.lua')+glob.glob('UI/*.lua')+glob.glob('Locales/*.lua')+glob.glob('Skin/*.lua')); rs=[(f,)+tuple(ld(io.open(f,encoding='utf-8').read(),'@'+f)) for f in fs]; bad=[r for r in rs if not r[1]]; [print('FAIL',r[0],r[2]) for r in bad]; sys.exit(1) if bad else print('lupa: all files parse (' + str(len(fs)) + ')')"; \
	else \
		echo "no Lua available (install lua/luac, or 'pip install lupa') - skipped"; \
	fi

libs:
	@missing=0; \
	for lib in $$(tr '\134' '/' < embeds.xml | sed -n 's|.*Libs/\([^/]*\)/.*|\1|p' | sort -u); do \
		if [ -d "Libs/$$lib" ]; then echo "  ok      Libs/$$lib"; \
		else echo "  MISSING Libs/$$lib"; missing=1; fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo ""; \
		echo "Libraries are not vendored - see Libs/README.md. 'make install' keeps"; \
		echo "whatever is already installed in the client, so this is only fatal on"; \
		echo "a first install or for 'make dist'."; \
	fi

install:
	@wow=$$($(FIND_WOW)); \
	if [ -z "$$wow" ]; then \
		echo "WoW not found. Pass WOW_DIR=/path/to/World\ of\ Warcraft"; exit 1; fi; \
	target="$$wow/$(FLAVOR)/Interface/AddOns/$(ADDON)"; \
	echo "installing $(ADDON) $(VERSION) -> $$target"; \
	mkdir -p "$$target"; \
	for d in $(INSTALL_DIRS); do rm -rf "$$target/$$d"; cp -r "$$d" "$$target/"; done; \
	for f in $(INSTALL_FILES); do cp "$$f" "$$target/"; done; \
	if [ -n "$$(ls -A Libs 2>/dev/null | grep -v '^README.md$$')" ]; then \
		cp -r Libs/. "$$target/Libs/"; \
	elif [ ! -d "$$target/Libs" ]; then \
		echo "  warning: no Libs/ here and none installed - the addon will not load"; \
	else \
		echo "  keeping the libraries already installed in the client"; \
	fi; \
	for x in design .claude .git dist README.md .gitignore .pkgmeta Makefile Makefile.bat; do \
		if [ -e "$$target/$$x" ]; then \
			echo "  removing stray $$x (not part of the addon)"; \
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
		echo "  stale libraries still installed:$$stale"; \
		echo "  run 'make prune-libs' to remove them"; \
	fi; \
	echo "done - /reload in game"

uninstall:
	@wow=$$($(FIND_WOW)); \
	if [ -z "$$wow" ]; then echo "WoW not found. Pass WOW_DIR=..."; exit 1; fi; \
	target="$$wow/$(FLAVOR)/Interface/AddOns/$(ADDON)"; \
	if [ ! -d "$$target" ]; then echo "not installed: $$target"; exit 0; fi; \
	rm -rf "$$target"; \
	echo "removed $$target"; \
	echo "SavedVariables kept - use 'make purge CONFIRM=yes' to delete those too"

prune-libs:
	@wow=$$($(FIND_WOW)); \
	if [ -z "$$wow" ]; then echo "WoW not found. Pass WOW_DIR=..."; exit 1; fi; \
	target="$$wow/$(FLAVOR)/Interface/AddOns/$(ADDON)"; \
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

dist: clean
	@if [ -z "$$(ls -A Libs 2>/dev/null | grep -v '^README.md$$')" ]; then \
		echo "Libs/ is empty - the zip would not load. Populate it first (make libs)."; \
		exit 1; fi
	@mkdir -p $(DIST_DIR)/$(ADDON)
	@for d in $(INSTALL_DIRS) Libs; do cp -r "$$d" $(DIST_DIR)/$(ADDON)/; done
	@for f in $(INSTALL_FILES); do cp "$$f" $(DIST_DIR)/$(ADDON)/; done
	@rm -f $(DIST_DIR)/$(ADDON)/Libs/README.md $(DIST_DIR)/$(ADDON)/Media/README.md
	@if command -v zip >/dev/null 2>&1; then \
		( cd $(DIST_DIR) && zip -qr "$(ADDON)-$(VERSION).zip" $(ADDON) ); \
	elif command -v tar >/dev/null 2>&1; then \
		tar -a -c -f "$(ZIP)" -C "$(DIST_DIR)" "$(ADDON)"; \
	else \
		echo "  warning: no zip/tar, falling back to Compress-Archive"; \
		echo "  (that writes backslash paths - fine on Windows, not for uploads)"; \
		powershell -NoProfile -Command \
			"Compress-Archive -Path '$(DIST_DIR)/$(ADDON)' -DestinationPath '$(ZIP)' -Force"; \
	fi
	@rm -rf $(DIST_DIR)/$(ADDON)
	@echo "built $(ZIP)"

clean:
	@rm -rf $(DIST_DIR)
	@echo "cleaned"

distclean: clean
	@find Libs -mindepth 1 -maxdepth 1 ! -name README.md -exec rm -rf {} +
	@echo "emptied Libs/"

purge:
	@if [ "$(CONFIRM)" != "yes" ]; then \
		echo "refusing to delete SavedVariables without CONFIRM=yes"; \
		echo "   make purge CONFIRM=yes"; exit 1; fi
	@$(MAKE) --no-print-directory uninstall
	@wow=$$($(FIND_WOW)); \
	found=0; \
	for f in "$$wow/$(FLAVOR)"/WTF/Account/*/SavedVariables/$(ADDON).lua*; do \
		[ -e "$$f" ] || continue; \
		echo "  deleting $$f"; rm -f "$$f"; found=1; \
	done; \
	[ $$found -eq 1 ] || echo "  no SavedVariables found"
