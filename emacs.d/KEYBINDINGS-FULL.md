# Emacs 快捷键全表

本文件由脚本从**实际加载的配置**中导出，不是手写的摘要：它以 `emacs --batch` 加载 `init.el`，再把所有插件的模式加载起来，然后遍历各个 keymap。因此这里出现的每一条都是当前真实生效的绑定，共 2403 条。

想看精简版、按使用场景组织的常用键位，见 [KEYBINDINGS.md](KEYBINDINGS.md)。本文件的用途相反：把全部功能摊开，便于发现没用过的命令，以及审查键位是否合理。

这是一份快照，不会随配置自动更新。装了新插件或改了绑定之后，以运行中的 Emacs 为准：`C-h b` 列出当前缓冲区里全部生效的绑定，`C-h B` 用检索的方式浏览同一份数据。

## 怎么读这份表

- **模式内的键位优先于全局键位。** 同一个按键在不同缓冲区可以是不同命令，下面每一节标题写明了它在什么场合生效。
- **前缀键会整体屏蔽同名的单键。** markdown-mode 定义了 `C-c C-c e`、`C-c C-c p` 等等，于是在 Markdown 缓冲区里 `C-c C-c` 只能是前缀，全局绑在它上面的 `recompile` 按不出来。这类冲突已在下一节逐条列出。
- **自插入字符、鼠标事件、菜单栏没有列出。** 它们数量大且没有查阅价值。

## 怎么改键位

配置分散在 `lisp/init-*.el`，改键位有三种写法，按场合选：

```elisp
;; 一、全局键位：写在 lisp/init-keymap.el
(global-set-key (kbd "C-c q") #'some-command)

;; 二、某个插件自己的键位：写在该插件的 use-package 里
(use-package treemacs
  :bind (("C-c t" . treemacs)))

;; 三、只在某个模式里生效：绑到该模式的 keymap
(use-package markdown-mode
  :bind (:map markdown-mode-map
         ("C-c C-x a" . markdown-table-align)))
```

取消一个碍事的绑定用 `(keymap-global-unset "C-c x")`，或在模式里 `(keymap-unset some-mode-map "C-c x")`。

改完在运行中的 Emacs 里想立刻验证，用 `C-h k` 按一下那个键看它现在是什么命令，或者 `C-h w` 输入命令名反查它绑在哪里。

## 键位审查

### 覆盖了原生 Emacs 的键位

以下按键在原生 Emacs 里另有含义，被本配置改掉了。都是有意为之（多数是换成 consult 的增强版），列在这里是为了在读别人的 Emacs 文档时心里有数。

| 快捷键 | 现在是 | 原生是 | 说明 |
| --- | --- | --- | --- |
| `C-s` | `consult-line` | `isearch-forward` | 在当前缓冲区按行搜索 |
| `M-i` | `minuet-complete-with-minibuffer` | `tab-to-tab-stop` | 用大模型补全，在小缓冲中选择结果 |
| `M-y` | `consult-yank-pop` | `yank-pop` | 带预览地从剪切环中粘贴 |
| `C-x \` | `my-rotate-windows-counterclockwise` | `activate-transient-input-method` | 两窗口布局逆时针旋转 |
| `C-x b` | `consult-buffer` | `switch-to-buffer` | 切换缓冲区（带预览和虚拟缓冲区） |
| `C-x C-d` | `consult-dir` | `list-directory` | 选择目录并在其中操作 |
| `C-x C-r` | `consult-recent-file` | `find-file-read-only` | 从最近打开过的文件中选择 |
| `M-g g` | `consult-goto-line` | `goto-line` | 带预览地跳转到指定行号 |
| `M-g i` | `consult-imenu` | `imenu` | 在当前文件的符号列表中检索跳转 |
| `C-x 4 b` | `consult-buffer-other-window` | `switch-to-buffer-other-window` | 在另一窗口切换缓冲区 |

### 被模式前缀吃掉的全局键位

下面这些全局键位在特定模式里按不出来，因为该模式把同样的按键当成了前缀。

| 全局键位 | 全局命令 | 在哪些模式里失效 | 因为该模式有 |
| --- | --- | --- | --- |
| `C-c C-c` | `recompile` | markdown | `C-c C-c ]`、`C-c C-c ^`、`C-c C-c c` 等 14 个 |
| `C-t` | `transpose-chars` | dired | `C-t .`、`C-t C-t`、`C-t a` 等 12 个 |

### 次模式盖住主模式的键位

次模式的 keymap 优先级高于所有主模式。下面这些键在对应的主模式里本来另有含义，被一直开着的次模式接管了。

| 快捷键 | 实际执行 | 在哪个模式里 | 本来是 |
| --- | --- | --- | --- |
| `S-<down>` | `windmove-down` | org | `org-shiftdown` —— 按情境向下调整（状态、优先级、日期） |
| `S-<left>` | `windmove-left` | org | `org-shiftleft` —— 按情境向左调整（状态、优先级、日期） |
| `S-<right>` | `windmove-right` | org | `org-shiftright` —— 按情境向右调整（状态、优先级、日期） |
| `S-<up>` | `windmove-up` | org | `org-shiftup` —— 按情境向上调整 |

Org 为此另外提供了 `C-c <left>`、`C-c <right>`、`C-c <up>`、`C-c <down>`，和被盖住的四个命令完全一样，所以没有功能真的丢失。

### 没有被占用的 C-c 单键

`C-c` 加单个字母是留给用户的保留区。以下字母目前全局和各模式都没用到，可以放心拿来绑新命令：

- 小写：`C-c d`、`C-c f`、`C-c h`、`C-c i`、`C-c j`、`C-c k`、`C-c l`、`C-c o`、`C-c p`、`C-c q`、`C-c u`、`C-c w`、`C-c x`、`C-c y`
- 大写：`C-c B`、`C-c C`、`C-c D`、`C-c E`、`C-c F`、`C-c G`、`C-c H`、`C-c I`、`C-c J`、`C-c K`、`C-c L`、`C-c M`、`C-c N`、`C-c O`、`C-c P`、`C-c Q`、`C-c R`、`C-c S`、`C-c T`、`C-c U`、`C-c W`、`C-c X`、`C-c Y`

## 目录

- [全局键位](#全局键位)（772 条）
- [窗口移动（Windmove）](#窗口移动windmove)（4 条）
- [Which-key 翻页](#which-key-翻页)（4 条）
- [未提交改动（diff-hl）](#未提交改动diff-hl)（7 条）
- [增量搜索](#增量搜索)（72 条）
- [小缓冲输入](#小缓冲输入)（17 条）
- [小缓冲候选列表（Vertico）](#小缓冲候选列表vertico)（21 条）
- [补全弹窗（Corfu）](#补全弹窗corfu)（16 条）
- [Embark 操作菜单](#embark-操作菜单)（24 条）
- [编程模式通用](#编程模式通用)（2 条）
- [Eglot 语言服务器](#eglot-语言服务器)（6 条）
- [Flymake 诊断](#flymake-诊断)（4 条）
- [Python](#python)（29 条）
- [Python（tree-sitter 模式）](#pythontree-sitter-模式)（29 条）
- [C](#c)（43 条）
- [C++](#c-1)（46 条）
- [Fortran（固定格式）](#fortran固定格式)（22 条）
- [Fortran 90（自由格式）](#fortran-90自由格式)（23 条）
- [Org mode](#org-mode)（221 条）
- [Markdown](#markdown)（114 条）
- [LaTeX（AUCTeX）](#latexauctex)（61 条）
- [TeX（AUCTeX 通用）](#texauctex-通用)（41 条）
- [Magit 状态页](#magit-状态页)（89 条）
- [Magit 通用](#magit-通用)（89 条）
- [合并冲突（Smerge）](#合并冲突smerge)（13 条）
- [编译与搜索结果](#编译与搜索结果)（23 条）
- [Dired 目录管理](#dired-目录管理)（125 条）
- [缓冲区列表（Ibuffer）](#缓冲区列表ibuffer)（131 条）
- [项目树（Treemacs）](#项目树treemacs)（87 条）
- [PDF 阅读](#pdf-阅读)（77 条）
- [智能体会话（agent-shell）](#智能体会话agent-shell)（44 条）
- [浏览器（embr）](#浏览器embr)（132 条）
- [多光标](#多光标)（6 条）
- [代码模板（YASnippet）](#代码模板yasnippet)（3 条）
- [帮助页面（Helpful）](#帮助页面helpful)（6 条）

## 全局键位

在任何缓冲区都可用，除非被下面某个模式的键位盖住。

### 无前缀的单键

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<again>` | `repeat-complex-command` | 编辑并重新执行上一条复杂命令 |
| `<begin>` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<compose-last-chars>` | `compose-last-chars` | 组合输入最后几个字符 |
| `<copy>` | `kill-ring-save` | 复制选中区域 |
| `<cut>` | `kill-region` | 剪切选中区域 |
| `<deletechar>` | `delete-forward-char` | 删除后一个字符 |
| `<deleteline>` | `kill-line` | 剪切到行尾 |
| `<down>` | `next-line` | 下移一行 |
| `<end>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `<escape>` | `keyboard-escape-quit` | 退出当前状态（关弹窗、取消选区等） |
| `<execute>` | `execute-extended-command` | 按名称执行命令（M-x） |
| `<f10>` | `menu-bar-open` | 用键盘打开菜单栏 |
| `<f11>` | `toggle-frame-fullscreen` | 切换全屏 |
| `<f3>` | `kmacro-start-macro-or-insert-counter` | 开始录制宏，录制中则插入计数器 |
| `<f4>` | `kmacro-end-or-call-macro` | 正在录制则结束，否则执行上一个宏 |
| `<find>` | `search-forward` | 向后查找字符串（非增量） |
| `<home>` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<insert>` | `overwrite-mode` | 开关改写模式 |
| `<insertchar>` | `overwrite-mode` | 开关改写模式 |
| `<insertline>` | `open-line` | 在光标处插入空行，光标不动 |
| `<kp-end>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `<kp-home>` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<kp-next>` | `scroll-up-command` | 向下翻页 |
| `<kp-prior>` | `scroll-down-command` | 向上翻页 |
| `<left>` | `left-char` | 光标左移一个字符 |
| `<menu>` | `execute-extended-command` | 按名称执行命令（M-x） |
| `<next>` | `scroll-up-command` | 向下翻页 |
| `<open>` | `find-file` | 打开文件 |
| `<paste>` | `yank` | 粘贴最近剪切的内容 |
| `<prior>` | `scroll-down-command` | 向上翻页 |
| `<redo>` | `repeat-complex-command` | 编辑并重新执行上一条复杂命令 |
| `<right>` | `right-char` | 光标右移一个字符 |
| `<Scroll_Lock>` | `scroll-lock-mode` | 开关翻页式滚动 |
| `<undo>` | `undo` | 撤销 |
| `<up>` | `previous-line` | 上移一行 |
| `<XF86Back>` | `previous-buffer` | 切到上一个缓冲区 |
| `<XF86Forward>` | `next-buffer` | 切到下一个缓冲区 |
| `C-.` | `embark-act` | 对光标处或候选项执行某个操作 |
| `C-/` | `undo` | 撤销 |
| `C-;` | `embark-dwim` | 对当前目标执行默认操作 |
| `C-<` | `mc/mark-previous-like-this` | 向上标记上一处相同内容 |
| `C-<backspace>` | `backward-kill-word` | 向前删除一个词 |
| `C-<delete>` | `kill-word` | 向后剪切一个词 |
| `C-<down>` | `forward-paragraph` | 移动到段落末尾 |
| `C-<end>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `C-<f10>` | `buffer-menu-open` | 用键盘操作缓冲区菜单 |
| `C-<home>` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `C-<insert>` | `kill-ring-save` | 复制选中区域 |
| `C-<insertchar>` | `kill-ring-save` | 复制选中区域 |
| `C-<left>` | `left-word` | 光标左移一个词 |
| `C-<next>` | `scroll-left` | 画面向左滚动 |
| `C-<prior>` | `scroll-right` | 画面向右滚动 |
| `C-<right>` | `right-word` | 光标右移一个词 |
| `C-<up>` | `backward-paragraph` | 移动到段落开头 |
| `C->` | `mc/mark-next-like-this` | 向下标记下一处相同内容 |
| `C-?` | `undo-redo` | 重做 |
| `C-@` | `set-mark-command` | 设置标记开始选择，或跳回标记 |
| `C-\` | `toggle-input-method` | 开关输入法 |
| `C-]` | `abort-recursive-edit` | 中止递归编辑或小缓冲输入 |
| `C-_` | `undo` | 撤销 |
| `C-a` | `move-beginning-of-line` | 跳到行首 |
| `C-b` | `backward-char` | 光标左移一个字符 |
| `C-d` | `delete-char` | 删除后一个字符 |
| `C-e` | `move-end-of-line` | 跳到行尾 |
| `C-f` | `forward-char` | 光标右移一个字符 |
| `C-g` | `keyboard-quit` | 取消当前命令 |
| `C-j` | `electric-newline-and-maybe-indent` | 插入换行并按需缩进 |
| `C-k` | `kill-line` | 剪切到行尾 |
| `C-l` | `recenter-top-bottom` | 把当前行滚到窗口中间、顶部或底部 |
| `C-n` | `next-line` | 下移一行 |
| `C-o` | `open-line` | 在光标处插入空行，光标不动 |
| `C-p` | `previous-line` | 上移一行 |
| `C-q` | `quoted-insert` | 按原样插入下一个输入字符 |
| `C-r` | `isearch-backward` | 向前增量搜索 |
| `C-s` | `consult-line` | 在当前缓冲区按行搜索 |
| `C-S-<backspace>` | `kill-whole-line` | 剪切整行 |
| `C-s-SPC` | `ns-do-show-character-palette` | 打开系统字符面板（macOS） |
| `C-SPC` | `set-mark-command` | 设置标记开始选择，或跳回标记 |
| `C-t` | `transpose-chars` | 交换光标前后两个字符 |
| `C-u` | `universal-argument` | 给下一个命令加前缀参数 |
| `C-v` | `scroll-up-command` | 向下翻页 |
| `C-w` | `kill-region` | 剪切选中区域 |
| `C-y` | `yank` | 粘贴最近剪切的内容 |
| `C-z` | `suspend-frame` | 挂起或最小化当前窗体 |
| `DEL` | `delete-backward-char` | 删除前一个字符 |
| `M-!` | `shell-command` | 执行 shell 命令并显示输出 |
| `M-$` | `ispell-word` | 检查光标处词的拼写 |
| `M-%` | `query-replace` | 逐处确认替换 |
| `M-&` | `async-shell-command` | 在后台异步执行 shell 命令 |
| `M-'` | `abbrev-prefix-mark` | 标记光标处为缩写的起点 |
| `M-(` | `insert-parentheses` | 用括号把后面的表达式括起来 |
| `M-)` | `move-past-close-and-reindent` | 跳过右括号并重新缩进 |
| `M-,` | `xref-go-back` | 跳回上一个位置 |
| `M-.` | `xref-find-definitions` | 跳到光标处标识符的定义 |
| `M-/` | `dabbrev-expand` | 用缓冲区中出现过的词动态补全 |
| `M-:` | `eval-expression` | 求值一个 Lisp 表达式并显示结果 |
| `M-;` | `comment-dwim` | 按当前情境注释或取消注释 |
| `M-<` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `M-<begin>` | `beginning-of-buffer-other-window` | 跳到另一窗口缓冲区的开头 |
| `M-<end>` | `end-of-buffer-other-window` | 跳到另一窗口缓冲区的末尾 |
| `M-<f10>` | `toggle-frame-maximized` | 切换最大化 |
| `M-<home>` | `beginning-of-buffer-other-window` | 跳到另一窗口缓冲区的开头 |
| `M-<left>` | `left-word` | 光标左移一个词 |
| `M-<next>` | `scroll-other-window` | 另一窗口向下翻页 |
| `M-<prior>` | `scroll-other-window-down` | 另一窗口向上翻页 |
| `M-<right>` | `right-word` | 光标右移一个词 |
| `M-=` | `count-words-region` | 统计区域内的词数 |
| `M->` | `end-of-buffer` | 跳到缓冲区末尾 |
| `M-?` | `xref-find-references` | 查找光标处标识符的所有引用 |
| `M-@` | `mark-word` | 选中一个词 |
| `M-\` | `delete-horizontal-space` | 删除光标两侧的空格和制表符 |
| `M-^` | `delete-indentation` | 把本行并到上一行 |
| `M-`` | `tmm-menubar` | 用文本方式打开菜单栏 |
| `M-a` | `backward-sentence` | 移动到句子开头 |
| `M-b` | `backward-word` | 向前移动一个词 |
| `M-c` | `capitalize-word` | 把词首字母改为大写 |
| `M-d` | `kill-word` | 向后剪切一个词 |
| `M-DEL` | `backward-kill-word` | 向前删除一个词 |
| `M-e` | `forward-sentence` | 移动到句子末尾 |
| `M-f` | `forward-word` | 向后移动一个词 |
| `M-h` | `mark-paragraph` | 选中当前段落 |
| `M-i` | `minuet-complete-with-minibuffer` | 用大模型补全，在小缓冲中选择结果 |
| `M-j` | `default-indent-new-line` | 断行并缩进 |
| `M-k` | `kill-sentence` | 剪切到句尾 |
| `M-l` | `downcase-word` | 把词转为小写 |
| `M-m` | `back-to-indentation` | 跳到本行第一个非空白字符 |
| `M-q` | `fill-paragraph` | 重排当前段落的折行 |
| `M-r` | `move-to-window-line-top-bottom` | 在窗口顶部、中间、底部之间跳 |
| `M-s-F` | `isearch-backward-regexp` | 向前按正则增量搜索 |
| `M-s-f` | `isearch-forward-regexp` | 向后按正则增量搜索 |
| `M-s-h` | `ns-do-hide-others` | 隐藏其他应用（macOS） |
| `M-SPC` | `cycle-spacing` | 循环调整光标周围的空白 |
| `M-t` | `transpose-words` | 交换前后两个词 |
| `M-u` | `upcase-word` | 把词转为大写 |
| `M-v` | `scroll-down-command` | 向上翻页 |
| `M-w` | `kill-ring-save` | 复制选中区域 |
| `M-X` | `execute-extended-command-for-buffer` | 只列出与当前模式相关的命令来执行 |
| `M-x` | `execute-extended-command` | 按名称执行命令（M-x） |
| `M-y` | `consult-yank-pop` | 带预览地从剪切环中粘贴 |
| `M-z` | `zap-to-char` | 删除到指定字符为止 |
| `M-{` | `backward-paragraph` | 移动到段落开头 |
| `M-|` | `shell-command-on-region` | 把选中区域作为输入执行 shell 命令 |
| `M-}` | `forward-paragraph` | 移动到段落末尾 |
| `M-~` | `not-modified` | 把缓冲区标记为未修改 |
| `RET` | `newline` | 插入换行 |
| `s-&` | `kill-current-buffer` | 关闭当前缓冲区 |
| `s-'` | `next-window-any-frame` | 切到下一个窗口（跨窗体） |
| `s-+` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `s-,` | `customize` | 打开自定义设置界面 |
| `s--` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `s-0` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `s-:` | `ispell` | 对区域或缓冲区做拼写检查 |
| `S-<delete>` | `kill-region` | 剪切选中区域 |
| `S-<f10>` | `context-menu-open` | 用键盘打开右键菜单 |
| `S-<insert>` | `yank` | 粘贴最近剪切的内容 |
| `S-<insertchar>` | `yank` | 粘贴最近剪切的内容 |
| `s-<kp-bar>` | `shell-command-on-region` | 把选中区域作为输入执行 shell 命令 |
| `s-<left>` | `move-beginning-of-line` | 跳到行首 |
| `s-<right>` | `move-end-of-line` | 跳到行尾 |
| `s-=` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `s-?` | `info` | 打开 Info 文档浏览器 |
| `s-^` | `kill-some-buffers` | 逐个询问并关闭缓冲区 |
| `s-`` | `other-frame` | 切到另一个窗体 |
| `s-a` | `mark-whole-buffer` | 全选 |
| `s-C` | `ns-popup-color-panel` | 打开系统取色面板（macOS） |
| `s-c` | `ns-copy-including-secondary` | 复制并包含次要选区（macOS） |
| `s-D` | `dired` | 打开目录管理器 |
| `s-d` | `isearch-repeat-backward` | 重复向前搜索 |
| `s-E` | `edit-abbrevs` | 编辑缩写定义列表 |
| `s-e` | `isearch-yank-kill` | 把剪切环内容加入搜索词 |
| `s-F` | `isearch-backward` | 向前增量搜索 |
| `s-f` | `isearch-forward` | 向后增量搜索 |
| `s-g` | `isearch-repeat-forward` | 重复向后搜索 |
| `s-H` | `ns-do-hide-others` | 隐藏其他应用（macOS） |
| `s-h` | `ns-do-hide-emacs` | 隐藏 Emacs（macOS） |
| `s-j` | `exchange-point-and-mark` | 交换光标与标记的位置 |
| `s-k` | `kill-current-buffer` | 关闭当前缓冲区 |
| `s-L` | `shell-command` | 执行 shell 命令并显示输出 |
| `s-l` | `goto-line` | 跳到指定行号 |
| `s-M` | `manual-entry` | 查看 man 手册页 |
| `s-m` | `iconify-frame` | 最小化窗体 |
| `s-n` | `make-frame` | 新建一个窗体显示当前缓冲区 |
| `s-o` | `ns-open-file-using-panel` | 用系统面板打开文件（macOS） |
| `s-p` | `ns-print-buffer` | 打印缓冲区（macOS） |
| `s-q` | `save-buffers-kill-emacs` | 保存并退出 Emacs |
| `s-S` | `ns-write-file-using-panel` | 用系统面板另存为（macOS） |
| `s-s` | `save-buffer` | 保存当前文件 |
| `s-t` | `menu-set-font` | 选择并设置默认字体 |
| `s-u` | `revert-buffer` | 丢弃修改，从磁盘重新加载文件 |
| `s-v` | `yank` | 粘贴最近剪切的内容 |
| `s-w` | `delete-frame` | 关闭当前窗体 |
| `s-x` | `kill-region` | 剪切选中区域 |
| `s-y` | `ns-paste-secondary` | 粘贴次要选区（macOS） |
| `s-z` | `undo` | 撤销 |
| `s-|` | `shell-command-on-region` | 把选中区域作为输入执行 shell 命令 |
| `s-~` | `ns-prev-frame` | 切到上一个窗体（macOS） |
| `TAB` | `indent-for-tab-command` | 缩进当前行或区域，或插入制表符 |
| `<f1> .` | `display-local-help` | 在回显区显示光标处的提示文字 |
| `<f1> <f1>` | `help-for-help` | 显示帮助命令的总览 |
| `<f1> <help>` | `help-for-help` | 显示帮助命令的总览 |
| `<f1> ?` | `help-for-help` | 显示帮助命令的总览 |
| `<f1> a` | `apropos-command` | 按关键词搜索命令 |
| `<f1> B` | `embark-bindings` | 用检索方式浏览当前可用按键 |
| `<f1> b` | `describe-bindings` | 列出当前所有按键绑定 |
| `<f1> C` | `describe-coding-system` | 查看编码系统的说明 |
| `<f1> c` | `describe-key-briefly` | 简要显示某个按键调用的命令名 |
| `<f1> C-\` | `describe-input-method` | 查看输入法说明 |
| `<f1> C-a` | `about-emacs` | 显示 Emacs 关于页面 |
| `<f1> C-c` | `describe-copying` | 显示 GNU 许可证条款 |
| `<f1> C-d` | `view-emacs-debugging` | 查看如何调试 Emacs 问题 |
| `<f1> C-e` | `view-external-packages` | 查看如何获取更多插件 |
| `<f1> C-f` | `view-emacs-FAQ` | 查看 Emacs 常见问题 |
| `<f1> C-h` | `help-for-help` | 显示帮助命令的总览 |
| `<f1> C-n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `<f1> C-o` | `describe-distribution` | 显示如何获取最新版 Emacs |
| `<f1> C-p` | `view-emacs-problems` | 查看已知问题和规避办法 |
| `<f1> C-q` | `help-quick-toggle` | 开关常用命令速查窗口 |
| `<f1> C-s` | `search-forward-help-for-help` | 在帮助窗口中向后搜索 |
| `<f1> C-t` | `view-emacs-todo` | 查看 Emacs 的待办列表 |
| `<f1> C-w` | `describe-no-warranty` | 显示免责声明 |
| `<f1> d` | `apropos-documentation` | 按关键词搜索文档内容 |
| `<f1> e` | `view-echo-area-messages` | 查看 *Messages* 消息日志 |
| `<f1> F` | `Info-goto-emacs-command-node` | 跳到 Emacs 手册中讲某命令的节 |
| `<f1> f` | `describe-function` | 查看某个函数的完整文档 |
| `<f1> g` | `describe-gnu-project` | 浏览 GNU 项目介绍 |
| `<f1> h` | `view-hello-file` | 查看多语言示例文件 |
| `<f1> I` | `describe-input-method` | 查看输入法说明 |
| `<f1> i` | `info` | 打开 Info 文档浏览器 |
| `<f1> K` | `Info-goto-emacs-key-command-node` | 跳到 Emacs 手册中讲某按键的节 |
| `<f1> k` | `describe-key` | 查看某个按键调用的命令及其文档 |
| `<f1> L` | `describe-language-environment` | 查看语言环境说明 |
| `<f1> l` | `view-lossage` | 查看最近的按键和触发的命令 |
| `<f1> m` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `<f1> n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `<f1> o` | `describe-symbol` | 查看某个符号的完整文档 |
| `<f1> P` | `describe-package` | 查看某个插件的说明 |
| `<f1> p` | `finder-by-keyword` | 按关键词查找 Emacs 插件 |
| `<f1> q` | `help-quit` | 退出帮助命令 |
| `<f1> R` | `info-display-manual` | 打开指定的 Info 手册 |
| `<f1> r` | `info-emacs-manual` | 打开 Emacs 手册 |
| `<f1> RET` | `view-order-manuals` | 查看如何购买纸质手册 |
| `<f1> S` | `info-lookup-symbol` | 在相关手册中查阅光标处符号 |
| `<f1> s` | `describe-syntax` | 查看当前语法表的定义 |
| `<f1> t` | `help-with-tutorial` | 打开 Emacs 入门教程 |
| `<f1> v` | `describe-variable` | 查看某个变量的完整文档 |
| `<f1> w` | `where-is` | 查看某个命令绑定在哪些按键上 |
| `<f1> x` | `describe-command` | 查看某个命令的完整文档 |
| `<f2> 2` | `2C-two-columns` | 纵向分割窗口，进入双栏编辑 |
| `<f2> <f2>` | `2C-two-columns` | 纵向分割窗口，进入双栏编辑 |
| `<f2> b` | `2C-associate-buffer` | 把另一个缓冲区关联为双栏编辑的第二栏 |
| `<f2> s` | `2C-split` | 在光标处把双栏文本拆成两个缓冲区 |
| `<help> .` | `display-local-help` | 在回显区显示光标处的提示文字 |
| `<help> <f1>` | `help-for-help` | 显示帮助命令的总览 |
| `<help> <help>` | `help-for-help` | 显示帮助命令的总览 |
| `<help> ?` | `help-for-help` | 显示帮助命令的总览 |
| `<help> a` | `apropos-command` | 按关键词搜索命令 |
| `<help> B` | `embark-bindings` | 用检索方式浏览当前可用按键 |
| `<help> b` | `describe-bindings` | 列出当前所有按键绑定 |
| `<help> C` | `describe-coding-system` | 查看编码系统的说明 |
| `<help> c` | `describe-key-briefly` | 简要显示某个按键调用的命令名 |
| `<help> C-\` | `describe-input-method` | 查看输入法说明 |
| `<help> C-a` | `about-emacs` | 显示 Emacs 关于页面 |
| `<help> C-c` | `describe-copying` | 显示 GNU 许可证条款 |
| `<help> C-d` | `view-emacs-debugging` | 查看如何调试 Emacs 问题 |
| `<help> C-e` | `view-external-packages` | 查看如何获取更多插件 |
| `<help> C-f` | `view-emacs-FAQ` | 查看 Emacs 常见问题 |
| `<help> C-h` | `help-for-help` | 显示帮助命令的总览 |
| `<help> C-n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `<help> C-o` | `describe-distribution` | 显示如何获取最新版 Emacs |
| `<help> C-p` | `view-emacs-problems` | 查看已知问题和规避办法 |
| `<help> C-q` | `help-quick-toggle` | 开关常用命令速查窗口 |
| `<help> C-s` | `search-forward-help-for-help` | 在帮助窗口中向后搜索 |
| `<help> C-t` | `view-emacs-todo` | 查看 Emacs 的待办列表 |
| `<help> C-w` | `describe-no-warranty` | 显示免责声明 |
| `<help> d` | `apropos-documentation` | 按关键词搜索文档内容 |
| `<help> e` | `view-echo-area-messages` | 查看 *Messages* 消息日志 |
| `<help> F` | `Info-goto-emacs-command-node` | 跳到 Emacs 手册中讲某命令的节 |
| `<help> f` | `describe-function` | 查看某个函数的完整文档 |
| `<help> g` | `describe-gnu-project` | 浏览 GNU 项目介绍 |
| `<help> h` | `view-hello-file` | 查看多语言示例文件 |
| `<help> I` | `describe-input-method` | 查看输入法说明 |
| `<help> i` | `info` | 打开 Info 文档浏览器 |
| `<help> K` | `Info-goto-emacs-key-command-node` | 跳到 Emacs 手册中讲某按键的节 |
| `<help> k` | `describe-key` | 查看某个按键调用的命令及其文档 |
| `<help> L` | `describe-language-environment` | 查看语言环境说明 |
| `<help> l` | `view-lossage` | 查看最近的按键和触发的命令 |
| `<help> m` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `<help> n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `<help> o` | `describe-symbol` | 查看某个符号的完整文档 |
| `<help> P` | `describe-package` | 查看某个插件的说明 |
| `<help> p` | `finder-by-keyword` | 按关键词查找 Emacs 插件 |
| `<help> q` | `help-quit` | 退出帮助命令 |
| `<help> R` | `info-display-manual` | 打开指定的 Info 手册 |
| `<help> r` | `info-emacs-manual` | 打开 Emacs 手册 |
| `<help> RET` | `view-order-manuals` | 查看如何购买纸质手册 |
| `<help> S` | `info-lookup-symbol` | 在相关手册中查阅光标处符号 |
| `<help> s` | `describe-syntax` | 查看当前语法表的定义 |
| `<help> t` | `help-with-tutorial` | 打开 Emacs 入门教程 |
| `<help> v` | `describe-variable` | 查看某个变量的完整文档 |
| `<help> w` | `where-is` | 查看某个命令绑定在哪些按键上 |
| `<help> x` | `describe-command` | 查看某个命令的完整文档 |
| `ESC <begin>` | `beginning-of-buffer-other-window` | 跳到另一窗口缓冲区的开头 |
| `ESC <end>` | `end-of-buffer-other-window` | 跳到另一窗口缓冲区的末尾 |
| `ESC <f10>` | `toggle-frame-maximized` | 切换最大化 |
| `ESC <home>` | `beginning-of-buffer-other-window` | 跳到另一窗口缓冲区的开头 |
| `ESC <left>` | `backward-word` | 向前移动一个词 |
| `ESC <next>` | `scroll-other-window` | 另一窗口向下翻页 |
| `ESC <prior>` | `scroll-other-window-down` | 另一窗口向上翻页 |
| `ESC <right>` | `forward-word` | 向后移动一个词 |
| `ESC C-<backspace>` | `backward-kill-sexp` | 删除光标前的一个括号表达式 |
| `ESC C-<delete>` | `backward-kill-sexp` | 删除光标前的一个括号表达式 |
| `ESC C-<down>` | `down-list` | 向内进入一层括号 |
| `ESC C-<end>` | `end-of-defun` | 跳到当前函数末尾 |
| `ESC C-<home>` | `beginning-of-defun` | 跳到当前函数开头 |
| `ESC C-<left>` | `backward-sexp` | 向前跨过一个括号表达式 |
| `ESC C-<right>` | `forward-sexp` | 向后跨过一个括号表达式 |
| `ESC C-<up>` | `backward-up-list` | 向外跳出一层括号 |
| `ESC M-:` | `eval-expression` | 求值一个 Lisp 表达式并显示结果 |
| `<f1> 4 i` | `info-other-window` | 在另一窗口打开 Info |
| `<f1> 4 s` | `help-find-source` | 跳到帮助页面所描述对象的源码 |
| `<help> 4 i` | `info-other-window` | 在另一窗口打开 Info |
| `<help> 4 s` | `help-find-source` | 跳到帮助页面所描述对象的源码 |
| `ESC ESC ESC` | `keyboard-escape-quit` | 退出当前状态（关弹窗、取消选区等） |

### C-M- 开头 —— 按表达式操作

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-M-%` | `query-replace-regexp` | 按正则逐处确认替换 |
| `C-M-,` | `xref-go-forward` | 跳回前进方向的位置 |
| `C-M-.` | `xref-find-apropos` | 按模式查找所有相关符号 |
| `C-M-/` | `dabbrev-completion` | 按缓冲区内已有的词补全 |
| `C-M-<backspace>` | `backward-kill-sexp` | 删除光标前的一个括号表达式 |
| `C-M-<delete>` | `backward-kill-sexp` | 删除光标前的一个括号表达式 |
| `C-M-<down>` | `down-list` | 向内进入一层括号 |
| `C-M-<end>` | `end-of-defun` | 跳到当前函数末尾 |
| `C-M-<home>` | `beginning-of-defun` | 跳到当前函数开头 |
| `C-M-<left>` | `backward-sexp` | 向前跨过一个括号表达式 |
| `C-M-<right>` | `forward-sexp` | 向后跨过一个括号表达式 |
| `C-M-<up>` | `backward-up-list` | 向外跳出一层括号 |
| `C-M-@` | `mark-sexp` | 选中一个括号表达式 |
| `C-M-\` | `indent-region` | 缩进区域内每一非空行 |
| `C-M-_` | `undo-redo` | 重做 |
| `C-M-a` | `beginning-of-defun` | 跳到当前函数开头 |
| `C-M-b` | `backward-sexp` | 向前跨过一个括号表达式 |
| `C-M-c` | `exit-recursive-edit` | 退出递归编辑 |
| `C-M-d` | `down-list` | 向内进入一层括号 |
| `C-M-e` | `end-of-defun` | 跳到当前函数末尾 |
| `C-M-f` | `forward-sexp` | 向后跨过一个括号表达式 |
| `C-M-h` | `mark-defun` | 选中当前函数 |
| `C-M-i` | `complete-symbol` | 补全光标处的符号 |
| `C-M-j` | `default-indent-new-line` | 断行并缩进 |
| `C-M-k` | `kill-sexp` | 剪切光标后的一个括号表达式 |
| `C-M-l` | `reposition-window` | 滚动窗口让当前定义完整可见 |
| `C-M-n` | `forward-list` | 向后跨过一组括号 |
| `C-M-o` | `split-line` | 在光标处断开，后半部分下移 |
| `C-M-p` | `backward-list` | 向前跨过一组括号 |
| `C-M-r` | `isearch-backward-regexp` | 向前按正则增量搜索 |
| `C-M-s` | `isearch-forward-regexp` | 向后按正则增量搜索 |
| `C-M-S-l` | `recenter-other-window` | 把另一窗口的当前行居中 |
| `C-M-S-v` | `scroll-other-window-down` | 另一窗口向上翻页 |
| `C-M-SPC` | `mark-sexp` | 选中一个括号表达式 |
| `C-M-t` | `transpose-sexps` | 交换前后两个括号表达式 |
| `C-M-u` | `backward-up-list` | 向外跳出一层括号 |
| `C-M-v` | `scroll-other-window` | 另一窗口向下翻页 |
| `C-M-w` | `append-next-kill` | 让下一次剪切追加到上一次的内容后面 |

### C-c —— 自定义键位

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-c A` | `agent-shell` | 打开或复用当前项目的智能体会话 |
| `C-c a` | `org-agenda` | 打开 Org 议程视图 |
| `C-c c` | `compile` | 编译当前项目，默认运行 make |
| `C-c C-c` | `recompile` | 用上次的命令重新编译 |
| `C-c m` | `consult-mode-command` | 列出当前模式提供的命令 |
| `C-c M-g` | `magit-file-dispatch` | 打开针对当前文件的 Magit 菜单 |
| `C-c n` | `org-capture` | 快速记录（捕获） |
| `C-c o` | `my-reveal-in-file-manager` | 在 Finder/Dolphin 中显示当前文件（前缀参数打开所在目录） |
| `C-c r` | `revert-buffer` | 丢弃修改，从磁盘重新加载文件 |
| `C-c t` | `treemacs` | 打开或关闭项目树 |
| `C-c V` | `vterm-other-window` | 在另一窗口打开 vterm 终端 |
| `C-c v` | `vterm` | 在当前窗口打开 vterm 终端 |
| `C-c Z` | `my-zoxide-dired` | 用 zoxide 跳到常用目录并打开 Dired |
| `C-c z` | `my-zoxide-find-file` | 用 zoxide 跳到常用目录并打开其中文件 |
| `C-c b ?` | `embr-info` | 查看 embr 的安装诊断信息 |
| `C-c b b` | `my-browser-open` | 打开 embr 浏览器并提示输入网址 |
| `C-c b i` | `embr-browse-incognito` | 用隐身会话打开网址 |
| `C-c e a` | `mc/mark-all-like-this` | 标记全文中所有与选区相同的地方 |
| `C-c e l` | `mc/edit-lines` | 给选中区域的每一行加一个光标 |
| `C-c e n` | `mc/skip-to-next-like-this` | 跳过当前处，标记下一处 |
| `C-c e p` | `mc/skip-to-previous-like-this` | 跳过当前处，标记上一处 |
| `C-c e r` | `mc/mark-all-in-region` | 在区域内标记所有匹配处 |
| `C-c e SPC` | `mc/vertical-align-with-space` | 用空格把所有光标对齐 |
| `C-c e u` | `mc/unmark-next-like-this` | 取消下一处的标记 |
| `C-c g b` | `magit-blame-addition` | 逐行显示是哪次提交加进来的 |

