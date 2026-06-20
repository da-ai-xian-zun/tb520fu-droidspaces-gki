#!/system/bin/sh
echo "=== saved networks / priority ==="
cmd wifi list-networks 2>/dev/null || settings list global wifi 2>/dev/null | head -20

echo "=== who triggers wifi connect ==="
logcat -d -t 500 2>/dev/null | grep -iE 'CMD_CONNECT_NETWORK|ConnectNetwork|WifiPicker|switch.*wifi|DZT|zjy|NETWORK_DISCONNECTION|IP_REACHABILITY|NUD_FAILED|ASSOCIATION_REJECTION' | tail -50

echo "=== disconnect reason codes history ==="
dumpsys wifi 2>/dev/null | grep -iE 'reasonCode|Disconnect|IP_REACHABILITY|NUD|ASSOCIATION_REJECTION|roam|BSSID' | tail -40

echo "=== manual routes (our scripts may add these) ==="
ip route show
ip -6 route show

echo "=== arp/neigh gateway ==="
ip neigh show 192.168.5.1 2>/dev/null
ping -c2 -W2 192.168.5.1 2>&1

echo "=== wifi settings ==="
settings get global wifi_networks_available_notification_on
settings get global network_recommendations_enabled
settings get secure wifi_wakeup_enabled 2>/dev/null
dumpsys wifi 2>/dev/null | grep -iE 'auto.*join|metered|disabled|Internet|lastConnected' | head -20