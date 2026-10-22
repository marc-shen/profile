# Steam Deck 安装与系统更新后检查（2026-10-22）

设备为 `deck@100.100.1.4`。本次检查时系统报告 SteamOS **3.8.28**，
build **20260922.1**。只记录当前实际版本，不根据用户执行更新的时间推断版本变化。

## 新增软件

| 软件 | 来源与管理方式 | 安装位置 | 入口 |
| --- | --- | --- | --- |
| WezTerm 20240203-110809-5046fc22 | GitHub 上游 latest 稳定 release 的 AppImage，SHA256 校验后解包 | `~/Software/apps/wezterm/20240203-110809-5046fc22` | `wezterm`、桌面菜单 WezTerm |
| TeX Live 2026 | 上游 install-tl，TUNA CTAN 镜像；宏包由 tlmgr 管理 | `~/Software/apps/texlive/2026` | `xelatex`、`pdflatex`、`lualatex`、`latexmk`、`biber`、`tlmgr` |

两个应用均使用 `apps/<name>/current` 和 `Software/bin` 稳定入口，并记录 `receipt.json`。
安装脚本见 `scripts/install-wezterm.py`、`scripts/install-texlive.py`；
使用和更新方法见 [Steam Deck 维护说明](Steam-Deck.txt)。不加入基础环境的自动安装。

WezTerm 的 AppImage 不需要 FUSE。SteamOS 新的 Compose 表与旧 AppImage 所带
xkbcommon 不匹配，因此仅在应用目录中链接系统的两个 xkbcommon 库；原打包库
保存在该应用的 `bundled-libraries/`，没有修改系统库。配置仍完整使用 profile 的
`wezterm.lua`，默认不自动全屏，F12 可手动切换。桌面入口在
`~/.local/share/applications/org.wezfurlong.wezterm.desktop`。

TeX Live 使用 medium 方案，补装 `collection-langchinese`、`collection-latexextra`、
`collection-bibtexextra`、`latexmk` 和 `biber`。未安装离线文档和源码；需要时可补装。
`module load texlive/current` 提供全部原生 TeX 命令；常用命令无需加载模块即可使用。
个人 texmf、配置和缓存也在 Software 中。年度内用 `tlmgr update --self --all` 更新，
跨年度重新运行安装脚本建立新目录。版本是安装记录，并非禁止更新的固定约束。

## 更新后检查

| 检查项 | 结果与范围 |
| --- | --- |
| SteamOS 只读 | `steamos-readonly status` 为 `enabled`，Btrfs 根子卷属性 `ro=true`。未执行 pacman、sudo 安装或只读切换。 |
| Tailscale | tailscaled 为 enabled/active；BackendState=Running，设备在线；原 atomic-update 配置和额外持久化清单仍在。 |
| 接电不自动休眠 | KDE `[AC][SuspendAndShutdown] AutoSuspendAction=0`；Steam `IdleSuspendACSeconds=0`。检查的是设置保留，不代表已做长时间待机网络测试。 |
| 登录与终端 | 系统账户仍是 `/bin/bash`；个人 Bash 配置转入 `Software/bin/zsh -l`；Konsole Software-Zsh 默认配置保留。 |
| Zsh 插件 | 真实 PTY 和 WezTerm 子终端均验证 fzf-tab、autosuggestions、syntax-highlighting、Starship 加载；zsh-completions 路径由共享配置加载。 |
| 基础工具 | uv、Pixi、fd、rg、fzf、zoxide、starship、jq、bat、nvim、zsh 的统一入口和版本命令通过。 |
| Modules / GCC | Modules 5.7.0；加载 gcc/current 后 GCC 16.2.0 成功编译并运行简单 C 程序。 |
| Emacs | 只有一个活动 emacs.service；31.1 daemon 正常响应，无 init 错误，Tree-sitter 可用；vterm 原生模块和 PDF Tools 后端检查通过。未重启用户 Emacs。 |
| Steam Emacs 入口 | shortcuts.vdf 中目标仍为 `/home/deck/Software/bin/emacs-steam`，起始目录 `/home/deck`，启动选项为空。本次未从 Steam UI 点击启动。 |
| WezTerm GUI | 当前 gamescope 会话中实测窗口为 1280×800 全屏；复测无键盘库错误，测试窗口自动退出。未切换到 KDE 桌面。 |