### C-h —— 帮助

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-h .` | `display-local-help` | 在回显区显示光标处的提示文字 |
| `C-h <f1>` | `help-for-help` | 显示帮助命令的总览 |
| `C-h <help>` | `help-for-help` | 显示帮助命令的总览 |
| `C-h ?` | `help-for-help` | 显示帮助命令的总览 |
| `C-h a` | `apropos-command` | 按关键词搜索命令 |
| `C-h B` | `embark-bindings` | 用检索方式浏览当前可用按键 |
| `C-h b` | `describe-bindings` | 列出当前所有按键绑定 |
| `C-h C` | `describe-coding-system` | 查看编码系统的说明 |
| `C-h c` | `describe-key-briefly` | 简要显示某个按键调用的命令名 |
| `C-h C-\` | `describe-input-method` | 查看输入法说明 |
| `C-h C-a` | `about-emacs` | 显示 Emacs 关于页面 |
| `C-h C-c` | `describe-copying` | 显示 GNU 许可证条款 |
| `C-h C-d` | `view-emacs-debugging` | 查看如何调试 Emacs 问题 |
| `C-h C-e` | `view-external-packages` | 查看如何获取更多插件 |
| `C-h C-f` | `view-emacs-FAQ` | 查看 Emacs 常见问题 |
| `C-h C-h` | `help-for-help` | 显示帮助命令的总览 |
| `C-h C-n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `C-h C-o` | `describe-distribution` | 显示如何获取最新版 Emacs |
| `C-h C-p` | `view-emacs-problems` | 查看已知问题和规避办法 |
| `C-h C-q` | `help-quick-toggle` | 开关常用命令速查窗口 |
| `C-h C-s` | `search-forward-help-for-help` | 在帮助窗口中向后搜索 |
| `C-h C-t` | `view-emacs-todo` | 查看 Emacs 的待办列表 |
| `C-h C-w` | `describe-no-warranty` | 显示免责声明 |
| `C-h d` | `apropos-documentation` | 按关键词搜索文档内容 |
| `C-h e` | `view-echo-area-messages` | 查看 *Messages* 消息日志 |
| `C-h F` | `Info-goto-emacs-command-node` | 跳到 Emacs 手册中讲某命令的节 |
| `C-h f` | `describe-function` | 查看某个函数的完整文档 |
| `C-h g` | `describe-gnu-project` | 浏览 GNU 项目介绍 |
| `C-h h` | `view-hello-file` | 查看多语言示例文件 |
| `C-h I` | `describe-input-method` | 查看输入法说明 |
| `C-h i` | `info` | 打开 Info 文档浏览器 |
| `C-h K` | `Info-goto-emacs-key-command-node` | 跳到 Emacs 手册中讲某按键的节 |
| `C-h k` | `describe-key` | 查看某个按键调用的命令及其文档 |
| `C-h L` | `describe-language-environment` | 查看语言环境说明 |
| `C-h l` | `view-lossage` | 查看最近的按键和触发的命令 |
| `C-h m` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `C-h n` | `view-emacs-news` | 查看 Emacs 新版变更 |
| `C-h o` | `describe-symbol` | 查看某个符号的完整文档 |
| `C-h P` | `describe-package` | 查看某个插件的说明 |
| `C-h p` | `finder-by-keyword` | 按关键词查找 Emacs 插件 |
| `C-h q` | `help-quit` | 退出帮助命令 |
| `C-h R` | `info-display-manual` | 打开指定的 Info 手册 |
| `C-h r` | `info-emacs-manual` | 打开 Emacs 手册 |
| `C-h RET` | `view-order-manuals` | 查看如何购买纸质手册 |
| `C-h S` | `info-lookup-symbol` | 在相关手册中查阅光标处符号 |
| `C-h s` | `describe-syntax` | 查看当前语法表的定义 |
| `C-h t` | `help-with-tutorial` | 打开 Emacs 入门教程 |
| `C-h v` | `describe-variable` | 查看某个变量的完整文档 |
| `C-h w` | `where-is` | 查看某个命令绑定在哪些按键上 |
| `C-h x` | `describe-command` | 查看某个命令的完整文档 |
| `C-h 4 i` | `info-other-window` | 在另一窗口打开 Info |
| `C-h 4 s` | `help-find-source` | 跳到帮助页面所描述对象的源码 |

### C-x —— 文件、缓冲区与窗口

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x #` | `server-edit` | 处理完当前文件，切到下一个客户端文件 |
| `C-x $` | `set-selective-display` | 按缩进层级折叠显示 |
| `C-x '` | `expand-abbrev` | 展开光标前的缩写 |
| `C-x (` | `kmacro-start-macro` | 开始录制键盘宏 |
| `C-x )` | `kmacro-end-macro` | 结束宏录制 |
| `C-x *` | `calc-dispatch` | 打开 Emacs 计算器 |
| `C-x +` | `balance-windows` | 平均分配各窗口大小 |
| `C-x -` | `shrink-window-if-larger-than-buffer` | 把窗口缩到刚好容纳内容 |
| `C-x .` | `set-fill-prefix` | 把当前行开头设为折行前缀 |
| `C-x 0` | `delete-window` | 关闭当前窗口 |
| `C-x 1` | `delete-other-windows` | 只保留当前窗口 |
| `C-x 2` | `split-window-below` | 上下分割窗口 |
| `C-x 3` | `split-window-right` | 左右分割窗口 |
| `C-x ;` | `comment-set-column` | 以光标位置设定注释对齐列 |
| `C-x <` | `scroll-left` | 画面向左滚动 |
| `C-x <left>` | `previous-buffer` | 切到上一个缓冲区 |
| `C-x <right>` | `next-buffer` | 切到下一个缓冲区 |
| `C-x =` | `what-cursor-position` | 显示光标位置和字符信息 |
| `C-x >` | `scroll-right` | 画面向右滚动 |
| `C-x [` | `backward-page` | 向前移动到分页符 |
| `C-x \` | `my-rotate-windows-counterclockwise` | 两窗口布局逆时针旋转 |
| `C-x ]` | `forward-page` | 向后移动到分页符 |
| `C-x ^` | `enlarge-window` | 增高当前窗口 |
| `C-x `` | `next-error` | 跳到下一条错误及其源码位置 |
| `C-x b` | `consult-buffer` | 切换缓冲区（带预览和虚拟缓冲区） |
| `C-x C-+` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `C-x C--` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `C-x C-0` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `C-x C-;` | `comment-line` | 注释或取消注释当前行 |
| `C-x C-<left>` | `previous-buffer` | 切到上一个缓冲区 |
| `C-x C-<right>` | `next-buffer` | 切到下一个缓冲区 |
| `C-x C-=` | `text-scale-adjust` | 调整当前缓冲区的字号 |
| `C-x C-@` | `pop-global-mark` | 跳回全局标记环中的上一个位置 |
| `C-x C-b` | `list-buffers` | 列出所有缓冲区 |
| `C-x C-c` | `save-buffers-kill-terminal` | 保存并关闭当前连接 |
| `C-x C-d` | `consult-dir` | 选择目录并在其中操作 |
| `C-x C-e` | `eval-last-sexp` | 求值光标前的表达式 |
| `C-x C-f` | `find-file` | 打开文件 |
| `C-x C-j` | `dired-jump` | 跳到当前文件所在的 Dired 目录 |
| `C-x C-l` | `downcase-region` | 把区域转为小写 |
| `C-x C-M-+` | `global-text-scale-adjust` | 调整所有缓冲区的字号 |
| `C-x C-M--` | `global-text-scale-adjust` | 调整所有缓冲区的字号 |
| `C-x C-M-0` | `global-text-scale-adjust` | 调整所有缓冲区的字号 |
| `C-x C-M-=` | `global-text-scale-adjust` | 调整所有缓冲区的字号 |
| `C-x C-n` | `set-goal-column` | 固定上下移动时的目标列 |
| `C-x C-o` | `delete-blank-lines` | 清理光标周围的空行 |
| `C-x C-p` | `mark-page` | 选中当前页 |
| `C-x C-q` | `read-only-mode` | 开关只读 |
| `C-x C-r` | `consult-recent-file` | 从最近打开过的文件中选择 |
| `C-x C-s` | `save-buffer` | 保存当前文件 |
| `C-x C-SPC` | `pop-global-mark` | 跳回全局标记环中的上一个位置 |
| `C-x C-t` | `transpose-lines` | 交换当前行与上一行 |
| `C-x C-u` | `upcase-region` | 把区域转为大写 |
| `C-x C-v` | `find-alternate-file` | 打开另一个文件并关掉当前缓冲区 |
| `C-x C-w` | `write-file` | 另存为 |
| `C-x C-x` | `exchange-point-and-mark` | 交换光标与标记的位置 |
| `C-x C-z` | `suspend-frame` | 挂起或最小化当前窗体 |
| `C-x d` | `dired` | 打开目录管理器 |
| `C-x DEL` | `backward-kill-sentence` | 向前删到句首 |
| `C-x e` | `kmacro-end-and-call-macro` | 结束录制并执行宏 |
| `C-x f` | `set-fill-column` | 设置自动折行的列宽 |
| `C-x g` | `magit-status` | 打开当前仓库的 Magit 状态页 |
| `C-x h` | `mark-whole-buffer` | 全选 |
| `C-x i` | `insert-file` | 把文件内容插入到此处 |
| `C-x k` | `kill-buffer` | 关闭指定缓冲区 |
| `C-x l` | `count-lines-page` | 统计当前页的行数 |
| `C-x m` | `compose-mail` | 撰写邮件 |
| `C-x M-:` | `repeat-complex-command` | 编辑并重新执行上一条复杂命令 |
| `C-x M-g` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `C-x o` | `other-window` | 切到另一个窗口 |
| `C-x q` | `kbd-macro-query` | 执行宏时暂停询问 |
| `C-x s` | `save-some-buffers` | 逐个询问并保存已修改的文件 |
| `C-x SPC` | `rectangle-mark-mode` | 切换成矩形选区 |
| `C-x TAB` | `indent-rigidly` | 把区域内所有行整体左右移动 |
| `C-x u` | `undo` | 撤销 |
| `C-x z` | `repeat` | 重复上一个命令 |
| `C-x {` | `shrink-window-horizontally` | 减小窗口宽度 |
| `C-x |` | `my-rotate-windows-clockwise` | 两窗口布局顺时针旋转 |
| `C-x }` | `enlarge-window-horizontally` | 加宽当前窗口 |
| `C-x ESC ESC` | `repeat-complex-command` | 编辑并重新执行上一条复杂命令 |
| `C-x x f` | `font-lock-update` | 重新计算语法高亮 |
| `C-x x g` | `revert-buffer-quick` | 重新加载文件，少问几句 |
| `C-x x i` | `insert-buffer` | 把另一个缓冲区的内容插入到此处 |
| `C-x x n` | `clone-buffer` | 复制当前缓冲区为一个副本 |
| `C-x x r` | `rename-buffer` | 重命名当前缓冲区 |
| `C-x x t` | `toggle-truncate-lines` | 开关长行截断（不折行） |
| `C-x x u` | `rename-uniquely` | 把缓冲区改成不重名的名字 |

### C-x 4 —— 在另一个窗口

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x 4 .` | `xref-find-definitions-other-window` | 在另一窗口跳到定义 |
| `C-x 4 0` | `kill-buffer-and-window` | 关闭当前缓冲区并关掉窗口 |
| `C-x 4 1` | `same-window-prefix` | 让下一个命令在当前窗口中显示 |
| `C-x 4 4` | `other-window-prefix` | 让下一个命令在新窗口中显示 |
| `C-x 4 a` | `add-change-log-entry-other-window` | 在另一窗口打开 ChangeLog 并添加条目 |
| `C-x 4 b` | `consult-buffer-other-window` | 在另一窗口切换缓冲区 |
| `C-x 4 c` | `clone-indirect-buffer-other-window` | 在另一窗口打开当前缓冲区的间接副本 |
| `C-x 4 C-f` | `find-file-other-window` | 在另一窗口打开文件 |
| `C-x 4 C-j` | `dired-jump-other-window` | 在另一窗口跳到当前文件所在目录 |
| `C-x 4 C-o` | `display-buffer` | 在某个窗口显示缓冲区但不切过去 |
| `C-x 4 d` | `dired-other-window` | 在另一窗口打开目录 |
| `C-x 4 f` | `find-file-other-window` | 在另一窗口打开文件 |
| `C-x 4 m` | `compose-mail-other-window` | 在另一窗口撰写邮件 |
| `C-x 4 p` | `project-other-window-command` | 执行项目命令，结果显示在另一窗口 |
| `C-x 4 r` | `find-file-read-only-other-window` | 在另一窗口以只读方式打开文件 |

### C-x 5 —— 在另一个窗体

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x 5 .` | `xref-find-definitions-other-frame` | 在新窗体中跳到定义 |
| `C-x 5 0` | `delete-frame` | 关闭当前窗体 |
| `C-x 5 1` | `delete-other-frames` | 关闭其他所有窗体 |
| `C-x 5 2` | `make-frame-command` | 在同一终端上新建窗体 |
| `C-x 5 5` | `other-frame-prefix` | 让下一个命令在新窗体中显示 |
| `C-x 5 b` | `switch-to-buffer-other-frame` | 在新窗体中切换缓冲区 |
| `C-x 5 c` | `clone-frame` | 复制当前窗体 |
| `C-x 5 C-f` | `find-file-other-frame` | 在新窗体中打开文件 |
| `C-x 5 C-o` | `display-buffer-other-frame` | 优先在另一窗体显示缓冲区 |
| `C-x 5 d` | `dired-other-frame` | 在新窗体中打开目录 |
| `C-x 5 f` | `find-file-other-frame` | 在新窗体中打开文件 |
| `C-x 5 m` | `compose-mail-other-frame` | 在新窗体中撰写邮件 |
| `C-x 5 o` | `other-frame` | 切到另一个窗体 |
| `C-x 5 p` | `project-other-frame-command` | 执行项目命令，结果显示在新窗体 |
| `C-x 5 r` | `find-file-read-only-other-frame` | 在新窗体中以只读方式打开文件 |
| `C-x 5 u` | `undelete-frame` | 恢复刚关闭的窗体 |

