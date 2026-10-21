# 三平台软件、安装途径与依赖清单

> **历史快照：以下内容记录迁移前状态。更新后的安装、清理和验证结果见 [本次迁移记录](environment-migration-2026-10-21.md)。**

> 现场核对日期：2026-10-21。本文是**现状与待讨论项**，不是已确定的新安装方案。
> 本轮仅移除 Yazi，未替换 GCC、未删除 Pixi、未重新编译 Emacs，也未改 SteamOS 只读状态。

## 1. 阅读范围与状态

本清单覆盖：profile 的部署目标、三台机器的 Software 用户安装、编译器与科研库、Zsh 插件、Emacs 包/语法库、Mac Homebrew 实装记录，以及已检查的 Pixi/uv 用户环境。
它**不是整台电脑所有操作系统软件的清单**：不枚举 Steam 游戏、系统完整 RPM/pacman 数据库、每个项目的 `.venv`/`node_modules` 或所有 GUI 应用。Mac 的 Homebrew 完整实装列表收在附录，以免把原有软件误当作本次新装的软件。

- **实装**：由程序版本、安装收据、包数据库或环境元数据确认；不代表每个功能都做了运行测试。
- **计划**：仓库安装脚本会安装，但不能据此宣称当前机器已装。
- **源码安装**：由构建选项、安装前缀或构建记录确认；依赖仍可能来自包管理器。
- **独立二进制/应用包**：直接放置的可执行文件或 App；无法核实原下载命令时明确注明。
- **未见**：本次检查范围内没有找到，不等同于证明整块磁盘绝不存在。
- **依赖**：正文列直接依赖/构建依赖，附录列实际包记录；公共系统库与 ABI 要求见对应元数据说明。

| 机器 | 系统与架构 | 实际软件来源 | 当前配置落点 |
| --- | --- | --- | --- |
| Mac | macOS 15.7.4，arm64 | Homebrew + Apple 工具链 + 独立 PKG/App/二进制 + 源码 + 既有 Pixi 环境 | 仓库 `/Users/marcshen/program/GitHub/profile`；实际 `~/.zshrc` 仍是本机文件 |
| Fedora | Fedora 44 KDE，x86_64 | Fedora RPM + Intel RPM + 源码 + uv/pixi 独立二进制 | `~/projects/profile`；共享 Zsh 已生效；`~/.emacs.d` 完整链接仓库 |
| Steam Deck | SteamOS 3.8.28，x86_64 | 官方二进制 + conda-forge 预编译包 + 源码 | `~/Software`；仍用 Deck 专用 Shell/启动器；共享配置尚未整套切换 |

**目录组织方式与安装来源应分开看待。** `apps/gcc/16.2.0` 这个路径本身不能说明它是源码编译、二进制解压还是 Pixi 安装。

## 2. Steam Deck 的 GCC 到底怎样安装

当前独立 GCC 环境是 **Pixi 下载并安装 conda-forge 的预编译 GCC/G++ 16.2.0**。没有在 Steam Deck 上从 GCC 源码构建编译器。

```text
~/Software/apps/gcc/16.2.0/
  pixi.toml                    两个直接依赖：gcc_linux-64、gxx_linux-64
  pixi.lock                    固定依赖解算结果
  .pixi/envs/default/           实际工具链、sysroot、头文件、运行库
  bin -> .pixi/envs/default/bin
  module-bin/{gcc,g++,cc,c++}   module 使用的直接启动包装
```

普通命令链：

```text
~/Software/bin/gcc
  → pixi run --manifest-path .../gcc/16.2.0/pixi.toml --frozen
  → x86_64-conda-linux-gnu-gcc
```

`module load gcc/16.2.0` 则把 `module-bin` 加入 PATH，并设置 CC/CXX/GCC_HOME；这个入口直接执行同一环境里的编译器。**安装方式仍然是 conda-forge 预编译包，不会因为使用 module 而变成源码安装。**

现场命令结果：

```text
gcc --version:   x86_64-conda-linux-gnu-gcc (conda-forge gcc 16.2.0-7) 16.2.0
gcc -dumpmachine: x86_64-conda-linux-gnu
sysroot: .../.pixi/envs/default/x86_64-conda-linux-gnu/sysroot
```

独立 GCC 环境有 19 个 Conda 包，见下表。这里只有 C/C++，**没有安装 GFortran 编译器包**。此外 Emacs、Modules 自己的构建环境中也有编译器依赖，不是全部共用此目录。

| 包 | 版本 | 分类 | 来源 |
| --- | --- | --- | --- |
| _openmp_mutex | 4.5 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| binutils_impl_linux-64 | 2.46.1 | 汇编/链接工具 | conda-forge / linux-64 或 noarch |
| binutils_linux-64 | 2.46.1 | 汇编/链接工具 | conda-forge / linux-64 或 noarch |
| gcc_impl_linux-64 | 16.2.0 | 编译器实现/平台包装 | conda-forge / linux-64 或 noarch |
| gcc_linux-64 | 16.2.0 | 编译器实现/平台包装 | conda-forge / linux-64 或 noarch |
| gxx_impl_linux-64 | 16.2.0 | 编译器实现/平台包装 | conda-forge / linux-64 或 noarch |
| gxx_linux-64 | 16.2.0 | 编译器实现/平台包装 | conda-forge / linux-64 或 noarch |
| kernel-headers_linux-64 | 4.18.0 | 内核用户态头文件 | conda-forge / linux-64 或 noarch |
| ld_impl_linux-64 | 2.46.1 | 汇编/链接工具 | conda-forge / linux-64 或 noarch |
| libgcc | 16.2.0 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| libgcc-devel_linux-64 | 16.2.0 | 编译器开发文件/头文件 | conda-forge / linux-64 或 noarch |
| libgomp | 16.2.0 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| libsanitizer | 16.2.0 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| libstdcxx | 16.2.0 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| libstdcxx-devel_linux-64 | 16.2.0 | 编译器开发文件/头文件 | conda-forge / linux-64 或 noarch |
| libzlib | 1.3.2 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| sysroot_linux-64 | 2.28 | 目标 C 运行库/系统根 | conda-forge / linux-64 或 noarch |
| tzdata | 2026c | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |
| zstd | 1.5.7 | 运行库或辅助数据 | conda-forge / linux-64 或 noarch |

### 三台机器的编译器不是同一种安装

| 系统 | 组件 | 实际版本 | 安装途径/位置 | 依赖或注意点 |
| --- | --- | --- | --- | --- |
| Mac | Apple Clang / cc、系统 gcc 命令 | 17.0.0 | Apple 工具链，`/usr/bin/gcc` 实际是 Clang | 不能把命令名 gcc 等同于 GNU GCC |
| Mac | GNU GCC / G++ / GFortran | 16.2.0 | Homebrew `gcc`，`/opt/homebrew` | GMP、MPFR、MPC、ISL 等；详见 Homebrew 收据附录 |
| Mac | GNU GCC 14 系列 | 14.4.0 | Homebrew `gcc@14`，`/opt/homebrew/opt/gcc@14` | 已装不代表其 bin 已在 PATH |
| Mac | 独立 GNU Fortran | 14.2.0 | PKG 收据 `com.gnu.gfortran`；`/usr/local/gfortran` | 现有 MPICH 与部分 HDF5 构建记录指向这一套；不是 Homebrew 管理 |
| Fedora | GCC / G++ / GFortran | 16.2.1-2.fc44 | RPM：gcc、gcc-c++、gcc-gfortran | 系统工具链，由 dnf/RPM 管理 |
| Fedora | Intel LLVM C/C++ / Fortran | 2026.1.1；还有旧版本 | Intel oneAPI RPM，`/opt/intel/oneapi` | 已验证 icx 所属包为 intel-oneapi-dpcpp-cpp-2026.1；不是手工移动到 apps 的软件 |
| Steam Deck | GNU GCC / G++ | 16.2.0 | Pixi + conda-forge，`apps/gcc/16.2.0` | 包含 binutils、sysroot 2.28、内核头文件 4.18；当前无 GFortran |

## 3. 基础工具、编辑器与管理器总表

下表的“计划”取自当前仓库，已反映本轮删除 Yazi 的变化。现有 Mac 的安装来源不应直接由 Brewfile 推断。完整逐项安装目标另见附录 9.11。

| 分类 | 项目 | Mac 实装 | Fedora 实装 | Deck 实装 | 仓库安装计划 | 依赖/说明 |
| --- | --- | --- | --- | --- | --- | --- |
| Shell | Zsh | 系统 5.9 | 5.9-21.fc44 | 5.9.2，Pixi | Mac Brewfile 仍计划另装 brew zsh；应讨论是否保留 | 交互 Shell；补全与插件见第 6 节 |
| 版本控制 | Git | Apple Git 2.50.1 | 2.56.0-1.fc44 | 2.56.0，Pixi | 三平台列入部署；Mac 计划 Brew Git 与现状不同 | TLS/SSH、证书、libcurl 等平台依赖 |
| 终端工具 | fd | 10.5.0 | 10.4.2-4.fc44 | 10.5.0，Pixi | 三平台 | 独立命令；可供 fzf/Emacs 搜索 |
| 终端工具 | ripgrep / rg | 15.2.0 | 15.2.0-1.fc44 | 15.2.0，Pixi | 三平台 | 独立命令；Emacs 搜索使用 |
| 终端工具 | fzf | 0.74.4 | 0.74.4-1.fc44 | 0.74.5（Conda 版本标签），Pixi | 三平台 | fzf-tab、Shell 搜索；fd 是本配置的文件枚举工具 |
| 终端工具 | zoxide | 0.10.0 | 0.9.8-2.fc44 | 0.10.0，Pixi | 三平台 | Shell 导航与本地数据库 |
| 提示符 | Starship | 1.26.0 | 1.24.2-1.fc44 | 1.27.0，Pixi | 三平台 | 共享 starship.toml；不是 Pixi 管理器本身的依赖 |
| 终端工具 | jq | 1.8.2 | 1.8.1-3.fc44 | 1.8.2，Pixi | 三平台 | JSON 命令行工具 |
| 终端工具 | bat | 0.26.1 | 0.26.1-4.fc44 | 未见 | 仅 Mac/Fedora 清单 | 代码预览；不是启动 Shell 的硬依赖 |
| 编辑器 | Neovim | 0.12.5_1 | 未见该 RPM | 未见 | Mac/Fedora 仍列为安装目标 | Lua/LuaJIT、libuv、Tree-sitter 等；是否保留可讨论 |
| 编辑器 | Emacs | 31.1，Homebrew Cask emacs-app | 31.1，源码编译 | 31.1，源码编译 | Mac Cask / Fedora dnf / Deck 源码 | 实际 Fedora 与新部署 dnf 计划不同；详见第 5 节 |
| 终端应用 | WezTerm | 20240922-151228-2b76c63b，已有 App；原安装器未核实 | 本次未核实 | 本次未核实 | Brewfile 仅为新 Mac 计划安装 | 共享 wezterm.lua；Linux 未配置自动安装 |
| Python 管理 | uv / uvx | 0.11.17，`~/.local/bin` 独立二进制 | 0.12.7，apps/uv，非 RPM | 0.13.1，官方二进制 | Mac 新部署用 brew；Fedora 新部署优先 dnf；Deck 下载 | uv 本体无需由 Pixi 提供；项目/工具环境独立 |
| 环境管理 | Pixi | 0.67.0，`~/.pixi/bin` 独立二进制 | 0.78.0，apps/pixi，非 RPM | 0.82.0，官方二进制 | 目前三平台都仍列为基础工具 | 目前 Deck 大部分命令/构建环境依赖它；待讨论是否降低为可选后端 |
| 环境切换 | Environment Modules | 5.7.0，Homebrew | 5.6.2-1.fc44 | 5.7.0，源码编译 | 三平台 | Tcl；Deck Tcl/编译依赖由 Pixi 提供 |
| 构建 | CMake | 4.0.0，`/Applications/CMake.app`，独立 App | 4.3.0-1.fc44 | Emacs 环境内 4.4.4 | Mac/Fedora 基础构建清单；Deck 应用私有依赖 | 生成构建系统；Mac 当前不由 Homebrew 管理 |
| 构建 | Make | 系统 GNU Make 3.81 | 4.4.1-12.fc44 | 应用依赖环境内 4.4.1 | Mac 计划 brew make；Fedora dnf；Deck Pixi | 构建工具，不应该自动决定用户默认编译器 |
| 构建 | Autoconf / Automake / Libtool | 2.73 / 1.19 / 2.6.2 | 2.72-10.fc44 / 1.18.1-4.fc44 / 2.5.4-10.fc44 | Emacs 应用依赖环境 | 三平台构建相关 | Shell、M4、Perl 等基础工具；平台 bin 名可能不同 |
| 构建 | pkg-config / pkgconf | 3.0.7 | 2.5.1-1.fc44 | Emacs 环境内 pkg-config 0.29.2 | 三平台 | 定位编译/链接依赖；不应全局塞入所有库的路径 |
| 语言运行时 | Python | 系统 3.9.6；brew 3.14.8；另有 Pixi Python | 3.14.8-1.fc44 | Emacs 构建环境 3.13.16；另有系统 Python | Mac/Fedora 的 Python 安装与 uv 管理 Python 并存 | 不能把某个审计进程的 PATH 当作所有终端默认解释器 |
| 字体 | MesloLGS NF / Nerd Font | 已有字体/Cask 记录，见附录 | 本次未核实完整字体目录 | MesloLGS-NF-Regular.ttf 手动下载并链接 | 当前新部署脚本未覆盖全部字体 | 界面外观；不应成为 uv/Pixi 的依赖 |
| 网络 | Tailscale / deck-tailscale | 本次未清点 Mac 安装途径 | 本次未清点 Fedora 安装途径 | Tailscale 1.104.1，原 deck-tailscale 安装，/opt/tailscale | profile 尚未自动安装 | 系统服务/SteamOS 更新保留是另一层；不纳入 Pixi |
| 已移除 | Yazi | 已卸载 26.9.1；旧配置归档 | 未见安装 | 未见安装 | 已从 Brewfile、Fedora 安装逻辑、共享及 Mac 实际 Shell 移除 | 不再安装、不再定义 y()；未连带卸载共享依赖 |

## 4. 软件目录与科研环境

### 4.1 Steam Deck：apps 下的全部应用

这 13 个目录中，只有 Emacs 和 Environment Modules 是我们从源码编译的；uv/pixi 是官方可执行文件；其余列出的程序来自应用内的 Conda 包。`gcc` 目录里并不存在一次 GCC 源码构建。

| 应用 | 版本目录 | 实际安装方式 | manifest 直接依赖 | 实际 Conda 包数 |
| --- | --- | --- | --- | --- |
| emacs | 31.1 | 源码编译；构建依赖经 Pixi 安装 | autoconf ==2.72、automake ==1.19、cmake ==4.4.4、dbus ==1.16.2、expat ==2.8.5、gcc_linux-64 ==16.2.0、giflib ==6.1.3、git ==2.56.0、glib ==2.90.0、gnutls ==3.8.13、gtk3 ==3.24.52、gxx_linux-64 ==16.2.0、libjpeg-turbo ==3.2.0、libpng ==1.6.59、librsvg ==2.62.4、libtiff ==4.7.2、libtool ==2.5.4、libtree-sitter ==0.27.1、libvterm ==0.3.3、libwebp ==1.6.0、libxml2 ==2.15.4、libxml2-devel ==2.15.4、make ==4.4.1、ncurses ==6.6、pkg-config ==0.29.2、poppler ==26.09.0、python ==3.13.16、sqlite ==3.54.1、texinfo ==7.2、zlib ==1.3.2 | 157 |
| fd | 10.5.0 | Pixi → conda-forge 预编译包 | fd-find ==10.5.0 | 4 |
| fzf | 0.74.5 | Pixi → conda-forge 预编译包 | fzf ==0.74.5 | 1 |
| gcc | 16.2.0 | Pixi → conda-forge 预编译包 | gcc_linux-64 ==16.2.0、gxx_linux-64 ==16.2.0 | 19 |
| git | 2.56.0 | Pixi → conda-forge 预编译包 | git ==2.56.0 | 26 |
| jq | 1.8.2 | Pixi → conda-forge 预编译包 | jq ==1.8.2 | 5 |
| modules | 5.7.0 | 源码编译；构建依赖经 Pixi 安装 | tk ==8.6.13、gcc_linux-64 ==16.2.0、make ==4.4.1 | 19 |
| pixi | 0.82.0 | 官方独立二进制 | 无需 Pixi 环境；依赖宿主系统 ABI | 0 |
| ripgrep | 15.2.0 | Pixi → conda-forge 预编译包 | ripgrep ==15.2.0 | 4 |
| starship | 1.27.0 | Pixi → conda-forge 预编译包 | starship ==1.27.0 | 4 |
| uv | 0.13.1 | 官方独立二进制 | 无需 Pixi 环境；依赖宿主系统 ABI | 0 |
| zoxide | 0.10.0 | Pixi → conda-forge 预编译包 | zoxide ==0.10.0 | 4 |
| zsh | 5.9.2 | Pixi → conda-forge 预编译包 | zsh ==5.9.2 | 12 |

### 4.2 Fedora：用户源码安装与系统科研库

| 项目 | 版本/变体 | 安装途径与位置 | 构建/运行依赖 | 管理边界 |
| --- | --- | --- | --- | --- |
| Emacs | 31.1 | 源码；`apps/emacs/31.1` | GTK3/X11、Tree-sitter、native compilation 等；依赖由系统提供 | 旧编译前缀仍是 ~/software/emacs/31.1，靠兼容链接保留 |
| HDF5 | 2.2.0-intel | 源码；`apps/hdf5/2.2.0-intel` | 构建记录：mpiicx 2026.1.0、mpiifx；运行模块现在加载 Intel 2026.1.1 + MPI 2021.18；zlib | 源码构建版本与当前加载的编译器补丁版并非同一字段 |
| FFTW | 3.3.11-gcc | 源码；`apps/fftw/3.3.11-gcc` | GNU 编译器、线程/OpenMP 运行库 | 按 module 加载，不应塞进全局 LD_LIBRARY_PATH |
| FFTW | 3.3.11-intel | 源码；`apps/fftw/3.3.11-intel` | Intel LLVM/OpenMP；当前模块依赖 2026.1.1 | 与 GNU 版本并存 |
| OpenMPI | 5.0.9-4.fc44 | Fedora RPM；/usr | 系统编译器及 RPM 依赖 | 保持 dnf 所有权，不搬进 Software |
| MPICH | 4.2.2-7.fc44 | Fedora RPM；/usr | 系统编译器及 RPM 依赖 | 通过发行版 modulefile 选择 |
| HDF5 | 1.14.6，串行/OpenMPI/MPICH | Fedora RPM；/usr | 对应 MPI 与 Fortran 模块 | modulefile 名字中的版本需和 RPM 实装区分维护 |
| Intel oneAPI | 多个组件与版本，见附录 | Intel RPM；/opt/intel/oneapi | 组件之间由原厂 modulefile/RPM 依赖联系 | 用户 share/modulefiles/intel 只是链接，不是自行复制安装 |
| uv / pixi | 0.12.7 / 0.78.0 | 独立二进制；apps/uv、apps/pixi | 不依赖系统 GCC 来运行 | 现有 uv Python/工具数据仍在 ~/.local/share/uv |
| EMPi / EMPi-Fortran 环境 | MPI 变体 | 项目 .venv 与用户 modulefile | MPI、HDF5、FFTW、Python/uv 等 | 属于项目环境，本轮未扫描其所有 Python 间接依赖 |

### 4.3 Mac：Software 与独立工具链

| 项目 | 版本/位置 | 安装途径 | 依赖/证据 |
| --- | --- | --- | --- |
| HDF5 串行 | 1.14.6；Software/hdf5-1.14.6 | 源码编译 | libhdf5.settings：Apple Clang 17 + 独立 GFortran 14.2；Fortran=yes；parallel=no |
| HDF5 并行 | 1.14.6；Software/hdf5-1.14.6-openmpi | 源码编译 | 构建记录指向 Software/openmpi-5.0.7/bin/mpicc、mpifort；parallel=yes |
| OpenMPI | 5.0.7；Software/openmpi-5.0.7 | 独立前缀/源码安装 | ompi_info 已返回 5.0.7；与系统/Homebrew MPI 分开 |
| MPICH | 4.3.0；Software/mpich-4.3.0 | 源码编译 | mpichversion：Apple Clang + /usr/local/gfortran/bin/gfortran；ch4:ofi |
| GFortran | 14.2.0；/usr/local/gfortran | 独立 PKG 安装 | pkgutil 收据 com.gnu.gfortran；不要按 Homebrew 软件卸载/升级 |
| CMake | 4.0.0；/Applications/CMake.app | 独立 App | /usr/local/bin/{cmake,ctest,cpack} 是指向 App 的链接 |
| oh-my-rime-cli | Software/oh-my-rime-cli | 独立 darwin-arm64 二进制；版本/原下载命令未核实 | 只确认文件存在，不执行未知版本查询逻辑 |
| pyomp | Software/pyomp | Pixi + PyPI 项目环境 | 直接项含 Python、NumPy、Astropy、Pandas、Matplotlib、SciPy、Jupyter；MPI feature 含 OpenMPI/mpi4py/HDF5/h5py；PyPI pyomp、numba |
| unrpa | Software/unrpa | Pixi Python + PyPI unrpa | manifest Python >=3.14.2,<3.15；unrpa >=2.3.0,<3；范围不是已安装版本 |
| 旧全局 Pixi default | ~/.pixi/envs/default | 既有全局 Pixi 环境 | manifest 包含 Python、Jupyter、NumPy、Pandas、Matplotlib、IPython、SciPy、Astropy、ipykernel、jupytext、ruff、pylint |
| 旧全局 Pixi openpyxl | ~/.pixi/envs/openpyxl | 既有全局 Pixi 环境 | 与 profile/Software 的新布局并存；本轮未移动 |
| markitdown 残留目录 | ~/.pixi/envs/markitdown | 只有目录，未查到 Conda 安装记录 | 不能按“目录存在”宣称软件已完整安装 |

Mac 的两个 Software 项目和全局 Pixi 环境的实际 Conda 包明细收在附录。PyPI 顶层依赖按 manifest 列出；未在这轮把所有项目的 pip 依赖树都导出，因此不把版本约束当成精确实装版本。

## 5. Emacs、后台服务与原生依赖

| 部分 | Mac | Fedora | Steam Deck | 依赖/管理方式 |
| --- | --- | --- | --- | --- |
| Emacs 程序 | Homebrew Cask 31.1 | 源码 31.1，GTK3/X11，native compilation=aot | 源码 31.1，GTK3/X11；无 Lisp native compilation | 安装来源独立于 Lisp 配置 |
| Lisp 配置 | 仓库仍通过旧的逐项链接生效；尚未整套部署新链接 | ~/.emacs.d 完整指向 ~/projects/profile/emacs.d | ~/.emacs.d 完整指向 Software/src/profile/emacs.d | 不要把现状和新 deploy.py 的“完整目录链接”目标混为一谈 |
| 后台 | launchd org.gnu.emacs.daemon | systemd --user emacs.service | systemd --user emacs.service；一个 X11 daemon | 启动器与服务定义不同，不应全部放到通用 Zsh 中 |
| Steam 启动器 | 不适用 | 不适用 | emacs-steam 只是客户端启动器 | 等待客户端窗口关闭并设置 Steam 窗口属性，不启动第二个后台 |
| vterm | 本机原生模块 | 本机原生模块 | 在 Emacs 私有依赖环境编译 | CMake、C 编译器、libvterm；.so/.dylib 不能跨平台同步 |
| PDF Tools / epdfinfo | 本机原生 helper | 本机原生 helper | Pixi 构建依赖；跳过系统依赖安装 | Autotools、编译器、Poppler/GLib、图像库等 |
| Tree-sitter | 10 个已存在 grammar 动态库 | 9 个 | 9 个 | 各语言 grammar 本地编译；版本/ABI 不能仅从文件名确认 |
| ELPA/VC 包 | 76 个包目录 | 70 个包目录 | 70 个包目录 | 包含直接配置包和间接依赖；版本明细见附录，不等于仅有 76/70 个手选功能 |

共享 `init-package.el` 指定 GNU ELPA、NonGNU ELPA、MELPA，并包含 VC 安装来源 embr、markdown-ts-appear、tramp-rpc。个别历史包的原始来源不能仅凭现有目录反推；附录以实际包描述文件版本为准，Git 包额外标提交。

## 6. Zsh 插件与配置

| 项目 | Mac 实装 | Fedora 实装 | Deck 实装 | 来源 | 依赖 |
| --- | --- | --- | --- | --- | --- |
| fzf-tab | Git，24105b15714b | Git，24105b15714b | Git，24105b15714b | https://github.com/Aloxaf/fzf-tab.git | Zsh；fzf-tab 另依赖 fzf/compinit |
| zsh-autosuggestions | Homebrew 0.7.1 | Git，85919cd1ffa7 | Git，85919cd1ffa7 | https://github.com/zsh-users/zsh-autosuggestions.git | Zsh |
| zsh-completions | 未见该插件独立安装 | Git，989b23277ab3 | Git，989b23277ab3 | https://github.com/zsh-users/zsh-completions.git | Zsh |
| zsh-syntax-highlighting | Homebrew 0.8.0 | Git，e6683f20e5c3 | Git，e6683f20e5c3 | https://github.com/zsh-users/zsh-syntax-highlighting.git | Zsh |
| fast-syntax-highlighting | Homebrew 1.56，Mac 当前优先使用 | 未见 | 未见 | Homebrew 公式 | 与 standard syntax-highlighting 二选一 |

Fedora 自定义 `_tailscale` 补全已移到 `Software/share/zsh/completions`，不再混在 zsh-completions 的 Git 工作树。插件无需由 Pixi 管理。

## 7. 当前方案的问题与下一轮待决定项

| 事项 | 现在的具体情况 | 待讨论的调整方向（尚未实施） |
| --- | --- | --- |
| 安装后端与目录耦合 | `software-app create` 无条件生成 Pixi workspace | 目录/版本管理独立；安装来源可记录为 system、archive、source、pixi、uv |
| Pixi 覆盖范围偏大 | Deck 的 fd、rg、fzf、zoxide、Starship、jq、Git、Zsh 都各有 Pixi 环境 | 逐个评估官方独立二进制或源码安装；不能在未验证 ABI/更新流程前一键删 Pixi |
| 通用工具检查强制 Pixi | `deploy.py check` 对所有平台把 pixi 当作必需命令 | 将基础 Shell、开发工具、科研环境、Deck 构建分别设为可选组 |
| GCC 名义不清 | 路径叫 gcc，但当前由 conda-forge 供给；全局包装再调用 Pixi | 明确“预编译 GCC”或“源码构建 GCC”；记录 bootstrap 编译器、目标、sysroot、语言集合 |
| 工具链边界 | 独立 gcc 环境与 Emacs/Modules 构建环境同时含编译器 | 讨论保留应用隔离还是共享工具链；先核实兼容性和运行库依赖，再做去重 |
| 科研库不是普通独立命令 | HDF5/FFTW 与 MPI、Fortran、OpenMP、编译器 ABI 相关 | 使用 module 组合环境，按版本/变体保存；不要对全局 LD_LIBRARY_PATH 做统一注入 |
| Mac 新装计划不等于现状 | Git/Zsh/Make/CMake 等计划用 Brew，当前有系统或独立 App；uv/pixi 当前是独立二进制 | 按已有软件来源选择接管策略；不重复安装另一套后宣称统一完成 |
| Fedora 新装计划不等于现状 | 新脚本用 dnf Emacs，但当前是源码构建；uv 计划 RPM，当前独立下载 | 明确哪种方式作为新机默认，哪些源码配方需保留 |
| 编译器未在通用清单完整表达 | Mac Brewfile 没有 GCC；Fedora 基础列表没列 gcc-gfortran；Deck 独立 GCC 不含 Fortran | 根据实际开发需求列 C/C++/Fortran 工具链，而不是从当前偶然 PATH 推断 |
| 平台包名 | Fedora 当前安装 zlib-ng-compat-devel，清单写 zlib-devel | 判断提供关系和目标发行版，不把包名视为永久跨版本稳定接口 |
| 安装器范围 | `bootstrap install` 一次安装较宽的基础/构建集合；参数只在后续 link 阶段筛选 | 后续拆分 install profiles；本轮未重写安装器 |
| Yazi | 已卸载和移除配置 | 已完成；不作为基础环境组成部分 |
| Mac 老环境 | Software 旧布局、~/.pixi 全局环境、独立 GFortran 和 App 并存 | 先决定归属再迁移；保留绝对路径兼容，不粗暴移动已有安装 |
| 应用版本与依赖版本 | apps 名称、包版本、源码提交、编译器版本、ABI 不是同一概念 | 清单应分别记录，而不是都压在一个目录名里 |

建议下一轮先决定**哪些软件是基础必需、各软件采用什么来源**，再改通用管理脚本。本文不给尚未批准的方案默认打勾。

## 8. 本轮 Yazi 删除记录

