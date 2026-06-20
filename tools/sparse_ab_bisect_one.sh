#!/system/bin/sh
# Disable ONE module, require reboot externally, then smoke
set -eu
id="$1"
[ -n "$id" ] || { echo "usage: $0 <module_id>"; exit 1; }
d="/data/adb/modules/$id"
[ -d "$d" ] || { echo "no module $id"; exit 1; }
if [ -f "$d/disable" ]; then
  echo "already disabled $id"
else
  touch "$d/disable"
  echo "disabled $id (reboot required)"
fi
echo "$id" > /data/local/tmp/sparse_ab_bisect_active.txt