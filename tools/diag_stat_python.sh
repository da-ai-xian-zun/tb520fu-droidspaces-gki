#!/bin/bash
python3 - <<'PY'
import os, time, tempfile

def bench(label, path, n):
    os.stat(path)  # warm
    t0 = time.perf_counter()
    for _ in range(n):
        os.stat(path)
    ms = (time.perf_counter() - t0) * 1000
    print(f"{label} stat x{n}: {ms:.1f} ms (avg {ms*1000/n:.1f} us)")

bench("f2fs /etc/passwd", "/etc/passwd", 5000)
fd, p = tempfile.mkstemp(dir="/tmp")
os.close(fd)
bench("tmpfs tempfile", p, 5000)
os.unlink(p)

# simulate dolphin listing a medium dir
t0 = time.perf_counter()
count = 0
for root, dirs, files in os.walk("/usr/share/pixmaps"):
    for f in files:
        os.stat(os.path.join(root, f))
        count += 1
ms = (time.perf_counter() - t0) * 1000
print(f"walk+stat /usr/share/pixmaps: {count} files in {ms:.1f} ms")
PY

echo "LD_PRELOAD=${LD_PRELOAD:-}"
cat /proc/1/status 2>/dev/null | grep -i seccomp || true