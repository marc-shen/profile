# Source from interactive shells or explicitly from a build script.
if ! type module >/dev/null 2>&1; then
 _profile_shell=bash
 [ -z "${ZSH_VERSION:-}" ] || _profile_shell=zsh
 for _profile_init in \
  "$SOFTWARE_HOME/config/modules/init/$_profile_shell" \
  "$SOFTWARE_HOME/apps/modules/current/init/$_profile_shell" \
  "${HOMEBREW_PREFIX:-/nonexistent}/opt/modules/init/$_profile_shell" \
  "/usr/share/Modules/init/$_profile_shell" \
  "/usr/share/modules/init/$_profile_shell"; do
  if [ -r "$_profile_init" ]; then . "$_profile_init"; break; fi
 done
fi
if type module >/dev/null 2>&1; then
 case ":${MODULEPATH:-}:" in
  *":$SOFTWARE_HOME/share/modulefiles:"*) ;;
  *) export MODULEPATH="$SOFTWARE_HOME/share/modulefiles${MODULEPATH:+:$MODULEPATH}";;
 esac
fi
if type module >/dev/null 2>&1; then
 for _profile_modules in /opt/Software/share/modulefiles "$SOFTWARE_USER_HOME/share/modulefiles"; do
  [ -d "$_profile_modules" ] || continue
  case ":${MODULEPATH:-}:" in *":$_profile_modules:"*) ;; *) export MODULEPATH="$_profile_modules${MODULEPATH:+:$MODULEPATH}";; esac
 done
fi
unset _profile_shell _profile_init _profile_modules
