# Emacs 快捷键指南

本文档介绍这套 Emacs 配置中最常用的快捷键，包括自定义键位、Emacs
内置键位和插件提供的模式内键位。实际绑定以当前缓冲区的 major mode、
minor mode 以及已安装插件为准。

要一份不做取舍的完整清单——每一条生效的绑定、对应命令和中文说明，另附
键位冲突审查——见 [KEYBINDINGS-FULL.md](KEYBINDINGS-FULL.md)。

## 按键记号

| 记号 | 含义 |
| --- | --- |
| `C-x` | 按住 Control，再按 x |
| `M-x` | 按住 Meta/Alt，再按 x；macOS 通常是 Option |
| `S-x` | 按住 Shift，再按 x |
| `SPC` | 空格键 |
| `RET` | 回车键 |
| `TAB` | Tab 键 |
| `C-x C-f` | 先按 Control+x，再按 Control+f |

模式内键位优先于全局键位。例如全局的 `C-c C-c` 是重新编译，但在
Python 缓冲区中会发送整个 Python 缓冲区，在 LaTeX 中则会执行 AUCTeX
命令。

## Helix 模态编辑

本配置启用了 [helix-mode](https://github.com/mgmarlow/helix-mode)，普通
文件缓冲区默认处于 **normal 状态**（模式行显示 `helix[N]`，光标为方块），
`i`/`a` 进入 **insert 状态**（`helix[I]`，光标为竖线），`ESC` 回到
normal；在 macOS 上还会让 Squirrel 保持为当前输入法并切回 Rime 英文。
insert 状态下依次按 `jk`（间隔 0.2 秒内）等价于 ESC，图形界面和
终端都可用——终端下 ESC 无法与 Meta 前缀区分，`jk` 是唯一可靠的退出方式。
`j` 后若 0.2 秒内没有按 `k`，被暂存的 `j` 会照常插入。

它只是一层键位映射，不是 Evil 那样的完整模拟：**没有被 Helix 占用的键仍
然走原来的 Emacs 绑定**。因此 normal 状态下 `C-x`、`M-x` 和整个 `C-c`
前缀（`C-c r`、`C-c c`、`C-c g b`、`C-c e l` 等）都照常可用。上游把
`C-c` 绑成了注释，本配置已解绑以保住前缀——注释请用 Emacs 原生的 `M-;`。

Helix 是"先选择后操作"：`w` 不只是移动，还会把整个词选中，`d` 删除的是
当前选区。

| 快捷键 | 功能 |
| --- | --- |
| `h` `j` `k` `l` | 左/下/上/右移动 |
| `w` `e` `b` | 下一词首 / 词尾 / 上一词（大写为 WORD） |
| `f` `t` `F` `T` | 跳到 / 跳到之前 某字符，`M-.` 重复 |
| `x` | 选中整行 |
| `v` | 开始选择 |
| `M-o` `M-i` | 按语法树扩大 / 缩小选区（需 tree-sitter） |
| `d` `y` `p` | 删除 / 复制选区，粘贴 |
| `r` `R` | 用一个字符替换选区 / 用剪贴板内容替换选区 |
| `o` `O` | 下方 / 上方插入新行并进入 insert |
| `u` | 撤销 |
| `/` `?` `n` `N` | 向后 / 向前搜索，继续搜索 |
| `s` `C` `,` | 选区内正则建多光标 / 选中下一个相同项 / 退出多光标 |
| `g` 前缀 | `gg` 文件头、`ge` 文件尾、`gh` 行首、`gl` 行尾、`gs` 首个非空白、`gd` 定义、`gr` 引用、`gw` 跳词（Avy） |
| `C-w` 前缀 | `C-w v/s` 分屏、`C-w h/j/k/l` 切窗口、`C-w q` 关闭、`C-w o` 只留当前 |
| `SPC` 前缀 | `SPC f` 项目内找文件、`SPC b` 项目缓冲区、`SPC j` 切项目、`SPC /` 项目内搜索 |
| `:` | 命令行，如 `:write`、`:quit` |
| `C-f` `C-b` | 翻页 |

Magit、Dired、vterm、PDF、compilation 等自带单键操作的缓冲区不启用
Helix（见 `my-helix-exempt-modes`），在那里一切照旧。`M-x helix-mode`
可全局开关 Helix。

## 随时可用的帮助

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-g` | 取消当前命令、退出提示或关闭补全菜单 | Emacs |
| `ESC` | 退出当前操作或递归编辑 | 自定义配置 |
| `C-h k` | 输入一个快捷键，查看它调用的命令和说明 | Emacs/Helpful |
| `C-h w` | 输入命令名，查找它绑定在哪些按键上 | Emacs |
| `C-h a` | 按关键词搜索命令 | Emacs |
| `C-h b` | 显示当前缓冲区所有有效键位 | Emacs |
| `C-h m` | 查看当前 major/minor mode 及主要键位 | Emacs |
| `C-h f` | 查看函数说明 | Helpful（安装后） |
| `C-h v` | 查看变量说明 | Helpful（安装后） |
| `C-h x` | 查看交互命令说明 | Helpful（安装后） |
| `C-h B` | 搜索当前模式和次模式的键位（**不含全局键位**） | Embark（安装后） |
| `C-u C-h B` | 同上，并且包含全局键位 | Embark（安装后） |
| `C-c m` | 搜索并执行当前 major/minor mode 提供的命令 | Consult |

不知道某个功能叫什么时，先用 `C-h a` 搜索关键词；知道命令名后，用
`C-h w` 查快捷键。

`C-h B` 默认**不列全局键位**，只列当前模式和次模式的，所以 `C-x t <tab>`
这类挂在全局的键在里面找不到。要连全局一起看，按 `C-u C-h B`；要看全部
（含所有前缀，不可搜索但最完整），用 `C-h b`。

## 文件和缓冲区

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-x C-f` | 打开文件；文件不存在时创建新缓冲区 | Emacs |
| `C-x d` | 打开目录管理器 Dired | Emacs |
| `C-x C-s` | 保存当前文件 | Emacs |
| `C-x s` | 询问并保存所有已修改文件 | Emacs |
| `C-x k` | 关闭当前缓冲区 | Emacs |
| `C-x K` | 关闭所有用户缓冲区，保留 `*` 开头的系统缓冲区 | 自定义配置 |
| `C-x b` | 搜索并切换缓冲区 | Consult |
| `C-x 4 b` | 在另一个窗口中切换缓冲区 | Consult |
| `C-x C-r` | 从最近访问的文件中选择并打开 | Consult |
| `C-c r` | 从磁盘重新载入当前文件 | 自定义配置 |
| `C-c d` | 跳到 `*scratch*` 草稿缓冲区，再按一次返回 | 自定义配置 |
| `C-x f` | 修改当前缓冲区的 `fill-column`；不是打开文件 | Emacs |

配置会自动恢复上次光标位置，并把最近文件、历史记录、自动保存和备份
保存在 `~/.emacs.d/var/` 下。

`C-c d` 在任何缓冲区都能直接跳到 `*scratch*`：它被关掉过也会按
`initial-major-mode` 重新建出来。人已经在 `*scratch*` 里时再按一次就回到跳进来
之前的那个缓冲区。加前缀 `C-u C-c d` 则在另一个窗口显示草稿缓冲区，当前窗口不动。

`C-x K` 一次关掉所有用户缓冲区：名字以 `*` 或空格开头的算系统缓冲区（`*scratch*`、
`*Messages*`、各种日志和 REPL），会被留下，其余的文件缓冲区全部关闭；有未保存
改动的文件缓冲区在关闭前照常询问。

这个键放在一张覆盖键表里（`emulation-mode-map-alists`），优先级高于主模式、次
要模式和 Helix 的模式映射，所以在 Magit、Dired、vterm、PDF 等自己占用大量单键
的缓冲区里同样有效。

## 基础编辑

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-SPC` | 设置标记，开始选择区域 | Emacs |
| `C-w` | 剪切选中区域 | Emacs |
| `M-w` | 复制选中区域 | Emacs |
| `C-y` | 粘贴最近一次剪切/复制的内容 | Emacs |
| `M-y` | 浏览剪切环并选择要粘贴的内容 | Consult |
| `C-/` | 撤销 | Emacs |
| `M-q` | 按 `fill-column` 重新排版当前段落 | Emacs |
| `C-a` / `C-e` | 移动到行首/行尾 | Emacs |
| `M-<` / `M->` | 移动到缓冲区开头/末尾 | Emacs |

默认 `fill-column` 是 88。它只影响 `M-q`、自动换行提示等排版功能，
不会强制截断代码行。

## 搜索和跳转

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-s` | 在当前缓冲区按行搜索 | Consult |
| `M-s r` | 使用 ripgrep 搜索当前项目内容 | Consult |
| `M-s f` | 在目录中搜索文件 | Consult |
| `M-g g` | 跳转到指定行 | Consult |
| `M-g i` | 按当前文件中的函数、类、章节等符号跳转 | Consult/Imenu |
| `M-.` | 跳转到光标处符号的定义 | Emacs Xref/Eglot |
| `M-?` | 查找光标处符号的所有引用 | Emacs Xref/Eglot |
| `M-,` | 返回跳转前的位置 | Emacs Xref |

`M-.` 和 `M-?` 的准确性取决于语言服务器。状态栏出现
`[eglot:项目名]` 时，说明当前缓冲区正在使用 LSP。

## 窗口管理

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
窗口操作全部使用 Emacs 内置键位，没有自定义别名。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-x o` | 轮换到下一个窗口 | Emacs |
| `S-方向键` | 按方向切换窗口 | Windmove |
| `C-x 2` | 上下分割窗口 | Emacs |
| `C-x 3` | 左右分割窗口 | Emacs |
| `C-x 0` | 关闭当前窗口 | Emacs |
| `C-x 1` | 只保留当前窗口 | Emacs |
| `C-x \|` | 两窗口布局顺时针旋转 | 自定义配置 |
| `C-x \` | 两窗口布局逆时针旋转 | 自定义配置 |

两个窗口时 `C-x o` 最省事；窗口多了用 `S-方向键` 直接指方向。

早先这里还有 `C-c h/j/k/l` 和 `C-c w v/s/d/o`，与上面的键位完全重复，
已经删掉——`C-c` 加单个字母是留给用户的稀缺位置，不该花在这里。

`S-方向键` 来自 `windmove-mode`，它是次模式，优先级高于所有主模式：
在 Org 缓冲区里 `S-<left>` 是切换窗口，不是切换 TODO 状态。Org 为此
另外提供了 `C-c <left>`、`C-c <right>`、`C-c <up>`、`C-c <down>`，
功能完全相同。

语言服务器的命令用 `C-c s` 前缀，是为了不让 `C-c l` 这类单键被前缀键
吃掉——前缀键会让同名的单键在该模式下按不出来。

## 补全菜单

### 正文补全：Corfu

Corfu 显示语言服务器、major mode 和 Cape 提供的候选。

| 快捷键 | 功能 |
| --- | --- |
| `TAB` | 接受当前候选 |
| `RET` | 接受当前候选 |
| `C-n` / `M-n` / `↓` | 选择下一个候选 |
| `C-p` / `M-p` / `↑` | 选择上一个候选 |
| `M-d` | 显示候选文档 |
| `C-g` | 关闭补全菜单 |

补全菜单打开时，`C-n` 和 `C-p` 控制候选列表。如果需要移动正文行，
先按 `C-g` 关闭菜单，再使用 `C-n` 或 `C-p`。

### 底部输入区补全：Vertico

`M-x`、`C-x C-f`、`C-x b` 等命令在 minibuffer 中使用 Vertico。

| 快捷键 | 功能 |
| --- | --- |
| `C-n` / `↓` | 选择下一个候选 |
| `C-p` / `↑` | 选择上一个候选 |
| `TAB` | 补全或插入当前候选 |
| `RET` | 确认选择 |
| `C-g` | 取消并返回编辑器 |
| `C-.` | 对当前候选执行 Embark 操作 |
| `C-;` | 执行 Embark 推荐操作 |

## 项目管理

Emacs 内置 Project 使用 `C-x p` 作为前缀。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-x p p` | 切换项目 | Emacs Project |
| `C-x p f` | 在项目中查找文件 | Emacs Project |
| `C-x p d` | 在项目中查找目录 | Emacs Project |
| `C-x p b` | 切换到项目缓冲区 | Emacs Project |
| `C-x p e` | 在项目根目录打开 Eshell | Emacs Project |
| `C-x p c` | 编译项目 | Emacs Project |
| `C-x p k` | 关闭项目的所有缓冲区 | Emacs Project |
| `C-x p !` | 在项目根目录运行同步 shell 命令 | Emacs Project |
| `C-x p &` | 在项目根目录运行异步 shell 命令 | Emacs Project |
| `C-c t` | 打开或关闭 Treemacs 项目树 | Treemacs（安装后） |

运行 `M-x project-switch-project` 后，还可以按提示选择查找文件、ripgrep、
目录、Eshell、Magit 或编译。

## Dired 目录管理

用 `C-x d` 打开 Dired，或者用 `C-x C-f` 选择一个目录。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `RET` | 打开光标处文件或目录 | Dired |
| `^` | 返回上一级目录 | Dired |
| `g` | 刷新目录 | Dired |
| `TAB` | 展开/收起子目录 | Dired Subtree（安装后） |
| `m` | 标记文件 | Dired |
| `u` | 取消标记 | Dired |
| `d` | 标记为待删除 | Dired |
| `x` | 执行所有待删除标记 | Dired |
| `C` | 复制文件 | Dired |
| `R` | 移动或重命名文件 | Dired |
| `D` | 立即删除文件 | Dired |
| `+` | 创建目录 | Dired |
| `q` | 关闭 Dired 窗口 | Dired |
| `C-c o` | 在 Finder/Dolphin 中显示光标处文件 | 自定义配置 |

`D` 和 `x` 会删除文件，执行前应确认目标是否正确。

`C-c o` 在任何缓冲区都可用：在 Dired 里定位光标处的条目，在文件缓冲区里定位
该文件，其他情况打开 `default-directory`。加前缀 `C-u C-c o` 则直接打开文件
所在目录，而不是在父目录里选中它。它放在覆盖键表里，因此 Org、Markdown、
vterm、Helix 模态状态等自己占用 `C-c o` 的地方也一样生效。

## 编译和诊断

| 快捷键 | 功能 | 条件 |
| --- | --- | --- |
| `C-c c` | 输入并运行编译命令 | 全局 |
| `C-c C-c` | 重新运行上一次编译命令 | 普通缓冲区 |
| `M-n` | 跳转到下一个 Flymake 诊断 | Flymake 缓冲区 |
| `M-p` | 跳转到上一个 Flymake 诊断 | Flymake 缓冲区 |
| `C-c ! l` | 显示当前缓冲区诊断 | Flymake 缓冲区 |
| `C-c ! p` | 显示整个项目诊断 | Flymake 缓冲区 |

编译窗口会自动滚动到第一个错误。再次编译时，配置会自动终止旧编译
进程，并且不会重复询问是否保存缓冲区。

## Eglot 与语言服务器

`M-x my-install-packages` 会安装 Python、C、C++、Bash、JSON、YAML、
Markdown 和 Markdown Inline 共八套 grammar。普通主模式会自动迁移为
`python-ts-mode`、`c-ts-mode`、`c++-ts-mode`、`bash-ts-mode`、
`json-ts-mode` 和 `yaml-ts-mode`；统一使用最高的 Tree-sitter 着色级别。
grammar 尚未装好时会先使用传统模式，不影响 Fedora 新机首次打开文件。

只想补装 grammar 时可运行 `M-x my-install-tree-sitter-grammars`。配置使用
Emacs 31 内置且固定版本的 grammar 配方，不另行维护 URL 或 commit。

以下键位只在 Eglot 正在管理当前缓冲区时生效。

| 快捷键 | 功能 |
| --- | --- |
| `C-c s a` | 显示可用的代码操作 |
| `C-c s r` | 重命名当前符号及其引用 |
| `C-c s f` | 使用语言服务器格式化整个缓冲区 |
| `C-c s d` | 打开光标处符号的文档 |
| `C-c s s` | 搜索语言服务器提供的项目符号 |
| `C-c s q` | 关闭当前语言服务器 |
| `M-.` | 跳转到定义 |
| `M-?` | 查找引用 |
| `M-,` | 返回跳转前的位置 |

配置会在相应服务器存在时自动启动：Python 依次支持 BasedPyright、Pyright
和 pylsp，C/C++ 支持 clangd 或 ccls，Bash、JSON、YAML 与 Fortran 分别支持
`bash-language-server`、VS Code JSON Language Server、
`yaml-language-server` 和 `fortls`。没有安装服务器时仍可使用相应主模式，
不会产生启动错误。

在新机器上可先运行 `M-x my-development-environment-report`，集中检查 Emacs
版本、Tree-sitter runtime、八套 grammar、各语言服务器及 Fortran 编译器。

### Fedora 准备

配置没有写死 Homebrew 路径，macOS 和 Fedora 都从 `PATH` 找语言服务器；
`~/.local/bin` 会由 Emacs 主动加入 `PATH`。Fedora 上先准备 grammar 编译器与
Fortran 工具链：

```sh
sudo dnf install gcc gcc-c++ gcc-gfortran git
uv tool install --upgrade fortls
```

然后启动 Emacs，运行 `M-x my-install-packages`。其他语言服务器仍是可选项，
缺哪个只会让相应缓冲区不自动启动 Eglot。Fedora 应使用带 Tree-sitter 支持的
Emacs 31 构建；诊断报告中的 `Tree-sitter runtime` 应显示 `OK`。

## Python

以下键位默认在 `python-ts-mode` 中生效；手动进入传统 `python-mode` 时也相同。

| 快捷键 | 功能 |
| --- | --- |
| `C-c C-c` | 把整个缓冲区发送到 Python 解释器 |
| `C-c C-r` | 把选中区域发送到 Python 解释器 |
| `C-c C-z` | 切换到 Python 解释器缓冲区 |

格式化命令目前没有固定快捷键，可通过 `M-x ruff-format-buffer` 或
`M-x black-format-buffer` 调用；前提是对应程序已安装。

### Jupyter Notebook：Code Cells + Jupytext

运行 `M-x my-install-packages` 安装 `code-cells`，并确保命令行可找到
Jupytext（推荐 `uv tool install jupytext`）。打开含 `# %%` 或 `# In[]:`
单元格标记的 Python 文件时会自动启用 `code-cells-mode`；普通 Python 文件
不受影响。

推荐使用配对文件，而不是长期直接编辑 `.ipynb`：

1. 打开 `.ipynb`，运行 `M-x my-jupytext-pair-notebook`，生成对应的
   `py:percent` 脚本。
2. 在 Emacs 中编辑生成的 `.py` 文件，用 `# %%` 新建代码单元，或用
   `# %% [markdown]` 新建 Markdown 单元。
3. 用下面的单元格命令执行和移动；保存后运行 `C-c % j`，把最新内容同步
   回 `.ipynb`。配对的 `.ipynb` 会保留已有输出。

| 快捷键 | 功能 |
| --- | --- |
| `C-c C-c` | 执行当前单元格；只在 `code-cells-mode` 中覆盖“执行整个缓冲区” |
| `C-c % e` | 执行当前单元格 |
| `C-c % s` | 执行当前单元格并移动到下一格 |
| `C-c % a` | 执行当前单元格及其上方所有单元格 |
| `C-c % p` / `C-c % n` | 移动到上一个 / 下一个单元格 |
| `C-c % P` / `C-c % N` | 把当前单元格上移 / 下移 |
| `C-c % d` | 复制当前单元格 |
| `C-c % j` | 用 Jupytext 同步当前配对文件 |

也可以直接打开 `.ipynb`；`code-cells` 会通过 Jupytext 把它临时显示成脚本。
但这种方式保存时会清除 Notebook 的输出，因此只适合不需要保留输出的文件。
从任意带单元格标记的脚本生成 Notebook，可运行
`M-x code-cells-write-ipynb`。

## C、C++ 与 Fortran

C/C++ 和 Fortran 没有额外的语言专属自定义键位，主要使用 Eglot 的
通用键位：

- C/C++ 语言服务器：`clangd`
- Fortran 语言服务器：`fortls`
- Fortran 自由格式：`.f90/.F90`、`.f95/.F95`、`.f03/.F03`、
  `.f08/.F08`、`.f18/.F18`，使用内置 `f90-mode`
- Fortran 固定格式：`.f/.F`、`.for/.FOR`、`.ftn/.FTN`、`.f77/.F77`，
  使用内置 `fortran-mode`
- 定义跳转：`M-.`
- 查找引用：`M-?`
- 重命名：`C-c s r`
- 格式化：`C-c s f`

Emacs 31.1 目前没有内置 `fortran-ts-mode`，因此 Fortran 有意保留上述两个
内置传统模式；语义补全、诊断与跳转由 Emacs 31 自带的 Eglot 配合 `fortls`
提供，而不是引入来源和维护状态不明确的第三方 TS 主模式。

## LaTeX 与 AUCTeX

以下键位只在 AUCTeX 的 `LaTeX-mode` 中生效。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-c` | 执行主 TeX 命令；默认是 `LaTeXMk` | AUCTeX |
| `C-c C-v` | 查看生成的 PDF | AUCTeX |
| `C-c C-e` | 插入 LaTeX 环境 | AUCTeX |
| `C-c C-s` | 插入章节命令 | AUCTeX |
| `C-c C-m` | 插入 LaTeX 宏 | AUCTeX |
| ``C-c ` `` | 跳转到下一个 TeX 错误 | AUCTeX |
| `C-c ]` | 插入文献引用 | Citar（安装并加载后） |

如果 Citar 未安装或尚未接管该键，AUCTeX 默认用 `C-c ]` 关闭当前
LaTeX 环境。

## Org mode

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c a` | 打开 Org Agenda | 自定义配置/Org |
| `C-c n` | 打开 Org Capture | 自定义配置/Org |
| `TAB` | 展开或折叠当前标题 | Org |
| `S-TAB` | 循环整个文档的折叠状态 | Org |
| `C-c C-t` | 切换 TODO 状态 | Org |
| `C-c C-s` | 设置计划时间 | Org |
| `C-c C-d` | 设置截止时间 | Org |
| `C-c C-o` | 打开光标处链接 | Org |
| `C-c C-c` | 执行当前上下文操作 | Org |
| `M-RET` | 插入同级标题或列表项 | Org |
| `M-S-RET` | 插入带 TODO 状态的标题 | Org |

Capture 模板中可选择任务、研究笔记和会议笔记。

## Markdown

Emacs 31 用内置 `markdown-ts-mode` 打开 `.md`、`.markdown`、`.mdx` 等文件。
它同时支持 CommonMark 和常用 GFM 扩展，不再区分 `markdown-mode` 与
`gfm-mode`。首次安装时，`M-x my-install-packages` 会同时安装 `markdown`、
`markdown-inline` 两套 Tree-sitter grammar，以及 `markdown-ts-appear`。

打开文件时自动生效：按语法树着色、软换行（第 88 列）、拼写与行文检查、
本地图片显示，以及 `markdown-ts-appear` 的“阅读时渲染、光标处显示源码”。

折行只改变显示，不会往文件里插入换行符，所以 diff 不受影响。宽度取自
`fill-column`（默认 88），用 `C-x f` 可为当前缓冲区改成别的值，立即生效。
窗口比该宽度还窄时，按窗口边缘折行。

### 折叠与浏览

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `TAB` | 折叠或展开光标处标题（在标题行上按） | markdown-ts-mode |
| `M-g i` | 按标题跳转，标题层级以 `/` 分隔 | Consult/Imenu |
| `C-c C-n` / `C-c C-p` | 跳到下一个/上一个标题 | markdown-ts-mode |
| `C-c C-f` / `C-c C-b` | 跳到同级的下一个/上一个标题 | markdown-ts-mode |
| `C-c C-u` | 跳到上一级标题 | markdown-ts-mode |
| `M-<up>` / `M-<down>` | 上移/下移当前标题子树或列表项 | markdown-ts-mode |
| `M-<left>` / `M-<right>` | 提升/降低当前标题或列表项 | markdown-ts-mode |

### 结构与编辑

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `RET` | 延续列表或引用上下文；空列表项再次回车退出 | markdown-ts-mode |
| `M-RET` | 插入下一个列表项 | markdown-ts-mode |
| `C-c C-c` | 切换当前任务列表勾选框 | markdown-ts-mode |
| `C-c C-r` | 重新编号当前有序列表 | markdown-ts-mode |
| `C-c C-x C-f` | 选择粗体、斜体、删除线或行内代码 | markdown-ts-mode |
| `C-c C-,` | 选择插入代码块、引用、分隔线或表格 | markdown-ts-mode |

### 代码块

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-v n` / `C-c C-v p` | 跳到下一个/上一个代码块 | markdown-ts-mode |
| `TAB` | 在代码块语言的模式中缩进 | markdown-ts-mode |
| `M-q` | 按代码块语言的规则整理当前段落 | markdown-ts-mode |
| `M-.` | 在代码块语言上下文中跳转定义 | markdown-ts-mode |

围栏内的代码按语言着色。装了对应的 tree-sitter 语法后自动改用
`*-ts-mode`，无需离开 Markdown 缓冲区；缩进、填充和跳转会直接使用该语言
模式的上下文。

### 即时渲染与公式

`markdown-ts-appear` 默认隐藏 `**`、链接地址、围栏等标记，并把标题、引用、
callout、代码标签和表格显示成阅读形态。光标进入最小语法元素时只展开该元素
的真实源码，移开后立即恢复渲染，因此不再需要手动切换编辑/预览模式。

`$...$` 与 `$$...$$` 由 MathJax 和 Node 异步渲染成 SVG；光标进入公式时显示
源码，移开后重新渲染。公式预览只在图形界面且支持 SVG 时启用，终端中其余
Markdown 功能照常工作。

### 显示开关

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-x C-v` | 显示或隐藏内联图片 | markdown-ts-mode |
| `C-c C-x RET` | 隐藏或显示 Markdown 标记 | markdown-ts-mode |

图片默认打开就显示，宽度自动限制在当前窗口内；只读取本地文件，不会因为
打开文档而访问远程图片。

### 表格上下文

进入表格后会自动启用一组上下文键：`TAB` / `S-TAB` 移动单元格，`RET` /
`S-RET` 移动行，`M-方向键` 移动行列，`M-S-方向键` 插入或删除行列，
`C-c C-c` 对齐整张表，`C-c C-t a` 调整当前列对齐，`C-c C-t t` 转置表格。

## Git 与 Magit

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-x g` | 打开当前项目的 Magit 状态页 | 自定义配置/Magit |
| `C-c g b` | 显示当前行最后由谁修改 | 自定义配置/Magit |

进入 Magit 状态页后：

| 快捷键 | 功能 |
| --- | --- |
| `g` | 刷新状态 |
| `TAB` | 展开或收起当前区块 |
| `s` | 暂存光标处文件、区块或改动 |
| `u` | 取消暂存 |
| `c` | 打开提交命令菜单；通常再按 `c` 创建提交 |
| `P` | 打开推送菜单；通常再按 `p` 推送当前分支 |
| `F` | 打开拉取菜单；通常再按 `p` 拉取当前分支 |
| `b` | 打开分支菜单 |
| `l` | 打开日志菜单 |
| `d` | 打开差异菜单 |
| `q` | 关闭 Magit 状态页 |

Magit 的大写前缀有意义，例如推送使用大写 `P`，拉取使用大写 `F`。

## 终端

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c v` | 在当前窗口打开 vterm | 自定义配置/vterm |
| `C-c V` | 在另一个窗口打开 vterm | 自定义配置/vterm |

vterm 只有在插件及本机动态模块依赖安装成功后才可用。

## 编程智能体（agent-shell）

agent-shell 通过 ACP 协议驱动 Claude 等编程智能体，对话直接呈现在普通
缓冲区里，可以照常搜索和复制。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c A` | 打开当前项目的智能体会话，没有则新建 | 自定义配置 |
| `RET` | 发送当前输入 | agent-shell |
| `M-J` | 换行但不发送 | agent-shell |
| `C-c C-c` | 打断正在进行的回答 | agent-shell |
| `C-c C-v` | 选择模型 | agent-shell |
| `C-c C-m` | 选择会话模式 | agent-shell |
| `C-<tab>` | 在会话模式之间循环 | agent-shell |

`C-c A` 之外的入口留在 `M-x`：`agent-shell-new-shell` 强制新建会话，
`agent-shell-resume-session` 恢复此前的会话。

使用前需要单独安装 Claude 的 ACP 适配器，它不是 Emacs 插件：

```sh
npm install -g @agentclientprotocol/claude-agent-acp
```

认证沿用 `claude` 命令行已登录的订阅，无需另配 API key。

## 浏览器（embr）

embr 用无头 Chromium 渲染网页，把画面贴进普通缓冲区。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c b b` | 打开 embr，并提示输入网址或搜索词 | 自定义配置 |
| `C-c b i` | 用一次性的隐身会话打开网址 | 自定义配置/embr |
| `C-c b ?` | 查看 embr 已安装了哪些组件 | 自定义配置/embr |
| `C-c C-l` | 在 embr 缓冲区内输入新的网址或搜索词 | 自定义配置/embr |
| `C-c C-c` | 打开 embr 的命令菜单 | 自定义配置/embr |
| `C-c C-c o` | 同 `C-c C-l`，从命令菜单进入 | embr |
| `C-c C-c ?` | 列出全部浏览器键位 | embr |

`M-x embr-browse` 本身不接受网址，只会打开 `embr-home-url`；`C-c b b`
是把它和 `embr-navigate` 串起来的封装，加前缀参数（`C-u C-c b b`）则
只切回浏览器不提示。

`URL/Search:` 提示符接受两种输入：像网址的（`example.com`、
`https://…`）直接访问，其余当作搜索词交给 DuckDuckGo。提示符带历史
补全，上下键可翻已访问过的地址；`C-u C-c C-l` 清空这份历史。

embr 默认把命令菜单放在 `C-c`、把输入网址放在 `C-l`。本配置把菜单移到
`C-c C-c`、输入网址移到 `C-c C-l`，好让 `C-l` 保持 Emacs 原本的
`recenter-top-bottom`。一个键不能既是命令又是前缀，所以这两处必须一起
改；菜单键由 `embr-dispatch-key` 控制。

在 embr 缓冲区内，其余按键基本都转发给网页，全局键位不再生效；`C-x`、
`M-x` 保留给 Emacs。鼠标左键点击顶部的地址栏，会复制当前网址并直接进入
`URL/Search:` 提示符。缓冲区外任意位置的网址也可以直接点击打开
（`goto-address`），Org、帮助、编译输出里的链接同样会走 embr。

配置使用开源的 Playwright Chromium 引擎。**每台机器都要各跑一次**
`M-x my-browser-setup`：它用 uv 在 `~/.local/share/embr/.venv` 建立
Python 环境并下载浏览器，都在仓库之外。前提是装好 uv，除此之外不依赖
系统上任何一个 python3——uv 会自己下载对应版本的 CPython，macOS 和
Linux 因此用的是同一个解释器。重复执行即更新。

显示模式按机器自动判断：装了 Xvfb 的 Linux 用 `headed-offscreen`，
macOS 和没有 Xvfb 的机器用无头模式。无头模式下网页没有滚动条，也装不了
uBlock Origin 之类的扩展——它们都要先在有界面的浏览器里启用一次。两种
模式下都可用的广告拦截是域名黑名单：`M-x embr-install-or-update-blocklist`，
它与引擎无关，用 `M-x embr-remove-blocklist` 移除。

## 其他常用命令

这些命令没有固定快捷键，通过 `M-x` 调用：

| 命令 | 功能 |
| --- | --- |
| `my-install-packages` | 安装插件及八套 Tree-sitter grammar |
| `my-install-tree-sitter-grammars` | 只安装缺失的 Tree-sitter grammar |
| `my-development-environment-report` | 检查 grammars、语言服务器和编译器 |
| `my-browser-setup` | 用 uv 建立/更新 embr 的 Python 环境和浏览器 |
| `eglot` | 手动为当前项目启动语言服务器 |
| `eglot-reconnect` | 重新连接当前语言服务器 |
| `eglot-stderr-buffer` | 查看语言服务器错误输出 |
| `eglot-events-buffer` | 查看 Eglot 与语言服务器的通信记录 |
| `magit-status` | 打开 Magit 状态页 |
| `vterm` | 打开 vterm |
| `hl-todo-mode` | 切换 TODO/FIXME 等标记高亮 |
| `writegood-mode` | 切换英文写作检查 |

## 如何确认真实绑定

插件版本和 major mode 可能改变局部键位。遇到文档与实际行为不一致时，
以 Emacs 当前显示为准：

1. 按 `C-h k`，再按想检查的快捷键。
2. 按 `C-h m` 查看当前模式说明。
3. 按 `C-h b` 查看当前缓冲区的完整键位表。
4. 按任意前缀后稍等，例如 `C-c` 或 `C-x p`，Which-key 会列出可用后续键。

### Which-key 提示放不下时

`C-c` 之后的候选往往不止一屏，底部会显示类似 `1/3` 的页码。

| 快捷键 | 功能 |
| --- | --- |
| `C-c <f5>` | 进入翻页模式，随后 `n` 下一页、`p` 上一页 |
| `C-c C-h` | 改用可搜索的列表：直接输入命令名或关键词过滤 |

翻页模式里还可以按 `u` 退掉刚才按下的那个前缀键、`d` 显示命令文档、
`a` 放弃。`C-x`、`M-g`、`M-s` 之后同样可以用 `<f5>`。

想少翻几页，可以把 `which-key-side-window-max-height`（默认 0.25，即
屏幕高度的四分之一）调大，配置在 `lisp/init-ui.el`。
