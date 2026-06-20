#!/bin/bash
pgrep -a kwin_x11 || echo "kwin: not running"
pgrep -a plasmashell || echo "plasmashell: not running"
echo "compositor=$(kreadconfig6 --file kwinrc --group Compositing --key Enabled 2>/dev/null)"
pid=$(pgrep -n kwin_x11 2>/dev/null || true)
if [ -n "$pid" ]; then
  echo "kwin mesa env:"
  tr '\0' '\n' < "/proc/$pid/environ" | grep -E 'MESA|GALLIUM|FD_FORCE' || echo "(none)"
fi
pid2=$(pgrep -n plasmashell 2>/dev/null || true)
if [ -n "$pid2" ]; then
  echo "plasmashell mesa env:"
  tr '\0' '\n' < "/proc/$pid2/environ" | grep -E 'MESA|GALLIUM|FD_FORCE' || echo "(none)"
fi