- Mac：卸载 Homebrew `yazi 26.9.1`，关闭自动 autoremove，保留可能被其他软件使用的依赖。
- Mac 实际 `~/.zshrc`：删除 Yazi 的 `y()` 集成，其他内容保留。
- 旧 Shell 备份和 Yazi 个性化配置已移入 `~/Software/backups/remove-yazi-20261021-205825/`；不再占用活动 `~/.config/yazi`。
- profile：删除 Brewfile 项、Fedora 安装尝试、共享 Shell 函数和相关安装说明；同步 Fedora 的活动仓库；Deck 仓库旧 zshrc 中未启用的 Yazi 段也移除。
- Fedora / Steam Deck：未发现 Yazi 可执行文件或对应系统包，不执行无目标卸载。
- 本轮没有删除 Pixi，也没有切换 GCC、MPI、HDF5 或 Emacs 后台。

## 9. 安装记录附录

以下是截至核对时间的包记录。传递依赖并不等于用户需要手动安装这些包，也不等于基础环境必须对外暴露这些命令。
<details>
<summary>9.1 Mac Homebrew Formula：全部 147 条实装收据（已排除卸载的 Yazi）</summary>

分类/用途先用安装收据角色表示：手选、依赖、未标注。`runtime_dependencies` 是收据记录，可能是完整运行依赖闭包而非最小直接依赖；并不包含所有源码构建时依赖。包版本为当前 Cellar 目录版本。

| Formula | 版本 | 收据角色 | 途径 | 收据运行依赖 |
| --- | --- | --- | --- | --- |
| aom | 3.15.1 | 收据未标注 | Homebrew bottle | libvmaf |
| aspell | 0.60.8.2 | 依赖 | Homebrew bottle | 收据未列 |
| autoconf | 2.73 | 手选 | Homebrew bottle | m4 |
| automake | 1.19 | 手选 | Homebrew bottle | m4, autoconf |
| bat | 0.26.1 | 手选 | Homebrew bottle | ca-certificates, openssl@3, libssh2, libgit2, oniguruma |
| bat-extras | 2024.08.24 | 手选 | Homebrew bottle | 收据未列 |
| brotli | 1.2.0 | 依赖 | Homebrew bottle | 收据未列 |
| btop | 1.4.7 | 手选 | Homebrew bottle | 收据未列 |
| ca-certificates | 2026-09-25 | 收据未标注 | Homebrew bottle | 收据未列 |
| cairo | 1.18.6 | 收据未标注 | Homebrew bottle | libpng, freetype, json-c, libunistring, gettext, fontconfig, pcre2, glib, xorgproto, libxau, libxdmcp, libxcb, libx11, libxext, libxrender, lzo, pixman |
| cjson | 1.7.19 | 依赖 | Homebrew bottle | 收据未列 |
| dav1d | 1.5.4 | 收据未标注 | Homebrew bottle | 收据未列 |
| dotnet@9 | 9.0.121 | 收据未标注 | Homebrew bottle | brotli, icu4c@78, ca-certificates, openssl@3 |
| doxx | 0.1.4 | 手选 | Homebrew bottle | 收据未列 |
| enchant | 2.8.21 | 收据未标注 | Homebrew bottle | aspell, pcre2, json-c, libunistring, gettext, glib |
| fd | 10.5.0 | 手选 | Homebrew bottle | 收据未列 |
| ffmpeg | 9.0.2 | 手选 | Homebrew bottle | dav1d, mpg123, lame, libvmaf, libvpx, ca-certificates, openssl@3, opus, sdl3, sdl2-compat, svt-av1, x264, x265, xz |
| fontconfig | 2.18.3 | 收据未标注 | Homebrew bottle | libpng, freetype, json-c, libunistring, gettext |
| fpm | 0.13.0 | 手选 | Homebrew bottle | gmp, isl, mpfr, libmpc, lz4, xz, zstd, gcc |
| freetype | 2.14.3 | 依赖 | Homebrew bottle | libpng |
| fzf | 0.74.4 | 手选 | Homebrew bottle | 收据未列 |
| gcc | 16.2.0 | 手选 | Homebrew bottle | gmp, isl, mpfr, libmpc, lz4, xz, zstd |
| gcc@14 | 14.4.0 | 手选 | Homebrew bottle | gmp, isl, mpfr, libmpc, lz4, xz, zstd |
| gettext | 1.0 | 依赖 | Homebrew bottle | libunistring |
| gh | 2.102.0 | 手选 | Homebrew bottle | 收据未列 |
| giflib | 6.1.3 | 依赖 | Homebrew bottle | 收据未列 |
| git-filter-repo | 2.47.0 | 手选 | Homebrew bottle | 收据未列 |
| glib | 2.90.1 | 收据未标注 | Homebrew bottle | pcre2, json-c, libunistring, gettext |
| gmp | 6.3.0 | 依赖 | Homebrew bottle | 收据未列 |
| gnupg | 2.5.24 | 收据未标注 | Homebrew bottle | ca-certificates, gmp, libunistring, json-c, gettext, libidn2, libtasn1, nettle, p11-kit, gnutls, libgpg-error, libassuan, libgcrypt, libksba, libusb, npth, pinentry, readline |
| gnutls | 3.8.13_2 | 收据未标注 | Homebrew bottle | ca-certificates, gmp, libunistring, gettext, libidn2, libtasn1, nettle, p11-kit |
| gpgme | 2.2.0 | 收据未标注 | Homebrew bottle | ca-certificates, gmp, libunistring, json-c, gettext, libidn2, libtasn1, nettle, p11-kit, gnutls, libgpg-error, libassuan, libgcrypt, libksba, libusb, npth, pinentry, readline, gnupg |
| gpgmepp | 2.2.0 | 收据未标注 | Homebrew bottle | ca-certificates, gmp, libunistring, json-c, gettext, libidn2, libtasn1, nettle, p11-kit, gnutls, libgpg-error, libassuan, libgcrypt, libksba, libusb, npth, pinentry, readline, gnupg, gpgme |
| graphite2 | 1.3.15 | 收据未标注 | Homebrew bottle | 收据未列 |
| harfbuzz | 14.6.0 | 收据未标注 | Homebrew bottle | libpng, freetype, json-c, libunistring, gettext, fontconfig, pcre2, glib, xorgproto, libxau, libxdmcp, libxcb, libx11, libxext, libxrender, lzo, pixman, cairo, graphite2, icu4c@78 |
| helix | 25.07.1 | 手选 | Homebrew bottle | 收据未列 |
| htop | 3.5.3 | 手选 | Homebrew bottle | ncurses |
| icu4c@78 | 78.3 | 依赖 | Homebrew bottle | 收据未列 |
| imagemagick | 7.1.2-32 | 手选 | Homebrew bottle | libpng, freetype, jpeg-turbo, libvmaf, aom, libde265, giflib, webp, xz, lz4, zstd, libtiff, x265, libheif, m4, libtool, little-cms2 |
| ipatool | 2.6.0 | 手选 | Homebrew bottle | 收据未列 |
| isl | 0.28 | 收据未标注 | Homebrew bottle | gmp |
| jemalloc | 5.4.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| john-jumbo | 1.9.0_1 | 手选 | Homebrew bottle | gmp, ca-certificates, openssl@3 |
| jpeg-turbo | 3.2.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| jq | 1.8.2 | 手选 | Homebrew bottle | oniguruma |
| json-c | 0.19 | 收据未标注 | Homebrew bottle | 收据未列 |
| lame | 4.0 | 收据未标注 | Homebrew bottle | mpg123 |
| libassuan | 3.0.2 | 依赖 | Homebrew bottle | libunistring, gettext, libgpg-error |
| libde265 | 1.1.3 | 收据未标注 | Homebrew bottle | 收据未列 |
| libevent | 2.1.13 | 收据未标注 | Homebrew bottle | ca-certificates, openssl@3 |
| libgcrypt | 1.12.4 | 收据未标注 | Homebrew bottle | json-c, libunistring, gettext, libgpg-error |
| libgit2 | 1.9.7 | 收据未标注 | Homebrew bottle | ca-certificates, openssl@3, libssh2, llhttp |
| libgpg-error | 1.61 | 收据未标注 | Homebrew bottle | libunistring, gettext |
| libheif | 1.23.6 | 收据未标注 | Homebrew bottle | libvmaf, aom, jpeg-turbo, libde265, libpng, giflib, webp, xz, lz4, zstd, libtiff, x265 |
| libidn2 | 2.3.8 | 依赖 | Homebrew bottle | libunistring, gettext |
| libksba | 1.8.1 | 收据未标注 | Homebrew bottle | json-c, libunistring, gettext, libgpg-error |
| libmpc | 1.4.1 | 收据未标注 | Homebrew bottle | gmp, mpfr |
| libpng | 1.6.59 | 收据未标注 | Homebrew bottle | 收据未列 |
| libpsl | 0.23.3 | 收据未标注 | Homebrew bottle | 收据未列 |
| libssh2 | 1.11.1_6 | 收据未标注 | Homebrew bottle | ca-certificates, openssl@3 |
| libtasn1 | 4.21.0 | 依赖 | Homebrew bottle | 收据未列 |
| libtiff | 4.7.2 | 收据未标注 | Homebrew bottle | jpeg-turbo, xz, lz4, zstd |
| libtommath | 1.3.0 | 依赖 | Homebrew bottle | 收据未列 |
| libtool | 2.6.2 | 收据未标注 | Homebrew bottle | m4 |
| libunistring | 1.4.2 | 依赖 | Homebrew bottle | 收据未列 |
| libusb | 1.0.30 | 收据未标注 | Homebrew bottle | 收据未列 |
| libuv | 1.53.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| libvmaf | 3.2.1 | 收据未标注 | Homebrew bottle | 收据未列 |
| libvpx | 1.17.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| libx11 | 1.8.13 | 依赖 | Homebrew bottle | xorgproto, libxau, libxdmcp, libxcb |
| libxau | 1.0.12 | 依赖 | Homebrew bottle | xorgproto |
| libxcb | 1.17.0 | 依赖 | Homebrew bottle | xorgproto, libxau, libxdmcp |
| libxdmcp | 1.1.5 | 依赖 | Homebrew bottle | xorgproto |
| libxext | 1.3.7 | 依赖 | Homebrew bottle | xorgproto, libxau, libxdmcp, libxcb, libx11 |
| libxrender | 0.9.12 | 依赖 | Homebrew bottle | xorgproto, libxau, libxdmcp, libxcb, libx11 |
| libyaml | 0.2.5 | 依赖 | Homebrew bottle | 收据未列 |
| little-cms2 | 2.19.1 | 收据未标注 | Homebrew bottle | jpeg-turbo, giflib, libpng, webp, xz, lz4, zstd, libtiff |
| llhttp | 9.4.3 | 收据未标注 | Homebrew bottle | 收据未列 |
| lpeg | 1.1.0_2 | 依赖 | Homebrew bottle | 收据未列 |
| lua | 5.5.1 | 收据未标注 | Homebrew bottle | 收据未列 |
| luajit | 2.1.1788856981 | 收据未标注 | Homebrew bottle | 收据未列 |
| luv | 1.53.0-0 | 收据未标注 | Homebrew bottle | libuv |
| lz4 | 1.10.0 | 手选 | Homebrew bottle | 收据未列 |
| lzo | 2.10 | 依赖 | Homebrew bottle | 收据未列 |
| m4 | 1.4.21 | 依赖 | Homebrew bottle | 收据未列 |
| macism | 3.1.1 | 手选 | Homebrew；收据未标为 bottle | 收据未列 |
| marksman | 2026-02-08 | 手选 | Homebrew bottle | brotli, icu4c@78, ca-certificates, openssl@3, dotnet@9 |
| modules | 5.7.0 | 手选 | Homebrew bottle | libtommath, ca-certificates, openssl@3, tcl-tk |
| mpdecimal | 4.0.1 | 依赖 | Homebrew bottle | 收据未列 |
| mpfr | 4.2.2 | 依赖 | Homebrew bottle | gmp |
| mpg123 | 1.33.7 | 收据未标注 | Homebrew bottle | 收据未列 |
| nb | 7.25.4 | 手选 | Homebrew；收据未标为 bottle | ca-certificates, openssl@3, libssh2, llhttp, libgit2, oniguruma, bat, ncurses, readline, libunistring, gettext, bash, bash-completion@2, pcre2, git, liblinear, lua, mpdecimal, sqlite, xz, lz4, zstd, python@3.14, nmap, gmp, pandoc, pygments, ripgrep, tig, bdw-gc, w3m |
| ncurses | 6.6 | 依赖 | Homebrew bottle | 收据未列 |
| neovim | 0.12.5_1 | 手选 | Homebrew bottle | libuv, lpeg, luajit, luv, tree-sitter, unibilium, utf8proc, json-c, libunistring, gettext |
| nettle | 4.0 | 收据未标注 | Homebrew bottle | gmp |
| npth | 1.8 | 依赖 | Homebrew bottle | 收据未列 |
| nspr | 4.40 | 收据未标注 | Homebrew bottle | 收据未列 |
| nss | 3.131 | 收据未标注 | Homebrew bottle | nspr |
| oniguruma | 6.9.10 | 依赖 | Homebrew bottle | 收据未列 |
| opencode | 2.0.20 | 手选 | Homebrew bottle | pcre2, ripgrep |
| openjpeg | 2.5.4_1 | 收据未标注 | Homebrew bottle | libpng, jpeg-turbo, giflib, webp, xz, lz4, zstd, libtiff, little-cms2 |
| openssl@3 | 3.6.5 | 收据未标注 | Homebrew bottle | ca-certificates |
| openssl@4 | 4.0.3 | 收据未标注 | Homebrew bottle | ca-certificates |
| opus | 1.6.1 | 依赖 | Homebrew bottle | 收据未列 |
| p11-kit | 0.26.5 | 收据未标注 | Homebrew bottle | ca-certificates, libtasn1 |
| p7zip | 17.06 | 手选 | Homebrew bottle | 收据未列 |
| pcre2 | 10.49 | 收据未标注 | Homebrew bottle | 收据未列 |
| pinentry | 1.3.3 | 收据未标注 | Homebrew bottle | libunistring, gettext, libgpg-error, libassuan |
| pixman | 0.46.4 | 依赖 | Homebrew bottle | 收据未列 |
| pkgconf | 3.0.7 | 手选 | Homebrew bottle | 收据未列 |
| poppler | 26.10.0 | 手选 | Homebrew bottle | brotli, libpng, freetype, json-c, libunistring, gettext, fontconfig, pcre2, glib, xorgproto, libxau, libxdmcp, libxcb, libx11, libxext, libxrender, lzo, pixman, cairo, ca-certificates, gmp, libidn2, libtasn1, nettle, p11-kit, gnutls, libgpg-error, libassuan, libgcrypt, libksba, libusb, npth, pinentry, readline, gnupg, gpgme, gpgmepp, graphite2, icu4c@78, harfbuzz, jpeg-turbo, giflib, webp, xz, lz4, zstd, libtiff, little-cms2, nspr, nss, openjpeg |
| python@3.14 | 3.14.8 | 收据未标注 | Homebrew bottle | ca-certificates, mpdecimal, openssl@3, readline, sqlite, xz, lz4, zstd |
| readline | 8.3.6 | 收据未标注 | Homebrew bottle | 收据未列 |
| resvg | 0.48.1 | 手选 | Homebrew bottle | 收据未列 |
| ripgrep | 15.2.0 | 手选 | Homebrew bottle | pcre2 |
| ruby | 4.0.7 | 收据未标注 | Homebrew bottle | libyaml, ca-certificates, openssl@3 |
| sdl2-compat | 2.32.74 | 收据未标注 | Homebrew bottle | sdl3 |
| sdl3 | 3.4.18 | 收据未标注 | Homebrew bottle | 收据未列 |
| sevenzip | 26.04 | 手选 | Homebrew bottle | 收据未列 |
| sqlite | 3.53.4 | 收据未标注 | Homebrew bottle | readline |
| starship | 1.26.0 | 手选 | Homebrew bottle | 收据未列 |
| svt-av1 | 4.2.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| tcl-tk | 9.1.0 | 收据未标注 | Homebrew bottle | libtommath |
| telnet | 308 | 手选 | Homebrew bottle | 收据未列 |
| terminal-notifier | 3.1.0 | 手选 | Homebrew bottle | 收据未列 |
| texlab | 5.26.0 | 手选 | Homebrew bottle | 收据未列 |
| tmux | 3.7c | 手选 | Homebrew bottle | ca-certificates, openssl@3, libevent, ncurses, utf8proc, jemalloc |
| tre-command | 0.4.0 | 手选 | Homebrew bottle | 收据未列 |
| tree | 2.3.2 | 手选 | Homebrew bottle | 收据未列 |
| tree-sitter | 0.27.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| ty | 0.0.84 | 手选 | Homebrew bottle | 收据未列 |
| unibilium | 2.1.4 | 收据未标注 | Homebrew bottle | 收据未列 |
| utf8proc | 2.12.0 | 收据未标注 | Homebrew bottle | 收据未列 |
| utftex | 1.31 | 手选 | Homebrew bottle | 收据未列 |
| webp | 1.6.0 | 依赖 | Homebrew bottle | giflib, jpeg-turbo, libpng, xz, lz4, zstd, libtiff |
| weechat | 4.10.1_1 | 手选 | Homebrew bottle | cjson, aspell, pcre2, json-c, libunistring, gettext, glib, enchant, ca-certificates, gmp, libidn2, libtasn1, nettle, p11-kit, gnutls, libgpg-error, libgcrypt, lua, ncurses, mpdecimal, openssl@3, readline, sqlite, xz, lz4, zstd, python@3.14, libyaml, ruby, libtommath, tcl-tk |
| wget | 1.25.0_2 | 手选 | Homebrew bottle | libunistring, json-c, gettext, libidn2, libpsl, ca-certificates, openssl@4 |
| x264 | r3222 | 依赖 | Homebrew bottle | 收据未列 |
| x265 | 4.3 | 收据未标注 | Homebrew bottle | 收据未列 |
| xorgproto | 2026.1 | 收据未标注 | Homebrew bottle | 收据未列 |
| xz | 5.8.4 | 收据未标注 | Homebrew bottle | 收据未列 |
| zellij | 0.45.1 | 手选 | Homebrew bottle | ca-certificates, openssl@3 |
| zoxide | 0.10.0 | 手选 | Homebrew bottle | 收据未列 |
| zsh-autosuggestions | 0.7.1 | 手选 | Homebrew bottle | 收据未列 |
| zsh-fast-syntax-highlighting | 1.56 | 手选 | Homebrew bottle | 收据未列 |
| zsh-syntax-highlighting | 0.8.0 | 手选 | Homebrew bottle | 收据未列 |
| zstd | 1.5.7_1 | 依赖 | Homebrew bottle | lz4, xz |


</details>

<details>
<summary>9.2 Mac Caskroom 记录</summary>

有版本目录不完全等价于目标 App 仍存在；Emacs、Codex、Copilot CLI、Claude Code 的版本另经 brew 查询确认。codexbar 只留 metadata，不能写成已安装。

| 项目 | 版本目录 | 证据状态 |
| --- | --- | --- |
| claude-code@latest | 2.1.302 | has-version-directory |
| codex | 0.163.0 | has-version-directory |
| codexbar | 无 | metadata-only |
| copilot-cli | 0.0.421 | has-version-directory |
| emacs-app | 31.1 | has-version-directory |
| font-gnu-unifont | 18.0.01 | has-version-directory |
| font-symbols-only-nerd-font | 3.5.1 | has-version-directory |
| jordanbaird-ice | 0.11.12 | has-version-directory |


</details>

<details>
<summary>9.3 Fedora：本环境涉及且实际安装的系统 RPM</summary>

版本来自 rpm 数据库。依赖为 rpm Requires，已略去 rpmlib 格式能力和 /bin/sh 等通用脚本解释器项；库 SONAME/ABI 不应误当作 dnf 包名。没有列出的目标见正文的“未见该 RPM”。

| RPM | 版本 | 架构 | Requires |
| --- | --- | --- | --- |
| git | 2.56.0-1.fc44 | x86_64 | /usr/bin/perl, /usr/bin/sh, git-core = 2.56.0-1.fc44, git-core-doc = 2.56.0-1.fc44, perl(:VERSION) >= 5.8.0, perl(File::Basename), perl(File::Spec), perl(Getopt::Long), perl(Git), perl(IPC::Open2), perl(Term::ReadKey), perl(lib), perl(strict), perl(warnings), perl-Git = 2.56.0-1.fc44 |
| python3 | 3.14.8-1.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libpython3.14.so.1.0()(64bit), python3-libs(x86-64) = 3.14.8-1.fc44, rtld(GNU_HASH) |
| zsh | 5.9-21.fc44 | x86_64 | /usr/bin/sh, /usr/bin/zsh, config(zsh) = 5.9-21.fc44, coreutils, grep, grep, libc.so.6()(64bit), libc.so.6(GLIBC_2.11)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.7)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.23)(64bit), libm.so.6(GLIBC_2.29)(64bit), libm.so.6(GLIBC_2.35)(64bit), libm.so.6(GLIBC_2.38)(64bit), libncursesw.so.6()(64bit), libpcre2-8.so.0()(64bit), libpcre2-8.so.0(PCRE2_10.47)(64bit), libtinfo.so.6()(64bit), rtld(GNU_HASH) |
| fd-find | 10.4.2-4.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.16)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.18)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.28)(64bit), libc.so.6(GLIBC_2.29)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.30)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.39)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.9)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3)(64bit), libgcc_s.so.1(GCC_4.2.0)(64bit), libjemalloc.so.2()(64bit), rtld(GNU_HASH) |
| ripgrep | 15.2.0-1.fc44 | x86_64 | ld-linux-x86-64.so.2()(64bit), ld-linux-x86-64.so.2(GLIBC_2.3)(64bit), libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.16)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.18)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.28)(64bit), libc.so.6(GLIBC_2.29)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.30)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.39)(64bit), libc.so.6(GLIBC_2.9)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3)(64bit), libgcc_s.so.1(GCC_4.2.0)(64bit), libpcre2-8.so.0()(64bit), libpcre2-8.so.0(PCRE2_10.47)(64bit), rtld(GNU_HASH) |
| fzf | 0.74.4-1.fc44 | x86_64 | /usr/bin/bash, libc.so.6()(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libresolv.so.2()(64bit), rtld(GNU_HASH) |
| zoxide | 0.9.8-2.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.16)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.28)(64bit), libc.so.6(GLIBC_2.29)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.30)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.39)(64bit), libc.so.6(GLIBC_2.9)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3)(64bit), libgcc_s.so.1(GCC_4.2.0)(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.29)(64bit), rtld(GNU_HASH) |
| starship | 1.24.2-1.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.13)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.16)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.18)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.28)(64bit), libc.so.6(GLIBC_2.29)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.30)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.39)(64bit), libc.so.6(GLIBC_2.9)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3)(64bit), libgcc_s.so.1(GCC_4.2.0)(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.29)(64bit), rtld(GNU_HASH) |
| bat | 0.26.1-4.fc44 | x86_64 | filesystem(unmerged-sbin-symlinks), libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.16)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.18)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.28)(64bit), libc.so.6(GLIBC_2.29)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.30)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.39)(64bit), libc.so.6(GLIBC_2.9)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3)(64bit), libgcc_s.so.1(GCC_4.2.0)(64bit), libgit2.so.1.9()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.27)(64bit), libm.so.6(GLIBC_2.29)(64bit), libonig.so.5()(64bit), rtld(GNU_HASH) |
| jq | 1.8.1-3.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.7)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libjq.so.1()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.23)(64bit), libm.so.6(GLIBC_2.29)(64bit), libm.so.6(GLIBC_2.35)(64bit), libm.so.6(GLIBC_2.38)(64bit), libm.so.6(GLIBC_2.39)(64bit), libm.so.6(GLIBC_2.43)(64bit), libonig.so.5()(64bit), rtld(GNU_HASH) |
| environment-modules | 5.6.2-1.fc44 | x86_64 | /usr/bin/bash, /usr/bin/sh, /usr/bin/tclsh, /usr/bin/update-alternatives, /usr/bin/update-alternatives, config(environment-modules) = 5.6.2-1.fc44, coreutils, emacs-filesystem >= 30.2, less, libc.so.6()(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), man-db, procps-ng, rtld(GNU_HASH), sed, tcl, util-linux-core, vim-filesystem |
| gcc | 16.2.1-2.fc44 | x86_64 | /usr/bin/sh, binutils >= 2.43, cpp = 16.2.1-2.fc44, glibc-devel >= 2.2.90-12, libatomic = 16.2.1-2.fc44, libc.so.6()(64bit), libc.so.6(GLIBC_2.11)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.3.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.35)(64bit), libc.so.6(GLIBC_2.36)(64bit), libc.so.6(GLIBC_2.38)(64bit), libgcc >= 16.2.1-2.fc44, libgmp.so.10()(64bit), libgomp = 16.2.1-2.fc44, libgomp.so.1()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libmpc.so.3()(64bit), libmpfr.so.6()(64bit), libz.so.1()(64bit), libzstd.so.1()(64bit), make, rtld(GNU_HASH) |
| gcc-c++ | 16.2.1-2.fc44 | x86_64 | gcc = 16.2.1-2.fc44, libc.so.6()(64bit), libc.so.6(GLIBC_2.10)(64bit), libc.so.6(GLIBC_2.11)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.35)(64bit), libc.so.6(GLIBC_2.36)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.6)(64bit), libgmp.so.10()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libmpc.so.3()(64bit), libmpfr.so.6()(64bit), libstdc++ = 16.2.1-2.fc44, libstdc++-devel = 16.2.1-2.fc44, libstdc++.so.6()(64bit), libz.so.1()(64bit), libz.so.1(ZLIB_1.2.2)(64bit), libzstd.so.1()(64bit), rtld(GNU_HASH) |
| gcc-gfortran | 16.2.1-2.fc44 | x86_64 | gcc = 16.2.1-2.fc44, libc.so.6()(64bit), libc.so.6(GLIBC_2.11)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.25)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.35)(64bit), libc.so.6(GLIBC_2.36)(64bit), libc.so.6(GLIBC_2.38)(64bit), libgfortran = 16.2.1-2.fc44, libgfortran.so.5()(64bit), libgmp.so.10()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libmpc.so.3()(64bit), libmpfr.so.6()(64bit), libquadmath = 16.2.1-2.fc44, libquadmath-devel = 16.2.1-2.fc44, libz.so.1()(64bit), libzstd.so.1()(64bit), rtld(GNU_HASH) |
| make | 4.4.1-12.fc44 | x86_64 | libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.27)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), rtld(GNU_HASH) |
| cmake | 4.3.0-1.fc44 | x86_64 | (cmake-rpm-macros = 4.3.0-1.fc44 if rpm-build), cmake-data = 4.3.0-1.fc44, cmake-filesystem(x86-64) = 4.3.0-1.fc44, libarchive.so.13()(64bit), libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.6)(64bit), libc.so.6(GLIBC_2.7)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libcurl.so.4()(64bit), libexpat.so.1()(64bit), libform.so.6()(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3.1)(64bit), libjsoncpp.so.26()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libncurses.so.6()(64bit), librhash.so.1()(64bit), libstdc++.so.6()(64bit), libstdc++.so.6(CXXABI_1.3)(64bit), libstdc++.so.6(CXXABI_1.3.11)(64bit), libstdc++.so.6(CXXABI_1.3.13)(64bit), libstdc++.so.6(CXXABI_1.3.15)(64bit), libstdc++.so.6(CXXABI_1.3.2)(64bit), libstdc++.so.6(CXXABI_1.3.5)(64bit), libstdc++.so.6(CXXABI_1.3.9)(64bit), libstdc++.so.6(GLIBCXX_3.4)(64bit), libstdc++.so.6(GLIBCXX_3.4.11)(64bit), libstdc++.so.6(GLIBCXX_3.4.14)(64bit), libstdc++.so.6(GLIBCXX_3.4.15)(64bit), libstdc++.so.6(GLIBCXX_3.4.17)(64bit), libstdc++.so.6(GLIBCXX_3.4.18)(64bit), libstdc++.so.6(GLIBCXX_3.4.19)(64bit), libstdc++.so.6(GLIBCXX_3.4.20)(64bit), libstdc++.so.6(GLIBCXX_3.4.21)(64bit), libstdc++.so.6(GLIBCXX_3.4.22)(64bit), libstdc++.so.6(GLIBCXX_3.4.26)(64bit), libstdc++.so.6(GLIBCXX_3.4.29)(64bit), libstdc++.so.6(GLIBCXX_3.4.30)(64bit), libstdc++.so.6(GLIBCXX_3.4.32)(64bit), libstdc++.so.6(GLIBCXX_3.4.9)(64bit), libtinfo.so.6()(64bit), libuv.so.1()(64bit), libz.so.1()(64bit), make, rtld(GNU_HASH) |
| pkgconf-pkg-config | 2.5.1-1.fc44 | x86_64 | /usr/bin/sh, pkgconf(x86-64) = 2.5.1-1.fc44, pkgconf-m4 = 2.5.1-1.fc44 |
| autoconf | 2.72-10.fc44 | noarch | /usr/bin/perl, /usr/bin/sh, emacs-filesystem, gettext-devel, m4 >= 1.4.14, perl(:VERSION) >= 5.6.0, perl(Carp), perl(Class::Struct), perl(Cwd), perl(Data::Dumper), perl(Errno), perl(Exporter), perl(File::Basename), perl(File::Compare), perl(File::Copy), perl(File::Find), perl(File::Spec), perl(File::Temp), perl(File::stat), perl(Getopt::Long), perl(IO::File), perl(POSIX), perl(Text::ParseWords), perl(constant), perl(strict), perl(warnings), perl-interpreter |
| automake | 1.18.1-4.fc44 | noarch | /usr/bin/perl, /usr/bin/sh, autoconf >= 2.65, perl(:VERSION) >= 5.6.0, perl(Carp), perl(Class::Struct), perl(Config), perl(Errno), perl(Exporter), perl(File::Basename), perl(File::Path), perl(File::Spec), perl(Getopt::Long), perl(IO::File), perl(Thread::Queue), perl(constant), perl(threads) |
| libtool | 2.5.4-10.fc44 | x86_64 | /usr/bin/sh, autoconf, automake, findutils, gcc(major) = 16, sed, tar |
| libvterm-devel | 0.3.3-7.fc44 | x86_64 | /usr/bin/pkg-config, libvterm(x86-64) = 0.3.3-7.fc44, libvterm.so.0()(64bit) |
| poppler-glib-devel | 26.01.0-3.fc44 | x86_64 | /usr/bin/pkg-config, libpoppler-glib.so.8()(64bit), pkgconfig(cairo) >= 1.16.0, pkgconfig(freetype2) >= 2.11, pkgconfig(gio-2.0) >= 2.72, pkgconfig(glib-2.0) >= 2.72, pkgconfig(gobject-2.0) >= 2.72, pkgconfig(poppler) = 26.01.0, poppler-devel(x86-64) = 26.01.0-3.fc44, poppler-glib(x86-64) = 26.01.0-3.fc44 |
| libpng-devel | 1.6.58-1.fc44 | x86_64 | /usr/bin/pkg-config, /usr/bin/sh, cmake-filesystem(x86-64), libc.so.6()(64bit), libc.so.6(GLIBC_2.11)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libpng(x86-64) = 2:1.6.58-1.fc44, libpng16.so.16()(64bit), libpng16.so.16(PNG16_0)(64bit), libz.so.1()(64bit), libz.so.1(ZLIB_1.2.3.4)(64bit), pkgconfig, pkgconfig(zlib), rtld(GNU_HASH), zlib-devel(x86-64) |
| openmpi | 5.0.9-4.fc44 | x86_64 | config(openmpi) = 5.0.9-4.fc44, environment(modules), libc.so.6()(64bit), libc.so.6(GLIBC_2.10)(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.27)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.2)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.8)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libc.so.6(GLIBC_ABI_GNU2_TLS)(64bit), libevent_core-2.1.so.7()(64bit), libevent_pthreads-2.1.so.7()(64bit), libfabric.so.1()(64bit), libfabric.so.1(FABRIC_1.0)(64bit), libfabric.so.1(FABRIC_1.1)(64bit), libfabric.so.1(FABRIC_1.5)(64bit), libfabric.so.1(FABRIC_1.8)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3.1)(64bit), libgfortran.so.5()(64bit), libhwloc.so.15()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.29)(64bit), libmpi.so.40()(64bit)(openmpi-x86_64), libmpi_mpifh.so.40()(64bit)(openmpi-x86_64), liboshmem.so.40()(64bit)(openmpi-x86_64), libpmix.so.2()(64bit), libpsm2.so.2()(64bit), libpsm2.so.2(PSM2_1.0)(64bit), libpvfs2.so.2.10.0()(64bit), libquadmath.so.0()(64bit), libucm.so.0()(64bit), libucp.so.0()(64bit), libucs.so.0()(64bit), libuct.so.0()(64bit), openssh-clients, prrte, rtld(GNU_HASH) |
| openmpi-devel | 5.0.9-4.fc44 | x86_64 | (python(abi) = 3.14 if python3), /usr/bin/pkg-config, gcc-gfortran, libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.8)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libpmix.so.2()(64bit), openmpi = 5.0.9-4.fc44, rpm-mpi-hooks, rtld(GNU_HASH) |
| mpich | 4.2.2-7.fc44 | x86_64 | (python(abi) = 3.14 if python3), environment(modules), libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.15)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.32)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libc.so.6(GLIBC_ABI_GNU2_TLS)(64bit), libfabric.so.1()(64bit), libfabric.so.1(FABRIC_1.0)(64bit), libfabric.so.1(FABRIC_1.1)(64bit), libfabric.so.1(FABRIC_1.8)(64bit), libgcc_s.so.1()(64bit), libgfortran.so.5()(64bit), libgfortran.so.5(GFORTRAN_8)(64bit), libgfortran.so.5(GFORTRAN_9)(64bit), libhwloc.so.15()(64bit), libm.so.6()(64bit), libmpi.so.12()(64bit)(mpich-x86_64), libstdc++.so.6()(64bit), libstdc++.so.6(CXXABI_1.3)(64bit), libstdc++.so.6(CXXABI_1.3.8)(64bit), libstdc++.so.6(CXXABI_1.3.9)(64bit), libstdc++.so.6(GLIBCXX_3.4)(64bit), libyaksa.so.0()(64bit), rtld(GNU_HASH) |
| mpich-devel | 4.2.2-7.fc44 | x86_64 | /usr/bin/bash, gcc-gfortran, mpich = 4.2.2-7.fc44, pkgconfig, redhat-rpm-config, rpm-mpi-hooks |
| hdf5 | 1.14.6-7.fc44 | x86_64 | /usr/bin/bash, libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.8)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libgcc_s.so.1()(64bit), libgcc_s.so.1(GCC_3.0)(64bit), libgcc_s.so.1(GCC_3.3.1)(64bit), libgfortran.so.5()(64bit), libgfortran.so.5(GFORTRAN_8)(64bit), libhdf5.so.310()(64bit), libhdf5_fortran.so.310()(64bit), libhdf5_hl.so.310()(64bit), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.27)(64bit), libm.so.6(GLIBC_2.29)(64bit), libstdc++.so.6()(64bit), libstdc++.so.6(CXXABI_1.3)(64bit), libstdc++.so.6(CXXABI_1.3.15)(64bit), libstdc++.so.6(GLIBCXX_3.4)(64bit), libstdc++.so.6(GLIBCXX_3.4.11)(64bit), libstdc++.so.6(GLIBCXX_3.4.32)(64bit), libstdc++.so.6(GLIBCXX_3.4.9)(64bit), libsz.so.2()(64bit), libz.so.1()(64bit), libz.so.1(ZLIB_1.2.0)(64bit), rtld(GNU_HASH) |
| hdf5-openmpi | 1.14.6-7.fc44 | x86_64 | /usr/bin/bash, /usr/bin/sh, libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.8)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libgcc_s.so.1()(64bit), libgfortran.so.5()(64bit), libgfortran.so.5(GFORTRAN_8)(64bit), libhdf5.so.310()(64bit)(openmpi-x86_64), libhdf5_fortran.so.310()(64bit)(openmpi-x86_64), libhdf5_hl.so.310()(64bit)(openmpi-x86_64), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.27)(64bit), libm.so.6(GLIBC_2.29)(64bit), libmpi.so.40()(64bit)(openmpi-x86_64), libsz.so.2()(64bit), libz.so.1()(64bit), libz.so.1(ZLIB_1.2.0)(64bit), rtld(GNU_HASH) |
| hdf5-mpich | 1.14.6-7.fc44 | x86_64 | /usr/bin/bash, /usr/bin/sh, libc.so.6()(64bit), libc.so.6(GLIBC_2.14)(64bit), libc.so.6(GLIBC_2.17)(64bit), libc.so.6(GLIBC_2.2.5)(64bit), libc.so.6(GLIBC_2.3)(64bit), libc.so.6(GLIBC_2.3.4)(64bit), libc.so.6(GLIBC_2.33)(64bit), libc.so.6(GLIBC_2.34)(64bit), libc.so.6(GLIBC_2.38)(64bit), libc.so.6(GLIBC_2.4)(64bit), libc.so.6(GLIBC_2.8)(64bit), libc.so.6(GLIBC_ABI_DT_RELR)(64bit), libgcc_s.so.1()(64bit), libgfortran.so.5()(64bit), libgfortran.so.5(GFORTRAN_8)(64bit), libhdf5.so.310()(64bit)(mpich-x86_64), libhdf5_fortran.so.310()(64bit)(mpich-x86_64), libhdf5_hl.so.310()(64bit)(mpich-x86_64), libm.so.6()(64bit), libm.so.6(GLIBC_2.2.5)(64bit), libm.so.6(GLIBC_2.27)(64bit), libm.so.6(GLIBC_2.29)(64bit), libmpi.so.12()(64bit)(mpich-x86_64), libsz.so.2()(64bit), libz.so.1()(64bit), libz.so.1(ZLIB_1.2.0)(64bit), rtld(GNU_HASH) |

