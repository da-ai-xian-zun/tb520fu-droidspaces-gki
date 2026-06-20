#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/99force-ipv4 <<EOF
Acquire::ForceIPv4 "true";
EOF
ip route show | grep -q "^default" || ip route add default via 192.168.5.1 dev wlan0
rm -rf /var/lib/apt/lists/*
apt-get -o Debug::Acquire::http=true update 2>&1 | tail -20
' 2>&1