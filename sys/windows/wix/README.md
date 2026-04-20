# HanNetHack Windows Installer (WiX MSI)

This directory contains the [WiX Toolset v5](https://wixtoolset.org/) project
that can produce a `.msi` installer for HanNetHack on Windows x64.

> **Status — currently *not* published on GitHub Releases.**
>
> Unsigned MSIs trigger noticeably worse SmartScreen / "unknown publisher"
> warnings than unsigned portable executables (Windows treats running an
> installer as a higher-privilege action), and many users abandon installs
> at that prompt.  Until Authenticode code signing is in place
> (e.g. via [SignPath OSS](https://signpath.io/open-source) or
> [Azure Trusted Signing](https://learn.microsoft.com/azure/trusted-signing/)),
> the release workflow only ships the portable zip.
>
> The WiX project below is kept fully working so it can be re-enabled in
> `.github/workflows/release.yml` with no source changes the moment a
> signing certificate becomes available.

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

   The script will install the WiX v5 `dotnet` tool and the `WixToolset.UI.wixext`
   extension on first run. The MSI is written to
   `package\hannethack-<version>-win-x64.msi`.

## Re-enabling MSI publishing in CI

Once a code-signing certificate is available, restore the MSI pipeline by
adding these steps back into `.github/workflows/release.yml`, between the
*Verify build output* and *Compute SHA256 sums* steps:

```yaml
- name: Install WiX toolset
  shell: pwsh
  env:
    WIX_VERSION: '5.0.2'
  run: |
    dotnet tool install --global wix --version $env:WIX_VERSION
    "$env:USERPROFILE\.dotnet\tools" | Out-File -Append $env:GITHUB_PATH
    & "$env:USERPROFILE\.dotnet\tools\wix.exe" extension add -g `
        "WixToolset.UI.wixext/$env:WIX_VERSION"

- name: Build MSI installer
  shell: cmd
  run: call sys\windows\wix\build-msi.cmd <derived-version>

- name: Sign MSI + executables
  # ... signtool / SignPath / Azure Trusted Signing step here ...

- name: Rename MSI for release
  shell: pwsh
  run: |
    $src = Get-ChildItem package\hannethack-*.msi | Select-Object -First 1
    Move-Item $src.FullName "package\hannethack-${{ github.ref_name }}-win-x64.msi" -Force
```

Then add `package/*.msi` to both the `upload-artifact` and the
`softprops/action-gh-release` `files:` lists.

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
* No code-signing certificate is configured. Sign the MSI (and ideally
  the `.exe` files inside `binary\` *before* packaging the MSI, since
  the MSI embeds them) once a certificate is available, e.g. via
  [`signtool sign /fd SHA256 /a /tr http://...`](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool),
  [SignPath](https://signpath.io/open-source) (free for OSS), or
  [Azure Trusted Signing](https://learn.microsoft.com/azure/trusted-signing/).
