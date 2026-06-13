# Changelog

All notable changes to Tallymaster are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.15-alpha] - 2026-06-13

### Fixed
- The Add window opened behind the Known items window when shift-clicking a row to
  paste. It now uses the same FULLSCREEN_DIALOG strata and is raised on open.

## [0.2.14-alpha] - 2026-06-13

### Added
- The Add window now shows the item's icon next to the details.

### Fixed
- The sell-price coin icon is sized to the details font so it aligns with the text
  (was using the default 14px size).

## [0.2.13-alpha] - 2026-06-13

### Removed
- The right-click context menu in the Known items list (and its Rename/Delete
  actions). Item and category renaming is no longer possible; `DisplayName` now
  always returns the original name. Note: this also removes the only Delete UI.

## [0.2.12-alpha] - 2026-06-13

### Added
- Hovering an item in the Known items window now shows the same tooltip as the
  tracker (item info + per-character count breakdown), respecting the "Show item
  tooltip" and "Show counts in tooltip" settings. The tooltip logic is now shared.

## [0.2.11-alpha] - 2026-06-13

### Added
- Settings option "Show counts in tooltip" (default on) to show/hide the
  per-character count breakdown within the tracker tooltip, independently of the
  tooltip itself.

## [0.2.10-alpha] - 2026-06-13

### Fixed
- Bindings.xml failed to parse (a double hyphen inside an XML comment is illegal),
  so no keybindings registered and the section disappeared entirely. Reworded the
  comment; the "Tallymaster" keybindings section is back.

## [0.2.9-alpha] - 2026-06-13

### Changed
- The per-character (per-realm) count breakdown in the tracker tooltip is now shown
  regardless of the count scope, including when set to Per character.

## [0.2.8-alpha] - 2026-06-13

### Changed
- Account-wide tooltip: the header is now the addon name ("Tallymaster") instead of
  "Account-wide", and characters are grouped under realm headers with the realm
  stripped from each character name.

## [0.2.7-alpha] - 2026-06-13

### Added
- Tracker tooltips now list each character's count and the total when the count
  scope is Account-wide.
- Settings option "Show item tooltip" (default on) to enable/disable the tracker
  hover tooltip.

## [0.2.6-alpha] - 2026-06-13

### Fixed
- Keybindings now appear in their own "Tallymaster" section of the Key Bindings UI
  (instead of under "Other" with a stray HEADER_TALLYMASTER row). This needs the
  `category` attribute in Bindings.xml, which re-introduces a cosmetic
  "Unrecognized XML attribute: category" schema-validation warning — the same one
  every addon with binding categories (RaiderIO, BagSync, ...) produces; harmless.

## [0.2.5-alpha] - 2026-06-13

### Fixed
- Account-wide counting now works. Each character records its count for every
  known entry on refresh (not only the items it is itself tracking), so the
  account-wide total includes all characters. Previously a character only
  contributed for items visible on its own tracker, so the sum omitted others.

## [0.2.4-alpha] - 2026-06-13

### Added
- An "Add" button in the Add window (bottom-right), doing the same as pressing
  Enter. Skinned by ElvUI when active.

## [0.2.3-alpha] - 2026-06-13

### Fixed
- Known items: the sort-direction indicator showed as a broken glyph (Unicode
  arrow with no font glyph); replaced with an arrow texture.
- Known items: added a divider line so the column header no longer visually
  merges with the first row.

## [0.2.2-alpha] - 2026-06-13

### Added
- Settings option "Group by category" (default on). When off, the tracker shows a
  single flat list (sorted by the current sort order) instead of category groups.

## [0.2.1-alpha] - 2026-06-13

### Fixed
- The tracker now remembers its position across sessions once dragged.
- Collapsing/expanding a group now resizes the tracker downward only, keeping its
  position fixed (previously the center-anchored frame shifted when it resized).
  The frame is TOPLEFT-anchored and its position is saved on drag.

