# Releasing

Two ways to publish. The automated one is preferred; the manual one is the
fallback when the workflow is unavailable.

## Project ids

| Site        | Id         | TOC field               |
| ----------- | ---------- | ----------------------- |
| CurseForge  | `1574454`  | `X-Curse-Project-ID`    |
| Wago Addons | `bGoyWq60` | `X-Wago-ID`             |

The packager reads both from `Tallymaster.toc`, so they never need to be
repeated in the workflow.

## Secrets (GitHub → Settings → Secrets and variables → Actions)

| Secret            | Where it comes from                                | Needed for      |
| ----------------- | -------------------------------------------------- | --------------- |
| `WAGO_API_TOKEN`  | wago.io → account settings → API keys              | Wago upload     |
| `CF_API_TOKEN`    | authors.curseforge.com → Settings → API Tokens      | CurseForge      |
| `GITHUB_TOKEN`    | provided by Actions automatically                  | GitHub release  |

Tokens belong in the repository secrets only - never in the TOC, the workflow
or any tracked file. A missing token just skips that upload target, so Wago can
go live before the CurseForge token exists.

## Automated release

1. Bump `## Version:` in `Tallymaster.toc` and add the section to `CHANGELOG.md`.
2. Commit, then tag and push:

       git tag -a v1.2.3 -m "Tallymaster 1.2.3"
       git push origin main
       git push origin v1.2.3

3. `.github/workflows/release.yml` runs `BigWigsMods/packager`, which pulls the
   libraries listed in `.pkgmeta`, builds the zip, cuts the changelog and
   uploads to every site it has a token for.

Only tags matching `v*` trigger it.

## Manual release

    Makefile.bat dist          # or: make dist

Builds `dist/Tallymaster-<version>.zip` from the working tree, including
whatever is in `Libs/` - so run `make libs` first and check the list. Upload it
by hand, pick the game version matching `## Interface:` and paste the release
notes into the changelog field.
