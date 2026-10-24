# 多设备同步

[返回项目说明](../README.md) · [维护指南](maintenance.md)

Git 同步配置和安装清单；软件、依赖与运行数据在各设备本地管理。各机器的 checkout 可以位于不同目录，部署后的统一入口是 `~/Software/config/profile`。

## 一次完整的同步

### 在修改设备提交并推送

先拉取其他设备已推送的修改，再开始编辑，可以减少冲突。以下以修改 `zshrc` 为例：

```sh
cd ~/Software/config/profile
git status
git pull --ff-only
# 编辑 zshrc 后：
git diff -- zshrc
git add zshrc
git diff --cached
git commit -m "调整终端配置"
git push
```

使用 `ec` 填写提交信息时，编辑完成按 `C-x #` 结束等待。若不传 `-m`，`git commit` 会调用配置的编辑器。

也可在确认所有变化都应提交后使用 `gap -m "调整终端配置"`。`gap` 会暂存**整个仓库**，不只是当前目录；分块选择使用 `gap -p`，其余参数继续传给 `git commit`。只需提交部分文件时，显式 `git add 文件名` 更清楚。

`git commit` 只创建本地提交；只有 `git push` 成功后，其他设备才能从远程取得它。默认 `git push` 依赖分支的远程配置，GitHub 推送认证需要事先配置。

### 在接收设备快速同步

已经部署过的个人设备，推荐：

```sh
cd ~/Software/config/profile
./bootstrap.sh sync
# 需要一起补装新增工具、插件和语言服务时：
./bootstrap.sh sync --install-missing
```

