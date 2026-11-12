# 软件镜像源

统一入口为 `workbench mirrors <action> [auto|dnf|flatpak|apt]`。省略对象时按当前平台选择：Fedora 使用 DNF，Steam Deck 使用 Flatpak，Ubuntu 使用 APT。macOS 可以查看目录，不修改 Homebrew。

```sh
workbench mirrors list
workbench mirrors apply          # 检测并换源
workbench mirrors check          # 对照配置记录并检测元数据
workbench mirrors update         # 验证联合镜像，刷新元数据
workbench mirrors restore        # 恢复首次换源前的配置
workbench mirrors apply --plan   # 只预览执行入口，不联网或修改
```

`install` 与 `apply` 一样应用 CERNET 联合镜像。以上操作和对象支持 Tab 补全。`workbench system install/update/check` 根据 `platforms/<platform>/platform.toml` 的 `mirror_target` 自动包含换源或检查，安装时先配置镜像，再安装原生依赖。首次安装的 Python/Git/curl 引导仍使用系统现有源。

镜像目录位于 `catalog/mirrors.toml`。默认统一使用 [CERNET 教育网联合镜像站](https://mirrors.cernet.edu.cn/)，使用 `sjtug-ustc-tuna` 前缀表达清华 → 科大 → 交大的偏好，由联合镜像服务将请求重定向到可用成员站点；Workbench 验证入口可用后保存 CERNET URL，不固定某一次检测选中的学校，也不再在本地逐站选择。标签用 `-` 分隔，越靠右优先级越高；这是偏好而非强制绑定，仓库未收录、站点异常或访问范围不满足时仍由 CERNET 选择其他可用候选。

| 对象 | 写入的入口 |
| --- | --- |
| Fedora DNF | `https://sjtug-ustc-tuna.mirrors.cernet.edu.cn/fedora` |
| Ubuntu APT | `https://sjtug-ustc-tuna.mirrors.cernet.edu.cn/ubuntu` |
| Ubuntu ARM 等 ports | `https://sjtug-ustc-tuna.mirrors.cernet.edu.cn/ubuntu-ports` |
| Steam Deck Flathub | `https://sjtug-ustc-tuna.mirrors.cernet.edu.cn/flathub` |

检测实际仓库元数据，接受 CERNET 的跨站重定向，每次跳转保持 HTTPS。下载站点由 CERNET 决定。Flathub 成员站的缓存未命中时，应用数据可能回源；`extra-data` 也可能从软件自己的原始站点下载。Flathub beta 保留原地址。

- Fedora：修改 `fedora.repo` 和 `fedora-updates.repo` 中的官方发行、更新、源码和调试仓库地址；保留启用状态、GPG 校验及密钥路径，不改 RPM Fusion/COPR 等第三方源。根据本机版本和架构检测仓库，已停止支持且镜像不再收录的版本不会盲目换源。
- Ubuntu：兼容 `sources.list`、`*.list` 和 DEB822 `*.sources`；覆盖官方普通、安全更新和 ports 地址，保留 suite、组件、架构、Signed-By 和第三方源。检查实际使用的每个 suite；应用后执行 `apt-get update`，继续由 APT 验证签名及元数据有效期。
- Steam Deck：修改已有用户级/系统级稳定 `flathub` remote 的 URL，保留现有信任密钥和应用。不改只读根分区，不新建重复 remote。系统级 remote 通过 Flatpak 的正常桌面授权更新，数据位于 `/var/lib/flatpak`；SteamOS 保持只读。若系统尚未配置可信 Flathub，先按官方说明添加 remote。

应用后使用包管理器读取仓库元数据，验证失败则恢复本次修改前的配置；联合镜像不可用时保留原配置。APT/DNF 需要正常 sudo 授权；Flatpak 系统级授权建议从本机桌面终端执行。没有禁用 TLS/GPG 验证，也不会改变订阅或节点。

原配置备份在 `~/Software/backups/mirrors/`；选择记录和中断恢复记录在 `~/Software/data/mirrors/`。多次换源仍保留首次换源前的配置，`restore` 可以恢复。检测到用户在 Workbench 之外修改了已管理配置时，会拒绝覆盖；先检查差异。中断留下 pending 记录时，先执行 `restore` 恢复到中断前的状态，再重试。

Mihomo 每次合成配置时，从同一 TOML 目录读取镜像直连规则，并放在订阅规则之前。CERNET 入口、已知镜像域名和对象存储均直连；镜像主机名正则还覆盖高校和科研院所的 `mirror.*` / `mirrors.*` 以及其子域，适配联合镜像动态选择的成员站，而不放行整个高校域名。后续订阅更新会保留这些规则。海外原始站点仍遵循订阅的正常分流。

前缀实现参考：[MirrorZ 调度评分](https://github.com/mirrorz-org/mirrorz-302/blob/master/pkg/scoring/eval.go)。例如 `ustc-tuna` 优先清华，`tuna-ustc` 优先科大；`avoidtuna` 则排除清华。

参考：[CERNET Fedora](https://help.mirrors.cernet.edu.cn/fedora/)、[CERNET Ubuntu](https://help.mirrors.cernet.edu.cn/ubuntu/)、[CERNET Flathub](https://help.mirrors.cernet.edu.cn/flathub/)、[Flatpak 命令参考](https://docs.flatpak.org/en/latest/flatpak-command-reference.html)。
