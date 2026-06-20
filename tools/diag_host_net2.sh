#!/system/bin/sh
echo "=== all addrs ==="
ip addr show wlan0 rmnet_data0 rmnet0 ccmni0 2>/dev/null
ip -6 addr show 2>/dev/null | head -20
echo "=== dumpsys connectivity (short) ==="
dumpsys connectivity 2>/dev/null | grep -iE 'NetworkAgentInfo|VALIDATED|wifi|TRANSPORT' | head -25