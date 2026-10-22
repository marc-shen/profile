# Sourced by Linux Emacs launchers before contacting or starting the daemon.
# KDE uses a session-specific XAUTHORITY. Xlib reads the daemon's native
# environment, so changing only Emacs Lisp process-environment is insufficient.
# Keep the user's standard private authority file current, without xhost bypasses.
if [[ $(uname -s) == Linux && -n ${DISPLAY:-} ]]; then
 _emacs_auth_source=${XAUTHORITY:-$HOME/.Xauthority}
 _emacs_auth_target=$HOME/.Xauthority
 if [[ -r $_emacs_auth_source && ! $_emacs_auth_source -ef $_emacs_auth_target ]]; then
  if ! command -v xauth >/dev/null 2>&1; then
   echo 'Emacs: xauth is required to share the current X11 session with the daemon.' >&2
   return 1
  fi
  (
   umask 077
   touch "$_emacs_auth_target"
   chmod 600 "$_emacs_auth_target"
   xauth -f "$_emacs_auth_target" merge "$_emacs_auth_source"
  ) || return 1
 fi
 unset _emacs_auth_source _emacs_auth_target
fi
