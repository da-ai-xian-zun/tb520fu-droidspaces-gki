#!/system/bin/sh
echo "==> stop apt/install scripts stressing network"
pkill -9 -f 'fix_apt_ipv4|container_install_anland|retry_apt|fix_net_and_apt' 2>/dev/null || true
/data/local/Droidspaces/bin/droidspaces --name=debian13 run sh -c 'pkill -9 apt-get apt dpkg 2>/dev/null; true' 2>/dev/null || true

echo "==> remove manual default route (let Android manage)"
ip route del default via 192.168.5.1 dev wlan0 2>/dev/null || true

echo "==> remaining stress procs"
ps -A 2>/dev/null | grep -iE 'apt-get|container_install|fix_apt' || echo "none"
ip route show