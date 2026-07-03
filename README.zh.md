# openwrt-luci-theme-proton2025

用于 **OpenWrt 25 (apk)** 的 LuCI **Proton2025** 主题（[luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)）安装器：一个交互式脚本，自动从 GitHub 获取最新 `.apk` 的确切文件名，下载、安装、启用主题，也能同样干净地卸载 —— 无需手动敲命令或猜文件名。

[![OpenWrt](https://img.shields.io/badge/OpenWrt-25.x%20(apk)-blue)](https://openwrt.org)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-green)](proton2025.sh)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

[Русский](README.md) · [English](README.en.md) · **中文**

---

`proton2025.sh` 是一个小菜单：安装/更新主题、查看状态、卸载。发布包中的 `.apk` 文件名会随版本变化并带有构建号，手动输入不便 —— 脚本会自动找到当前文件。

### 为什么

从 OpenWrt 24.10 和快照版开始，项目将包管理器由 **opkg**（`.ipk`）切换为 **apk**（`.apk`）。Proton2025 主题不在官方源中 —— 它的发布包放在 GitHub 上。作者给出的安装命令带有通配符：

```
wget .../releases/latest/download/luci-theme-proton2025-*.apk
apk add --allow-untrusted luci-theme-proton2025-*.apk
```

问题在于：`wget` **不会展开** URL 中的 `*` —— 星号被原样发送到服务器，不存在这样的文件，下载以 **404** 失败。随后 `apk add` 拿到一个不存在的本地通配符，报 `no such package`。它期望你自己填入发布中的确切文件名（如 `luci-theme-proton2025-1.1.2-r1.apk`）。本脚本免去这些麻烦：向 GitHub 请求最新 `.apk` 的**确切**链接，下载，用 `apk add --allow-untrusted` 安装，并一次性把 LuCI 切换到 Proton2025。

### 脚本功能

启动后显示 `[1-4]` 菜单：

1. **安装 / 更新主题** —— 解析 [luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025) 最新发布，找到确切的 `.apk` 链接，下载到 `/tmp`，用 `apk add --allow-untrusted` 安装，然后设置 `luci.main.mediaurlbase='/luci-static/proton2025'` 并重启 `uhttpd`。同一项也用于更新 —— 始终拉取最新版。
2. **查看状态** —— 显示当前主题（`mediaurlbase`），以及是否已安装 `luci-theme-proton2025` 包及其版本。
3. **卸载主题** —— 恢复默认 `bootstrap` 主题，用 `apk del` 删除包，重启 `uhttpd`。
4. **退出**。

发布链接通过两种方式解析：先用 **GitHub API**（快），若不可用或触发限流，则用 **发布 Atom 源 + expanded_assets**（无限流）。两者都不需要 `jq` —— JSON 和 HTML 用标准的 `grep`/`sed` 解析。`curl` 或 `wget` 均可。

### 要求

- 使用 **apk** 包管理器的 OpenWrt **25.x**（opkg 版本请按主题作者说明安装 `.ipk`）。
- 安装时路由器**可联网** —— 需从 GitHub 下载主题包。
- 可用的 **HTTPS** 及证书（`ca-bundle` / `ca-certificates`）。
- **SSH** 访问权限和 root 权限。

### 安装

在**路由器上**（通过 SSH）执行：

```
wget https://raw.githubusercontent.com/lastik9/openwrt-luci-theme-proton2025/main/proton2025.sh
sh proton2025.sh
```

在菜单中选择 **1**。安装后在浏览器中用 **Ctrl+F5** 刷新 LuCI（否则会保留缓存的旧 CSS）。

配置项位于脚本顶部的变量中：主题仓库、包名、`mediaurlbase` 路径 —— 在同一处修改。

### 卸载

同一脚本，选择 **3**：

```
sh proton2025.sh
```

恢复默认 `bootstrap` 主题并删除 `luci-theme-proton2025` 包。可重复运行。

### 已知问题

- **主题 README 命令中的通配符** —— `wget` 不会展开 URL 中的 `*`，因此作者的字面命令会以 404 失败。脚本通过填入确切文件名来规避。若手动安装，请先在[发布页](https://github.com/ChesterGoodiny/luci-theme-proton2025/releases)查看真实的 `.apk` 名称并完整填入。
- **`.apk` 必须由 OpenWrt SDK 构建** —— 只有官方 SDK/buildroot 才能生成 `apk add` 可用的有效包。自 v1.1.2 起作者通过 SDK 正确构建 `.apk`，因此在 apk 系统上可正常安装。较早手动重新打包的 `.apk` 可能无法安装。
- **GitHub API 限流** —— 未认证时为每 IP 每小时 60 次。触发后脚本会回退到 Atom 源方式，该方式无限流。
- **下载 / SSL 错误** —— 若报证书错误，安装证书：`apk add ca-bundle ca-certificates`。
- **界面仍是旧样子** —— 这是浏览器缓存。用 **Ctrl+F5** 刷新。
- **不支持 opkg 版本** —— 脚本面向 apk。在较旧的（仅 opkg）版本上会立即提示并退出。
- **在 Windows 上编辑脚本？** 请以 **LF（Unix）** 换行保存。`#!/bin/sh` 中的 CRLF 会导致路由器无法执行。由 `.gitattributes` 保护。

### 诊断

```
apk info -e luci-theme-proton2025            # 包是否已安装（退出码 0 = 是）
apk list --installed | grep -i proton2025    # 已安装包的版本
uci get luci.main.mediaurlbase               # 当前主题（应为 /luci-static/proton2025）
ls -l /www/luci-static/proton2025            # 主题文件是否存在？
logread | grep -i uhttpd                      # LuCI web 服务器日志
```

### 测试环境

OpenWrt 25.12.5（mediatek/filogic，`aarch64_cortex-a53`），Proton2025 主题 v1.1.2+。

### 致谢

本项目只是一个安装器。主题本身开发于 **[ChesterGoodiny/luci-theme-proton2025](https://github.com/ChesterGoodiny/luci-theme-proton2025)**，以 **Apache-2.0** 许可证分发。

所安装的组件归其各自作者所有，并按其各自许可证分发。MIT 许可证仅涵盖安装器代码。

### 许可证

[MIT](LICENSE) © 2026 lastik9
