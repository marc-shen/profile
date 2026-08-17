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
normal。insert 状态下依次按 `jk`（间隔 0.2 秒内）等价于 ESC，图形界面和
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
| `C-x b` | 搜索并切换缓冲区 | Consult |
| `C-x 4 b` | 在另一个窗口中切换缓冲区 | Consult |
| `C-x C-r` | 从最近访问的文件中选择并打开 | Consult |
| `C-c r` | 从磁盘重新载入当前文件 | 自定义配置 |
| `C-x f` | 修改当前缓冲区的 `fill-column`；不是打开文件 | Emacs |

配置会自动恢复上次光标位置，并把最近文件、历史记录、自动保存和备份
保存在 `~/.emacs.d/var/` 下。

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
所在目录，而不是在父目录里选中它。

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

配置会在相应服务器存在时自动启动：Python 使用
`pyright-langserver`，C/C++ 使用 `clangd`，Fortran 使用 `fortls`。

## Python

以下键位只在 `python-mode` 中生效。

| 快捷键 | 功能 |
| --- | --- |
| `C-c C-c` | 把整个缓冲区发送到 Python 解释器 |
| `C-c C-r` | 把选中区域发送到 Python 解释器 |
| `C-c C-z` | 切换到 Python 解释器缓冲区 |

格式化命令目前没有固定快捷键，可通过 `M-x ruff-format-buffer` 或
`M-x black-format-buffer` 调用；前提是对应程序已安装。

## C、C++ 与 Fortran

C/C++ 和 Fortran 没有额外的语言专属自定义键位，主要使用 Eglot 的
通用键位：

- C/C++ 语言服务器：`clangd`
- Fortran 语言服务器：`fortls`
- 定义跳转：`M-.`
- 查找引用：`M-?`
- 重命名：`C-c s r`
- 格式化：`C-c s f`

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

`.md`、`.markdown`、`.mdx` 等扩展名自动进入 `markdown-mode`；
`README.md`、`CONTRIBUTING.md`、`CHANGELOG.md` 进入 GitHub 方言
`gfm-mode`。其余文件可用 `M-x gfm-mode` 手动切换。两者的键位相同。

打开文件时自动生效：软换行（在第 88 列处折行，而不是在窗口边缘）、
拼写检查（本机装了 aspell 或 hunspell 时）、行文检查，以及显示本地图片。

折行只改变显示，不会往文件里插入换行符，所以 diff 不受影响。宽度取自
`fill-column`（默认 88），用 `C-x f` 可为当前缓冲区改成别的值，立即生效。
窗口比该宽度还窄时，按窗口边缘折行。

### 折叠与浏览

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `TAB` | 折叠或展开光标处标题（在标题行上按） | markdown-mode |
| `S-TAB` | 循环整个文档的折叠状态 | markdown-mode |
| `C-x n s` | 只显示当前标题及其内容 | markdown-mode |
| `C-x n w` | 取消上面的收窄 | Emacs |
| `M-g i` | 按标题跳转，标题层级以 `/` 分隔 | Consult/Imenu |
| `C-c C-n` / `C-c C-p` | 跳到下一个/上一个标题 | markdown-mode |
| `C-c C-f` / `C-c C-b` | 跳到同级的下一个/上一个标题 | markdown-mode |
| `C-c C-u` | 跳到上一级标题 | markdown-mode |
| `C-c C-o` | 打开光标处的链接，或跳到目录指向的标题 | markdown-mode |

### 目录

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-x t` | 在光标处生成目录；再按一次按当前标题刷新 | 自定义配置/markdown-toc |

目录写在自己的 HTML 注释标记之间，因此标题改动后重新按一次即可更新，
不会破坏正文。只是想跳转、不想在文件里留目录时用 `M-g i`。

### 结构与编辑

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-t h` | 按上下文插入合适层级的标题 | markdown-mode |
| `C-c C-t 1` … `C-c C-t 6` | 插入指定层级的标题 | markdown-mode |
| `C-c <left>` / `C-c <right>` | 提升/降低当前标题连同其子树 | markdown-mode |
| `RET` | 列表内自动续下一项 | markdown-mode |
| `C-c C-x m` | 插入列表项 | markdown-mode |
| `C-c C-x C-x` | 切换任务列表勾选框 | markdown-mode |
| `C-c C-s b` / `C-c C-s e` | 加粗/斜体 | markdown-mode |
| `C-c C-s c` | 行内代码 | markdown-mode |
| `C-c C-s s` | 删除线 | markdown-mode |
| `C-c C-l` | 插入链接 | markdown-mode |
| `C-c C-i` | 插入图片 | markdown-mode |
| `C-c C-s t` | 插入表格 | markdown-mode |
| `C-c C-x a` | 对齐当前表格 | 自定义配置/markdown-mode |