发现并修复一个同步遗漏：Deck 的 `gap` 仍为旧的逐块暂存 alias，已同步为默认
`git add -A`，只有 `gap -p` / `gap --patch` 才逐块询问。
旧 zshrc 备份在 `~/Software/backups/post-update-20261022/zshrc`。
完整 `emacs.d` 未修改，也没有覆盖 Deck checkout 中的其他本地改动。

## 排版验证与日志

实际编译通过：

- `latexmk -xelatex` 编译 ctexart 中文、数学公式及 biblatex 文献，自动调用 Biber。
- `pdflatex` 编译英文及数学公式。
- `lualatex` 编译中文及数学公式。

样例、PDF 和编译日志在 `~/Software/build/texlive-smoke-20261022/`。
TeX Live 安装目录约 1.7 GiB，WezTerm 约 126 MiB（不包含下载缓存）。
宏包清单在 `~/Software/docs/texlive-packages-20261022.txt`；
整体软件清单更新到 `~/Software/docs/installed.json`。

安装日志：`~/Software/logs/texlive-install-20261022.log`。
WezTerm 验证：`~/Software/logs/wezterm-gui-test.log`、`wezterm-shell-test.log`。

## 后续修复：WezTerm 中 `em .` 无法打开窗口

晚间 KDE 桌面会话复现失败：后台早于桌面启动，原生进程环境中没有
`XAUTHORITY`，而 KDE 使用 `/run/user/1000/xauth_*` 临时授权文件。
后台日志报 `Authorization required, but no authorization protocol specified`；
仅更新 Lisp 的 `process-environment` 不能修复 Xlib 使用的原生环境。

新增 `scripts/emacs-x11-auth.sh`，在 Linux 图形客户端启动前，用系统 `xauth`
把当前会话授权合并到 `~/.Xauthority`，权限 0600，保留其他 display 的记录。
`em/ec`、Steam Deck 的 `emacs` 和 `emacs-steam` 共用该逻辑；后台启动脚本
固定使用这个稳定路径。macOS 和无 DISPLAY 的普通 SSH 会话跳过此操作。
Fedora、Ubuntu、Debian 的基础依赖清单补充 xauth；Deck 使用系统已有命令。
没有修改 Emacs Lisp 配置、没有新增常驻后台、没有关闭 SteamOS 只读。

验证包括真实 xauth 的授权轮换、保留其他 display、文件权限和重复执行测试，
以及独立临时 daemon 先启动、桌面授权后出现的建窗测试。临时 daemon 测试后退出。
修复过程中，原 GTK daemon 在一次授权失败后再次建窗时发生段错误，由 systemd
自动恢复；事前检查没有未保存的文件缓冲区。此后通过真实 WezTerm 执行 `em .`
成功打开测试目录。最终 WezTerm 回归中 `em .` 和 `ec .` 均退出 0，`ec`
等待窗口关闭后才返回，整个测试使用同一个 PID 25123，没有再次重启后台。
测试日志在 `Software/logs/test-em.log`、`Software/logs/test-ec.log` 和
`Software/logs/emacs-auth-integration.log`，旧脚本备份在
`Software/backups/emacs-xauth-20261022/`。

## 桌面插电休眠策略持久化

再次检查时，原 `AutoSuspendAction=0` 仍在，PowerDevil 当前 profile 为 `AC`，
硬件电源状态 online=1。本次重新应用配置，并加入用户级 PowerDevil 启动前规则，
让每次服务启动自动恢复该偏好。规则和独立应用脚本都在 Home 下，不写系统分区。
安装入口为 `platform/steamdeck/scripts/install-desktop-power.py`，路径和撤销方式见
[Steam Deck 维护说明](Steam-Deck.txt)。原配置保存到 `Software/backups/desktop-power-*`。
