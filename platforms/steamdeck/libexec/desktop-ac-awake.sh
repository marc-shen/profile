#!/bin/bash
set -euo pipefail
# Plasma 6: disable automatic suspend on AC; keep all other power preferences.
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
mkdir -p "$config_home"
/usr/bin/kwriteconfig6 --file "$config_home/powerdevilrc" \
 --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
value=$(/usr/bin/kreadconfig6 --file "$config_home/powerdevilrc" \
 --group AC --group SuspendAndShutdown --key AutoSuspendAction)
[[ $value == 0 ]] || { echo 'Could not disable automatic suspend on AC.' >&2; exit 1; }
