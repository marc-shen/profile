#!/bin/bash
set -euo pipefail
root=$1
deck_user=$2
test "$EUID" = 0
[[ $deck_user =~ ^[a-z_][a-z0-9_-]*$ ]]
core=$(readlink -f "$root/apps/mihomo/current/mihomo")
setcap cap_net_admin,cap_net_raw,cap_net_bind_service,cap_sys_ptrace,cap_dac_read_search+ep "$core"
mkdir -p /etc/polkit-1/rules.d /etc/profile-mihomo /etc/atomic-update.conf.d
cat > /etc/polkit-1/rules.d/49-profile-mihomo-dns.rules <<EOF
polkit.addRule(function(action, subject) {
  var allowed = ["org.freedesktop.resolve1.set-dns-servers", "org.freedesktop.resolve1.set-domains", "org.freedesktop.resolve1.set-default-route", "org.freedesktop.resolve1.revert"];
  if (subject.user == "$deck_user" && action.lookup("interface") == "mihomo-tun" && allowed.indexOf(action.id) >= 0) return polkit.Result.YES;
});
EOF
cat > /etc/profile-mihomo/firewall.nft <<'EOF'
table inet profile_mihomo {
  chain input {
    type filter hook input priority -5; policy accept;
    tcp dport 9090 iifname "lo" accept
    tcp dport 9090 iifname "tailscale0" ip saddr 100.64.0.0/10 accept
    tcp dport 9090 iifname "tailscale0" ip6 saddr fd7a:115c:a1e0::/48 accept
    tcp dport 9090 drop
  }
}
EOF
cat > /etc/profile-mihomo/firewall.sh <<'EOF'
#!/bin/sh
set -e
/usr/bin/nft list table inet profile_mihomo >/dev/null 2>&1 && /usr/bin/nft delete table inet profile_mihomo
/usr/bin/nft -f /etc/profile-mihomo/firewall.nft
EOF
chmod 755 /etc/profile-mihomo/firewall.sh
cat > /etc/systemd/system/profile-mihomo-firewall.service <<'EOF'
[Unit]
Description=Limit Mihomo web access to Tailscale
After=network-pre.target
Before=network.target
[Service]
Type=oneshot
ExecStart=/etc/profile-mihomo/firewall.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/atomic-update.conf.d/91-profile-mihomo.conf <<'EOF'
/etc/atomic-update.conf.d/91-profile-mihomo.conf
/etc/polkit-1/rules.d/49-profile-mihomo-dns.rules
/etc/profile-mihomo/**
/etc/systemd/system/profile-mihomo-firewall.service
/etc/systemd/system/multi-user.target.wants/profile-mihomo-firewall.service
EOF
systemctl daemon-reload
systemctl enable profile-mihomo-firewall.service
systemctl restart profile-mihomo-firewall.service
loginctl enable-linger "$deck_user"