### C-x 6 —— 双栏编辑

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x 6 2` | `2C-two-columns` | 纵向分割窗口，进入双栏编辑 |
| `C-x 6 <f2>` | `2C-two-columns` | 纵向分割窗口，进入双栏编辑 |
| `C-x 6 b` | `2C-associate-buffer` | 把另一个缓冲区关联为双栏编辑的第二栏 |
| `C-x 6 s` | `2C-split` | 在光标处把双栏文本拆成两个缓冲区 |

### C-x 8 —— 特殊字符输入

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x 8 RET` | `insert-char` | 按 Unicode 名称或码位插入字符 |
| `C-x 8 e +` | `emoji-zoom-increase` | 放大光标处字符 |
| `C-x 8 e -` | `emoji-zoom-decrease` | 缩小光标处字符 |
| `C-x 8 e 0` | `emoji-zoom-reset` | 恢复光标处字符大小 |
| `C-x 8 e d` | `emoji-describe` | 显示光标处表情符号的名称 |
| `C-x 8 e e` | `emoji-insert` | 按分类选择并插入表情符号 |
| `C-x 8 e i` | `emoji-insert` | 按分类选择并插入表情符号 |
| `C-x 8 e l` | `emoji-list` | 列出所有表情符号供选择 |
| `C-x 8 e r` | `emoji-recent` | 从最近用过的表情符号中选择 |
| `C-x 8 e s` | `emoji-search` | 按名称搜索表情符号 |

### C-x C-k —— 键盘宏

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x C-k b` | `kmacro-bind-to-key` | 把最后录制的宏绑定到某个按键 |
| `C-x C-k C-a` | `kmacro-add-counter` | 给宏计数器加上指定值 |
| `C-x C-k C-c` | `kmacro-set-counter` | 设置宏计数器的值 |
| `C-x C-k C-d` | `kmacro-delete-ring-head` | 从宏环中删掉当前宏 |
| `C-x C-k C-e` | `kmacro-edit-macro-repeat` | 编辑最后录制的宏（可重复） |
| `C-x C-k C-f` | `kmacro-set-format` | 设置宏计数器的输出格式 |
| `C-x C-k C-k` | `kmacro-end-or-call-macro-repeat` | 同上，且可连按重复执行 |
| `C-x C-k C-l` | `kmacro-call-ring-2nd-repeat` | 执行宏环中的第二个宏 |
| `C-x C-k C-n` | `kmacro-cycle-ring-next` | 切到宏环中的下一个宏 |
| `C-x C-k C-p` | `kmacro-cycle-ring-previous` | 切到宏环中的上一个宏 |
| `C-x C-k C-s` | `kmacro-start-macro` | 开始录制键盘宏 |
| `C-x C-k C-t` | `kmacro-swap-ring` | 交换宏环中的前两个宏 |
| `C-x C-k C-v` | `kmacro-view-macro-repeat` | 查看最后录制的宏 |
| `C-x C-k d` | `kmacro-redisplay` | 宏执行过程中强制刷新显示 |
| `C-x C-k e` | `edit-kbd-macro` | 编辑一个键盘宏 |
| `C-x C-k l` | `kmacro-edit-lossage` | 把最近 300 次按键编辑成一个宏 |
| `C-x C-k n` | `kmacro-name-last-macro` | 给最后录制的宏起个名字 |
| `C-x C-k q` | `kbd-macro-query` | 执行宏时暂停询问 |
| `C-x C-k r` | `apply-macro-to-region-lines` | 对区域内每一行执行上一个键盘宏 |
| `C-x C-k RET` | `kmacro-edit-macro` | 编辑最后录制的宏 |
| `C-x C-k s` | `kmacro-start-macro` | 开始录制键盘宏 |
| `C-x C-k SPC` | `kmacro-step-edit-macro` | 单步编辑并执行上一个宏 |
| `C-x C-k TAB` | `kmacro-insert-counter` | 插入宏计数器的当前值并递增 |
| `C-x C-k x` | `kmacro-to-register` | 把最后录制的宏存入寄存器 |
| `C-x C-k C-q <` | `kmacro-quit-counter-less` | 计数器小于指定值时终止宏 |
| `C-x C-k C-q =` | `kmacro-quit-counter-equal` | 计数器等于指定值时终止宏 |
| `C-x C-k C-q >` | `kmacro-quit-counter-greater` | 计数器大于指定值时终止宏 |
| `C-x C-k C-r l` | `kmacro-reg-load-counter` | 从寄存器载入宏计数器的值 |
| `C-x C-k C-r s` | `kmacro-reg-save-counter` | 把宏计数器的值存入寄存器 |

### C-x RET —— 编码系统

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x RET c` | `universal-coding-system-argument` | 指定编码后执行下一个读写命令 |
| `C-x RET C-\` | `set-input-method` | 选择并启用输入法 |
| `C-x RET F` | `set-file-name-coding-system` | 设置文件名的编码 |
| `C-x RET f` | `set-buffer-file-coding-system` | 设置当前文件的编码 |
| `C-x RET k` | `set-keyboard-coding-system` | 设置键盘输入的编码 |
| `C-x RET l` | `set-language-environment` | 设置语言环境 |
| `C-x RET p` | `set-buffer-process-coding-system` | 设置进程通信的编码 |
| `C-x RET r` | `revert-buffer-with-coding-system` | 用指定编码重新加载文件 |
| `C-x RET t` | `set-terminal-coding-system` | 设置终端输出的编码 |
| `C-x RET X` | `set-next-selection-coding-system` | 设置下次剪贴板交互的编码 |
| `C-x RET x` | `set-selection-coding-system` | 设置剪贴板交互的编码 |

### C-x X —— 键盘宏

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x X =` | `edebug-display-freq-count` | 显示各行的执行次数统计 |
| `C-x X a` | `abort-recursive-edit` | 中止递归编辑或小缓冲输入 |
| `C-x X b` | `edebug-set-breakpoint` | 在最近的表达式处设断点 |
| `C-x X C` | `edebug-Continue-fast-mode` | 不停顿地快速跟踪执行 |
| `C-x X c` | `edebug-continue-mode` | 进入连续执行模式 |
| `C-x X D` | `edebug-toggle-disable-breakpoint` | 启用或禁用附近的断点 |
| `C-x X G` | `edebug-Go-nonstop-mode` | 不调试地直接运行完 |
| `C-x X g` | `edebug-go-mode` | 运行到下一个断点 |
| `C-x X Q` | `edebug-top-level-nonstop` | 切到不停模式并退回顶层 |
| `C-x X q` | `top-level` | 退出所有递归编辑层 |
| `C-x X SPC` | `edebug-step-mode` | 单步执行到下一个停靠点 |
| `C-x X T` | `edebug-Trace-fast-mode` | 不停顿地快速跟踪 |
| `C-x X t` | `edebug-trace-mode` | 进入跟踪模式 |
| `C-x X U` | `edebug-unset-breakpoints` | 清除当前定义中的所有断点 |
| `C-x X u` | `edebug-unset-breakpoint` | 清除最近的断点 |
| `C-x X W` | `edebug-toggle-save-windows` | 开关调试时的窗口布局保存 |
| `C-x X w` | `edebug-where` | 显示调试窗口和当前停在哪里 |
| `C-x X X` | `edebug-set-global-break-condition` | 设置全局断点条件 |
| `C-x X x` | `edebug-set-conditional-breakpoint` | 设置条件断点 |

### C-x a —— 缩写

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x a '` | `expand-abbrev` | 展开光标前的缩写 |
| `C-x a +` | `add-mode-abbrev` | 为光标前的词定义当前模式的缩写 |
| `C-x a -` | `inverse-add-global-abbrev` | 把光标前的词定义为全局缩写的缩写形式 |
| `C-x a C-a` | `add-mode-abbrev` | 为光标前的词定义当前模式的缩写 |
| `C-x a e` | `expand-abbrev` | 展开光标前的缩写 |
| `C-x a g` | `add-global-abbrev` | 为光标前的词定义全局缩写 |
| `C-x a l` | `add-mode-abbrev` | 为光标前的词定义当前模式的缩写 |
| `C-x a n` | `expand-jump-to-next-slot` | 跳到展开结果的下一个填空位 |
| `C-x a p` | `expand-jump-to-previous-slot` | 跳到展开结果的上一个填空位 |
| `C-x a i g` | `inverse-add-global-abbrev` | 把光标前的词定义为全局缩写的缩写形式 |
| `C-x a i l` | `inverse-add-mode-abbrev` | 把光标前的词定义为模式缩写的缩写形式 |

### C-x n —— 只显示局部

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x n d` | `narrow-to-defun` | 只显示当前函数 |
| `C-x n g` | `goto-line-relative` | 跳到相对于可见区域开头的行号 |
| `C-x n n` | `narrow-to-region` | 只显示选中区域 |
| `C-x n p` | `narrow-to-page` | 只显示当前页 |
| `C-x n w` | `widen` | 取消只显示局部的限制 |

### C-x p —— 项目

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x p !` | `project-shell-command` | 在项目根目录执行 shell 命令 |
| `C-x p &` | `project-async-shell-command` | 在项目根目录异步执行 shell 命令 |
| `C-x p b` | `project-switch-to-buffer` | 在当前项目的缓冲区之间切换 |
| `C-x p c` | `project-compile` | 在项目根目录编译 |
| `C-x p C-b` | `project-list-buffers` | 列出当前项目的缓冲区 |
| `C-x p D` | `project-dired` | 打开项目根目录的 Dired |
| `C-x p d` | `project-find-dir` | 在项目内选择目录并打开 |
| `C-x p e` | `project-eshell` | 在项目根目录打开 Eshell |
| `C-x p F` | `project-or-external-find-file` | 在项目或外部根目录中查找文件 |
| `C-x p f` | `project-find-file` | 在项目内按文件名检索并打开 |
| `C-x p G` | `project-or-external-find-regexp` | 在项目或外部根目录中搜索正则 |
| `C-x p g` | `project-find-regexp` | 在项目内搜索正则 |
| `C-x p k` | `project-kill-buffers` | 关闭当前项目的所有缓冲区 |
| `C-x p o` | `project-any-command` | 在当前项目下执行任意命令 |
| `C-x p p` | `project-switch-project` | 切换到另一个项目 |
| `C-x p r` | `project-query-replace-regexp` | 在项目所有文件中按正则逐处替换 |
| `C-x p s` | `project-shell` | 在项目根目录打开 shell |
| `C-x p v` | `project-vc-dir` | 打开项目的版本控制目录视图 |
| `C-x p x` | `project-execute-extended-command` | 在项目根目录下执行 M-x 命令 |

### C-x r —— 寄存器与矩形

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x r +` | `increment-register` | 给寄存器中的数值加上前缀参数 |
| `C-x r b` | `bookmark-jump` | 跳转到指定书签 |
| `C-x r c` | `clear-rectangle` | 清空矩形区域内的文本 |
| `C-x r C-@` | `point-to-register` | 把当前位置存入寄存器 |
| `C-x r C-SPC` | `point-to-register` | 把当前位置存入寄存器 |
| `C-x r d` | `delete-rectangle` | 删除矩形区域（不进剪切环） |
| `C-x r f` | `frameset-to-register` | 把当前窗体布局存入寄存器 |
| `C-x r g` | `insert-register` | 插入寄存器中的内容 |
| `C-x r i` | `insert-register` | 插入寄存器中的内容 |
| `C-x r j` | `jump-to-register` | 跳到寄存器中保存的位置或恢复窗口布局 |
| `C-x r k` | `kill-rectangle` | 剪切矩形区域 |
| `C-x r l` | `bookmark-bmenu-list` | 列出所有书签 |
| `C-x r M` | `bookmark-set-no-overwrite` | 设置书签，不覆盖同名书签 |
| `C-x r m` | `bookmark-set` | 在当前位置设置书签 |
| `C-x r M-w` | `copy-rectangle-as-kill` | 复制矩形区域 |
| `C-x r N` | `rectangle-number-lines` | 在矩形区域前插入行号 |
| `C-x r n` | `number-to-register` | 把数字存入寄存器 |
| `C-x r o` | `open-rectangle` | 插入空白矩形，把文字整体右移 |
| `C-x r r` | `copy-rectangle-to-register` | 把矩形区域存入寄存器 |
| `C-x r s` | `copy-to-register` | 把区域文本存入寄存器 |
| `C-x r SPC` | `point-to-register` | 把当前位置存入寄存器 |
| `C-x r t` | `string-rectangle` | 用指定字符串替换矩形区域每行 |
| `C-x r w` | `window-configuration-to-register` | 把当前窗口布局存入寄存器 |
| `C-x r x` | `copy-to-register` | 把区域文本存入寄存器 |
| `C-x r y` | `yank-rectangle` | 粘贴矩形区域 |

### C-x t —— 标签页

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x t 0` | `tab-close` | 关闭标签页 |
| `C-x t 1` | `tab-close-other` | 关闭其他所有标签页 |
| `C-x t 2` | `tab-new` | 新建标签页 |
| `C-x t <backtab>` | `tab-previous` | 切到上一个标签页 |
| `C-x t <tab>` | `tab-next` | 切到下一个标签页 |
| `C-x t b` | `switch-to-buffer-other-tab` | 在新标签页中切换缓冲区 |
| `C-x t C-f` | `find-file-other-tab` | 在新标签页中打开文件 |
| `C-x t C-r` | `find-file-read-only-other-tab` | 在新标签页中以只读方式打开文件 |
| `C-x t d` | `dired-other-tab` | 在新标签页中打开目录 |
| `C-x t f` | `find-file-other-tab` | 在新标签页中打开文件 |
| `C-x t G` | `tab-group` | 把标签页归入某个分组 |
| `C-x t M` | `tab-move-to` | 把标签页移到指定位置 |
| `C-x t m` | `tab-move` | 移动当前标签页的位置 |
| `C-x t N` | `tab-new-to` | 在指定位置新建标签页 |
| `C-x t n` | `tab-duplicate` | 复制当前标签页 |
| `C-x t O` | `tab-previous` | 切到上一个标签页 |
| `C-x t o` | `tab-next` | 切到下一个标签页 |
| `C-x t p` | `project-other-tab-command` | 执行项目命令，结果显示在新标签页 |
| `C-x t r` | `tab-rename` | 重命名标签页 |
| `C-x t RET` | `tab-switch` | 按名称切换标签页 |
| `C-x t S-<tab>` | `tab-previous` | 切到上一个标签页 |
| `C-x t t` | `other-tab-prefix` | 让下一个命令在新标签页中显示 |
| `C-x t u` | `tab-undo` | 恢复最近关闭的标签页 |
| `C-x t ^ f` | `tab-detach` | 把标签页移到新窗体 |

### C-x v —— 内置版本控制（VC）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x v !` | `vc-edit-next-command` | 执行前先编辑下一条 VC 命令 |
| `C-x v +` | `vc-update` | 更新当前文件或分支 |
| `C-x v =` | `vc-diff` | 查看文件不同版本间的差异 |
| `C-x v a` | `vc-update-change-log` | 从版本日志生成 ChangeLog 条目 |
| `C-x v D` | `vc-root-diff` | 查看整个仓库的差异 |
| `C-x v d` | `vc-dir` | 查看目录的版本控制状态 |
| `C-x v G` | `vc-ignore` | 把文件加入忽略列表 |
| `C-x v g` | `vc-annotate` | 按颜色显示每行的修改历史 |
| `C-x v h` | `vc-region-history` | 查看选中区域的修改历史 |
| `C-x v I` | `vc-log-incoming` | 查看拉取会带来哪些改动 |
| `C-x v i` | `vc-register` | 把文件纳入版本控制 |
| `C-x v L` | `vc-print-root-log` | 查看整个仓库的修改历史 |
| `C-x v l` | `vc-print-log` | 查看当前文件的修改历史 |
| `C-x v m` | `vc-merge` | 执行版本合并 |
| `C-x v O` | `vc-log-outgoing` | 查看推送会送出哪些改动 |
| `C-x v P` | `vc-push` | 推送当前分支 |
| `C-x v r` | `vc-retrieve-tag` | 检出某个标签的版本 |
| `C-x v s` | `vc-create-tag` | 创建标签 |
| `C-x v u` | `vc-revert` | 丢弃改动，恢复到仓库中的版本 |
| `C-x v v` | `vc-next-action` | 按情境执行下一步版本控制操作 |
| `C-x v x` | `vc-delete-file` | 删除文件并在版本控制中标记 |
| `C-x v ~` | `vc-revision-other-window` | 在另一窗口打开某个历史版本 |
| `C-x v b c` | `vc-create-branch` | 创建分支 |
| `C-x v b l` | `vc-print-branch-log` | 查看指定分支的历史 |
| `C-x v b s` | `vc-switch-branch` | 切换分支 |
| `C-x v M D` | `vc-diff-mergebase` | 查看两个版本合并基点之间的差异 |
| `C-x v M L` | `vc-log-mergebase` | 查看合并基点之间的日志 |

### C-x w —— 高亮

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x w -` | `fit-window-to-buffer` | 让窗口高度刚好容纳内容 |
| `C-x w 0` | `delete-windows-on` | 关闭所有显示某缓冲区的窗口 |
| `C-x w 2` | `split-root-window-below` | 把整个窗体上下分割 |
| `C-x w 3` | `split-root-window-right` | 把整个窗体左右分割 |
| `C-x w d` | `toggle-window-dedicated` | 切换窗口是否专用于当前缓冲区 |
| `C-x w q` | `quit-window` | 关闭窗口并把缓冲区沉底 |
| `C-x w s` | `window-toggle-side-windows` | 开关侧边窗口的显示 |
| `C-x w ^ f` | `tear-off-window` | 把当前窗口拆分成独立窗体 |
| `C-x w ^ t` | `tab-window-detach` | 把当前窗口移到新标签页 |

### M-g —— 跳转

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `M-g c` | `goto-char` | 跳到指定字符位置 |
| `M-g g` | `consult-goto-line` | 带预览地跳转到指定行号 |
| `M-g i` | `consult-imenu` | 在当前文件的符号列表中检索跳转 |
| `M-g M-g` | `goto-line` | 跳到指定行号 |
| `M-g M-n` | `next-error` | 跳到下一条错误及其源码位置 |
| `M-g M-p` | `previous-error` | 跳到上一条错误及其源码位置 |
| `M-g n` | `next-error` | 跳到下一条错误及其源码位置 |
| `M-g p` | `previous-error` | 跳到上一条错误及其源码位置 |
| `M-g TAB` | `move-to-column` | 跳到指定列 |

### M-s —— 搜索

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `M-s .` | `isearch-forward-symbol-at-point` | 搜索光标处的符号 |
| `M-s _` | `isearch-forward-symbol` | 按符号向后增量搜索 |
| `M-s d` | `consult-fd` | 用 fd 查找文件 |
| `M-s M-.` | `isearch-forward-thing-at-point` | 搜索光标处的对象 |
| `M-s M-w` | `eww-search-words` | 用选中的文字上网搜索 |
| `M-s o` | `occur` | 列出当前缓冲区所有匹配正则的行 |
| `M-s r` | `consult-ripgrep` | 用 ripgrep 搜索文件内容 |
| `M-s w` | `isearch-forward-word` | 按词向后增量搜索 |
| `M-s h .` | `highlight-symbol-at-point` | 高亮光标处符号的所有出现 |
| `M-s h f` | `hi-lock-find-patterns` | 从缓冲区内读取高亮规则 |
| `M-s h l` | `highlight-lines-matching-regexp` | 高亮所有匹配正则的整行 |
| `M-s h p` | `highlight-phrase` | 高亮匹配的短语 |
| `M-s h r` | `highlight-regexp` | 高亮所有匹配正则的文本 |
| `M-s h u` | `unhighlight-regexp` | 取消某条正则的高亮 |
| `M-s h w` | `hi-lock-write-interactive-patterns` | 把临时高亮规则写入缓冲区 |

## 窗口移动（Windmove）

`windmove-mode` 是全局次模式，这四个键在任何缓冲区里都优先生效。与 `C-x o` 的分工：两个窗口用 `C-x o` 轮换，窗口多了用方向键直接指。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `S-<down>` | `windmove-down` | 切到下方窗口 |
| `S-<left>` | `windmove-left` | 切到左边窗口 |
| `S-<right>` | `windmove-right` | 切到右边窗口 |
| `S-<up>` | `windmove-up` | 切到上方窗口 |

## Which-key 翻页

按下前缀后，提示不止一屏时用 `<f5>` 进入翻页菜单，随后 `n` 下一页、`p` 上一页、`u` 退回一个键、`a` 放弃。前缀后按 `C-h` 则交给 Embark，列出可搜索的绑定表。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-c <f5>` | `which-key-C-h-dispatch` | 进入 which-key 翻页菜单（随后 n/p 翻页） |
| `C-x <f5>` | `which-key-C-h-dispatch` | 进入 which-key 翻页菜单（随后 n/p 翻页） |
| `M-g <f5>` | `which-key-C-h-dispatch` | 进入 which-key 翻页菜单（随后 n/p 翻页） |
| `M-s <f5>` | `which-key-C-h-dispatch` | 进入 which-key 翻页菜单（随后 n/p 翻页） |

## 未提交改动（diff-hl）

在版本控制下的文件中生效，边栏显示改动标记。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-x v *` | `diff-hl-show-hunk` | 弹窗显示光标处改动的前后对比 |
| `C-x v [` | `diff-hl-previous-hunk` | 跳到上一处未提交的改动 |
| `C-x v ]` | `diff-hl-next-hunk` | 跳到下一处未提交的改动 |
| `C-x v n` | `diff-hl-revert-hunk` | 撤销光标处的改动块 |
| `C-x v S` | `diff-hl-stage-dwim` | 暂存光标处的改动块 |
| `C-x v {` | `diff-hl-show-hunk-previous` | 在弹窗中看上一处改动 |
| `C-x v }` | `diff-hl-show-hunk-next` | 在弹窗中看下一处改动 |

## 增量搜索

`C-s` 在本配置里已换成 `consult-line`，但原生增量搜索并没有被拿掉：`C-r` 向前搜、`C-M-s` 和 `C-M-r` 按正则搜、`M-s .` 搜光标处的符号，进入之后以下键位生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<return>` | `isearch-exit` | 结束搜索，停在当前位置 |
| `<xterm-paste>` | `isearch-xterm-paste` | 把终端粘贴的内容加入搜索词 |
| `C-\` | `isearch-toggle-input-method` | 在搜索中开关输入法 |
| `C-^` | `isearch-toggle-specified-input-method` | 选择输入法并在搜索中启用 |
| `C-g` | `isearch-abort` | 中止增量搜索 |
| `C-M-%` | `isearch-query-replace-regexp` | 以当前搜索词开始正则逐处替换 |
| `C-M-d` | `isearch-del-char` | 从搜索词末尾删掉一个字符 |
| `C-M-i` | `isearch-complete` | 用搜索历史补全当前搜索词 |
| `C-M-r` | `isearch-repeat-backward` | 重复向前搜索 |
| `C-M-s` | `isearch-repeat-forward` | 重复向后搜索 |
| `C-M-w` | `isearch-yank-symbol-or-char` | 把下一个符号或字符加入搜索词 |
| `C-M-y` | `isearch-yank-char` | 把缓冲区中下一个字符加入搜索词 |
| `C-M-z` | `isearch-yank-until-char` | 把直到指定字符为止的内容加入搜索词 |
| `C-q` | `isearch-quote-char` | 转义输入特殊字符 |
| `C-r` | `isearch-repeat-backward` | 重复向前搜索 |
| `C-s` | `isearch-repeat-forward` | 重复向后搜索 |
| `C-w` | `isearch-yank-word-or-char` | 把下一个词或字符加入搜索词 |
| `C-y` | `isearch-yank-kill` | 把剪切环内容加入搜索词 |
| `DEL` | `isearch-delete-char` | 撤销上一次搜索输入 |
| `M-%` | `isearch-query-replace` | 以当前搜索词开始逐处替换 |
| `M-c` | `isearch-toggle-case-fold` | 开关大小写敏感 |
| `M-e` | `isearch-edit-string` | 在小缓冲中编辑搜索词 |
| `M-n` | `isearch-ring-advance` | 取搜索历史中的下一条 |
| `M-p` | `isearch-ring-retreat` | 取搜索历史中的上一条 |
| `M-r` | `isearch-toggle-regexp` | 开关正则搜索 |
| `M-y` | `isearch-yank-pop-only` | 用剪切环中更早的内容替换搜索词 |
| `RET` | `isearch-exit` | 结束搜索，停在当前位置 |
| `s-F` | `isearch-repeat-backward` | 重复向前搜索 |
| `s-f` | `isearch-repeat-forward` | 重复向后搜索 |
| `S-SPC` | `isearch-printing-char` | 把输入的字符加入搜索词 |
| `<f1> <f1>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<f1> <help>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<f1> ?` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<f1> b` | `isearch-describe-bindings` | 列出搜索模式下的所有按键 |
| `<f1> C-h` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<f1> k` | `isearch-describe-key` | 查看搜索模式下某个按键的说明 |
| `<f1> m` | `isearch-describe-mode` | 查看增量搜索的文档 |
| `<f1> q` | `help-quit` | 退出帮助命令 |
| `<help> <f1>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<help> <help>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<help> ?` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<help> b` | `isearch-describe-bindings` | 列出搜索模式下的所有按键 |
| `<help> C-h` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `<help> k` | `isearch-describe-key` | 查看搜索模式下某个按键的说明 |
| `<help> m` | `isearch-describe-mode` | 查看增量搜索的文档 |
| `<help> q` | `help-quit` | 退出帮助命令 |
| `C-h <f1>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `C-h <help>` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `C-h ?` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `C-h b` | `isearch-describe-bindings` | 列出搜索模式下的所有按键 |
| `C-h C-h` | `isearch-help-for-help` | 显示增量搜索的帮助菜单 |
| `C-h k` | `isearch-describe-key` | 查看搜索模式下某个按键的说明 |
| `C-h m` | `isearch-describe-mode` | 查看增量搜索的文档 |
| `C-h q` | `help-quit` | 退出帮助命令 |
| `C-x \` | `isearch-transient-input-method` | 临时启用输入法 |
| `M-s '` | `isearch-toggle-char-fold` | 开关字符等价匹配 |
| `M-s _` | `isearch-toggle-symbol` | 开关按符号匹配 |
| `M-s c` | `isearch-toggle-case-fold` | 开关大小写敏感 |
| `M-s C-e` | `isearch-yank-line` | 把本行剩余部分加入搜索词 |
| `M-s e` | `isearch-edit-string` | 在小缓冲中编辑搜索词 |
| `M-s i` | `isearch-toggle-invisible` | 开关搜索隐藏文本 |
| `M-s M-<` | `isearch-beginning-of-buffer` | 跳到搜索词的第一处匹配 |
| `M-s M->` | `isearch-end-of-buffer` | 跳到搜索词的最后一处匹配 |
| `M-s o` | `isearch-occur` | 用当前搜索词列出所有匹配行 |
| `M-s r` | `isearch-toggle-regexp` | 开关正则搜索 |
| `M-s SPC` | `isearch-toggle-lax-whitespace` | 开关空白宽松匹配 |
| `M-s w` | `isearch-toggle-word` | 开关按词匹配 |
| `C-x 8 RET` | `isearch-char-by-name` | 按 Unicode 名称输入字符加入搜索词 |
| `ESC ESC ESC` | `isearch-cancel` | 取消搜索并回到起点 |
| `M-s h l` | `isearch-highlight-lines-matching-regexp` | 退出搜索并高亮所有匹配行 |
| `M-s h r` | `isearch-highlight-regexp` | 退出搜索并高亮所有匹配 |
| `C-x 8 e RET` | `isearch-emoji-by-name` | 按名称把表情符号加入搜索词 |