另核实：`zlib-ng-compat-devel 2.3.3-3.fc44.x86_64` 已安装。

</details>

<details>
<summary>9.4 Fedora：Intel oneAPI RPM 全部安装记录</summary>

同一组件的版本包、元包、运行时和开发包会同时存在；不要把每一行都算作一个独立用户程序。它们归 RPM 管理，用户 modulefile 只负责加载环境。

| RPM | 版本 | 架构 |
| --- | --- | --- |
| intel-oneapi-advisor | 2026.0.0-263 | x86_64 |
| intel-oneapi-ccl-2022.1 | 2022.1.2-9 | x86_64 |
| intel-oneapi-ccl-devel-2022.1 | 2022.1.2-9 | x86_64 |
| intel-oneapi-ccl-devel | 2022.1.2-9 | x86_64 |
| intel-oneapi-common-licensing-2025.3 | 2025.3.1-15 | noarch |
| intel-oneapi-common-licensing-2026.0 | 2026.0.0-235 | noarch |
| intel-oneapi-common-licensing | 2026.0.0-235 | noarch |
| intel-oneapi-common-oneapi-vars-2025.3 | 2025.3.1-15 | noarch |
| intel-oneapi-common-oneapi-vars-2026.0 | 2026.0.0-235 | noarch |
| intel-oneapi-common-oneapi-vars | 2026.0.0-235 | noarch |
| intel-oneapi-common-vars | 2026.0.0-235 | noarch |
| intel-oneapi-compiler-cpp-eclipse-cfg-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-compiler-dpcpp-cpp-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-dpcpp-cpp-common-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-compiler-dpcpp-cpp-runtime-2026.0 | 2026.0.0-947 | x86_64 |
| intel-oneapi-compiler-dpcpp-cpp-runtime-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-dpcpp-cpp | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-dpcpp-eclipse-cfg-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-compiler-fortran-2025.3 | 2025.3.3-30 | x86_64 |
| intel-oneapi-compiler-fortran-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-fortran-common-2025.3 | 2025.3.3-30 | noarch |
| intel-oneapi-compiler-fortran-common-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-compiler-fortran-runtime-2025.3 | 2025.3.3-30 | x86_64 |
| intel-oneapi-compiler-fortran-runtime-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-shared-2025.3 | 2025.3.3-30 | x86_64 |
| intel-oneapi-compiler-shared-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-compiler-shared-common-2025.3 | 2025.3.3-30 | noarch |
| intel-oneapi-compiler-shared-common-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-compiler-shared-runtime-2025.3 | 2025.3.3-30 | x86_64 |
| intel-oneapi-compiler-shared-runtime-2026.0 | 2026.0.0-947 | x86_64 |
| intel-oneapi-compiler-shared-runtime-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-dal-2026.1 | 2026.1.0-7 | x86_64 |
| intel-oneapi-dal-devel-2026.1 | 2026.1.0-7 | x86_64 |
| intel-oneapi-dal-devel | 2026.1.0-7 | x86_64 |
| intel-oneapi-dev-utilities-2026.0 | 2026.0.1-16 | x86_64 |
| intel-oneapi-dev-utilities-eclipse-cfg-2026.0 | 2026.0.1-16 | noarch |
| intel-oneapi-dev-utilities | 2026.0.1-16 | x86_64 |
| intel-oneapi-dnnl-2026.0 | 2026.0.2-40 | x86_64 |
| intel-oneapi-dnnl-devel-2026.0 | 2026.0.2-40 | x86_64 |
| intel-oneapi-dnnl-devel | 2026.0.2-40 | x86_64 |
| intel-oneapi-dpcpp-cpp-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-dpcpp-ct-2025.3 | 2025.3.1-18 | x86_64 |
| intel-oneapi-dpcpp-ct-eclipse-cfg-2025.3 | 2025.3.1-18 | noarch |
| intel-oneapi-dpcpp-ct | 2025.3.1-18 | x86_64 |
| intel-oneapi-dpcpp-debugger-2025.3 | 2025.3.1-7 | x86_64 |
| intel-oneapi-dpcpp-debugger-2026.1 | 2026.1.0-70 | x86_64 |
| intel-oneapi-hpc-toolkit-env-2025.3 | 2025.3.1-52 | noarch |
| intel-oneapi-hpc-toolkit-getting-started-2025.3 | 2025.3.1-52 | noarch |
| intel-oneapi-hpc-toolkit | 2025.3.1-52 | x86_64 |
| intel-oneapi-icc-eclipse-plugin-cpp-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-ipp-2026.0 | 2026.0.1-51 | x86_64 |
| intel-oneapi-ipp-devel-2026.0 | 2026.0.1-51 | x86_64 |
| intel-oneapi-ipp-devel | 2026.0.1-51 | x86_64 |
| intel-oneapi-ippcp-2026.0 | 2026.0.1-9 | x86_64 |
| intel-oneapi-ippcp-devel-2026.0 | 2026.0.1-9 | x86_64 |
| intel-oneapi-ippcp-devel | 2026.0.1-9 | x86_64 |
| intel-oneapi-ishmem-1.6 | 1.6.0-223 | x86_64 |
| intel-oneapi-ishmem-devel-1.6 | 1.6.0-223 | x86_64 |
| intel-oneapi-ishmem-devel | 1.6.0-223 | x86_64 |
| intel-oneapi-libdpstd-devel-2022.10 | 2022.10.0-275 | x86_64 |
| intel-oneapi-libdpstd-devel-2022.13 | 2022.13.0-107 | x86_64 |
| intel-oneapi-mkl-classic-devel-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-classic-devel-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-classic-include-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-classic-include-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-cluster-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-cluster-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-cluster-devel-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-cluster-devel-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-core-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-core-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-core-devel-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-core-devel-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-devel-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-devel-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-devel | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-blas-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-blas-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-data-fitting-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-data-fitting-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-devel-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-devel-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-dft-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-dft-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-include-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-include-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-lapack-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-lapack-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-rng-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-rng-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-sparse-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-sparse-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-stats-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-stats-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mkl-sycl-vm-2026.0 | 2026.0.0-908 | x86_64 |
| intel-oneapi-mkl-sycl-vm-2026.1 | 2026.1.0-236 | x86_64 |
| intel-oneapi-mpi-2021.17 | 2021.17.2-91 | x86_64 |
| intel-oneapi-mpi-2021.18 | 2021.18.1-9 | x86_64 |
| intel-oneapi-mpi-devel-2021.18 | 2021.18.1-9 | x86_64 |
| intel-oneapi-mpi-devel | 2021.18.1-9 | x86_64 |
| intel-oneapi-openmp-2025.3 | 2025.3.3-30 | x86_64 |
| intel-oneapi-openmp-2026.0 | 2026.0.0-947 | x86_64 |
| intel-oneapi-openmp-2026.1 | 2026.1.1-325 | x86_64 |
| intel-oneapi-openmp-common-2025.3 | 2025.3.3-30 | noarch |
| intel-oneapi-openmp-common-2026.0 | 2026.0.0-947 | noarch |
| intel-oneapi-openmp-common-2026.1 | 2026.1.1-325 | noarch |
| intel-oneapi-tbb-2023.0 | 2023.0.0-724 | x86_64 |
| intel-oneapi-tbb-2023.1 | 2023.1.0-151 | x86_64 |
| intel-oneapi-tbb-devel-2023.0 | 2023.0.0-724 | x86_64 |
| intel-oneapi-tbb-devel-2023.1 | 2023.1.0-151 | x86_64 |
| intel-oneapi-tbb-devel | 2023.1.0-151 | x86_64 |
| intel-oneapi-tcm-1.4 | 1.4.1-445 | x86_64 |
| intel-oneapi-tcm-1.5 | 1.5.0-489 | x86_64 |
| intel-oneapi-tlt-2025.3 | 2025.3.0-157 | x86_64 |
| intel-oneapi-tlt-2026.0 | 2026.0.0-220 | x86_64 |
| intel-oneapi-tlt | 2026.0.0-220 | x86_64 |
| intel-oneapi-toolkit-env-2026.1 | 2026.1.1-31 | noarch |
| intel-oneapi-toolkit-getting-started-2026.1 | 2026.1.1-31 | noarch |
| intel-oneapi-toolkit | 2026.1.1-31 | x86_64 |
| intel-oneapi-umf-1.0 | 1.0.3-17 | x86_64 |
| intel-oneapi-umf-1.1 | 1.1.0-340 | x86_64 |
| intel-oneapi-vtune | 2026.4.0-20 | x86_64 |


</details>

<details>
<summary>9.5 Steam Deck：全部应用环境的实际 Conda 包与依赖</summary>

按“包名 + 版本 + build”合并，共 167 条。环境列表示实际归属；同名包不同 build 不合并。依赖为 Conda 元数据中的 MatchSpec，`__glibc` 等属于宿主虚拟包要求。

