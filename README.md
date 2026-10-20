# Tallymaster

A World of Warcraft addon that keeps a live, on-screen list of items and currencies —
icon, name and a running count — grouped by category, much like Blizzard's
*Track Recipe* feature.

Runs on **Midnight** (retail), **Mists Classic** and **Classic Era** from one folder.

## Features
- **Live tracker** — counts update from bags, bank, equipped slots and mail. Grouped by
  category; groups fold. Sort alphabetically or by count.
- **Add by name or ID** — slash command, minimap button or keybind. Ambiguous IDs
  (item vs currency) ask which one you mean.
- **Known items** — every entry ever added, searchable and filterable. Shift-click a
  tracker row to hide it, shift-click a Known items row to add it again.
- **Scope** — counts per character (default) or summed account-wide.
- **ElvUI skin** — optional, toggled in the options.

## Usage
- `/tally` — open the add box
- `/tally known` — open the Known items window
- `/tally show` — toggle the tracker
- `/tally config` — open the options
- Keybinds for all three under Key Bindings → Tallymaster.

## Flavor support

| | Midnight | Mists Classic | Classic Era |
|---|---|---|---|
| Items — bags, bank, mail, equipped | yes | yes | yes |
| Currencies by ID | yes | yes | — |
| Currencies by name, currency headers | yes | yes | — |
| Crafting quality tiers | yes | — | — |

## Building

`make help` (or `Makefile help` on Windows) lists every target and variable.

```
make fetch-libs              # download the embedded libraries into Libs/
make install                 # copy the addon into the live client
make stage                   # dist/<expansion>/Tallymaster, one folder per client
make lint                    # Lua syntax, TOCs, luacheck, Makefile comments
```

## Licence and credits

MIT — see [LICENSE](LICENSE). © 2026 lasse tech, Lars Gossard — <lars@lasse-tech.de>

Embedded libraries, each under its own licence:
[LibStub](https://www.wowace.com/projects/libstub),
[CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler),
[LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1) and
[LibDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0).
