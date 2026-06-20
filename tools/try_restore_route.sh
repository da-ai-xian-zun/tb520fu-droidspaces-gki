#!/system/bin/sh
echo "before:"
ip -4 route show
ip neigh show 192.168.5.1

# restore default route Android lost after NUD failure
ip route add default via 192.168.5.1 dev wlan0 2>/dev/null || true

echo "after:"
ip -4 route show
ping -c2 -W3 223.5.5.5 2>&1
curl -I --max-time 8 http://connectivitycheck.gstatic.com/generate_204 2>&1 | head -4