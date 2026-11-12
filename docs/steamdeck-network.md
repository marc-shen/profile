# Steam Deck 网络命令

每个网络软件都有独立入口：`workbench <软件> <操作>`。组件名称为：

- `steamcommunity302`：Steamcommunity 302。
- `mihomo`：Mihomo 核心、MetaCubeXD 网页、订阅更新任务。
- `tailscale`：官方 deck-tailscale 管理的 Tailscale。

```sh
workbench list --category network
workbench mihomo update --help
workbench mihomo status
workbench tailscale status
workbench steamcommunity302 status
workbench system check steamdeck
```

Zsh 支持分层 Tab 补全：`workbench <Tab>` 选择软件，再按 Tab 选择操作。
fzf-tab 可用时显示可搜索的选择菜单，否则使用 Zsh 原生选择菜单。
首次更新配置后，在已有终端执行 `source ~/.zshrc`，或打开新终端即可。

## 统一操作

所有服务使用同一组动词，没有 `authorize`、`tailscale-update`、`daily-update`
等额外入口，也不再安装 `mihomo-deck` 或 `steamcommunity302` 命令。

| 操作 | 含义 |
|---|---|
| `install` | 准备固定版本客户端、菜单与配置，不重启正在运行的服务 |
| `apply` | 完成首次权限/后台安装及启用，需要在 Deck 本机操作 |
| `update` | 更新该服务管理的内容，具体范围见下表 |
| `start` | 启动后台服务 |
| `stop` | 停止后台服务，保留开机启动设置 |
| `restart` | 重启后台服务 |
| `status` | 查看后台状态；Mihomo 同时显示下次订阅更新时间 |
| `check` | 检查部署、权限、持久化等条件，缺项时返回非零状态 |
| `open` | 打开 302 客户端、Mihomo 网页或 Tailscale 官方管理网页 |
| `logs` | 查看最近 50 条服务日志；Mihomo 包含订阅更新日志 |

| 服务 | `update` 的范围 | `apply` 的行为 |
|---|---|---|
| `mihomo` | 下载订阅、校验并应用变化；失败回退；不升级核心或网页 | 配置 TUN 权限、9090 防火墙及自启并重启服务 |
| `sc302` | 客户端对齐 profile 清单的固定版本；不会自动升级 root 后台 | 打开官方 GUI 完成后台安装与证书授权 |
| `tailscale` | 用固定的官方安装脚本安装执行时最新稳定版 | 安装/补齐持久化配置；首次需要登录时引导登录 |

302 官方后台目前没有无人值守更新命令，后端升级需在
`workbench steamcommunity302 open` 打开的窗口完成。`workbench steamcommunity302 update` 不会将客户端同步
误报为后端已升级。Mihomo 核心/网页版本由 `components/mihomo/component.toml` 管理，
变更清单后执行 `install`，更换核心后执行 `apply` 恢复文件权限。

Tailscale 的更新、停止、重启会影响当前网络连接，因此要求在 Deck 本机执行。
Tailscale 和 302 的系统服务操作需要管理员权限；Mihomo 日常启停、节点选择和订阅更新不需要。

## 常用命令

```sh
# 检查全部服务
workbench system check steamdeck
# 打开代理网页
workbench mihomo open
# 立即运行和每日定时任务相同的订阅更新流程
workbench mihomo update
# 查看代理及订阅更新日志
workbench mihomo logs
# 打开 302
workbench steamcommunity302 open
# 在 Deck 本机更新 Tailscale
workbench tailscale update
```

## 重建环境

```sh
cd ~/Software/config/workbench
workbench profile apply --only network
# 等效的网络部署入口（不记录完整 profile 部署快照）：
workbench mihomo install
workbench tailscale install
workbench steamcommunity302 install
```

新机器在仓库外的 `~/Software/config/mihomo/subscription.url` 写入订阅链接，
权限设为 600，再执行 `workbench mihomo install`。
在本机分别执行 `workbench mihomo apply`、`workbench tailscale apply`、`workbench steamcommunity302 apply` 完成管理员授权及 GUI 设置。
已有 Tailscale 登录、出口节点和路由偏好保留。

