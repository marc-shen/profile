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

### 在接收设备拉取

```sh
cd ~/Software/config/profile
git status
git branch --show-current
git pull --ff-only
```

两端应使用同一个仓库和分支。`--ff-only` 只接受快进更新，遇到分叉会停止，留给你明确选择合并方式。[Git 官方说明](https://git-scm.com/docs/git-pull)

首次部署已建立的软链接会自然指向更新后的文件，不需要每次重新复制 `.zshrc` 或 `.emacs.d`。

## 拉取后怎样生效

| 改动 | 接收设备上的操作 |
|---|---|
| `zshrc`、Shell 函数/别名 | `source ~/.zshrc`，或重开终端 |
| `shell/env.sh` / 本机环境入口 | 新开登录 Shell；已运行的 Emacs 等进程需单独重启 |
| `starship.toml` | 已启用 Starship 的新提示符读取配置；必要时重开终端 |
| Emacs Lisp 配置 | 保存缓冲区后重启后台；具体命令见维护指南 |
| Emacs 包清单新增依赖 | `bash scripts/install-emacs-packages.sh`，再重启 Emacs |
| `manifests/tools.json` 新增或调整工具 | `software-app install 工具名`；多个工具名可一起传入 |
| Zsh 插件来源 | `python3 scripts/plugins.py`，再重开终端 |
| `manifests/uv-tools.txt` | `bash scripts/install-uv-tools.sh` |
| 新增配置链接、部署脚本变化 | `./bootstrap.sh link` |
| Emacs 服务定义变化 | `./bootstrap.sh service`，保存工作后按维护指南重启/重载服务 |

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
| 已跟踪的 Zsh、Emacs、Neovim、Starship、WezTerm 配置 | 是 |
| 安装脚本、软件清单、可复用 modulefile 模板 | 是 |
| `~/Software/config/local/env.sh`、`local/zshrc` | 否，本机设置 |
| Emacs `custom.el`、ELPA、`.eln`、native 模块、历史、缓存 | 否，以 `.gitignore` 为准 |
| `Software/apps`、`cache`、`data`、本机生成的 modulefiles | 否，在目标平台安装或生成 |
| SSH 密钥、认证文件、API 密钥 | 不应加入这个仓库 |

Emacs Customize 保存到 `custom.el` 的设置不会自动到达其他设备。需要共享时，把相应设置移入仓库已跟踪的 Lisp 文件。普通配置中也不要直接写密钥，优先使用本机环境或工具自己的凭据存储。

## 新设备与已部署设备

新设备先按 [README 的快速部署](../README.md#快速部署) 安装并建立链接。已经部署的设备，通常只需 **pull → 按修改类型重新加载**。不必为了一个别名或键位变化执行全套 `bootstrap.sh update`。
