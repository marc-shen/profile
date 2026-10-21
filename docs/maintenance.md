# 日常维护

[返回项目说明](../README.md) · [多设备同步](sync.md) · [Software 规范](Software.txt)

本文命令默认使用个人安装 `~/Software`，并在 `~/Software/config/profile` 内执行。源码编译、软件升级和 Git 拉取是独立操作。

## 选择合适的操作

| 目标 | 命令 | 操作范围 |
|---|---|---|
| 查看平台与安装策略 | `./bootstrap.sh plan` | 概览，无安装动作；不是逐包差异报告 |
| 检查入口和插件目录 | `./bootstrap.sh check` | 只读；不等于完整功能测试 |
| 重新部署配置 | `./bootstrap.sh link` | 链接配置，必要时备份原文件；不安装软件 |
| 只重新部署 Shell 配置 | `./bootstrap.sh link --only shell` | 不部署 Emacs 配置 |
| 只重新部署 Emacs 配置 | `./bootstrap.sh link --only emacs` | 不替换 Zsh 配置 |
| 安装或更新指定基础工具 | `software-app install fd ripgrep` | 按当前清单解析版本，验证后切换入口 |
| 更新管理器及指定基础工具 | `software-app update fd ripgrep` | 先更新 Pixi/uv，再更新指定工具 |
| 仅更新官方管理器 | `python3 scripts/software.py managers` | Pixi、uv；不更新其他工具 |
| 更新 Zsh 插件和管理器补全 | `python3 scripts/plugins.py` | 上游 Git HEAD，拒绝覆盖脏插件工作树 |
| 安装/升级默认 Python CLI | `bash scripts/install-uv-tools.sh` | 默认 fortls、pyright；额外包可通过参数指定 |
| 维护完整安装环境 | `./bootstrap.sh update` | 管理器、全部基础 CLI、平台依赖、Emacs、插件，再部署配置 |

`bootstrap.sh update` 在 Linux 会源码重编译 Emacs，在 Deck 还会构建 Modules；它不只是刷新配置，也不自动升级 ELPA、所有 uv 工具或个人科研环境。`--reinstall` 可让 Pixi 基础工具重装。

`--only` 控制配置部署范围，**不是 install/update 的软件过滤器**；不要用 `./bootstrap.sh update --only shell` 来期待跳过 Emacs 编译。

## 版本、依赖和目录

稳定入口在 `Software/bin`；自动安装的应用通常在 `apps/<名称>/<版本>`，`current` 指向选定版本。重建可能带有 `-r<时间戳>` 后缀。安装配方、锁文件和收据属于本机实际安装记录，目录名不应限制未来升级。

```sh
software-app list
python3 scripts/software.py list
python3 scripts/inventory.py --system --output ~/Software/docs/installed.json
```

第一条列出应用目录，第二条列出具有 current 收据的应用，第三条导出应用来源、依赖、插件提交、uv 收据和系统包列表。快照覆盖安装器可识别的内容，不枚举所有项目环境、游戏或手工安装文件。

新环境应在最终目录安装。不要直接移动已安装的 Pixi 环境，或对版本目录里的管理器执行原地 self-update；它们可能含绝对路径，且会造成目录名与实际版本不符。

## Emacs 后台

`em`、`ec` 使用当前用户的默认 `server`。客户端在连接失败时尝试启动已有的用户服务；首次使用前应执行 `./bootstrap.sh service` 创建服务定义。此命令不会为了配置更新终止已运行的 daemon。

**重启前先保存所有需要保留的缓冲区。** `ec` 的 `C-x #` 结束客户端编辑等待，并不会关闭后台。

### Linux：Fedora、Steam Deck、Ubuntu / Debian

```sh
systemctl --user status emacs
systemctl --user restart emacs
emacsclient --eval '(list emacs-version (daemonp) init-file-had-error)'
```

后台可能需要几秒加载配置；如查询尚未成功，查看日志后稍后重试：

```sh
journalctl --user -u emacs -n 80 --no-pager
```

如果服务定义有变化，先运行 `./bootstrap.sh service` 更新定义，再重启。

### macOS

查看状态：

```sh
launchctl print "gui/$(id -u)/org.gnu.emacs.daemon"
```

仅重启进程、继续使用当前已加载的服务定义：

```sh
launchctl kickstart -k "gui/$(id -u)/org.gnu.emacs.daemon"
```

修改了 LaunchAgent 定义时，先运行 `./bootstrap.sh service` 写入配置。保存工作后重新登录 macOS，可以重新加载定义；无需为一次普通 Lisp 修改重载整个 LaunchAgent。

### Emacs 本体和包

- Mac 的 Emacs 本体由 Homebrew 管理。
- Fedora / Ubuntu / Debian：`python3 scripts/build-emacs.py --deps system`。
- Deck：`python3 scripts/build-emacs.py --deps pixi`，依赖在应用内部。
- 安装缺少的配置包：`bash scripts/install-emacs-packages.sh`。包安装和本体升级分开维护。

Deck 更新 Emacs 或 vterm/PDF Tools 后，需要按新前缀重建 native 模块：

