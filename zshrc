#zmodload zsh/zprof

################# Platform Detection #################
case "$(uname -s)" in
    Darwin)
        PLATFORM="macos"
        ;;
    Linux)
        PLATFORM="linux"
        ;;
    *)
        PLATFORM="unknown"
        ;;
esac

################# 基础配置 #################
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

autoload -U compinit; compinit
bindkey -e

################# 环境变量和路径 #################
export EDITOR=nvim
export VISUAL=nvim

# DISPLAY 配置 (支持 SSH X11 转发)
export DISPLAY="${DISPLAY:-:0}"

################# Debian Chroot 检测 (Linux) #################
if [[ "$PLATFORM" == "linux" ]]; then
    if [[ -z "${debian_chroot:-}" && -r /etc/debian_chroot ]]; then
        debian_chroot=$(cat /etc/debian_chroot)
    fi
fi

################# Homebrew 初始化 #################
if [[ "$PLATFORM" == "macos" ]]; then
    # macOS Homebrew 配置
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        BREW_PREFIX="/opt/homebrew"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        BREW_PREFIX="/usr/local"
    fi
    
    # Homebrew 编译器配置 (macOS)
    if command -v gcc-15 &> /dev/null; then
        export HOMEBREW_CXX=g++-15
        export HOMEBREW_CC=gcc-15
        export HOMEBREW_FC=gfortran-15
    fi
elif [[ "$PLATFORM" == "linux" ]]; then
    # Linux Homebrew 配置
    if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    fi
fi

################# PATH 配置 #################
# WezTerm
# macOS: brew install --cask wezterm
# Linux: apt install wezterm
if [[ "$PLATFORM" == "macos" && -d "/Applications/WezTerm.app/Contents/MacOS" ]]; then
    export PATH="/Applications/WezTerm.app/Contents/MacOS:$PATH"
fi

# Java (OpenJDK)
if [[ -n "$BREW_PREFIX" && -d "$BREW_PREFIX/opt/openjdk@21/bin" ]]; then
    export PATH="$BREW_PREFIX/opt/openjdk@21/bin:$PATH"
fi

# Pixi
if [[ -d "$HOME/.pixi/bin" ]]; then
    export PATH="$HOME/.pixi/bin:$PATH"
    [[ -d "$HOME/.pixi/completions/zsh" ]] && fpath+=("$HOME/.pixi/completions/zsh")
fi

################# Modules #################
# 检测并加载 Environment Modules
if [[ -n "$BREW_PREFIX" && -f "$BREW_PREFIX/opt/modules/init/zsh" ]]; then
    # Homebrew modules (macOS & Linux)
    source "$BREW_PREFIX/opt/modules/init/zsh"
elif [[ -f "/usr/share/Modules/init/zsh" ]]; then
    # 系统 modules (Linux)
    source "/usr/share/Modules/init/zsh"
fi

# 配置 MODULEPATH
if command -v module &> /dev/null; then
    export MODULEPATH="$HOME/.config/modulefiles:$MODULEPATH"
    
    # Linux: Intel modulefiles
    if [[ "$PLATFORM" == "linux" && -d "$HOME/software/intel-modulefiles" ]]; then
        export MODULEPATH="$HOME/software/intel-modulefiles:$MODULEPATH"
    fi
fi

################# 开发工具初始化 #################

# Rust/Cargo
if [[ -f "$HOME/.cargo/env" ]]; then
    . "$HOME/.cargo/env"
fi

# nvm (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    \. "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
fi

# sedona 相关 (macOS only)
if [[ "$PLATFORM" == "macos" ]]; then
    [[ -d "/opt/homebrew/Cellar/gsl/2.8" ]] && export GSL_DIR="/opt/homebrew/Cellar/gsl/2.8/"
    [[ -d "/opt/homebrew/Cellar/lua/5.4.7" ]] && export LUA_DIR="/opt/homebrew/Cellar/lua/5.4.7/"
