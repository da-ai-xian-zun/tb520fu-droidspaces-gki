#!/bin/bash
echo "=== kdeglobals KDE/KScreen ==="
kreadconfig6 --file kdeglobals --group KDE --key ScaleFactor 2>/dev/null || true
kreadconfig6 --file kdeglobals --group KDE --key ScreenScaleFactor 2>/dev/null || true
kreadconfig6 --file kdeglobals --group KScreen --key ScaleFactor 2>/dev/null || true
kreadconfig6 --file kdeglobals --group KScreen --key ScreenScaleFactors 2>/dev/null || true
grep -A5 '^\[KDE\]' /root/.config/kdeglobals 2>/dev/null || true
grep -A5 '^\[KScreen\]' /root/.config/kdeglobals 2>/dev/null || true

echo "=== kwinrc compositing ==="
kreadconfig6 --file kwinrc --group Compositing --key Enabled 2>/dev/null || true
kreadconfig6 --file kwinrc --group Compositing --key Backend 2>/dev/null || true

echo "=== kscreen json ==="
grep '"scale"' /root/.local/share/kscreen/* 2>/dev/null || true

echo "=== de-start scale exports ==="
grep -E 'PLASMA|QT_|GDK_' /usr/local/bin/de-start 2>/dev/null || true

echo "=== plasmashell env ==="
pid=$(pgrep -n plasmashell || true)
if [ -n "$pid" ]; then
  tr '\0' '\n' < "/proc/$pid/environ" | grep -E 'PLASMA|QT_|GDK_' || echo "(none)"
fi

echo "=== xdpyinfo dimensions ==="
xdpyinfo 2>/dev/null | grep dimensions || true