# Tallymaster — Design spec

Target: World of Warcraft **Midnight** (retail). Status: design locked, pre-implementation.
Last updated: 2026-06-13.

## Core feature
A live, on-screen list (like Blizzard's *Track Recipe*) showing tracked entries with icon,
name, and a live count. Counts update in real time from the player's holdings.

## Trackable types
Items, currencies, mounts, transmog, battle pets, profession knowledge — "all of them".
Each type resolves via its own API but is normalized into a common `TrackedEntry`.

## Count scope (live count source)
Counts aggregate from: **bags + bank + equipped + mail**.
- Bank and mail are only fully readable while their frames are open → cache last-known
  per-source counts and refresh on the relevant events; show cached value otherwise.
- Scope is **toggleable in the addon window**; default = **per character**.
  Account-wide mode caches each character's per-source counts and sums them.

## Add flow
- Opened via slash command, minimap icon, or user keybind.
- Input field accepts item/currency/etc. **name or ID**.
- On an **ambiguous numeric ID** (same number valid as item and currency), **ask the user** which type.
- Uncached items return nil from GetItemInfo on first call → show "loading…" and resolve on
  `GET_ITEM_INFO_RECEIVED`.
- Found entry is appended to the on-screen tracker AND saved to internal storage.

## Storage & removal
- Entries stored by **immutable ID** (+ type namespace). Renaming never changes the ID.
- **Shift-click** an on-screen row → removed from the visible tracker, **kept in storage**.
- A separate **known-items list** (scroll + search + filter) shows everything in storage:
  - shift-click → pastes the entry's name into the add input box
  - right-click → context menu: **Delete** (purge from storage) and **Rename**.

## Rename
- User-supplied custom name stored alongside the original.
- **On-screen tracker:** shows **custom name only**.
- **Known-items list:** shows `Custom name (Original name)`.

## Categories
- Every entry has a `category` field.
- **Default (auto):** the item's **top-level type** (itemType: Armor / Consumable / Tradegoods / …),
  via `C_Item.GetItemInfoInstant`. Currencies default to their currency-list header; other
  types default to a fixed label ("Mounts", "Transmog", "Pets", "Knowledge").
- User can override: pick an existing category or type a **custom** one.
- **Uncategorized** entries (no auto-value, user-cleared) collect under an "Uncategorized"
  folding group at the bottom.
- On-screen list is **grouped by category**; groups are **foldable** (fold state persisted).
- **Category scope:** account-wide (assignments + custom categories shared across all
  characters) even when counts are per-character.

## Sorting
Within each category group, toggle between **alphabetical** and **by count**. No manual drag.

## ElvUI compatibility (skinnable)
- Build widgets from standard Blizzard templates (UIPanelButtonTemplate, InputBoxTemplate,
  WowScrollBox + MinimalScrollBar, UICheckButtonTemplate, BackdropTemplate) with stable names.
- Ship a registered ElvUI skin via LibElvUIPlugin-1.0 (EP:RegisterPlugin) that strips textures,
  applies SetTemplate, and calls S:HandleButton / HandleEditBox / HandleCloseButton /
  HandleTrimScrollBar / HandleCheckBox / HandleIcon. Gate on E.private.skins.misc.enable
  and an in-addon "Allow ElvUI skinning" toggle.
- Render each row icon as a bare texture + separate border frame so HandleIcon can reskin it.
- Embed LibStub + LibElvUIPlugin-1.0; no hard dependency on ElvUI.

## Open implementation choices (decide at scaffold time)
- Ace3 (AceDB/AceConfig/AceGUI) vs. hand-rolled SavedVariables + Blizzard widgets.
- Minimap button: LibDBIcon-1.0 (+ LibDataBroker) vs. custom.
- Final addon name + chosen icon (see name-candidates.txt, design/icons/).
