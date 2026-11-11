# workbench

一套用于 macOS、Steam Deck、Fedora、Ubuntu 的个人工作站管理工具。
配置共享，安装与服务操作按平台实现；软件和数据默认保存在 `~/Software`。
框架仅依赖 Python 3.9+ 标准库，模块可用任意可执行语言编写。

## 从零安装

在目标机器以普通用户取得本仓库或解压源码包后运行：

```sh
./install.sh --plan          # 先查看完整方案，不安装、不联网
./install.sh                 # 安装适合当前平台的完整方案
```

Fedora/Ubuntu 自动补齐 Python、Git、curl 等基础依赖，并用 sudo 安装系统构建依赖。
macOS 自动安装缺失的 Homebrew；如未安装 Apple Command Line Tools，会打开系统安装提示，
完成后重跑同一命令。Steam Deck 保持系统只读，编译依赖使用用户目录下的 Pixi 环境。

已有环境也可以重复运行：install 保留已安装组件，补齐缺失项；update 才显式升级。
安装出错会停止并记录失败步骤，解决原因后重跑原命令，不需要清空 Software。
整机安装包括工具、Zsh 插件、Node/npm/nvm、Emacs、语言服务器、Lisp 包、WezTerm、
配置部署与 Emacs 用户后台；末尾执行整套检查。Deck 方案还包含网络客户端、服务准备和检查。

代理订阅、Tailscale 登录、系统管理员授权属于本机输入，不能从 Git 恢复。
Deck 首次网络授权需在本机终端执行；缺少这些输入时不会报告“全部完成”。
请勿以 root 运行整套安装，也不要关闭 SteamOS 只读。

仅做最小引导（保留 bootstrap 的原本职责）：

```sh
./bootstrap.sh              # Software 布局、入口、PATH、缺失的 uv/Pixi
. ~/Software/env.sh
workbench system install   # 后续再安装完整方案
```

## 统一命令

所有模块采用 `workbench <模块> <操作> [对象…]`。
`list` 查看对象，`check` 检查本机，`install` 补齐，`update` 更新，`apply` 应用配置。
服务模块额外声明 `start/stop/restart/status/logs`，不支持的能力会明确拒绝。
帮助、平台支持、补全和依赖计划来自同一份 `module.json`。

```sh
workbench list
workbench system list
workbench system install base        # 基础 CLI / Shell
workbench system install workstation # 完整开发工作站
workbench system install steamdeck   # 工作站 + Deck 网络（Deck 专用）
workbench system install scientific  # Linux 可选科研扩展：GCC/Fortran、TeX、Python CLI
workbench system check
workbench tools update fd ripgrep
workbench plugins list
workbench languages check --probe
workbench emacs status
workbench network update mihomo
workbench network check all
workbench profile apply              # 部署当前 checkout
workbench profile update             # Git 快进拉取，再部署
```

任何操作可加 `--plan` 查看其 argv 计划；此时不执行模块、不下载、不写入。
`--platform` 可用于在 Mac 上检查 Linux 安装计划，但不能伪装成另一平台执行安装。

```sh
workbench --platform ubuntu system install --plan
workbench --platform fedora system install --plan --json
workbench tools update --help
```

`profile update` 会拒绝有未提交修改的仓库。`profile apply` 可以部署当前工作树。
现有终端运行 `source ~/.zshrc` 或新开终端后启用新版补全。Bash 也提供模块/操作/对象补全。

## 目录与扩展

```text
bin/workbench             唯一公共总入口
lib/workbench/            发现、校验、依赖图、计划、执行与状态记录
modules/<名称>/            module.json + 独立实现
platforms/<平台>/          OS 依赖清单与平台资源
profiles/                  整机安装方案（有序模块操作组合）
config/                    Shell、Emacs、Helix、WezTerm 等共享配置
catalog/                   工具、语言服务器、插件与版本来源清单
libexec/                   可复用的安装/部署后端（内部实现）
examples/modules/          可运行的扩展示例
install.sh                 完整初始化
bootstrap.sh               最小引导
```

```sh
workbench modules create my-app          # 创建 ~/Software/extensions/my-app
workbench modules create my-app --shared # 创建仓库 modules/my-app（两者二选一）
workbench my-app list
workbench my-app install
workbench my-app check
```

生成的示例实际管理一个用户目录中的演示文件；将其 run.py 替换为你的安装逻辑即可。
不需要修改核心注册表。平台专用入口、依赖、可选操作和模块协议见
[架构与扩展](docs/architecture.md)，日常操作见 [使用说明](docs/workbench.md)。

运行数据位于 `Software/data`，日志位于 `Software/logs`，备份位于 `Software/backups`，
私人配置位于 `Software/config/local`。Emacs 包与缓存迁至 `Software/data/emacs`，
通过本机链接接入配置。订阅和密钥不放入模块、配置仓库或安装方案。
旧版本升级保留本机兼容链接，避免已有进程、服务和启动器立即失效；新架构不再扫描 manage.d。

源码包可用 `python3 libexec/export-source.py /path/workbench-source.tar.gz` 生成，
只包含安装代码与共享配置，不包含运行数据和私人设置。源码包支持 apply/install；Git update 需要 Git checkout。
