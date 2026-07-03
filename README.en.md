# openwrt-luci-theme-proton2025

Installer for the **Proton2025** theme ([luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)) for LuCI on **OpenWrt 25 (apk)**: a single interactive script that figures out the exact latest `.apk` name from GitHub, downloads it, installs it, makes the theme active, and removes it just as cleanly — no manual commands or filename guessing.

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.x%20(apk)-blue)](https://openwrt.org)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-green)](proton2025.sh)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

[Русский](README.md) · **English** · [中文](README.zh.md)

---

`proton2025.sh` is a small menu: install/update the theme, show status, remove it. The `.apk` filename in releases changes per version and carries a build number, so typing it by hand is awkward — the script finds the current file itself.

### Why

Starting with OpenWrt 24.10 and snapshots, the project moved from the **opkg** package manager (`.ipk`) to **apk** (`.apk`). The Proton2025 theme is not in the official feed — its releases live on GitHub. The author's instructions suggest installing the `.apk` with a wildcard command:

```
wget .../releases/latest/download/luci-theme-proton2025-*.apk
apk add --allow-untrusted luci-theme-proton2025-*.apk
```

The catch: `wget` does **not** expand `*` in a URL — the asterisk is sent to the server literally, no such file exists, and the download fails with **404**. Then `apk add` gets a non-existent local glob and complains `no such package`. You are expected to substitute the exact filename from the release yourself (e.g. `luci-theme-proton2025-1.1.2-r1.apk`). This script removes that chore: it asks GitHub for the **exact** URL of the latest `.apk`, downloads it, installs it via `apk add --allow-untrusted`, and switches LuCI to Proton2025 in one go.

### What the script does

On launch it shows a `[1-4]` menu:

1. **Install / update the theme** — resolves the latest [luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025) release, finds the exact `.apk` URL, downloads it to `/tmp`, installs it with `apk add --allow-untrusted`, then sets `luci.main.mediaurlbase='/luci-static/proton2025'` and restarts `uhttpd`. The same option updates the theme — it always pulls the newest version.
2. **Show status** — prints the active theme (`mediaurlbase`) and whether the `luci-theme-proton2025` package is installed, with its version.
3. **Remove the theme** — restores the default `bootstrap` theme, removes the package via `apk del`, restarts `uhttpd`.
4. **Exit**.

The release link is resolved two ways: first via the **GitHub API** (fast), and if that's unavailable or rate-limited, via the **releases Atom feed + expanded_assets** (no rate limit). Neither needs `jq` — JSON and HTML are parsed with plain `grep`/`sed`. Works with either `curl` or `wget`.

### Requirements

- OpenWrt **25.x** with the **apk** package manager (for opkg builds, install the `.ipk` per the theme author's instructions).
- **Internet on the router** at install time — the theme package is downloaded from GitHub.
- Working **HTTPS** with certificates (`ca-bundle` / `ca-certificates`).
- **SSH** access and root privileges.

### Installation

Run **on the router** (over SSH):

```
wget https://raw.githubusercontent.com/lastik9/openwrt-luci-theme-proton2025/main/proton2025.sh
sh proton2025.sh
```

Pick option **1** in the menu. After installing, refresh LuCI in the browser with **Ctrl+F5** (otherwise the old CSS stays cached).

Settings live in variables at the top of the script: theme repo, package name, `mediaurlbase` path — tweak them in one place.

### Removal

Same script, option **3**:

```
sh proton2025.sh
```

Restores the default `bootstrap` theme and removes the `luci-theme-proton2025` package. Safe to re-run.

### Known issues

- **The wildcard in the theme's README command** — `wget` does not expand `*` in a URL, so the author's literal command fails with 404. The script works around this by substituting the exact filename. If installing by hand, first check the real `.apk` name on the [releases page](https://github.com/ChesterGoodiny/luci-theme-proton2025/releases) and use it in full.
- **The `.apk` must be built by the OpenWrt SDK** — only the official SDK/buildroot produces a package valid for `apk add`. Since v1.1.2 the author builds `.apk` properly via the SDK, so installing on an apk system works. Older manually repacked `.apk` files could fail to install.
- **GitHub API rate limit** — unauthenticated, 60 requests per hour per IP. If you hit it, the script falls back to the Atom-feed method, which has no limit.
- **Download / SSL error** — if it complains about certificates, install them: `apk add ca-bundle ca-certificates`.
- **Interface still looks old** after install/update — that's browser cache. Refresh with **Ctrl+F5**.
- **opkg builds are not supported** — the script targets apk. On older (opkg-only) builds it reports this and exits.
- **Editing the script on Windows?** Save with **LF (Unix)** line endings. CRLF in `#!/bin/sh` breaks execution on the router. Guarded by `.gitattributes`.

### Diagnostics

```
apk info -e luci-theme-proton2025            # is the package installed (exit code 0 = yes)
apk list --installed | grep -i proton2025    # installed package version
uci get luci.main.mediaurlbase               # active theme (should be /luci-static/proton2025)
ls -l /www/luci-static/proton2025            # theme files present?
logread | grep -i uhttpd                      # LuCI web server log
```

### Tested on

OpenWrt 25.12.5 (mediatek/filogic, `aarch64_cortex-a53`), Proton2025 theme v1.1.2+.

### Credits

This project is just an installer. The theme itself is developed in **[ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)** and distributed under the **Apache-2.0** license.

Installed components are property of their authors and distributed under their own licenses. The MIT license covers only the installer code.

### License

[MIT](LICENSE) © 2026 lastik9
