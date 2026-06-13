# Media/

The addon expects an icon at `Media\Satchel.blp` (or `.tga`). The chosen design is
[`design/icons/icon-07-satchel.svg`](../design/icons/icon-07-satchel.svg).

WoW does not read SVG or PNG — convert to BLP or 32-bit TGA, power-of-two size
(64×64 recommended for an icon):

1. Render the SVG to PNG at 64×64 (or 256×256), e.g.
   `inkscape design/icons/icon-07-satchel.svg -w 256 -h 256 -o satchel.png`
   or any SVG→PNG tool.
2. Convert to BLP with **BLPConverter** (or save as 32-bit uncompressed TGA from
   GIMP/Photoshop) and place it here as `Satchel.blp`.

Until that file exists, the addon falls back to the Blizzard icon
`Interface\Icons\INV_Misc_Bag_10` (see `FALLBACK_ICON` in `Core/Core.lua`) and the
`## IconTexture` line in the `.toc` will simply be ignored for the missing file.
After adding `Satchel.blp`, switch `FALLBACK_ICON` -> `PLACEHOLDER_ICON` in
`Core/Core.lua` for the minimap button.