## [0.2.0-alpha] - 2026-06-13

### Added
- Item detail capture: when an item is added (typed, by ID, or shift-clicked), the
  Add window now shows a details panel — quality (rarity + crafting tier), item
  level & type/subtype, stack size & sell price, expansion & bind type — and these
  are stored on the entry. Details preview live as you type and on shift-click.
- Crafting-quality handling. A "Respect quality" checkbox appears for items that
  have a crafting tier:
  - Off (default): the entry counts **any quality** of the item, summed across all
    tiers (sibling tiers discovered by name across your containers).
  - On: the entry counts **only that exact tier**. The tracked entry then shows the
    tier star in the tracker and Known items list.

### Fixed
- (carried from 0.1.21) Shift-clicking a quality item no longer pastes the tier
  atlas markup into the box.

## [0.1.21-alpha] - 2026-06-13

### Fixed
- Shift-clicking an item with a crafting quality (Tier 1-3 stars) pasted the inline
  atlas markup into the box, so the item couldn't be resolved. The pasted name now
  strips inline escapes (atlas |A..|a, textures |T..|t, colour codes).

## [0.1.20-alpha] - 2026-06-13

### Added
- The Known items window now has two columns (icon+name | count) with clickable
  column headers: click "Name" or "Count" to sort by it, click again to reverse.
  Name defaults to A→Z, Count to highest-first; the active header shows an arrow.

## [0.1.19-alpha] - 2026-06-13

### Changed
- Minimap icon clicks rearranged: left-click opens the Add window, Shift-click
  toggles the tracker, Ctrl-click opens Known items, Right-click opens Options.
  Tooltip updated; the empty-tracker hint again lists the minimap as an add method.

## [0.1.18-alpha] - 2026-06-13

### Added
- Click the tracker's background/title to open the Add window; Shift+left-click
  hides the tracker. Dragging to move is no longer mistaken for a click. (Rows
  keep their per-entry shift-click-to-hide behaviour.)

## [0.1.17-alpha] - 2026-06-13

### Fixed
- Key Bindings UI showed raw tokens (HEADER_TALLYMASTER, TALLYMASTER_OPEN_ADD, ...).
  Defined the `BINDING_HEADER_TALLYMASTER` and `BINDING_NAME_*` globals so the header
  and each action show readable, localized names ("Tallymaster", "Open Add window",
  "Toggle tracker", "Toggle known items").

## [0.1.16-alpha] - 2026-06-13

### Fixed
- Item categories were stored as a numeric classID instead of the type name
  (e.g. a Consumable showed up under category "0"). `Categories:Auto` now reads the
  2nd return of `GetItemInfoInstant` (itemType) rather than the 6th (classID).
- Added `DB:RepairCategories()` (run on enable) to re-derive proper categories for
  entries already saved with a numeric category from the old bug.

## [0.1.15-alpha] - 2026-06-13

### Fixed
- Shift-clicking an item while the Add window is open no longer pops up the
  stack-split amount picker; it just copies the name (StackSplitFrame is suppressed
  while the Add window is shown).

## [0.1.14-alpha] - 2026-06-13

### Changed
- The minimap icon's left-click now toggles the on-screen tracker (was: open Add
  window). Add moved to Ctrl-click; Shift-click (Known items) and Right-click
  (Options) are unchanged. Tooltip updated accordingly. The empty-tracker hint no
  longer lists the minimap as an add method.

## [0.1.13-alpha] - 2026-06-13

### Added
- Shift-clicking the tracker's background/title now hides the whole tracker. (Rows
  keep their existing shift-click behaviour of hiding that single entry.)

## [0.1.12-alpha] - 2026-06-13

### Changed
- The empty-tracker hint now also tells the user that, with the Add window open,
  Shift-clicking an item in their bags copies its name into the input box.

## [0.1.11-alpha] - 2026-06-13

