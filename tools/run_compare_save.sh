#!/system/bin/sh
OUT=/data/local/tmp/sparse_compare_20260621.txt
sh /data/local/tmp/sparse_cli_app_compare.sh >"$OUT" 2>&1
echo SAVED:$OUT
wc -c "$OUT"