| 包 | 版本 | build | 所属环境 | 声明依赖 |
| --- | --- | --- | --- | --- |
| _openmp_mutex | 4.5 | 20_gnu | emacs/31.1, fd/10.5.0, gcc/16.2.0, git/2.56.0, jq/1.8.2, modules/5.7.0, ripgrep/15.2.0, starship/1.27.0, zoxide/0.10.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgomp >=7.5.0 |
| at-spi2-atk | 2.38.0 | h0630a04_3 | emacs/31.1 | at-spi2-core >=2.40.0,<2.41.0a0, atk-1.0 >=2.36.0, dbus >=1.13.6,<2.0a0, libgcc-ng >=9.3.0, libglib >=2.68.1,<3.0a0 |
| at-spi2-core | 2.40.3 | h0630a04_0 | emacs/31.1 | dbus >=1.13.6,<2.0a0, libgcc-ng >=9.3.0, libglib >=2.68.3,<3.0a0, xorg-libx11, xorg-libxi, xorg-libxtst |
| atk-1.0 | 2.38.0 | h04ea711_2 | emacs/31.1 | libgcc-ng >=12, libglib >=2.80.0,<3.0a0, libstdcxx-ng >=12 |
| autoconf | 2.72 | pl5321hbb4ee43_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, m4, perl 5.* |
| automake | 1.19 | hfc2019e_0 | emacs/31.1 | m4, autoconf, perl 5.* |
| binutils_impl_linux-64 | 2.46.1 | default_hfdba357_103 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | ld_impl_linux-64 2.46.1 default_hbd61a6d_103, sysroot_linux-64, zstd >=1.5.7,<1.6.0a0 |
| binutils_linux-64 | 2.46.1 | default_h4852527_103 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | binutils_impl_linux-64 2.46.1 default_hfdba357_103 |
| bzip2 | 1.0.8 | hda65f42_10 | emacs/31.1, git/2.56.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| c-ares | 1.34.8 | hebe6cf0_2 | emacs/31.1, git/2.56.0 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| ca-certificates | 2026.10.18 | hbd8a1cb_0 | emacs/31.1, git/2.56.0 | __unix |
| cairo | 1.18.6 | h3c89d7e_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, fontconfig >=2.18.3,<3.0a0, fonts-conda-ecosystem, icu >=78.3,<79.0a0, libexpat >=2.8.1,<3.0a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, libgcc >=15, libglib >=2.90.0,<3.0a0, libpng >=1.6.58,<1.7.0a0, libstdcxx >=15, libxcb >=1.17.0,<2.0a0, libzlib >=1.3.2,<2.0a0, pixman >=0.46.4,<1.0a0, xorg-libice >=1.1.2,<2.0a0, xorg-libsm >=1.2.6,<2.0a0, xorg-libx11 >=1.8.13,<2.0a0, xorg-libxext >=1.3.7,<2.0a0, xorg-libxrender >=0.9.12,<0.10.0a0 |
| cmake | 4.4.4 | hff7ac6b_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libstdcxx >=15, ncurses >=6.6,<7.0a0, libexpat >=2.8.5,<3.0a0, libcurl >=8.22.0,<9.0a0, rhash >=1.4.6,<2.0a0, liblzma >=5.8.3,<6.0a0, libzlib >=1.3.2,<2.0a0, zstd >=1.5.7,<1.6.0a0, libuv >=1.52.1,<2.0a0, bzip2 >=1.0.8,<2.0a0 |
| dbus | 1.16.2 | he8c428d_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libstdcxx >=15, libexpat >=2.8.1,<3.0a0, libzlib >=1.3.2,<2.0a0, libglib >=2.88.3,<3.0a0 |
| epoxy | 1.5.10 | hb03c661_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libdrm >=2.4.125,<2.5.0a0, libegl >=1.7.0,<2.0a0, libegl-devel, libgcc >=14, libgl >=1.7.0,<2.0a0, libgl-devel, libglx >=1.7.0,<2.0a0, libglx-devel, xorg-libx11 >=1.8.12,<2.0a0, xorg-libxdamage >=1.1.6,<2.0a0, xorg-libxext >=1.3.6,<2.0a0, xorg-libxfixes >=6.0.1,<7.0a0, xorg-libxxf86vm >=1.1.6,<2.0a0 |
| expat | 2.8.5 | hd2095e1_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libexpat 2.8.5 hd2095e1_0, libgcc >=15 |
| fd-find | 10.5.0 | hf19af3b_0 | fd/10.5.0 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| font-ttf-dejavu-sans-mono | 2.37 | hab24e00_0 | emacs/31.1 | 无 |
| font-ttf-inconsolata | 3.000 | h77eed37_0 | emacs/31.1 | 无 |
| font-ttf-source-code-pro | 2.038 | h77eed37_0 | emacs/31.1 | 无 |
| font-ttf-ubuntu | 0.83 | h77eed37_3 | emacs/31.1 | 无 |
| fontconfig | 2.18.3 | h4db4eae_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libexpat >=2.8.1,<3.0a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, libgcc >=15, libuuid >=2.42.2,<3.0a0, libzlib >=1.3.2,<2.0a0 |
| fonts-conda-ecosystem | 1 | 0 | emacs/31.1 | fonts-conda-forge |
| fonts-conda-forge | 1 | hc364b38_1 | emacs/31.1 | font-ttf-ubuntu, font-ttf-inconsolata, font-ttf-dejavu-sans-mono, font-ttf-source-code-pro |
| freetype | 2.14.3 | ha770c72_2 | emacs/31.1 | libfreetype 2.14.3 ha770c72_2, libfreetype6 2.14.3 h5e6c136_2 |
| fribidi | 1.0.17 | h7cc23a3_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| fzf | 0.74.5 | hfc2019e_0 | fzf/0.74.5 | 无 |
| gcc_impl_linux-64 | 16.2.0 | h9891192_7 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | binutils_impl_linux-64 >=2.46.1, libgcc >=16.2.0, libgcc-devel_linux-64 16.2.0 he3ce08f_107, libgomp >=16.2.0, libsanitizer 16.2.0 h3048135_7, libstdcxx >=16.2.0, libstdcxx-devel_linux-64 16.2.0 h86e191b_107, sysroot_linux-64 |
| gcc_linux-64 | 16.2.0 | h0ab548f_2 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | gcc_impl_linux-64 16.2.0.*, binutils_linux-64, sysroot_linux-64 |
| gdbm | 1.18 | h0a1914f_2 | zsh/5.9.2 | libgcc-ng >=7.5.0, readline >=8.0,<9.0a0 |
| gdk-pixbuf | 2.44.8 | h68053f1_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libglib >=2.88.3,<3.0a0, libjpeg-turbo >=3.2.0,<4.0a0, liblzma >=5.8.3,<6.0a0, libpng >=1.6.58,<1.7.0a0, libtiff >=4.7.2,<4.8.0a0 |
| giflib | 6.1.3 | hebe6cf0_2 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| git | 2.56.0 | pl5440h3795e67_0 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libcurl >=8.22.0,<9.0a0, libexpat >=2.8.5,<3.0a0, libgcc >=15, libiconv >=1.18,<2.0a0, libzlib >=1.3.2,<2.0a0, openssl >=3.5.8,<4.0a0, pcre2 >=10.47,<10.48.0a0, perl 5.* |
| glib | 2.90.0 | h5e3c387_0 | emacs/31.1 | python *, packaging, libglib ==2.90.0 h569388d_0, glib-tools ==2.90.0 h3d503d9_0 |
| glib-tools | 2.90.0 | h3d503d9_0 | emacs/31.1 | libglib ==2.90.0 h569388d_0, libffi, libgcc >=15, __glibc >=2.17,<3.0.a0 |
| gmp | 6.3.0 | hfd2156b_3 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libstdcxx >=14 |
| gnutls | 3.8.13 | h18acefa_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, gmp >=6.3.0,<7.0a0, libgcc >=14, libidn2 >=2,<3.0a0, libstdcxx >=14, libtasn1 >=4.21.0,<5.0a0, nettle >=3.10.1,<3.11.0a0, p11-kit >=0.26.2,<0.27.0a0 |
| graphite2 | 1.3.15 | h54a6638_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libstdcxx >=14, libgcc >=14 |
| gtk3 | 3.24.52 | ha5ea40c_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, at-spi2-atk >=2.38.0,<3.0a0, atk-1.0 >=2.38.0, cairo >=1.18.4,<2.0a0, epoxy >=1.5.10,<1.6.0a0, fontconfig >=2.17.1,<3.0a0, fonts-conda-ecosystem, fribidi >=1.0.16,<2.0a0, gdk-pixbuf >=2.44.5,<3.0a0, glib-tools, harfbuzz >=13.2.1, hicolor-icon-theme, libcups >=2.3.3,<2.4.0a0, libcups >=2.3.3,<3.0a0, libexpat >=2.7.4,<3.0a0, libfreetype >=2.14.2, libfreetype6 >=2.14.2, libgcc >=14, libglib >=2.86.4,<3.0a0, liblzma >=5.8.2,<6.0a0, libxkbcommon >=1.13.1,<2.0a0, libzlib >=1.3.2,<2.0a0, pango >=1.56.4,<2.0a0, wayland >=1.25.0,<2.0a0, xorg-libx11 >=1.8.13,<2.0a0, xorg-libxcomposite >=0.4.7,<1.0a0, xorg-libxcursor >=1.2.3,<2.0a0, xorg-libxdamage >=1.1.6,<2.0a0, xorg-libxext >=1.3.7,<2.0a0, xorg-libxfixes >=6.0.2,<7.0a0, xorg-libxi >=1.8.2,<2.0a0, xorg-libxinerama >=1.1.6,<1.2.0a0, xorg-libxrandr >=1.5.5,<2.0a0, xorg-libxrender >=0.9.12,<0.10.0a0 |
| gxx_impl_linux-64 | 16.2.0 | h0d273dc_7 | emacs/31.1, gcc/16.2.0 | gcc_impl_linux-64 16.2.0 h9891192_7, libstdcxx-devel_linux-64 16.2.0 h86e191b_107, sysroot_linux-64, tzdata |
| gxx_linux-64 | 16.2.0 | h23aca61_2 | emacs/31.1, gcc/16.2.0 | gxx_impl_linux-64 16.2.0.*, gcc_linux-64 ==16.2.0 h0ab548f_2, binutils_linux-64, sysroot_linux-64 |
| harfbuzz | 14.6.0 | ha770c72_2 | emacs/31.1 | libharfbuzz-devel 14.6.0 h23af247_2 |
| hicolor-icon-theme | 0.17 | ha770c72_3 | emacs/31.1 | 无 |
| icu | 78.3 | py310h44b86e0_2 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libstdcxx >=14, libgcc >=14 |
| jq | 1.8.2 | h280c20c_1 | jq/1.8.2 | oniguruma 6.9.*, libgcc >=14, __glibc >=2.17,<3.0.a0, oniguruma >=6.9.10,<6.10.0a0 |
| kernel-headers_linux-64 | 4.18.0 | he073ed8_9 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | 无 |
| keyutils | 1.6.3 | h7cc23a3_1 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| krb5 | 1.22.2 | hbc21106_2 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, keyutils >=1.6.3,<2.0a0, libedit >=3.1.20250104,<3.2.0a0, libedit >=3.1.20250104,<4.0a0, libgcc >=15, libstdcxx >=15, openssl >=3.5.7,<4.0a0 |
| lcms2 | 2.19.1 | h9073bf1_3 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libjpeg-turbo >=3.2.0,<4.0a0, libtiff >=4.7.2,<4.8.0a0 |
| ld_impl_linux-64 | 2.46.1 | default_hbd61a6d_103 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | __glibc >=2.17,<3.0.a0, zstd >=1.5.7,<1.6.0a0 |
| lerc | 4.2.0 | hdb68285_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libstdcxx >=14 |
| libcap | 2.78 | h084b8d7_1 | zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libcups | 2.3.3 | h7a8fb5f_6 | emacs/31.1 | __glibc >=2.17,<3.0.a0, krb5 >=1.22.2,<1.23.0a0, libgcc >=14, libstdcxx >=14, libzlib >=1.3.1,<2.0a0 |
| libcurl | 8.23.0 | ha042cf0_0 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, krb5 >=1.22.2,<1.23.0a0, libgcc >=15, libnghttp2 >=1.68.1,<2.0a0, libpsl >=0.23.1,<0.24.0a0, libssh2 >=1.11.1,<2.0a0, libzlib >=1.3.2,<2.0a0, openssl >=3.5.9,<4.0a0, zstd >=1.5.7,<1.6.0a0 |
| libdeflate | 1.25 | hd45a770_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libdrm | 2.4.129 | h7cc23a3_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libpciaccess >=0.19,<0.20.0a0 |
| libedit | 3.1.20260512 | pl5321h373387f_0 | emacs/31.1, git/2.56.0 | ncurses, __glibc >=2.17,<3.0.a0, libgcc >=14, ncurses >=6.6,<7.0a0 |
| libegl | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libglvnd 1.7.0 ha4b6fd6_5 |
| libegl-devel | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libegl 1.7.0 ha4b6fd6_5, libgl-devel 1.7.0 ha4b6fd6_5, xorg-libx11 |
| libev | 4.33 | h280c20c_3 | emacs/31.1, git/2.56.0 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| libexpat | 2.8.5 | hd2095e1_0 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| libffi | 3.7.0 | h81df57d_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| libfreetype | 2.14.3 | ha770c72_2 | emacs/31.1 | libfreetype6 >=2.14.3 |
| libfreetype6 | 2.14.3 | h5e6c136_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libpng >=1.6.58,<1.7.0a0, libzlib >=1.3.2,<2.0a0 |
| libgcc | 16.2.0 | ha9f2e26_7 | emacs/31.1, fd/10.5.0, gcc/16.2.0, git/2.56.0, jq/1.8.2, modules/5.7.0, ripgrep/15.2.0, starship/1.27.0, zoxide/0.10.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, _openmp_mutex >=4.5 |
| libgcc-devel_linux-64 | 16.2.0 | he3ce08f_107 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | __unix |
| libgcc-ng | 16.2.0 | h69a702a_7 | emacs/31.1, zsh/5.9.2 | libgcc 16.2.0 ha9f2e26_7 |
| libgl | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libglvnd 1.7.0 ha4b6fd6_5, libglx 1.7.0 ha4b6fd6_5 |
| libgl-devel | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgl 1.7.0 ha4b6fd6_5, libglx-devel 1.7.0 ha4b6fd6_5 |
| libglib | 2.90.0 | h569388d_0 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0, libiconv >=1.18,<2.0a0, pcre2 >=10.47,<10.48.0a0, libffi >=3.7.0,<3.8.0a0, libzlib >=1.3.2,<2.0a0 |
| libglvnd | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0 |
| libglx | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libglvnd 1.7.0 ha4b6fd6_5, xorg-libx11 >=1.8.13,<2.0a0 |
| libglx-devel | 1.7.0 | ha4b6fd6_5 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libglx 1.7.0 ha4b6fd6_5, xorg-libx11 >=1.8.13,<2.0a0, xorg-xorgproto |
| libgomp | 16.2.0 | he0feb66_7 | emacs/31.1, fd/10.5.0, gcc/16.2.0, git/2.56.0, jq/1.8.2, modules/5.7.0, ripgrep/15.2.0, starship/1.27.0, zoxide/0.10.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0 |
| libharfbuzz | 14.6.0 | h23af247_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, cairo >=1.18.6,<2.0a0, graphite2 >=1.3.15,<2.0a0, icu >=78.3,<79.0a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, libgcc >=15, libglib >=2.90.0,<3.0a0, libpng >=1.6.59,<1.7.0a0, libstdcxx >=15, libzlib >=1.3.2,<2.0a0 |
| libharfbuzz-devel | 14.6.0 | h23af247_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, cairo >=1.18.6,<2.0a0, freetype, graphite2 >=1.3.15,<2.0a0, icu >=78.3,<79.0a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, libgcc >=15, libglib >=2.90.0,<3.0a0, libharfbuzz 14.6.0 h23af247_2, libpng >=1.6.59,<1.7.0a0, libstdcxx >=15, libzlib >=1.3.2,<2.0a0 |
| libiconv | 1.18 | h0cb94f2_3 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| libidn2 | 2.3.8 | hfac485b_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libunistring >=0,<1.0a0 |
| libjpeg-turbo | 3.2.0 | hb03c661_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libltdl | 2.4.3a | h5888daf_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13 |
| liblzma | 5.8.3 | hb03c661_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libmpdec | 4.0.0 | hb03c661_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libnghttp2 | 1.68.1 | h74cf4be_1 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, c-ares >=1.34.8,<2.0a0, libev >=4.33,<4.34.0a0, libev >=4.33,<5.0a0, libgcc >=15, libstdcxx >=15, libzlib >=1.3.2,<2.0a0, openssl >=3.5.7,<4.0a0 |
| libpango | 1.58.2 | hce4e988_3 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, fontconfig >=2.18.3,<3.0a0, fonts-conda-ecosystem, cairo >=1.18.6,<2.0a0, fribidi >=1.0.17,<2.0a0, libglib >=2.90.0,<3.0a0, libharfbuzz >=14.6.0 |
| libpango-devel | 1.58.2 | h317d9d0_3 | emacs/31.1 | libpango ==1.58.2 hce4e988_3, freetype, libharfbuzz-devel, libgcc >=15, __glibc >=2.17,<3.0.a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, fontconfig >=2.18.3,<3.0a0, fonts-conda-ecosystem, cairo >=1.18.6,<2.0a0, fribidi >=1.0.17,<2.0a0, libglib >=2.90.0,<3.0a0, libharfbuzz >=14.6.0 |
| libpciaccess | 0.19 | hb03c661_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libpng | 1.6.59 | h922cc85_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, libzlib >=1.3.2,<2.0a0 |
| libpsl | 0.23.1 | hd9e3e90_1 | emacs/31.1, git/2.56.0 | libstdcxx >=15, libgcc >=15, __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0 |
| libpython | 3.13.16 | hd51c5da_102_cp313 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| librsvg | 2.62.4 | ha427ee3_0 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0, libglib >=2.90.0,<3.0a0, pango >=1.58.2,<2.0a0, fontconfig >=2.18.3,<3.0a0, fonts-conda-ecosystem, libxml2-16 >=2.15.4, cairo >=1.18.6,<2.0a0, libharfbuzz >=14.5.0, gdk-pixbuf >=2.44.8,<3.0a0 |
| libsanitizer | 16.2.0 | h3048135_7 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | __glibc >=2.17,<3.0.a0, libgcc >=16.2.0, libstdcxx >=16.2.0 |
| libsqlite | 3.54.1 | h13e7031_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0, libgcc >=15, libzlib >=1.3.2,<2.0a0 |
| libssh2 | 1.11.1 | h6154650_1 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libgcc >=14, libzlib >=1.3.2,<2.0a0, openssl >=3.5.7,<4.0a0 |
| libstdcxx | 16.2.0 | h934c35e_7 | emacs/31.1, gcc/16.2.0, git/2.56.0, modules/5.7.0 | __glibc >=2.17,<3.0.a0, libgcc 16.2.0 ha9f2e26_7 |
| libstdcxx-devel_linux-64 | 16.2.0 | h86e191b_107 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | __unix |
| libstdcxx-ng | 16.2.0 | hdf11a46_7 | emacs/31.1 | libstdcxx 16.2.0 h934c35e_7 |
| libtasn1 | 4.21.0 | hb03c661_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libtiff | 4.7.2 | hcc2c06a_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, lerc >=4.2.0,<5.0a0, libdeflate >=1.25,<1.26.0a0, libgcc >=15, libjpeg-turbo >=3.2.0,<4.0a0, liblzma >=5.8.3,<6.0a0, libstdcxx >=15, libwebp-base >=1.6.0,<2.0a0, libzlib >=1.3.2,<2.0a0, zstd >=1.5.7,<1.6.0a0 |
| libtool | 2.5.4 | h5888daf_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13, libltdl 2.4.3a h5888daf_0 |
| libtree-sitter | 0.27.1 | hebe6cf0_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| libunistring | 0.9.10 | h7f98852_0 | emacs/31.1 | libgcc-ng >=9.3.0 |
| libuuid | 2.42.4 | hcfc3c73_0 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| libuv | 1.52.1 | h280c20c_1 | emacs/31.1 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| libvterm | 0.3.3 | pl5321h8c9361a_3 | emacs/31.1 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| libwebp | 1.6.0 | hb3daedd_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, giflib >=6.1.3,<6.2.0a0, libgcc >=15, libjpeg-turbo >=3.2.0,<4.0a0, libpng >=1.6.58,<1.7.0a0, libtiff >=4.7.2,<4.8.0a0, libwebp-base 1.6.0.*, libwebp-base >=1.6.0,<2.0a0 |
| libwebp-base | 1.6.0 | hd42ef1d_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| libxcb | 1.17.0 | hb83e432_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, pthread-stubs, xorg-libxau >=1.0.12,<2.0a0, xorg-libxdmcp >=1.1.5,<2.0a0 |
| libxcrypt | 4.4.38 | h280c20c_0 | emacs/31.1, git/2.56.0 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| libxkbcommon | 1.13.2 | h51789e4_1 | emacs/31.1 | xkeyboard-config, libstdcxx >=14, libgcc >=14, __glibc >=2.17,<3.0.a0, libxcb >=1.17.0,<2.0a0, xorg-libxau >=1.0.12,<2.0a0, libxml2, libxml2-16 >=2.14.6 |
| libxml2 | 2.15.4 | h7df9aa5_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0, libgcc >=15, libiconv >=1.18,<2.0a0, liblzma >=5.8.3,<6.0a0, libxml2-16 2.15.4 hf3af7cc_1, libzlib >=1.3.2,<2.0a0 |
| libxml2-16 | 2.15.4 | hf3af7cc_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0, libgcc >=15, libiconv >=1.18,<2.0a0, liblzma >=5.8.3,<6.0a0, libzlib >=1.3.2,<2.0a0 |
| libxml2-devel | 2.15.4 | h7df9aa5_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0, libgcc >=15, libiconv >=1.18,<2.0a0, liblzma >=5.8.3,<6.0a0, libxml2 2.15.4 h7df9aa5_1, libxml2-16 2.15.4 hf3af7cc_1, libzlib >=1.3.2,<2.0a0 |
| libzlib | 1.3.2 | h25fd6f3_3 | emacs/31.1, gcc/16.2.0, git/2.56.0, modules/5.7.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0 |
| m4 | 1.4.21 | hb03c661_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| make | 4.4.1 | h1114479_4 | emacs/31.1, modules/5.7.0 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| ncurses | 6.6 | hdb14827_1 | emacs/31.1, git/2.56.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| nettle | 3.10.1 | h5ef0d04_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, gmp >=6.3.0,<7.0a0 |
| nspr | 4.40 | h29cc59b_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libstdcxx >=14 |
| nss | 3.118 | h445c969_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libsqlite >=3.51.0,<4.0a0, libstdcxx >=14, libzlib >=1.3.1,<2.0a0, nspr >=4.38,<5.0a0 |
| oniguruma | 6.9.10 | hebe6cf0_1 | jq/1.8.2 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| openjpeg | 2.5.4 | heb1ab33_2 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0, libstdcxx >=15, libtiff >=4.7.2,<4.8.0a0, libzlib >=1.3.2,<2.0a0, libpng >=1.6.58,<1.7.0a0 |
| openssl | 3.6.5 | h781a0a9_0 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, ca-certificates, libgcc >=15 |
| p11-kit | 0.26.5 | h8d769aa_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libffi >=3.7.0,<3.8.0a0, libgcc >=15, libtasn1 >=4.21.0,<5.0a0 |
| packaging | 26.3 | pyhc364b38_0 | emacs/31.1 | python >=3.9, python |
| pango | 1.58.2 | h2f58602_3 | emacs/31.1 | libpango-devel ==1.58.2 h317d9d0_3 |
| pcre2 | 10.47 | h8b3dc9c_1 | emacs/31.1, git/2.56.0, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, bzip2 >=1.0.8,<2.0a0, libgcc >=15, libzlib >=1.3.2,<2.0a0 |
| perl | 5.32.1 | 10_h7cc23a3_perl5 | emacs/31.1, git/2.56.0 | __glibc >=2.17,<3.0.a0, libgcc >=15, libxcrypt >=4.4.38 |
| pixman | 0.46.4 | h54a6638_3 | emacs/31.1 | libstdcxx >=14, libgcc >=14, __glibc >=2.17,<3.0.a0 |
| pkg-config | 0.29.2 | h1114479_1013 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| poppler | 26.09.0 | h0b47b50_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, cairo >=1.18.4,<2.0a0, fontconfig >=2.18.3,<3.0a0, fonts-conda-ecosystem, lcms2 >=2.19.1,<3.0a0, libcurl >=8.22.0,<9.0a0, libegl >=1.7.0,<2.0a0, libfreetype >=2.14.3, libfreetype6 >=2.14.3, libgcc >=15, libgl >=1.7.0,<2.0a0, libglib >=2.88.3,<3.0a0, libharfbuzz >=14.4.0, libiconv >=1.18,<2.0a0, libjpeg-turbo >=3.2.0,<4.0a0, libpng >=1.6.58,<1.7.0a0, libstdcxx >=15, libtiff >=4.7.2,<4.8.0a0, libzlib >=1.3.2,<2.0a0, nspr >=4.40,<5.0a0, nss >=3.118,<4.0a0, openjpeg >=2.5.4,<3.0a0, poppler-data, xorg-libxscrnsaver >=1.2.4,<2.0a0, xorg-libxtst >=1.2.5,<2.0a0 |
| poppler-data | 0.4.12 | hd8ed1ab_0 | emacs/31.1 | 无 |
| pthread-stubs | 0.4 | h7cc23a3_1004 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| python | 3.13.16 | hf47f18c_102_cp313 | emacs/31.1 | __glibc >=2.17,<3.0.a0, bzip2 >=1.0.8,<2.0a0, ld_impl_linux-64 >=2.36.1, libexpat >=2.8.5,<3.0a0, libffi >=3.7.0,<3.8.0a0, libgcc >=15, liblzma >=5.8.3,<6.0a0, libmpdec >=4.0.0,<5.0a0, libpython 3.13.16 hd51c5da_102_cp313, libsqlite >=3.54.0,<4.0a0, libuuid >=2.42.4,<3.0a0, libzlib >=1.3.2,<2.0a0, ncurses >=6.6,<7.0a0, openssl >=3.5.9,<4.0a0, python_abi 3.13.* *_cp313, readline >=8.3,<9.0a0, tk >=8.6.13,<8.7.0a0, tzdata |
| python_abi | 3.13 | 9_cp313 | emacs/31.1 | 无 |
| readline | 8.3 | hd6e31c0_1 | emacs/31.1, zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgcc >=15, ncurses >=6.6,<7.0a0 |
| rhash | 1.4.6 | hb03c661_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14 |
| ripgrep | 15.2.0 | hf19af3b_1 | ripgrep/15.2.0 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| sqlite | 3.54.1 | h9ffa6c4_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, icu >=78.3,<79.0a0, libgcc >=15, libsqlite 3.54.1 h13e7031_0, libzlib >=1.3.2,<2.0a0, ncurses >=6.6,<7.0a0, readline >=8.3,<9.0a0 |
| starship | 1.27.0 | hf473dc7_0 | starship/1.27.0 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| sysroot_linux-64 | 2.28 | h4ee821c_9 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | __glibc >=2.28, kernel-headers_linux-64 4.18.0 he073ed8_9, tzdata |
| texinfo | 7.2 | pl5321haa1a288_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13, ncurses >=6.5,<7.0a0, perl >=5.32.1,<5.33.0a0 *_perl5 |
| tk | 8.6.13 | noxft_h1df4ec4_4 | emacs/31.1, modules/5.7.0 | libgcc >=15, __glibc >=2.17,<3.0.a0, libzlib >=1.3.2,<2.0a0 |
| tzdata | 2026c | h151e31d_0 | emacs/31.1, gcc/16.2.0, modules/5.7.0 | 无 |
| wayland | 1.26.0 | hc1c935e_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libexpat >=2.8.1,<3.0a0, libffi >=3.7.0,<3.8.0a0, libgcc >=15, libstdcxx >=15 |
| xkeyboard-config | 2.48 | h280c20c_0 | emacs/31.1 | libgcc >=14, __glibc >=2.17,<3.0.a0, xorg-libx11 >=1.8.13,<2.0a0 |
| xorg-libice | 1.1.2 | h280c20c_0 | emacs/31.1 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| xorg-libsm | 1.2.6 | h0d788c3_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, xorg-libice >=1.1.2,<2.0a0, libuuid >=2.42.2,<3.0a0 |
| xorg-libx11 | 1.8.13 | he1eb515_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libxcb >=1.17.0,<2.0a0 |
| xorg-libxau | 1.0.12 | h7cc23a3_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| xorg-libxcomposite | 0.4.7 | hb03c661_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, xorg-libx11 >=1.8.12,<2.0a0, xorg-libxfixes >=6.0.2,<7.0a0 |
| xorg-libxcursor | 1.2.3 | hb9d3cd8_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13, xorg-libx11 >=1.8.10,<2.0a0, xorg-libxfixes >=6.0.1,<7.0a0, xorg-libxrender >=0.9.11,<0.10.0a0 |
| xorg-libxdamage | 1.1.6 | hb9d3cd8_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13, xorg-libx11 >=1.8.10,<2.0a0, xorg-libxext >=1.3.6,<2.0a0, xorg-libxfixes >=6.0.1,<7.0a0 |
| xorg-libxdmcp | 1.1.5 | h7cc23a3_2 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15 |
| xorg-libxext | 1.3.7 | h7cc23a3_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, xorg-libx11 >=1.8.13,<2.0a0 |
| xorg-libxfixes | 6.0.2 | h7cc23a3_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, xorg-libx11 >=1.8.13,<2.0a0 |
| xorg-libxi | 1.8.3 | h7cc23a3_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, xorg-libx11 >=1.8.13,<2.0a0, xorg-libxext >=1.3.7,<2.0a0, xorg-libxfixes >=6.0.2,<7.0a0 |
| xorg-libxinerama | 1.1.6 | hecca717_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, libstdcxx >=14, xorg-libx11 >=1.8.12,<2.0a0, xorg-libxext >=1.3.6,<2.0a0 |
| xorg-libxrandr | 1.5.5 | h7cc23a3_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, xorg-libx11 >=1.8.13,<2.0a0, xorg-libxext >=1.3.7,<2.0a0, xorg-libxrender >=0.9.12,<0.10.0a0 |
| xorg-libxrender | 0.9.12 | hb03c661_1 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, xorg-libx11 >=1.8.13,<2.0a0 |
| xorg-libxscrnsaver | 1.2.4 | hb9d3cd8_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=13, xorg-libx11 >=1.8.10,<2.0a0, xorg-libxext >=1.3.6,<2.0a0 |
| xorg-libxtst | 1.2.6 | h7cc23a3_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=15, xorg-libx11 >=1.8.13,<2.0a0, xorg-libxext >=1.3.7,<2.0a0, xorg-libxi >=1.8.3,<2.0a0 |
| xorg-libxxf86vm | 1.1.7 | hb03c661_0 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libgcc >=14, xorg-libx11 >=1.8.12,<2.0a0, xorg-libxext >=1.3.6,<2.0a0 |
| xorg-xorgproto | 2025.1 | hebe6cf0_3 | emacs/31.1 | libgcc >=15, __glibc >=2.17,<3.0.a0 |
| zlib | 1.3.2 | h25fd6f3_3 | emacs/31.1 | __glibc >=2.17,<3.0.a0, libzlib 1.3.2 h25fd6f3_3 |
| zoxide | 0.10.0 | hb17b654_0 | zoxide/0.10.0 | libgcc >=14, __glibc >=2.17,<3.0.a0 |
| zsh | 5.9.2 | he5de814_0 | zsh/5.9.2 | __glibc >=2.17,<3.0.a0, libgcc >=15, libcap >=2.78,<2.79.0a0, pcre2 >=10.47,<10.48.0a0, ncurses >=6.6,<7.0a0, gdbm >=1.18,<1.19.0a0 |
| zstd | 1.5.7 | hb78ec9c_7 | emacs/31.1, gcc/16.2.0, git/2.56.0, modules/5.7.0 | __glibc >=2.17,<3.0.a0, libzlib >=1.3.2,<2.0a0 |


</details>

<details>
<summary>9.6 Mac：Software 项目与旧全局 Pixi 环境的实际 Conda 包</summary>

按“包名 + 版本 + build”合并，共 340 条。环境列表示实际归属；同名包不同 build 不合并。依赖为 Conda 元数据中的 MatchSpec，`__glibc` 等属于宿主虚拟包要求。

