# workbench 使用说明

完整入口和安装方式见 [README](../README.md)，组件协议见 [architecture](architecture.md)。

| 需求 | 命令 |
| --- | --- |
| 列出所有功能 | `workbench list` |
| 查看组件能力 | `workbench tools --help` |
| 查看对象和安装状态 | `workbench tools list` |
| 安装整个工作站 | `workbench system install` |
| 检查整个工作站 | `workbench system check` |
| 预览 Fedora 安装 | `workbench --platform fedora system install --plan` |
| 显式升级整个工作站 | `workbench system update` |
| 更新基础管理器 | `workbench managers update uv` |
| 更新 CLI | `workbench tools update fd ripgrep` |
| 更新 Zsh 插件 | `workbench plugins update` |
| 检查语言服务器 | `workbench languages check --probe` |
| 安装 Emacs 包 | `workbench emacs install packages` |
| 启用 Emacs 服务 | `workbench emacs start` |
| 查看 Emacs 状态 | `workbench emacs status` |
| 部署本地配置 | `workbench profile apply` |
| 拉取并部署配置 | `workbench profile update` |
| 更新订阅 | `workbench network update mihomo` |
| 检查所有 Deck 网络服务 | `workbench network check all` |
| 首次 Deck 网络授权（本机） | `workbench network apply all` |
| 新增本机功能 | `workbench components create my-app` |
| 验证组件与依赖图 | `workbench components check` |

system update 会更新原生组件，Linux 上可能重新编译 Emacs；日常配置同步用 profile update。
配置 apply 保留正在运行的 Emacs；需要重启时显式调用 emacs restart。
网络软件或订阅更新可能在内容发生变化后重载相应服务。

公开入口是 bin/workbench；libexec 下的文件属于后端实现，不作为新的日常命令推广。
扩展直接放 Software/extensions，公共功能放 components；不再使用 manage.d。

## 终端输出

终端中自动启用配色，列表按中英文显示宽度对齐；步骤使用 `[1/3]`、
`[OK]`、`[PENDING]`、`[FAIL]` 等标记，颜色之外也能辨别状态。
帮助中的 `<参数>` 表示必填，`[参数]` 表示可选，`...` 表示可重复。
例如 `workbench components create <name> [--shared]`。

重定向、管道、`TERM=dumb` 或设置 `NO_COLOR` 时不输出颜色；
`--json` 和补全数据始终保持机器可读。安装日志会移除 ANSI 颜色控制码。

```sh
workbench --help
workbench profile apply --help
NO_COLOR=1 workbench list
workbench tools update fd --plan --json
```
