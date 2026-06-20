#!/bin/bash
python3 - <<'PY'
import os, time, subprocess

t0 = time.perf_counter()
for _ in range(100):
    subprocess.run(["/usr/bin/stat", "/etc/passwd"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(f"subprocess stat x100: {(time.perf_counter()-t0)*1000:.0f} ms")

t0 = time.perf_counter()
for _ in range(100):
    os.fork()
print(f"os.fork x100: {(time.perf_counter()-t0)*1000:.0f} ms (includes child exit wait issues)")
PY

echo "========== THUMBNAIL PIPELINE =========="
ls /usr/lib/aarch64-linux-gnu/qt6/plugins/kf6/thumbcreator/ 2>/dev/null | head -20
ls /usr/lib/aarch64-linux-gnu/libexec/kf6/thumbnail* 2>/dev/null || true
dpkg -l | grep -E 'kio-extras|ffmpegthumbs|kdegraphics-thumbnailers' || true

echo "========== BALOO FILES =========="
ls -la /root/.local/share/baloo/ 2>/dev/null || true
find /root/.local/share/baloo -type f 2>/dev/null | head -10

echo "========== DOLPHIN PREVIEW =========="
kreadconfig6 --file dolphinrc --group Preview --key Plugins 2>/dev/null || true
grep -r Preview /root/.config/dolphinrc 2>/dev/null || true

echo "========== KCM WALLPAPER WALLPAPERS COUNT =========="
find /usr/share/wallpapers -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) 2>/dev/null | wc -l
find /usr/share/wallpapers -type f 2>/dev/null | wc -l