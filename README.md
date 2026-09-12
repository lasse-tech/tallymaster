# Tallymaster

A World of Warcraft addon that keeps a live, on-screen list of items, currencies and
collectibles — icon, name and a running count — grouped by category, much like
Blizzard's *Track Recipe* feature.

Runs on **Midnight** (retail), **Mists Classic** and **Classic Era** from one folder.
Folder name and in-game title are both **Tallymaster**.

## Features
- **Live tracker** — on-screen list, counts update in real time from bags, bank,
  equipped slots and mail. Grouped by category; groups fold. Sort alphabetically
  or by count. Position and shown/hidden state survive a reload or relog.
- **Add by name or ID** — slash command, minimap button, or keybind opens an input
  box. Ambiguous IDs (item vs currency) prompt you to choose. Items and currencies
  can be added; mounts, battle pets, transmog and knowledge are carried by the data
  model and counted, but nothing constructs them yet.
- **Persistent storage** — shift-click a tracked row to hide it (kept in storage).
  A searchable/filterable **Known items** window lists everything stored:
  shift-click a row to paste it into the add box.
- **Scope toggle** — counts per character (default) or summed account-wide.
- **ElvUI-skinnable** — registers an ElvUI plugin skin, gated behind a toggle.
- **Retail and Classic from one folder** — three TOCs (`_Mainline`, `_Mists`,
  `_Vanilla`); the client picks the matching one. Every flavor difference sits in
  `Core/Compat.lua`. See [Flavor support](#flavor-support).
- **No Ace3** — addon lifecycle, events, slash commands, saved variables,
  localization, the options panel and the Known items window all run directly on the
  Blizzard API. Only `LibStub`, `CallbackHandler-1.0`, `LibDataBroker-1.1` and
  `LibDBIcon-1.0` are embedded, and only for the minimap button.

## Usage
- `/tally` — open the add box
- `/tally known` — open the storage browser
- `/tally show` — toggle the on-screen tracker
- `/tally config` — open options (Game Menu → Options → AddOns → Tallymaster)
- Keybinds for all three under Key Bindings → Tallymaster.

## Flavor support

| | Midnight | Mists Classic | Classic Era |
|---|---|---|---|
| Items — bags, bank, mail, equipped | yes | yes | yes |
| Currencies by ID | yes | yes | no such system |
| Currencies by name, currency headers | yes | yes | no currency list |
| Mounts, battle pets | yes | yes | no such system |
| Transmog | yes | API present, no wardrobe | no such system |
| Crafting quality tiers | yes | no | no |

In Classic Era that leaves the item tracker, which is the whole of what vanilla has to
track. Where a system exists but holds nothing, the count is zero rather than an error.

## Status
`1.1.0`. See [design/DESIGN.md](design/DESIGN.md) for the full spec.

### Installing
`make install` (or `Makefile install` on Windows) copies the addon into the live
client. Pick the client with `FLAVOR`: `_retail_` (default), `_classic_` for Mists
Classic, `_classic_era_` for Vanilla. All three TOCs are installed either way, so one
copy works everywhere. Point it at the AddOns folder with `WOW_RETAIL_ADDON_FOLDER`:

```
export WOW_RETAIL_ADDON_FOLDER="/path/to/World of Warcraft/_retail_/Interface/AddOns"
make install
```

Without it, the Makefile falls back to `WOW_DIR` and then to auto-detection.
`WOW_RETAIL_ADDON_FOLDER` names the retail folder only. With a `FLAVOR` override the
Makefile tries `WOW_DIR` and auto-detection first, then looks for the other client
next to `_retail_` in the same WoW folder — so one variable also covers
`make install FLAVOR=_classic_` under Wine, where auto-detection finds nothing.

### Before first run
1. `make fetch-libs` to populate `Libs/` (see [Libs/README.md](Libs/README.md)).
2. The addon icon ships as `Media/Satchel.tga` (see [Media/README.md](Media/README.md)).
3. Confirm the `## Interface:` number in each `.toc` matches the live build of that
   flavor. `make check-tocs` only guards the TOCs against drifting apart from each
   other; it cannot know what the live clients are on.

## Building and installing
`Makefile` (GNU make) and `Makefile.bat` (plain Windows batch, no make/zip needed)
expose the same targets. The WoW folder is auto-detected; override it with
`WOW_DIR`, and pick another client with `FLAVOR=_classic_` or `FLAVOR=_classic_era_`.

| target | what it does |
|---|---|
| `check` | syntax-check every Lua file (`luac`, `lua`, or Python + `lupa`) |
| `check-tocs` | verify the three flavor TOCs differ only in `## Interface:`, and that every file they list exists |
| `lint` | `check` + `check-tocs` |
| `libs` | report which libraries `embeds.xml` expects but `Libs/` lacks |
| `fetch-libs` | download them into `Libs/` straight from `.pkgmeta` (needs `svn`, and `git` for LibDataBroker-1.1) |
| `install` | copy the addon into the live client; keeps the libraries already installed there and reports ones `embeds.xml` no longer lists |
| `uninstall` | remove the addon; SavedVariables are kept |
| `prune-libs` | delete those stale libraries from the installed copy |
| `stage` | build `dist/<expansion>/Tallymaster` for Midnight, Mists and Vanilla - each with only its own TOC, ready to copy into that client's `Interface/AddOns` |
| `dist` | build `dist/Tallymaster-<version>.zip` (all three TOCs in one folder) |
| `clean` / `distclean` | drop build output / also empty `Libs/` |
| `purge` | uninstall **and** delete SavedVariables; needs `CONFIRM=yes` |

```
make install                 # or:  Makefile install
make stage                   #      Makefile stage
make dist                    #      Makefile dist
make purge CONFIRM=yes       #      set "CONFIRM=yes" && Makefile purge
```

`stage` lays the builds out by expansion so they only have to be copied over:

```
dist/Midnight/Tallymaster  ->  _retail_/Interface/AddOns/
dist/Mists/Tallymaster     ->  _classic_/Interface/AddOns/
dist/Vanilla/Tallymaster   ->  _classic_era_/Interface/AddOns/
```

## Source layout
```
Core/      Addon (lifecycle/events/slash), Compat (retail/Classic API differences),
           Database, Core (init/minimap), Categories, Resolve, Counting
UI/        Tracker (on-screen list), AddInput, KnownList, Options
Skin/      ElvUI integration
Locales/   Locale (runtime), enUS, deDE
design/    spec, name candidates, icon SVGs (not shipped)
```

## Licence and credits

© 2026 incudex, Lars Gossard — <tallymaster@incudex.de>

Embedded libraries, each under its own licence: [LibStub](https://www.wowace.com/projects/libstub),
[CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler),
[LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1) and
[LibDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0). They are not vendored here;
`make fetch-libs` and the CI packager both pull them from the same source, [.pkgmeta](.pkgmeta).
See also [Libs/README.md](Libs/README.md).
