# 软件镜像源

统一入口为 `workbench mirrors <action> [auto|dnf|flatpak|apt]`。省略对象时按当前平台选择：Fedora 使用 DNF，Steam Deck 使用 Flatpak，Ubuntu 使用 APT。macOS 可以查看目录，不修改 Homebrew。

```sh
workbench mirrors list
workbench mirrors apply          # 检测并换源
workbench mirrors check          # 对照配置记录并检测元数据
workbench mirrors update         # 重新按优先级选择，刷新元数据
workbench mirrors restore        # 恢复首次换源前的配置
workbench mirrors apply --plan   # 只预览执行入口，不联网或修改
```

`install` 与 `apply` 一样按优先级应用配置。以上操作和对象支持 Tab 补全。`workbench system install/update/check` 根据 `platforms/<platform>/platform.toml` 的 `mirror_target` 自动包含换源或检查，安装时先配置镜像，再安装原生依赖。首次安装的 Python/Git/curl 引导仍使用系统现有源。

镜像目录位于 `catalog/mirrors.toml`，默认顺序为清华 TUNA、科大 USTC、上海交大 SJTUG。每次应用或更新都会按顺序检测实际仓库元数据，而非只检查网站首页；不可达、返回网页、跳转到站外上游或不提供对应仓库时跳过。顺序是执行换源时的选择策略，不是后台持续探活，也不是包管理器下载过程中逐包切换。

清华当前未提供 Flathub；科大提供动态缓存，交大候选地址如果跳转到官方站点会被跳过。镜像缓存未命中的应用数据或 `extra-data` 仍可能从原始站点下载。Flathub beta 不属于稳定镜像，保留原地址。

- Fedora：修改 `fedora.repo` 和 `fedora-updates.repo` 中的官方发行、更新、源码和调试仓库地址；保留启用状态、GPG 校验及密钥路径，不改 RPM Fusion/COPR 等第三方源。根据本机版本和架构检测仓库，已停止支持且镜像不再收录的版本不会盲目换源。
- Ubuntu：兼容 `sources.list`、`*.list` 和 DEB822 `*.sources`；覆盖官方普通、安全更新和 ports 地址，保留 suite、组件、架构、Signed-By 和第三方源。检查实际使用的每个 suite；应用后执行 `apt-get update`，继续由 APT 验证签名及元数据有效期。
- Steam Deck：修改已有用户级/系统级稳定 `flathub` remote 的 URL，保留现有信任密钥和应用。不改只读根分区，不新建重复 remote。系统级 remote 通过 Flatpak 的正常桌面授权更新，数据位于 `/var/lib/flatpak`；SteamOS 保持只读。若系统尚未配置可信 Flathub，先按官方说明添加 remote。

应用后使用包管理器读取仓库元数据，验证失败则恢复本次修改前的配置，再尝试下一候选。所有候选均失败时保留原配置。APT/DNF 需要正常 sudo 授权；Flatpak 系统级授权建议从本机桌面终端执行。没有禁用 TLS/GPG 验证，也不会改变订阅或节点。

原配置备份在 `~/Software/backups/mirrors/`；选择记录和中断恢复记录在 `~/Software/data/mirrors/`。多次换源仍保留首次换源前的配置，`restore` 可以恢复。检测到用户在 Workbench 之外修改了已管理配置时，会拒绝覆盖；先检查差异。中断留下 pending 记录时，先执行 `restore` 恢复到中断前的状态，再重试。

Mihomo 每次合成配置时，从同一 TOML 目录读取镜像域名直连规则，并放在订阅规则之前。覆盖清华、科大、交大（含交大对象存储），以及北外、南大、阿里、腾讯、华为和 CERNET 镜像域名；不会将整个高校域名设为直连。后续订阅更新会保留这些规则。

参考：[清华 Fedora](https://mirrors.tuna.tsinghua.edu.cn/help/fedora/)、[清华 Ubuntu](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/)、[科大 Flathub](https://mirrors.ustc.edu.cn/help/flathub.html)、[Flatpak 命令参考](https://docs.flatpak.org/en/latest/flatpak-command-reference.html)。
