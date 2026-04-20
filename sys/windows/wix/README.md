# HanNetHack Windows Installer (WiX MSI)

This directory contains the [WiX Toolset v4](https://wixtoolset.org/) project
that produces the `.msi` installer shipped on GitHub Releases.

## Files

| File | Purpose |
|---|---|
| `Package.wxs` | Product definition (install layout, shortcuts, upgrade rules). |
| `License.rtf` | License text shown on the *License* page of the wizard. |
| `build-msi.cmd` | Local-build helper. Builds an MSI from `binary\` produced by `nmake package`. |

## Building the MSI locally

1. Build the game first so that `binary\` is fully populated:

   ```cmd
   _nh_win_build.bat
   ```

   (Or, manually: open a *x64 Developer Command Prompt for VS 2022*,
   `cd src`, then `nmake package`.)

2. Install the .NET SDK 6+ if you don't have it:
   <https://dotnet.microsoft.com/download>.

3. Build the MSI:

   ```cmd
   sys\windows\wix\build-msi.cmd 3.7.0.0
   ```

   The script will install the WiX v4 `dotnet` tool and the `WixToolset.UI.wixext`
   extension on first run. The MSI is written to
   `package\hannethack-<version>-win-x64.msi`.

## Cutting a release

Releases are produced automatically by `.github/workflows/release.yml`.

1. Bump translations / docs / version metadata if needed.
2. Tag the commit and push:

   ```bash
   git tag -a v3.7.0-han.20260420 -m "HanNetHack 3.7 build 2026-04-20"
   git push origin v3.7.0-han.20260420
   ```

3. Watch the *Actions → Release* run. On success it will:
   * Build the game on a clean `windows-latest` runner.
   * Compile the Korean `.mo` from `po/ko*.po`.
   * Run `nmake package` → `package\nethack-370-win-x64.zip` and
     `package\nethack-370-win-x64-debugsymbols.zip`.
   * Build the MSI via `sys\windows\wix\build-msi.cmd`.
   * Compute `SHA256SUMS.txt` for every artifact.
   * Create the GitHub Release and attach all artifacts.

The same workflow can be triggered manually via *Actions → Release →
Run workflow*; in that case the MSI/zip are uploaded as build
artifacts but no Release is created.

## Notes for maintainers

* `UpgradeCode` (in `Package.wxs`) **must never change** — it is what
  Windows Installer uses to identify successive versions of the same
  product. Only the `Version` argument changes between releases.
* MSI `Version` must be `Major.Minor.Build[.Revision]`, all numeric.
  Windows Installer ignores the *Revision* field for upgrade decisions,
  so use `Major.Minor.Build` for actual version bumps.
* The package layout mirrors `binary\` exactly via WiX v4's `<Files>`
  element.  To add or remove shipped files, change what `nmake package`
  produces — no edits to the WiX project are required.
* No code-signing certificate is configured. Add a signing step before
  the *Build MSI installer* step in `release.yml` once a certificate is
  available, e.g. via [`signtool sign /fd SHA256 /a /tr http://...`](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool).