| 包 | 版本 | build | 所属环境 | 声明依赖 |
| --- | --- | --- | --- | --- |
| _openmp_mutex | 4.5 | 7_kmp_llvm | Software/pyomp, ~/.pixi/envs/default | llvm-openmp >=9.0.1 |
| _python_abi3_support | 1.0 | hd8ed1ab_2 | Software/pyomp, ~/.pixi/envs/default | cpython, python-gil |
| aiobotocore | 2.25.2 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, aiohttp >=3.9.2,<4.0.0, aioitertools >=0.5.1,<1.0.0, botocore >=1.40.46,<1.40.71, python-dateutil >=2.1,<3.0.0, jmespath >=0.7.1,<2.0.0, multidict >=6.0.0,<7.0.0, wrapt >=1.10.10,<2.0.0, python |
| aiohappyeyeballs | 2.6.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| aiohttp | 3.13.2 | py312he52fbff_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aiohappyeyeballs >=2.5.0, aiosignal >=1.4.0, attrs >=17.3.0, frozenlist >=1.1.1, multidict >=4.5,<7.0, propcache >=0.2.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312, yarl >=1.17.0,<2.0 |
| aioitertools | 0.12.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, typing_extensions >=4.0 |
| aiosignal | 1.4.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | frozenlist >=1.1.0, python >=3.9, typing_extensions >=4.2 |
| anyio | 4.12.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | exceptiongroup >=1.0.2, idna >=2.8, python >=3.10, typing_extensions >=4.5, python |
| appnope | 0.1.4 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| argon2-cffi | 25.1.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | argon2-cffi-bindings, python >=3.9, typing-extensions |
| argon2-cffi-bindings | 25.1.0 | py312h4409184_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, cffi >=1.0.1, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| arrow | 1.4.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python-dateutil >=2.7.0, python-tzdata, python |
| astroid | 4.0.2 | py312h81bd7bf_0 | ~/.pixi/envs/default | python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| astropy | 7.2.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | aiohttp, astropy-base >=7.2.0,<7.2.1.0a0, beautifulsoup4 >=4.9.3, bleach >=3.2.1, bottleneck >=1.3.3, certifi >=2022.6.15.1, dask-core >=2024.8.0, fsspec >=2023.4.0, h5py >=3.9.0, html5lib >=1.1, ipydatagrid >=1.1.13, ipykernel >=6.16.0, ipython >=8.0.0, ipywidgets >=7.7.3, jplephem >=2.17.0, matplotlib-base >=3.8.0, mpmath >=1.2.1, narwhals >=1.42.0, pandas >=2.0, pyarrow >=14.0.2, python >=3.11, pytz >=2016.10, s3fs >=2023.4.0, scipy >=1.9.2, sortedcontainers >=2.1.0, uncompresspy >=0.4.0 |
| astropy-base | 7.2.0 | py312ha11c99a_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, astropy-iers-data >=0.2025.10.27.0.39.10, numpy >=1.23,<3, numpy >=1.24, packaging >=22.0.0, pyerfa >=2.0.1.1, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312, pyyaml >=6.0.0 |
| astropy-iers-data | 0.2025.12.1.0.45.12 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| asttokens | 3.0.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| async-lru | 2.0.5 | pyh29332c3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, typing_extensions >=4.0.0, python |
| attrs | 25.4.0 | pyh71513ae_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| aws-c-auth | 0.9.1 | h8818502_7 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-http >=0.10.7,<0.10.8.0a0, aws-c-common >=0.12.5,<0.12.6.0a0, aws-c-cal >=0.9.10,<0.9.11.0a0, aws-c-sdkutils >=0.2.4,<0.2.5.0a0, aws-c-io >=0.23.3,<0.23.4.0a0 |
| aws-c-cal | 0.9.10 | hca30140_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-c-common | 0.12.5 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| aws-c-compression | 0.3.1 | h61d5560_8 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-c-event-stream | 0.5.6 | h18584fc_6 | Software/pyomp, ~/.pixi/envs/default | libcxx >=19, __osx >=11.0, aws-checksums >=0.2.7,<0.2.8.0a0, aws-c-io >=0.23.3,<0.23.4.0a0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-c-http | 0.10.7 | hcd69b29_4 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-compression >=0.3.1,<0.3.2.0a0, aws-c-common >=0.12.5,<0.12.6.0a0, aws-c-cal >=0.9.10,<0.9.11.0a0, aws-c-io >=0.23.3,<0.23.4.0a0 |
| aws-c-io | 0.23.3 | h9710c81_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-cal >=0.9.10,<0.9.11.0a0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-c-mqtt | 0.13.3 | ha255ef3_10 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-common >=0.12.5,<0.12.6.0a0, aws-c-io >=0.23.3,<0.23.4.0a0, aws-c-http >=0.10.7,<0.10.8.0a0 |
| aws-c-s3 | 0.10.1 | hd860258_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-http >=0.10.7,<0.10.8.0a0, aws-checksums >=0.2.7,<0.2.8.0a0, aws-c-cal >=0.9.10,<0.9.11.0a0, aws-c-auth >=0.9.1,<0.9.2.0a0, aws-c-common >=0.12.5,<0.12.6.0a0, aws-c-io >=0.23.3,<0.23.4.0a0 |
| aws-c-sdkutils | 0.2.4 | h61d5560_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-checksums | 0.2.7 | h61d5560_4 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-c-common >=0.12.5,<0.12.6.0a0 |
| aws-crt-cpp | 0.35.2 | h5596a46_4 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, aws-c-s3 >=0.10.1,<0.10.2.0a0, aws-c-mqtt >=0.13.3,<0.13.4.0a0, aws-c-common >=0.12.5,<0.12.6.0a0, aws-c-cal >=0.9.10,<0.9.11.0a0, aws-c-sdkutils >=0.2.4,<0.2.5.0a0, aws-c-auth >=0.9.1,<0.9.2.0a0, aws-c-event-stream >=0.5.6,<0.5.7.0a0, aws-c-io >=0.23.3,<0.23.4.0a0, aws-c-http >=0.10.7,<0.10.8.0a0 |
| aws-sdk-cpp | 1.11.606 | h95becb6_7 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, aws-c-event-stream >=0.5.6,<0.5.7.0a0, aws-crt-cpp >=0.35.2,<0.35.3.0a0, libcurl >=8.17.0,<9.0a0, aws-c-common >=0.12.5,<0.12.6.0a0, libzlib >=1.3.1,<2.0a0 |
| azure-core-cpp | 1.16.1 | h88fedcc_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcurl >=8.14.1,<9.0a0, libcxx >=19, openssl >=3.5.4,<4.0a0 |
| azure-identity-cpp | 1.13.2 | h853621b_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, azure-core-cpp >=1.16.1,<1.16.2.0a0, libcxx >=19, openssl >=3.5.4,<4.0a0 |
| azure-storage-blobs-cpp | 12.15.0 | h10d327b_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, azure-core-cpp >=1.16.1,<1.16.2.0a0, azure-storage-common-cpp >=12.11.0,<12.11.1.0a0, libcxx >=19 |
| azure-storage-common-cpp | 12.11.0 | h7e4aa5d_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, azure-core-cpp >=1.16.1,<1.16.2.0a0, libcxx >=19, libxml2, libxml2-16 >=2.14.6, openssl >=3.5.4,<4.0a0 |
| azure-storage-files-datalake-cpp | 12.13.0 | hb288d13_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, azure-core-cpp >=1.16.1,<1.16.2.0a0, azure-storage-blobs-cpp >=12.15.0,<12.15.1.0a0, azure-storage-common-cpp >=12.11.0,<12.11.1.0a0, libcxx >=19 |
| babel | 2.17.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, pytz >=2015.7 |
| beautifulsoup4 | 4.14.3 | pyha770c72_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, soupsieve >=1.2, typing-extensions |
| bleach | 6.3.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, webencodings, python |
| bleach-with-css | 6.3.0 | h5f6438b_0 | Software/pyomp, ~/.pixi/envs/default | bleach ==6.3.0 pyhcf101f3_0, tinycss2 |
| botocore | 1.40.70 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | jmespath >=0.7.1,<2.0.0, python >=3.10, python-dateutil >=2.1,<3.0.0, urllib3 >=1.25.4,!=2.2.0,<3 |
| bottleneck | 1.6.0 | np2py312h931d34d_3 | Software/pyomp, ~/.pixi/envs/default | numpy, python, python 3.12.* *_cpython, __osx >=11.0, python_abi 3.12.* *_cp312, numpy >=1.23,<3 |
| bqplot | 0.12.45 | pyhe01879c_0 | Software/pyomp, ~/.pixi/envs/default | ipywidgets >=7.6.0,<9, numpy >=1.10.4, pandas >=1.0.0,<3.0.0, python >=3.9, traitlets >=4.3.0,<6.0, traittypes >=0.0.6, python |
| brotli | 1.2.0 | h7d5ae5b_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, brotli-bin 1.2.0 hc919400_1, libbrotlidec 1.2.0 hc919400_1, libbrotlienc 1.2.0 hc919400_1 |
| brotli-bin | 1.2.0 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libbrotlidec 1.2.0 hc919400_1, libbrotlienc 1.2.0 hc919400_1 |
| brotli-python | 1.2.0 | py312h0dfefe5_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| bzip2 | 1.0.8 | hd037594_8 | Software/pyomp, Software/unrpa, ~/.pixi/envs/default | __osx >=11.0 |
| bzip2 | 1.0.8 | hd037594_9 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| c-ares | 1.34.5 | h5505292_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| ca-certificates | 2025.11.12 | hbd8a1cb_0 | Software/pyomp, ~/.pixi/envs/default | __unix |
| ca-certificates | 2026.1.4 | hbd8a1cb_0 | Software/unrpa | __unix |
| ca-certificates | 2026.5.20 | hbd8a1cb_0 | ~/.pixi/envs/openpyxl | __unix |
| cached-property | 1.5.2 | hd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | cached_property >=1.5.2,<1.5.3.0a0 |
| cached_property | 1.5.2 | pyha770c72_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.6 |
| certifi | 2025.11.12 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| cffi | 2.0.0 | py312h1b4d9a2_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libffi >=3.5.2,<3.6.0a0, pycparser, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| charset-normalizer | 3.4.4 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| click | 8.3.1 | pyh8f84b5b_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, __unix, python |
| cloudpickle | 3.1.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| colorama | 0.4.6 | pyhd8ed1ab_1 | ~/.pixi/envs/default | python >=3.9 |
| comm | 0.2.3 | pyhe01879c_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, python |
| contourpy | 1.3.3 | py312h84eede6_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, numpy >=1.25, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| cpython | 3.12.12 | py312hd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.12,<3.13.0a0, python_abi * *_cp312 |
| cycler | 0.12.1 | pyhcf101f3_2 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| dask-core | 2025.11.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, click >=8.1, cloudpickle >=3.0.0, fsspec >=2021.9.0, packaging >=20.0, partd >=1.4.0, pyyaml >=5.3.1, toolz >=0.10.0, importlib-metadata >=4.13.0, python |
| debugpy | 1.8.17 | py312h56d30c9_0 | Software/pyomp, ~/.pixi/envs/default | python, __osx >=11.0, python 3.12.* *_cpython, libcxx >=19, python_abi 3.12.* *_cp312 |
| decorator | 5.2.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| defusedxml | 0.7.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.6 |
| dill | 0.4.0 | pyhcf101f3_1 | ~/.pixi/envs/default | python >=3.10, python |
| et_xmlfile | 2.0.0 | pyhd8ed1ab_1 | ~/.pixi/envs/openpyxl | python >=3.9 |
| exceptiongroup | 1.3.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, typing_extensions >=4.6.0 |
| executing | 2.2.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| fonttools | 4.61.0 | py312h5748b74_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, brotli, munkres, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312, unicodedata2 >=15.1.0 |
| fqdn | 1.5.1 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | cached-property >=1.3.0, python >=3.9,<4 |
| freetype | 2.14.1 | hce30654_0 | Software/pyomp, ~/.pixi/envs/default | libfreetype 2.14.1 hce30654_0, libfreetype6 2.14.1 h6da58f4_0 |
| frozenlist | 1.7.0 | py312h512c567_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| fsspec | 2025.10.0 | pyhd8ed1ab_0 | Software/pyomp | python >=3.10 |
| fsspec | 2025.12.0 | pyhd8ed1ab_0 | ~/.pixi/envs/default | python >=3.10 |
| gast | 0.4.0 | pyh9f0ad1d_0 | Software/pyomp, ~/.pixi/envs/default | python |
| gflags | 2.2.2 | hf9b8971_1005 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=17 |
| glog | 0.7.1 | heb240a5_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, gflags >=2.2.2,<2.3.0a0, libcxx >=16 |
| h11 | 0.16.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, typing_extensions |
| h2 | 4.3.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, hyperframe >=6.1,<7, hpack >=4.1,<5, python |
| h5py | 3.15.1 | mpi_openmpi_py312hf76bcf3_1 | Software/pyomp | __osx >=11.0, cached-property, hdf5 >=1.14.6,<1.14.7.0a0 mpi_openmpi_*, mpi4py >=3.0, mpi4py >=4.1.1,<5.0a0, numpy >=1.23,<3, openmpi >=5.0.8,<6.0a0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| h5py | 3.15.1 | nompi_py312h4eecd6b_101 | ~/.pixi/envs/default | __osx >=11.0, cached-property, hdf5 >=1.14.6,<1.14.7.0a0, numpy >=1.23,<3, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| hdf5 | 1.14.6 | mpi_openmpi_h7c22107_3 | Software/pyomp | __osx >=11.0, libaec >=1.1.4,<2.0a0, libcurl >=8.14.1,<9.0a0, libcxx >=19, libgfortran, libgfortran5 >=14.3.0, libgfortran5 >=15.1.0, libzlib >=1.3.1,<2.0a0, openmpi >=5.0.8,<6.0a0, openssl >=3.5.1,<4.0a0 |
| hdf5 | 1.14.6 | nompi_hd3baa01_104 | ~/.pixi/envs/default | __osx >=11.0, libaec >=1.1.4,<2.0a0, libcurl >=8.17.0,<9.0a0, libcxx >=19, libgfortran, libgfortran5 >=14.3.0, libzlib >=1.3.1,<2.0a0, openssl >=3.5.4,<4.0a0 |
| hpack | 4.1.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| html5lib | 1.1 | pyhd8ed1ab_2 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, six >=1.9, webencodings |
| httpcore | 1.0.9 | pyh29332c3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, h11 >=0.16, h2 >=3,<5, sniffio 1.*, anyio >=4.0,<5.0, certifi, python |
| httpx | 0.28.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | anyio, certifi, httpcore 1.*, idna, python >=3.9 |
| hyperframe | 6.1.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| icu | 78.2 | h38cb7af_0 | Software/unrpa | __osx >=11.0 |
| icu | 78.3 | hef89b57_0 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| idna | 3.11 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| importlib-metadata | 8.7.0 | pyhe01879c_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, zipp >=3.20, python |
| importlib_resources | 6.5.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, zipp >=3.1.0 |
| ipydatagrid | 1.4.0 | pyhcf101f3_2 | Software/pyomp, ~/.pixi/envs/default | bqplot >=0.11.6, ipywidgets >=7.6,<9, pandas >=1.3.5, py2vega >=0.5, python >=3.10, python |
| ipykernel | 7.1.0 | pyh5552912_0 | Software/pyomp, ~/.pixi/envs/default | appnope, __osx, comm >=0.1.1, debugpy >=1.6.5, ipython >=7.23.1, jupyter_client >=8.0.0, jupyter_core >=4.12,!=5.0.*, matplotlib-inline >=0.1, nest-asyncio >=1.4, packaging >=22, psutil >=5.7, python >=3.10, pyzmq >=25, tornado >=6.2, traitlets >=5.4.0, python |
| ipython | 9.7.0 | pyh53cf698_0 | Software/pyomp | __unix, pexpect >4.3, decorator >=4.3.2, ipython_pygments_lexers >=1.0.0, jedi >=0.18.1, matplotlib-inline >=0.1.5, prompt-toolkit >=3.0.41,<3.1.0, pygments >=2.11.0, python >=3.11, stack_data >=0.6.0, traitlets >=5.13.0, typing_extensions >=4.6, python |
| ipython | 9.8.0 | pyh53cf698_0 | ~/.pixi/envs/default | __unix, pexpect >4.3, decorator >=4.3.2, ipython_pygments_lexers >=1.0.0, jedi >=0.18.1, matplotlib-inline >=0.1.5, prompt-toolkit >=3.0.41,<3.1.0, pygments >=2.11.0, python >=3.11, stack_data >=0.6.0, traitlets >=5.13.0, typing_extensions >=4.6, python |
| ipython_pygments_lexers | 1.1.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | pygments, python >=3.9 |
| ipywidgets | 8.1.8 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | comm >=0.1.3, ipython >=6.1.0, jupyterlab_widgets >=3.0.15,<3.1.0, python >=3.10, traitlets >=4.3.1, widgetsnbextension >=4.0.14,<4.1.0 |
| isoduration | 20.11.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | arrow >=0.15.0, python >=3.9 |
| isort | 7.0.0 | pyhd8ed1ab_0 | ~/.pixi/envs/default | importlib-metadata >=4.6.0, python >=3.10,<4.0 |
| jedi | 0.19.2 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | parso >=0.8.3,<0.9.0, python >=3.9 |
| jinja2 | 3.1.6 | pyhcf101f3_1 | Software/pyomp, ~/.pixi/envs/default | markupsafe >=2.0, python >=3.10, python |
| jmespath | 1.0.1 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| jplephem | 2.23 | pyha4b2019_0 | Software/pyomp, ~/.pixi/envs/default | numpy, python >=3.9 |
| json5 | 0.12.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| jsonpointer | 3.0.0 | py312h81bd7bf_2 | Software/pyomp, ~/.pixi/envs/default | python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| jsonschema | 4.25.1 | pyhe01879c_0 | Software/pyomp, ~/.pixi/envs/default | attrs >=22.2.0, jsonschema-specifications >=2023.3.6, python >=3.9, referencing >=0.28.4, rpds-py >=0.7.1, python |
| jsonschema-specifications | 2025.9.1 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, referencing >=0.31.0, python |
| jsonschema-with-format-nongpl | 4.25.1 | he01879c_0 | Software/pyomp, ~/.pixi/envs/default | jsonschema >=4.25.1,<4.25.2.0a0, fqdn, idna, isoduration, jsonpointer >1.13, rfc3339-validator, rfc3986-validator >0.1.0, rfc3987-syntax >=1.1.0, uri-template, webcolors >=24.6.0 |
| jupyter | 1.1.1 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | ipykernel, ipywidgets, jupyter_console, jupyterlab, nbconvert-core, notebook, python >=3.9 |
| jupyter-lsp | 2.3.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | importlib-metadata >=4.8.3, jupyter_server >=1.1.2, python >=3.10, python |
| jupyter_client | 8.6.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | importlib-metadata >=4.8.3, jupyter_core >=4.12,!=5.0.*, python >=3.9, python-dateutil >=2.8.2, pyzmq >=23.0, tornado >=6.2, traitlets >=5.3 |
| jupyter_console | 6.6.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | ipykernel >=6.14, ipython, jupyter_client >=7.0.0, jupyter_core >=4.12,!=5.0.*, prompt_toolkit >=3.0.30, pygments, python >=3.9, pyzmq >=17, traitlets >=5.4 |
| jupyter_core | 5.9.1 | pyhc90fa1f_0 | Software/pyomp, ~/.pixi/envs/default | __unix, python, platformdirs >=2.5, python >=3.10, traitlets >=5.3, python |
| jupyter_events | 0.12.0 | pyh29332c3_0 | Software/pyomp, ~/.pixi/envs/default | jsonschema-with-format-nongpl >=4.18.0, packaging, python >=3.9, python-json-logger >=2.0.4, pyyaml >=5.3, referencing, rfc3339-validator, rfc3986-validator >=0.1.1, traitlets >=5.3, python |
| jupyter_server | 2.17.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | anyio >=3.1.0, argon2-cffi >=21.1, jinja2 >=3.0.3, jupyter_client >=7.4.4, jupyter_core >=4.12,!=5.0.*, jupyter_events >=0.11.0, jupyter_server_terminals >=0.4.4, nbconvert-core >=6.4.4, nbformat >=5.3.0, overrides >=5.0, packaging >=22.0, prometheus_client >=0.9, python >=3.10, pyzmq >=24, send2trash >=1.8.2, terminado >=0.8.3, tornado >=6.2.0, traitlets >=5.6.0, websocket-client >=1.7, python |
| jupyter_server_terminals | 0.5.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, terminado >=0.8.3 |
| jupyterlab | 4.5.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | async-lru >=1.0.0, httpx >=0.25.0,<1, ipykernel >=6.5.0,!=6.30.0, jinja2 >=3.0.3, jupyter-lsp >=2.0.0, jupyter_core, jupyter_server >=2.4.0,<3, jupyterlab_server >=2.28.0,<3, notebook-shim >=0.2, packaging, python >=3.10, setuptools >=41.1.0, tomli >=1.2.2, tornado >=6.2.0, traitlets |
| jupyterlab_pygments | 0.3.0 | pyhd8ed1ab_2 | Software/pyomp, ~/.pixi/envs/default | pygments >=2.4.1,<3, python >=3.9 |
| jupyterlab_server | 2.28.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | babel >=2.10, jinja2 >=3.0.3, json5 >=0.9.0, jsonschema >=4.18, jupyter_server >=1.21,<3, packaging >=21.3, python >=3.10, requests >=2.31, python |
| jupyterlab_widgets | 3.0.16 | pyhcf101f3_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| jupytext | 1.18.1 | pyh80e38bb_0 | ~/.pixi/envs/default | markdown-it-py >=1.0, mdit-py-plugins, nbformat, packaging, python >=3.10, pyyaml, tomli |
| kiwisolver | 1.4.9 | py312hd8c8125_2 | Software/pyomp, ~/.pixi/envs/default | python, python 3.12.* *_cpython, libcxx >=19, __osx >=11.0, python_abi 3.12.* *_cp312 |
| krb5 | 1.21.3 | h237132a_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=16, libedit >=3.1.20191231,<3.2.0a0, libedit >=3.1.20191231,<4.0a0, openssl >=3.3.1,<4.0a0 |
| lark | 1.3.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| lcms2 | 2.17 | h7eeda09_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libjpeg-turbo >=3.0.0,<4.0a0, libtiff >=4.7.0,<4.8.0a0 |
| lerc | 4.0.0 | hd64df32_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=18 |
| libabseil | 20250512.1 | cxx17_hd41c47c_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=18 |
| libaec | 1.1.4 | h51d1e36_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=18 |
| libarrow | 22.0.0 | h4a3aeba_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, aws-crt-cpp >=0.35.2,<0.35.3.0a0, aws-sdk-cpp >=1.11.606,<1.11.607.0a0, azure-core-cpp >=1.16.1,<1.16.2.0a0, azure-identity-cpp >=1.13.2,<1.13.3.0a0, azure-storage-blobs-cpp >=12.15.0,<12.15.1.0a0, azure-storage-files-datalake-cpp >=12.13.0,<12.13.1.0a0, bzip2 >=1.0.8,<2.0a0, glog >=0.7.1,<0.8.0a0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libbrotlidec >=1.2.0,<1.3.0a0, libbrotlienc >=1.2.0,<1.3.0a0, libcxx >=19, libgoogle-cloud >=2.39.0,<2.40.0a0, libgoogle-cloud-storage >=2.39.0,<2.40.0a0, libopentelemetry-cpp >=1.21.0,<1.22.0a0, libprotobuf >=6.31.1,<6.31.2.0a0, libzlib >=1.3.1,<2.0a0, lz4-c >=1.10.0,<1.11.0a0, orc >=2.2.1,<2.2.2.0a0, snappy >=1.2.2,<1.3.0a0, zstd >=1.5.7,<1.6.0a0 |
| libarrow-acero | 22.0.0 | hc317990_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libarrow 22.0.0 h4a3aeba_4_cpu, libarrow-compute 22.0.0 h75845d1_4_cpu, libcxx >=19, libopentelemetry-cpp >=1.21.0,<1.22.0a0, libprotobuf >=6.31.1,<6.31.2.0a0 |
| libarrow-compute | 22.0.0 | h75845d1_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libarrow 22.0.0 h4a3aeba_4_cpu, libcxx >=19, libopentelemetry-cpp >=1.21.0,<1.22.0a0, libprotobuf >=6.31.1,<6.31.2.0a0, libre2-11 >=2025.8.12, libutf8proc >=2.11.0,<2.12.0a0, re2 |
| libarrow-dataset | 22.0.0 | hc317990_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libarrow 22.0.0 h4a3aeba_4_cpu, libarrow-acero 22.0.0 hc317990_4_cpu, libarrow-compute 22.0.0 h75845d1_4_cpu, libcxx >=19, libopentelemetry-cpp >=1.21.0,<1.22.0a0, libparquet 22.0.0 h0ac143b_4_cpu, libprotobuf >=6.31.1,<6.31.2.0a0 |
| libarrow-substrait | 22.0.0 | h144af7f_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libarrow 22.0.0 h4a3aeba_4_cpu, libarrow-acero 22.0.0 hc317990_4_cpu, libarrow-dataset 22.0.0 hc317990_4_cpu, libcxx >=19, libprotobuf >=6.31.1,<6.31.2.0a0 |
| libblas | 3.11.0 | 2_h51639a9_openblas | Software/pyomp | libopenblas >=0.3.30,<0.3.31.0a0, libopenblas >=0.3.30,<1.0a0 |
| libblas | 3.11.0 | 4_h51639a9_openblas | ~/.pixi/envs/default | libopenblas >=0.3.30,<0.3.31.0a0, libopenblas >=0.3.30,<1.0a0 |
| libbrotlicommon | 1.2.0 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libbrotlidec | 1.2.0 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libbrotlicommon 1.2.0 hc919400_1 |
| libbrotlienc | 1.2.0 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libbrotlicommon 1.2.0 hc919400_1 |
| libcblas | 3.11.0 | 2_hb0561ab_openblas | Software/pyomp | libblas 3.11.0 2_h51639a9_openblas |
| libcblas | 3.11.0 | 4_hb0561ab_openblas | ~/.pixi/envs/default | libblas 3.11.0 4_h51639a9_openblas |
| libcrc32c | 1.1.2 | hbdafb3b_0 | Software/pyomp, ~/.pixi/envs/default | libcxx >=11.1.0 |
| libcurl | 8.17.0 | hdece5d2_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, krb5 >=1.21.3,<1.22.0a0, libnghttp2 >=1.67.0,<2.0a0, libssh2 >=1.11.1,<2.0a0, libzlib >=1.3.1,<2.0a0, openssl >=3.5.4,<4.0a0, zstd >=1.5.7,<1.6.0a0 |
| libcxx | 21.1.6 | hf598326_0 | Software/pyomp | __osx >=11.0 |
| libcxx | 21.1.7 | hf598326_0 | ~/.pixi/envs/default | __osx >=11.0 |
| libdeflate | 1.25 | hc11a715_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libedit | 3.1.20250104 | pl5321hafb1f1b_0 | Software/pyomp, ~/.pixi/envs/default | ncurses, __osx >=11.0, ncurses >=6.5,<7.0a0 |
| libev | 4.33 | h93a5062_2 | Software/pyomp, ~/.pixi/envs/default | 无 |
| libevent | 2.1.12 | h2757513_1 | Software/pyomp, ~/.pixi/envs/default | openssl >=3.1.1,<4.0a0 |
| libexpat | 2.7.3 | haf25636_0 | Software/pyomp, Software/unrpa, ~/.pixi/envs/default | __osx >=11.0 |
| libexpat | 2.8.1 | hf6b4638_1 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| libfabric | 2.3.1 | hce30654_1 | Software/pyomp | libfabric1 2.3.1 hc919400_1 |
| libfabric1 | 2.3.1 | hc919400_1 | Software/pyomp | __osx >=11.0 |
| libffi | 3.5.2 | hcf2aa1b_0 | Software/unrpa, ~/.pixi/envs/openpyxl | __osx >=11.0 |
| libffi | 3.5.2 | he5f378a_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libfreetype | 2.14.1 | hce30654_0 | Software/pyomp, ~/.pixi/envs/default | libfreetype6 >=2.14.1 |
| libfreetype6 | 2.14.1 | h6da58f4_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libpng >=1.6.50,<1.7.0a0, libzlib >=1.3.1,<2.0a0 |
| libgcc | 15.2.0 | hcbb3090_14 | Software/pyomp, ~/.pixi/envs/default | _openmp_mutex |
| libgfortran | 15.2.0 | h07b0088_14 | Software/pyomp, ~/.pixi/envs/default | libgfortran5 15.2.0 hdae7583_14 |
| libgfortran5 | 15.2.0 | hdae7583_14 | Software/pyomp, ~/.pixi/envs/default | libgcc >=15.2.0 |
| libgoogle-cloud | 2.39.0 | head0a95_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libcurl >=8.14.1,<9.0a0, libcxx >=19, libgrpc >=1.73.1,<1.74.0a0, libprotobuf >=6.31.1,<6.31.2.0a0, openssl >=3.5.1,<4.0a0 |
| libgoogle-cloud-storage | 2.39.0 | hfa3a374_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil, libcrc32c >=1.1.2,<1.2.0a0, libcurl, libcxx >=19, libgoogle-cloud 2.39.0 head0a95_0, libzlib >=1.3.1,<2.0a0, openssl |
| libgrpc | 1.73.1 | h3063b79_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, c-ares >=1.34.5,<2.0a0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libcxx >=19, libprotobuf >=6.31.1,<6.31.2.0a0, libre2-11 >=2025.8.12, libzlib >=1.3.1,<2.0a0, openssl >=3.5.4,<4.0a0, re2 |
| libhwloc | 2.12.1 | default_h48b22c3_1002 | Software/pyomp | __osx >=11.0, libcxx >=19, libxml2, libxml2-16 >=2.14.6 |
| libiconv | 1.18 | h23cfdf5_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libjpeg-turbo | 3.1.2 | hc919400_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| liblapack | 3.11.0 | 2_hd9741b5_openblas | Software/pyomp | libblas 3.11.0 2_h51639a9_openblas |
| liblapack | 3.11.0 | 4_hd9741b5_openblas | ~/.pixi/envs/default | libblas 3.11.0 4_h51639a9_openblas |
| liblzma | 5.8.1 | h39f12f2_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| liblzma | 5.8.2 | h8088a28_0 | Software/unrpa | __osx >=11.0 |
| liblzma | 5.8.3 | h8088a28_0 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| libmpdec | 4.0.0 | h84a0fba_1 | Software/unrpa, ~/.pixi/envs/openpyxl | __osx >=11.0 |
| libnghttp2 | 1.67.0 | hc438710_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, c-ares >=1.34.5,<2.0a0, libcxx >=19, libev >=4.33,<4.34.0a0, libev >=4.33,<5.0a0, libzlib >=1.3.1,<2.0a0, openssl >=3.5.2,<4.0a0 |
| libopenblas | 0.3.30 | openmp_ha158390_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libgfortran, libgfortran5 >=14.3.0, llvm-openmp >=19.1.7 |
| libopentelemetry-cpp | 1.21.0 | he15edb5_1 | Software/pyomp, ~/.pixi/envs/default | libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libcurl >=8.14.1,<9.0a0, libgrpc >=1.73.1,<1.74.0a0, libopentelemetry-cpp-headers 1.21.0 hce30654_1, libprotobuf >=6.31.1,<6.31.2.0a0, libzlib >=1.3.1,<2.0a0, nlohmann_json, prometheus-cpp >=1.3.0,<1.4.0a0 |
| libopentelemetry-cpp-headers | 1.21.0 | hce30654_1 | Software/pyomp, ~/.pixi/envs/default | 无 |
| libparquet | 22.0.0 | h0ac143b_4_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libarrow 22.0.0 h4a3aeba_4_cpu, libcxx >=19, libopentelemetry-cpp >=1.21.0,<1.22.0a0, libprotobuf >=6.31.1,<6.31.2.0a0, libthrift >=0.22.0,<0.22.1.0a0, openssl >=3.5.4,<4.0a0 |
| libpmix | 5.0.8 | h3e7ebac_2 | Software/pyomp | __osx >=11.0, libevent >=2.1.12,<2.1.13.0a0, libhwloc >=2.12.1,<2.12.2.0a0, libzlib >=1.3.1,<2.0a0 |
| libpng | 1.6.51 | hfab5511_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |
| libprotobuf | 6.31.1 | h658db43_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libcxx >=19, libzlib >=1.3.1,<2.0a0 |
| libre2-11 | 2025.11.05 | h91c62da_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libabseil * cxx17*, libabseil >=20250512.1,<20250513.0a0, libcxx >=19 |
| libsodium | 1.0.20 | h99b78c6_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libsqlite | 3.51.1 | h9a5124b_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |
| libsqlite | 3.51.2 | h1ae2325_0 | Software/unrpa | __osx >=11.0, icu >=78.2,<79.0a0, libzlib >=1.3.1,<2.0a0 |
| libsqlite | 3.53.2 | h1ae2325_0 | ~/.pixi/envs/openpyxl | __osx >=11.0, icu >=78.3,<79.0a0, libzlib >=1.3.2,<2.0a0 |
| libssh2 | 1.11.1 | h1590b86_0 | Software/pyomp, ~/.pixi/envs/default | libzlib >=1.3.1,<2.0a0, openssl >=3.5.0,<4.0a0 |
| libthrift | 0.22.0 | h14a376c_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, libevent >=2.1.12,<2.1.13.0a0, libzlib >=1.3.1,<2.0a0, openssl >=3.5.1,<4.0a0 |
| libtiff | 4.7.1 | h4030677_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, lerc >=4.0.0,<5.0a0, libcxx >=19, libdeflate >=1.25,<1.26.0a0, libjpeg-turbo >=3.1.0,<4.0a0, liblzma >=5.8.1,<6.0a0, libwebp-base >=1.6.0,<2.0a0, libzlib >=1.3.1,<2.0a0, zstd >=1.5.7,<1.6.0a0 |
| libutf8proc | 2.11.2 | hd2415e0_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libwebp-base | 1.6.0 | h07db88b_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| libxcb | 1.17.0 | hdb1d25a_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, pthread-stubs, xorg-libxau >=1.0.11,<2.0a0, xorg-libxdmcp |
| libxml2 | 2.15.1 | hba2cd1d_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libiconv >=1.18,<2.0a0, liblzma >=5.8.1,<6.0a0, libxml2-16 2.15.1 h8eac4d7_0, libzlib >=1.3.1,<2.0a0 |
| libxml2-16 | 2.15.1 | h8eac4d7_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libiconv >=1.18,<2.0a0, liblzma >=5.8.1,<6.0a0, libzlib >=1.3.1,<2.0a0 |
| libzlib | 1.3.1 | h8359307_2 | Software/pyomp, Software/unrpa, ~/.pixi/envs/default | __osx >=11.0 |
| libzlib | 1.3.2 | h8088a28_2 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| llvm-openmp | 21.1.6 | h4a912ad_0 | Software/pyomp | __osx >=11.0 |
| llvm-openmp | 21.1.7 | h4a912ad_0 | ~/.pixi/envs/default | __osx >=11.0 |
| locket | 1.0.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=2.7,!=3.0.*,!=3.1.*,!=3.2.*,!=3.3.* |
| lz4-c | 1.10.0 | h286801f_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=18 |
| markdown-it-py | 4.0.0 | pyhd8ed1ab_0 | ~/.pixi/envs/default | mdurl >=0.1,<1, python >=3.10 |
| markupsafe | 3.0.3 | py312h5748b74_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| matplotlib | 3.10.8 | py312h1f38498_0 | Software/pyomp, ~/.pixi/envs/default | matplotlib-base >=3.10.8,<3.10.9.0a0, python >=3.12,<3.13.0a0, python_abi 3.12.* *_cp312, tornado >=5 |
| matplotlib-base | 3.10.8 | py312h605b88b_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, contourpy >=1.0.1, cycler >=0.10, fonttools >=4.22.0, freetype, kiwisolver >=1.3.1, libcxx >=19, libfreetype >=2.14.1, libfreetype6 >=2.14.1, numpy >=1.23, numpy >=1.23,<3, packaging >=20.0, pillow >=8, pyparsing >=2.3.1, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python-dateutil >=2.7, python_abi 3.12.* *_cp312, qhull >=2020.2,<2020.3.0a0 |
| matplotlib-inline | 0.2.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, traitlets |
| mccabe | 0.7.0 | pyhd8ed1ab_1 | ~/.pixi/envs/default | python >=3.9 |
| mdit-py-plugins | 0.5.0 | pyhd8ed1ab_0 | ~/.pixi/envs/default | markdown-it-py >=2.0.0,<5.0.0, python >=3.10 |
| mdurl | 0.1.2 | pyhd8ed1ab_1 | ~/.pixi/envs/default | python >=3.9 |
| mistune | 3.1.4 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, typing_extensions, python |
| mpi | 1.0.1 | openmpi | Software/pyomp | 无 |
| mpi4py | 4.1.1 | py312h11c5ce7_102 | Software/pyomp | python, openmpi >=4.1, python 3.12.* *_cpython, __osx >=11.0, python_abi 3.12.* *_cp312 |
| mpmath | 1.3.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| multidict | 6.6.3 | py312hdb8e49c_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| munkres | 1.1.4 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| narwhals | 2.13.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| nbclient | 0.10.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | jupyter_client >=6.1.12, jupyter_core >=4.12,!=5.0.*, nbformat >=5.1, python >=3.8, traitlets >=5.4 |
| nbconvert-core | 7.16.6 | pyhcf101f3_1 | Software/pyomp, ~/.pixi/envs/default | beautifulsoup4, bleach-with-css !=5.0.0, defusedxml, importlib-metadata >=3.6, jinja2 >=3.0, jupyter_core >=4.7, jupyterlab_pygments, markupsafe >=2.0, mistune >=2.0.3,<4, nbclient >=0.5.0, nbformat >=5.7, packaging, pandocfilters >=1.4.1, pygments >=2.4.1, python >=3.10, traitlets >=5.1, python |
| nbformat | 5.10.4 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | jsonschema >=2.6, jupyter_core >=4.12,!=5.0.*, python >=3.9, python-fastjsonschema >=2.15, traitlets >=5.1 |
| ncurses | 6.5 | h5e97a16_3 | Software/pyomp, Software/unrpa, ~/.pixi/envs/default | __osx >=11.0 |
| ncurses | 6.6 | h1d4f5a5_0 | ~/.pixi/envs/openpyxl | __osx >=11.0 |
| nest-asyncio | 1.6.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| nlohmann_json | 3.12.0 | h248ca61_1 | Software/pyomp, ~/.pixi/envs/default | 无 |
| notebook | 7.5.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | importlib_resources >=5.0, jupyter_server >=2.4.0,<3, jupyterlab >=4.5.0,<4.6, jupyterlab_server >=2.28.0,<3, notebook-shim >=0.2,<0.3, python >=3.10, tornado >=6.2.0, python |
| notebook-shim | 0.2.4 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | jupyter_server >=1.8,<3, python >=3.9 |
| numpy | 2.0.2 | py312h94ee1e1_1 | Software/pyomp | __osx >=11.0, libblas >=3.9.0,<4.0a0, libcblas >=3.9.0,<4.0a0, libcxx >=18, liblapack >=3.9.0,<4.0a0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| numpy | 2.3.5 | py312h85ea64e_0 | ~/.pixi/envs/default | python, __osx >=11.0, python 3.12.* *_cpython, libcxx >=19, libcblas >=3.9.0,<4.0a0, libblas >=3.9.0,<4.0a0, liblapack >=3.9.0,<4.0a0, python_abi 3.12.* *_cp312 |
| openjpeg | 2.5.4 | hbfb3c88_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, libpng >=1.6.50,<1.7.0a0, libtiff >=4.7.1,<4.8.0a0, libzlib >=1.3.1,<2.0a0 |
| openmpi | 5.0.8 | h65ea042_108 | Software/pyomp | mpi 1.0.* openmpi, libcxx >=19, libgfortran, libgfortran5 >=14.3.0, __osx >=11.0, libhwloc >=2.12.1,<2.12.2.0a0, libzlib >=1.3.1,<2.0a0, libfabric, libfabric1 >=1.14.0, libevent >=2.1.12,<2.1.13.0a0, libpmix >=5.0.8,<6.0a0 |
| openpyxl | 3.1.5 | py314hc627673_3 | ~/.pixi/envs/openpyxl | et_xmlfile, python >=3.14,<3.15.0a0, python >=3.14,<3.15.0a0 *_cp314t, python_abi 3.14.* *_cp314t |
| openssl | 3.6.0 | h5503f6c_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, ca-certificates |
| openssl | 3.6.1 | hd24854e_1 | Software/unrpa | __osx >=11.0, ca-certificates |
| openssl | 3.6.3 | hd24854e_0 | ~/.pixi/envs/openpyxl | __osx >=11.0, ca-certificates |
| orc | 2.2.1 | h4fd0076_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, libprotobuf >=6.31.1,<6.31.2.0a0, libzlib >=1.3.1,<2.0a0, lz4-c >=1.10.0,<1.11.0a0, snappy >=1.2.2,<1.3.0a0, tzdata, zstd >=1.5.7,<1.6.0a0 |
| overrides | 7.7.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, typing_utils |
| packaging | 25.0 | pyh29332c3_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.8, python |
| pandas | 2.3.3 | py312h5978115_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, numpy >=1.22.4, numpy >=1.23,<3, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python-dateutil >=2.8.2, python-tzdata >=2022.7, python_abi 3.12.* *_cp312, pytz >=2020.1 |
| pandocfilters | 1.5.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python !=3.0,!=3.1,!=3.2,!=3.3 |
| parso | 0.8.5 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| partd | 1.4.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | locket, python >=3.9, toolz |
| pexpect | 4.9.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | ptyprocess >=0.5, python >=3.9 |
| pillow | 12.0.0 | py312h95c711c_2 | Software/pyomp, ~/.pixi/envs/default | python, python 3.12.* *_cpython, __osx >=11.0, libjpeg-turbo >=3.1.2,<4.0a0, libxcb >=1.17.0,<2.0a0, libfreetype >=2.14.1, libfreetype6 >=2.14.1, zlib-ng >=2.3.1,<2.4.0a0, libtiff >=4.7.1,<4.8.0a0, libwebp-base >=1.6.0,<2.0a0, tk >=8.6.13,<8.7.0a0, lcms2 >=2.17,<3.0a0, openjpeg >=2.5.4,<3.0a0, python_abi 3.12.* *_cp312 |
| platformdirs | 4.5.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| prometheus-cpp | 1.3.0 | h0967b3e_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcurl >=8.10.1,<9.0a0, libcxx >=18, libzlib >=1.3.1,<2.0a0, zlib |
| prometheus_client | 0.23.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| prompt-toolkit | 3.0.52 | pyha770c72_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, wcwidth |
| prompt_toolkit | 3.0.52 | hd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | prompt-toolkit >=3.0.52,<3.0.53.0a0 |
| propcache | 0.3.1 | py312h998013c_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| psutil | 7.1.3 | py312h37e1c23_0 | Software/pyomp, ~/.pixi/envs/default | python, __osx >=11.0, python 3.12.* *_cpython, python_abi 3.12.* *_cp312 |
| pthread-stubs | 0.4 | hd74edd7_1002 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| ptyprocess | 0.7.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| pure_eval | 0.2.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| py2vega | 0.6.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | gast >=0.4,<0.5, python >=3.6 |
| pyarrow | 22.0.0 | py312h1f38498_0 | Software/pyomp, ~/.pixi/envs/default | libarrow-acero 22.0.0.*, libarrow-dataset 22.0.0.*, libarrow-substrait 22.0.0.*, libparquet 22.0.0.*, pyarrow-core 22.0.0 *_0_*, python >=3.12,<3.13.0a0, python_abi 3.12.* *_cp312 |
| pyarrow-core | 22.0.0 | py312hea229ce_0_cpu | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libarrow 22.0.0.* *cpu, libarrow-compute 22.0.0.* *cpu, libcxx >=18, libzlib >=1.3.1,<2.0a0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| pycparser | 2.22 | pyh29332c3_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, python |
| pyerfa | 2.0.1.5 | py310hbb12772_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, numpy >=1.21,<3, python |
| pygments | 2.19.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| pylint | 4.0.4 | pyhcf101f3_0 | ~/.pixi/envs/default | astroid >=4.0.2,<=4.1.0.dev0, colorama >=0.4.5, isort >=5,<8,!=5.13, mccabe >=0.6,<0.8, platformdirs >=2.2, python >=3.10, tomli >=1.1.0, tomlkit >=0.10.1, dill >=0.3.7, python |
| pyobjc-core | 12.1 | py312h19bbe71_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libffi >=3.5.2,<3.6.0a0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312, setuptools |
| pyobjc-framework-cocoa | 12.1 | py312h1de3e18_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libffi >=3.5.2,<3.6.0a0, pyobjc-core 12.1.*, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| pyparsing | 3.2.5 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| pysocks | 1.7.1 | pyha55dd90_7 | Software/pyomp, ~/.pixi/envs/default | __unix, python >=3.9 |
| python | 3.12.12 | h18782d2_1_cpython | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, bzip2 >=1.0.8,<2.0a0, libexpat >=2.7.1,<3.0a0, libffi >=3.5.2,<3.6.0a0, liblzma >=5.8.1,<6.0a0, libsqlite >=3.50.4,<4.0a0, libzlib >=1.3.1,<2.0a0, ncurses >=6.5,<7.0a0, openssl >=3.5.4,<4.0a0, readline >=8.2,<9.0a0, tk >=8.6.13,<8.7.0a0, tzdata |
| python | 3.14.2 | h40d2674_101_cp314 | Software/unrpa | __osx >=11.0, bzip2 >=1.0.8,<2.0a0, libexpat >=2.7.3,<3.0a0, libffi >=3.5.2,<3.6.0a0, liblzma >=5.8.2,<6.0a0, libmpdec >=4.0.0,<5.0a0, libsqlite >=3.51.2,<4.0a0, libzlib >=1.3.1,<2.0a0, ncurses >=6.5,<7.0a0, openssl >=3.5.4,<4.0a0, python_abi 3.14.* *_cp314, readline >=8.3,<9.0a0, tk >=8.6.13,<8.7.0a0, tzdata, zstd >=1.5.7,<1.6.0a0 |
| python | 3.14.6 | he51be1b_0_cp314t | ~/.pixi/envs/openpyxl | __osx >=11.0, bzip2 >=1.0.8,<2.0a0, libexpat >=2.8.1,<3.0a0, libffi >=3.5.2,<3.6.0a0, liblzma >=5.8.3,<6.0a0, libmpdec >=4.0.0,<5.0a0, libsqlite >=3.53.2,<4.0a0, libzlib >=1.3.2,<2.0a0, ncurses >=6.6,<7.0a0, openssl >=3.5.7,<4.0a0, python_abi 3.14.* *_cp314t, readline >=8.3,<9.0a0, tk >=8.6.13,<8.7.0a0, tzdata, zstd >=1.5.7,<1.6.0a0 |
| python-dateutil | 2.9.0.post0 | pyhe01879c_2 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, six >=1.5, python |
| python-fastjsonschema | 2.21.2 | pyhe01879c_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, python |
| python-gil | 3.12.12 | hd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | cpython 3.12.12.*, python_abi * *_cp312 |
| python-json-logger | 2.0.7 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.6 |
| python-tzdata | 2025.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| python_abi | 3.12 | 8_cp312 | Software/pyomp, ~/.pixi/envs/default | 无 |
| python_abi | 3.14 | 8_cp314 | Software/unrpa | 无 |
| python_abi | 3.14 | 8_cp314t | ~/.pixi/envs/openpyxl | 无 |
| pytz | 2025.2 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| pyyaml | 6.0.3 | py312h5748b74_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312, yaml >=0.2.5,<0.3.0a0 |
| pyzmq | 27.1.0 | py312hd65ceae_0 | Software/pyomp, ~/.pixi/envs/default | python, __osx >=11.0, libcxx >=19, _python_abi3_support 1.*, cpython >=3.12, zeromq >=4.3.5,<4.4.0a0 |
| qhull | 2020.2 | h420ef59_5 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=16 |
| re2 | 2025.11.05 | h64b956e_0 | Software/pyomp, ~/.pixi/envs/default | libre2-11 2025.11.05 h91c62da_0 |
| readline | 8.2 | h1d1bf99_2 | Software/pyomp, ~/.pixi/envs/default | ncurses >=6.5,<7.0a0 |
| readline | 8.3 | h46df422_0 | Software/unrpa, ~/.pixi/envs/openpyxl | __osx >=11.0, ncurses >=6.5,<7.0a0 |
| referencing | 0.37.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | attrs >=22.2.0, python >=3.10, rpds-py >=0.7.0, typing_extensions >=4.4.0, python |
| requests | 2.32.5 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | certifi >=2017.4.17, charset-normalizer >=2,<4, idna >=2.5,<4, python >=3.9, urllib3 >=1.21.1,<3 |
| rfc3339-validator | 0.1.4 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, six |
| rfc3986-validator | 0.1.1 | pyh9f0ad1d_0 | Software/pyomp, ~/.pixi/envs/default | python |
| rfc3987-syntax | 1.1.0 | pyhe01879c_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, lark >=1.2.2, python |
| rpds-py | 0.30.0 | py312h6ef9ec0_0 | Software/pyomp, ~/.pixi/envs/default | python, __osx >=11.0, python 3.12.* *_cpython, python_abi 3.12.* *_cp312 |
| ruff | 0.14.7 | h382de68_0 | ~/.pixi/envs/default | python, __osx >=11.0 |
| s3fs | 2025.10.0 | pyhd8ed1ab_0 | Software/pyomp | aiobotocore >=2.5.4,<3.0.0, aiohttp, fsspec 2025.10.0, python >=3.10 |
| s3fs | 2025.12.0 | pyhd8ed1ab_0 | ~/.pixi/envs/default | aiobotocore >=2.5.4,<3.0.0, aiohttp, fsspec 2025.12.0, python >=3.10 |
| scipy | 1.16.3 | py312ha6bbf71_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libblas >=3.9.0,<4.0a0, libcblas >=3.9.0,<4.0a0, libcxx >=19, libgfortran, libgfortran5 >=14.3.0, libgfortran5 >=15.2.0, liblapack >=3.9.0,<4.0a0, numpy <2.6, numpy >=1.23,<3, numpy >=1.25.2, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| send2trash | 1.8.3 | pyh31c8845_1 | Software/pyomp, ~/.pixi/envs/default | __osx, pyobjc-framework-cocoa, python >=3.9 |
| setuptools | 80.9.0 | pyhff2d567_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| six | 1.17.0 | pyhe01879c_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, python |
| snappy | 1.2.2 | hada39a4_1 | Software/pyomp, ~/.pixi/envs/default | libcxx >=19, __osx >=11.0 |
| sniffio | 1.3.1 | pyhd8ed1ab_2 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| sortedcontainers | 2.4.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| soupsieve | 2.8 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| stack_data | 0.6.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | asttokens, executing, pure_eval, python >=3.9 |
| terminado | 0.18.1 | pyh31c8845_0 | Software/pyomp, ~/.pixi/envs/default | __osx, ptyprocess, python >=3.8, tornado >=6.1.0 |
| tinycss2 | 1.5.1 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, webencodings >=0.4, python |
| tk | 8.6.13 | h010d191_3 | Software/unrpa, ~/.pixi/envs/openpyxl | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |
| tk | 8.6.13 | h892fb3f_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |
| tomli | 2.3.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| tomlkit | 0.13.3 | pyha770c72_0 | ~/.pixi/envs/default | python >=3.9 |
| toolz | 1.1.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| tornado | 6.5.2 | py312h4409184_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| traitlets | 5.14.3 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| traittypes | 0.2.3 | pyh332efcf_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.9, traitlets >=4.2.2,<6.0 |
| typing-extensions | 4.15.0 | h396c80c_0 | Software/pyomp, ~/.pixi/envs/default | typing_extensions ==4.15.0 pyhcf101f3_0 |
| typing_extensions | 4.15.0 | pyhcf101f3_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| typing_utils | 0.1.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| tzdata | 2025b | h78e105d_0 | Software/pyomp, ~/.pixi/envs/default | 无 |
| tzdata | 2025c | hc9c84f9_1 | Software/unrpa, ~/.pixi/envs/openpyxl | 无 |
| uncompresspy | 0.4.1 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| unicodedata2 | 17.0.0 | py312h4409184_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| uri-template | 1.3.0 | pyhd8ed1ab_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| urllib3 | 2.5.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | brotli-python >=1.0.9, h2 >=4,<5, pysocks >=1.5.6,<2.0,!=1.5.7, python >=3.9, zstandard >=0.18.0 |
| wcwidth | 0.2.14 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| webcolors | 25.10.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| webencodings | 0.5.1 | pyhd8ed1ab_3 | Software/pyomp, ~/.pixi/envs/default | python >=3.9 |
| websocket-client | 1.9.0 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| widgetsnbextension | 4.0.15 | pyhd8ed1ab_0 | Software/pyomp, ~/.pixi/envs/default | python >=3.10 |
| wrapt | 1.17.3 | py312h163523d_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| xorg-libxau | 1.0.12 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| xorg-libxdmcp | 1.1.5 | hc919400_1 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| yaml | 0.2.5 | h925e9cb_3 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0 |
| yarl | 1.22.0 | py312h5748b74_0 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, idna >=2.0, multidict >=4.0, propcache >=0.2.1, python >=3.12,<3.13.0a0, python >=3.12,<3.13.0a0 *_cpython, python_abi 3.12.* *_cp312 |
| zeromq | 4.3.5 | h888dc83_9 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libcxx >=19, libsodium >=1.0.20,<1.0.21.0a0, krb5 >=1.21.3,<1.22.0a0 |
| zipp | 3.23.0 | pyhcf101f3_1 | Software/pyomp, ~/.pixi/envs/default | python >=3.10, python |
| zlib | 1.3.1 | h8359307_2 | Software/pyomp, ~/.pixi/envs/default | __osx >=11.0, libzlib 1.3.1 h8359307_2 |
| zlib-ng | 2.3.1 | h248ca61_1 | Software/pyomp | libcxx >=19, __osx >=11.0 |
| zlib-ng | 2.3.2 | h248ca61_0 | ~/.pixi/envs/default | libcxx >=19, __osx >=11.0 |
| zstandard | 0.25.0 | py312h37e1c23_1 | Software/pyomp, ~/.pixi/envs/default | python, cffi >=1.11, zstd >=1.5.7,<1.5.8.0a0, python 3.12.* *_cpython, __osx >=11.0, python_abi 3.12.* *_cp312, zstd >=1.5.7,<1.6.0a0 |
| zstd | 1.5.7 | hbf9d68e_6 | Software/unrpa, ~/.pixi/envs/default, ~/.pixi/envs/openpyxl | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |
| zstd | 1.5.7 | hd0aec43_5 | Software/pyomp | __osx >=11.0, libzlib >=1.3.1,<2.0a0 |


