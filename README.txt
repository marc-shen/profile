profile：macOS / Fedora / Steam Deck / Ubuntu
===========================================
统一配置与 Software 布局。安装策略见 docs/Software.txt。
本次迁移记录见 docs/environment-migration-2026-10-21.md。
docs/software-inventory.md 是迁移前的审计快照，保留用于对照。

快速部署
--------
前提：系统 Git、curl、证书和 Python 3.9+。
Mac：先 xcode-select --install，再按 https://brew.sh 安装 Homebrew。
Fedora：sudo dnf install git curl ca-certificates python3
Ubuntu：sudo apt-get install git curl ca-certificates python3
Steam Deck：使用现有系统组件，绝不解除只读或用 pacman 修改系统。

  git clone https://github.com/marc-shen/profile.git ~/Software/src/profile
  cd ~/Software/src/profile
  ./bootstrap.sh plan
  ./bootstrap.sh install
  bash scripts/install-emacs-packages.sh
  ./bootstrap.sh service
  exec ~/Software/bin/zsh -l
  ./bootstrap.sh check

当前修改未自动 commit/push；推送之前，新机器需要复制这个工作树。
Mac/Fedora/Deck 实机验证；Ubuntu 适配包含在代码中，尚未在 Ubuntu 实机验证。

安装与更新
----------
系统 Git 不重复安装。Pixi/uv 使用上游官方二进制，下载后校验 SHA256。
终端工具统一使用独立 Pixi 环境；工具与 Conda 包名映射在 manifests/tools.json。
Zsh 插件从上游默认分支更新，实际提交记录于 share/zsh/plugins-installed.json。
Mac Emacs 由 Homebrew 管理；Linux 从 GNU 稳定版源码编译。
Fedora/Ubuntu 使用系统开发库构建；Deck 使用应用内部的 Pixi 构建依赖。
每次安装解析最新兼容版本，保留实际 lock 和 receipt.json，不写死安装版本。

  ./bootstrap.sh update
  software-app install fd ripgrep
  software-app update fd ripgrep
  python3 scripts/software.py managers
  python3 scripts/build-emacs.py --deps system
  python3 scripts/build-emacs.py --deps pixi
  python3 scripts/install-gcc.py       # 可选：Linux GCC/G++/GFortran

update 显式更新并重新部署配置；不自动杀死正在编辑的 Emacs。
新版本安装在最终目录，验证成功后切换 current；失败保留旧入口。
--reinstall 可用于重装 Pixi 工具。源码 Emacs 使用新的构建目录。
项目自身的依赖约束、.venv 和 lock 属于项目，不由全局配置升级改写。

可选 Python CLI：
  bash scripts/install-uv-tools.sh        # fortls、pyright
  bash scripts/install-uv-tools.sh arxiv-mcp-server markitdown-mcp zotero-mcp-server
这些程序使用 uv 独立工具环境；MCP 登录、服务凭据仍由用户在本机配置。

安装清单：
  python3 scripts/inventory.py --system --output ~/Software/docs/installed.json
该只读快照包含应用来源、实际依赖、插件提交、uv 收据及系统包版本。

配置
----
~/.zshrc 链接到共享 zshrc；.zshenv 加载轻量环境。
~/.emacs.d 完整链接到本机 Git checkout 的 emacs.d，不拆分配置文件。
本机运行数据如 elpa、eln-cache、var、tree-sitter 由 .gitignore 排除。
私有变量放 ~/Software/config/local/env.sh；NVM、Bun 等放 local/zshrc。
这些文件不进入 Git。原文件在 Software/backups 中备份。

所有平台初始化 Modules、补全、fzf、fzf-tab、zoxide、Starship、自动建议和语法高亮。
只加载 zsh-syntax-highlighting 一套高亮。编译器通过 module 按需加载。
不会全局设置 CC、CFLAGS、LD_LIBRARY_PATH，也不伪造 DISPLAY。
系统登录 shell 与命令安装分开；账户使用的系统 zsh 不因清理重复工具而卸载。

Emacs
-----
em/ec 都连接当前用户唯一的默认 server；ec 等待编辑完成。
Mac 使用 org.gnu.emacs.daemon；Linux 使用 emacs.service。
Deck 始终使用 X11 构建，桌面与 Steam 游戏模式连接同一个后台。
图形会话退出导致 X 服务消失时，daemon 仍可能退出；不能保证未保存缓冲区跨会话存活。
运行中的服务不会因 link 自动重启。切换服务前应检查并保存缓冲区。

共享安装
--------
  sudo ./bootstrap.sh install --scope system --prefix /opt/Software

共享目录仅管理员可写，缓存、凭据和运行数据属于各用户。
Mac Homebrew 依然由其拥有者安装和维护，不能用 root 运行 brew。
系统范围部署不替换个人 .zshrc/.emacs.d，也不启动共用 Emacs daemon。
各用户仍在自己的 Git checkout 执行 ./bootstrap.sh link 和 service；
公共 /opt/Software/bin 自动加入 PATH，个人 ~/Software/bin 优先。
Steam Deck 不使用 /opt 共享部署。共享部署流程尚需目标系统实际提权验证。

目录整理、回退及科学计算环境说明见 docs/Software.txt 与本次迁移记录。