### Changed
- The empty-tracker hint now also mentions clicking the minimap icon as a way to
  open the Add window, alongside /tally and the Add keybinding.

## [0.1.10-alpha] - 2026-06-13

### Fixed
- Reworked Add-window focus handling (the 0.1.9 Escape approach didn't release the
  keyboard). Root cause was `SetAutoFocus(true)`, which kept re-grabbing the
  keyboard. Now: auto-focus is off (the box is focused explicitly on open for
  immediate typing); clicking anywhere outside the window releases keyboard focus so
  game keybinds like opening bags work again (via `GLOBAL_MOUSE_DOWN`); and Escape
  closes the window. Also start the frame hidden so the first toggle opens it.

## [0.1.9-alpha] - 2026-06-13

### Changed
- The Add window no longer holds the keyboard hostage. It still auto-focuses for
  immediate typing, but pressing Escape now releases keyboard focus (so game
  keybinds like opening bags work again) while keeping the window open; a second
  Escape closes it (registered via `UISpecialFrames`).

## [0.1.8-alpha] - 2026-06-13

### Added
- The tracker now shows a how-to-add hint ("No items tracked yet. Type /tally or use
  the Add keybinding...") instead of an empty list when nothing is tracked yet.

## [0.1.7-alpha] - 2026-06-13

### Added
- Shift-clicking an item or currency while the Add window is open now pastes that
  item's name into the input field (via a `HandleModifiedItemClick` hook).

## [0.1.6-alpha] - 2026-06-13

### Changed
- Enlarged the Add window and moved the instruction text into the input box as a
  proper placeholder, so it is no longer clipped/unreadable. The placeholder hides
  as soon as you start typing.

## [0.1.5-alpha] - 2026-06-13

### Fixed
- Fixed `Binding header TALLYMASTER was attempted to be loaded more than once`. The
  `header` attribute defines a Key Bindings UI header row and belongs only on the
  first binding of a group; it is now declared once on `TALLYMASTER_OPEN_ADD` and
  removed from the other two bindings in `Bindings.xml`.

## [0.1.4-alpha] - 2026-06-13

### Fixed
- Stopped embedding `LibElvUIPlugin-1.0`, which raised an `Error loading ... 
  LibElvUIPlugin-1.0.lua` whenever ElvUI was absent (the library requires ElvUI to
  load). It is now removed from `embeds.xml` and `.pkgmeta`. `Skin/ElvUI.lua` already
  resolves it at runtime via `LibStub("LibElvUIPlugin-1.0", true)` — which ElvUI
  registers itself when installed — and no-ops gracefully when ElvUI is absent.

## [0.1.3-alpha] - 2026-06-13

### Fixed
- Removed the obsolete `PLAYERREAGENTBANKSLOTS_CHANGED` event registration in
  `Core/Counting.lua`. That event was removed in patch 11.2 when the standalone
  Reagent Bank was replaced by tabbed banks, causing Ace3 to error on registration.
  Reagent items now live in regular bank tabs, whose updates are still caught by the
  existing `BAG_UPDATE_DELAYED` and `PLAYERBANKSLOTS_CHANGED` handlers.

## [0.1.2-alpha] - 2026-06-13

### Fixed
- Fixed keybinding actions throwing `unexpected symbol near '/'`. Binding bodies in
  `Bindings.xml` run as raw Lua, so the `/run` chat-command prefix was invalid;
  the bindings now call `Tallymaster_Binding(...)` directly.

## [0.1.1-alpha] - 2026-06-13

### Fixed
- Removed the unrecognized `category` XML attribute from `Bindings.xml`, which raised
  `Unrecognized XML attribute: category` (and a cascading `Unrecognized XML: Binding`)
  warnings on load. Bindings are grouped via the `header` attribute instead.

## [0.1.0-alpha]

### Added
- Initial alpha release: live on-screen tracker for items, currencies and
  collectibles, grouped by category.
