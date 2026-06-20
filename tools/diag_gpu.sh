#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
echo GROUPS
getent group droidspaces-gpu render video
id debian
usermod -aG droidspaces-gpu debian 2>/dev/null || true
chmod 666 /dev/kgsl-3d0 /dev/dri/renderD128 2>/dev/null || true
ls -la /dev/dri/ /dev/kgsl-3d0 2>/dev/null

echo MESA_LIBS
ls /usr/lib/aarch64-linux-gnu/libvulkan* 2>/dev/null | head -5
ls /usr/lib/aarch64-linux-gnu/dri/*zink* 2>/dev/null | head -5
ls /usr/share/vulkan/icd.d/ 2>/dev/null

echo VULKAN
su -l debian -c "HOME=/home/debian VK_LOADER_DEBUG=warn vulkaninfo --summary 2>&1" | tail -30

echo EGL_ROOT
su -l debian -c "HOME=/home/debian MESA_LOADER_DRIVER_OVERRIDE=zink LIBGL_DEBUG=verbose eglinfo 2>&1" | tail -25
'