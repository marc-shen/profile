# workbench 2 架构

## 职责边界

- `bin/workbench` 是稳定入口；`lib/workbench` 使用 Python 标准库，无需先安装 PyPI 包。
- `components/<名称>/component.json` 是功能合同；`run.py` 或其他入口负责实现。
- `platforms/` 保存平台依赖和资源。macOS 用 Homebrew；Fedora 用 dnf；Ubuntu 用 apt；SteamOS 用用户目录 Pixi。
- `profiles/` 定义完整环境由哪些操作组成。平台差异不复制一整套管理工具。
- `config/` 保存可版本管理的配置，`catalog/` 声明下载/软件来源；`libexec/` 是安装与部署的内部后端。
- `Software/extensions/` 是本机扩展目录。它与共享 components 使用相同协议；同名冲突报错，不静默覆盖。

## 命令与能力

固定形式为 `workbench COMPONENT ACTION [TARGET ...]`。通用操作的语义保持一致：

| 操作 | 约定 |
| --- | --- |
| list | 只读展示对象或状态，不联网安装 |
| check | 验证本机状态，失败返回非零 |
| install | 补齐缺失项，已有可用安装保持不变 |
| update | 用户明确要求更新选中对象 |
| apply | 应用配置、服务定义或必要授权 |
| start/stop/restart/status/logs | 仅服务组件提供 |

配置组件的 update 更新 Git 配置；插件组件更新上游 Git 插件；网络组件更新所选服务。
具体能力在帮助中声明；不会给不存在后台的 CLI 工具伪造 start/stop。
网络入口统一为 `workbench network update mihomo`，操作在前、对象在后。

## 组件协议

最小示例参见 `examples/components/example`。重要字段：

```json
{
  "schema": 1,
  "name": "my-app",
  "description": "我的应用",
  "platforms": ["macos", "steamdeck", "fedora", "ubuntu"],
  "requires": ["managers"],
  "entrypoint": ["{python}", "{component}/run.py"],
  "entrypoints": {
    "macos": ["{python}", "{component}/macos.py"]
  },
  "targets": ["client", "server"],
  "actions": {
    "list": {"description": "列出对象"},
    "check": {"description": "检查本机"},
    "install": {"description": "安装缺失项"},
    "update": {"description": "更新所选对象"}
  }
}
```

入口获得 `ACTION` 和后续参数的独立 argv，不经过 eval。占位符包括
`{python}`、`{repo}`、`{component}`、`{root}`、`{platform}`。
环境提供 SOFTWARE_HOME、SOFTWARE_USER_HOME、WORKBENCH_HOME、PROFILE_PLATFORM、PROFILE_PYTHON。

entrypoints 可按平台覆盖默认入口；单个 action 也可声明 platforms 与 targets。
对象可用静态列表，或 `{"catalog":"catalog/tools.json"}` 从本地 JSON 键读取。
帮助、列表、Tab 只读取声明，不导入或执行第三方组件代码。
扩展是用户明确选择的本机程序，不是沙盒插件，也不会自动获得 root。

install/update 先按 requires 拓扑排序执行依赖的 install，然后执行目标动作；
不会为了更新一个工具而自动更新所有依赖。未知依赖、环、名称冲突和未知对象在执行前拒绝。
系统方案按明确的步骤顺序组合这些组件，并合并重复步骤。方案可用 extends 继承其他方案，
Deck 和科研方案复用 workstation；循环继承和扩大父方案平台范围都会被拒绝。
新增 profiles/*.json 会自动出现在方案帮助和补全中。

## 整机安装与恢复

`install.sh` 在基础 Python/Git/curl 缺失时补齐平台前提，然后调用最小 bootstrap，
最后执行 system install。默认 macOS/Fedora/Ubuntu 使用 workstation，Deck 使用 steamdeck。

方案顺序是平台依赖 → 管理器 → 工具/插件 → 原生编辑器 → 语言服务 → 配置 →
编辑器包 → 终端 → 用户后台 → 全套检查；Deck 再完成网络准备、授权和检查。
base 只提供 CLI/Shell，不要求原生编辑器或后台。

写操作使用跨进程锁。每次运行在 `Software/data/workbench/runs/` 保存状态，
输出保存到权限 0600 的 `Software/logs/workbench-*.log`。状态记录只保留组件和操作，
不会把传入参数（可能包含私人 URL）写进回执；组件作者仍应避免向日志输出秘密。
失败立即停止，记录 returncode。恢复方式是修复原因后重跑同一命令；install 实现需可重复执行，
框架不盲目信任旧“完成”记录而跳过本机检查。update 是显式升级，重复执行可能再次检查上游。

`--plan` 仅解析组件命令，不假装已验证远程软件包是否仍可下载；它不是下载锁文件。
安装器各自保存版本、来源与校验信息。CLI 退出非零时不得将整套安装视为完成。

## 权限与私人状态

无需 root 运行框架，系统依赖或服务授权按步骤调用 sudo。无授权时失败或等待本机输入；
不会修改 sudoers 绕过授权，也不会解除 SteamOS 只读。
macOS 的 Apple CLT 安装对话框和 Homebrew 初次授权受系统限制；无人值守部署需要预先完成
这些 OS 前提，参见 [Homebrew 安装前提](https://docs.brew.sh/Installation)。
Tailscale 登录、代理订阅等身份/私人内容必须由用户提供，空白机器不能从本项目推导这些值。

## 正式版约定

框架统一使用 `components/`、`component.json` 和 `workbench components`。
Environment Modules 的 `module` 命令及其配置路径保持原名。
本机扩展仅读取 `extensions/<名称>/component.json`，入口使用 `{component}`。
安装方案步骤和运行记录使用 `component` 字段。
不保留 `modules`、`manage.d`、`profile upgrade/service` 或独立 `deck-network` 兼容入口。
软件更新使用对应组件的 `update`；Emacs 服务定义使用 `workbench emacs apply service`。
Emacs 运行数据位于 Software/data/emacs；配置部署不重启现有守护进程。
