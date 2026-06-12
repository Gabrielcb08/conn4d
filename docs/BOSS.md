# Boss

[Boss](https://github.com/HashLoad/boss) is the recommended package manager for installing and updating Conn4D.

## Install

```bash
# Pin to a release tag (recommended for production projects)
boss install https://github.com/gabrielcb08/conn4d@v0.3.0-alpha.1

# Latest commit on default branch (only for experimentation)
boss install https://github.com/gabrielcb08/conn4d
```

Boss clones the repo into `./modules/conn4d`, resolves transitive dependencies (Spring4D + DUnitX), and patches your project's search paths so `uses Conn4D;` works out of the box.

**Spring4D** is a required dependency: Conn4D links `Spring.Base` / `Spring.Core` (used internally by `TConn4DContainer` for provider resolution). Boss pulls the `andriwsluna/Spring4D` fork declared in `boss.json` automatically.

## Automated build (`postinstall`)

`boss.json` declares a `postinstall` hook that runs `scripts/boss-build.ps1` right after dependencies are resolved, so a fresh `boss install` leaves the library compiled with no manual IDE step. It builds (Win32, Release):

- **Spring4D core** — `Spring.Base` and `Spring.Core` (Conn4D links them)
- **Runtime package** — `Conn4D.dproj`
- **Design-time package** — `dclConn4D.dproj`

Artifacts (`.dcp` / `.bpl` / `.dcu`) go to `bin\Win32` inside the repo, so nothing pollutes the global RAD Studio directories.

**Requirements**
- RAD Studio / Delphi **12 Athens (23.0)** — auto-detected via the `BDS` env var → Windows registry → the default `…\Studio\23.0` path.
- `git` on PATH (only as a fallback, to fetch Spring4D source if `modules/Spring4D/repo/Source` is missing).

Run it manually (e.g. after pulling changes):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/boss-build.ps1
```

To skip the build, remove the `scripts.postinstall` entry from `boss.json` (or set `$BuildSpringCore = $false` in the script to skip only the Spring step).

> **Win64 is out of scope.** Design-time packages are 32-bit (the IDE is a 32-bit process), and Win64 `dcc64` builds hit the 32 000-char command-line limit when the machine's global Win64 library path is long. Build Win64 from the IDE if you need it.
>
> **Close RAD Studio** (or uninstall the package from the IDE) before running, otherwise the `.bpl` write can fail with `F2039` (file locked).

## Update

```bash
# Refresh to the latest commit / tagged version declared in boss.json
boss update https://github.com/gabrielcb08/conn4d
```

To move to a different pinned version, edit `boss.json` and re-run `boss install`.

## Validate from a Clean Consumer Project

```bash
mkdir conn4d-smoke
cd conn4d-smoke
boss init -q
boss install https://github.com/gabrielcb08/conn4d@v0.3.0-alpha.1
```

Then drop a 10-line `.dpr` importing `Conn4D` to confirm the integration:

```delphi
program Smoke;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  Conn4D;
begin
  TConn4D.Configure
    .Pool('smoke')
      .Host('127.0.0.1').Port(3050)
      .Database('test.fdb').UserName('SYSDBA').Password('masterkey')
      .DriverID('FB')
    .Apply;
  Writeln(TConn4D.PoolExists('smoke'));  // TRUE
  TConn4D.Shutdown;
end.
```

If it compiles and prints `TRUE`, the install is good.

## Package metadata

Package metadata is declared in `boss.json` at the repo root:

```json
{
  "name": "conn4d",
  "description": "Provider-neutral connection management library for Delphi 12 (FireDAC adapter included). Named pools, RAII handles and transactions, background sweep — no SQL execution, no ORM, no Spring4D.",
  "version": "0.3.0-alpha.1",
  "homepage": "https://github.com/gabrielcb08/conn4d",
  "mainsrc": "./src",
  "projects": [
    "./packages/Delphi12/Conn4D.dproj",
    "./tests/Conn4D.Tests/Conn4D.Tests.dproj",
    "./samples/BasicUsage/BasicUsage.dproj",
    "./samples/AdvancedUsage/AdvancedUsage.dproj"
  ],
  "dependencies": {
    "github.com/VSoftTechnologies/DUnitX": "^1.0.0"
  }
}
```

## Release Workflow

Use semantic tags in the format `vX.Y.Z` or `vX.Y.Z-alpha.N`, always aligned with the `version` field in `boss.json`.

```bash
# 1) Update version + changelog, then commit
git add boss.json CHANGELOG.md docs/CHANGELOG.md README.md README.pt-BR.md docs/BOSS.md
git commit -m "release: v0.3.0-alpha.1"

# 2) Create an annotated tag
git tag -a v0.3.0-alpha.1 -m "Conn4D v0.3.0-alpha.1"

# 3) Push branch and tags
git push origin main
git push origin --tags
```

## Publish Checklist

1. Bump `version` in `boss.json`.
2. Move the corresponding section in [CHANGELOG.md](../CHANGELOG.md) and [docs/CHANGELOG.md](CHANGELOG.md) out of `Unreleased`, dating it with the release day.
3. Run the full test suite (`Conn4D.Tests.exe --console`) — must return `0`.
4. Build all sample projects to catch any compile breakage from API changes.
5. Commit the release changes.
6. Tag (annotated) with `vX.Y.Z` or `vX.Y.Z-alpha.N`.
7. Push branch + tags.
8. Validate `boss install https://github.com/gabrielcb08/conn4d@<tag>` from a clean workspace.
9. Cut a GitHub Release pointing at the tag and pasting the changelog block as the release notes.
