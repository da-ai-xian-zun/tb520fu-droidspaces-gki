#!/system/bin/sh
echo "=== network validation ==="
dumpsys connectivity 2>/dev/null | grep -iE 'VALIDATED|PARTIAL|CAPTIVE|111|zjy|NetworkAgent' | head -25

echo "=== kill remaining apt ==="
kill -9 20166 20154 20152 20153 20150 20148 2>/dev/null || pkill -9 apt-get 2>/dev/null || true
ps -A | grep apt || echo "apt stopped"

echo "=== test internet from android ==="
curl -I --max-time 10 http://connectivitycheck.gstatic.com/generate_204 2>&1 | head -5
curl -I --max-time 10 https://www.baidu.com 2>&1 | head -3

echo "=== wifi recent validation failures ==="
logcat -d -t 300 2>/dev/null | grep -iE 'validation|VALIDATED|CAPTIVE|NUD_FAILED|REACHABILITY|Blocklist|zjy|DZT' | tail -30