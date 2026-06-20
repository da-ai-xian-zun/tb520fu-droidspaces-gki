#!/system/bin/sh
echo "=== routes ==="
ip -4 route show
echo "=== dns props ==="
getprop | grep -i dns | head -10
echo "=== dns test via router ==="
nslookup baidu.com 192.168.5.1 2>&1 | head -8
echo "=== ping public ip ==="
ping -c2 -W3 223.5.5.5 2>&1
ping -c2 -W3 1.1.1.1 2>&1
echo "=== curl by ip ==="
curl -I --max-time 8 http://223.5.5.5 2>&1 | head -4