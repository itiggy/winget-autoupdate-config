# Winget-AutoUpdate Config (5-Day Release Maturity Filter & Custom Mods)

Centralized management repository for [Winget-AutoUpdate (WAU)](https://github.com/Romanitho/Winget-AutoUpdate). This repository dynamically generates an `excluded_apps.txt` file containing package IDs of software updated within the last **5 days** (release maturity), hosts custom post-install/pre-install **Mods**, and provides a web Site Index hub with standardized installation scripts.

> 🌐 **Web Site Index Hub:** [https://itiggy.github.io/winget-autoupdate-config/](https://itiggy.github.io/winget-autoupdate-config/)  
> Visit the Site Index to download both installer files (`install.cmd` + `install.ps1`) with **1-click**, copy terminal installation snippets, or view live rule statistics.

---

## 🚀 How It Works

The generated `excluded_apps.txt` is compiled automatically **every 288 minutes (~5 hours)** (00:07, 04:55, 09:43, 14:31, 19:19 UTC) using a 3-layer approach:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: WAU Default Exclusions                             │
│ Downloaded from WAU repo (with local cached fallback)       │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Custom User Exclusions                             │
│ Static list defined in config/user_excluded_apps.txt        │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: 5-Day Release Maturity Filter                      │
│ Dynamically fetched from microsoft/winget-pkgs GitHub API   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   list/excluded_apps.txt
```

1. **Layer 1 (Default Exclusions)**: Downloads official default exclusions from WAU repository (e.g. browsers, Office, Teams). If unreachable, uses local cache in [`config/default_excluded_apps.txt`](file:///home/larsickler/projects/winget-autoupdate-config/config/default_excluded_apps.txt).
2. **Layer 2 (User Exclusions)**: Custom blocked apps defined in [`config/user_excluded_apps.txt`](file:///home/larsickler/projects/winget-autoupdate-config/config/user_excluded_apps.txt).
3. **Layer 3 (5-Day Rule)**: Queries GitHub API for commits to `microsoft/winget-pkgs` within the last 5 days and extracts package IDs.

---

## 📁 Repository Structure

- [`index.html`](file:///home/larsickler/projects/winget-autoupdate-config/index.html): Web Site Index dashboard served via GitHub Pages.
- [`list/excluded_apps.txt`](file:///home/larsickler/projects/winget-autoupdate-config/list/excluded_apps.txt): Compiled exclusion file fetched by WAU (`LISTPATH`).
- [`mods/`](file:///home/larsickler/projects/winget-autoupdate-config/mods): Custom PowerShell scripts for pre/post-installation tasks (`MODSPATH`).
- [`config/user_excluded_apps.txt`](file:///home/larsickler/projects/winget-autoupdate-config/config/user_excluded_apps.txt): File for your permanent custom app exclusions.
- [`config/default_excluded_apps.txt`](file:///home/larsickler/projects/winget-autoupdate-config/config/default_excluded_apps.txt): Cached fallback copy of WAU default exclusions.
- [`install/install.cmd`](file:///home/larsickler/projects/winget-autoupdate-config/install/install.cmd) & [`install/install.ps1`](file:///home/larsickler/projects/winget-autoupdate-config/install/install.ps1): One-click installer scripts configured with remote GitHub Pages URLs.
- [`scripts/Update-ExcludedApps.ps1`](file:///home/larsickler/projects/winget-autoupdate-config/scripts/Update-ExcludedApps.ps1): PowerShell 5.1 script generating the exclusion list and updating site stats.
- [`.github/workflows/update-excluded-apps.yml`](file:///home/larsickler/projects/winget-autoupdate-config/.github/workflows/update-excluded-apps.yml): GitHub Action workflow (runs every 288 minutes off-peak).

---

## ⚙️ Winget-AutoUpdate Configuration (`LISTPATH` & `MODSPATH`)

To configure Winget-AutoUpdate on client PCs to fetch your rules and mods:

- **LISTPATH:**
  ```text
  https://itiggy.github.io/winget-autoupdate-config/list/
  ```
- **MODSPATH:**
  ```text
  https://itiggy.github.io/winget-autoupdate-config/mods/
  ```

---

## 🛠️ Workstation Download & Installation

### Option 1: 1-Click Download via Site Index (Web Browser)
Visit [https://itiggy.github.io/winget-autoupdate-config/](https://itiggy.github.io/winget-autoupdate-config/) and click **"Download Installer Bundle (cmd + ps1)"**.  
Both `install.cmd` and `install.ps1` will be downloaded cleanly to your downloads folder with exact **UTF-8 / UTF-8 BOM** and **CRLF (`\r\n`)** encodings.

Double-click `install.cmd` (auto-elevates to Administrator).

### Option 2: Direct Terminal Download (PowerShell)
Run this command in Windows PowerShell:
```powershell
'cmd', 'ps1' | ForEach-Object { Invoke-WebRequest -UseBasicParsing -Uri "https://itiggy.github.io/winget-autoupdate-config/install/install.$_" -OutFile "install.$_" }
```

### Run Generator Locally
```powershell
pwsh ./scripts/Update-ExcludedApps.ps1 -DaysThreshold 5 -Verbose
```