## 小缓冲输入

在小缓冲里读取参数、文件名、命令名时生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<down>` | `next-line-or-history-element` | 下移一行，或取下一条历史记录 |
| `<next>` | `next-history-element` | 取小缓冲历史中的下一条 |
| `<prior>` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `<up>` | `previous-line-or-history-element` | 上移一行，或取上一条历史记录 |
| `<XF86Back>` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `<XF86Forward>` | `next-history-element` | 取小缓冲历史中的下一条 |
| `C-<tab>` | `file-cache-minibuffer-complete` | 用文件名缓存补全路径 |
| `C-g` | `minibuffer-keyboard-quit` | 取消小缓冲输入 |
| `C-j` | `exit-minibuffer` | 确认小缓冲输入 |
| `M-<` | `minibuffer-beginning-of-buffer` | 跳到小缓冲输入的开头 |
| `M-n` | `next-history-element` | 取小缓冲历史中的下一条 |
| `M-p` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `M-r` | `previous-matching-history-element` | 按正则查找上一条历史记录 |
| `M-s` | `next-matching-history-element` | 按正则查找下一条历史记录 |
| `RET` | `exit-minibuffer` | 确认小缓冲输入 |
| `C-x <down>` | `minibuffer-complete-defaults` | 在默认值中补全 |
| `C-x <up>` | `minibuffer-complete-history` | 用历史记录补全小缓冲输入 |

## 小缓冲候选列表（Vertico）

小缓冲中出现候选列表时生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<down>` | `next-line-or-history-element` | 下移一行，或取下一条历史记录 |
| `<next>` | `next-history-element` | 取小缓冲历史中的下一条 |
| `<prior>` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `<up>` | `previous-line-or-history-element` | 上移一行，或取上一条历史记录 |
| `<XF86Back>` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `<XF86Forward>` | `next-history-element` | 取小缓冲历史中的下一条 |
| `C-<tab>` | `file-cache-minibuffer-complete` | 用文件名缓存补全路径 |
| `C-g` | `minibuffer-keyboard-quit` | 取消小缓冲输入 |
| `C-j` | `exit-minibuffer` | 确认小缓冲输入 |
| `M-<` | `minibuffer-beginning-of-buffer` | 跳到小缓冲输入的开头 |
| `M-n` | `next-history-element` | 取小缓冲历史中的下一条 |
| `M-p` | `previous-history-element` | 取小缓冲历史中的上一条 |
| `M-r` | `previous-matching-history-element` | 按正则查找上一条历史记录 |
| `M-RET` | `vertico-exit-input` | 按输入的原文确认，不用候选项 |
| `M-s` | `next-matching-history-element` | 按正则查找下一条历史记录 |
| `RET` | `exit-minibuffer` | 确认小缓冲输入 |
| `TAB` | `vertico-insert` | 把当前候选项插入小缓冲 |
| `C-x <down>` | `minibuffer-complete-defaults` | 在默认值中补全 |
| `C-x <up>` | `minibuffer-complete-history` | 用历史记录补全小缓冲输入 |
| `C-x C-d` | `consult-dir` | 选择目录并在其中操作 |
| `C-x C-j` | `consult-dir-jump-file` | 从小缓冲中的目录跳到文件 |

## 补全弹窗（Corfu）

代码补全弹窗打开时生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `corfu-previous` | 选中上一个候选项 |
| `<down>` | `corfu-next` | 选中下一个候选项 |
| `<return>` | `corfu-insert` | 插入当前候选项 |
| `<tab>` | `corfu-next` | 选中下一个候选项 |
| `<up>` | `corfu-previous` | 选中上一个候选项 |
| `C-g` | `corfu-quit` | 关闭补全弹窗 |
| `C-M-i` | `corfu-expand` | 补全出所有候选的公共前缀 |
| `M-d` | `corfu-info-documentation` | 查看当前候选项的文档 |
| `M-g` | `corfu-info-location` | 跳到当前候选项的定义位置 |
| `M-h` | `corfu-info-documentation` | 查看当前候选项的文档 |
| `M-n` | `corfu-next` | 选中下一个候选项 |
| `M-p` | `corfu-previous` | 选中上一个候选项 |
| `M-SPC` | `corfu-insert-separator` | 插入分隔符，用于分段过滤候选 |
| `RET` | `corfu-insert` | 插入当前候选项 |
| `S-TAB` | `corfu-previous` | 选中上一个候选项 |
| `TAB` | `corfu-next` | 选中下一个候选项 |

## Embark 操作菜单

`C-.` 之后出现的通用操作。不同类型的目标还有各自的操作表。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `A` | `embark-act-all` | 对所有候选项批量执行操作 |
| `B` | `embark-become` | 把当前命令换成另一个命令重新执行 |
| `C-r` | `embark-isearch-backward` | 以目标为关键词反向增量搜索 |
| `C-s` | `embark-isearch-forward` | 以目标为关键词正向增量搜索 |
| `C-SPC` | `mark` | 返回当前缓冲区的标记位置 |
| `DEL` | `delete-region` | 删除选中区域 |
| `E` | `embark-export` | 把候选项导出为对应类型的专用缓冲区 |
| `i` | `embark-insert` | 把目标插入到当前位置 |
| `L` | `embark-live` | 创建实时更新的候选项缓冲区 |
| `q` | `embark-toggle-quit` | 切换执行操作后是否退出小缓冲 |
| `S` | `embark-collect` | 把候选项收集到一个缓冲区 |
| `SPC` | `embark-select` | 把目标加入或移出当前选择集 |
| `w` | `embark-copy-as-kill` | 把目标复制到剪切环 |
| `C d` | `consult-fd` | 用 fd 查找文件 |
| `C F` | `consult-locate` | 用 locate 查找文件 |
| `C f` | `consult-find` | 用 find 查找文件 |
| `C G` | `consult-git-grep` | 用 git grep 搜索 |
| `C g` | `consult-grep` | 用 grep 搜索文件内容 |
| `C I` | `consult-imenu-multi` | 在项目内所有缓冲区的符号中检索 |
| `C i` | `consult-imenu` | 在当前文件的符号列表中检索跳转 |
| `C L` | `consult-line-multi` | 跨多个缓冲区按行搜索 |
| `C l` | `consult-line` | 在当前缓冲区按行搜索 |
| `C o` | `consult-outline` | 在大纲标题中检索跳转 |
| `C r` | `consult-ripgrep` | 用 ripgrep 搜索文件内容 |

## 编程模式通用

所有编程语言模式共有。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-M-q` | `prog-indent-sexp` | 缩进光标后的整个表达式 |
| `M-q` | `prog-fill-reindent-defun` | 重排注释段落或重新缩进函数 |

## Eglot 语言服务器

语言服务器启动后生效。前缀取 `C-c s`（server）而不是 lsp-mode 惯用的 `C-c l`：前缀键会让同名的单键在整个模式里按不出来，`C-c` 加单个字母的位置有限，不该被一个插件占掉。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-c s a` | `eglot-code-actions` | 列出并执行语言服务器给出的代码操作 |
| `C-c s d` | `eldoc-doc-buffer` | 打开文档缓冲区查看当前符号说明 |
| `C-c s f` | `eglot-format-buffer` | 用语言服务器格式化整个缓冲区 |
| `C-c s q` | `eglot-shutdown` | 关闭语言服务器 |
| `C-c s r` | `eglot-rename` | 重命名当前符号（跨文件） |
| `C-c s s` | `consult-eglot-symbols` | 从语言服务器的符号表中检索并跳转 |

## Flymake 诊断

语法检查开启时生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `M-n` | `flymake-goto-next-error` | 跳到下一个诊断错误 |
| `M-p` | `flymake-goto-prev-error` | 跳到上一个诊断错误 |
| `C-c ! l` | `flymake-show-buffer-diagnostics` | 列出当前文件的所有诊断信息 |
| `C-c ! p` | `flymake-show-project-diagnostics` | 列出整个项目的诊断信息 |

## Python

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `python-indent-dedent-line` | 当前行反缩进 |
| `C-M-i` | `completion-at-point` | 在光标处触发补全 |
| `C-M-x` | `python-shell-send-defun` | 把当前函数发给 Python 进程 |
| `DEL` | `python-indent-dedent-line-backspace` | 退格时按缩进级别反缩进 |
| `C-c <` | `python-indent-shift-left` | 把区域整体左移 |
| `C-c >` | `python-indent-shift-right` | 把区域整体右移 |
| `C-c C-b` | `python-shell-send-block` | 把光标处的代码块发给 Python 进程 |
| `C-c C-c` | `python-shell-send-buffer` | 把整个缓冲区发给 Python 进程 |
| `C-c C-d` | `python-describe-at-point` | 查看光标处对象的帮助 |
| `C-c C-e` | `python-shell-send-statement` | 把光标处的语句发给 Python 进程 |
| `C-c C-f` | `python-eldoc-at-point` | 查看光标处符号的文档 |
| `C-c C-j` | `imenu` | 在当前文件的符号列表中跳转 |
| `C-c C-l` | `python-shell-send-file` | 把指定文件发给 Python 进程 |
| `C-c C-p` | `run-python` | 启动 Python 交互进程 |
| `C-c C-r` | `python-shell-send-region` | 把选中区域发给 Python 进程 |
| `C-c C-s` | `python-shell-send-string` | 把一段字符串发给 Python 进程 |
| `C-c C-v` | `python-check` | 对 Python 文件做静态检查 |
| `C-c C-z` | `python-shell-switch-to-shell` | 切换到 Python 交互进程缓冲区 |
| `C-c C-t c` | `python-skeleton-class` | 插入 class 语句模板 |
| `C-c C-t d` | `python-skeleton-def` | 插入 def 语句模板 |
| `C-c C-t f` | `python-skeleton-for` | 插入 for 语句模板 |
| `C-c C-t i` | `python-skeleton-if` | 插入 if 语句模板 |
| `C-c C-t m` | `python-skeleton-import` | 插入 import 语句模板 |
| `C-c C-t t` | `python-skeleton-try` | 插入 try 语句模板 |
| `C-c C-t w` | `python-skeleton-while` | 插入 while 语句模板 |
| `C-c TAB a` | `python-add-import` | 添加一条 import 语句 |
| `C-c TAB f` | `python-fix-imports` | 补上缺失的 import 并删掉没用的 |
| `C-c TAB r` | `python-remove-import` | 删除一条 import 语句 |
| `C-c TAB s` | `python-sort-imports` | 对 import 语句排序 |

## Python（tree-sitter 模式）

与上一节相同，只是主模式换成了 `python-ts-mode`。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `python-indent-dedent-line` | 当前行反缩进 |
| `C-M-i` | `completion-at-point` | 在光标处触发补全 |
| `C-M-x` | `python-shell-send-defun` | 把当前函数发给 Python 进程 |
| `DEL` | `python-indent-dedent-line-backspace` | 退格时按缩进级别反缩进 |
| `C-c <` | `python-indent-shift-left` | 把区域整体左移 |
| `C-c >` | `python-indent-shift-right` | 把区域整体右移 |
| `C-c C-b` | `python-shell-send-block` | 把光标处的代码块发给 Python 进程 |
| `C-c C-c` | `python-shell-send-buffer` | 把整个缓冲区发给 Python 进程 |
| `C-c C-d` | `python-describe-at-point` | 查看光标处对象的帮助 |
| `C-c C-e` | `python-shell-send-statement` | 把光标处的语句发给 Python 进程 |
| `C-c C-f` | `python-eldoc-at-point` | 查看光标处符号的文档 |
| `C-c C-j` | `imenu` | 在当前文件的符号列表中跳转 |
| `C-c C-l` | `python-shell-send-file` | 把指定文件发给 Python 进程 |
| `C-c C-p` | `run-python` | 启动 Python 交互进程 |
| `C-c C-r` | `python-shell-send-region` | 把选中区域发给 Python 进程 |
| `C-c C-s` | `python-shell-send-string` | 把一段字符串发给 Python 进程 |
| `C-c C-v` | `python-check` | 对 Python 文件做静态检查 |
| `C-c C-z` | `python-shell-switch-to-shell` | 切换到 Python 交互进程缓冲区 |
| `C-c C-t c` | `python-skeleton-class` | 插入 class 语句模板 |
| `C-c C-t d` | `python-skeleton-def` | 插入 def 语句模板 |
| `C-c C-t f` | `python-skeleton-for` | 插入 for 语句模板 |
| `C-c C-t i` | `python-skeleton-if` | 插入 if 语句模板 |
| `C-c C-t m` | `python-skeleton-import` | 插入 import 语句模板 |
| `C-c C-t t` | `python-skeleton-try` | 插入 try 语句模板 |
| `C-c C-t w` | `python-skeleton-while` | 插入 while 语句模板 |
| `C-c TAB a` | `python-add-import` | 添加一条 import 语句 |
| `C-c TAB f` | `python-fix-imports` | 补上缺失的 import 并删掉没用的 |
| `C-c TAB r` | `python-remove-import` | 删除一条 import 语句 |
| `C-c TAB s` | `python-sort-imports` | 对 import 语句排序 |

## C

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `#` | `c-electric-pound` | 插入井号并自动缩进 |
| `(` | `c-electric-paren` | 插入圆括号并自动缩进 |
| `)` | `c-electric-paren` | 插入圆括号并自动缩进 |
| `*` | `c-electric-star` | 插入星号并自动缩进 |
| `,` | `c-electric-semi&comma` | 插入分号或逗号并自动缩进 |
| `/` | `c-electric-slash` | 插入斜杠并自动缩进 |
| `:` | `c-electric-colon` | 插入冒号并自动缩进 |
| `;` | `c-electric-semi&comma` | 插入分号或逗号并自动缩进 |
| `C-d` | `c-electric-delete-forward` | 删除后一个字符或整段空白 |
| `C-M-a` | `c-beginning-of-defun` | 跳到函数开头 |
| `C-M-e` | `c-end-of-defun` | 跳到顶层声明的末尾 |
| `C-M-h` | `c-mark-function` | 选中当前顶层声明 |
| `C-M-q` | `prog-indent-sexp` | 缩进光标后的整个表达式 |
| `DEL` | `c-electric-backspace` | 删除前一个字符或整段空白 |
| `M-a` | `c-beginning-of-statement` | 跳到当前语句开头 |
| `M-e` | `c-end-of-statement` | 跳到当前语句末尾 |
| `M-q` | `prog-fill-reindent-defun` | 重排注释段落或重新缩进函数 |
| `TAB` | `c-indent-line-or-region` | 缩进当前行或选中区域 |
| `{` | `c-electric-brace` | 插入花括号并自动缩进 |
| `}` | `c-electric-brace` | 插入花括号并自动缩进 |
| `C-c .` | `c-set-style` | 切换当前缓冲区的代码风格 |
| `C-c <deletechar>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-<backspace>` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |
| `C-c C-<delete>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-<deletechar>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-\` | `c-backslash-region` | 对齐或删除区域内行尾的续行反斜杠 |
| `C-c C-a` | `c-toggle-auto-newline` | 开关自动换行 |
| `C-c C-b` | `c-submit-bug-report` | 提交 CC Mode 的缺陷报告 |
| `C-c C-c` | `comment-region` | 注释区域内每一行 |
| `C-c C-d` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-DEL` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |
| `C-c C-e` | `c-macro-expand` | 用预处理器展开区域内的 C 宏 |
| `C-c C-k` | `c-toggle-comment-style` | 在块注释与行注释之间切换 |
| `C-c C-l` | `c-toggle-electric-state` | 开关输入时自动缩进 |
| `C-c C-n` | `c-forward-conditional` | 向后跳过一个预处理条件块 |
| `C-c C-o` | `c-set-offset` | 修改某个语法元素的缩进量 |
| `C-c C-p` | `c-backward-conditional` | 向前跳过一个预处理条件块 |
| `C-c C-q` | `c-indent-defun` | 重新缩进当前顶层声明或宏 |
| `C-c C-s` | `c-show-syntactic-information` | 显示当前行的语法分析信息 |
| `C-c C-u` | `c-up-conditional` | 跳到外层预处理条件块 |
| `C-c C-w` | `c-subword-mode` | 开关驼峰词内移动与编辑 |
| `C-c C-z` | `c-display-defun-name` | 显示当前所在函数名及位置 |
| `C-c DEL` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |

## C++

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `#` | `c-electric-pound` | 插入井号并自动缩进 |
| `(` | `c-electric-paren` | 插入圆括号并自动缩进 |
| `)` | `c-electric-paren` | 插入圆括号并自动缩进 |
| `*` | `c-electric-star` | 插入星号并自动缩进 |
| `,` | `c-electric-semi&comma` | 插入分号或逗号并自动缩进 |
| `/` | `c-electric-slash` | 插入斜杠并自动缩进 |
| `:` | `c-electric-colon` | 插入冒号并自动缩进 |
| `;` | `c-electric-semi&comma` | 插入分号或逗号并自动缩进 |
| `<` | `c-electric-lt-gt` | 插入尖括号并自动缩进 |
| `>` | `c-electric-lt-gt` | 插入尖括号并自动缩进 |
| `C-d` | `c-electric-delete-forward` | 删除后一个字符或整段空白 |
| `C-M-a` | `c-beginning-of-defun` | 跳到函数开头 |
| `C-M-e` | `c-end-of-defun` | 跳到顶层声明的末尾 |
| `C-M-h` | `c-mark-function` | 选中当前顶层声明 |
| `C-M-q` | `prog-indent-sexp` | 缩进光标后的整个表达式 |
| `DEL` | `c-electric-backspace` | 删除前一个字符或整段空白 |
| `M-a` | `c-beginning-of-statement` | 跳到当前语句开头 |
| `M-e` | `c-end-of-statement` | 跳到当前语句末尾 |
| `M-q` | `prog-fill-reindent-defun` | 重排注释段落或重新缩进函数 |
| `TAB` | `c-indent-line-or-region` | 缩进当前行或选中区域 |
| `{` | `c-electric-brace` | 插入花括号并自动缩进 |
| `}` | `c-electric-brace` | 插入花括号并自动缩进 |
| `C-c .` | `c-set-style` | 切换当前缓冲区的代码风格 |
| `C-c :` | `c-scope-operator` | 插入作用域运算符 :: |
| `C-c <deletechar>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-<backspace>` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |
| `C-c C-<delete>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-<deletechar>` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-\` | `c-backslash-region` | 对齐或删除区域内行尾的续行反斜杠 |
| `C-c C-a` | `c-toggle-auto-newline` | 开关自动换行 |
| `C-c C-b` | `c-submit-bug-report` | 提交 CC Mode 的缺陷报告 |
| `C-c C-c` | `comment-region` | 注释区域内每一行 |
| `C-c C-d` | `c-hungry-delete-forward` | 向后一次删掉所有连续空白 |
| `C-c C-DEL` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |
| `C-c C-e` | `c-macro-expand` | 用预处理器展开区域内的 C 宏 |
| `C-c C-k` | `c-toggle-comment-style` | 在块注释与行注释之间切换 |
| `C-c C-l` | `c-toggle-electric-state` | 开关输入时自动缩进 |
| `C-c C-n` | `c-forward-conditional` | 向后跳过一个预处理条件块 |
| `C-c C-o` | `c-set-offset` | 修改某个语法元素的缩进量 |
| `C-c C-p` | `c-backward-conditional` | 向前跳过一个预处理条件块 |
| `C-c C-q` | `c-indent-defun` | 重新缩进当前顶层声明或宏 |
| `C-c C-s` | `c-show-syntactic-information` | 显示当前行的语法分析信息 |
| `C-c C-u` | `c-up-conditional` | 跳到外层预处理条件块 |
| `C-c C-w` | `c-subword-mode` | 开关驼峰词内移动与编辑 |
| `C-c C-z` | `c-display-defun-name` | 显示当前所在函数名及位置 |
| `C-c DEL` | `c-hungry-delete-backwards` | 向前一次删掉所有连续空白 |

## Fortran（固定格式）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `0` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `1` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `2` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `3` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `4` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `5` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `6` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `7` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `8` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `9` | `fortran-electric-line-number` | 输入行号时自动缩进 |
| `;` | `fortran-abbrev-start` | 列出 Fortran 的所有缩写 |
| `C-M-j` | `fortran-split-line` | 断行并插入续行标记 |
| `C-M-n` | `fortran-end-of-block` | 跳到当前代码块末尾 |
| `C-M-p` | `fortran-beginning-of-block` | 跳到当前代码块开头 |
| `C-M-q` | `fortran-indent-subprogram` | 重新缩进当前子程序 |
| `M-^` | `fortran-join-line` | 把本行并到上一行并重新缩进 |
| `C-c ;` | `fortran-comment-region` | 注释区域内每一行 |
| `C-c C-d` | `fortran-join-line` | 把本行并到上一行并重新缩进 |
| `C-c C-n` | `fortran-next-statement` | 跳到下一条语句 |
| `C-c C-p` | `fortran-previous-statement` | 跳到上一条语句 |
| `C-c C-r` | `fortran-column-ruler` | 临时显示列标尺 |
| `C-c C-w` | `fortran-window-create-momentarily` | 临时把窗口调成 72 列宽 |

## Fortran 90（自由格式）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `*` | `f90-electric-insert` | 输入运算符时自动调整关键字大小写 |
| `+` | `f90-electric-insert` | 输入运算符时自动调整关键字大小写 |
| `,` | `f90-electric-insert` | 输入运算符时自动调整关键字大小写 |
| `-` | `f90-electric-insert` | 输入运算符时自动调整关键字大小写 |
| `/` | `f90-electric-insert` | 输入运算符时自动调整关键字大小写 |
| ``` | `f90-abbrev-start` | 列出 F90 的所有缩写 |
| `C-j` | `f90-indent-new-line` | 重新缩进本行并换行缩进 |
| `C-M-a` | `f90-beginning-of-subprogram` | 跳到当前子程序开头 |
| `C-M-e` | `f90-end-of-subprogram` | 跳到当前子程序末尾 |
| `C-M-h` | `f90-mark-subprogram` | 选中当前子程序 |
| `C-M-n` | `f90-end-of-block` | 跳到当前代码块末尾 |
| `C-M-p` | `f90-beginning-of-block` | 跳到当前代码块开头 |
| `C-M-q` | `f90-indent-subprogram` | 重新缩进当前子程序 |
| `C-c ;` | `f90-comment-region` | 注释或取消注释区域 |
| `C-c ]` | `f90-insert-end` | 插入与当前块匹配的 end 语句 |
| `C-c C-a` | `f90-previous-block` | 跳到上一个代码块边界 |
| `C-c C-d` | `f90-join-lines` | 把本行并到上一行 |
| `C-c C-e` | `f90-next-block` | 跳到下一个代码块边界 |
| `C-c C-f` | `f90-fill-region` | 重排区域内的折行 |
| `C-c C-n` | `f90-next-statement` | 跳到下一条语句 |
| `C-c C-p` | `f90-previous-statement` | 跳到上一条语句 |
| `C-c C-w` | `f90-insert-end` | 插入与当前块匹配的 end 语句 |
| `C-c RET` | `f90-break-line` | 断行并插入续行符 |

