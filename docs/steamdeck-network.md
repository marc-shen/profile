# Steam Deck 网络命令

唯一入口为 `workbench network <操作> <服务>`。服务名固定为：

- `all`：批量操作全部网络服务。
- `sc302`：Steamcommunity 302。
- `mihomo`：Mihomo 核心、MetaCubeXD 网页、订阅更新任务。
- `tailscale`：官方 deck-tailscale 管理的 Tailscale。

```sh
workbench network --help
workbench network update --help
workbench network status all
workbench network check all
```

Zsh 支持分层 Tab 补全：`workbench network <Tab>` 选择操作，再按 Tab 选择服务。
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
`workbench network open sc302` 打开的窗口完成。`workbench network update sc302` 不会将客户端同步
误报为后端已升级。Mihomo 核心/网页版本由 `catalog/mihomo.json` 管理，
变更清单后执行 `install`，更换核心后执行 `apply` 恢复文件权限。

`all` 对每项执行同一操作。启动/重启/首次启用先处理 Tailscale，停止时最后
处理 Tailscale。会打断 Tailscale SSH 的操作（包括 `update/stop/restart all`）
在批量执行前拒绝远程调用，避免半途断线。Tailscale 和 302 的服务启停需要
管理员权限；Mihomo 的日常启停及订阅更新不需要。

## 常用命令

```sh
# 检查全部服务
workbench network check all
# 打开代理网页
workbench network open mihomo
# 立即运行和每日定时任务相同的订阅更新流程
workbench network update mihomo
# 查看代理及订阅更新日志
workbench network logs mihomo
# 打开 302
workbench network open sc302
# 在 Deck 本机更新 Tailscale
workbench network update tailscale
```

## 重建环境

```sh
cd ~/Software/config/workbench
workbench profile apply --only network
# 等效的网络部署入口（不记录完整 profile 部署快照）：
workbench network install all
```

新机器在仓库外的 `~/Software/config/mihomo/subscription.url` 写入订阅链接，
权限设为 600，再执行 `workbench network install mihomo`。
本机执行 `workbench network apply all` 完成管理员授权与 302 图形界面设置。
已有 Tailscale 登录、出口节点和路由偏好保留。

Tailscale 使用 [deck-tailscale](https://github.com/tailscale-dev/deck-tailscale)，
安装脚本位于 `Software/apps/deck-tailscale/current`，程序位于 `/opt/tailscale`，
身份状态位于 `/var/lib/tailscale`。旧 `~/deck-tailscale` 克隆不是运行依赖。

302 菜单统一使用 `Steamcommunity_302.desktop`；客户端与图标来自
`Software/apps/steamcommunity302/current`，部署时仅删除 `~/Applications` 中
与托管版本校验值完全相同的重复 AppImage。后台数据保留在
`/var/lib/Steamcommunity_302`，不因重新部署客户端而删除。
Mihomo 图标来自 MetaCubeXD 安装目录。两个菜单入口均调用 `workbench network`。

所有订阅、节点、密钥和运行数据保存在仓库外。SteamOS 保持只读。
系统服务及授权文件通过 `/etc/atomic-update.conf.d` 保留；系统重装后仍需
重新部署。代理细节见 [Mihomo 说明](steamdeck-mihomo.md)。
