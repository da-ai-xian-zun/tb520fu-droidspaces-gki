#!/system/bin/sh
echo "===== $(date) wifi diagnostic ====="

echo "=== current wifi ==="
dumpsys wifi 2>/dev/null | grep -iE 'mWifiInfo|SSID|BSSID|RSSI|Supplicant state|Disconnected|connected|reason|fail|Last|frequency|score' | head -40

echo "=== connectivity ==="
dumpsys connectivity 2>/dev/null | grep -iE 'NetworkAgentInfo|WIFI|CONNECTED|DISCONNECTED|VALIDATED|wlan0|192\.168' | head -20

echo "=== ip link wlan0 ==="
ip link show wlan0 2>/dev/null
ip -4 addr show wlan0 2>/dev/null
ip -4 route show 2>/dev/null

echo "=== wifi supplicant state ==="
wpa_cli -i wlan0 status 2>/dev/null || true

echo "=== recent wifi logcat ==="
logcat -d -t 200 -s WifiHAL:w WifiNative:w wpa_supplicant:I WifiClientModeImpl:w WifiScoreCard:v WifiConnectivityManager:w ConnectivityService:i AndroidRuntime:E 2>/dev/null | tail -80

echo "=== kernel wlan/drv (dmesg) ==="
dmesg 2>/dev/null | grep -iE 'wlan|wifi|cnss|qca|disconnect|deauth|firmware|crash|reset' | tail -40

echo "=== power / doze ==="
dumpsys deviceidle 2>/dev/null | grep -iE 'mScreenOn|mActive|wifi' | head -10
settings get global wifi_sleep_policy 2>/dev/null
settings get global wifi_scan_always_enabled 2>/dev/null

echo "=== heavy processes ==="
ps -A -o PID,NAME,RSS,ARGS 2>/dev/null | grep -iE 'apt|dpkg|ninja|meson|weston|display_daemon|droidspaces|container' | head -20

echo "=== thermal ==="
cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || true
dumpsys thermalservice 2>/dev/null | grep -iE 'Current|throttle|wifi' | head -15