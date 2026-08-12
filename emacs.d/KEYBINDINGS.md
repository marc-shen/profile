# Emacs 快捷键指南

本文档介绍这套 Emacs 配置中最常用的快捷键，包括自定义键位、Emacs
内置键位和插件提供的模式内键位。实际绑定以当前缓冲区的 major mode、
minor mode 以及已安装插件为准。

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
| `C-h B` | 查看当前上下文中的 Embark 绑定 | Embark（安装后） |
| `C-c m` | 搜索并执行当前 major/minor mode 提供的命令 | Consult |

不知道某个功能叫什么时，先用 `C-h a` 搜索关键词；知道命令名后，用
`C-h w` 查快捷键。

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
| `C-c h` | 选择左侧窗口 | 自定义配置 |
| `C-c j` | 选择下方窗口 | 自定义配置 |
| `C-c k` | 选择上方窗口 | 自定义配置 |
| `C-c l` | 选择右侧窗口 | 自定义配置 |
| `S-方向键` | 按方向切换窗口 | Windmove |
| `C-c w v` | 左右分割窗口 | 自定义配置 |
| `C-c w s` | 上下分割窗口 | 自定义配置 |
| `C-c w d` | 删除当前窗口 | 自定义配置 |
| `C-c w o` | 只保留当前窗口 | 自定义配置 |
| `C-x 2` | 上下分割窗口 | Emacs |
| `C-x 3` | 左右分割窗口 | Emacs |
| `C-x 0` | 删除当前窗口 | Emacs |
| `C-x 1` | 只保留当前窗口 | Emacs |
| `C-x o` | 切换到下一个窗口 | Emacs |

在普通缓冲区中 `C-c l` 表示向右切换窗口；在 Eglot 管理的缓冲区中，
它会成为语言服务器命令前缀。

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

`D` 和 `x` 会删除文件，执行前应确认目标是否正确。

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
| `C-c l a` | 显示可用的代码操作 |
| `C-c l r` | 重命名当前符号及其引用 |
| `C-c l f` | 使用语言服务器格式化整个缓冲区 |
| `C-c l d` | 打开光标处符号的文档 |
| `C-c l s` | 搜索语言服务器提供的项目符号 |
| `C-c l q` | 关闭当前语言服务器 |
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
- 重命名：`C-c l r`
- 格式化：`C-c l f`

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
4. 按任意前缀后稍等，例如 `C-c l` 或 `C-x p`，Which-key 会列出可用后续键。