### 代码块

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-s C` | 插入带语言标记的围栏代码块 | markdown-mode |
| `C-c C-x C-f` | 开关围栏代码的语言着色 | markdown-mode |
| `C-c '` | 在独立缓冲区中以该语言的模式编辑当前代码块 | markdown-mode/edit-indirect |

围栏内的代码按语言着色。装了对应的 tree-sitter 语法后自动改用
`*-ts-mode`，无需改配置。`C-c '` 打开的缓冲区是真正的语言模式，
补全、缩进和诊断都可用，`C-c C-c` 写回原文件。

### 编辑模式与预览模式

Markdown 缓冲区默认是**编辑模式**：公式、`**`、链接地址都以源码显示并着色，
所见即文件内容。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-v` | 在编辑模式与预览模式之间切换（v = view） | 自定义配置 |
| `C-c C-e` | 光标处公式：图片与源码来回切换（e = equation） | preview.el |

`C-c C-e` 是写公式时最常用的一个键：在渲染好的公式上按它变回源码以便修改，
改完再按一次就地重新渲染那一个 —— 不必整个模式来回切。缓冲区里还没渲染过
任何公式时，第一次按它会把全篇公式一次渲染出来。

切到**预览模式**后（状态栏出现 ` Preview`）：

- 公式渲染成图片
- `**`、`_` 等只起标记作用的字符隐藏，只留下加粗、斜体的效果
- 链接只显示文字，不显示地址

再按一次 `C-c C-v` 回到编辑模式，图片撤掉、标记恢复。内联图片不受模式
影响 —— 图片是内容而不是标记，两种模式下都显示。

**公式渲染需要图形界面的 Emacs。** 渲染的本质是把图片贴在公式位置上，
终端里的 Emacs（`emacs -nw`）无法显示任何图片，此时预览模式只隐藏标记，
公式仍是源码。用 `M-: (display-images-p)` 可以确认，结果应为 `t`。

### 公式：少用的命令

日常只需要上面两个键。剩下的放在三键的组里，用 which-key 就能看到：

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-x v C-d` | 渲染整个文件的公式（不改变模式） | texfrag |
| `C-c C-x v C-l` | 公式编译报错时查看 LaTeX 日志 | texfrag |
| `C-c C-x v C-p` | 同 `C-c C-e` | texfrag/preview.el |
| `M-x texfrag-scale` | 调整渲染出来的公式大小 | texfrag |
| `C-c C-x C-e` | 开关 `$...$` 的数学着色（不渲染） | markdown-mode |

支持 `$...$`、`$$...$$`、`\(...\)`、`\[...\]` 以及
`\begin{align}...\end{align}` 这类环境。句子里的 `$5`、`$10` 不算公式，
不含公式的文件不会白跑一次 LaTeX。

渲染由本机的 TeX Live 加 dvipng 完成，和写 LaTeX 论文用的是同一套工具，
所以公式的字形与论文里一致。一份 200 行、66 个公式的笔记 LaTeX 约需 0.3 秒。
中间文件写到 `~/.emacs.d/var/texfrag`，不会在仓库里留下 `texfrag/` 目录。

导言区默认只有 `amsmath` 和 `amsfonts`。公式用到别的宏包时，把宏包加进
`texfrag-header-default` 即可。没装 LaTeX 的机器上该功能自动关闭，
其余 Markdown 功能不受影响。

**注意一个 MathJax 与真 LaTeX 的差异**：不要把 `\begin{align}` 套在
`$$...$$` 里面。`align` 本身就是行间公式，真 LaTeX 会报
`\begin{align} allowed only in paragraph mode`，而且一处出错会导致该文件
后面所有公式都渲染不出来。Obsidian、GitHub 用的 MathJax 会容错，所以这种
写法很常见。同理，`\end{align}` 前面多余的 `\\` 加空白行会被当成分段，
也会报错。`C-c C-x v C-l` 里能看到具体是哪一行。

### 显示开关

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-x TAB` | 显示或隐藏内联图片 | markdown-mode |
| `C-c C-x RET` | 隐藏或显示 `**`、`_` 等标记字符 | markdown-mode |
| `C-c C-x C-l` | 隐藏或显示链接地址 | markdown-mode |

图片默认打开就显示，最宽 1024 像素，因此截图不会撑破窗口。只读取本地
文件，不会因为打开文件而访问网络。

### 预览与导出

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-c p` | 预览当前文件 | markdown-mode |
| `C-c C-c l` | 编辑时实时预览 | markdown-mode |
| `C-c C-c v` | 导出 HTML 并打开 | markdown-mode |
| `C-c C-c w` | 把渲染结果复制到 kill ring | markdown-mode |

预览需要一个转换程序，配置会自动选用本机的 pandoc、multimarkdown 或
cmark。三个都没有时，只有以上四个命令报错提示缺少程序，其他功能不受影响；
装上任意一个即可，无需改配置。预览结果由 `browse-url` 打开，因此会落在
embr 浏览器里。

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
| `my-install-packages` | 安装当前配置声明但尚未安装的插件 |
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
