# Tallymaster

A World of Warcraft (Midnight) addon that keeps a live, on-screen list of items,
currencies and collectibles — icon, name and a running count — grouped by category,
much like Blizzard's *Track Recipe* feature.

Folder name and in-game title are both **Tallymaster**.

## Features
- **Live tracker** — always-on list, counts update in real time from bags, bank,
  equipped slots and mail. Grouped by category; groups fold. Sort alphabetically
  or by count.
- **Add by name or ID** — slash command, minimap button, or keybind opens an input
  box. Ambiguous IDs (item vs currency) prompt you to choose. Tracks items,
  currencies, mounts, battle pets, transmog (knowledge is stubbed).
- **Persistent storage** — shift-click a tracked row to hide it (kept in storage).
  A searchable/filterable **Known items** window lists everything stored:
  shift-click a row to paste it into the add box.
- **Scope toggle** — counts per character (default) or summed account-wide.
- **ElvUI-skinnable** — registers an ElvUI plugin skin, gated behind a toggle.
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

## Status
`1.0.0`. See [design/DESIGN.md](design/DESIGN.md) for the full spec.

### Before first run
1. Populate `Libs/` (see [Libs/README.md](Libs/README.md)).
2. The addon icon ships as `Media/Satchel.tga` (see [Media/README.md](Media/README.md)).
3. Confirm the `## Interface:` number in the `.toc` matches the live Midnight build.

## Building and installing
`Makefile` (GNU make) and `Makefile.bat` (plain Windows batch, no make/zip needed)
expose the same targets. The WoW folder is auto-detected; override it with
`WOW_DIR`, and pick another client with `FLAVOR=_classic_era_`.

| target | what it does |
|---|---|
| `check` | syntax-check every Lua file (`luac`, `lua`, or Python + `lupa`) |
| `libs` | report which libraries `embeds.xml` expects but `Libs/` lacks |
| `install` | copy the addon into the live client; keeps the libraries already installed there and reports ones `embeds.xml` no longer lists |
| `uninstall` | remove the addon; SavedVariables are kept |
| `prune-libs` | delete those stale libraries from the installed copy |
| `dist` | build `dist/Tallymaster-<version>.zip` |
| `clean` / `distclean` | drop build output / also empty `Libs/` |
| `purge` | uninstall **and** delete SavedVariables; needs `CONFIRM=yes` |

```
make install                 # or:  Makefile install
make dist                    #      Makefile dist
make purge CONFIRM=yes       #      set "CONFIRM=yes" && Makefile purge
```

## Source layout
```
Core/      Addon (lifecycle/events/slash), Database, Core (init/minimap),
           Categories, Resolve, Counting
UI/        Tracker (on-screen list), AddInput, KnownList, Options
Skin/      ElvUI integration
Locales/   Locale (runtime), enUS, deDE
design/    spec, name candidates, icon SVGs (not shipped)
```