## Org mode

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `org-shifttab` | 全局折叠或展开，表格中跳到上一格 |
| `C-#` | `org-table-rotate-recalc-marks` | 轮换首列的重算标记 |
| `C-'` | `org-cycle-agenda-files` | 在议程文件之间循环切换 |
| `C-,` | `org-cycle-agenda-files` | 在议程文件之间循环切换 |
| `C-<return>` | `org-insert-heading-respect-content` | 在当前内容之后插入新标题 |
| `C-j` | `org-return-and-maybe-indent` | 同上，并按需缩进 |
| `C-M-S-<left>` | `org-decrease-number-at-point` | 光标处的数字减一 |
| `C-M-S-<right>` | `org-increase-number-at-point` | 光标处的数字加一 |
| `C-M-t` | `org-transpose-element` | 交换当前元素与上一个元素 |
| `C-S-<down>` | `org-shiftcontroldown` | 同步调整计时日志中的时间戳 |
| `C-S-<left>` | `org-shiftcontrolleft` | 切换到上一组 TODO 状态 |
| `C-S-<return>` | `org-insert-todo-heading-respect-content` | 在当前子树之后插入 TODO 标题 |
| `C-S-<right>` | `org-shiftcontrolright` | 切换到下一组 TODO 状态 |
| `C-S-<up>` | `org-shiftcontrolup` | 同步调整计时日志中的时间戳 |
| `M-<down>` | `org-metadown` | 子树下移或表格行下移 |
| `M-<left>` | `org-metaleft` | 标题升级、列表项左移或表格列左移 |
| `M-<right>` | `org-metaright` | 标题降级、列表项右移或表格列右移 |
| `M-<up>` | `org-metaup` | 子树上移或表格行上移 |
| `M-h` | `org-mark-element` | 选中当前元素 |
| `M-RET` | `org-meta-return` | 插入新标题，或把区域变成表格 |
| `M-S-<down>` | `org-shiftmetadown` | 把当前行下移 |
| `M-S-<left>` | `org-shiftmetaleft` | 子树升级或删除表格列 |
| `M-S-<return>` | `org-insert-todo-heading` | 插入同级的 TODO 标题 |
| `M-S-<right>` | `org-shiftmetaright` | 子树降级或插入表格列 |
| `M-S-<up>` | `org-shiftmetaup` | 把当前行上移 |
| `M-S-RET` | `org-insert-todo-heading` | 插入同级的 TODO 标题 |
| `M-{` | `org-backward-element` | 向前移动一个元素 |
| `M-}` | `org-forward-element` | 向后移动一个元素 |
| `RET` | `org-return` | 表格中跳到下一行，否则插入换行 |
| `S-<down>` | `org-shiftdown` | 按情境向下调整（状态、优先级、日期） |
| `S-<left>` | `org-shiftleft` | 按情境向左调整（状态、优先级、日期） |
| `S-<return>` | `org-table-copy-down` | 把当前格的值复制到下一行 |
| `S-<right>` | `org-shiftright` | 按情境向右调整（状态、优先级、日期） |
| `S-<up>` | `org-shiftup` | 按情境向上调整 |
| `S-RET` | `org-table-copy-down` | 把当前格的值复制到下一行 |
| `S-TAB` | `org-shifttab` | 全局折叠或展开，表格中跳到上一格 |
| `TAB` | `org-cycle` | 折叠或展开当前标题 |
| `|` | `org-force-self-insert` | 强制按原样插入字符 |
| `C-c !` | `org-timestamp-inactive` | 插入不进议程的时间戳 |
| `C-c #` | `org-update-statistics-cookies` | 更新统计标记（如 [1/3]） |
| `C-c $` | `org-archive-subtree` | 把当前子树归档 |
| `C-c %` | `org-mark-ring-push` | 把当前位置压入标记环 |
| `C-c &` | `org-mark-ring-goto` | 跳回标记环中的上一个位置 |
| `C-c '` | `org-edit-special` | 用专用编辑器编辑光标处元素 |
| `C-c *` | `org-ctrl-c-star` | 计算表格或把行变成标题 |
| `C-c +` | `org-table-sum` | 对表格列中的数字求和 |
| `C-c ,` | `org-priority` | 设置条目优先级 |
| `C-c -` | `org-ctrl-c-minus` | 插入表格分隔线或切换列表符号 |
| `C-c .` | `org-timestamp` | 插入时间戳 |
| `C-c /` | `org-sparse-tree` | 按条件生成稀疏树视图 |
| `C-c :` | `org-toggle-fixed-width` | 开关等宽文本标记 |
| `C-c ;` | `org-toggle-comment` | 把条目标记为注释或取消 |
| `C-c <` | `org-date-from-calendar` | 插入日历中光标所在日期的时间戳 |
| `C-c <down>` | `org-shiftdown` | 按情境向下调整（状态、优先级、日期） |
| `C-c <left>` | `org-shiftleft` | 按情境向左调整（状态、优先级、日期） |
| `C-c <right>` | `org-shiftright` | 按情境向右调整（状态、优先级、日期） |
| `C-c <up>` | `org-shiftup` | 按情境向上调整 |
| `C-c =` | `org-table-eval-formula` | 用公式计算并填入当前格 |
| `C-c >` | `org-goto-calendar` | 打开日历并跳到当前日期 |
| `C-c ?` | `org-table-field-info` | 显示当前单元格的信息 |
| `C-c @` | `org-mark-subtree` | 选中当前子树 |
| `C-c [` | `org-agenda-file-to-front` | 把当前文件加到议程文件列表最前 |
| `C-c \` | `org-match-sparse-tree` | 按标签条件生成稀疏树视图 |
| `C-c ]` | `org-remove-file` | 把当前文件移出议程文件列表 |
| `C-c ^` | `org-sort` | 对条目、表格行或列表排序 |
| `C-c `` | `org-table-edit-field` | 在另一窗口编辑表格单元格 |
| `C-c C-*` | `org-list-make-subtree` | 把普通列表转成标题子树 |
| `C-c C-,` | `org-insert-structure-template` | 插入 #+begin_…/#+end_… 结构块 |
| `C-c C-<tab>` | `org-cycle-force-archived` | 即使已归档也强制折叠展开 |
| `C-c C-^` | `org-up-element` | 跳到上一层元素 |
| `C-c C-_` | `org-down-element` | 进入下一层元素 |
| `C-c C-a` | `org-attach` | 打开附件命令菜单 |
| `C-c C-b` | `org-backward-heading-same-level` | 跳到上一个同级标题 |
| `C-c C-c` | `org-ctrl-c-ctrl-c` | 按情境执行（设标签、更新表格等） |
| `C-c C-d` | `org-deadline` | 设置截止时间 |
| `C-c C-e` | `org-export-dispatch` | 打开导出菜单 |
| `C-c C-f` | `org-forward-heading-same-level` | 跳到下一个同级标题 |
| `C-c C-j` | `org-goto` | 在当前文件中跳转到别处，保持折叠状态 |
| `C-c C-k` | `org-kill-note-or-show-branches` | 放弃当前备注，或只显示各级标题 |
| `C-c C-l` | `org-insert-link` | 插入链接 |
| `C-c C-M-l` | `org-insert-all-links` | 插入所有已存储的链接 |
| `C-c C-M-w` | `org-refile-reverse` | 移动条目，临时反转插入顺序 |
| `C-c C-o` | `org-open-at-point` | 打开光标处的链接或对象 |
| `C-c C-q` | `org-set-tags-command` | 设置当前条目的标签 |
| `C-c C-r` | `org-fold-reveal` | 展开当前条目及其上层结构 |
| `C-c C-s` | `org-schedule` | 设置计划开始时间 |
| `C-c C-t` | `org-todo` | 切换条目的 TODO 状态 |
| `C-c C-w` | `org-refile` | 把条目移动到别的标题下 |
| `C-c C-y` | `org-evaluate-time-range` | 计算时间区间的长度 |
| `C-c C-z` | `org-add-note` | 给当前条目添加备注 |
| `C-c M-b` | `org-previous-block` | 跳到上一个块 |
| `C-c M-f` | `org-next-block` | 跳到下一个块 |
| `C-c M-l` | `org-insert-last-stored-link` | 插入最近存储的链接 |
| `C-c M-w` | `org-refile-copy` | 把条目复制到别的标题下 |
| `C-c RET` | `org-ctrl-c-ret` | 插入表格横线或新建标题 |
| `C-c TAB` | `org-ctrl-c-tab` | 切换表格列宽或展开子标题 |
| `C-c {` | `org-table-toggle-formula-debugger` | 开关表格公式调试器 |
| `C-c |` | `org-table-create-or-convert-from-region` | 把区域转成表格或插入空表格 |
| `C-c }` | `org-table-toggle-coordinate-overlays` | 开关表格行列号显示 |
| `C-c ~` | `org-table-create-with-table.el` | 用 table.el 插入表格 |
| `ESC <down>` | `org-metadown` | 子树下移或表格行下移 |
| `ESC <left>` | `org-metaleft` | 标题升级、列表项左移或表格列左移 |
| `ESC <right>` | `org-metaright` | 标题降级、列表项右移或表格列右移 |
| `ESC <up>` | `org-metaup` | 子树上移或表格行上移 |
| `ESC S-<down>` | `org-shiftmetadown` | 把当前行下移 |
| `ESC S-<left>` | `org-shiftmetaleft` | 子树升级或删除表格列 |
| `ESC S-<right>` | `org-shiftmetaright` | 子树降级或插入表格列 |
| `ESC S-<up>` | `org-shiftmetaup` | 把当前行上移 |
| `C-c " a` | `orgtbl-ascii-plot` | 在表格列中画 ASCII 条形图 |
| `C-c " g` | `org-plot/gnuplot` | 用 gnuplot 绘制表格数据 |
| `C-c C-v a` | `org-babel-sha1-hash` | 计算代码块的 sha1 校验值 |
| `C-c C-v b` | `org-babel-execute-buffer` | 执行全文的代码块 |
| `C-c C-v c` | `org-babel-check-src-block` | 检查代码块头部参数是否拼错 |
| `C-c C-v C-a` | `org-babel-sha1-hash` | 计算代码块的 sha1 校验值 |
| `C-c C-v C-b` | `org-babel-execute-buffer` | 执行全文的代码块 |
| `C-c C-v C-c` | `org-babel-check-src-block` | 检查代码块头部参数是否拼错 |
| `C-c C-v C-d` | `org-babel-demarcate-block` | 包裹或拆分代码块 |
| `C-c C-v C-e` | `org-babel-execute-maybe` | 执行光标处的代码块 |
| `C-c C-v C-f` | `org-babel-tangle-file` | 导出指定文件中的代码块 |
| `C-c C-v C-j` | `org-babel-insert-header-arg` | 插入代码块头部参数 |
| `C-c C-v C-l` | `org-babel-load-in-session` | 把代码块内容载入会话 |
| `C-c C-v C-M-h` | `org-babel-mark-block` | 选中当前代码块 |
| `C-c C-v C-n` | `org-babel-next-src-block` | 跳到下一个代码块 |
| `C-c C-v C-o` | `org-babel-open-src-block-result` | 打开代码块的执行结果 |
| `C-c C-v C-p` | `org-babel-previous-src-block` | 跳到上一个代码块 |
| `C-c C-v C-r` | `org-babel-goto-named-result` | 跳到指定名字的结果 |
| `C-c C-v C-s` | `org-babel-execute-subtree` | 执行当前子树中的代码块 |
| `C-c C-v C-t` | `org-babel-tangle` | 把代码块导出成源文件 |
| `C-c C-v C-u` | `org-babel-goto-src-block-head` | 跳到当前代码块的开头 |
| `C-c C-v C-v` | `org-babel-expand-src-block` | 展开当前代码块的模板变量 |
| `C-c C-v C-x` | `org-babel-do-key-sequence-in-edit-buffer` | 在代码编辑缓冲区中执行某个按键 |
| `C-c C-v C-z` | `org-babel-switch-to-session` | 切换到代码块对应的会话 |
| `C-c C-v d` | `org-babel-demarcate-block` | 包裹或拆分代码块 |
| `C-c C-v e` | `org-babel-execute-maybe` | 执行光标处的代码块 |
| `C-c C-v f` | `org-babel-tangle-file` | 导出指定文件中的代码块 |
| `C-c C-v g` | `org-babel-goto-named-src-block` | 跳到指定名字的代码块 |
| `C-c C-v h` | `org-babel-describe-bindings` | 列出所有 Babel 快捷键 |
| `C-c C-v I` | `org-babel-view-src-block-info` | 查看当前代码块的参数信息 |
| `C-c C-v i` | `org-babel-lob-ingest` | 把文件中的具名代码块收进代码库 |
| `C-c C-v j` | `org-babel-insert-header-arg` | 插入代码块头部参数 |
| `C-c C-v k` | `org-babel-remove-result-one-or-many` | 删除代码块的执行结果 |
| `C-c C-v l` | `org-babel-load-in-session` | 把代码块内容载入会话 |
| `C-c C-v n` | `org-babel-next-src-block` | 跳到下一个代码块 |
| `C-c C-v o` | `org-babel-open-src-block-result` | 打开代码块的执行结果 |
| `C-c C-v p` | `org-babel-previous-src-block` | 跳到上一个代码块 |
| `C-c C-v r` | `org-babel-goto-named-result` | 跳到指定名字的结果 |
| `C-c C-v s` | `org-babel-execute-subtree` | 执行当前子树中的代码块 |
| `C-c C-v t` | `org-babel-tangle` | 把代码块导出成源文件 |
| `C-c C-v TAB` | `org-babel-view-src-block-info` | 查看当前代码块的参数信息 |
| `C-c C-v u` | `org-babel-goto-src-block-head` | 跳到当前代码块的开头 |
| `C-c C-v v` | `org-babel-expand-src-block` | 展开当前代码块的模板变量 |
| `C-c C-v x` | `org-babel-do-key-sequence-in-edit-buffer` | 在代码编辑缓冲区中执行某个按键 |
| `C-c C-v z` | `org-babel-switch-to-session-with-code` | 切到代码缓冲区并显示会话 |
| `C-c C-x !` | `org-reload` | 重新加载所有 Org 的 Lisp 文件 |
| `C-c C-x ,` | `org-timer-pause-or-continue` | 暂停或继续计时器 |
| `C-c C-x -` | `org-timer-item` | 插入带计时读数的列表项 |
| `C-c C-x .` | `org-timer` | 插入计时器的当前读数 |
| `C-c C-x 0` | `org-timer-start` | 启动相对计时器 |
| `C-c C-x ;` | `org-timer-set-timer` | 设置倒计时 |
| `C-c C-x <` | `org-agenda-set-restriction-lock` | 把议程限制在当前子树或文件 |
| `C-c C-x <left>` | `org-shiftcontrolleft` | 切换到上一组 TODO 状态 |
| `C-c C-x <right>` | `org-shiftcontrolright` | 切换到下一组 TODO 状态 |
| `C-c C-x >` | `org-agenda-remove-restriction-lock` | 解除议程的范围限制 |
| `C-c C-x @` | `org-cite-insert` | 插入文献引用 |
| `C-c C-x [` | `org-reftex-citation` | 用 RefTeX 插入文献引用 |
| `C-c C-x \` | `org-toggle-pretty-entities` | 开关实体的美化显示 |
| `C-c C-x _` | `org-timer-stop` | 停止计时器 |
| `C-c C-x A` | `org-archive-to-archive-sibling` | 归档到同级的归档标题下 |
| `C-c C-x a` | `org-toggle-archive-tag` | 开关归档标签 |
| `C-c C-x b` | `org-tree-to-indirect-buffer` | 把当前子树放进独立的间接缓冲区 |
| `C-c C-x c` | `org-clone-subtree-with-time-shift` | 复制子树 N 份并顺延时间戳 |
| `C-c C-x C-a` | `org-archive-subtree-default` | 用默认方式归档当前子树 |
| `C-c C-x C-b` | `org-toggle-checkbox` | 勾选或取消当前行的复选框 |
| `C-c C-x C-c` | `org-columns` | 打开列视图 |
| `C-c C-x C-d` | `org-clock-display` | 在全文显示各子树的计时汇总 |
| `C-c C-x C-f` | `org-emphasize` | 添加或修改强调标记（粗体、斜体等） |
| `C-c C-x C-j` | `org-clock-goto` | 跳到正在计时或最近计时的条目 |
| `C-c C-x C-l` | `org-latex-preview` | 预览光标处的 LaTeX 公式 |
| `C-c C-x C-M-v` | `org-redisplay-inline-images` | 刷新行内图片显示 |
| `C-c C-x C-n` | `org-next-link` | 跳到下一个链接 |
| `C-c C-x C-o` | `org-clock-out` | 停止计时 |
| `C-c C-x C-p` | `org-previous-link` | 跳到上一个链接 |
| `C-c C-x C-q` | `org-clock-cancel` | 取消正在计时的任务 |
| `C-c C-x C-r` | `org-toggle-radio-button` | 把复选框变成单选效果 |
| `C-c C-x C-s` | `org-archive-subtree` | 把当前子树归档 |
| `C-c C-x C-t` | `org-toggle-timestamp-overlays` | 开关自定义时间戳格式 |
| `C-c C-x C-u` | `org-dblock-update` | 更新动态块的内容 |
| `C-c C-x C-v` | `org-toggle-inline-images` | 开关行内图片显示 |
| `C-c C-x C-w` | `org-cut-special` | 剪切表格区域或当前子树 |
| `C-c C-x C-x` | `org-clock-in-last` | 对上次计时的条目重新开始计时 |
| `C-c C-x C-y` | `org-paste-special` | 把矩形区域粘进表格，或按层级粘贴子树 |
| `C-c C-x C-z` | `org-resolve-clocks` | 处理所有未结束的计时 |
| `C-c C-x D` | `org-shiftmetadown` | 把当前行下移 |
| `C-c C-x d` | `org-insert-drawer` | 插入抽屉块 |
| `C-c C-x E` | `org-inc-effort` | 增加当前条目的工作量估计 |
| `C-c C-x e` | `org-set-effort` | 设置当前条目的工作量估计 |
| `C-c C-x f` | `org-footnote-action` | 按情境处理脚注 |
| `C-c C-x G` | `org-feed-goto-inbox` | 跳到某个订阅源的收件箱 |
| `C-c C-x g` | `org-feed-update-all` | 更新所有订阅源 |
| `C-c C-x I` | `org-info-find-node` | 查阅 Org 手册中的对应节 |
| `C-c C-x L` | `org-shiftmetaleft` | 子树升级或删除表格列 |
| `C-c C-x l` | `org-metaleft` | 标题升级、列表项左移或表格列左移 |
| `C-c C-x M` | `org-insert-todo-heading` | 插入同级的 TODO 标题 |
| `C-c C-x m` | `org-meta-return` | 插入新标题，或把区域变成表格 |
| `C-c C-x M-w` | `org-copy-special` | 复制表格区域或当前子树 |
| `C-c C-x o` | `org-toggle-ordered-property` | 开关子任务必须按序完成的属性 |
| `C-c C-x P` | `org-set-property-and-value` | 一次输入属性名和值 |
| `C-c C-x p` | `org-set-property` | 设置当前条目的属性 |
| `C-c C-x q` | `org-toggle-tags-groups` | 开关标签分组支持 |
| `C-c C-x R` | `org-shiftmetaright` | 子树降级或插入表格列 |
| `C-c C-x r` | `org-metaright` | 标题降级、列表项右移或表格列右移 |
| `C-c C-x RET` | `org-meta-return` | 插入新标题，或把区域变成表格 |
| `C-c C-x s` | `org-insert-structure-template` | 插入 #+begin_…/#+end_… 结构块 |
| `C-c C-x TAB` | `org-clock-in` | 对当前条目开始计时 |
| `C-c C-x U` | `org-shiftmetaup` | 把当前行上移 |
| `C-c C-x u` | `org-metaup` | 子树上移或表格行上移 |
| `C-c C-x v` | `org-copy-visible` | 只复制可见部分 |
| `C-c C-x x` | `org-dynamic-block-insert-dblock` | 插入指定类型的动态块 |
| `C-x n b` | `org-narrow-to-block` | 只显示当前块 |
| `C-x n e` | `org-narrow-to-element` | 只显示当前元素 |
| `C-x n s` | `org-narrow-to-subtree` | 只显示当前子树 |

## Markdown

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `markdown-shifttab` | 按情境处理 Shift-Tab（全局折叠） |
| `C-M-{` | `markdown-backward-block` | 跳到当前块的开头 |
| `C-M-}` | `markdown-forward-block` | 跳到当前块的末尾 |
| `DEL` | `markdown-outdent-or-delete` | 退格时按缩进级别回退 |
| `M-n` | `markdown-next-link` | 跳到下一个链接 |
| `M-p` | `markdown-previous-link` | 跳到上一个链接 |
| `M-RET` | `markdown-insert-list-item` | 插入新的列表项 |
| `RET` | `markdown-enter-key` | 按情境处理回车（自动续列表等） |
| `TAB` | `markdown-cycle` | 循环折叠或展开标题 |
| `C-c '` | `markdown-edit-code-block` | 在独立缓冲区中编辑代码块 |
| `C-c -` | `markdown-insert-hr` | 插入水平分割线 |
| `C-c <` | `markdown-outdent-region` | 反缩进区域 |
| `C-c <down>` | `markdown-move-down` | 把光标处的元素下移 |
| `C-c <left>` | `markdown-promote` | 升级或左移光标处的元素 |
| `C-c <right>` | `markdown-demote` | 降级或右移光标处的元素 |
| `C-c <up>` | `markdown-move-up` | 把光标处的元素上移 |
| `C-c >` | `markdown-indent-region` | 按情境缩进区域 |
| `C-c C--` | `markdown-promote` | 升级或左移光标处的元素 |
| `C-c C-=` | `markdown-demote` | 降级或右移光标处的元素 |
| `C-c C-]` | `markdown-complete` | 补全光标处或区域的标记语法 |
| `C-c C-b` | `markdown-outline-previous-same-level` | 跳到上一个同级标题或列表项 |
| `C-c C-d` | `markdown-do` | 按当前情境做合适的事 |
| `C-c C-e` | `preview-at-point` | 预览光标处的公式或图片 |
| `C-c C-f` | `markdown-outline-next-same-level` | 跳到下一个同级标题或列表项 |
| `C-c C-j` | `markdown-insert-list-item` | 插入新的列表项 |
| `C-c C-k` | `markdown-kill-thing-at-point` | 剪切光标处对象，去掉标记后进剪切环 |
| `C-c C-l` | `markdown-insert-link` | 插入或修改链接 |
| `C-c C-M-h` | `markdown-mark-subtree` | 选中当前标题下的整棵子树 |
| `C-c C-n` | `markdown-outline-next` | 跳到下一个列表项或标题 |
| `C-c C-o` | `markdown-follow-thing-at-point` | 跟随光标处的链接 |
| `C-c C-p` | `markdown-outline-previous` | 跳到上一个列表项或标题 |
| `C-c C-u` | `markdown-outline-up` | 跳到上一级标题 |
| `C-c C-v` | `my-markdown-preview-mode` | 以渲染效果查看 Markdown |
| `C-c M-h` | `markdown-mark-block` | 选中当前块 |
| `C-c S-<down>` | `markdown-table-insert-row` | 插入表格行 |
| `C-c S-<left>` | `markdown-table-delete-column` | 删除表格当前列 |
| `C-c S-<right>` | `markdown-table-insert-column` | 插入表格列 |
| `C-c S-<up>` | `markdown-table-delete-row` | 删除表格当前行 |
| `C-c TAB` | `markdown-insert-image` | 插入或修改图片 |
| `C-c C-a f` | `markdown-insert-footnote` | 插入脚注并跳到脚注定义处 |
| `C-c C-a L` | `markdown-insert-link` | 插入或修改链接 |
| `C-c C-a l` | `markdown-insert-link` | 插入或修改链接 |
| `C-c C-a r` | `markdown-insert-link` | 插入或修改链接 |
| `C-c C-a u` | `markdown-insert-uri` | 插入行内网址 |
| `C-c C-a w` | `markdown-insert-wiki-link` | 插入 [[WikiLink]] 形式的链接 |
| `C-c C-c ]` | `markdown-complete-buffer` | 补全全文的标记语法 |
| `C-c C-c ^` | `markdown-table-sort-lines` | 按当前列排序表格 |
| `C-c C-c c` | `markdown-check-refs` | 列出所有未定义的引用 |
| `C-c C-c e` | `markdown-export` | 导出为 HTML 文件 |
| `C-c C-c l` | `markdown-live-preview-mode` | 开关保存时自动预览 |
| `C-c C-c m` | `markdown-other-window` | 渲染当前缓冲区并在另一窗口显示 |
| `C-c C-c n` | `markdown-cleanup-list-numbers` | 重排有序列表的编号 |
| `C-c C-c o` | `markdown-open` | 用外部程序打开当前文件 |
| `C-c C-c p` | `markdown-preview` | 渲染并在浏览器中预览 |
| `C-c C-c t` | `markdown-table-transpose` | 转置表格的行列 |
| `C-c C-c u` | `markdown-unused-refs` | 列出所有没用到的引用定义 |
| `C-c C-c v` | `markdown-export-and-preview` | 导出 HTML 并在浏览器中打开 |
| `C-c C-c w` | `markdown-kill-ring-save` | 把渲染结果复制到剪切环 |
| `C-c C-c |` | `markdown-table-convert-region` | 把区域按分隔符转成表格 |
| `C-c C-s !` | `markdown-insert-header-setext-1` | 插入下划线式一级标题 |
| `C-c C-s -` | `markdown-insert-hr` | 插入水平分割线 |
| `C-c C-s 1` | `markdown-insert-header-atx-1` | 插入一级标题 |
| `C-c C-s 2` | `markdown-insert-header-atx-2` | 插入二级标题 |
| `C-c C-s 3` | `markdown-insert-header-atx-3` | 插入三级标题 |
| `C-c C-s 4` | `markdown-insert-header-atx-4` | 插入四级标题 |
| `C-c C-s 5` | `markdown-insert-header-atx-5` | 插入五级标题 |
| `C-c C-s 6` | `markdown-insert-header-atx-6` | 插入六级标题 |
| `C-c C-s @` | `markdown-insert-header-setext-2` | 插入下划线式二级标题 |
| `C-c C-s [` | `markdown-insert-gfm-checkbox` | 插入任务列表复选框 |
| `C-c C-s b` | `markdown-insert-bold` | 插入粗体标记 |
| `C-c C-s C` | `markdown-insert-gfm-code-block` | 插入带语言标注的代码块 |
| `C-c C-s c` | `markdown-insert-code` | 插入行内代码标记 |
| `C-c C-s e` | `markdown-insert-italic` | 插入斜体标记 |
| `C-c C-s F` | `markdown-insert-foldable-block` | 插入可折叠的 details 块 |
| `C-c C-s f` | `markdown-insert-footnote` | 插入脚注并跳到脚注定义处 |
| `C-c C-s H` | `markdown-insert-header-setext-dwim` | 按情境插入下划线式标题 |
| `C-c C-s h` | `markdown-insert-header-dwim` | 按情境插入或替换标题标记 |
| `C-c C-s i` | `markdown-insert-italic` | 插入斜体标记 |
| `C-c C-s k` | `markdown-insert-kbd` | 用 <kbd> 标签包裹 |
| `C-c C-s l` | `markdown-insert-link` | 插入或修改链接 |
| `C-c C-s P` | `markdown-pre-region` | 把区域变成预格式化文本 |
| `C-c C-s p` | `markdown-insert-pre` | 插入预格式化块 |
| `C-c C-s Q` | `markdown-blockquote-region` | 把区域变成引用块 |
| `C-c C-s q` | `markdown-insert-blockquote` | 插入引用块 |
| `C-c C-s s` | `markdown-insert-strike-through` | 插入删除线标记 |
| `C-c C-s t` | `markdown-insert-table` | 插入空表格 |
| `C-c C-s w` | `markdown-insert-wiki-link` | 插入 [[WikiLink]] 形式的链接 |
| `C-c C-t !` | `markdown-insert-header-setext-1` | 插入下划线式一级标题 |
| `C-c C-t 1` | `markdown-insert-header-atx-1` | 插入一级标题 |
| `C-c C-t 2` | `markdown-insert-header-atx-2` | 插入二级标题 |
| `C-c C-t 3` | `markdown-insert-header-atx-3` | 插入三级标题 |
| `C-c C-t 4` | `markdown-insert-header-atx-4` | 插入四级标题 |
| `C-c C-t 5` | `markdown-insert-header-atx-5` | 插入五级标题 |
| `C-c C-t 6` | `markdown-insert-header-atx-6` | 插入六级标题 |
| `C-c C-t @` | `markdown-insert-header-setext-2` | 插入下划线式二级标题 |
| `C-c C-t H` | `markdown-insert-header-setext-dwim` | 按情境插入下划线式标题 |
| `C-c C-t h` | `markdown-insert-header-dwim` | 按情境插入或替换标题标记 |
| `C-c C-t s` | `markdown-insert-header-setext-2` | 插入下划线式二级标题 |
| `C-c C-t t` | `markdown-insert-header-setext-1` | 插入下划线式一级标题 |
| `C-c C-x a` | `markdown-table-align` | 对齐光标处的表格 |
| `C-c C-x C-e` | `markdown-toggle-math` | 开关 LaTeX 数学公式支持 |
| `C-c C-x C-f` | `markdown-toggle-fontify-code-blocks-natively` | 开关代码块的语法高亮 |
| `C-c C-x C-l` | `markdown-toggle-url-hiding` | 开关网址的隐藏 |
| `C-c C-x C-x` | `markdown-toggle-gfm-checkbox` | 勾选或取消任务列表复选框 |
| `C-c C-x d` | `markdown-move-down` | 把光标处的元素下移 |
| `C-c C-x l` | `markdown-promote` | 升级或左移光标处的元素 |
| `C-c C-x m` | `markdown-insert-list-item` | 插入新的列表项 |
| `C-c C-x r` | `markdown-demote` | 降级或右移光标处的元素 |
| `C-c C-x RET` | `markdown-toggle-markup-hiding` | 开关标记符号的隐藏 |
| `C-c C-x t` | `markdown-toc-generate-or-refresh-toc` | 生成或刷新目录 |
| `C-c C-x TAB` | `markdown-toggle-inline-images` | 开关行内图片显示 |
| `C-c C-x u` | `markdown-move-up` | 把光标处的元素上移 |
| `C-x n b` | `markdown-narrow-to-block` | 只显示当前块 |
| `C-x n s` | `markdown-narrow-to-subtree` | 只显示当前子树 |

