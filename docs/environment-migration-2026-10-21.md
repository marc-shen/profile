# 三平台环境迁移记录

核验日期：2026-10-21。配置源为本机 `/Users/marcshen/program/GitHub/profile` 工作树；已同步到 Fedora `~/projects/profile` 和 Deck `~/Software/src/profile`。修改尚未 commit/push，因此远端 GitHub 仓库暂不包含本轮更新。

## 布局和安装规则

统一名称为 **Software**，用户安装在 `~/Software`。`bin` 是稳定命令入口，`apps/<名称>/<版本>` 保存管理器、工具、编译器和复杂环境，`current` 选择当前版本；`share`、`config`、`src`、`build`、`downloads`、`cache`、`data`、`logs`、`backups` 各司其职。

安装需求不固定补丁版本：普通 Pixi 工具使用 `*`，更新时重新求解；安装后的 `pixi.lock` 和 `receipt.json` 记录实际版本。项目已有的 Python、MPI、Numba 等兼容性约束保留。Modules 的 Tcl 使用 `>=8.6,<9`，这是构建接口兼容范围。

来源顺序：系统基础组件 → 上游独立 Pixi/uv → Pixi CLI → 明确选择的 brew/dnf/apt → 上游二进制或源码。网络失败不会自动切换来源。当前清单里的 CLI 都有可用 Pixi 包；任意新软件的自动回退安装器尚未实现，需要加入经核验的配方。

## 已安装的统一工具

下表版本是本次实装快照，不是未来安装限制。每个 CLI 使用独立 Pixi 环境，不默认附带 Python；完整传递依赖见各应用的锁文件和 `~/Software/docs/installed.json`。

| 类别 | 项目 | 三平台实装版本 | 来源 / 直接依赖 | 状态 |
|---|---|---|---|---|
| 管理器 | Pixi | 0.82.1 | prefix-dev 官方发行二进制，SHA256 校验 | 已更新 |
| 管理器 | uv / uvx | 0.13.4 | astral-sh 官方发行二进制，SHA256 校验 | 已更新 |
| Shell | Zsh | 5.9.2 | conda-forge `zsh` | 独立环境 |
| 文件查找 | fd | 10.5.0 | conda-forge **`fd-find`** | 独立环境 |
| 内容搜索 | ripgrep / rg | 15.2.0 | conda-forge `ripgrep` | 独立环境 |
| 模糊选择 | fzf | 包版本 0.74.5 | conda-forge `fzf`；程序显示 `0.74` | 独立环境 |
| 目录跳转 | zoxide | 0.10.0 | conda-forge `zoxide` | 独立环境 |
| 提示符 | Starship | 1.27.0 | conda-forge `starship` | 独立环境 |
| JSON | jq | 1.8.2 | conda-forge `jq` | 独立环境 |
| 文件查看 | bat | 0.26.1 | conda-forge `bat` | 独立环境 |
| 编辑器 | Neovim | 0.12.6 | conda-forge **`nvim`** | 独立环境 |

`fd`、`neovim` 在 conda-forge 中不是这里所需程序的正确包名；安装器现已采用正确映射，并在切换入口前执行运行验证。初次尝试留下的错误包环境已删除。

| Zsh 插件 | 来源 | 本次提交（前 12 位） |
|---|---|---|
| fzf-tab | Aloxaf/fzf-tab | 24105b15714b |
| zsh-completions | zsh-users/zsh-completions | 989b23277ab3 |
| zsh-autosuggestions | zsh-users/zsh-autosuggestions | 85919cd1ffa7 |
| zsh-syntax-highlighting | zsh-users/zsh-syntax-highlighting | e6683f20e5c3 |

插件使用上游 Git 默认分支；完整 SHA 写入 `share/zsh/plugins-installed.json`。只加载一套语法高亮。fzf-tab、fzf 键绑定及 Starship 在真实交互终端中初始化，不在后台命令里启动 ZLE。

## 平台差异

| 项目 | macOS | Fedora | Steam Deck |
|---|---|---|---|
| 系统基础 | Xcode CLT / 系统 Git | 系统 Git、DNF 开发库 | 现有系统 Git 2.50.1 |
| Homebrew | 保留默认前缀 | 不使用 | 不使用 |
| Emacs | Homebrew `emacs-app` 31.1，已是目标版本，保留安装并重启服务 | GNU 31.1 源码重编译，X11/GTK3 + native compilation | GNU 31.1 源码重编译，X11/GTK3，无 native compilation |
| Emacs 构建依赖 | Brew 的 native 模块开发库 | DNF GCC、GTK3、libgccjit 等 | 应用目录中的独立 Pixi 构建依赖 |
| Modules | Brew 5.7.0 | 系统 5.6.2 | 源码 5.7.0 + 私有 Tcl/编译器 |
| GCC | 保留 Brew GCC；修正 14.4.0、16.2.0 modulefile | 保留系统 GCC/GFortran 与 Intel 工具链 | Pixi GCC/G++/GFortran 16.2.0，独立应用 |
| 登录终端 | 账户原有 Zsh，统一配置 | 保留系统 `/usr/bin/zsh`，统一配置 | 系统账户仍为 Bash；交互 Bash 自动进入用户 Zsh，Konsole 使用 Software Zsh |

Deck 新 Emacs 目录为 `apps/emacs/31.1-r20261021-231122`，Fedora 为 `apps/emacs/31.1-r20261021-230358`。以后应使用 `current` 或 `bin`，不要把这些快照目录写入新配置。

