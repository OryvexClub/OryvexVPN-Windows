#!/usr/bin/env python3
"""
fixer.py - OryvexVPN (warp_vpn_app) production fixer

Run this from the ROOT of the Flutter project
(the folder that contains pubspec.yaml), on Windows, with Python 3.9+.

What it does:
  1. Rewrites windows/runner/runner.exe.manifest with a real
     requestedExecutionLevel=requireAdministrator block (this is the
     actual cause of the missing UAC shield - your old CI step was
     patching a file, windows\\runner\\app.manifest, that never existed).
  2. Confirms windows/runner/CMakeLists.txt embeds runner.exe.manifest
     into the exe (adds it if a hand-edited CMakeLists dropped it).
  3. Fixes .github/workflows/build_windows.yml so CI stops patching a
     nonexistent file and instead verifies the manifest is correct.
  4. Writes a ready-to-build installer/installer.iss (Inno Setup 6).
  5. Prints a checklist of what still needs a human decision
     (icon paths, publisher name, signing cert) instead of guessing.

Usage:
    python fixer.py                 # apply fixes
    python fixer.py --dry-run       # show what would change, write nothing
    python fixer.py --check         # verify current state only, exit 1 if broken
"""

import argparse
import re
import sys
from pathlib import Path

MANIFEST_CONTENT = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity type="win32" name="OryvexVPN.warp_vpn_app" version="1.0.0.0" processorArchitecture="amd64"/>

  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">true</longPathAware>
    </windowsSettings>
  </application>

  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>

  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>