`sync` 要求工作树干净，使用 `git pull --ff-only`，然后执行**刚拉取的新版本**部署脚本。不会自动 stash、丢弃本地修改或强制合并。两端应使用同一分支。[Git 官方说明](https://git-scm.com/docs/git-pull)

如果已手动 `git pull`，或正在调试本地配置：

```sh
./bootstrap.sh apply --plan                 # 离线预览，不写入、不下载
./bootstrap.sh apply                        # 部署配置并报告缺失依赖
./bootstrap.sh apply --install-missing      # 同时补装缺失依赖
./bootstrap.sh apply --only emacs           # 只更新 Emacs 配置、入口及服务定义
./bootstrap.sh check
```

首次从旧版脚本升级，需要先手动 `git pull --ff-only`，再运行 `apply`。首次装机仍使用 README 的安装流程；`apply --install-missing` 不会隐式源码编译缺失的 Emacs 本体，也不负责安装全部 ELPA 包或 Tree-sitter grammar。

`apply` 会修复配置链接、补齐新命令、更新 macOS 的 Emacs Client.app、执行现有的配置迁移，并写入服务定义；不停止或重启 Emacs。Linux 写入服务定义后执行 `daemon-reload`，不启动服务；macOS 仅写 plist。首次启动仍使用 `./bootstrap.sh service`。Dock 应用更新后退出并重新打开 Emacs Client，后台仍可保留。

部署状态保存在 `Software/data/profile/deployment.json`，按 Shell、Emacs、Helix 分别记录内容指纹与提交号。因此先手动拉取也不会遗漏待部署变化；本地未提交配置可以 `apply`，状态会标记 dirty。失败时保留上次成功的配置快照及失败步骤，重跑即可继续。缺失依赖会单独记录：仅配置已部署但仍有依赖缺失时退出码为 **2**，执行失败为 **1**，完成为 **0**。日志位于 `Software/logs/profile-*.log`。

重复 `apply` 仍会检查并修复链接，已部署内容保持不变。它不是整个桌面环境的事务回滚；部分步骤失败时，已完成的操作可能已经生效，原配置备份位于 `Software/backups/`。

清单中已安装的工具不因 `apply` 自动升级或卸载。需要升级时显式选择：

```sh
./bootstrap.sh upgrade --plan
./bootstrap.sh upgrade --component tools --tool fd --tool ripgrep
./bootstrap.sh upgrade --component languages
./bootstrap.sh upgrade --component languages --tool python --tool fortran
./bootstrap.sh upgrade --component plugins
./bootstrap.sh upgrade --component managers
./bootstrap.sh upgrade --component emacs
./bootstrap.sh upgrade --component all      # 包含 Linux Emacs 源码构建
```

默认 `upgrade` 只升级清单中的基础 CLI 工具；`--tool` 仅用于 tools/languages，不能与其他 component 混用。软件升级后执行 `apply`，再按提示重新加载应用。`apply/sync/upgrade` 当前面向个人安装；管理员 `/opt/Software` 部署仍是单独且未完成端到端验证的流程。

## 拉取后怎样生效

| 改动 | 接收设备上的操作 |
|---|---|
| `zshrc`、Shell 函数/别名 | `source ~/.zshrc`，或重开终端 |
| `shell/env.sh` / 本机环境入口 | 新开登录 Shell；已运行的 Emacs 等进程需单独重启 |
| `starship.toml` | 已启用 Starship 的新提示符读取配置；必要时重开终端 |
| `helix/` 配置 | 首次运行 `./bootstrap.sh link --only helix`；之后在 Helix 中执行 `:config-reload` 或重新启动 |
| Emacs Lisp 配置 | 保存缓冲区后重启后台；具体命令见维护指南 |
| Emacs 包清单新增依赖 | `bash scripts/install-emacs-packages.sh`，再重启 Emacs |
| `manifests/tools.json` 新增或调整工具 | `software-app install 工具名`；多个工具名可一起传入 |
| Zsh 插件来源 | `python3 scripts/plugins.py`，再重开终端 |
| `manifests/language-servers.json` / 默认 Python 工具 | `python3 scripts/language-servers.py install`；升级用 `upgrade --component languages` |
| 新增配置链接、部署脚本变化 | `./bootstrap.sh apply` |
| Emacs 服务定义变化 | `./bootstrap.sh service`，保存工作后按维护指南重启/重载服务 |

Neovim 配置现归档于 `archieve/nvim/`。拉取后运行 `./bootstrap.sh link --only shell`，会备份并移走指向此 checkout 的旧 `~/.config/nvim` 链接；独立配置目录和其他来源的链接不受影响。新开终端后，profile 不再设置 Neovim 编辑器或 `vim` / `vimdiff` 别名。已安装的 Neovim 程序及插件数据保留，不会自动删除。

清单是期望配置，不会自动卸载已移除的工具。`uv-tools-mcp.txt` 是可选项目列表，不由默认 uv 安装命令自动遍历；需要的包作为参数传给安装脚本。

若只变更某些 Shell 变量，`source` 不一定能消除旧会话里已经加载的函数、变量或 module 状态；重新打开终端最容易得到干净的配置。关闭 Emacs 窗口不会结束 daemon，后台仍可能使用旧配置。

## 接收设备也有修改怎么办

先看 `git status`、`git diff` 和 `git diff --cached`。不要用强制重置来替代核对。

### 修改还没有提交

可以先提交有意义的改动，或临时保存工作树后再拉取：

```sh
git stash push -u -m "同步 profile 前的本地修改"
git pull --ff-only
# 仅在拉取成功后恢复：
git stash apply 'stash@{0}'
git status
git diff
```

`stash apply` 会保留原 stash。如果出现冲突，先编辑冲突文件，检查结果并暂存；确认本地修改完整恢复后，再删除对应记录：

```sh
git stash list
git stash drop 'stash@{0}'
```

以上编号假设中途没有新增其他 stash；删除前应核对说明。`-u` 包含未跟踪文件，不包含 `.gitignore` 排除的 Emacs 包、缓存等内容。

即使某个改动曾经手动复制到另一台机器，也不能据此认为两个 Git 工作树同步完成；仍要核对提交和未提交变化。

### 两台设备各自已经提交

此时 `git pull --ff-only` 可能提示分叉。先查看双方提交：

```sh
git fetch
git log --oneline --graph --decorate --all -20
```

工作树干净且**本地提交尚未推送**时，可以把它们重新应用到上游之后：

```sh
git rebase '@{upstream}'
```

冲突处理后执行 `git rebase --continue`；放弃此次重放用 `git rebase --abort`。如果两边的提交都已经共享，通常应合并上游：`git merge '@{upstream}'`。核对结果后再 `git push`。未设置 upstream 的分支需先确认远程和分支名。

## 哪些内容会同步

| 内容 | 是否通过本仓库同步 |
|---|---|
| 已跟踪的 Zsh、Emacs、Helix、Starship、WezTerm 配置及归档文件 | 是 |
| 安装脚本、软件清单、可复用 modulefile 模板 | 是 |
| `~/Software/config/local/env.sh`、`local/zshrc` | 否，本机设置 |
| Emacs `custom.el`、ELPA、`.eln`、native 模块、历史、缓存 | 否，以 `.gitignore` 为准 |
| `Software/apps`、`cache`、`data`、本机生成的 modulefiles | 否，在目标平台安装或生成 |
| SSH 密钥、认证文件、API 密钥 | 不应加入这个仓库 |

Emacs Customize 保存到 `custom.el` 的设置不会自动到达其他设备。需要共享时，把相应设置移入仓库已跟踪的 Lisp 文件。普通配置中也不要直接写密钥，优先使用本机环境或工具自己的凭据存储。

## 新设备与已部署设备

新设备先按 [README 的快速部署](../README.md#快速部署) 安装并建立链接。已经部署的设备，通常使用 **sync → 按提示重新加载**。不必为了一个别名或键位变化执行全套 `bootstrap.sh update`。