三台机器的 `~/.emacs.d` 都完整链接到各自 checkout 的 `emacs.d`。ELPA、原生模块、缓存、历史等本机数据保留并由 Git 忽略。本轮没有为了平台适配拆分或重写共享 Lisp 配置。

Mac 使用 `org.gnu.emacs.daemon`，Linux 使用用户级 `emacs.service`；每台机器只有一个默认 daemon。服务统一加载 `Software/env.sh`。Mac `.zprofile` 在系统 `path_helper` / Brew 初始化之后恢复命令优先级。Deck 桌面与 Steam 入口继续共用同一个 X11 daemon。

## 删除和保留

- **Fedora**：用户运行清理脚本后，已核验 `fd-find`、`ripgrep`、`fzf`、`zoxide`、`starship`、`bat`、`jq`、`neovim` 八个 RPM 均已卸载；删除 5 个失效或被替代的 Software 环境。保留 Git、系统登录 Zsh、编译器、开发库和 Modules。
- **Deck**：删除 18 个旧版、失败构建或重复环境，包含旧 Emacs、旧 Modules、旧 GCC、旧 Pixi/uv 和多余的 Pixi Git；Git 入口改为系统 `/usr/bin/git`。保留本机源码、项目、配置和数据。旧构建脚本与 modulefile 已改为指向当前安装。
- **Mac**：卸载 10 个重复 Brew 包：fd、fzf、zoxide、starship、bat、jq、neovim、zsh-fast-syntax-highlighting、zsh-autosuggestions、zsh-syntax-highlighting；另删除错误的 Neovim 包环境。Brew ripgrep 是 opencode 的依赖，因此保留，但全局 `rg` 优先使用 Software 版本。未自动清理其他 Brew 依赖。
- **Yazi**：不在安装清单中，已移除旧配置/安装。

已有科研软件没有盲目升级：Mac 的 HDF5、OpenMPI、MPICH、PyOMP、unrpa、oh-my-rime-cli 整理到 `apps`；已有科学 Python 3.12.12 和 openpyxl/Python 3.14.6 环境整理到 `apps/scientific-python`、`apps/openpyxl`，通过 `module load scientific-python/current` 等按需启用。原安装前缀保留兼容链接，以免破坏二进制 RPATH、Python shebang 或项目依赖。Fedora 的 FFTW、HDF5、Intel/MPI 科研环境保留。

Mac 的个人 Python CLI 用 uv 独立工具环境重新安装到 `Software/data/uv/tools`，统一入口为 `Software/bin`。清单及可复用命令在 `manifests/uv-tools*.txt` 和 `scripts/install-uv-tools.sh`。本次 Python CLI 版本：fortls 3.2.2、pyright 1.1.414、arxiv-mcp-server 0.8.2、markitdown-mcp 0.0.1a7、zotero-mcp-server 0.15.1。旧工具环境已删除，旧命令路径改为兼容链接。

科研环境与 Python CLI 是不同用途，不将科研环境的 Python 强制设为全局 Python。

## 验证与边界

已验证 Deck GCC/GFortran 实际编译和运行小程序、module 卸载恢复变量，以及三平台命令版本与入口、交互 Zsh 插件、Modules 加载、完整 Emacs 配置、daemon 应答、Tree-sitter、vterm 原生模块加载和 PDF Tools 的 epdfinfo 自检。旧环境删除前检查了活动入口及 Linux 进程映射。自动测试覆盖部署备份/幂等、运行数据冲突、无副作用计划、安装失败保留旧入口，以及激活脚本保留调用方 PATH。

Deck 的只读状态仍为 `enabled`；本轮没有修改系统分区、Tailscale 或电源设置。Steam 启动器和单后台路径已核验，本轮没有切换游戏/桌面会话进行完整 UI 回归。

Ubuntu/Debian 的系统依赖适配和管理员 `--scope system --prefix /opt/Software` 流程已加入代码；尚未在 Ubuntu 或实际共享管理员安装中完成实机验证。共享安装不创建所有用户共用的 Emacs server；个人数据、凭据及缓存仍归各用户所有。

## 清单、备份与后续更新

每台机器的 `~/Software/docs/installed.json` 保存实际应用收据、传递依赖、Git 插件提交、uv 工具收据及系统包版本；`verification.json` 保存命令与 Emacs 检查结果。Mac 的 Brew 清单查询提示残留的 codexbar Cask 记录不完整，快照保留了这个警告；本轮没有处理无关 GUI 应用。系统包清单是只读审计，列出不代表本次重新安装。项目 `.venv`、`node_modules` 和游戏内容不在此清单范围内。

```sh
cd "$PROFILE_HOME"
python3 scripts/inventory.py --system --output ~/Software/docs/installed.json
./bootstrap.sh check
./bootstrap.sh update
software-app update fd ripgrep
python3 scripts/software.py managers
bash scripts/install-uv-tools.sh
```

升级 Emacs 后，先保存缓冲区再重启服务；更新不会自动终止正在编辑的后台。

原配置、旧链接和迁移记录在各机 `Software/backups`。本轮主要前置备份为 `unified-20261021-*`，后续操作分别记录在 `profile-*`、`finalize-*`、`layout-*`、`removed-envs-*`。被删除的旧应用只保留 manifest/lock/receipt 等重建信息，没有保留完整二进制副本；回退这类程序需要重新安装。个人设置留在 `config/local`，不进入 Git。
