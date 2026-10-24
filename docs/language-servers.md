# Emacs 语言服务

Emacs 使用内置 Eglot。语言服务是外部程序，缺少它们时仍能编辑文件，只缺少相应语义补全、诊断和跳转。安装清单统一保存在 `manifests/language-servers.json`，不固定版本。

| 用途 | 程序 | 安装来源 | 位置 |
|---|---|---|---|
| Python 类型检查、补全 | basedpyright-langserver | 官方 PyPI 包，经 uv tool | 本机 `UV_TOOL_DIR`；默认 `Software/data/uv/tools` |
| Fortran 补全、跳转 | fortls | 官方 PyPI 包，经 uv tool | 同上 |
| Python 格式化；Helix Ruff LSP | ruff | 官方 PyPI 包，经 uv tool | 同上 |
| C/C++ | clangd | conda-forge clang-tools，经 Pixi | `Software/apps/lsp-c-cpp/<版本>` |
| Bash | bash-language-server | conda-forge，经 Pixi | `Software/apps/lsp-bash/<版本>` |
| JSON | vscode-json-language-server | conda-forge vscode-langservers-extracted，经 Pixi | `Software/apps/lsp-json/<版本>` |
| YAML | yaml-language-server | conda-forge，经 Pixi | `Software/apps/lsp-yaml/<版本>` |

fortls 的自动自升级被关闭，版本更新统一通过部署命令显式执行。

原有可用命令会被识别并保留，例如 macOS 已有 clangd。旧的 pyright/pylsp 不会自动卸载；Emacs 新会话优先选择 basedpyright，保留 pyright/pylsp 回退。Helix Python 同样使用 basedpyright 和 Ruff。Emacs 的 Ruff 用于手动格式化，不额外启动第二套 Python Eglot 服务。

```sh
./bootstrap.sh apply --plan
./bootstrap.sh apply
python3 scripts/language-servers.py plan
python3 scripts/language-servers.py install python fortran
python3 scripts/language-servers.py check --probe
./bootstrap.sh upgrade --component languages --tool python --tool fortran
```

`install` 只补缺失项，`upgrade` 才主动解析新版本。`apply` 还会验证已有语言服务，因此重试不会把“可执行文件存在但服务启动失败”当作安装成功。安装新语言服务时进行真实的 LSP initialize/shutdown 验证；`check --probe` 同样验证已安装服务，使用独立的临时目录和独立进程，不连接编辑器的项目或后台。安装收据在 `Software/data/profile/language-servers.json`；Pixi 安装另保留应用内锁文件和收据，uv 保留自己的工具收据。

新装机的 `bootstrap.sh install` 包含语言服务安装。无需全局激活项目 Python，也不将语言服务依赖添加到项目环境；项目依赖仍使用项目自己的 uv/Pixi/venv，Emacs 的 Pet 负责识别项目环境。Fortran 编译器和语言服务分开管理，fortls 的安装不会安装 GCC/GFortran。

TeX 当前使用 AUCTeX/RefTeX 和 latexmk，不会因为 Helix 的 texlab 配置自动安装或启用 Emacs Texlab。Tree-sitter grammars、ELPA 包、Jupyter/Jupytext、编译器和 TeX Live 不属于此语言服务清单；它们仍使用各自安装流程。

正在运行的 Emacs 可能保留旧 PATH 或旧 Eglot 进程。检查 `M-x my-development-environment-report`；必要时在保存工作后重启 Emacs，或关闭当前 Eglot 会话后重新连接。部署流程不会自动强制重启编辑器。

来源：[basedpyright 官方安装](https://docs.basedpyright.com/latest/installation/command-line-and-language-server/)、[fortls 官方安装](https://fortls.fortran-lang.org/quickstart.html)。
