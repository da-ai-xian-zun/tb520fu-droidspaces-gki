#!/bin/sh
# Run on Android host as root via adb: refresh stale Termux:X11 + Droidspaces session

set -e

DS=/data/local/Droidspaces/bin/droidspaces

echo "Stopping debian13 container ..."
$DS --name=debian13 stop 2>/dev/null || true
sleep 2

echo "Killing stale Termux:X11 X server ..."
pkill -f 'termux-x11.*:5' 2>/dev/null || true
sleep 1

echo "Restarting Termux:X11 app ..."
am force-stop com.termux.x11 2>/dev/null || true
sleep 1

echo "Starting debian13 container ..."
$DS --name=debian13 start

echo "Done. Open Termux:X11 app on the tablet now."