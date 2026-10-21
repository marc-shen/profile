# Environment Modules

[项目入口](README.md) · [维护与编译环境](docs/maintenance.md)

当前规范见 [Software 目录与环境管理](docs/Software.txt)，使用说明见 [modulefiles/README.txt](modulefiles/README.txt)。

活动模块位于 `~/Software/share/modulefiles`。每个应用安装到 `apps/<name>/<version>` 后，可运行 `software-app module NAME VERSION` 生成模块，然后使用 `module load` / `module unload`。

原先绑定 Homebrew Cellar 具体路径的说明和模块保存在 `archieve/modulefiles-macos-2025`，不再加入全局 MODULEPATH。Fedora 科研环境模板保存在 `modulefiles/fedora`，依赖由该机器实际安装情况决定。
