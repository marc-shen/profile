#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
source "$repo/config/shell/env.sh"
if [[ $PROFILE_PLATFORM == steamdeck ]]; then
 app="$SOFTWARE_HOME/apps/emacs/current"
 source "$app/activate.sh"
 export CPPFLAGS="-D_GNU_SOURCE -I$CONDA_PREFIX/include"
 export LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"
 export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$CONDA_PREFIX/share/pkgconfig"
 binary="$app/bin/emacs"
else
 binary=${EMACS_BINARY:-}
 if [[ -z $binary ]]; then
  if [[ $PROFILE_PLATFORM == macos && -x "$HOME/Applications/Emacs Client.app/Contents/MacOS/Emacs" ]]; then
   binary="$HOME/Applications/Emacs Client.app/Contents/MacOS/Emacs"
  elif [[ $PROFILE_PLATFORM == macos && -x /Applications/Emacs.app/Contents/MacOS/Emacs ]]; then
   binary=/Applications/Emacs.app/Contents/MacOS/Emacs
  elif [[ -x $SOFTWARE_HOME/bin/emacs-real ]]; then
   binary="$SOFTWARE_HOME/bin/emacs-real"
  else
   binary=$(command -v emacs || true)
  fi
 fi
fi
[[ -n $binary && -x $binary ]] || { echo 'Native Emacs is not installed' >&2; exit 1; }
# The installer tells PDF Tools to skip distribution package installation.
exec "$binary" --batch -Q -l "$repo/libexec/install-emacs-packages.el"