</details>

<details>
<summary>9.7 Emacs：三个系统的全部 ELPA/VC 包目录</summary>

版本取自 `*-pkg.el`；表中每列为该机器已安装版本。安装目录中存在包不意味着当前 init 一定加载它。包自身的间接 Lisp 依赖也在此列出，但本轮未导出逐包 Lisp 依赖边。

| 包 | Mac | Fedora | Deck |
| --- | --- | --- | --- |
| ace-window | 20220911.358 | 20220911.358 | 20220911.358 |
| acp | 20260914.1318 | 20260914.1318 | 20261018.1243 |
| agent-shell | 20260921.1420 | 20260919.218 | 20261018.1349 |
| auctex | 14.2.0 | 14.2.0 | 14.2.0 |
| avy | 20241101.1357 | 20241101.1357 | 20241101.1357 |
| cape | 20260905.500 | 20260905.500 | 20260927.2347 |
| cfrs | 20250729.1422 | 20250729.1422 | 20250729.1422 |
| citar | 20260922.132 | 20260706.1221 | 20261015.55 |
| citeproc | 20260113.1047 | 20260113.1047 | 20260113.1047 |
| cmake-mode | 20260825.1510 | 20260825.1510 | 20261002.1529 |
| code-cells | 20241119.1421 | 20241119.1421 | 20241119.1421 |
| compat | 31.1.0.0 | — | — |
| cond-let | 20260901.1107 | 20260901.1107 | 20261001.1537 |
| consult | 20260913.2232 | 20260913.2232 | 20261004.957 |
| consult-dir | 20251020.416 | 20251020.416 | 20251020.416 |
| consult-eglot | 20260613.1443 | 20260613.1443 | 20260613.1443 |
| corfu | 20260913.1527 | 20260913.1527 | 20261014.1751 |
| csv-mode | 1.27 | 1.27 | 1.27 |
| dash | 20260221.1346 | 20260221.1346 | 20260221.1346 |
| diff-hl | 20260915.417 | 20260915.417 | 20261001.135 |
| dired-hacks-utils | 20240629.1906 | 20240629.1906 | 20240629.1906 |
| dired-subtree | 20240629.1859 | 20240629.1859 | 20240629.1859 |
| doom-themes | 20260826.1413 | 20260826.1413 | 20260826.1413 |
| edit-indirect | 20240128.119 | — | — |
| elisp-refs | 20230920.201 | 20230920.201 | 20230920.201 |
| embark | 20260610.302 | 20260610.302 | 20260610.302 |
| embark-consult | 20260503.118 | 20260503.118 | 20260503.118 |
| embr | 0 (Git d0f65b3a363c) | 0 (Git d0f65b3a363c) | 0 (Git d0f65b3a363c) |
| f | 20241003.1131 | 20241003.1131 | 20241003.1131 |
| f90-ts-mode | 20260918.1132 | 20260918.1132 | 20261001.1036 |
| helix | 20260911.1659 | 20260911.1659 | 20261005.1637 |
| helpful | 20250408.334 | 20250408.334 | 20250408.334 |
| hl-todo | 20260601.1508 | 20260601.1508 | 20261001.1547 |
| ht | 20230703.558 | 20230703.558 | 20230703.558 |
| hydra | 20250316.1254 | 20250316.1254 | 20250316.1254 |
| llama | 20260909.859 | 20260909.859 | 20261001.1538 |
| lv | 20200507.1518 | 20200507.1518 | 20200507.1518 |
| magit | 20260921.2144 | 20260919.934 | 20261018.1900 |
| magit-section | 20260901.1810 | 20260901.1810 | 20261018.807 |
| marginalia | 20260907.511 | 20260907.511 | 20261010.1524 |
| markdown-mode | 20260827.909 | — | — |
| markdown-toc | 20260131.1444 | — | — |
| markdown-ts-appear | 0.2.1 (Git 0a760125ddf2) | 0.2.1 (Git 0a760125ddf2) | 0.3.1 (Git 22577039b48c) |
| mathjax | 0.1 | 0.1 | 0.1 |
| minuet | 20260814.654 | 20260814.654 | 20261007.1956 |
| msgpack | 20260706.1555 | 20260706.1555 | 20260706.1555 |
| multiple-cursors | 20260419.931 | 20260419.931 | 20260419.931 |
| orderless | 20260909.1506 | 20260909.1506 | 20261013.1927 |
| org-modern | 20260722.1411 | 20260722.1411 | 20260722.1411 |
| parsebib | 20251125.1320 | 20251125.1320 | 20251125.1320 |
| pdf-tools | 20260102.1101 [native 文件] | 20260102.1101 [native 文件] | 20260102.1101 [native 文件] |
| pet | 20260716.2214 | 20260716.2214 | 20260716.2214 |
| pfuture | 20220913.1401 | 20220913.1401 | 20220913.1401 |
| plz | 0.9.1 | 0.9.1 | 0.9.1 |
| posframe | 20260920.706 | 20260908.156 | 20261019.601 |
| queue | 0.2 | 0.2 | 0.2 |
| rainbow-delimiters | 20210515.1254 | 20210515.1254 | 20210515.1254 |
| reformatter | 20241204.1051 | 20241204.1051 | 20241204.1051 |
| s | 20260522.135 | 20260522.135 | 20260522.135 |
| shell-maker | 20260910.119 | 20260910.119 | 20261015.2327 |
| string-inflection | 20251114.1041 | 20251114.1041 | 20251114.1041 |
| tablist | 20260623.1855 | 20260623.1855 | 20260623.1855 |
| texfrag | 20240415.1043 | — | — |
| tramp-rpc | 0.13.1 (Git 948e42a76a97) | 0.13.1 (Git 948e42a76a97) | 0.15.0 (Git de8df792d824) |
| transient | 20260919.938 | — | — |
| treemacs | 20251226.1307 | 20251226.1307 | 20251226.1307 |
| valign | 3.1.1 | 3.1.1 | 3.1.1 |
| vertico | 20260913.1525 | 20260913.1525 | 20260913.1525 |
| visual-fill-column | 20251110.1039 | 20251110.1039 | 20251110.1039 |
| vterm | 20260914.1641 [native 文件] | 20260914.1641 [native 文件] | 20260914.1641 [native 文件] |
| with-editor | 20260919.936 | 20260919.936 | 20261018.2026 |
| writegood-mode | 20220511.2109 | 20220511.2109 | 20220511.2109 |
| yaml-mode | 20260830.2340 | 20260830.2340 | 20260830.2340 |
| yasnippet | 20250602.1342 | 20250602.1342 | 20250602.1342 |
| yasnippet-snippets | 20251215.1231 | 20251215.1231 | 20251215.1231 |
| zoxide | 20241003.1103 | 20241003.1103 | 20241003.1103 |


</details>

<details>
<summary>9.8 已存在的 Tree-sitter grammar 文件</summary>


| 系统 | 文件 |
| --- | --- |
| Mac | libtree-sitter-bash.dylib, libtree-sitter-c.dylib, libtree-sitter-cpp.dylib, libtree-sitter-fortran.dylib, libtree-sitter-json.dylib, libtree-sitter-markdown-inline.dylib, libtree-sitter-markdown.dylib, libtree-sitter-python.dylib, libtree-sitter-toml.dylib, libtree-sitter-yaml.dylib |
| Fedora | libtree-sitter-bash.so, libtree-sitter-c.so, libtree-sitter-cpp.so, libtree-sitter-fortran.so, libtree-sitter-json.so, libtree-sitter-markdown-inline.so, libtree-sitter-markdown.so, libtree-sitter-python.so, libtree-sitter-yaml.so |
| Deck | libtree-sitter-bash.so, libtree-sitter-c.so, libtree-sitter-cpp.so, libtree-sitter-fortran.so, libtree-sitter-json.so, libtree-sitter-markdown-inline.so, libtree-sitter-markdown.so, libtree-sitter-python.so, libtree-sitter-yaml.so |


</details>

<details>
<summary>9.9 uv 已安装的独立工具</summary>

**Mac**

```text
arxiv-mcp-server v0.5.0
- arxiv-mcp-server
fortls v3.2.2
- fortls
markitdown-mcp v0.0.1a4
- markitdown-mcp
pyright v1.1.411
- pyright
- pyright-langserver
- pyright-python
- pyright-python-langserver
zotero-mcp-server v0.5.0
- zotero-cli
- zotero-mcp
```
**Fedora**

```text
uv tool list 未列出工具
```
**Deck**

```text
uv tool list 未列出工具
```

</details>

<details>
<summary>9.10 Mac uv 独立工具：用途与实际 Python 依赖</summary>


| 工具 | 分类/用途 | 安装方式 | 实际 Python 包数 |
| --- | --- | --- | --- |
| arxiv-mcp-server | 论文检索 MCP 工具 | uv tool / PyPI 隔离环境 | 61 |
| fortls | Fortran 语言服务器 | uv tool / PyPI 隔离环境 | 3 |
| markitdown-mcp | 文档转换 MCP 工具 | uv tool / PyPI 隔离环境 | 64 |
| pyright | Python 类型检查/语言服务器 | uv tool / PyPI 隔离环境 | 4 |
| zotero-mcp-server | 文献库 MCP 工具 | uv tool / PyPI 隔离环境 | 92 |

以下 Requires-Dist 含可选 extra/平台条件，不能把每一项都当作无条件依赖。实际存在的包以表格行本身为准；不导出用户配置或认证信息。

