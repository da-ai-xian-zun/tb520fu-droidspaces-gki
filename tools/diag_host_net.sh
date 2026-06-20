#!/system/bin/sh
echo "=== interfaces with ipv4 ==="
ip -4 addr show
echo "=== routes ==="
ip -4 route show
echo "=== connectivity ==="
ping -c1 -W3 1.1.1.1 2>&1
ping -c1 -W3 8.8.8.8 2>&1
nslookup deb.debian.org 1.1.1.1 2>&1 | head -6