Tailscale 使用 [deck-tailscale](https://github.com/tailscale-dev/deck-tailscale)，
安装脚本位于 `Software/apps/deck-tailscale/current`，程序位于 `/opt/tailscale`，
身份状态位于 `/var/lib/tailscale`。旧 `~/deck-tailscale` 克隆不是运行依赖。

302 菜单统一使用 `Steamcommunity_302.desktop`；客户端与图标来自
`Software/apps/steamcommunity302/current`，部署时仅删除 `~/Applications` 中
与托管版本校验值完全相同的重复 AppImage。后台数据保留在
`/var/lib/Steamcommunity_302`，不因重新部署客户端而删除。
Mihomo 图标来自 MetaCubeXD 安装目录。两个菜单入口分别调用 `workbench mihomo open` 与 `workbench steamcommunity302 open`。

## 游戏模式停在“正在连接 Steam”

302 的 hosts 模式与 Mihomo TUN 可以同时使用，但系统信任 302 的根证书，并不代表
Steam 的 pressure-vessel 容器也信任它。2026-11-12 的实机排查中，Steam API
被 `/etc/hosts` 映射到 `127.0.0.1`；系统 curl 成功，使用 Steam 容器 CA 的同一
请求则报证书验证失败。Steam 持续重试登录 API，界面停在“正在连接 Steam”。

### 修复容器的证书信任

```sh
workbench steamcommunity302 install
# 安装不会打断正在运行的 Steam。退出游戏后重新启动 Steam，再检查：
workbench steamcommunity302 check
```

安装会部署 `~/Software/libexec/steam-ca-bwrap` 和用户服务配置
`~/.config/systemd/user/steam-launcher.service.d/60-workbench-ca.conf`。
游戏模式启动 Steam 时，通过 Valve 支持的 `PRESSURE_VESSEL_BWRAP` 环境变量调用
这个小型钩子；它继续使用当前 Steam 自带的 `srt-bwrap`，仅在容器的运行时挂载之后，
将系统 `/etc/ssl/certs/ca-certificates.crt` 只读挂载到容器的相同路径。
同时设置容器内 `SSL_CERT_FILE`，使 OpenSSL 命令行工具也使用同一份证书库。

这让 Steam 信任与系统相同的 CA，包含已由 302 官方安装器授权的本机根证书。
不会关闭 TLS 校验、添加过期 CA、改动 Steam 下载的运行时文件或解除 SteamOS 只读。
钩子在客户端容器内清除自身环境变量，游戏容器继续选择各自的启动工具。
文件存放在 home；每次启动读取当前系统证书和 Steam 自带的工具，无需复制整套运行时。
Steam 更新后仍需以 `check` 验证兼容性，系统 CA 轮换后重启 Steam 即可重新挂载。

`check` 同时验证安装文件和运行中 Steam 容器的 CA 内容；发现尚未重启或证书已变化时
会明确提示。2026-11-13 实机恢复上述四项 302 规则后，Steam 从开始登录到
`Success` 约 5 秒，运行中容器的证书库与系统一致。

此自动启动配置针对游戏模式的 `steam-launcher.service`。在 KDE 中直接运行 Steam
而不经过该服务时，可在 Steam 完全退出后使用相同钩子启动：

```sh
PRESSURE_VESSEL_BWRAP="$HOME/Software/libexec/steam-ca-bwrap" steam
```

上游的 `PRESSURE_VESSEL_IMPORT_CA_CERTS=1` 当前要求系统存在指定旧根证书的哈希文件
`244b5494.0`，本机缺少该文件时会放弃整个导入。本方案不为满足该检查而重新信任旧 CA。
实现参考：[Valve 的 bubblewrap 环境变量入口](https://gitlab.steamos.cloud/steamrt/steam-runtime-tools/-/blob/main/steam-runtime-tools/bwrap.c)、
[上游证书导入检查](https://gitlab.steamos.cloud/steamrt/steam-runtime-tools/-/blob/main/pressure-vessel/runtime.c)。

### 无法使用证书挂载时的回退方案

保持 hosts 模式，在 `workbench steamcommunity302 open` 中关闭下列规则并应用：

| 302 规则 | 原因 |
| --- | --- |
| Steam API (`Steam_API`) | 接管客户端登录需要的 `api.steampowered.com` |
| Steam 客户端更新 (`steam_update`) | 接管客户端更新地址 |
| Steam 白山云重定向阿里云 (`baishan2ali`) | 同样接管更新入口 `media.st.dl.eccdnx.com` |
| Steam 网页布局/图片修复 CF+Akamai (`imgfix`) | 同样接管 `client-update.akamai.steamstatic.com` |

这些功能会有域名重叠，仅关闭“客户端更新”并不足够。商店、社区、聊天等其余规则
无需随之关闭。Workbench 的 `steamcommunity302 check` 仅在证书挂载尚未就绪时
报告这些冲突规则，不覆盖 GUI 中的用户选择。证书信任修复后可以恢复这些功能。

在 Mihomo 网页中检查登录 API 实际命中的策略。如果订阅的“游戏平台”使用 `DIRECT`
而当前网络直连 Steam API 超时，将该组改为跟随“节点选择”。当前 Deck 的订阅先匹配
`GEOSITE,steam@cn,全球直连`，再匹配 `GEOSITE,steam,游戏平台`，因此国内 Steam
下载规则保持直连。其他订阅需根据实际规则判断，不应把所有 Steam 下载强制代理。
策略选择由 Mihomo `profile.store-selected` 保存，日常订阅更新保留该选择（组名不变时）。

```sh
workbench steamcommunity302 check
workbench mihomo check
```

修复后检查 `~/.local/share/Steam/logs/steamui_login.txt` 中的新记录是否出现
`SetLoginState: Success - OK`。已经卡住的客户端可能保留旧 DNS/hosts 或连接，需要
退出并重新启动 Steam。不要关闭 TLS 校验，也不要修改 Steam 随更新替换的运行时文件。
证书修复和回退方案都保持 SteamOS 只读，不修改 Tailscale。

注意：Mihomo 的 `use-system-hosts: false` 不能单独解决这个问题，systemd-resolved
默认也会读取 `/etc/hosts`，Steam 容器还可能保留启动时的 hosts 文件。
参考：[systemd-resolved 的 hosts 解析](https://www.freedesktop.org/software/systemd/man/258/systemd-resolved.html)、
[Steam Runtime 的独立 CA 问题](https://github.com/ValveSoftware/steam-runtime/issues/834)。

所有订阅、节点、密钥和运行数据保存在仓库外。SteamOS 保持只读。
系统服务及授权文件通过 `/etc/atomic-update.conf.d` 保留；系统重装后仍需
重新部署。代理细节见 [Mihomo 说明](steamdeck-mihomo.md)。