## LaTeX（AUCTeX）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `"` | `TeX-insert-quote` | 插入符合 TeX 习惯的引号 |
| `$` | `TeX-insert-dollar` | 插入美元符号（数学模式） |
| `(` | `LaTeX-insert-left-brace` | 插入左花括号并自动补右括号 |
| `-` | `LaTeX-babel-insert-hyphen` | 插入 babel 的连字符 |
| `[` | `LaTeX-insert-left-brace` | 插入左花括号并自动补右括号 |
| `\` | `TeX-insert-backslash` | 插入反斜杠或触发宏补全 |
| `^` | `TeX-insert-sub-or-superscript` | 插入上下标并自动补花括号 |
| `_` | `TeX-insert-sub-or-superscript` | 插入上下标并自动补花括号 |
| `C-j` | `reindent-then-newline-and-indent` | 重新缩进本行，换行并缩进新行 |
| `C-M-i` | `TeX-complete-symbol` | 补全光标前的 TeX 命令 |
| `M-RET` | `LaTeX-insert-item` | 在列表环境中插入新条目 |
| `RET` | `TeX-newline` | 按 AUCTeX 的设定处理换行 |
| `{` | `LaTeX-insert-left-brace` | 插入左花括号并自动补右括号 |
| `C-c "` | `TeX-uncomment` | 取消注释 |
| `C-c #` | `TeX-normal-mode` | 重新解析文件并重新套用样式 |
| `C-c %` | `TeX-comment-or-uncomment-paragraph` | 注释或取消注释当前段落 |
| `C-c '` | `TeX-comment-or-uncomment-paragraph` | 注释或取消注释当前段落 |
| `C-c *` | `LaTeX-mark-section` | 选中当前 section |
| `C-c .` | `LaTeX-mark-environment` | 选中当前环境 |
| `C-c :` | `comment-or-uncomment-region` | 注释或取消注释选中区域 |
| `C-c ;` | `comment-or-uncomment-region` | 注释或取消注释选中区域 |
| `C-c ?` | `TeX-documentation-texdoc` | 用 texdoc 查阅宏包文档 |
| `C-c ]` | `citar-insert-citation` | 插入文献引用 |
| `C-c ^` | `TeX-home-buffer` | 回到上次发出 TeX 命令的缓冲区 |
| `C-c _` | `TeX-master-file-ask` | 设置主文档 |
| `C-c `` | `TeX-next-error` | 跳到编译输出中的下一条错误 |
| `C-c C-a` | `TeX-command-run-all` | 一路编译到完成或出错 |
| `C-c C-b` | `TeX-command-buffer` | 对当前缓冲区运行 TeX 命令 |
| `C-c C-c` | `TeX-command-master` | 对主文档运行 TeX 命令（编译等） |
| `C-c C-d` | `TeX-save-document` | 保存该文档涉及的所有文件 |
| `C-c C-e` | `LaTeX-environment` | 插入 \begin{}…\end{} 环境 |
| `C-c C-f` | `TeX-font` | 插入字体切换命令模板 |
| `C-c C-j` | `LaTeX-insert-item` | 在列表环境中插入新条目 |
| `C-c C-k` | `TeX-kill-job` | 终止正在运行的 TeX 任务 |
| `C-c C-l` | `TeX-recenter-output-buffer` | 把编译输出滚动到最新处 |
| `C-c C-n` | `TeX-normal-mode` | 重新解析文件并重新套用样式 |
| `C-c C-r` | `TeX-command-region` | 只对选中区域运行 TeX |
| `C-c C-s` | `LaTeX-section` | 插入 section 模板 |
| `C-c C-v` | `TeX-view` | 打开阅读器查看编译结果 |
| `C-c C-w` | `TeX-toggle-debug-bad-boxes` | 开关 bad box 警告的显示 |
| `C-c C-z` | `LaTeX-command-section` | 只对当前 section 运行编译命令 |
| `C-c M-z` | `LaTeX-command-section-change-level` | 调整按 section 编译的层级 |
| `C-c RET` | `TeX-insert-macro` | 带补全地插入 TeX 宏 |
| `C-c TAB` | `TeX-goto-info-page` | 查阅 AUCTeX 的 Info 手册 |
| `C-c {` | `TeX-insert-braces` | 插入一对花括号，光标停在里面 |
| `C-c }` | `up-list` | 向外跳出一层括号 |
| `C-c ~` | `LaTeX-math-mode` | 开关数学符号快捷输入 |
| `C-c C-o C-f` | `TeX-fold-mode` | 开关宏和环境的折叠显示 |
| `C-c C-q C-e` | `LaTeX-fill-environment` | 重排并缩进当前环境 |
| `C-c C-q C-p` | `LaTeX-fill-paragraph` | 重排当前段落（识别 LaTeX 注释） |
| `C-c C-q C-r` | `LaTeX-fill-region` | 重排并缩进区域内的文本 |
| `C-c C-q C-s` | `LaTeX-fill-section` | 重排并缩进当前 section |
| `C-c C-t C-b` | `TeX-toggle-debug-bad-boxes` | 开关 bad box 警告的显示 |
| `C-c C-t C-p` | `TeX-PDF-mode` | 开关 PDFTeX 输出模式 |
| `C-c C-t C-r` | `TeX-pin-region` | 固定要编译的区域 |
| `C-c C-t C-s` | `TeX-source-correlate-mode` | 开关源码与 PDF 的正反向定位 |
| `C-c C-t C-w` | `TeX-toggle-debug-warnings` | 开关警告信息的显示 |
| `C-c C-t C-x` | `TeX-toggle-suppress-ignored-warnings` | 开关被忽略警告的显示 |
| `C-c C-t TAB` | `TeX-interactive-mode` | 开关 TeX 的交互运行模式 |
| `C-x n e` | `LaTeX-narrow-to-environment` | 只显示当前环境的内容 |
| `C-x n g` | `TeX-narrow-to-group` | 只显示当前分组 |

## TeX（AUCTeX 通用）

LaTeX 模式继承这一层，上一节列出的是 LaTeX 特有的部分。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `"` | `TeX-insert-quote` | 插入符合 TeX 习惯的引号 |
| `$` | `TeX-insert-dollar` | 插入美元符号（数学模式） |
| `\` | `TeX-insert-backslash` | 插入反斜杠或触发宏补全 |
| `^` | `TeX-insert-sub-or-superscript` | 插入上下标并自动补花括号 |
| `_` | `TeX-insert-sub-or-superscript` | 插入上下标并自动补花括号 |
| `C-M-i` | `TeX-complete-symbol` | 补全光标前的 TeX 命令 |
| `RET` | `TeX-newline` | 按 AUCTeX 的设定处理换行 |
| `C-c "` | `TeX-uncomment` | 取消注释 |
| `C-c #` | `TeX-normal-mode` | 重新解析文件并重新套用样式 |
| `C-c %` | `TeX-comment-or-uncomment-paragraph` | 注释或取消注释当前段落 |
| `C-c '` | `TeX-comment-or-uncomment-paragraph` | 注释或取消注释当前段落 |
| `C-c :` | `comment-or-uncomment-region` | 注释或取消注释选中区域 |
| `C-c ;` | `comment-or-uncomment-region` | 注释或取消注释选中区域 |
| `C-c ?` | `TeX-documentation-texdoc` | 用 texdoc 查阅宏包文档 |
| `C-c ^` | `TeX-home-buffer` | 回到上次发出 TeX 命令的缓冲区 |
| `C-c _` | `TeX-master-file-ask` | 设置主文档 |
| `C-c `` | `TeX-next-error` | 跳到编译输出中的下一条错误 |
| `C-c C-a` | `TeX-command-run-all` | 一路编译到完成或出错 |
| `C-c C-b` | `TeX-command-buffer` | 对当前缓冲区运行 TeX 命令 |
| `C-c C-c` | `TeX-command-master` | 对主文档运行 TeX 命令（编译等） |
| `C-c C-d` | `TeX-save-document` | 保存该文档涉及的所有文件 |
| `C-c C-f` | `TeX-font` | 插入字体切换命令模板 |
| `C-c C-k` | `TeX-kill-job` | 终止正在运行的 TeX 任务 |
| `C-c C-l` | `TeX-recenter-output-buffer` | 把编译输出滚动到最新处 |
| `C-c C-n` | `TeX-normal-mode` | 重新解析文件并重新套用样式 |
| `C-c C-r` | `TeX-command-region` | 只对选中区域运行 TeX |
| `C-c C-v` | `TeX-view` | 打开阅读器查看编译结果 |
| `C-c C-w` | `TeX-toggle-debug-bad-boxes` | 开关 bad box 警告的显示 |
| `C-c RET` | `TeX-insert-macro` | 带补全地插入 TeX 宏 |
| `C-c TAB` | `TeX-goto-info-page` | 查阅 AUCTeX 的 Info 手册 |
| `C-c {` | `TeX-insert-braces` | 插入一对花括号，光标停在里面 |
| `C-c }` | `up-list` | 向外跳出一层括号 |
| `C-c C-o C-f` | `TeX-fold-mode` | 开关宏和环境的折叠显示 |
| `C-c C-t C-b` | `TeX-toggle-debug-bad-boxes` | 开关 bad box 警告的显示 |
| `C-c C-t C-p` | `TeX-PDF-mode` | 开关 PDFTeX 输出模式 |
| `C-c C-t C-r` | `TeX-pin-region` | 固定要编译的区域 |
| `C-c C-t C-s` | `TeX-source-correlate-mode` | 开关源码与 PDF 的正反向定位 |
| `C-c C-t C-w` | `TeX-toggle-debug-warnings` | 开关警告信息的显示 |
| `C-c C-t C-x` | `TeX-toggle-suppress-ignored-warnings` | 开关被忽略警告的显示 |
| `C-c C-t TAB` | `TeX-interactive-mode` | 开关 TeX 的交互运行模式 |
| `C-x n g` | `TeX-narrow-to-group` | 只显示当前分组 |

## Magit 状态页

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `magit-run` | 运行 git 或其他命令 |
| `$` | `magit-process-buffer` | 查看本仓库的 Git 进程输出 |
| `%` | `magit-worktree` | 操作工作树 |
| `+` | `magit-diff-more-context` | 增加差异显示的上下文行数 |
| `-` | `magit-diff-less-context` | 减少差异显示的上下文行数 |
| `0` | `magit-diff-default-context` | 差异上下文行数恢复默认 |
| `1` | `magit-section-show-level-1` | 展开到第一层 |
| `2` | `magit-section-show-level-2` | 展开到第二层 |
| `3` | `magit-section-show-level-3` | 展开到第三层 |
| `4` | `magit-section-show-level-4` | 展开到第四层 |
| `:` | `magit-git-command` | 异步执行任意 git 命令并显示输出 |
| `<backtab>` | `magit-section-cycle-global` | 循环折叠或展开整个缓冲区 |
| `>` | `magit-sparse-checkout` | 配置稀疏检出 |
| `?` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `^` | `magit-section-up` | 跳到父级小节 |
| `A` | `magit-cherry-pick` | 拣选或移植提交 |
| `a` | `magit-cherry-apply` | 把指定提交的改动应用过来但不提交 |
| `B` | `magit-bisect` | 用二分法定位引入问题的提交 |
| `b` | `magit-branch` | 新建、配置或删除分支 |
| `C` | `magit-clone` | 克隆仓库 |
| `c` | `magit-commit` | 创建或修改提交 |
| `C-<return>` | `magit-visit-thing` | 打开光标处的对象 |
| `C-<tab>` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |
| `C-M-i` | `magit-dired-jump` | 用 Dired 打开光标处文件 |
| `C-w` | `magit-copy-section-value` | 复制当前小节的值 |
| `D` | `magit-diff-refresh` | 修改当前缓冲区的 diff 参数 |
| `d` | `magit-diff` | 查看不同版本之间的差异 |
| `DEL` | `magit-diff-show-or-scroll-down` | 显示光标处提交的详情或向下滚动 |
| `E` | `magit-ediff` | 用 Ediff 查看差异 |
| `e` | `magit-ediff-dwim` | 按情境用 Ediff 查看差异 |
| `F` | `magit-pull` | 从远程拉取并合并 |
| `f` | `magit-fetch` | 从远程抓取 |
| `G` | `magit-refresh-all` | 刷新本仓库的所有缓冲区 |
| `g` | `magit-refresh` | 刷新当前仓库的相关缓冲区 |
| `H` | `magit-describe-section` | 查看光标处小节的内部信息 |
| `h` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `I` | `magit-init` | 初始化 Git 仓库 |
| `i` | `magit-gitignore` | 把文件加入 gitignore |
| `J` | `magit-display-repository-buffer` | 切换到本仓库的某个 Magit 缓冲区 |
| `j` | `magit-status-quick` | 快速打开状态页（可能不刷新） |
| `K` | `magit-file-untrack` | 把文件移出版本控制 |
| `k` | `magit-delete-thing` | 删除光标处的对象 |
| `L` | `magit-log-refresh` | 修改当前缓冲区的日志参数 |
| `l` | `magit-log` | 查看提交历史 |
| `M` | `magit-remote` | 添加、配置或删除远程仓库 |
| `m` | `magit-merge` | 合并分支 |
| `M-1` | `magit-section-show-level-1-all` | 所有小节都展开到第一层 |
| `M-2` | `magit-section-show-level-2-all` | 所有小节都展开到第二层 |
| `M-3` | `magit-section-show-level-3-all` | 所有小节都展开到第三层 |
| `M-4` | `magit-section-show-level-4-all` | 所有小节都展开到第四层 |
| `M-<tab>` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |
| `M-n` | `magit-section-forward-sibling` | 跳到下一个同级小节 |
| `M-p` | `magit-section-backward-sibling` | 跳到上一个同级小节 |
| `M-w` | `magit-copy-buffer-revision` | 复制当前缓冲区对应的版本号 |
| `n` | `magit-section-forward` | 跳到下一个可见小节 |
| `O` | `magit-subtree` | 操作 git subtree |
| `o` | `magit-submodule` | 操作子模块 |
| `P` | `magit-push` | 推送到远程 |
| `p` | `magit-section-backward` | 跳到上一个可见小节 |
| `Q` | `magit-git-command` | 异步执行任意 git 命令并显示输出 |
| `q` | `magit-mode-bury-buffer` | 关闭或隐藏当前 Magit 缓冲区 |
| `R` | `magit-file-rename` | 重命名或移动文件（走 git） |
| `r` | `magit-rebase` | 变基，移植或改写提交 |
| `RET` | `magit-visit-thing` | 打开光标处的对象 |
| `S` | `magit-stage-modified` | 暂存所有已修改文件 |
| `s` | `magit-stage-files` | 暂存指定文件的全部改动 |
| `S-SPC` | `magit-diff-show-or-scroll-down` | 显示光标处提交的详情或向下滚动 |
| `SPC` | `magit-diff-show-or-scroll-up` | 显示光标处提交的详情或向上滚动 |
| `T` | `magit-notes` | 编辑附加在提交上的备注 |
| `t` | `magit-tag` | 创建或删除标签 |
| `TAB` | `magit-section-toggle` | 展开或折叠当前小节 |
| `U` | `magit-unstage-all` | 把所有改动移出暂存区 |
| `u` | `magit-unstage-files` | 把指定文件的改动移出暂存区 |
| `V` | `magit-revert` | 回滚已有的提交 |
| `v` | `magit-revert-no-commit` | 把提交反向应用到工作区但不提交 |
| `W` | `magit-patch` | 生成或应用补丁 |
| `w` | `magit-am` | 应用邮件形式的补丁 |
| `X` | `magit-reset` | 把 HEAD、暂存区或工作区重置到某个状态 |
| `x` | `magit-reset-quickly` | 快速重置 HEAD 和暂存区 |
| `Y` | `magit-cherry` | 列出本分支上游没有的提交 |
| `y` | `magit-show-refs` | 列出并比较各个引用（分支、标签） |
| `Z` | `magit-worktree` | 操作工作树 |
| `z` | `magit-stash` | 把未提交的改动贮藏起来 |
| `C-c C-c` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `C-c C-e` | `magit-edit-thing` | 编辑光标处的对象 |
| `C-c C-o` | `magit-browse-thing` | 在浏览器中打开光标处对象 |
| `C-c C-r` | `magit-next-reference` | 跳到下一个 Git 引用 |
| `C-c C-w` | `magit-copy-thing` | 复制光标处的对象 |
| `C-c TAB` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |

## Magit 通用

所有 Magit 缓冲区共有，状态页也继承这一层。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `magit-run` | 运行 git 或其他命令 |
| `$` | `magit-process-buffer` | 查看本仓库的 Git 进程输出 |
| `%` | `magit-worktree` | 操作工作树 |
| `+` | `magit-diff-more-context` | 增加差异显示的上下文行数 |
| `-` | `magit-diff-less-context` | 减少差异显示的上下文行数 |
| `0` | `magit-diff-default-context` | 差异上下文行数恢复默认 |
| `1` | `magit-section-show-level-1` | 展开到第一层 |
| `2` | `magit-section-show-level-2` | 展开到第二层 |
| `3` | `magit-section-show-level-3` | 展开到第三层 |
| `4` | `magit-section-show-level-4` | 展开到第四层 |
| `:` | `magit-git-command` | 异步执行任意 git 命令并显示输出 |
| `<backtab>` | `magit-section-cycle-global` | 循环折叠或展开整个缓冲区 |
| `>` | `magit-sparse-checkout` | 配置稀疏检出 |
| `?` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `^` | `magit-section-up` | 跳到父级小节 |
| `A` | `magit-cherry-pick` | 拣选或移植提交 |
| `a` | `magit-cherry-apply` | 把指定提交的改动应用过来但不提交 |
| `B` | `magit-bisect` | 用二分法定位引入问题的提交 |
| `b` | `magit-branch` | 新建、配置或删除分支 |
| `C` | `magit-clone` | 克隆仓库 |
| `c` | `magit-commit` | 创建或修改提交 |
| `C-<return>` | `magit-visit-thing` | 打开光标处的对象 |
| `C-<tab>` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |
| `C-M-i` | `magit-dired-jump` | 用 Dired 打开光标处文件 |
| `C-w` | `magit-copy-section-value` | 复制当前小节的值 |
| `D` | `magit-diff-refresh` | 修改当前缓冲区的 diff 参数 |
| `d` | `magit-diff` | 查看不同版本之间的差异 |
| `DEL` | `magit-diff-show-or-scroll-down` | 显示光标处提交的详情或向下滚动 |
| `E` | `magit-ediff` | 用 Ediff 查看差异 |
| `e` | `magit-ediff-dwim` | 按情境用 Ediff 查看差异 |
| `F` | `magit-pull` | 从远程拉取并合并 |
| `f` | `magit-fetch` | 从远程抓取 |
| `G` | `magit-refresh-all` | 刷新本仓库的所有缓冲区 |
| `g` | `magit-refresh` | 刷新当前仓库的相关缓冲区 |
| `H` | `magit-describe-section` | 查看光标处小节的内部信息 |
| `h` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `I` | `magit-init` | 初始化 Git 仓库 |
| `i` | `magit-gitignore` | 把文件加入 gitignore |
| `J` | `magit-display-repository-buffer` | 切换到本仓库的某个 Magit 缓冲区 |
| `j` | `magit-status-quick` | 快速打开状态页（可能不刷新） |
| `K` | `magit-file-untrack` | 把文件移出版本控制 |
| `k` | `magit-delete-thing` | 删除光标处的对象 |
| `L` | `magit-log-refresh` | 修改当前缓冲区的日志参数 |
| `l` | `magit-log` | 查看提交历史 |
| `M` | `magit-remote` | 添加、配置或删除远程仓库 |
| `m` | `magit-merge` | 合并分支 |
| `M-1` | `magit-section-show-level-1-all` | 所有小节都展开到第一层 |
| `M-2` | `magit-section-show-level-2-all` | 所有小节都展开到第二层 |
| `M-3` | `magit-section-show-level-3-all` | 所有小节都展开到第三层 |
| `M-4` | `magit-section-show-level-4-all` | 所有小节都展开到第四层 |
| `M-<tab>` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |
| `M-n` | `magit-section-forward-sibling` | 跳到下一个同级小节 |
| `M-p` | `magit-section-backward-sibling` | 跳到上一个同级小节 |
| `M-w` | `magit-copy-buffer-revision` | 复制当前缓冲区对应的版本号 |
| `n` | `magit-section-forward` | 跳到下一个可见小节 |
| `O` | `magit-subtree` | 操作 git subtree |
| `o` | `magit-submodule` | 操作子模块 |
| `P` | `magit-push` | 推送到远程 |
| `p` | `magit-section-backward` | 跳到上一个可见小节 |
| `Q` | `magit-git-command` | 异步执行任意 git 命令并显示输出 |
| `q` | `magit-mode-bury-buffer` | 关闭或隐藏当前 Magit 缓冲区 |
| `R` | `magit-file-rename` | 重命名或移动文件（走 git） |
| `r` | `magit-rebase` | 变基，移植或改写提交 |
| `RET` | `magit-visit-thing` | 打开光标处的对象 |
| `S` | `magit-stage-modified` | 暂存所有已修改文件 |
| `s` | `magit-stage-files` | 暂存指定文件的全部改动 |
| `S-SPC` | `magit-diff-show-or-scroll-down` | 显示光标处提交的详情或向下滚动 |
| `SPC` | `magit-diff-show-or-scroll-up` | 显示光标处提交的详情或向上滚动 |
| `T` | `magit-notes` | 编辑附加在提交上的备注 |
| `t` | `magit-tag` | 创建或删除标签 |
| `TAB` | `magit-section-toggle` | 展开或折叠当前小节 |
| `U` | `magit-unstage-all` | 把所有改动移出暂存区 |
| `u` | `magit-unstage-files` | 把指定文件的改动移出暂存区 |
| `V` | `magit-revert` | 回滚已有的提交 |
| `v` | `magit-revert-no-commit` | 把提交反向应用到工作区但不提交 |
| `W` | `magit-patch` | 生成或应用补丁 |
| `w` | `magit-am` | 应用邮件形式的补丁 |
| `X` | `magit-reset` | 把 HEAD、暂存区或工作区重置到某个状态 |
| `x` | `magit-reset-quickly` | 快速重置 HEAD 和暂存区 |
| `Y` | `magit-cherry` | 列出本分支上游没有的提交 |
| `y` | `magit-show-refs` | 列出并比较各个引用（分支、标签） |
| `Z` | `magit-worktree` | 操作工作树 |
| `z` | `magit-stash` | 把未提交的改动贮藏起来 |
| `C-c C-c` | `magit-dispatch` | 打开 Magit 主命令菜单 |
| `C-c C-e` | `magit-edit-thing` | 编辑光标处的对象 |
| `C-c C-o` | `magit-browse-thing` | 在浏览器中打开光标处对象 |
| `C-c C-r` | `magit-next-reference` | 跳到下一个 Git 引用 |
| `C-c C-w` | `magit-copy-thing` | 复制光标处的对象 |
| `C-c TAB` | `magit-section-cycle` | 循环折叠或展开当前小节及其子节 |

## 合并冲突（Smerge）

打开含冲突标记的文件时自动启用。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-c ^ a` | `smerge-keep-all` | 保留冲突的所有版本 |
| `C-c ^ b` | `smerge-keep-base` | 恢复为共同祖先版本 |
| `C-c ^ C` | `smerge-combine-with-next` | 把当前冲突与下一个合并成一处 |
| `C-c ^ E` | `smerge-ediff` | 用 Ediff 解决冲突 |
| `C-c ^ l` | `smerge-keep-lower` | 保留冲突的下半部分 |
| `C-c ^ m` | `smerge-keep-upper` | 保留冲突的上半部分 |
| `C-c ^ n` | `smerge-next` | 跳到下一处冲突 |
| `C-c ^ o` | `smerge-keep-lower` | 保留冲突的下半部分 |
| `C-c ^ p` | `smerge-prev` | 跳到上一处冲突 |
| `C-c ^ R` | `smerge-refine` | 高亮冲突双方逐词的差异 |
| `C-c ^ r` | `smerge-resolve` | 自动解决当前冲突 |
| `C-c ^ RET` | `smerge-keep-current` | 保留光标所在的那个版本 |
| `C-c ^ u` | `smerge-keep-upper` | 保留冲突的上半部分 |

## 编译与搜索结果

`*compilation*`、`*grep*` 等结果缓冲区。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<backtab>` | `compilation-previous-error` | 跳到上一条编译错误 |
| `<follow-link>` | `mouse-face` | 鼠标相关的显示属性 |
| `>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `?` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `C-o` | `compilation-display-error` | 在另一窗口显示当前错误对应的源码 |
| `DEL` | `scroll-down-command` | 向上翻页 |
| `g` | `revert-buffer` | 丢弃修改，从磁盘重新加载文件 |
| `h` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `M-n` | `compilation-next-error` | 跳到下一条编译错误 |
| `M-p` | `compilation-previous-error` | 跳到上一条编译错误 |
| `M-{` | `compilation-previous-file` | 跳到上一个文件的错误 |
| `M-}` | `compilation-next-file` | 跳到下一个文件的错误 |
| `n` | `next-error-no-select` | 高亮下一条错误但不切换窗口 |
| `p` | `previous-error-no-select` | 高亮上一条错误但不切换窗口 |
| `q` | `quit-window` | 关闭窗口并把缓冲区沉底 |
| `RET` | `compile-goto-error` | 跳转到光标处错误对应的源码 |
| `S-SPC` | `scroll-down-command` | 向上翻页 |
| `SPC` | `scroll-up-command` | 向下翻页 |
| `TAB` | `compilation-next-error` | 跳到下一条编译错误 |
| `C-c C-c` | `compile-goto-error` | 跳转到光标处错误对应的源码 |
| `C-c C-f` | `next-error-follow-minor-mode` | 开关移动光标即跟随显示源码 |
| `C-c C-k` | `kill-compilation` | 终止正在运行的编译进程 |

## Dired 目录管理

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `dired-do-shell-command` | 对标记文件执行 shell 命令 |
| `#` | `dired-flag-auto-save-files` | 标记自动保存文件待删除 |
| `$` | `dired-hide-subdir` | 折叠或展开当前子目录 |
| `&` | `dired-do-async-shell-command` | 对标记文件异步执行 shell 命令 |
| `(` | `dired-hide-details-mode` | 开关详细信息（权限、大小等）的显示 |
| `+` | `dired-create-directory` | 新建目录 |
| `.` | `dired-clean-directory` | 标记编号备份文件待删除 |
| `<` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<follow-link>` | `mouse-face` | 鼠标相关的显示属性 |
| `=` | `dired-diff` | 用 diff 比较光标处文件与另一文件 |
| `>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `?` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `^` | `dired-up-directory` | 进入上级目录 |
| `A` | `dired-do-find-regexp` | 在标记文件中搜索正则 |
| `a` | `dired-find-alternate-file` | 打开该文件并复用当前 Dired 缓冲区 |
| `B` | `dired-do-byte-compile` | 字节编译标记的 Elisp 文件 |
| `C` | `dired-do-copy` | 复制标记的文件 |
| `c` | `dired-do-compress-to` | 把标记的文件压缩成指定压缩包 |
| `C-M-d` | `dired-tree-down` | 在目录树中向下移动 |
| `C-M-n` | `dired-next-subdir` | 跳到下一个子目录 |
| `C-M-p` | `dired-prev-subdir` | 跳到上一个子目录 |
| `C-M-u` | `dired-tree-up` | 在目录树中向上移动 |
| `C-o` | `dired-display-file` | 在另一窗口显示该文件但不切过去 |
| `D` | `dired-do-delete` | 删除标记的文件 |
| `d` | `dired-flag-file-deletion` | 给当前文件打删除标记 |
| `DEL` | `scroll-down-command` | 向上翻页 |
| `E` | `dired-do-open` | 用外部程序打开标记的文件 |
| `F` | `dired-do-find-marked-files` | 同时打开所有标记的文件 |
| `G` | `dired-do-chgrp` | 修改标记文件的属组 |
| `g` | `revert-buffer` | 丢弃修改，从磁盘重新加载文件 |
| `H` | `dired-do-hardlink` | 为标记的文件建立硬链接 |
| `h` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `I` | `dired-do-info` | 用 info 查看该文件 |
| `i` | `dired-maybe-insert-subdir` | 在当前缓冲区内展开子目录 |
| `j` | `dired-goto-file` | 跳到指定文件所在行 |
| `k` | `dired-do-kill-lines` | 把标记的行从列表中移除（不删文件） |
| `L` | `dired-do-load` | 加载标记的 Elisp 文件 |
| `l` | `dired-do-redisplay` | 刷新标记文件的显示 |
| `M` | `dired-do-chmod` | 修改标记文件的权限 |
| `m` | `dired-mark` | 标记光标处的文件 |
| `M-!` | `dired-smart-shell-command` | 在当前目录下执行 shell 命令 |
| `M-$` | `dired-hide-all` | 折叠所有子目录 |
| `M-(` | `dired-mark-sexp` | 按 Lisp 表达式条件标记文件 |
| `M-DEL` | `dired-unmark-all-files` | 取消某一种标记 |
| `M-G` | `dired-goto-subdir` | 跳到某个已插入子目录的标题行 |
| `M-{` | `dired-prev-marked-file` | 跳到上一个标记的文件 |
| `M-}` | `dired-next-marked-file` | 跳到下一个标记的文件 |
| `N` | `dired-do-man` | 用 man 查看该文件 |
| `n` | `dired-next-line` | 下移一行 |
| `O` | `dired-do-chown` | 修改标记文件的属主 |
| `o` | `dired-find-file-other-window` | 在另一窗口打开该文件或目录 |
| `P` | `dired-do-print` | 打印标记的文件 |
| `p` | `dired-previous-line` | 上移一行 |
| `Q` | `dired-do-find-regexp-and-replace` | 在标记文件中批量正则替换 |
| `q` | `quit-window` | 关闭窗口并把缓冲区沉底 |
| `R` | `dired-do-rename` | 重命名或移动标记的文件 |
| `RET` | `dired-find-file` | 打开光标处的文件或目录 |
| `S` | `dired-do-symlink` | 为标记文件建立符号链接 |
| `s` | `dired-sort-toggle-or-edit` | 在按名称和按时间排序之间切换 |
| `S-SPC` | `scroll-down-command` | 向上翻页 |
| `SPC` | `scroll-up-command` | 向下翻页 |
| `T` | `dired-do-touch` | 修改标记文件的时间戳 |
| `t` | `dired-toggle-marks` | 反转标记 |
| `TAB` | `dired-subtree-toggle` | 就地展开或收起光标处的子目录 |
| `U` | `dired-unmark-all-marks` | 取消所有标记 |
| `u` | `dired-unmark` | 取消光标处文件的标记 |
| `V` | `dired-do-run-mail` | 把该文件当作邮箱打开 |
| `v` | `dired-view-file` | 以只读方式查看文件 |
| `W` | `browse-url-of-dired-file` | 用浏览器打开 Dired 中光标所在的文件 |
| `w` | `dired-copy-filename-as-kill` | 复制标记文件的文件名 |
| `X` | `dired-do-shell-command` | 对标记文件执行 shell 命令 |
| `x` | `dired-do-flagged-delete` | 删除所有打了删除标记的文件 |
| `Y` | `dired-do-relsymlink` | 为标记文件建立相对路径符号链接 |
| `y` | `dired-show-file-type` | 显示文件类型（file 命令的结果） |
| `Z` | `dired-do-compress` | 压缩或解压标记的文件 |
| `~` | `dired-flag-backup-files` | 标记备份文件（~ 结尾）待删除 |
| `% &` | `dired-flag-garbage-files` | 标记临时垃圾文件待删除 |
| `% C` | `dired-do-copy-regexp` | 按正则匹配文件名批量复制 |
| `% d` | `dired-flag-files-regexp` | 按正则批量打删除标记 |
| `% g` | `dired-mark-files-containing-regexp` | 按文件内容匹配正则来标记 |
| `% H` | `dired-do-hardlink-regexp` | 按正则批量建立硬链接 |
| `% l` | `dired-downcase` | 把标记文件名改为小写 |
| `% m` | `dired-mark-files-regexp` | 按文件名匹配正则来标记 |
| `% R` | `dired-do-rename-regexp` | 按正则批量重命名 |
| `% r` | `dired-do-rename-regexp` | 按正则批量重命名 |
| `% S` | `dired-do-symlink-regexp` | 按正则批量建立符号链接 |
| `% u` | `dired-upcase` | 把标记文件名改为大写 |
| `% Y` | `dired-do-relsymlink-regexp` | 按正则批量建立相对符号链接 |
| `* !` | `dired-unmark-all-marks` | 取消所有标记 |
| `* %` | `dired-mark-files-regexp` | 按文件名匹配正则来标记 |
| `* (` | `dired-mark-sexp` | 按 Lisp 表达式条件标记文件 |
| `* *` | `dired-mark-executables` | 标记所有可执行文件 |
| `* .` | `dired-mark-extension` | 按扩展名批量标记 |
| `* /` | `dired-mark-directories` | 标记所有目录 |
| `* ?` | `dired-unmark-all-files` | 取消某一种标记 |
| `* @` | `dired-mark-symlinks` | 标记所有符号链接 |
| `* c` | `dired-change-marks` | 把一种标记批量换成另一种 |
| `* C-n` | `dired-next-marked-file` | 跳到下一个标记的文件 |
| `* C-p` | `dired-prev-marked-file` | 跳到上一个标记的文件 |
| `* DEL` | `dired-unmark-backward` | 上移一行并取消标记 |
| `* m` | `dired-mark` | 标记光标处的文件 |
| `* N` | `dired-number-of-marked-files` | 显示标记文件的数量和总大小 |
| `* O` | `dired-mark-omitted` | 标记被隐藏规则匹配的文件 |
| `* s` | `dired-mark-subdir-files` | 标记当前子目录下所有文件 |
| `* t` | `dired-toggle-marks` | 反转标记 |
| `* u` | `dired-unmark` | 取消光标处文件的标记 |
| `: d` | `epa-dired-do-decrypt` | 解密标记的文件 |
| `: e` | `epa-dired-do-encrypt` | 加密标记的文件 |
| `: s` | `epa-dired-do-sign` | 对标记的文件签名 |
| `: v` | `epa-dired-do-verify` | 验证标记文件的签名 |
| `C-t .` | `image-dired-display-thumb` | 显示当前文件的缩略图 |
| `C-t a` | `image-dired-display-thumbs-append` | 把缩略图追加到缩略图缓冲区 |
| `C-t c` | `image-dired-dired-comment-files` | 给图片文件加注释 |
| `C-t C-t` | `image-dired-dired-toggle-marked-thumbs` | 在文件名前显示或隐藏缩略图 |
| `C-t d` | `image-dired-display-thumbs` | 显示所有标记文件的缩略图 |
| `C-t e` | `image-dired-dired-edit-comment-and-tags` | 编辑图片的注释和标签 |
| `C-t f` | `image-dired-mark-tagged-files` | 按标签正则标记文件 |
| `C-t i` | `image-dired-dired-display-image` | 显示当前图片文件 |
| `C-t j` | `image-dired-jump-thumbnail-buffer` | 跳到缩略图缓冲区 |
| `C-t r` | `image-dired-delete-tag` | 删除所选文件的标签 |
| `C-t t` | `image-dired-tag-files` | 给标记的文件加标签 |
| `C-t x` | `image-dired-dired-display-external` | 用外部程序查看该图片 |
| `C-x M-o` | `dired-omit-mode` | 开关隐藏无关文件 |
| `M-s a C-s` | `dired-do-isearch` | 在标记的文件中增量搜索 |
| `M-s f C-s` | `dired-isearch-filenames` | 只在文件名范围内增量搜索 |

## 缓冲区列表（Ibuffer）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `ibuffer-do-shell-command-file` | 对标记缓冲区的文件执行 shell 命令 |
| `+` | `ibuffer-add-to-tmp-show` | 临时强制显示匹配正则的缓冲区 |
| `,` | `ibuffer-toggle-sorting-mode` | 切换排序方式 |
| `-` | `ibuffer-add-to-tmp-hide` | 临时隐藏匹配正则的缓冲区 |
| `.` | `ibuffer-mark-old-buffers` | 标记很久没看过的缓冲区 |
| `<backtab>` | `ibuffer-backward-filter-group` | 跳到上一个分组 |
| `=` | `ibuffer-diff-with-file` | 比较标记缓冲区与其磁盘文件的差异 |
| ``` | `ibuffer-switch-format` | 切换列表的显示格式 |
| `A` | `ibuffer-do-view` | 查看标记的缓冲区 |
| `B` | `ibuffer-copy-buffername-as-kill` | 复制标记缓冲区的名字 |
| `b` | `ibuffer-bury-buffer` | 把该缓冲区沉到列表末尾 |
| `C-d` | `ibuffer-mark-for-delete-backwards` | 向上打删除标记 |
| `C-k` | `ibuffer-kill-line` | 删掉光标处的分组 |
| `C-o` | `ibuffer-visit-buffer-other-window-noselect` | 在另一窗口显示但不切过去 |
| `C-t` | `ibuffer-visit-tags-table` | 加载该缓冲区作为 tags 表 |
| `C-y` | `ibuffer-yank` | 粘回刚删掉的分组 |
| `D` | `ibuffer-do-delete` | 关闭标记的缓冲区 |
| `d` | `ibuffer-mark-for-delete` | 打删除标记 |
| `DEL` | `ibuffer-unmark-backward` | 向上取消标记 |
| `E` | `ibuffer-do-eval` | 在标记的缓冲区中求值 Lisp 表达式 |
| `F` | `ibuffer-do-shell-command-file` | 对标记缓冲区的文件执行 shell 命令 |
| `g` | `ibuffer-update` | 重新生成缓冲区列表 |
| `H` | `ibuffer-do-view-other-frame` | 在各自窗体中查看标记的缓冲区 |
| `I` | `ibuffer-do-query-replace-regexp` | 在标记的缓冲区中按正则逐处替换 |
| `j` | `ibuffer-jump-to-buffer` | 按名称跳到某个缓冲区 |
| `k` | `ibuffer-do-kill-lines` | 把标记的行从列表中隐藏 |
| `L` | `ibuffer-do-toggle-lock` | 切换标记缓冲区的锁定状态 |
| `l` | `ibuffer-redisplay` | 重绘缓冲区列表 |
| `M` | `ibuffer-do-toggle-modified` | 切换标记缓冲区的修改标志 |
| `m` | `ibuffer-mark-forward` | 标记缓冲区并下移 |
| `M-DEL` | `ibuffer-unmark-all` | 取消某一种标记 |
| `M-g` | `ibuffer-jump-to-buffer` | 按名称跳到某个缓冲区 |
| `M-j` | `ibuffer-jump-to-filter-group` | 按名称跳到某个分组 |
| `M-n` | `ibuffer-forward-filter-group` | 跳到下一个分组 |
| `M-o` | `ibuffer-visit-buffer-1-window` | 切换到该缓冲区并独占窗口 |
| `M-p` | `ibuffer-backward-filter-group` | 跳到上一个分组 |
| `M-{` | `ibuffer-backwards-next-marked` | 跳到上一个标记的缓冲区 |
| `M-}` | `ibuffer-forward-next-marked` | 跳到下一个标记的缓冲区 |
| `N` | `ibuffer-do-shell-command-pipe-replace` | 用 shell 命令的输出替换缓冲区内容 |
| `n` | `ibuffer-forward-line` | 下移一行（到底后回绕） |
| `O` | `ibuffer-do-occur` | 在标记的缓冲区中列出匹配行 |
| `o` | `ibuffer-visit-buffer-other-window` | 在另一窗口打开该缓冲区 |
| `P` | `ibuffer-do-print` | 打印标记的缓冲区 |
| `p` | `ibuffer-backward-line` | 上移一行（到顶后回绕） |
| `Q` | `ibuffer-do-query-replace` | 在标记的缓冲区中逐处替换 |
| `R` | `ibuffer-do-rename-uniquely` | 给标记的缓冲区改成不重名的名字 |
| `r` | `ibuffer-do-replace-regexp` | 在标记的缓冲区中批量正则替换 |
| `RET` | `ibuffer-visit-buffer` | 切换到光标处的缓冲区 |
| `S` | `ibuffer-do-save` | 保存标记的缓冲区 |
| `SPC` | `forward-line` | 下移一行 |
| `T` | `ibuffer-do-toggle-read-only` | 切换标记缓冲区的只读状态 |
| `t` | `ibuffer-toggle-marks` | 反转标记 |
| `TAB` | `ibuffer-forward-filter-group` | 跳到下一个分组 |
| `U` | `ibuffer-unmark-all-marks` | 取消所有标记 |
| `u` | `ibuffer-unmark-forward` | 取消标记并下移 |
| `V` | `ibuffer-do-revert` | 重新从磁盘加载标记的缓冲区 |
| `v` | `ibuffer-do-view` | 查看标记的缓冲区 |
| `W` | `ibuffer-do-view-and-eval` | 查看缓冲区并求值表达式 |
| `w` | `ibuffer-copy-filename-as-kill` | 复制标记缓冲区对应的文件名 |
| `X` | `ibuffer-do-shell-command-pipe` | 把标记缓冲区的内容管道给 shell 命令 |
| `x` | `ibuffer-do-kill-on-deletion-marks` | 关闭打了删除标记的缓冲区 |
| `|` | `ibuffer-do-shell-command-pipe` | 把标记缓冲区的内容管道给 shell 命令 |
| `~` | `ibuffer-do-toggle-modified` | 切换标记缓冲区的修改标志 |
| `% f` | `ibuffer-mark-by-file-name-regexp` | 按文件名正则标记缓冲区 |
| `% g` | `ibuffer-mark-by-content-regexp` | 按内容正则标记缓冲区 |
| `% L` | `ibuffer-mark-by-locked` | 标记所有锁定的缓冲区 |
| `% m` | `ibuffer-mark-by-mode-regexp` | 按主模式名正则标记缓冲区 |
| `% n` | `ibuffer-mark-by-name-regexp` | 按缓冲区名正则标记 |
| `* *` | `ibuffer-unmark-all` | 取消某一种标记 |
| `* /` | `ibuffer-mark-dired-buffers` | 标记所有 Dired 缓冲区 |
| `* c` | `ibuffer-change-marks` | 把一种标记批量换成另一种 |
| `* e` | `ibuffer-mark-dissociated-buffers` | 标记对应文件已不存在的缓冲区 |
| `* h` | `ibuffer-mark-help-buffers` | 标记所有帮助类缓冲区 |
| `* M` | `ibuffer-mark-by-mode` | 按主模式标记缓冲区 |
| `* m` | `ibuffer-mark-modified-buffers` | 标记所有已修改的缓冲区 |
| `* r` | `ibuffer-mark-read-only-buffers` | 标记所有只读缓冲区 |
| `* s` | `ibuffer-mark-special-buffers` | 标记所有名字带星号的缓冲区 |
| `* u` | `ibuffer-mark-unsaved-buffers` | 标记有文件且未保存的缓冲区 |
| `* z` | `ibuffer-mark-compressed-file-buffers` | 标记压缩文件对应的缓冲区 |
| `/ !` | `ibuffer-negate-filter` | 对栈顶过滤条件取反 |
| `/ &` | `ibuffer-and-filter` | 把栈顶两个过滤条件按与合并 |
| `/ *` | `ibuffer-filter-by-starred-name` | 只留名字带星号的特殊缓冲区 |
| `/ .` | `ibuffer-filter-by-file-extension` | 按扩展名过滤 |
| `/ /` | `ibuffer-filter-disable` | 取消当前所有过滤 |
| `/ <` | `ibuffer-filter-by-size-lt` | 只留小于指定大小的缓冲区 |
| `/ <up>` | `ibuffer-pop-filter` | 撤销最近一个过滤条件 |
| `/ >` | `ibuffer-filter-by-size-gt` | 只留大于指定大小的缓冲区 |
| `/ \` | `ibuffer-clear-filter-groups` | 清除所有分组 |
| `/ a` | `ibuffer-add-saved-filters` | 加载已保存的过滤条件 |
| `/ b` | `ibuffer-filter-by-basename` | 按文件基名过滤 |
| `/ c` | `ibuffer-filter-by-content` | 按缓冲区内容过滤 |
| `/ D` | `ibuffer-decompose-filter-group` | 把分组拆回独立的过滤条件 |
| `/ d` | `ibuffer-decompose-filter` | 拆开栈顶的复合过滤条件 |
| `/ E` | `ibuffer-filter-by-process` | 只留有进程的缓冲区 |
| `/ e` | `ibuffer-filter-by-predicate` | 按 Lisp 条件表达式过滤 |
| `/ F` | `ibuffer-filter-by-directory` | 按所在目录过滤 |
| `/ f` | `ibuffer-filter-by-filename` | 按文件路径过滤 |
| `/ g` | `ibuffer-filters-to-filter-group` | 把当前过滤条件保存成一个分组 |
| `/ i` | `ibuffer-filter-by-modified` | 只留未保存的缓冲区 |
| `/ M` | `ibuffer-filter-by-derived-mode` | 按派生模式过滤 |
| `/ m` | `ibuffer-filter-by-used-mode` | 按实际使用的模式过滤 |
| `/ n` | `ibuffer-filter-by-name` | 按缓冲区名过滤 |
| `/ o` | `ibuffer-or-filter` | 把栈顶两个过滤条件按或合并 |
| `/ P` | `ibuffer-pop-filter-group` | 移除第一个分组 |
| `/ p` | `ibuffer-pop-filter` | 撤销最近一个过滤条件 |
| `/ R` | `ibuffer-switch-to-saved-filter-groups` | 套用已保存的分组方案 |
| `/ r` | `ibuffer-switch-to-saved-filters` | 套用已保存的过滤条件 |
| `/ RET` | `ibuffer-filter-by-mode` | 按主模式过滤 |
| `/ S` | `ibuffer-save-filter-groups` | 保存当前分组方案 |
| `/ s` | `ibuffer-save-filters` | 保存当前过滤条件 |
| `/ S-<up>` | `ibuffer-pop-filter-group` | 移除第一个分组 |
| `/ SPC` | `ibuffer-filter-chosen-by-completion` | 从所有过滤器中检索选择 |
| `/ t` | `ibuffer-exchange-filters` | 交换栈顶的两个过滤条件 |
| `/ TAB` | `ibuffer-exchange-filters` | 交换栈顶的两个过滤条件 |
| `/ v` | `ibuffer-filter-by-visiting-file` | 只留对应磁盘文件的缓冲区 |
| `/ X` | `ibuffer-delete-saved-filter-groups` | 删除已保存的分组方案 |
| `/ x` | `ibuffer-delete-saved-filters` | 删除已保存的过滤条件 |
| `/ |` | `ibuffer-or-filter` | 把栈顶两个过滤条件按或合并 |
| `C-c C-a` | `ibuffer-auto-mode` | 开关列表自动刷新 |
| `C-x C-f` | `ibuffer-find-file` | 以光标处缓冲区的目录为起点打开文件 |
| `C-x v` | `ibuffer-do-view-horizontally` | 查看标记缓冲区并左右分屏 |
| `s a` | `ibuffer-do-sort-by-alphabetic` | 按名称排序 |
| `s f` | `ibuffer-do-sort-by-filename/process` | 按文件名或进程排序 |
| `s i` | `ibuffer-invert-sorting` | 反转排序方向 |
| `s m` | `ibuffer-do-sort-by-major-mode` | 按主模式排序 |
| `s s` | `ibuffer-do-sort-by-size` | 按大小排序 |
| `s v` | `ibuffer-do-sort-by-recency` | 按最近使用排序 |
| `C-x 4 RET` | `ibuffer-visit-buffer-other-window` | 在另一窗口打开该缓冲区 |
| `C-x 5 RET` | `ibuffer-visit-buffer-other-frame` | 在新窗体打开该缓冲区 |
| `M-s a C-o` | `ibuffer-do-occur` | 在标记的缓冲区中列出匹配行 |
| `M-s a C-s` | `ibuffer-do-isearch` | 在标记的缓冲区中增量搜索 |

## 项目树（Treemacs）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `treemacs-run-shell-command-for-current-node` | 对当前节点执行 shell 命令 |
| `<` | `treemacs-decrease-width` | 减小项目树宽度 |
| `<backtab>` | `treemacs-collapse-all-projects` | 折叠所有项目 |
| `<C-i>` | `treemacs-TAB-action` | 对当前节点执行 Tab 动作（展开折叠） |
| `<next>` | `treemacs-next-page-other-window` | 让另一窗口向下翻页 |
| `<prior>` | `treemacs-previous-page-other-window` | 让另一窗口向上翻页 |
| `<return>` | `treemacs-RET-action` | 对当前节点执行回车动作（打开） |
| `<tab>` | `treemacs-TAB-action` | 对当前节点执行 Tab 动作（展开折叠） |
| `=` | `treemacs-fit-window-width` | 把宽度调到刚好显示全部内容 |
| `>` | `treemacs-increase-width` | 增大项目树宽度 |
| `?` | `treemacs-common-helpful-hydra` | 显示 treemacs 的常用按键提示 |
| `b` | `treemacs-add-bookmark` | 把当前节点加入书签 |
| `C` | `treemacs-cleanup-litter` | 折叠所有杂物目录 |
| `C-?` | `treemacs-advanced-helpful-hydra` | 显示 treemacs 的进阶按键提示 |
| `C-j` | `treemacs-next-project` | 跳到下一个项目根节点 |
| `C-k` | `treemacs-previous-project` | 跳到上一个项目根节点 |
| `d` | `treemacs-delete-file` | 删除光标处的文件 |
| `g` | `treemacs-refresh` | 刷新当前项目 |
| `H` | `treemacs-collapse-parent-node` | 折叠当前节点的父节点 |
| `h` | `treemacs-COLLAPSE-action` | 对当前节点执行折叠动作 |
| `l` | `treemacs-RET-action` | 对当前节点执行回车动作（打开） |
| `m` | `treemacs-move-file` | 移动光标处的文件或目录 |
| `M-!` | `treemacs-run-shell-command-in-project-root` | 在项目根目录异步执行 shell 命令 |
| `M-<down>` | `treemacs-move-project-down` | 把当前项目下移一位 |
| `M-<up>` | `treemacs-move-project-up` | 把当前项目上移一位 |
| `M-H` | `treemacs-root-up` | 把根目录上移一层 |
| `M-h` | `treemacs-COLLAPSE-action` | 对当前节点执行折叠动作 |
| `M-L` | `treemacs-root-down` | 把根目录切到光标处的目录 |
| `M-l` | `treemacs-RET-action` | 对当前节点执行回车动作（打开） |
| `M-m` | `treemacs-bulk-file-actions` | 批量文件操作菜单 |
| `M-N` | `treemacs-next-line-other-window` | 让另一窗口向下滚动几行 |
| `M-n` | `treemacs-next-neighbour` | 跳到下一个同级节点 |
| `M-P` | `treemacs-previous-line-other-window` | 让另一窗口向上滚动几行 |
| `M-p` | `treemacs-previous-neighbour` | 跳到上一个同级节点 |
| `n` | `treemacs-next-line` | 下移一行 |
| `P` | `treemacs-peek-mode` | 开关预览模式（选中即预览文件） |
| `p` | `treemacs-previous-line` | 上移一行 |
| `Q` | `treemacs-kill-buffer` | 关闭项目树缓冲区 |
| `q` | `treemacs-quit` | 隐藏项目树 |
| `R` | `treemacs-rename-file` | 重命名光标处的文件或目录 |
| `r` | `treemacs-refresh` | 刷新当前项目 |
| `RET` | `treemacs-RET-action` | 对当前节点执行回车动作（打开） |
| `s` | `treemacs-resort` | 更改排序方式并刷新 |
| `TAB` | `treemacs-TAB-action` | 对当前节点执行 Tab 动作（展开折叠） |
| `u` | `treemacs-goto-parent-node` | 跳到父节点 |
| `W` | `treemacs-extra-wide-toggle` | 切换超宽显示 |
| `w` | `treemacs-set-width` | 设置项目树宽度 |
| `c d` | `treemacs-create-dir` | 新建目录 |
| `c f` | `treemacs-create-file` | 新建文件 |
| `o c` | `treemacs-visit-node-close-treemacs` | 打开节点并关闭项目树 |
| `o h` | `treemacs-visit-node-horizontal-split` | 上下分割后打开节点 |
| `o o` | `treemacs-visit-node-no-split` | 直接打开，不分割窗口 |
| `o r` | `treemacs-visit-node-in-most-recently-used-window` | 在最近使用的窗口中打开 |
| `o v` | `treemacs-visit-node-vertical-split` | 左右分割后打开节点 |
| `o x` | `treemacs-visit-node-in-external-application` | 用外部程序打开该文件 |
| `t a` | `treemacs-filewatch-mode` | 开关文件变动时自动刷新 |
| `t c` | `treemacs-indicate-top-scroll-mode` | 显示是否已滚动到顶部 |
| `t d` | `treemacs-git-commit-diff-mode` | 显示与远程分支的提交差异 |
| `t f` | `treemacs-follow-mode` | 开关跟随当前文件自动定位 |
| `t g` | `treemacs-git-mode` | 开关 Git 状态着色 |
| `t h` | `treemacs-toggle-show-dotfiles` | 开关隐藏文件的显示 |
| `t i` | `treemacs-hide-gitignored-files-mode` | 开关隐藏被 gitignore 的文件 |
| `t n` | `treemacs-indent-guide-mode` | 开关缩进参考线 |
| `t v` | `treemacs-fringe-indicator-mode` | 开关边栏当前行指示条 |
| `t w` | `treemacs-toggle-fixed-width` | 切换宽度是否固定 |
| `y a` | `treemacs-copy-absolute-path-at-point` | 复制节点的绝对路径 |
| `y f` | `treemacs-copy-file` | 复制光标处的文件或目录 |
| `y n` | `treemacs-copy-filename-at-point` | 复制节点的文件名 |
| `y p` | `treemacs-copy-project-path-at-point` | 复制当前项目根目录的路径 |
| `y r` | `treemacs-copy-relative-path-at-point` | 复制节点相对项目根的路径 |
| `y v` | `treemacs-paste-dir-at-point-to-minibuffer` | 把光标处目录粘到小缓冲 |
| `C-c C-p a` | `treemacs-add-project-to-workspace` | 把某个路径作为项目加入工作区 |
| `C-c C-p d` | `treemacs-remove-project-from-workspace` | 把项目移出工作区 |
| `C-c C-p r` | `treemacs-rename-project` | 重命名当前项目 |
| `C-c C-w a` | `treemacs-create-workspace` | 新建工作区 |
| `C-c C-w d` | `treemacs-remove-workspace` | 删除工作区 |
| `C-c C-w e` | `treemacs-edit-workspaces` | 用 Org 文件的形式编辑工作区和项目 |
| `C-c C-w f` | `treemacs-set-fallback-workspace` | 把当前工作区设为默认 |
| `C-c C-w n` | `treemacs-next-workspace` | 切到下一个工作区 |
| `C-c C-w r` | `treemacs-rename-workspace` | 重命名工作区 |
| `C-c C-w s` | `treemacs-switch-workspace` | 切换工作区 |
| `o a a` | `treemacs-visit-node-ace` | 用 ace-window 选窗口打开节点 |
| `o a h` | `treemacs-visit-node-ace-horizontal-split` | 选窗口上下分割后打开 |
| `o a v` | `treemacs-visit-node-ace-vertical-split` | 选窗口左右分割后打开 |
| `C-c C-p c a` | `treemacs-collapse-all-projects` | 折叠所有项目 |
| `C-c C-p c c` | `treemacs-collapse-project` | 折叠当前项目 |
| `C-c C-p c o` | `treemacs-collapse-other-projects` | 折叠除当前外的所有项目 |

## PDF 阅读

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `'` | `pdf-view-jump-to-register` | 跳到寄存器中保存的阅读位置 |
| `+` | `pdf-view-enlarge` | 放大 PDF |
| `-` | `pdf-view-shrink` | 缩小 PDF |
| `/` | `isearch-forward` | 向后增量搜索 |
| `0` | `pdf-view-scale-reset` | 恢复默认缩放 |
| `<` | `beginning-of-buffer` | 跳到缓冲区开头 |
| `<down>` | `pdf-view-next-line-or-next-page` | 下移一行，到底则翻到下一页 |
| `<next>` | `forward-page` | 向后移动到分页符 |
| `<prior>` | `backward-page` | 向前移动到分页符 |
| `<up>` | `pdf-view-previous-line-or-previous-page` | 上移一行，到顶则翻到上一页 |
| `=` | `pdf-view-enlarge` | 放大 PDF |
| `>` | `end-of-buffer` | 跳到缓冲区末尾 |
| `?` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `b` | `image-previous-frame` | 切到多帧图片的上一帧 |
| `C-n` | `pdf-view-next-line-or-next-page` | 下移一行，到底则翻到下一页 |
| `C-p` | `pdf-view-previous-line-or-previous-page` | 上移一行，到顶则翻到上一页 |
| `DEL` | `scroll-down-command` | 向上翻页 |
| `F` | `image-goto-frame` | 跳到多帧图片的第 N 帧 |
| `f` | `image-next-frame` | 切到多帧图片的下一帧 |
| `g` | `revert-buffer` | 丢弃修改，从磁盘重新加载文件 |
| `H` | `pdf-view-fit-height-to-window` | 页面高度适应窗口 |
| `h` | `describe-mode` | 查看当前主模式和次模式的文档 |
| `j` | `pdf-view-next-line-or-next-page` | 下移一行，到底则翻到下一页 |
| `k` | `pdf-view-previous-line-or-previous-page` | 上移一行，到顶则翻到上一页 |
| `l` | `image-forward-hscroll` | 图片向左横向滚动 |
| `m` | `image-mode-mark-file` | 在对应的 Dired 中标记此文件 |
| `M-<` | `pdf-view-first-page` | 跳到第一页 |
| `M->` | `pdf-view-last-page` | 跳到最后一页 |
| `n` | `image-next-file` | 查看同目录下的下一张图片 |
| `o` | `pdf-outline` | 显示 PDF 的书签大纲 |
| `P` | `pdf-view-fit-page-to-window` | 整页适应窗口 |
| `p` | `image-previous-file` | 查看同目录下的上一张图片 |
| `Q` | `kill-current-buffer` | 关闭当前缓冲区 |
| `q` | `quit-window` | 关闭窗口并把缓冲区沉底 |
| `R` | `pdf-view-rotate` | 顺时针旋转当前页 |
| `RET` | `image-toggle-animation` | 开始或停止播放动图 |
| `S-SPC` | `scroll-down-command` | 向上翻页 |
| `SPC` | `scroll-up-command` | 向下翻页 |
| `u` | `image-mode-unmark-file` | 在对应的 Dired 中取消标记 |
| `W` | `image-mode-wallpaper-set` | 把当前图片设为桌面壁纸 |
| `w` | `image-mode-copy-file-name-as-kill` | 复制当前图片的文件名 |
| `a +` | `image-increase-speed` | 动图播放加速一倍 |
| `a -` | `image-decrease-speed` | 动图播放减速一半 |
| `a 0` | `image-reset-speed` | 恢复动图默认播放速度 |
| `a r` | `image-reverse-speed` | 反向播放动图 |
| `C-c C-c` | `image-toggle-display` | 在图片和文本之间切换显示 |
| `C-c C-d` | `pdf-view-dark-minor-mode` | 开关深色背景阅读模式 |
| `C-c C-n` | `pdf-view-midnight-minor-mode` | 开关夜间配色 |
| `C-c C-x` | `image-toggle-hex-display` | 在图片和十六进制之间切换显示 |
| `C-c TAB` | `pdf-view-extract-region-image` | 把选中区域导出为 PNG 图片 |
| `i +` | `image-increase-size` | 放大图片 |
| `i -` | `image-decrease-size` | 缩小图片 |
| `i c` | `image-crop` | 裁剪光标处的图片 |
| `i h` | `image-flip-horizontally` | 图片水平翻转 |
| `i o` | `image-save` | 保存光标处的图片 |
| `i r` | `image-rotate` | 顺时针旋转图片 |
| `i v` | `image-flip-vertically` | 图片垂直翻转 |
| `i x` | `image-cut` | 从图片中挖去一块矩形 |
| `M-g l` | `pdf-view-goto-label` | 按页码标签跳转 |
| `s 0` | `image-transform-reset-to-initial` | 恢复图片的初始大小和角度 |
| `s b` | `image-transform-fit-both` | 缩小图片以完整放进窗口 |
| `s c` | `pdf-view-set-slice-common-bounding-box` | 按所有页的公共边界裁掉白边 |
| `s f` | `image-mode-fit-frame` | 把窗体调整到适合图片大小 |
| `s h` | `image-transform-fit-to-height` | 图片适应窗口高度 |
| `s i` | `image-transform-fit-to-width` | 图片适应窗口宽度 |
| `s m` | `image-transform-set-smoothing` | 开关图片缩放平滑 |
| `s o` | `image-transform-reset-to-original` | 恢复图片的原始大小和角度 |
| `s p` | `image-transform-set-percent` | 按百分比缩放图片 |
| `s r` | `image-transform-set-rotation` | 按指定角度旋转图片 |
| `s s` | `image-transform-set-scale` | 按指定倍数缩放图片 |
| `s w` | `image-transform-fit-to-window` | 图片适应窗口大小 |
| `C-c C-a h` | `pdf-annot-add-highlight-markup-annotation` | 添加高亮批注 |
| `C-c C-a t` | `pdf-annot-add-text-annotation` | 添加文字批注 |
| `C-c C-a u` | `pdf-annot-add-underline-markup-annotation` | 添加下划线批注 |
| `C-c C-r m` | `pdf-view-midnight-minor-mode` | 开关夜间配色 |
| `C-c C-r p` | `pdf-view-printer-minor-mode` | 按打印效果显示 |
| `C-c C-r t` | `pdf-view-themed-minor-mode` | 让 PDF 配色跟随 Emacs 主题 |

## 智能体会话（agent-shell）

大部分键位来自 comint，与其他交互式缓冲区一致。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `+` | `agent-shell-image-scale-increase` | 放大会话中的图片 |
| `-` | `agent-shell-image-scale-decrease` | 缩小会话中的图片 |
| `0` | `agent-shell-image-scale-reset` | 图片恢复原始大小 |
| `<backtab>` | `agent-shell-previous-item` | 跳到上一条消息 |
| `<delete>` | `delete-forward-char` | 删除后一个字符 |
| `<kp-delete>` | `delete-forward-char` | 删除后一个字符 |
| `C-<down>` | `comint-next-input` | 取历史中的下一条输入 |
| `C-<tab>` | `agent-shell-cycle-session-mode` | 在会话模式之间循环切换 |
| `C-<up>` | `comint-previous-input` | 取历史中的上一条输入 |
| `C-d` | `comint-delchar-or-maybe-eof` | 删除字符，行尾则发送 EOF |
| `C-M-h` | `shell-maker-mark-output` | 选中最后一段输出 |
| `C-M-l` | `comint-show-output` | 把本批输出的开头滚到窗口顶部 |
| `M-n` | `comint-next-input` | 取历史中的下一条输入 |
| `M-p` | `comint-previous-input` | 取历史中的上一条输入 |
| `M-r` | `comint-history-isearch-backward-regexp` | 用正则在输入历史中反向增量搜索 |
| `n` | `agent-shell-next-item` | 跳到下一条消息 |
| `p` | `agent-shell-previous-item` | 跳到上一条消息 |
| `r` | `agent-shell-quote-region` | 把选中区域引用进当前提示词 |
| `RET` | `comint-send-input` | 发送当前输入 |
| `S-<return>` | `newline` | 插入换行 |
| `TAB` | `agent-shell-next-item` | 跳到下一条消息 |
| `C-c .` | `comint-insert-previous-argument` | 插入上一条命令的第 N 个参数 |
| `C-c C-\` | `comint-quit-subjob` | 向子任务发送退出信号 |
| `C-c C-a` | `comint-bol-or-process-mark` | 跳到提示符之后或进程标记处 |
| `C-c C-c` | `comint-interrupt-subjob` | 中断当前子任务（相当于 Ctrl-C） |
| `C-c C-d` | `comint-send-eof` | 向进程发送 EOF |
| `C-c C-e` | `comint-show-maximum-output` | 把缓冲区末尾滚动到窗口底部 |
| `C-c C-l` | `comint-dynamic-list-input-ring` | 列出最近的输入历史 |
| `C-c C-n` | `comint-next-prompt` | 跳到下一个提示符 |
| `C-c C-o` | `comint-delete-output` | 删除上次输入以来的所有输出 |
| `C-c C-p` | `comint-previous-prompt` | 跳到上一个提示符 |
| `C-c C-r` | `comint-show-output` | 把本批输出的开头滚到窗口顶部 |
| `C-c C-s` | `comint-write-output` | 把上次输入以来的输出写入文件 |
| `C-c C-t` | `agent-shell-set-session-thought-level` | 设置思考强度（推理力度） |
| `C-c C-u` | `comint-kill-input` | 删除尚未发送的输入 |
| `C-c C-v` | `agent-shell-set-session-model` | 选择本次会话使用的模型 |
| `C-c C-w` | `backward-kill-word` | 向前删除一个词 |
| `C-c C-x` | `comint-get-next-from-history` | 取历史中上一条的下一行 |
| `C-c C-z` | `comint-stop-subjob` | 暂停当前子任务 |
| `C-c M-o` | `comint-clear-buffer` | 清空交互缓冲区 |
| `C-c M-r` | `comint-previous-matching-input-from-input` | 按当前输入向前搜索历史 |
| `C-c M-s` | `comint-next-matching-input-from-input` | 按当前输入向后搜索历史 |
| `C-c RET` | `comint-copy-old-input` | 把光标处的旧输入复制到提示符后 |
| `C-c SPC` | `comint-accumulate` | 把当前行暂存，与后续行一起发送 |

## 浏览器（embr）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `!` | `embr-self-insert` | 把按键转发给浏览器 |
| `"` | `embr-self-insert` | 把按键转发给浏览器 |
| `#` | `embr-self-insert` | 把按键转发给浏览器 |
| `$` | `embr-self-insert` | 把按键转发给浏览器 |
| `%` | `embr-self-insert` | 把按键转发给浏览器 |
| `&` | `embr-play-external` | 用外部程序打开当前页面地址 |
| `'` | `embr-self-insert` | 把按键转发给浏览器 |
| `(` | `embr-self-insert` | 把按键转发给浏览器 |
| `)` | `embr-self-insert` | 把按键转发给浏览器 |
| `*` | `embr-self-insert` | 把按键转发给浏览器 |
| `+` | `embr-self-insert` | 把按键转发给浏览器 |
| `,` | `embr-self-insert` | 把按键转发给浏览器 |
| `-` | `embr-self-insert` | 把按键转发给浏览器 |
| `.` | `embr-self-insert` | 把按键转发给浏览器 |
| `/` | `embr-self-insert` | 把按键转发给浏览器 |
| `0` | `embr-self-insert` | 把按键转发给浏览器 |
| `1` | `embr-self-insert` | 把按键转发给浏览器 |
| `2` | `embr-self-insert` | 把按键转发给浏览器 |
| `3` | `embr-self-insert` | 把按键转发给浏览器 |
| `4` | `embr-self-insert` | 把按键转发给浏览器 |
| `5` | `embr-self-insert` | 把按键转发给浏览器 |
| `6` | `embr-self-insert` | 把按键转发给浏览器 |
| `7` | `embr-self-insert` | 把按键转发给浏览器 |
| `8` | `embr-self-insert` | 把按键转发给浏览器 |
| `9` | `embr-self-insert` | 把按键转发给浏览器 |
| `:` | `embr-self-insert` | 把按键转发给浏览器 |
| `;` | `embr-self-insert` | 把按键转发给浏览器 |
| `<` | `embr-self-insert` | 把按键转发给浏览器 |
| `<backspace>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<backtab>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<delete>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<down>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<end>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<escape>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<f5>` | `embr-refresh` | 刷新当前页面 |
| `<home>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<left>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<next>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<prior>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<return>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<right>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<tab>` | `embr-self-insert` | 把按键转发给浏览器 |
| `<up>` | `embr-self-insert` | 把按键转发给浏览器 |
| `=` | `embr-self-insert` | 把按键转发给浏览器 |
| `>` | `embr-self-insert` | 把按键转发给浏览器 |
| `?` | `embr-self-insert` | 把按键转发给浏览器 |
| `@` | `embr-self-insert` | 把按键转发给浏览器 |
| `[` | `embr-self-insert` | 把按键转发给浏览器 |
| `\` | `embr-self-insert` | 把按键转发给浏览器 |
| `]` | `embr-self-insert` | 把按键转发给浏览器 |
| `^` | `embr-self-insert` | 把按键转发给浏览器 |
| `_` | `embr-self-insert` | 把按键转发给浏览器 |
| ``` | `embr-self-insert` | 把按键转发给浏览器 |
| `A` | `embr-self-insert` | 把按键转发给浏览器 |
| `a` | `embr-self-insert` | 把按键转发给浏览器 |
| `B` | `embr-self-insert` | 把按键转发给浏览器 |
| `b` | `embr-self-insert` | 把按键转发给浏览器 |
| `C` | `embr-self-insert` | 把按键转发给浏览器 |
| `c` | `embr-self-insert` | 把按键转发给浏览器 |
| `C--` | `embr-zoom-out` | 页面缩小 |
| `C-0` | `embr-zoom-reset` | 页面缩放恢复 100% |
| `C-=` | `embr-zoom-in` | 页面放大 |
| `C-a` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-b` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-d` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-e` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-f` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-n` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-p` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-r` | `embr-isearch-backward` | 在页面中反向搜索 |
| `C-s` | `embr-isearch-forward` | 在页面中正向搜索 |
| `C-v` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-y` | `embr-paste` | 把剪切环内容粘贴到浏览器 |
| `D` | `embr-self-insert` | 把按键转发给浏览器 |
| `d` | `embr-self-insert` | 把按键转发给浏览器 |
| `E` | `embr-self-insert` | 把按键转发给浏览器 |
| `e` | `embr-self-insert` | 把按键转发给浏览器 |
| `F` | `embr-self-insert` | 把按键转发给浏览器 |
| `f` | `embr-self-insert` | 把按键转发给浏览器 |
| `G` | `embr-self-insert` | 把按键转发给浏览器 |
| `g` | `embr-self-insert` | 把按键转发给浏览器 |
| `H` | `embr-self-insert` | 把按键转发给浏览器 |
| `h` | `embr-self-insert` | 把按键转发给浏览器 |
| `I` | `embr-self-insert` | 把按键转发给浏览器 |
| `i` | `embr-self-insert` | 把按键转发给浏览器 |
| `J` | `embr-self-insert` | 把按键转发给浏览器 |
| `j` | `embr-self-insert` | 把按键转发给浏览器 |
| `K` | `embr-self-insert` | 把按键转发给浏览器 |
| `k` | `embr-self-insert` | 把按键转发给浏览器 |
| `L` | `embr-self-insert` | 把按键转发给浏览器 |
| `l` | `embr-self-insert` | 把按键转发给浏览器 |
| `M` | `embr-self-insert` | 把按键转发给浏览器 |
| `m` | `embr-self-insert` | 把按键转发给浏览器 |
| `M-<` | `embr-self-insert` | 把按键转发给浏览器 |
| `M->` | `embr-self-insert` | 把按键转发给浏览器 |
| `M-b` | `embr-self-insert` | 把按键转发给浏览器 |
| `M-f` | `embr-self-insert` | 把按键转发给浏览器 |
| `M-v` | `embr-self-insert` | 把按键转发给浏览器 |
| `M-w` | `embr-copy` | 把浏览器中选中的内容复制到剪切环 |
| `N` | `embr-self-insert` | 把按键转发给浏览器 |
| `n` | `embr-self-insert` | 把按键转发给浏览器 |
| `O` | `embr-self-insert` | 把按键转发给浏览器 |
| `o` | `embr-self-insert` | 把按键转发给浏览器 |
| `P` | `embr-self-insert` | 把按键转发给浏览器 |
| `p` | `embr-self-insert` | 把按键转发给浏览器 |
| `Q` | `embr-self-insert` | 把按键转发给浏览器 |
| `q` | `embr-self-insert` | 把按键转发给浏览器 |
| `R` | `embr-self-insert` | 把按键转发给浏览器 |
| `r` | `embr-self-insert` | 把按键转发给浏览器 |
| `S` | `embr-self-insert` | 把按键转发给浏览器 |
| `s` | `embr-self-insert` | 把按键转发给浏览器 |
| `SPC` | `embr-self-insert` | 把按键转发给浏览器 |
| `T` | `embr-self-insert` | 把按键转发给浏览器 |
| `t` | `embr-self-insert` | 把按键转发给浏览器 |
| `U` | `embr-self-insert` | 把按键转发给浏览器 |
| `u` | `embr-self-insert` | 把按键转发给浏览器 |
| `V` | `embr-self-insert` | 把按键转发给浏览器 |
| `v` | `embr-self-insert` | 把按键转发给浏览器 |
| `W` | `embr-self-insert` | 把按键转发给浏览器 |
| `w` | `embr-self-insert` | 把按键转发给浏览器 |
| `X` | `embr-self-insert` | 把按键转发给浏览器 |
| `x` | `embr-self-insert` | 把按键转发给浏览器 |
| `Y` | `embr-self-insert` | 把按键转发给浏览器 |
| `y` | `embr-self-insert` | 把按键转发给浏览器 |
| `Z` | `embr-self-insert` | 把按键转发给浏览器 |
| `z` | `embr-self-insert` | 把按键转发给浏览器 |
| `{` | `embr-self-insert` | 把按键转发给浏览器 |
| `|` | `embr-self-insert` | 把按键转发给浏览器 |
| `}` | `embr-self-insert` | 把按键转发给浏览器 |
| `~` | `embr-self-insert` | 把按键转发给浏览器 |
| `C-c C-c` | `embr-dispatch` | 打开浏览器命令菜单 |
| `C-c C-l` | `embr-navigate` | 打开网址，非网址则作为搜索词 |

