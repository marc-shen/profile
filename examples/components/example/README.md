# 独立组件示例

此示例只管理 Software/data/extensions/<组件名称>/example.txt。
修改 component.toml 声明平台、依赖、操作；修改 run.py 实现实际安装逻辑。
install 补齐缺失项目，update 显式更新，check 失败时返回非零。
list/check 应保持只读，帮助和 Tab 补全不会执行 run.py。
不要把凭据放进组件目录。
