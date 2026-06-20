#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
am start -n com.virtual_drm.consumer/.MainActivity 2>/dev/null
sleep 2
$DS --name=debian13 run bash -c '
export SOCK=/var/lib/anland/display_daemon.sock
pgrep -a weston && pkill weston; sleep 1
/usr/local/bin/de-start &
sleep 25
echo "=== procs ==="
pgrep -af weston || echo no-weston
pgrep -af kwin || echo no-kwin
pgrep -af plasmashell || echo no-plasma
pgrep -af startplasma || echo no-startplasma
' 2>&1