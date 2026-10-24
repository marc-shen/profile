# Sourced by em/ec. Never starts an unmanaged alternate daemon.
root=${SOFTWARE_HOME:-$HOME/Software}
[[ ! -r $root/env.sh ]] || source "$root/env.sh"
source "${PROFILE_HOME:-$root/config/profile}/scripts/emacs-x11-auth.sh"
if [[ $(uname -s) == Darwin && -x /Applications/Emacs.app/Contents/MacOS/bin/emacsclient ]]; then
 client=/Applications/Emacs.app/Contents/MacOS/bin/emacsclient
else
 client=$(command -v emacsclient) || { echo 'emacsclient is missing from PATH' >&2; exit 1; }
fi
if ! "$client" --timeout=5 --socket-name=server --eval t >/dev/null 2>&1; then
 if [[ $(uname -s) == Darwin ]]; then
  domain="gui/$(id -u)"
  service="$domain/org.gnu.emacs.daemon"
  plist="$HOME/Library/LaunchAgents/org.gnu.emacs.daemon.plist"
  if ! launchctl print "$service" >/dev/null 2>&1; then
   if [[ ! -r $plist ]]; then
    echo "Missing $plist; run ./bootstrap.sh service from the profile checkout." >&2
    exit 1
   fi
   # A stopped/unloaded service needs bootstrap, not just kickstart.
   # Another launcher may win the race to load it; verify before failing.
   if ! launchctl bootstrap "$domain" "$plist"; then
    launchctl print "$service" >/dev/null 2>&1 || exit 1
   fi
  fi
  # No -k: never kill a running daemon or its unsaved buffers.
  launchctl kickstart "$service" >/dev/null
 else
  systemctl --user start emacs.service
 fi
 ready=false
 for ((i=0; i<20; i++)); do
  if "$client" --timeout=1 --socket-name=server --eval t >/dev/null 2>&1; then
   ready=true
   break
  fi
  sleep 0.1
 done
 if ! $ready; then
  echo "Emacs daemon is not responding. Save or recover unsaved buffers before restarting it." >&2
  exit 1
 fi
fi
frame=(--create-frame)
if [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} && ( $(uname -s) != Darwin || -n ${SSH_CONNECTION:-} ) ]]; then
 frame=(--tty)
fi

# A bare pipe/redirection, or a sole --stdin / -, opens an unnamed text buffer.
# File arguments always retain their normal meaning (including Git's EDITOR).
profile_emacs_stdin() {
 local mode=$1
 shift
 if [[ $# == 1 && ( $1 == --stdin || $1 == - ) ]]; then
  :
 elif [[ $# == 0 && ( -p /dev/stdin || -f /dev/stdin ) ]]; then
  :
 else
  return 0
 fi
 local input quoted_input helper directory expression wait=t
 input=$(mktemp "${TMPDIR:-/tmp}/emacs-stdin.XXXXXXXX")
 trap 'rm -f -- "$input"' EXIT
 cat > "$input"
 # Lisp string quoting: stdin itself is never interpolated into code/argv.
 helper=$repo/scripts/emacs-stdin.el
 directory=$PWD/
 quoted_input=${input//\\/\\\\}; quoted_input=${quoted_input//\"/\\\"}
 helper=${helper//\\/\\\\}; helper=${helper//\"/\\\"}
 directory=${directory//\\/\\\\}; directory=${directory//\"/\\\"}
 local options=()
 if [[ $mode == em && ${frame[0]} != --tty ]]; then
  options=(--no-wait)
  wait=nil
 fi
 expression="(progn (load \"$helper\" nil t) (profile-emacs-stdin \"$quoted_input\" \"$directory\" $wait))"
 # A terminal client must read keystrokes from the controlling tty, not the pipe.
 if [[ ${frame[0]} == --tty ]]; then
  "$client" --socket-name=server "${frame[@]}" --suppress-output --eval "$expression" </dev/tty
 elif [[ $wait == nil ]]; then
  "$client" --socket-name=server "${options[@]}" "${frame[@]}" --suppress-output --eval "$expression"
 else
  "$client" --socket-name=server "${frame[@]}" --suppress-output --eval "$expression"
 fi
 # The daemon removes the transfer file after reading it. In no-wait mode it
 # may not have read it yet, so only remove locally on failure (EXIT trap).
 trap - EXIT
 exit 0
}
