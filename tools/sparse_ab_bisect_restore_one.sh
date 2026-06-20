#!/system/bin/sh
set -eu
id="$1"
[ -n "$id" ] || { echo "usage: $0 <module_id>"; exit 1; }
rm -f "/data/adb/modules/$id/disable"
echo "restored $id (reboot required)"
rm -f /data/local/tmp/sparse_ab_bisect_active.txt