| Python 包 | 版本 | 所属工具环境 | 声明依赖（含条件） |
| --- | --- | --- | --- |
| Authlib | 1.7.2 | zotero-mcp-server | cryptography, joserfc>=1.6.0 |
| PyJWT | 2.13.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | typing_extensions>=4.0; python_version < "3.11", cryptography>=3.4.0; extra == "crypto" |
| PyMuPDF | 1.27.2.3 | arxiv-mcp-server | 无 |
| PyYAML | 6.0.3 | arxiv-mcp-server, zotero-mcp-server | 无 |
| Pygments | 2.20.0 | zotero-mcp-server | colorama>=0.4.6; extra == 'windows-terminal' |
| SpeechRecognition | 3.16.1 | markitdown-mcp | typing-extensions, standard-aifc; python_version >= "3.13", audioop-lts; python_version >= "3.13", pytest; extra == "dev", pytest-randomly; extra == "dev", respx; extra == "dev", numpy; extra == "dev", pytest-httpserver; extra == "dev", mypy; extra == "dev", types-requests; extra == "dev", PyAudio>=0.2.11; extra == "audio", pocketsphinx; extra == "pocketsphinx", google-cloud-speech; extra == "google-cloud", openai-whisper; extra == "whisper-local", soundfile; extra == "whisper-local", faster-whisper; extra == "faster-whisper", soundfile; extra == "faster-whisper", openai; extra == "openai", httpx<0.28; extra == "openai", groq; extra == "groq", httpx<0.28; extra == "groq", cohere>=5.21.0; extra == "cohere-api", requests; extra == "assemblyai", vosk; extra == "vosk" |
| Unidecode | 1.4.0 | zotero-mcp-server | 无 |
| aiofile | 3.11.1 | zotero-mcp-server | caio~=0.9.0 |
| aiofiles | 25.1.0 | arxiv-mcp-server | 无 |
| aiohappyeyeballs | 2.6.2 | arxiv-mcp-server | 无 |
| aiohttp | 3.14.1 | arxiv-mcp-server | aiohappyeyeballs>=2.5.0, aiosignal>=1.4.0, async-timeout<6.0,>=4.0; python_version < "3.11", attrs>=17.3.0, frozenlist>=1.1.1, multidict<7.0,>=4.5, propcache>=0.2.0, typing_extensions>=4.4; python_version < "3.13", yarl<2.0,>=1.17.0, aiodns>=3.3.0; (sys_platform != "android" and sys_platform != "ios") and extra == "speedups", Brotli>=1.2; (platform_python_implementation == "CPython" and sys_platform != "android" and sys_platform != "ios") and extra == "speedups", brotlicffi>=1.2; platform_python_implementation != "CPython" and extra == "speedups", backports.zstd; (platform_python_implementation == "CPython" and python_version < "3.14" and sys_platform != "android" and sys_platform != "ios") and extra == "speedups" |
| aiosignal | 1.4.0 | arxiv-mcp-server | frozenlist>=1.1.0, typing-extensions>=4.2; python_version < "3.13" |
| annotated-types | 0.7.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | typing-extensions>=4.0.0; python_version < '3.9' |
| anyio | 4.13.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | exceptiongroup>=1.0.2; python_version < "3.11", idna>=2.8, typing_extensions>=4.5; python_version < "3.13", trio>=0.32.0; extra == "trio" |
| arxiv | 4.0.0 | arxiv-mcp-server | lxml<7.0,>=6.1.0, requests<2.34,>=2.32, typing-extensions>=4.0.0; python_version < '3.11' |
| arxiv-mcp-server | 0.5.0 | arxiv-mcp-server | aiofiles>=23.2.1, aiohttp>=3.9.1, anyio>=4.2.0, arxiv>=2.1.0, black>=25.1.0, httpx>=0.24.0, mcp>=1.27.0, pydantic-settings>=2.1.0, pydantic>=2.8.0, python-dateutil>=2.8.2, python-dotenv>=1.0.0, sse-starlette>=1.8.2, starlette>=0.27.0, uvicorn>=0.30.0, black>=23.3.0; extra == 'dev', pymupdf-layout>=1.26.6; extra == 'pdf', pymupdf4llm>=0.0.17; extra == 'pdf', numpy>=1.26.0; extra == 'pro', sentence-transformers>=3.0.0; extra == 'pro', aioresponses>=0.7.6; extra == 'test', pytest-asyncio>=0.23.5; extra == 'test', pytest-cov>=4.1.0; extra == 'test', pytest-mock>=3.10.0; extra == 'test', pytest>=8.0.0; extra == 'test' |
| attrs | 26.1.0 | arxiv-mcp-server, zotero-mcp-server | 无 |
| azure-ai-documentintelligence | 1.0.2 | markitdown-mcp | isodate>=0.6.1, azure-core>=1.30.0, typing-extensions>=4.6.0 |
| azure-core | 1.41.0 | markitdown-mcp | requests>=2.21.0, typing-extensions>=4.6.0, aiohttp>=3.0; extra == "aio", opentelemetry-api~=1.26; extra == "tracing" |
| azure-identity | 1.25.3 | markitdown-mcp | azure-core>=1.31.0, cryptography>=2.5, msal>=1.35.1, msal-extensions>=1.2.0, typing-extensions>=4.0.0 |
| beartype | 0.22.9 | zotero-mcp-server | autoapi>=0.9.0; extra == 'dev', celery; extra == 'dev', click; extra == 'dev', coverage>=5.5; extra == 'dev', docutils>=0.22.0; extra == 'dev', equinox; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'dev', fastmcp; (python_version < '3.14.0') and extra == 'dev', jax[cpu]; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'dev', jaxtyping; (sys_platform == 'linux') and extra == 'dev', langchain; (python_version < '3.14.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'dev', mypy>=0.800; (platform_python_implementation != 'PyPy') and extra == 'dev', nuitka>=1.2.6; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'dev', numba; (python_version < '3.14.0') and extra == 'dev', numpy; (python_version < '3.15.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'dev', pandera>=0.26.0; (python_version < '3.14.0') and extra == 'dev', poetry; extra == 'dev', polars; (python_version < '3.14.0') and extra == 'dev', pydata-sphinx-theme<=0.7.2; extra == 'dev', pygments; extra == 'dev', pyinstaller; extra == 'dev', pyright>=1.1.370; extra == 'dev', pytest>=6.2.0; extra == 'dev', redis; extra == 'dev', rich-click; extra == 'dev', setuptools; extra == 'dev', sphinx; extra == 'dev', sphinx<6.0.0,>=4.2.0; extra == 'dev', sphinxext-opengraph>=0.7.5; extra == 'dev', sqlalchemy; extra == 'dev', torch; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'dev', tox>=3.20.1; extra == 'dev', typer; extra == 'dev', typing-extensions>=3.10.0.0; extra == 'dev', xarray; (python_version < '3.15.0') and extra == 'dev', mkdocs-material[imaging]>=9.6.0; extra == 'doc-ghp', mkdocstrings-python-xref>=1.16.0; extra == 'doc-ghp', mkdocstrings-python>=1.16.0; extra == 'doc-ghp', autoapi>=0.9.0; extra == 'doc-rtd', pydata-sphinx-theme<=0.7.2; extra == 'doc-rtd', setuptools; extra == 'doc-rtd', sphinx<6.0.0,>=4.2.0; extra == 'doc-rtd', sphinxext-opengraph>=0.7.5; extra == 'doc-rtd', celery; extra == 'test', click; extra == 'test', coverage>=5.5; extra == 'test', docutils>=0.22.0; extra == 'test', equinox; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'test', fastmcp; (python_version < '3.14.0') and extra == 'test', jax[cpu]; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'test', jaxtyping; (sys_platform == 'linux') and extra == 'test', langchain; (python_version < '3.14.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'test', mypy>=0.800; (platform_python_implementation != 'PyPy') and extra == 'test', nuitka>=1.2.6; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'test', numba; (python_version < '3.14.0') and extra == 'test', numpy; (python_version < '3.15.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'test', pandera>=0.26.0; (python_version < '3.14.0') and extra == 'test', poetry; extra == 'test', polars; (python_version < '3.14.0') and extra == 'test', pygments; extra == 'test', pyinstaller; extra == 'test', pyright>=1.1.370; extra == 'test', pytest>=6.2.0; extra == 'test', redis; extra == 'test', rich-click; extra == 'test', sphinx; extra == 'test', sqlalchemy; extra == 'test', torch; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'test', tox>=3.20.1; extra == 'test', typer; extra == 'test', typing-extensions>=3.10.0.0; extra == 'test', xarray; (python_version < '3.15.0') and extra == 'test', celery; extra == 'test-tox', click; extra == 'test-tox', docutils>=0.22.0; extra == 'test-tox', equinox; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'test-tox', fastmcp; (python_version < '3.14.0') and extra == 'test-tox', jax[cpu]; (sys_platform == 'linux' and python_version < '3.15.0') and extra == 'test-tox', jaxtyping; (sys_platform == 'linux') and extra == 'test-tox', langchain; (python_version < '3.14.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'test-tox', mypy>=0.800; (platform_python_implementation != 'PyPy') and extra == 'test-tox', nuitka>=1.2.6; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'test-tox', numba; (python_version < '3.14.0') and extra == 'test-tox', numpy; (python_version < '3.15.0' and sys_platform != 'darwin' and platform_python_implementation != 'PyPy') and extra == 'test-tox', pandera>=0.26.0; (python_version < '3.14.0') and extra == 'test-tox', poetry; extra == 'test-tox', polars; (python_version < '3.14.0') and extra == 'test-tox', pygments; extra == 'test-tox', pyinstaller; extra == 'test-tox', pyright>=1.1.370; extra == 'test-tox', pytest>=6.2.0; extra == 'test-tox', redis; extra == 'test-tox', rich-click; extra == 'test-tox', sphinx; extra == 'test-tox', sqlalchemy; extra == 'test-tox', torch; (sys_platform == 'linux' and python_version < '3.14.0') and extra == 'test-tox', typer; extra == 'test-tox', typing-extensions>=3.10.0.0; extra == 'test-tox', xarray; (python_version < '3.15.0') and extra == 'test-tox', coverage>=5.5; extra == 'test-tox-coverage' |
| beautifulsoup4 | 4.15.0 | markitdown-mcp, zotero-mcp-server | soupsieve>=1.6.1, typing-extensions>=4.0.0, cchardet; extra == 'cchardet', chardet; extra == 'chardet', charset-normalizer; extra == 'charset-normalizer', html5lib; extra == 'html5lib', lxml; extra == 'lxml' |
| bibtexparser | 1.4.4 | zotero-mcp-server | pyparsing>=2.0.3 |
| black | 26.5.1 | arxiv-mcp-server | click>=8.0.0, mypy-extensions>=0.4.3, packaging>=22.0, pathspec>=1.0.0, platformdirs>=2, pytokens~=0.4.0, tomli>=1.1.0; python_version < '3.11', typing-extensions>=4.0.1; python_version < '3.11', colorama>=0.4.3; extra == 'colorama', aiohttp>=3.10; extra == 'd', ipython>=7.8.0; extra == 'jupyter', tokenize-rt>=3.2.0; extra == 'jupyter', uvloop>=0.15.2; (sys_platform != 'win32') and extra == 'uvloop', winloop>=0.5.0; (sys_platform == 'win32') and extra == 'uvloop' |
| cachetools | 7.1.4 | zotero-mcp-server | 无 |
| caio | 0.9.25 | zotero-mcp-server | aiomisc-pytest; extra == "develop", coveralls; extra == "develop", pylama[toml]; extra == "develop", pytest; extra == "develop", pytest-cov; extra == "develop", setuptools; extra == "develop" |
| certifi | 2026.5.20 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| cffi | 2.0.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | pycparser; implementation_name != "PyPy" |
| charset-normalizer | 3.4.7 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| click | 8.4.1 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | colorama; platform_system == 'Windows' |
| cobble | 0.1.4 | markitdown-mcp | 无 |
| cryptography | 48.0.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | cffi>=2.0.0 ; platform_python_implementation != 'PyPy', typing-extensions>=4.13.2 ; python_full_version < '3.11', bcrypt>=3.1.5 ; extra == 'ssh' |
| cyclopts | 4.16.1 | zotero-mcp-server | attrs>=23.1.0, docstring-parser<4.0,>=0.15, rich-rst<3.0.0,>=1.3.1, rich>=13.6.0, tomli>=2.0.0; python_version < '3.11', typing-extensions>=4.8.0; python_version < '3.11', ipdb>=0.13.9; extra == 'debug', line-profiler>=3.5.1; extra == 'debug', coverage[toml]>=5.1; extra == 'dev', mkdocs>=1.4.0; extra == 'dev', pexpect>=4.9.0; (sys_platform != 'win32') and extra == 'dev', pre-commit>=2.16.0; extra == 'dev', pydantic<3.0.0,>=2.11.2; extra == 'dev', pytest-cov>=3.0.0; extra == 'dev', pytest-mock>=3.7.0; extra == 'dev', pytest>=8.2.0; extra == 'dev', pyyaml>=6.0.1; extra == 'dev', syrupy>=4.0.0; extra == 'dev', toml<1.0.0,>=0.10.2; extra == 'dev', trio>=0.10.0; extra == 'dev', gitpython>=3.1.31; extra == 'docs', myst-parser[linkify]<5.0.0,>=3.0.1; extra == 'docs', sphinx-autodoc-typehints<4.0.0,>=1.25.2; extra == 'docs', sphinx-copybutton<1.0,>=0.5; extra == 'docs', sphinx-rtd-dark-mode<2.0.0,>=1.3.0; extra == 'docs', sphinx-rtd-theme<4.0.0,>=3.0.0; extra == 'docs', sphinx<8.2.0,>=7.4.7; extra == 'docs', markdown>=3.3; extra == 'mkdocs', mkdocs>=1.4.0; extra == 'mkdocs', pymdown-extensions>=10.0; extra == 'mkdocs', tomli>=2.0.0; (python_version < '3.11') and extra == 'toml', trio>=0.10.0; extra == 'trio', pyyaml>=6.0.1; extra == 'yaml' |
| defusedxml | 0.7.1 | markitdown-mcp, zotero-mcp-server | 无 |
| dnspython | 2.8.0 | zotero-mcp-server | black>=25.1.0; extra == 'dev', coverage>=7.0; extra == 'dev', flake8>=7; extra == 'dev', hypercorn>=0.17.0; extra == 'dev', mypy>=1.17; extra == 'dev', pylint>=3; extra == 'dev', pytest-cov>=6.2.0; extra == 'dev', pytest>=8.4; extra == 'dev', quart-trio>=0.12.0; extra == 'dev', sphinx-rtd-theme>=3.0.0; extra == 'dev', sphinx>=8.2.0; extra == 'dev', twine>=6.1.0; extra == 'dev', wheel>=0.45.0; extra == 'dev', cryptography>=45; extra == 'dnssec', h2>=4.2.0; extra == 'doh', httpcore>=1.0.0; extra == 'doh', httpx>=0.28.0; extra == 'doh', aioquic>=1.2.0; extra == 'doq', idna>=3.10; extra == 'idna', trio>=0.30; extra == 'trio', wmi>=1.5.1; (platform_system == 'Windows') and extra == 'wmi' |
| docstring_parser | 0.18.0 | zotero-mcp-server | pre-commit>=2.16.0; (python_version >= '3.9') and extra == 'dev', pydoctor>=25.4.0; extra == 'dev', pytest; extra == 'dev', pydoctor>=25.4.0; extra == 'docs', pytest; extra == 'test' |
| email-validator | 2.3.0 | zotero-mcp-server | dnspython>=2.0.0, idna>=2.0.0 |
| et_xmlfile | 2.0.0 | markitdown-mcp | 无 |
| exceptiongroup | 1.3.1 | zotero-mcp-server | typing-extensions >= 4.6.0; python_version < '3.13', pytest >= 6 ; extra == "test" |
| fastmcp | 3.4.2 | zotero-mcp-server | fastmcp-slim[client,server]==3.4.2, fastmcp-slim[anthropic]==3.4.2; extra == 'anthropic', fastmcp-slim[apps]==3.4.2; extra == 'apps', fastmcp-slim[azure]==3.4.2; extra == 'azure', fastmcp-slim[code-mode]==3.4.2; extra == 'code-mode', fastmcp-slim[gemini]==3.4.2; extra == 'gemini', fastmcp-slim[openai]==3.4.2; extra == 'openai', fastmcp-slim[tasks]==3.4.2; extra == 'tasks' |
| fastmcp-slim | 3.4.2 | zotero-mcp-server | platformdirs>=4.0.0, pydantic-settings>=2.0.0, pydantic[email]>=2.11.7, python-dotenv>=1.1.0, rich>=13.9.4, typing-extensions>=4.0.0, anthropic>=0.48.0; extra == 'anthropic', prefab-ui>=0.18.0; extra == 'apps', azure-identity>=1.16.0; extra == 'azure', pyjwt>=2.12.0; extra == 'azure', authlib>=1.6.11; extra == 'client', exceptiongroup>=1.2.2; extra == 'client', httpx<1.0,>=0.28.1; extra == 'client', mcp<2.0,>=1.24.0; extra == 'client', opentelemetry-api>=1.20.0; extra == 'client', py-key-value-aio[filetree,keyring,memory]<0.5.0,>=0.4.4; extra == 'client', starlette>=1.0.1; extra == 'client', pydantic-monty==0.0.17; extra == 'code-mode', google-genai>=1.18.0; extra == 'gemini', jsonref>=1.1.0; extra == 'gemini', exceptiongroup>=1.2.2; extra == 'mcp', httpx<1.0,>=0.28.1; extra == 'mcp', mcp<2.0,>=1.24.0; extra == 'mcp', opentelemetry-api>=1.20.0; extra == 'mcp', starlette>=1.0.1; extra == 'mcp', openai>=1.102.0; extra == 'openai', authlib>=1.6.11; extra == 'server', cyclopts>=4.0.0; extra == 'server', exceptiongroup>=1.2.2; extra == 'server', griffelib>=2.0.0; extra == 'server', httpx<1.0,>=0.28.1; extra == 'server', joserfc>=1.1.0; extra == 'server', jsonref>=1.1.0; extra == 'server', jsonschema-path>=0.3.4; extra == 'server', mcp<2.0,>=1.24.0; extra == 'server', openapi-pydantic>=0.5.1; extra == 'server', opentelemetry-api>=1.20.0; extra == 'server', packaging>=24.0; extra == 'server', py-key-value-aio[filetree,keyring,memory]<0.5.0,>=0.4.4; extra == 'server', pyperclip>=1.9.0; extra == 'server', python-multipart>=0.0.26; extra == 'server', pyyaml<7.0,>=6.0; extra == 'server', starlette>=1.0.1; extra == 'server', uncalled-for>=0.2.0; extra == 'server', uvicorn>=0.35; extra == 'server', watchfiles>=1.0.0; extra == 'server', websockets>=15.0.1; extra == 'server', pydocket>=0.20.0; extra == 'tasks' |
| feedparser | 6.0.12 | zotero-mcp-server | sgmllib3k |
| flatbuffers | 25.12.19 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| fortls | 3.2.2 | fortls | json5, packaging, importlib-metadata; python_version < "3.8", typing-extensions; python_version < "3.8", pytest>=7.2.0; extra == "dev", pytest-cov>=4.0.0; extra == "dev", pytest-xdist>=3.0.2; extra == "dev", black; extra == "dev", isort; extra == "dev", pre-commit; extra == "dev", pydantic; extra == "dev", sphinx>=4.0.0; extra == "docs", sphinx-argparse; extra == "docs", sphinx-autodoc-typehints; extra == "docs", sphinx_design; extra == "docs", sphinx-copybutton; extra == "docs", furo; extra == "docs", myst-parser; extra == "docs", sphinx-sitemap; extra == "docs" |
| frozenlist | 1.8.0 | arxiv-mcp-server | 无 |
| griffelib | 2.0.2 | zotero-mcp-server | pip>=24.0; extra == 'pypi', platformdirs>=4.2; extra == 'pypi', wheel>=0.42; extra == 'pypi' |
| h11 | 0.16.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| httpcore | 1.0.9 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | certifi, h11>=0.16, anyio<5.0,>=4.0; extra == 'asyncio', h2<5,>=3; extra == 'http2', socksio==1.*; extra == 'socks', trio<1.0,>=0.22.0; extra == 'trio' |
| httpx | 0.28.1 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | anyio, certifi, httpcore==1.*, idna, brotli; (platform_python_implementation == 'CPython') and extra == 'brotli', brotlicffi; (platform_python_implementation != 'CPython') and extra == 'brotli', click==8.*; extra == 'cli', pygments==2.*; extra == 'cli', rich<14,>=10; extra == 'cli', h2<5,>=3; extra == 'http2', socksio==1.*; extra == 'socks', zstandard>=0.18.0; extra == 'zstd' |
| httpx-sse | 0.4.3 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| idna | 3.18 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | ruff >= 0.6.2 ; extra == "all", mypy >= 1.11.2 ; extra == "all", pytest >= 8.3.2 ; extra == "all" |
| isodate | 0.7.2 | markitdown-mcp | 无 |
| jaraco.classes | 3.4.0 | zotero-mcp-server | more-itertools, sphinx >=3.5 ; extra == 'docs', jaraco.packaging >=9.3 ; extra == 'docs', rst.linker >=1.9 ; extra == 'docs', furo ; extra == 'docs', sphinx-lint ; extra == 'docs', jaraco.tidelift >=1.4 ; extra == 'docs', pytest >=6 ; extra == 'testing', pytest-checkdocs >=2.4 ; extra == 'testing', pytest-cov ; extra == 'testing', pytest-mypy ; extra == 'testing', pytest-enabler >=2.2 ; extra == 'testing', pytest-ruff >=0.2.1 ; extra == 'testing' |
| jaraco.context | 6.1.2 | zotero-mcp-server | backports.tarfile; python_version < "3.12", pytest!=8.1.*,>=6; extra == "test", jaraco.test>=5.6.0; extra == "test", portend; extra == "test", sphinx>=3.5; extra == "doc", jaraco.packaging>=9.3; extra == "doc", rst.linker>=1.9; extra == "doc", furo; extra == "doc", sphinx-lint; extra == "doc", jaraco.tidelift>=1.4; extra == "doc", pytest-checkdocs>=2.14; extra == "check", pytest-ruff>=0.2.1; sys_platform != "cygwin" and extra == "check", pytest-cov; extra == "cover", pytest-enabler>=3.4; extra == "enabler", pytest-mypy>=1.0.1; platform_python_implementation != "PyPy" and extra == "type" |
| jaraco.functools | 4.5.0 | zotero-mcp-server | more_itertools, pytest!=8.1.*,>=6; extra == "test", jaraco.classes; extra == "test", sphinx>=3.5; extra == "doc", jaraco.packaging>=9.3; extra == "doc", rst.linker>=1.9; extra == "doc", furo; extra == "doc", sphinx-lint; extra == "doc", jaraco.tidelift>=1.4; extra == "doc", pytest-checkdocs>=2.14; extra == "check", pytest-ruff>=0.2.1; sys_platform != "cygwin" and extra == "check", pytest-cov; extra == "cover", pytest-enabler>=3.4; extra == "enabler", pytest-mypy>=1.0.1; platform_python_implementation != "PyPy" and extra == "type" |
| joserfc | 1.7.1 | zotero-mcp-server | cryptography>=45.0.1, pycryptodome; extra == "drafts" |
| json5 | 0.15.0 | fortls | 无 |
| jsonref | 1.1.0 | zotero-mcp-server | 无 |
| jsonschema | 4.26.0 | arxiv-mcp-server, zotero-mcp-server | attrs>=22.2.0, jsonschema-specifications>=2023.03.6, referencing>=0.28.4, rpds-py>=0.25.0, fqdn; extra == 'format', idna; extra == 'format', isoduration; extra == 'format', jsonpointer>1.13; extra == 'format', rfc3339-validator; extra == 'format', rfc3987; extra == 'format', uri-template; extra == 'format', webcolors>=1.11; extra == 'format', fqdn; extra == 'format-nongpl', idna; extra == 'format-nongpl', isoduration; extra == 'format-nongpl', jsonpointer>1.13; extra == 'format-nongpl', rfc3339-validator; extra == 'format-nongpl', rfc3986-validator>0.1.0; extra == 'format-nongpl', rfc3987-syntax>=1.1.0; extra == 'format-nongpl', uri-template; extra == 'format-nongpl', webcolors>=24.6.0; extra == 'format-nongpl' |
| jsonschema-path | 0.5.0 | zotero-mcp-server | PyYAML (>=5.1), attrs (>=22.2.0), pathable (>=0.6.0,<0.7.0), referencing (<0.38.0), requests (>=2.31.0,<3.0.0) ; extra == "requests" |
| jsonschema-specifications | 2025.9.1 | arxiv-mcp-server, zotero-mcp-server | referencing>=0.31.0 |
| keyring | 25.7.0 | zotero-mcp-server | pywin32-ctypes>=0.2.0; sys_platform == "win32", SecretStorage>=3.2; sys_platform == "linux", jeepney>=0.4.2; sys_platform == "linux", importlib_metadata>=4.11.4; python_version < "3.12", jaraco.classes, jaraco.functools, jaraco.context, pytest!=8.1.*,>=6; extra == "test", pyfakefs; extra == "test", sphinx>=3.5; extra == "doc", jaraco.packaging>=9.3; extra == "doc", rst.linker>=1.9; extra == "doc", furo; extra == "doc", sphinx-lint; extra == "doc", jaraco.tidelift>=1.4; extra == "doc", pytest-checkdocs>=2.4; extra == "check", pytest-ruff>=0.2.1; sys_platform != "cygwin" and extra == "check", pytest-cov; extra == "cover", pytest-enabler>=3.4; extra == "enabler", pytest-mypy>=1.0.1; extra == "type", pygobject-stubs; extra == "type", shtab; extra == "type", types-pywin32; extra == "type", shtab>=1.1.0; extra == "completion" |
| lxml | 6.1.1 | arxiv-mcp-server, markitdown-mcp | cssselect>=0.7; extra == "cssselect", html5lib; extra == "html5", BeautifulSoup4; extra == "htmlsoup", lxml_html_clean; extra == "html-clean" |
| magika | 0.6.3 | markitdown-mcp, zotero-mcp-server | click>=8.1.7, onnxruntime>=1.17.0 ; python_full_version >= '3.10', onnxruntime>=1.17.0,<1.20.0 ; python_full_version < '3.10', onnxruntime<=1.20.1 ; sys_platform == 'win32', numpy>=1.24 ; python_full_version < '3.12', numpy>=1.26 ; python_full_version == '3.12.*', numpy>=2.1.0 ; python_full_version >= '3.13', python-dotenv>=1.0.1 |
| mammoth | 1.11.0 | markitdown-mcp | cobble<0.2,>=0.1.3 |
| markdown-it-py | 4.2.0 | zotero-mcp-server | mdurl~=0.1, psutil ; extra == "benchmarking", pytest ; extra == "benchmarking", pytest-benchmark ; extra == "benchmarking", commonmark~=0.9 ; extra == "compare", markdown~=3.4 ; extra == "compare", mistletoe~=1.0 ; extra == "compare", mistune~=3.0 ; extra == "compare", panflute~=2.3 ; extra == "compare", markdown-it-pyrs ; extra == "compare", linkify-it-py>=1,<3 ; extra == "linkify", mdit-py-plugins>=0.5.0 ; extra == "plugins", gprof2dot ; extra == "profiling", mdit-py-plugins>=0.5.0 ; extra == "rtd", myst-parser ; extra == "rtd", pyyaml ; extra == "rtd", sphinx ; extra == "rtd", sphinx-copybutton ; extra == "rtd", sphinx-design ; extra == "rtd", sphinx-book-theme~=1.0 ; extra == "rtd", jupyter_sphinx ; extra == "rtd", ipykernel ; extra == "rtd", coverage ; extra == "testing", pytest ; extra == "testing", pytest-cov ; extra == "testing", pytest-regressions ; extra == "testing", pytest-timeout ; extra == "testing", requests ; extra == "testing" |
| markdownify | 1.2.2 | markitdown-mcp, zotero-mcp-server | beautifulsoup4<5,>=4.9, six<2,>=1.15 |
| markitdown | 0.1.5 | markitdown-mcp | beautifulsoup4, charset-normalizer, defusedxml, magika~=0.6.1, markdownify, requests, azure-ai-documentintelligence; extra == 'all', azure-identity; extra == 'all', lxml; extra == 'all', mammoth~=1.11.0; extra == 'all', olefile; extra == 'all', openpyxl; extra == 'all', pandas; extra == 'all', pdfminer-six>=20251230; extra == 'all', pdfplumber>=0.11.9; extra == 'all', pydub; extra == 'all', python-pptx; extra == 'all', speechrecognition; extra == 'all', xlrd; extra == 'all', youtube-transcript-api~=1.0.0; extra == 'all', pydub; extra == 'audio-transcription', speechrecognition; extra == 'audio-transcription', azure-ai-documentintelligence; extra == 'az-doc-intel', azure-identity; extra == 'az-doc-intel', lxml; extra == 'docx', mammoth~=1.11.0; extra == 'docx', olefile; extra == 'outlook', pdfminer-six>=20251230; extra == 'pdf', pdfplumber>=0.11.9; extra == 'pdf', python-pptx; extra == 'pptx', pandas; extra == 'xls', xlrd; extra == 'xls', openpyxl; extra == 'xlsx', pandas; extra == 'xlsx', youtube-transcript-api; extra == 'youtube-transcription' |
| markitdown | 0.1.6 | zotero-mcp-server | beautifulsoup4, charset-normalizer, defusedxml, magika~=0.6.1, markdownify, requests, azure-ai-contentunderstanding>=1.2.0b1; extra == 'all', azure-ai-documentintelligence; extra == 'all', azure-identity; extra == 'all', lxml; extra == 'all', mammoth~=1.11.0; extra == 'all', olefile; extra == 'all', openpyxl; extra == 'all', pandas; extra == 'all', pdfminer-six>=20251230; extra == 'all', pdfplumber>=0.11.9; extra == 'all', pydub; extra == 'all', python-pptx; extra == 'all', speechrecognition; extra == 'all', xlrd; extra == 'all', youtube-transcript-api~=1.0.0; extra == 'all', pydub; extra == 'audio-transcription', speechrecognition; extra == 'audio-transcription', azure-ai-contentunderstanding>=1.2.0b1; extra == 'az-content-understanding', azure-identity; extra == 'az-content-understanding', azure-ai-documentintelligence; extra == 'az-doc-intel', azure-identity; extra == 'az-doc-intel', lxml; extra == 'docx', mammoth~=1.11.0; extra == 'docx', olefile; extra == 'outlook', pdfminer-six>=20251230; extra == 'pdf', pdfplumber>=0.11.9; extra == 'pdf', python-pptx; extra == 'pptx', pandas; extra == 'xls', xlrd; extra == 'xls', openpyxl; extra == 'xlsx', pandas; extra == 'xlsx', youtube-transcript-api; extra == 'youtube-transcription' |
| markitdown-mcp | 0.0.1a4 | markitdown-mcp | markitdown[all]<0.2.0,>=0.1.1, mcp~=1.8.0 |
| mcp | 1.27.2 | arxiv-mcp-server, zotero-mcp-server | anyio>=4.5, httpx-sse>=0.4, httpx<1.0.0,>=0.27.1, jsonschema>=4.20.0, pydantic-settings>=2.5.2, pydantic<3.0.0,>=2.11.0, pyjwt[crypto]>=2.10.1, python-multipart>=0.0.9, pywin32>=310; sys_platform == 'win32', sse-starlette>=1.6.1, starlette>=0.27, typing-extensions>=4.9.0, typing-inspection>=0.4.1, uvicorn>=0.31.1; sys_platform != 'emscripten', python-dotenv>=1.0.0; extra == 'cli', typer>=0.16.0; extra == 'cli', rich>=13.9.4; extra == 'rich', websockets>=15.0.1; extra == 'ws' |
| mcp | 1.8.1 | markitdown-mcp | anyio>=4.5, httpx-sse>=0.4, httpx>=0.27, pydantic-settings>=2.5.2, pydantic<3.0.0,>=2.7.2, python-multipart>=0.0.9, sse-starlette>=1.6.1, starlette>=0.27, uvicorn>=0.23.1; sys_platform != 'emscripten', python-dotenv>=1.0.0; extra == 'cli', typer>=0.12.4; extra == 'cli', rich>=13.9.4; extra == 'rich', websockets>=15.0.1; extra == 'ws' |
| mdurl | 0.1.2 | zotero-mcp-server | 无 |
| more-itertools | 11.1.0 | zotero-mcp-server | 无 |
| msal | 1.37.0 | markitdown-mcp | requests<3,>=2.0.0, PyJWT[crypto]<3,>=1.0.0, cryptography<51,>=2.5, pymsalruntime<0.21,>=0.20; (python_version >= "3.9" and platform_system == "Windows") and extra == "broker", pymsalruntime<0.21,>=0.20; (python_version >= "3.9" and platform_system == "Darwin") and extra == "broker", pymsalruntime<0.21,>=0.20; (python_version >= "3.9" and platform_system == "Linux") and extra == "broker" |
| msal-extensions | 1.3.1 | markitdown-mcp | msal<2,>=1.29, portalocker<4,>=1.4; extra == "portalocker" |
| multidict | 6.7.1 | arxiv-mcp-server | typing-extensions>=4.1.0; python_version < "3.11" |
| mypy_extensions | 1.1.0 | arxiv-mcp-server | 无 |
| networkx | 3.6.1 | arxiv-mcp-server | asv; extra == "benchmarking", virtualenv; extra == "benchmarking", numpy>=1.25; extra == "default", scipy>=1.11.2; extra == "default", matplotlib>=3.8; extra == "default", pandas>=2.0; extra == "default", pre-commit>=4.1; extra == "developer", mypy>=1.15; extra == "developer", sphinx>=8.0; extra == "doc", pydata-sphinx-theme>=0.16; extra == "doc", sphinx-gallery>=0.18; extra == "doc", numpydoc>=1.8.0; extra == "doc", pillow>=10; extra == "doc", texext>=0.6.7; extra == "doc", myst-nb>=1.1; extra == "doc", intersphinx-registry; extra == "doc", osmnx>=2.0.0; extra == "example", momepy>=0.7.2; extra == "example", contextily>=1.6; extra == "example", seaborn>=0.13; extra == "example", cairocffi>=1.7; extra == "example", igraph>=0.11; extra == "example", scikit-learn>=1.5; extra == "example", iplotx>=0.9.0; extra == "example", lxml>=4.6; extra == "extra", pygraphviz>=1.14; extra == "extra", pydot>=3.0.1; extra == "extra", sympy>=1.10; extra == "extra", build>=0.10; extra == "release", twine>=4.0; extra == "release", wheel>=0.40; extra == "release", changelist==0.5; extra == "release", pytest>=7.2; extra == "test", pytest-cov>=4.0; extra == "test", pytest-xdist>=3.0; extra == "test", pytest-mpl; extra == "test-extras", pytest-randomly; extra == "test-extras" |
| nodeenv | 1.10.0 | pyright | 无 |
| nodejs-wheel-binaries | 24.16.0 | pyright | typing-extensions; python_version < "3.8" |
| numpy | 2.4.6 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| olefile | 0.47 | markitdown-mcp | pytest ; extra == 'tests', pytest-cov ; extra == 'tests' |
| onnxruntime | 1.26.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | flatbuffers, numpy>=1.21.6, packaging, protobuf, sympy; extra == "symbolic", ml_dtypes; extra == "quantization" |
| openapi-pydantic | 0.5.1 | zotero-mcp-server | pydantic (>=1.8) |
| openpyxl | 3.1.5 | markitdown-mcp | et-xmlfile |
| opentelemetry-api | 1.42.1 | zotero-mcp-server | typing-extensions>=4.5.0 |
| packaging | 26.2 | arxiv-mcp-server, fortls, markitdown-mcp, zotero-mcp-server | 无 |
| pandas | 3.0.3 | markitdown-mcp | numpy>=1.26.0; python_version < "3.14", numpy>=2.3.3; python_version >= "3.14", python-dateutil>=2.8.2, tzdata; sys_platform == "win32", tzdata; sys_platform == "emscripten", hypothesis>=6.116.0; extra == "test", pytest>=8.3.4; extra == "test", pytest-xdist>=3.6.1; extra == "test", pyarrow>=13.0.0; extra == "pyarrow", bottleneck>=1.4.2; extra == "performance", numba>=0.60.0; extra == "performance", numexpr>=2.10.2; extra == "performance", scipy>=1.14.1; extra == "computation", xarray>=2024.10.0; extra == "computation", fsspec>=2024.10.0; extra == "fss", s3fs>=2024.10.0; extra == "aws", gcsfs>=2024.10.0; extra == "gcp", odfpy>=1.4.1; extra == "excel", openpyxl>=3.1.5; extra == "excel", python-calamine>=0.3.0; extra == "excel", pyxlsb>=1.0.10; extra == "excel", xlrd>=2.0.1; extra == "excel", xlsxwriter>=3.2.0; extra == "excel", pyarrow>=13.0.0; extra == "parquet", pyarrow>=13.0.0; extra == "feather", pyiceberg>=0.8.1; extra == "iceberg", tables>=3.10.1; extra == "hdf5", pyreadstat>=1.2.8; extra == "spss", SQLAlchemy>=2.0.36; extra == "postgresql", psycopg2>=2.9.10; extra == "postgresql", adbc-driver-postgresql>=1.2.0; extra == "postgresql", SQLAlchemy>=2.0.36; extra == "mysql", pymysql>=1.1.1; extra == "mysql", SQLAlchemy>=2.0.36; extra == "sql-other", adbc-driver-postgresql>=1.2.0; extra == "sql-other", adbc-driver-sqlite>=1.2.0; extra == "sql-other", beautifulsoup4>=4.12.3; extra == "html", html5lib>=1.1; extra == "html", lxml>=5.3.0; extra == "html", lxml>=5.3.0; extra == "xml", matplotlib>=3.9.3; extra == "plot", jinja2>=3.1.5; extra == "output-formatting", tabulate>=0.9.0; extra == "output-formatting", PyQt5>=5.15.9; extra == "clipboard", qtpy>=2.4.2; extra == "clipboard", zstandard>=0.23.0; extra == "compression", pytz>=2020.1; extra == "timezone", adbc-driver-postgresql>=1.2.0; extra == "all", adbc-driver-sqlite>=1.2.0; extra == "all", beautifulsoup4>=4.12.3; extra == "all", bottleneck>=1.4.2; extra == "all", fastparquet>=2024.11.0; extra == "all", fsspec>=2024.10.0; extra == "all", gcsfs>=2024.10.0; extra == "all", html5lib>=1.1; extra == "all", hypothesis>=6.116.0; extra == "all", jinja2>=3.1.5; extra == "all", lxml>=5.3.0; extra == "all", matplotlib>=3.9.3; extra == "all", numba>=0.60.0; extra == "all", numexpr>=2.10.2; extra == "all", odfpy>=1.4.1; extra == "all", openpyxl>=3.1.5; extra == "all", psycopg2>=2.9.10; extra == "all", pyarrow>=13.0.0; extra == "all", pyiceberg>=0.8.1; extra == "all", pymysql>=1.1.1; extra == "all", PyQt5>=5.15.9; extra == "all", pyreadstat>=1.2.8; extra == "all", pytest>=8.3.4; extra == "all", pytest-xdist>=3.6.1; extra == "all", python-calamine>=0.3.0; extra == "all", pytz>=2020.1; extra == "all", pyxlsb>=1.0.10; extra == "all", qtpy>=2.4.2; extra == "all", scipy>=1.14.1; extra == "all", s3fs>=2024.10.0; extra == "all", SQLAlchemy>=2.0.36; extra == "all", tables>=3.10.1; extra == "all", tabulate>=0.9.0; extra == "all", xarray>=2024.10.0; extra == "all", xlrd>=2.0.1; extra == "all", xlsxwriter>=3.2.0; extra == "all", zstandard>=0.23.0; extra == "all" |
| pathable | 0.6.0 | zotero-mcp-server | 无 |
| pathspec | 1.1.1 | arxiv-mcp-server | hyperscan >=0.7 ; extra == "hyperscan", typing-extensions >=4 ; extra == "optional", google-re2 >=1.1 ; extra == "re2" |
| pdfminer.six | 20251230 | markitdown-mcp, zotero-mcp-server | charset-normalizer>=2.0.0, cryptography>=36.0.0, Pillow; extra == "image" |
| pdfplumber | 0.11.9 | markitdown-mcp, zotero-mcp-server | pdfminer.six==20251230, Pillow>=9.1, pypdfium2>=4.18.0 |
| pillow | 12.2.0 | markitdown-mcp, zotero-mcp-server | furo; extra == "docs", olefile; extra == "docs", sphinx>=8.2; extra == "docs", sphinx-autobuild; extra == "docs", sphinx-copybutton; extra == "docs", sphinx-inline-tabs; extra == "docs", sphinxext-opengraph; extra == "docs", olefile; extra == "fpx", olefile; extra == "mic", arro3-compute; extra == "test-arrow", arro3-core; extra == "test-arrow", nanoarrow; extra == "test-arrow", pyarrow; extra == "test-arrow", check-manifest; extra == "tests", coverage>=7.4.2; extra == "tests", defusedxml; extra == "tests", markdown2; extra == "tests", olefile; extra == "tests", packaging; extra == "tests", pyroma>=5; extra == "tests", pytest; extra == "tests", pytest-cov; extra == "tests", pytest-timeout; extra == "tests", pytest-xdist; extra == "tests", trove-classifiers>=2024.10.12; extra == "tests", defusedxml; extra == "xmp" |
| platformdirs | 4.10.0 | arxiv-mcp-server, zotero-mcp-server | 无 |
| propcache | 0.5.2 | arxiv-mcp-server | 无 |
| protobuf | 7.35.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| py-key-value-aio | 0.4.5 | zotero-mcp-server | beartype>=0.20.0, typing-extensions>=4.15.0, aerospike>=16.0.0 ; extra == 'aerospike', azure-data-tables>=12.4.0 ; extra == 'azure-tables', azure-core>=1.29.0 ; extra == 'azure-tables', chdb>=4.1.1 ; extra == 'chdb', diskcache>=5.0.0 ; extra == 'disk', pathvalidate>=3.3.1 ; extra == 'disk', mkdocs>=1.6.0 ; extra == 'docs', mkdocs-material>=9.5.0 ; extra == 'docs', mkdocstrings[python]>=0.30.0 ; extra == 'docs', mkdocstrings-python>=1.10.0 ; extra == 'docs', duckdb>=1.1.1 ; extra == 'duckdb', pytz>=2025.2 ; extra == 'duckdb', aioboto3>=13.3.0 ; extra == 'dynamodb', types-aiobotocore-dynamodb>=2.16.0 ; extra == 'dynamodb', elasticsearch>=8.0.0 ; extra == 'elasticsearch', aiohttp>=3.12 ; extra == 'elasticsearch', aiofile>=3.5.0 ; extra == 'filetree', anyio>=4.4.0 ; extra == 'filetree', google-cloud-firestore>=2.13.0 ; extra == 'firestore', google-auth>=2.24.0 ; extra == 'firestore', keyring>=25.6.0 ; extra == 'keyring', keyring>=25.6.0 ; extra == 'keyring-linux', dbus-python>=1.4.0 ; extra == 'keyring-linux', aiomcache>=0.8.0 ; extra == 'memcached', cachetools>=5.0.0 ; extra == 'memory', pymongo>=4.9.0 ; extra == 'mongodb', opensearch-py[async]>=2.0.0 ; extra == 'opensearch', asyncpg>=0.30.0 ; extra == 'postgresql', pydantic>=2.11.9 ; extra == 'pydantic', redis>=4.3.0 ; extra == 'redis', rocksdict>=0.3.24 ; python_full_version >= '3.12' and extra == 'rocksdb', rocksdict>=0.3.2 ; python_full_version < '3.12' and extra == 'rocksdb', aioboto3>=13.3.0 ; extra == 's3', types-aiobotocore-s3>=2.16.0 ; extra == 's3', valkey-glide>=2.1.0 ; extra == 'valkey', hvac>=2.3.0 ; extra == 'vault', types-hvac>=2.3.0 ; extra == 'vault', cryptography>=45.0.0 ; extra == 'wrappers-encryption' |
| pycparser | 3.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| pydantic | 2.13.4 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | annotated-types>=0.6.0, pydantic-core==2.46.4, typing-extensions>=4.14.1, typing-inspection>=0.4.2, email-validator>=2.0.0; extra == 'email', tzdata; (python_version >= '3.9' and platform_system == 'Windows') and extra == 'timezone' |
| pydantic-settings | 2.14.1 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | pydantic>=2.7.0, python-dotenv>=0.21.0, typing-inspection>=0.4.0, boto3>=1.35.0; extra == 'aws-secrets-manager', types-boto3[secretsmanager]; extra == 'aws-secrets-manager', azure-identity>=1.16.0; extra == 'azure-key-vault', azure-keyvault-secrets>=4.8.0; extra == 'azure-key-vault', google-cloud-secret-manager>=2.23.1; extra == 'gcp-secret-manager', tomli>=2.0.1; extra == 'toml', pyyaml>=6.0.1; extra == 'yaml' |
| pydantic_core | 2.46.4 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | typing-extensions>=4.14.1 |
| pydub | 0.25.1 | markitdown-mcp | 无 |
| pymupdf-layout | 1.27.2.3 | arxiv-mcp-server | PyMuPDF==1.27.2.3, pyyaml, numpy, onnxruntime, networkx |
| pymupdf4llm | 1.27.2.3 | arxiv-mcp-server | pymupdf==1.27.2.3, pymupdf_layout==1.27.2.3, tabulate |
| pyparsing | 3.3.2 | zotero-mcp-server | railroad-diagrams ; extra == "diagrams", jinja2 ; extra == "diagrams" |
| pypdfium2 | 5.9.0 | markitdown-mcp, zotero-mcp-server | 无 |
| pyperclip | 1.11.0 | zotero-mcp-server | 无 |
| pyright | 1.1.411 | pyright | nodeenv>=1.6.0, typing-extensions>=4.1, twine>=3.4.1; extra == "dev", nodejs-wheel-binaries; extra == "nodejs", twine>=3.4.1; extra == "all", nodejs-wheel-binaries; extra == "all" |
| python-dateutil | 2.9.0.post0 | arxiv-mcp-server, markitdown-mcp | six >=1.5 |
| python-dotenv | 1.2.2 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | click>=5.0; extra == "cli" |
| python-multipart | 0.0.32 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| python-pptx | 1.0.2 | markitdown-mcp | Pillow >=3.3.2, XlsxWriter >=0.5.7, lxml >=3.1.0, typing-extensions >=4.9.0 |
| pytokens | 0.4.1 | arxiv-mcp-server | black; extra == "dev", build; extra == "dev", mypy; extra == "dev", pytest; extra == "dev", pytest-cov; extra == "dev", setuptools; extra == "dev", tox; extra == "dev", twine; extra == "dev", wheel; extra == "dev" |
| pyzotero | 1.13.1 | zotero-mcp-server | feedparser>=6.0.12, bibtexparser>=1.4.3,<2.0.0, httpx>=0.28.1, whenever>=0.8.8, click>=8.0.0 ; extra == 'cli', mcp[cli]>=1.0.0 ; python_full_version >= '3.10' and extra == 'mcp' |
| referencing | 0.37.0 | arxiv-mcp-server, zotero-mcp-server | attrs>=22.2.0, rpds-py>=0.7.0, typing-extensions>=4.4.0; python_version < '3.13' |
| requests | 2.33.1 | arxiv-mcp-server | charset_normalizer<4,>=2, idna<4,>=2.5, urllib3<3,>=1.26, certifi>=2023.5.7, PySocks!=1.5.7,>=1.5.6; extra == "socks", chardet<8,>=3.0.2; extra == "use-chardet-on-py3" |
| requests | 2.34.2 | markitdown-mcp, zotero-mcp-server | charset_normalizer<4,>=2, idna<4,>=2.5, urllib3<3,>=1.26, certifi>=2023.5.7, PySocks!=1.5.7,>=1.5.6; extra == "socks", chardet<8,>=3.0.2; extra == "use-chardet-on-py3" |
| rich | 15.0.0 | zotero-mcp-server | ipywidgets (>=7.5.1,<9) ; extra == "jupyter", markdown-it-py (>=2.2.0), pygments (>=2.13.0,<3.0.0) |
| rich-rst | 2.0.1 | zotero-mcp-server | rich>=12.0.0, pygments>=2.0.0, docutils; extra == "docs", rich; extra == "docs", rich_rst; extra == "docs", sphinx; extra == "docs", sphinx_copybutton; extra == "docs", sphinx_rtd_theme; extra == "docs", pytest; extra == "tests", pytest-cov; extra == "tests" |
| rpds-py | 2026.5.1 | arxiv-mcp-server, zotero-mcp-server | 无 |
| sgmllib3k | 1.0.0 | zotero-mcp-server | 无 |
| six | 1.17.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| soupsieve | 2.8.4 | markitdown-mcp, zotero-mcp-server | 无 |
| sse-starlette | 3.4.4 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | starlette>=0.49.1, anyio>=4.7.0, uvicorn>=0.34.0; extra == "examples", fastapi>=0.115.12; extra == "examples", pydantic>=2; extra == "examples", sqlalchemy[asyncio]>=2.0.41; extra == "examples-db", aiosqlite>=0.21.0; extra == "examples-db", uvicorn>=0.34.0; extra == "uvicorn", granian>=2.3.1; extra == "granian", daphne>=4.2.0; extra == "daphne" |
| starlette | 1.2.1 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | anyio<5,>=3.6.2, typing-extensions>=4.10.0; python_version < '3.13', httpx<0.29.0,>=0.27.0; extra == 'full', itsdangerous; extra == 'full', jinja2; extra == 'full', python-multipart>=0.0.18; extra == 'full', pyyaml; extra == 'full' |
| tabulate | 0.10.0 | arxiv-mcp-server | wcwidth; extra == "widechars" |
| typing-inspection | 0.4.2 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | typing-extensions>=4.12.0 |
| typing_extensions | 4.15.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | 无 |
| typing_extensions | 4.16.0 | pyright | 无 |
| uncalled-for | 0.3.2 | zotero-mcp-server | 无 |
| urllib3 | 2.7.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | brotli>=1.2.0; (platform_python_implementation == 'CPython') and extra == 'brotli', brotlicffi>=1.2.0.0; (platform_python_implementation != 'CPython') and extra == 'brotli', h2<5,>=4; extra == 'h2', pysocks!=1.5.7,<2.0,>=1.5.6; extra == 'socks', backports-zstd>=1.0.0; (python_version < '3.14') and extra == 'zstd' |
| uvicorn | 0.49.0 | arxiv-mcp-server, markitdown-mcp, zotero-mcp-server | click>=7.0, h11>=0.8, typing-extensions>=4.0; python_version < '3.11', colorama>=0.4; (sys_platform == 'win32') and extra == 'standard', httptools>=0.8.0; extra == 'standard', python-dotenv>=0.13; extra == 'standard', pyyaml>=5.1; extra == 'standard', uvloop>=0.15.1; (sys_platform != 'win32' and (sys_platform != 'cygwin' and platform_python_implementation != 'PyPy')) and extra == 'standard', watchfiles>=0.20; extra == 'standard', websockets>=10.4; extra == 'standard' |
| watchfiles | 1.2.0 | zotero-mcp-server | anyio>=3.0.0 |
| websockets | 16.0 | zotero-mcp-server | 无 |
| whenever | 0.10.0 | zotero-mcp-server | tzdata>=2020.1 ; sys_platform == 'win32', tzlocal>=4.0 ; sys_platform != 'darwin' and sys_platform != 'linux' |
| xlrd | 2.0.2 | markitdown-mcp | wheel ; extra == 'build', twine ; extra == 'build', sphinx ; extra == 'docs', pytest ; extra == 'test', pytest-cov ; extra == 'test' |
| xlsxwriter | 3.2.9 | markitdown-mcp | 无 |
| yarl | 1.24.2 | arxiv-mcp-server | idna>=2.0, multidict>=4.0, propcache>=0.2.1 |
| youtube-transcript-api | 1.0.3 | markitdown-mcp | defusedxml (>=0.7.1,<0.8.0), requests |
| zotero-mcp-server | 0.5.0 | zotero-mcp-server | bibtexparser<2,>=1.4, fastmcp>=2.14.0, markitdown[pdf], mcp>=1.2.0, pydantic>=2.0.0, python-dotenv>=1.0.0, pyzotero>=1.8.0, requests>=2.28.0, unidecode>=1.3.0, chromadb>=1.0.0; extra == 'all', ebooklib>=0.18; extra == 'all', google-genai>=0.7.0; extra == 'all', openai>=1.0.0; extra == 'all', pymupdf>=1.24.2; extra == 'all', requests>=2.28.0; extra == 'all', sentence-transformers>=2.2.0; extra == 'all', tiktoken>=0.7.0; extra == 'all', chromadb>=1.0.0; extra == 'dev', ebooklib>=0.18; extra == 'dev', google-genai>=0.7.0; extra == 'dev', openai>=1.0.0; extra == 'dev', pymupdf>=1.24.2; extra == 'dev', pytest-asyncio>=0.21; extra == 'dev', pytest-timeout>=2.0.0; extra == 'dev', pytest>=7.0.0; extra == 'dev', requests>=2.28.0; extra == 'dev', ruff>=0.9.0; extra == 'dev', sentence-transformers>=2.2.0; extra == 'dev', tiktoken>=0.7.0; extra == 'dev', ebooklib>=0.18; extra == 'pdf', pymupdf>=1.24.2; extra == 'pdf', requests>=2.28.0; extra == 'scite', chromadb>=1.0.0; extra == 'semantic', google-genai>=0.7.0; extra == 'semantic', openai>=1.0.0; extra == 'semantic', sentence-transformers>=2.2.0; extra == 'semantic', tiktoken>=0.7.0; extra == 'semantic' |


</details>

<details>
<summary>9.11 profile 逐项安装目标：与实际安装区分</summary>


| 系统 | 安装目标 | 分类 | 计划途径 | 现状 |
| --- | --- | --- | --- | --- |
| Mac | git | 版本控制 | brew | 未见该 Formula 实装 |
| Mac | python | 语言运行时 | brew | 未见该 Formula 实装 |
| Mac | zsh | Shell | brew | 未见该 Formula 实装 |
| Mac | fd | 搜索 | brew | 10.5.0 |
| Mac | ripgrep | 搜索 | brew | 15.2.0 |
| Mac | fzf | 交互筛选 | brew | 0.74.4 |
| Mac | zoxide | 导航 | brew | 0.10.0 |
| Mac | starship | 提示符 | brew | 1.26.0 |
| Mac | bat | 预览 | brew | 0.26.1 |
| Mac | jq | JSON | brew | 1.8.2 |
| Mac | neovim | 编辑器 | brew | 0.12.5_1 |
| Mac | uv | Python 管理 | brew | 未见该 Formula 实装 |
| Mac | pixi | 可选环境后端（当前脚本仍强制） | brew | 未见该 Formula 实装 |
| Mac | modules | 环境切换 | brew | 5.7.0 |
| Mac | zsh-fast-syntax-highlighting | Shell 插件 | brew | 1.56 |
| Mac | cmake | 构建 | brew | 未见该 Formula 实装 |
| Mac | make | 构建 | brew | 未见该 Formula 实装 |
| Mac | pkgconf | 构建 | brew | 3.0.7 |
| Mac | autoconf | 构建 | brew | 2.73 |
| Mac | automake | 构建 | brew | 1.19 |
| Mac | libtool | 构建 | brew | 2.6.2 |
| Mac | libvterm | 构建/运行依赖库 | brew | 未见该 Formula 实装 |
| Mac | poppler | 构建/运行依赖库 | brew | 26.10.0 |
| Mac | gnutls | 构建/运行依赖库 | brew | 3.8.13_2 |
| Mac | tree-sitter | 构建/运行依赖库 | brew | 0.27.0 |
| Mac | emacs-app | 编辑器 | cask | 31.1 已核实 |
| Mac | wezterm | 终端 GUI | cask | 已有独立 App；未见 Cask 记录 |
| Fedora | git | 版本控制 | dnf | 2.56.0-1.fc44 |
| Fedora | python3 | 语言运行时 | dnf | 3.14.8-1.fc44 |
| Fedora | zsh | Shell | dnf | 5.9-21.fc44 |
| Fedora | fd-find | 搜索 | dnf | 10.4.2-4.fc44 |
| Fedora | ripgrep | 搜索 | dnf | 15.2.0-1.fc44 |
| Fedora | fzf | 交互筛选 | dnf | 0.74.4-1.fc44 |
| Fedora | zoxide | 导航 | dnf | 0.9.8-2.fc44 |
| Fedora | starship | 提示符 | dnf | 1.24.2-1.fc44 |
| Fedora | bat | 预览 | dnf | 0.26.1-4.fc44 |
| Fedora | jq | JSON | dnf | 1.8.1-3.fc44 |
| Fedora | neovim | 编辑器 | dnf | 未见同名 RPM |
| Fedora | uv | Python 管理 | dnf | 未见同名 RPM；现有独立二进制 0.12.7 |
| Fedora | environment-modules | 环境切换 | dnf | 5.6.2-1.fc44 |
| Fedora | emacs | 编辑器 | dnf | 未见同名 RPM；现有源码 31.1 |
| Fedora | gcc | 编译器 | dnf | 16.2.1-2.fc44 |
| Fedora | gcc-c++ | 编译器 | dnf | 16.2.1-2.fc44 |
| Fedora | make | 构建 | dnf | 4.4.1-12.fc44 |
| Fedora | cmake | 构建 | dnf | 4.3.0-1.fc44 |
| Fedora | pkgconf-pkg-config | 构建 | dnf | 2.5.1-1.fc44 |
| Fedora | autoconf | 构建 | dnf | 2.72-10.fc44 |
| Fedora | automake | 构建 | dnf | 1.18.1-4.fc44 |
| Fedora | libtool | 构建 | dnf | 2.5.4-10.fc44 |
| Fedora | libvterm-devel | 构建/运行依赖库 | dnf | 0.3.3-7.fc44 |
| Fedora | poppler-glib-devel | 构建/运行依赖库 | dnf | 26.01.0-3.fc44 |
| Fedora | libpng-devel | 构建/运行依赖库 | dnf | 1.6.58-1.fc44 |
| Fedora | zlib-devel | 构建/运行依赖库 | dnf | 未见同名 RPM；已装 zlib-ng-compat-devel |
| Fedora | pixi | 环境管理 | dnf 可用则安装，否则官方二进制 | 当前独立二进制 0.78.0 |

Deck 的全部目标已经逐项列在第 4.1 节；这个安装器还会恢复锁文件、编译 Emacs/Modules。Zsh 插件目标见第 6 节。

</details>

## 10. 审计依据与复核方式

- `brew list`、Cellar 的 `INSTALL_RECEIPT.json`、Caskroom 记录、`pkgutil` 收据。
- Fedora 的 `rpm -q`、`rpm -qf`、`rpm --requires` 与 Intel 模块实际目标。
- `Software/apps/*/*/pixi.toml`、`pixi.lock`、已安装环境的 `conda-meta/*.json`。
- GCC 实际包装脚本、`gcc --version`、`-dumpmachine`、`-print-sysroot`。
- HDF5 的 `libhdf5.settings`、`mpichversion`、`ompi_info`、Emacs 构建选项。
- Zsh 插件 Git HEAD、Emacs 包描述文件、grammar 文件名与 `uv tool list`。

清单只包含软件信息，不复制机器密钥或私有 Shell 配置。收据可以证明安装来源，但不能凭它宣称程序所有功能均正常；本文保留了未核实项，便于下一轮逐项决定。