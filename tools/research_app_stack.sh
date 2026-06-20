#!/system/bin/sh
PID=$(pidof com.droidspaces.app)
echo "app pid=$PID"
if [ -n "$PID" ]; then
  kill -3 "$PID" 2>/dev/null
  sleep 2
  logcat -d -t 400 2>/dev/null | grep -E 'com.droidspaces.app|ContainerInstaller|SparseImage|libsu|Shell|kotlin' | tail -80
fi