```sh
bash platform/steamdeck/scripts/rebuild-native.sh
```

共享完整 `emacs.d` 的源码配置，保留各机自己的 `.so`、`.eln` 和插件安装数据。Steam 游戏模式入口与会话切换限制见 [Steam Deck 说明](Steam-Deck.txt)。

## 编译器和复杂环境

先查看本机模块，不假设另一台机器的安装版本也存在：

```sh
module avail
module list
```

可选的 Linux GCC/G++/GFortran 配方：

```sh
python3 scripts/install-gcc.py
module load gcc/current
gcc --version
gfortran --version
module unload gcc
```

该配方也发布稳定的 gcc/cc/g++/c++/gfortran 命令入口；`module load` 用于设置 `CC`、`CXX`、`FC` 等完整环境。macOS 使用系统 Clang 或已有 Homebrew GCC，不能运行这个 Linux 配方。

创建独立项目工具环境，不向全局 PATH 发布项目 Python：

```sh
software-app create experiment-tools 1 python numpy scipy
software-app run experiment-tools 1 python --version
software-app module experiment-tools 1
module load experiment-tools/1
module unload experiment-tools
```

这里 `1` 是你为环境选择的目录标签。`create` 要求新目录；`module` 不覆盖已有模块文件。若显式使用 `software-app select` 发布命令，遇到已有全局入口会拒绝覆盖。

实际 modulefiles 位于 `Software/share/modulefiles`。历史科研程序可能依赖绝对路径，整理时保留的旧路径链接不是重复安装；详细规则见 [Modules 说明](../modulefile.md)。

## 本机设置和终端

通用配置从 checkout 加载；本机覆盖保存在：

```text
~/Software/config/local/env.sh     # Bash/Zsh/服务均可能读取，使用兼容 Shell 语法
~/Software/config/local/zshrc      # 仅交互 Zsh，可放本机集成
```

只放非敏感环境设置或本机需要的私有配置，不提交这些文件。Shell 加载它们的时机不同；环境变量变化后，已经启动的服务不会自动更新。

安装器不改 `/etc/passwd` 或账户登录 shell。`exec ~/Software/bin/zsh -l` 只切换当前终端。已有 Deck 的 Konsole 使用用户 Zsh，交互 Bash 有进入 Zsh 的本机配置；这个历史设置不代表新 clone 会自动修改终端默认项。新机器可在终端应用里设置启动命令 `~/Software/bin/zsh -l`。

## 管理员共享安装（待验证）

```sh
./bootstrap.sh plan --scope system --prefix /opt/Software
sudo ./bootstrap.sh install --scope system --prefix /opt/Software
```

`--scope system` 安装公共程序和配置副本，配置系统 Shell 入口；不替换所有用户的 `.zshrc` / `.emacs.d`，也不创建公用 Emacs daemon。共享目录由管理员维护，用户数据仍应保存在各自 Home。

此路径尚未完成端到端验证。个人部署脚本、插件目录和 daemon 默认按个人 Software 前缀查找；接入共享安装时需逐项确认，而非简单复制共享目录。Linux 个人服务使用共享 Emacs 时，原生程序入口可通过本机 `EMACS_BINARY` 指定，例如 `/opt/Software/bin/emacs-real`，但插件与完整用户部署仍需单独核验。

Mac 应由 Homebrew 拥有者先运行 `brew bundle install --file=manifests/Brewfile`；管理员流程不会以 root 安装 Homebrew。SteamOS 共享部署被拒绝，继续使用 `~/Software`。

## 检查、失败和恢复

```sh
cd ~/Software/config/profile
./bootstrap.sh check
command -v git zsh pixi uv fd rg emacsclient
ls -ld ~/.zshrc ~/.emacs.d ~/Software/config/profile
```

| 现象 | 先检查什么 |
|---|---|
| pull 后别名没变化 | 是否拉到了正确分支；重开终端或 `source ~/.zshrc` |
| Emacs 仍使用旧配置 | 是否只关闭了窗口；确认后台已重启 |
| 命令缺失 | 配置拉取不会安装软件，检查对应安装清单和 PATH |
| fzf-tab 没加载 | 需真实交互 Zsh，后台 `zsh -c` 不会启用相关界面 |
| Modules 命令存在但某个环境没有 | `module avail`；该机器是否安装并生成了对应 modulefile |
| 部署报告 Emacs runtime collision | 对照已有 `~/.emacs.d` 和 checkout 的运行数据，先备份并核对 |
| 更新下载或求解失败 | 检查网络及具体日志；安装器不会因此静默切换来源 |

部署备份位于 `Software/backups/profile-*`，其他安装或迁移过程也可能产生单独备份目录。回退配置时按其中记录恢复对应文件；旧应用若仅保留 lock/receipt，就需要按记录重装，而不能直接从收据恢复二进制。

清理旧版本前确认 `current`、命令入口、native 模块和运行中进程已切换。不要删除 `data`、科研项目或仍被依赖的系统包。移除安装清单中的条目不会自动执行卸载。