## 多光标

多光标激活期间生效。

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<return>` | `multiple-cursors-mode` | 多光标模式 |
| `C-'` | `mc-hide-unmatched-lines-mode` | 只显示有光标的行 |
| `C-:` | `mc/repeat-command` | 对每个光标重复执行上一个命令 |
| `C-g` | `mc/keyboard-quit` | 取消选区，或退出多光标模式 |
| `C-v` | `mc/cycle-forward` | 把焦点切到下一个光标 |
| `M-v` | `mc/cycle-backward` | 把焦点切到上一个光标 |

## 代码模板（YASnippet）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `C-c & C-n` | `yas-new-snippet` | 新建一个代码模板 |
| `C-c & C-s` | `yas-insert-snippet` | 选择并插入代码模板 |
| `C-c & C-v` | `yas-visit-snippet-file` | 打开某个代码模板文件编辑 |

## 帮助页面（Helpful）

| 快捷键 | 命令 | 说明 |
| --- | --- | --- |
| `<backtab>` | `backward-button` | 跳到上一个按钮 |
| `g` | `helpful-update` | 刷新当前 Helpful 帮助页面 |
| `n` | `forward-button` | 跳到下一个按钮 |
| `p` | `backward-button` | 跳到上一个按钮 |
| `RET` | `helpful-visit-reference` | 跳到光标处引用的定义 |
| `TAB` | `forward-button` | 跳到下一个按钮 |

## 没有收录的部分

- **vterm**：它的键位表要等本机动态模块编译完成才存在，导出时跳过了。vterm 缓冲区里绝大多数按键会直接转发给终端里的程序。
- **Magit 的 transient 菜单**：`C-c C-c`、`C-x g` 之后弹出的那些菜单，键位是运行时生成的，不在 keymap 里。菜单自己会把可用按键都显示出来。
- **which-key 提示**：按下前缀键停顿一下会列出后续按键，这是查阅本表之外最快的办法。

