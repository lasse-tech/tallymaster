# Tallymaster 1.0.0

Release notes for the CurseForge upload. Previous public file: **0.2.24-alpha**
(17 Jun 2026, WoW 12.0.7). This one is the first stable build and covers
0.2.25-alpha, 0.3.0-alpha and 1.0.0.

Game version: **12.1.0** (`## Interface: 120100`) · Release type: **Release**

---

**Tallymaster 1.0.0 — first stable release.**

### Fixed
- **Warband bank items were not counted.** `C_Item.GetItemCount` was missing the
  `includeAccountBank` parameter WoW 11.0 added, and the container scan still used
  the old `Enum.BagIndex.Bank` / `.Reagentbank` indices that Midnight replaced with
  per-tab ones, so `AccountBankTab_1..5` were never looked at.
- The minimap button showed Blizzard's generic bag icon instead of Tallymaster's own.
- The Known items window kept showing stale counts while it was open.

### Changed
- **Ace3 is gone.** The addon now runs directly on the Blizzard API — same
  SavedVariables layout, so your tracked entries carry over untouched. Options moved
  to Game Menu → Options → AddOns → Tallymaster.
- The options panel now opens with an about block (author, website, version).
- ElvUI skinning also covers the Add and Known items windows.
- Counts are computed once per refresh instead of once per sort comparison — much
  less work per update, especially with crafting-quality entries.
