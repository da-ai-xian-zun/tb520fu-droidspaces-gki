#!/bin/bash
echo "user debian: $(id debian 2>/dev/null || echo missing)"
ps -o user:12,pid,comm -C kwin_x11 -C plasmashell 2>/dev/null || ps aux | grep -E 'kwin_x11|plasmashell' | grep -v grep
echo "HOME for session should be /home/debian"
ls -la /home/debian/.config/kdeglobals 2>/dev/null | head -1 || echo "no kdeglobals"
grep '^Enabled=' /home/debian/.config/kwinrc 2>/dev/null || true