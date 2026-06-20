#!/bin/bash
python3 - <<'PY'
import os, time, subprocess

t0 = time.perf_counter()
for _ in range(50):
    subprocess.run(["/usr/bin/stat", "/etc/passwd"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(f"subprocess stat x50: {(time.perf_counter()-t0)*1000:.0f} ms")

t0 = time.perf_counter()
for _ in range(10):
    subprocess.run(["/bin/true"], stdout=subprocess.DEVNULL)
print(f"subprocess true x10: {(time.perf_counter()-t0)*1000:.0f} ms")

t0 = time.perf_counter()
os.stat("/etc/passwd")
print(f"os.stat once: {(time.perf_counter()-t0)*1000:.3f} ms")
PY
echo "thumbnail plugins: $(ls /usr/lib/aarch64-linux-gnu/qt6/plugins/kf6/thumbcreator/ 2>/dev/null | wc -l)"
find /usr/share/wallpapers -type f 2>/dev/null | wc -l