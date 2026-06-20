#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
OUT=/data/local/tmp/dri_fix.out
{
echo "=== dri fix $(date) ==="
echo "--- host dri ---"
ls -la /dev/dri/ 2>/dev/null || echo no host dri

$DS --name=debian13 run sh -c '
echo "--- container dri ---"
ls -la /dev/dri/ 2>/dev/null || echo no dri
ls -la /dev/kgsl* 2>/dev/null || true
id debian
groups debian
getent group render video 2>/dev/null || true

# ensure render group and membership
getent group render >/dev/null || groupadd -r render
getent group video >/dev/null || groupadd -r video
usermod -aG render,video debian 2>/dev/null || true

# permissive perms for testing
chmod 666 /dev/dri/* 2>/dev/null || true
chown root:render /dev/dri/renderD* 2>/dev/null || true
chmod 660 /dev/dri/renderD* 2>/dev/null || true

echo "--- after fix ---"
ls -la /dev/dri/ 2>/dev/null
id debian

echo "--- mesa test ---"
su -l debian -c "HOME=/home/debian MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink eglinfo 2>&1" | tail -20
'
} > "$OUT" 2>&1
cat "$OUT"