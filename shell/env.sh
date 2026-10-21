# POSIX environment shared by terminals, Emacs and launchers. No network calls.
export SOFTWARE_HOME="${SOFTWARE_HOME:-$HOME/Software}"
export SOFTWARE_USER_HOME="${SOFTWARE_USER_HOME:-$HOME/Software}"
export PROFILE_HOME="${PROFILE_HOME:-$SOFTWARE_HOME/config/profile}"
export PROFILE_PLATFORM=linux
case "$(uname -s)" in
 Darwin)
  export PROFILE_PLATFORM=macos
  for _profile_brew in /opt/homebrew /usr/local; do
   if [ -x "$_profile_brew/bin/brew" ]; then
    export HOMEBREW_PREFIX="$_profile_brew"
    case ":$PATH:" in *":$_profile_brew/bin:"*) ;; *) PATH="$_profile_brew/bin:$_profile_brew/sbin:$PATH";; esac
    break
   fi
  done;;
 Linux)
  if [ -r /etc/os-release ]; then
   _profile_os=$(. /etc/os-release; printf '%s' "$ID")
   case $_profile_os in steamos) PROFILE_PLATFORM=steamdeck;; fedora) PROFILE_PLATFORM=fedora;; ubuntu|debian) PROFILE_PLATFORM=$_profile_os;; esac
  fi;;
esac
# Personal commands override shared commands; do not globally activate a compiler.
for _profile_bin in /opt/Software/bin "$HOME/.cargo/bin" "$HOME/.local/bin" "$SOFTWARE_HOME/bin" "$SOFTWARE_USER_HOME/bin"; do
 [ -d "$_profile_bin" ] || continue
 _profile_rest=$PATH:
 _profile_tail=
 while [ -n "$_profile_rest" ]; do
  _profile_part=${_profile_rest%%:*}
  _profile_rest=${_profile_rest#*:}
  [ "$_profile_part" = "$_profile_bin" ] || _profile_tail="$_profile_tail${_profile_tail:+:}$_profile_part"
 done
 PATH="$_profile_bin${_profile_tail:+:}$_profile_tail"
done
export PATH
export PIXI_CACHE_DIR="${PIXI_CACHE_DIR:-$SOFTWARE_USER_HOME/cache/pixi}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$SOFTWARE_USER_HOME/cache/uv}"
export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$SOFTWARE_USER_HOME/data/uv/python}"
export UV_TOOL_DIR="${UV_TOOL_DIR:-$SOFTWARE_USER_HOME/data/uv/tools}"
export UV_TOOL_BIN_DIR="${UV_TOOL_BIN_DIR:-$SOFTWARE_USER_HOME/bin}"
[ ! -r "$SOFTWARE_USER_HOME/config/local/env.sh" ] || . "$SOFTWARE_USER_HOME/config/local/env.sh"
unset _profile_brew _profile_bin _profile_os _profile_rest _profile_tail _profile_part
