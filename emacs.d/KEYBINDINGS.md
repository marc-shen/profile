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

自定义全局键位按用途分组：`C-x` 管窗口、缓冲区、项目和文件导航；`C-c`
管编译、Git、程序工具、语法及文件处理；`M-g` 管定位，`M-s` 管搜索，
`C-h` 管帮助。Emacs 或插件已有的惯用键（如 `C-x C-s` 保存、
`C-x p c` 编译项目、模式内 `C-c C-c`）不为追求分类而强行改写。

## Helix 模态编辑

本配置启用了 [helix-mode](https://github.com/mgmarlow/helix-mode)，普通
文件缓冲区默认处于 **normal 状态**（模式行显示 `helix[N]`，光标为方块），
`i`/`a` 进入 **insert 状态**（`helix[I]`，光标为竖线），`ESC` 回到
normal；在 macOS 上还会让 Squirrel 保持为当前输入法并切回 Rime 英文。
insert 状态下依次按 `jk`（间隔 0.2 秒内）等价于 ESC，图形界面和
终端都可用——终端下 ESC 无法与 Meta 前缀区分，`jk` 是唯一可靠的退出方式。
`j` 后若 0.2 秒内没有按 `k`，被暂存的 `j` 会照常插入。

`M-x`、`C-x C-f`、Consult 等带候选列表的 minibuffer 也使用 Helix，但默认
进入 **insert 状态**，可以直接输入；按 `ESC` 进入 normal，按 `i`/`a` 返回
insert。minibuffer 中的 `j`、`k` 始终立即原样输入，`jk` 不作为退出键，以免
干扰文件名和命令参数；这里请使用 `ESC` 切换到 normal。普通确认和自由文本
提示不启用 Helix。

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

Magit、普通 Dired、vterm、PDF、compilation、普通 comint 等自带单键操作的
缓冲区不启用 Helix（见 `my-helix-exempt-modes`），在那里一切照旧。
agent-shell 是 comint 的例外：新会话从 insert 开始，可直接输入；按 `ESC` 或
`jk` 进入 normal 浏览对话。WDired 也是例外：进入文件名编辑后启用 Helix normal，
退出并返回 Dired 时关闭。`M-x helix-mode` 可全局开关 Helix。

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
| `C-x S` | 跳到 `*scratch*` 草稿缓冲区，再按一次返回 | 自定义配置 |
| `C-x f` | 修改当前缓冲区的 `fill-column`；不是打开文件 | Emacs |

配置会自动恢复上次光标位置，并把最近文件、历史记录、自动保存和备份
保存在 `~/.emacs.d/var/` 下。

`C-x S` 在任何缓冲区都能直接跳到 `*scratch*`：它被关掉过也会按
`initial-major-mode` 重新建出来。人已经在 `*scratch*` 里时再按一次就回到跳进来
之前的那个缓冲区。加前缀 `C-u C-x S` 则在另一个窗口显示草稿缓冲区，当前窗口不动。

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

默认 `fill-column` 是 88。它只影响 `M-q` 等显式排版命令；配置没有启用
`auto-fill-mode`，因此输入时不会自动插入换行，也不会强制截断代码行。

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
| `C-S-h/j/k/l` | 切到左／下／上／右窗口 | 自定义配置/Windmove |
| `C-x w h/j/k/l` | 与左／下／上／右窗口交换显示内容 | 自定义配置/Windmove |
| `C-x 2` | 上下分割窗口 | Emacs |
| `C-x 3` | 左右分割窗口 | Emacs |
| `C-x 0` | 关闭当前窗口 | Emacs |
| `C-x 1` | 只保留当前窗口 | Emacs |
| `C-x \|` | 两窗口布局顺时针旋转 | 自定义配置 |
| `C-x \` | 两窗口布局逆时针旋转 | 自定义配置 |

两个窗口时 `C-x o` 最省事；窗口多了用 `S-方向键` 或
`C-S-h/j/k/l` 直接指方向。
`C-x w h/j/k/l` 交换相邻窗口的显示内容，焦点跟随原来的 buffer 移动。
它沿用 Emacs 原有的 `C-x w` 窗口命令前缀。

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
| `M-/` | 强制打开光标处的补全 |
| `C-c i` | 请求模型补全，并在小缓冲区选择建议（Minuet） |
| `C-n` / `M-n` / `TAB` / `↓` | 选择下一个候选 |
| `C-p` / `M-p` / `S-TAB` / `↑` | 选择上一个候选 |
| `RET` | 接受当前候选 |
| `M-TAB` / `C-M-i` | 展开所有候选的公共前缀 |
| `M-d` | 显示候选文档 |
| `C-g` | 关闭补全菜单 |

补全菜单打开时，`C-n` 和 `C-p` 用于选择候选；先按 `C-g` 关闭菜单后才会
恢复为正文行移动。编程缓冲区输入 `.` 会立即触发补全；其他输入在前缀达到
两个字符后触发。

### 底部输入区补全：Vertico

`M-x`、`C-x C-f`、`C-x b` 等命令在 minibuffer 中使用 Vertico。

| 快捷键 | 功能 |
| --- | --- |
| `C-n` / `M-n` / `TAB` / `↓` | 选择下一个候选 |
| `C-p` / `M-p` / `S-TAB` / `↑` | 选择上一个候选 |
| `RET` | 确认选择 |
| `M-TAB` / `C-M-i` | 把当前候选填入输入区，继续补全 |
| `M-RET` | 原样提交输入，不使用选中的候选 |
| `C-M-n` / `C-M-p` | 下一条／上一条 minibuffer 历史 |
| `C-g` | 取消并返回编辑器 |
| `C-.` | 对当前候选执行 Embark 操作 |
| `C-;` | 执行 Embark 推荐操作 |

因此 `C-x C-f` 创建不存在的新文件时，输入文件名后使用 `M-RET`；浏览已有
文件和目录则使用统一的候选移动键与 `RET`。

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
| `C-x p t` | 打开或关闭 Treemacs 项目树 | Treemacs（安装后） |
| `C-x p z` | 用 zoxide 跳到常用目录并打开其中文件 | 自定义配置 |
| `C-x p Z` | 用 zoxide 跳到常用目录并打开 Dired | 自定义配置 |

运行 `M-x project-switch-project` 后，还可以按提示选择查找文件、ripgrep、
目录、Eshell、Magit 或编译。

## Dired 目录管理

用 `C-x d` 打开 Dired，或者用 `C-x C-f` 选择一个目录。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `h` / `^` | 返回上一级目录 | Helix 风格 / Dired |
| `j` / `n` | 移到下一个条目 | Helix 风格 / Dired |
| `k` / `p` | 移到上一个条目 | Helix 风格 / Dired |
| `l` / `RET` | 打开光标处文件或目录 | Helix 风格 / Dired |
| `g g` | 跳到第一个文件条目 | Helix 风格 |
| `g e` / `G` | 跳到最后一个文件条目 | Helix 风格 |
| `g r` | 刷新目录 | Helix 风格 |
| `g j` | 按文件名跳转 | 原 `j` |
| `g y` | 显示文件类型 | 原 `y` |
| `/` | 只在文件名中增量搜索 | Helix 风格 |
| `TAB` | 展开/收起子目录 | Dired Subtree（安装后） |
| `x` / `m` | 标记当前文件，相当于选择 | Helix 风格 / Dired |
| `,` / `u` | 取消当前文件的标记 | Helix 风格 / Dired |
| `U` | 清除所有标记 | Dired |
| `d` | 标记为待删除 | Dired |
| `X` | 执行所有待删除标记 | 原 `x`，自定义大写键 |
| `y` | 复制当前或已标记文件的文件名 | Helix 风格 |
| `Y` | 复制当前或已标记文件的绝对路径 | Helix 风格 |
| `r` / `R` | 移动或重命名文件 | Helix 风格 / Dired |
| `C` | 复制文件 | Dired |
| `D` | 立即删除文件 | Dired |
| `v` | 只读查看文件 | Dired |
| `o` | 在另一个窗口打开 | Dired |
| `i` | 在当前缓冲区展开子目录 | Dired |
| `K` | 从列表隐藏当前条目，不删除文件 | 原 `k` |
| `+` | 创建目录 | Dired |
| `!` | 对当前或标记文件执行 shell 命令 | Dired |
| `q` / `C-x C-q` | 进入 WDired，并启动 Helix normal | Helix 风格 / Dired |
| `C-c o` | 在 Finder/Dolphin 中显示光标处文件 | 自定义配置 |

这里把 Dired 的 mark 当作 Helix 的 selection：`x` 只选择文件，不再执行删除；
`d` 只添加删除标记。真正修改磁盘的是 `X` 和 `D`，执行前应确认目标是否正确。
进入 WDired 后处于 Helix normal；按 `i`/`a` 进入 insert 后编辑文件名。按
`C-c C-c` 应用修改，或按 `C-c ESC` 放弃修改；返回普通 Dired 后 Helix 自动关闭。

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
| `C-c p` | 从本地和全局候选中选择当前项目的 Python 环境 |
| `C-u C-c p` | 手动选择任意虚拟环境目录 |

`C-c p` 类似 VS Code/Zed 的解释器选择器，同时发现：

- **项目环境**：uv 项目的 `.venv`、Pixi 和 Hatch 的多个环境、Pet 为
  Poetry/Pipenv 检测到的环境，以及项目根目录下带 Python 的普通 venv；
- **全局环境**：Conda/Mamba 的全部已注册环境、pyenv/pyenv-virtualenv，
  当前 `VIRTUAL_ENV` / `CONDA_PREFIX`、`~/.venv`、`WORKON_HOME`，以及
  `~/.virtualenvs`、`~/.venvs`、`~/.local/share/virtualenvs` 下的环境；
- **手动路径**：`C-u C-c p` 可选择未处于上述位置的环境目录。

候选项会标明 `uv`、`pixi`、`conda`、`pyenv`、`global venv` 等来源并显示
完整路径。选择结果按项目保存在 `~/.emacs.d/var/history`，不污染项目文件。
uv 的 `uv python list` 列出的是基础 Python 安装而非虚拟环境，因此不会混入此
列表；用 `uv venv` 创建项目 `.venv` 后，它会自动出现。

GUI 或 daemon Emacs 不一定继承登录 shell 的 PATH。环境管理器除 `exec-path`
外还会在 `~/.pixi/bin`、`~/.local/bin`、`~/.pyenv/bin` 及常见的
Miniforge/Mambaforge/Miniconda/Anaconda 用户目录中查找；这些目录不会整体加入
PATH，避免 Conda base 的 Python 意外取代系统解释器。

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

### marimo：Emacs 编辑，浏览器执行

marimo notebook 本身就是 Python 文件。这里让 Emacs 负责源码编辑、Eglot、
Git 和项目虚拟环境，让 marimo 的浏览器页面负责响应式执行与富输出；启动参数
`--watch` 会在 Emacs 保存文件后把改动同步到页面。首次使用运行
`M-x my-marimo-setup`，它通过 uv 安装 `marimo[recommended]` 和用于高效文件
监听的 `watchdog`。项目已经用 uv 管理 marimo 时，也可以直接执行
`uv add --dev marimo watchdog`，配置会优先使用项目环境。

| 快捷键 | 功能 |
| --- | --- |
| `C-c j e` | 启动/打开当前 notebook；当前不是文件时提示路径 |
| `C-u C-c j e` | 提示选择或新建另一个 `.py` / `.md` notebook |
| `C-c j o` | 重新打开当前运行中 notebook 的页面 |
| `C-c j c` | 运行 `marimo check` |
| `C-u C-c j c` | 运行 `marimo check --fix`，应用安全修复 |
| `C-c j i` | 插入 Python 单元格；有选区时把选中代码包成单元格 |
| `C-c j l` | 查看 marimo 服务器日志 |
| `C-c j k` | 停止 marimo 服务器 |
| `C-c j m` | 插入 Markdown 单元格 |
| `C-c j s` | 安装或更新全局 marimo 工具环境 |

文件名以 `*_mo.py` 结尾时会直接识别为 marimo notebook；普通 `.py` 文件则只
扫描开头 16 KiB，检测 `marimo.App` 与 `__generated_with` / `@app.cell` 的组合。
识别后模式行显示 `Mo`。文件名只是推荐约定，已有的 `notebook.py` 无需改名。
插入模板时，如果 Yasnippet 已启用，可用 `TAB` 依次填写 cell 参数、正文和
`return`；没有 Yasnippet 时也会插入完整骨架并把光标放在正文。

推荐流程：打开（或新建）`notebook.py`，按 `C-c j e`；页面打开后继续在
Emacs 中修改并用 `C-x C-s` 保存。外部改动默认只把受影响的单元格标为 stale，
在页面按 **Run** / `runStale` 执行。希望每次保存都自动执行时，在项目的
`pyproject.toml` 中加入：

```toml
[tool.marimo.runtime]
watcher_on_save = "autorun"
```

marimo 页面固定使用系统默认浏览器，不经过 embr。它是包含 WebSocket、富输出、
表格和交互控件的完整 Web 应用，原生浏览器在输入、剪贴板和复杂渲染上更可靠。
服务只监听 `127.0.0.1`，并保留 marimo 默认的随机 token 验证。

#### Python 与 marimo 如何选择环境

打开 Python 文件时，`pet-mode` 先查找项目环境，再启动 Python shell 和 Eglot。
Pet 的环境优先级是：已缓存/手动选择的环境、当前 `VIRTUAL_ENV`、Pixi、
Conda/Mamba、Poetry、Hatch、Pipenv、项目根目录的 `.venv` / `venv` / `env`，
最后是 `.python-version` 指定的 pyenv 环境。找到后：

- `python-shell-interpreter` 指向该环境中的 Python；
- Eglot 优先从该环境寻找 basedpyright、pyright 或 pylsp，并把该 Python 路径
  告诉语言服务器；
- Ruff、Black、pytest 等 Pet 支持的工具也优先从该环境解析。

对于 basedpyright/pyright，只发送所选解释器的绝对 `pythonPath`。Pet 默认把
具体环境根目录同时当作 `venvPath`，会让 Pyright 把其中的 `bin` 误认成另一个
虚拟环境并报告“does not contain an executable Python”，这里会移除该歧义参数。

启动 marimo 时采用相容的顺序：Pixi 环境通过
`pixi run --environment <名称> marimo` 启动；其他已选项目环境直接使用该环境的
`marimo`。若项目有 `uv.lock`，则使用 `uv run marimo` 同步并运行项目依赖。
已经解析到非 uv 项目环境但其中没有 marimo 时会明确报错，不会偷用全局工具；
只有没有项目环境时才尝试 PATH 中的全局 `marimo`，或对普通
`pyproject.toml` 项目尝试 `uv run marimo`。

因此项目 notebook 最推荐运行 `uv add --dev marimo watchdog`：Python、Eglot
看到的项目依赖与 marimo kernel 使用同一个 `.venv`。`C-c j s` 安装的则是
uv tool 管理的独立全局环境，适合没有项目环境的零散 notebook；它不会自动继承
另一个项目虚拟环境里的包。可在 Python buffer 中运行 `M-x pet-verify-setup`
查看 Pet 最终解析出的 Python、虚拟环境和各工具路径。

Pixi 项目中，`C-c p` 会直接调用 `pixi info --json` 枚举项目中已创建的环境，
例如 `default`、`dev`、`cuda`，不依赖 Pet 解析 `pixi.toml`，因此没有安装
`dasel` / `tomlparse.el` 时也能识别。环境名称和路径都读取 Pixi 返回的
`name` / `prefix`，兼容 detached environment，而不是用路径末段猜环境名。
尚未安装的声明环境也会显示并标注 `[not installed]`；先运行
`pixi install --environment <名称>`，再选择即可。
选择会按项目保存在 Emacs 的
本地 history 状态中（不写入项目、不进入 Git），下次启动仍会恢复。
所有已打开的 Python buffer 都会刷新，已有 Eglot 会重连；模式行的
`Py[default]` / `Py[cuda]` 表示当前 buffer 使用的环境。随后重新启动 marimo
（`C-c j k`，再 `C-c j e`），它会以
`pixi run --environment <名称> marimo` 启动，从而同时应用该环境的解释器、依赖
和激活变量。已有 Python REPL 也需要关闭后重新运行，正在执行的进程不会被强制
迁移。所选环境必须包含 marimo，例如默认环境运行 `pixi add marimo watchdog`；
若 `dev` 环境由同名 feature 构成，则运行
`pixi add --feature dev marimo watchdog`。

同一规则适用于 Conda 和普通 venv：显式选择环境后，marimo 不会静默回退到
全局安装。如果所选环境没有 marimo，`C-c j e` 会直接提示先在该环境安装；
有 `uv.lock` 的 uv 项目是例外，它会通过 `uv run marimo` 先同步项目依赖。

依赖管理按 notebook 的用途选择：项目内分析把 `marimo` 放进项目依赖并用同一
`.venv`；需要独立分享的示例则可把 `--sandbox` 加入
`init-marimo-edit-arguments`，由 marimo/uv 将依赖写进 PEP 723 元数据。不要把
marimo notebook 当作 `# %%` 脚本交给 Code Cells 执行；其单元格是
`@app.cell` 函数，运行和依赖顺序应交给 marimo。

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
| `C-c A` | 打开 Org Agenda | 自定义配置/Org |
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

打开文件时自动生效：按语法树着色、随窗口边缘软换行、拼写与行文检查、
本地图片显示，以及 `markdown-ts-appear` 的“阅读时渲染、光标处显示源码”。

折行只改变显示，不会往文件里插入换行符，所以 diff 不受影响。Markdown
默认随窗口边缘软换行，不设置固定视觉宽度；如需固定宽度，可自定义
`init-markdown-visual-width` 为正整数。

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

`$...$` 与 `$$...$$` 由 MathJax 和 Node 异步渲染成 SVG（包括 GFM 表格单元格
中的公式）；光标进入公式时显示
源码，移开后重新渲染。公式预览只在图形界面且支持 SVG 时启用，终端中其余
Markdown 功能照常工作。

GFM 表格单元格会单独启用 `markdown-inline` Tree-sitter 解析，因此其中的强调、
链接和数学公式与普通段落使用同一套即时渲染规则。视觉换行只影响屏幕排版，
不会改变表格或公式的语法识别。`valign-mode` 按实际像素宽度对齐中文、英文与
公式图片，并绘制连续的竖向分隔线；这些效果只存在于显示层，不修改 Markdown
源文件中的空格。

### 显示开关

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c C-x r` | 依次切换实时渲染、纯源码、只读预览 | 本配置 |
| `C-c C-x C-v` | 显示或隐藏内联图片 | markdown-ts-mode |
| `C-c C-x RET` | 隐藏或显示 Markdown 标记 | markdown-ts-mode |

三种模式也可以直接通过 `M-x my-markdown-render-live`、
`M-x my-markdown-render-source` 和 `M-x my-markdown-render-preview` 进入。
实时模式边编辑边更新 MathJax 与表格布局；源码模式关闭公式、图片、隐藏标记及
`valign`，适合编辑大表格；预览模式完整渲染并把缓冲区设为只读，避免导航时
反复重排。实时模式按整张表共享内联解析器，并把同一批异步公式引起的多次表格
重排合并为一次空闲刷新。新缓冲区默认使用实时模式。

图片默认打开就显示，宽度自动限制在当前窗口内；只读取本地文件，不会因为
打开文档而访问远程图片。

### 表格上下文

进入表格后会自动启用一组上下文键：`TAB` / `S-TAB` 移动单元格，`RET` /
`S-RET` 移动行，`M-方向键` 移动行列，`M-S-方向键` 插入或删除行列，
`C-c C-c` 对齐整张表，`C-c C-t a` 调整当前列对齐，`C-c C-t t` 转置表格。

## Git 与 Magit

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c g s` | 打开当前项目的 Magit 状态页 | 自定义配置/Magit |
| `C-c g g` | 打开 Magit 主命令菜单 | 自定义配置/Magit |
| `C-c g f` | 打开针对当前文件的 Magit 菜单 | 自定义配置/Magit |
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

agent-shell 通过 ACP 协议驱动 Codex、Claude 等编程智能体，默认预选 Codex。
对话直接呈现在普通缓冲区里，可以照常搜索和复制。

| 快捷键 | 功能 | 来源 |
| --- | --- | --- |
| `C-c a` | 打开或复用当前项目的智能体会话 | 自定义配置 |
| `C-u C-c a` | 新开 agent-shell，并选择新会话或恢复历史会话 | agent-shell |
| `C-u C-u C-c a` | 从已有会话中选择一个 | agent-shell |
| `ESC` | 进入 Helix normal，不改变其他窗口 | Helix/自定义配置 |
| `RET` | 发送当前输入 | agent-shell |
| `S-RET` | 换行但不发送 | agent-shell/shell-maker |
| `C-c C-c` | 打断正在进行的回答 | agent-shell |
| `C-c C-v` | 选择模型 | agent-shell |
| `C-c C-m` | 选择会话模式 | agent-shell |
| `C-<tab>` | 在会话模式之间循环 | agent-shell |

同一项目可以同时运行多个 agent-shell：用 `C-u C-c a` 或
`M-x agent-shell-new-shell` 新开一个 buffer，然后在列表中选择 `New shell`
或一条历史会话；用 `C-u C-u C-c a` 切换到仍在运行的 buffer。
`M-x agent-shell-resume-session` 需要手动输入 session ID。

使用前需要单独安装 Codex 的 ACP 适配器，它不是 Emacs 插件：

```sh
npm install -g @agentclientprotocol/codex-acp
```

认证沿用 Codex CLI 的登录状态，无需另配 API key。如需选择 Claude，
另装 `@agentclientprotocol/claude-agent-acp`。

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