fi

################# 工具初始化 #################

# Pixi
command -v pixi &> /dev/null && eval "$(pixi completion --shell zsh)"

# GitHub Copilot CLI
# command -v gh &> /dev/null && eval "$(gh copilot alias -- zsh)"

# Starship Prompt
command -v starship &> /dev/null && eval "$(starship init zsh)"

# Zoxide
command -v zoxide &> /dev/null && eval "$(zoxide init zsh)"

################# fzf 初始化 #################
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
fi

# fzf-tab
if [[ -f "$HOME/.local/share/zshplugin/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    source "$HOME/.local/share/zshplugin/fzf-tab/fzf-tab.plugin.zsh"
fi

################# Zsh 插件 (Homebrew 安装) #################

# 优先使用 Homebrew 安装的插件 (macOS & Linux 通用)
if [[ -n "$BREW_PREFIX" ]]; then
    # Syntax Highlighting (优先使用 fast-syntax-highlighting)
    if [[ -f "$BREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
        source "$BREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    elif [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi
    
    # Autosuggestions
    if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
fi

################# 别名配置 #################

# 编辑器别名
command -v nvim &> /dev/null && alias vim='nvim' && alias vimdiff='nvim -d'

# ls 别名和颜色支持
if [[ "$PLATFORM" == "linux" ]]; then
    # Linux (GNU ls)
    if [[ -x /usr/bin/dircolors ]]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto -F'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
elif [[ "$PLATFORM" == "macos" ]]; then
    # macOS (BSD ls)
    alias ls='ls -GF'
fi

# ls 变体
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# 目录导航 (使用 zoxide 的 z 命令替代 cd)
alias cd='z'

# 平台特定的 open 命令
if [[ "$PLATFORM" == "macos" ]]; then
    alias o='open'
    [[ -d "/Applications/HDFView.app" ]] && alias h5view="open -a HDFView"
elif [[ "$PLATFORM" == "linux" ]]; then
    alias o='xdg-open'
fi

# Git 别名
alias ga='git add . && git commit && git push'

# 其他工具别名
# command -v bat &> /dev/null && alias cat='bat'

# 代理别名
alias proxy-on='export https_proxy=http://127.0.0.1:7890;export http_proxy=http://127.0.0.1:7890;export all_proxy=socks5://127.0.0.1:7890'
alias proxy-off='unset https_proxy;unset http_proxy;unset all_proxy'

# Intel OneAPI (Linux)
if [[ "$PLATFORM" == "linux" && -f "/opt/intel/oneapi/setvars.sh" ]]; then
    alias intel-on="source /opt/intel/oneapi/setvars.sh --force"
fi

################# Yazi 文件管理器集成 #################
if command -v yazi &> /dev/null; then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
    }
fi

################# Water Reminder (macOS) #################
if [[ "$PLATFORM" == "macos" && -f "$HOME/.local/bin/thirsty.sh" ]]; then
    # export WATER_TIME=10 # seconds
    alias drank='$HOME/.local/bin/thirsty.sh drink'
    TMOUT=60 # seconds
    TRAPALRM() {
        if [[ $- == *i* ]]; then
            zle reset-prompt 2>/dev/null || true
        fi
    }
fi

################# 性能分析（取消注释以启用） #################
# zprof

################# 平台特定注释 #################
# 
# Homebrew 插件安装命令:
# - brew install zsh-fast-syntax-highlighting
# - brew install zsh-autosuggestions
#
# WezTerm 安装:
# - macOS: brew install --cask wezterm
# - Linux: apt install wezterm
#
# macOS X11 支持:
# - brew install --cask xquartz
#
# Linux VPN 文档:
# - Cloudflare WARP: warp-cli registration new
#                    warp-cli connect/disconnect
# - OpenConnect VPN: sudo openconnect --protocol=pulse sslvpn.bnu.edu.cn
#
