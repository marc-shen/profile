# Mihomo + MetaCubeXD

此方案直接使用订阅商的完整 Clash/Mihomo YAML，保留节点、策略组与规则。
`components/mihomo/component.toml` 固定官方二进制、网页版本及 SHA256。
规则前置 Tailscale、局域网和 302 直连；DNS 保留供应商设置并支持本机 hosts
及 `.ts.net` MagicDNS。TUN 排除 Tailscale 接口和对应网段。
302 hosts 模式需避开 Steam 客户端登录 API 和更新域名；具体冲突规则及验证方法见
[游戏模式连接故障](steamdeck-network.md#游戏模式停在正在连接-steam)。系统 CA 信任不会自动传入 Steam 容器。

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
没有物理网络或 NetworkManager 明确报告认证门户时跳过本次更新，保留订阅缓存。

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

## 无网络时的行为

`mihomo.service` 由 `libexec/mihomo_network.py` 管理核心进程，每 5 秒检查一次
NetworkManager。没有已连接的 Wi-Fi、有线或移动网络持续约 10 秒后，正常终止核心，
停止节点健康检查并释放 TUN/DNS 接管；开机本来就无网络时不会启动核心。
Tailscale、Mihomo 的虚拟网卡不算外网连接。有线底座仍可正常使用代理。

物理连接稳定恢复约 10 秒后，使用已有配置重新启动核心，保留保存的策略组选择和
限定范围的自动回退。不会改成 `DIRECT` 或扩大节点范围；已有连接可能需要应用重新建立。
没有切换 Wi-Fi 或停掉 Tailscale、302，也没有新增 root 常驻程序。

NetworkManager 明确报告认证门户（`portal`）时同样暂停核心，便于直接登录 Wi-Fi。
`limited`/`unknown` 或探测命令失败不会触发停用：国内网络可能阻断连通性检测站点。
因此“Wi-Fi 已连接、但上游互联网不可用”不一定会暂停核心，避免把局部封锁误判为断网。

离线时用户服务保持运行等待网络，核心、9090 控制接口和 MetaCubeXD 网页暂时不可用。
用 `workbench mihomo status` 查看 `waiting-network` / `running`；
`workbench mihomo stop` 会停止整个管理进程，之后网络恢复也不会擅自启动，
需要执行 `workbench mihomo start`。订阅更新不会启动被手动停止的服务。

## 限定范围的自动回退

本机可使用 `~/Software/config/mihomo/fallbacks.toml` 添加独立的回退组。
文件不提交 Git；订阅更新时按供应商组的最新成员重新生成，不复制订阅或节点凭据。
例如当前 Deck 的游戏平台只在供应商的“香港节点”范围内自动回退：

```toml
schema = 1

[[fallback]]
name = "🎮 香港自动回退"
source = "🇭🇰 香港节点"
attach-to = "🎮 游戏平台"
# 可选：填入范围内的具体节点名，作为第一优先级；只保存在本机。
# preferred = "具体节点名"
url = "https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/"
interval = 180
timeout = 8000
```

每 180 秒对组内节点执行 Steam API 的 HTTPS HEAD 检查，8 秒超时，要求 HTTP 200。
按列表顺序选择首个健康节点，优先节点恢复后，新连接可以重新使用它。已有 TCP/UDP
连接不能无缝迁移，断线时应用仍可能需要重连；这个检查也不保证具体游戏 UDP 链路可用。
所有节点都失败时，不会扩大到其他地区或自动直连，业务仍可能失败。

`preferred` 已不在最新供应商范围内时会被忽略；新节点按供应商顺序加入。
目前支持源组的显式节点列表，不接受嵌套策略组、DIRECT 或动态 provider/filter
作为范围。源组消失、范围为空或配置无效时停止更新并保留旧配置，不扩大范围。

```sh
# 合并本机配置并校验；不重启正在运行的服务
workbench mihomo install
# 应用刚生成的配置
workbench mihomo restart
workbench mihomo open
```

随后在“游戏平台”选择“香港自动回退”。首次设置需选择一次；后续日常订阅更新
由 `store-selected` 保存选择。仅向游戏平台增加选项，不改变供应商香港组、
全局“节点选择”或其他应用的选择；在网页上改回原香港组即可恢复手动选择。
不要直接编辑生成的 `config.yaml`，下一次订阅更新会覆盖它。

机制参考：[Mihomo fallback](https://wiki.metacubex.one/config/proxy-groups/fallback/)、
[健康检查参数](https://wiki.metacubex.one/config/proxy-groups/)。
