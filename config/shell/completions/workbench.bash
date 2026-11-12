# Bash completion reads declarations; it never invokes component handlers.
_workbench_complete() {
 local current=${COMP_WORDS[COMP_CWORD]} component=${COMP_WORDS[1]-} action=${COMP_WORDS[2]-} values
 local helper=${WORKBENCH_HOME:-${SOFTWARE_HOME:-$HOME/Software}/config/workbench}/bin/workbench
 [[ ! -x ${SOFTWARE_HOME:-$HOME/Software}/bin/workbench ]] || helper=${SOFTWARE_HOME:-$HOME/Software}/bin/workbench
 case ${COMP_WORDS[COMP_CWORD-1]} in
  --category) values=$("$helper" --complete categories); COMPREPLY=($(compgen -W "$values" -- "$current")); return;;
  --tag) values=$("$helper" --complete tags); COMPREPLY=($(compgen -W "$values" -- "$current")); return;;
 esac
 case $COMP_CWORD in
  1) values=$("$helper" --complete components 2>/dev/null | cut -d: -f1); values="$values list";;
  2) values=$("$helper" --complete actions "$component" 2>/dev/null);;
  *) values=$("$helper" --complete targets "$component" "$action" 2>/dev/null);;
 esac
 COMPREPLY=($(compgen -W "$values" -- "$current"))
}
complete -F _workbench_complete workbench
