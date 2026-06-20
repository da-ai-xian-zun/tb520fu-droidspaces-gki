#!/system/bin/sh
echo "=== host shell ip ==="
ip -4 addr show
ip -4 route show
ping -c1 -W2 192.168.5.1 2>&1 | tail -2
ping -c1 -W2 1.1.1.1 2>&1 | tail -2

echo "=== container ip ==="
/data/local/Droidspaces/bin/droidspaces --name=debian13 run sh -c 'ip -4 addr show; ip -4 route show; ping -c1 -W2 192.168.5.1 2>&1 | tail -2' 2>&1