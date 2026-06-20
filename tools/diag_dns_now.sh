#!/system/bin/sh
echo "=== routes ==="
ip -4 route show
echo "=== resolv ==="
getprop net.dns1 getprop net.dns2 2>/dev/null
cat /etc/resolv.conf 2>/dev/null || true
echo "=== dns test ==="
nslookup baidu.com 192.168.5.1 2>&1 | head -8
nslookup baidu.com 223.5.5.5 2>&1 | head -8
echo "=== ip test bypass dns ==="
curl -I --max-time 8 http://223.5.5.5 2>&1 | head -3
curl -I --max-time 8 http://1.1.1.1 2>&1 | head -3
ping -c2 -W2 223.5.5.5 2>&1
echo "=== connectivity validated? ==="
dumpsys connectivity 2>/dev/null | grep -i validated | head -5
cmd connectivity set-airplane-mode disabled 2>/dev/null
svc wifi disable 2>/dev/null; sleep 2; svc wifi enable 2>/dev/null
echo "wifi toggled"