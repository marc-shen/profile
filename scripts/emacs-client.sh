# Sourced by em/ec. Never starts an unmanaged alternate daemon.
root=${SOFTWARE_HOME:-$HOME/Software}
[[ ! -r $root/env.sh ]] || source "$root/env.sh"
source "${PROFILE_HOME:-$root/config/profile}/scripts/emacs-x11-auth.sh"
if [[ $(uname -s) == Darwin && -x /Applications/Emacs.app/Contents/MacOS/bin/emacsclient ]]; then
 client=/Applications/Emacs.app/Contents/MacOS/bin/emacsclient
else
 client=$(command -v emacsclient) || { echo 'emacsclient is missing from PATH' >&2; exit 1; }
fi
if ! "$client" --socket-name=server --eval t >/dev/null 2>&1; then
 if [[ $(uname -s) == Darwin ]]; then
  launchctl kickstart "gui/$(id -u)/org.gnu.emacs.daemon" >/dev/null 2>&1 || true
 else
  systemctl --user start emacs.service
 fi
 for ((i=0; i<100; i++)); do
  "$client" --socket-name=server --eval t >/dev/null 2>&1 && break
  sleep 0.1
 done
fi
frame=(--create-frame)
if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} && ( $(uname -s) != Darwin || -n ${SSH_CONNECTION:-} ) ]]; then
 frame=(--tty)
fi
