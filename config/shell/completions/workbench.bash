# Bash completion reads declarations; it never invokes module handlers.
_workbench_complete() {
 local current=${COMP_WORDS[COMP_CWORD]} module=${COMP_WORDS[1]-} action=${COMP_WORDS[2]-} values
 local helper=${WORKBENCH_HOME:-${SOFTWARE_HOME:-$HOME/Software}/config/workbench}/bin/workbench
 case $COMP_CWORD in
  1) values=$(python3 "$helper" --complete modules 2>/dev/null | cut -d: -f1); values="$values list";;
  2) values=$(python3 "$helper" --complete actions "$module" 2>/dev/null);;
  *) values=$(python3 "$helper" --complete targets "$module" "$action" 2>/dev/null);;
 esac
 COMPREPLY=($(compgen -W "$values" -- "$current"))
}
complete -F _workbench_complete workbench
