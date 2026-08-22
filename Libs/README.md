# Libs/

These libraries are **not** vendored in the repo. They are pulled automatically by
the BigWigs/CurseForge packager from [`.pkgmeta`](../.pkgmeta) at release time.

Tallymaster does **not** use Ace3. Everything Ace3 used to provide (addon lifecycle,
events, chat commands, saved variables, localization, options panel, list window) is
implemented directly against the Blizzard API. The remaining libraries exist only
because `LibDBIcon-1.0` needs them for the minimap button.

For **local testing** in your WoW client you must drop them in here manually, so the
folder layout matches `embeds.xml`:

```
Libs/
  LibStub/LibStub.lua
  CallbackHandler-1.0/CallbackHandler-1.0.xml
  LibDataBroker-1.1/LibDataBroker-1.1.lua
  LibDBIcon-1.0/LibDBIcon-1.0.lua
  LibElvUIPlugin-1.0/LibElvUIPlugin-1.0.lua   (optional; from current ElvUI)
```

Fastest way to get them: copy these folders out of any existing addon that already
embeds them, or download the latest from wowace.com / curseforge.com.
`LibElvUIPlugin-1.0` is optional — if missing, ElvUI skinning falls back to a direct
call and everything else still works.
