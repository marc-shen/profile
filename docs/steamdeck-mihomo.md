# Mihomo + MetaCubeXD

此方案直接使用订阅商的完整 Clash/Mihomo YAML，保留节点、策略组与规则。
`components/mihomo/component.toml` 固定官方二进制、网页版本及 SHA256。
规则前置 Tailscale、局域网和 302 直连；DNS 保留供应商设置并支持本机 hosts
及 `.ts.net` MagicDNS。TUN 排除 Tailscale 接口和对应网段。

## 安装与启用

在本机 `~/Software/config/mihomo/subscription.url` 放置订阅地址，权限设为 600。
该文件、下载的 `provider.yaml` 和生成的 `config.yaml` 都在仓库外，不提交 Git。

```sh
cd ~/Software/config/workbench
workbench mihomo install
# 在 Deck 本机 Konsole 执行一次，输入 sudo 密码：
workbench mihomo apply
```

`workbench mihomo install` 下载客户端和网页、合并本机覆盖、运行核心配置检查、写入用户服务，
不会重启正在运行的代理服务。缺少 PyYAML 时用 uv 创建独立的 Python 辅助环境。
`workbench mihomo apply` 设置核心 capabilities、只针对 `mihomo-tun` 的 resolved DNS 授权，
以及只允许 loopback/Tailscale 接口访问 TCP 9090 的独立 nftables 规则。
完成后启动 Mihomo 并检查控制接口及 TUN 网卡，然后启用开机自启。

启动后访问 `http://本机TailscaleIPv4:9090/ui/`，无需密码/API 密钥。
推荐用 `workbench mihomo open` 或桌面的 Mihomo 入口打开，入口会自动带入正确的后端地址。
Deck 本机也可访问 `http://127.0.0.1:9090/ui/`。网页默认连接同源后端。
其他设备用 `http://本机TailscaleIPv4:9090` 作为后端地址，密钥留空；
后端地址不包含 `/ui/`，其他设备的 `127.0.0.1` 不代表 Deck。
端口迁移后需在 Deck 本机执行一次 `workbench mihomo apply` 更新 root 管理的
防火墙规则并重启服务；新服务会拒绝在旧端口防火墙配置下启动。
HTTP 位于 Tailscale 加密网络内；所有能通过 tailnet ACL 访问该端口的设备
都能管理代理，也可能读取节点信息。Wi-Fi 来源被专用防火墙拒绝。
Mihomo 用户服务启动前检查该防火墙服务已激活；不要手动清空这张 nft 表。

MetaCubeXD 用于选择策略组/节点、查看规则与连接，不是订阅 YAML 的完整编辑器。
高级规则由订阅商 YAML 加本机覆盖管理。

```sh
# 下载订阅、校验并应用变化；没有变化时不重启：
workbench mihomo update
workbench system check steamdeck
```

## 每日订阅更新

`workbench mihomo install` 部署并启用用户级 `mihomo-subscription-update.timer`，每天按 Deck
本地时区在 04:00–04:10 执行。设备关机或休眠错过时，在恢复运行后补执行，
不会主动唤醒设备。无需 sudo，SteamOS 仍保持只读。

定时任务仅刷新订阅与覆盖配置，不升级核心或网页。下载或校验失败时保留旧配置；
配置没有变化时不重启。配置变化且服务正在运行时重启并检查控制接口与 TUN，
失败则恢复旧配置并尝试恢复服务；主动停止的服务不会被定时任务启动。

```sh
# 下次执行时间
workbench mihomo status
# 手动执行一次相同的自动更新流程
workbench mihomo update
# 查看后台和订阅更新日志（更新任务不输出订阅链接）
workbench mihomo logs
```

Mihomo 是默认且唯一代理后端。新机器需先执行 `workbench mihomo install` / `workbench mihomo apply` 完成配置。
更新更换 Mihomo 二进制后重新执行 `workbench mihomo apply`，恢复文件 capabilities。
SteamOS 保持只读；防火墙及专用授权文件由 `/etc/atomic-update.conf.d` 保留。
Tailscale 的登录、exit node 和 302 状态不更改。

节点切换通过核心 API 完成。专用 polkit 规则只授权指定用户对 `mihomo-tun`
的 DNS 操作，没有授予任意 sudo 权限。
