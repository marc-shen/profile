# 配置同步与软件更新

配置仓库可以放在任意开发路径；bootstrap 将 Software/config/workbench 指向它。
自动安装默认检出到 Software/src/workbench。所有主机使用同一份组件、方案和平台声明。

```sh
workbench profile apply             # 应用当前本地修改
workbench profile update            # Git 快进拉取并部署
workbench profile apply --only shell
workbench profile apply --only emacs --config-only
workbench profile apply --plan
```

update 拒绝有未提交修改的 Git 检出，不自动 stash/reset。apply 允许部署当前工作树。
--config-only 跳过依赖安装和 LSP 探测；缺项会明确报告并返回待处理状态。
普通配置部署不会重启正在运行的 Emacs。服务定义更新后，保存工作再显式重启。

软件更新使用独立组件入口，例如 `workbench node update`、`workbench fzf-tab update`。
整机使用 `workbench system install` 补齐缺失项、`workbench system check` 验证，或显式 `workbench system update` 升级。
组件依赖、整机步骤及检查均来自 TOML；软件安装记录和配置部署快照使用 JSON。
声明不再包含的软件不会自动卸载。

切换到 Workbench 3 后，先运行 `bash bootstrap.sh` 准备托管 Python 3.12 并刷新命令包装器，
再执行 `workbench system install`。旧聚合命令和 JSON 组件声明不再受支持。
本机私有扩展也应使用 component.toml，并声明 category；不自动猜测转换用户脚本。