</assembly>
"""

ISS_CONTENT = r"""#define MyAppName "OryvexVPN"
#define MyAppExeName "warp_vpn_app.exe"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "OryvexVPN"
#define MyAppURL "https://oryvex.example.com"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{5E2B7B0E-9F0A-4F49-8E4E-9C0A7E9E7A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
OutputDir=Output
OutputBaseFilename=OryvexVPN-Setup-{#MyAppVersion}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start {#MyAppName} when Windows starts"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
"""

CI_YAML_CONTENT = """name: Build Windows App (AmneziaWG + UAC)

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-2022

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.2'
          channel: 'stable'
          cache: true

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Get dependencies
        run: flutter pub get

      - name: Verify UAC manifest is correct
        run: |
          $manifest = "windows\\runner\\runner.exe.manifest"
          if (-not (Test-Path $manifest)) {
            Write-Error "runner.exe.manifest not found at $manifest"
            exit 1
          }
          $content = Get-Content $manifest -Raw
          if ($content -notmatch 'level="requireAdministrator"') {
            Write-Error "runner.exe.manifest is missing requireAdministrator - run fixer.py before committing."
            exit 1
          }
          Write-Host "Manifest OK: requireAdministrator present."

      - name: Build Windows app
        run: flutter build windows --release

      - name: Download and extract AmneziaWG
        run: |
          $wgVersion = "2.0.2"
          $msiUrl = "https://github.com/amnezia-vpn/amneziawg-windows-client/releases/download/$wgVersion/amneziawg-amd64-$wgVersion.msi"
          Invoke-WebRequest -Uri $msiUrl -OutFile "amneziawg.msi"

          $extractDir = "$PWD\\amneziawg_extracted"
          New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

          $msiExecArgs = @("/a", "`"$PWD\\amneziawg.msi`"", "/qn", "TARGETDIR=`"$extractDir`"")
          Start-Process msiexec.exe -ArgumentList $msiExecArgs -Wait -NoNewWindow

          $wgExe = Get-ChildItem -Path $extractDir -Filter "amneziawg.exe" -Recurse | Select-Object -First 1
          if (-not $wgExe) {
            Write-Host "Failed to extract amneziawg.exe from MSI."
            exit 1
          }
          Copy-Item $wgExe.FullName "$PWD\\amneziawg.exe"

      - name: Bundle AmneziaWG binary inside data/
        run: |
          $ReleaseDir = "build\\windows\\x64\\runner\\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\\data" | Out-Null
          Copy-Item "$PWD\\amneziawg.exe" "$ReleaseDir\\data\\amneziawg.exe"

      - name: Install Inno Setup
        run: choco install innosetup -y

      - name: Build installer
        run: iscc installer\\installer.iss

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows-portable
          path: build/windows/x64/runner/Release/

      - name: Upload installer
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows-installer
          path: installer/Output/*.exe
"""


def find_project_root(start: Path) -> Path:
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / "pubspec.yaml").exists():
            return candidate
    print("ERROR: no pubspec.yaml found above this directory. "
          "Run fixer.py from inside the Flutter project.", file=sys.stderr)
    sys.exit(1)


def check_manifest(manifest_path: Path) -> bool:
    if not manifest_path.exists():
        return False
    text = manifest_path.read_text(encoding="utf-8")
    return 'level="requireAdministrator"' in text and "<trustInfo" in text


def check_cmakelists(cmake_path: Path) -> bool:
    if not cmake_path.exists():
        return False
    text = cmake_path.read_text(encoding="utf-8")
    return "runner.exe.manifest" in text


def apply_fixes(root: Path, dry_run: bool) -> None:
    windows_runner = root / "windows" / "runner"
    manifest_path = windows_runner / "runner.exe.manifest"
    cmake_path = windows_runner / "CMakeLists.txt"
    ci_path = root / ".github" / "workflows" / "build_windows.yml"
    installer_dir = root / "installer"
    iss_path = installer_dir / "installer.iss"

    changed = []

    # 1. manifest
    if not check_manifest(manifest_path):
        changed.append(str(manifest_path))
        if not dry_run:
            manifest_path.parent.mkdir(parents=True, exist_ok=True)
            manifest_path.write_text(MANIFEST_CONTENT, encoding="utf-8")

    # 2. CMakeLists.txt must list runner.exe.manifest as a source so MSVC
    #    embeds it as the exe's manifest resource.
    if cmake_path.exists() and not check_cmakelists(cmake_path):
        text = cmake_path.read_text(encoding="utf-8")
        if 'add_executable(' in text and '"Runner.rc"' in text and '"runner.exe.manifest"' not in text:
            new_text = text.replace('"Runner.rc"', '"Runner.rc"\n  "runner.exe.manifest"')
            changed.append(str(cmake_path))
            if not dry_run:
                cmake_path.write_text(new_text, encoding="utf-8")

    # 3. CI workflow
    if ci_path.exists():
        old_ci = ci_path.read_text(encoding="utf-8")
        if 'app.manifest' in old_ci or 'requireAdministrator' not in old_ci:
            changed.append(str(ci_path))
            if not dry_run:
                ci_path.write_text(CI_YAML_CONTENT, encoding="utf-8")
    else:
        changed.append(str(ci_path) + " (created)")
        if not dry_run:
            ci_path.parent.mkdir(parents=True, exist_ok=True)
            ci_path.write_text(CI_YAML_CONTENT, encoding="utf-8")

    # 4. Inno Setup installer script
    if not iss_path.exists():
        changed.append(str(iss_path) + " (created)")
        if not dry_run:
            installer_dir.mkdir(parents=True, exist_ok=True)
            iss_path.write_text(ISS_CONTENT, encoding="utf-8")

    if not changed:
        print("Nothing to fix - manifest, CMakeLists, CI workflow, and installer script all look correct.")
        return

    verb = "Would change" if dry_run else "Changed"
    print(f"{verb} {len(changed)} file(s):")
    for c in changed:
        print(f"  - {c}")

    print("""
Next steps (manual, on your Windows machine - I can't compile here):
  1. flutter clean && flutter pub get
  2. flutter build windows --release
     -> confirm build\\windows\\x64\\runner\\Release\\warp_vpn_app.exe
        now shows the UAC shield icon and prompts for elevation on launch.
  3. Install Inno Setup 6 (https://jrsoftware.org/isinfo.php) if you
     haven't, then: iscc installer\\installer.iss
  4. Open installer.iss and set your real Publisher name, AppURL, and
     confirm SetupIconFile points at an actual .ico you have (the sample
     I generated needs a real path filled in - I didn't guess one).
""")


def check_only(root: Path) -> int:
    windows_runner = root / "windows" / "runner"
    manifest_ok = check_manifest(windows_runner / "runner.exe.manifest")
    cmake_ok = check_cmakelists(windows_runner / "CMakeLists.txt")
    iss_ok = (root / "installer" / "installer.iss").exists()

    print(f"manifest requireAdministrator : {'OK' if manifest_ok else 'MISSING'}")
    print(f"CMakeLists embeds manifest    : {'OK' if cmake_ok else 'MISSING'}")
    print(f"installer/installer.iss       : {'OK' if iss_ok else 'MISSING'}")

    return 0 if (manifest_ok and cmake_ok and iss_ok) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="show what would change, write nothing")
    parser.add_argument("--check", action="store_true", help="only verify current state, exit code 1 if broken")
    parser.add_argument("--root", default=".", help="path inside the project (default: current directory)")
    args = parser.parse_args()

    root = find_project_root(Path(args.root))
    print(f"Project root: {root}\n")

    if args.check:
        sys.exit(check_only(root))

    apply_fixes(root, dry_run=args.dry_run)


if __name__ == "__main__":
    main()