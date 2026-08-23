# Media/

The addon icon lives here as `Satchel.tga` (64x64, 32-bit uncompressed). It is used
in two places: the `## IconTexture` line in the `.toc` (in-game AddOn list) and the
minimap button (`ICON` in `Core/Core.lua`).

The source artwork is
[`design/icons/icon-07-satchel.svg`](../design/icons/icon-07-satchel.svg).

## Replacing it

WoW reads BLP and 32-bit TGA, not SVG or PNG, and wants power-of-two dimensions:

1. Render the SVG to PNG at 64x64 (or 256x256), e.g.
   `inkscape design/icons/icon-07-satchel.svg -w 256 -h 256 -o satchel.png`
   or any SVG->PNG tool.
2. Save it as 32-bit uncompressed TGA (GIMP/Photoshop) over `Satchel.tga`, or convert
   to BLP with **BLPConverter** and drop it in as `Satchel.blp`. Both extensions work;
   the paths in the `.toc` and in `Core/Core.lua` are given without one.
