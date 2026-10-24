# Helix

共享 Mac 原有的主题、相对行号、光标、自动保存、软换行和快捷键，部署到 `~/.config/helix`。`jk` 返回普通模式，`Ctrl-Y` 打开内置文件选择器；原来的 Yazi/Zellij 集成保存在 `archieve/helix-yazi/`，不启用。

```sh
software-app install helix
./bootstrap.sh link --only helix
hx --health
hx 文件名
```

macOS、Fedora、Steam Deck 统一使用 conda-forge/Pixi，安装到 `Software/apps/helix/<version>`，入口是 `Software/bin/hx`。清单不固定版本；版本、依赖和锁文件记录在本机应用目录。更新再次执行安装命令，旧版本保留。Steam Deck 不需要修改系统只读状态。

`languages.toml` 使用 Python basedpyright、Ruff，并保留 TeXLab 保存时构建设置。`./bootstrap.sh apply` 会补装基础语言服务；只执行 `software-app install helix` 不会安装这些服务。Texlab 仍是可选单独安装项。未安装语言服务时编辑和语法高亮仍可使用，相应 LSP 功能不可用。`hx --health python`、`hx --health latex` 可检查本机可用性。

Helix 不替换默认编辑器 `ec`，也不修改 Emacs 内的 `helix-mode` 配置。

参考：[Helix 安装与 runtime](https://docs.helix-editor.com/install.html)、[配置说明](https://docs.helix-editor.com/configuration.html)。
