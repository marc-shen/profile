#!/bin/bash
# Invoked explicitly by deck-network tailscale activate in a local Konsole.
set -euo pipefail
root=$1
upstream=$2
deck_user=$3
action=${4:-prepare}
test "$EUID" = 0
. /etc/os-release
test "$ID" = steamos
# Preserve the user's exit node, login, DNS and advertised-route preferences.
if [ ! -x /opt/tailscale/tailscale ] || [ "$action" = update-tailscale ]; then
  (cd "$upstream" && bash tailscale.sh)
fi
mkdir -p /etc/atomic-update.conf.d
cat > /etc/atomic-update.conf.d/90-deck-tailscale-persistence.conf <<'EOF'
# Supplement upstream deck-tailscale's own persistence list.
/etc/atomic-update.conf.d/90-deck-tailscale-persistence.conf
/etc/default/tailscaled
/etc/profile.d/tailscale.sh
/etc/systemd/system/tailscaled.service
/etc/systemd/system/tailscaled.service.d/**
/etc/systemd/system/multi-user.target.wants/tailscaled.service
EOF
