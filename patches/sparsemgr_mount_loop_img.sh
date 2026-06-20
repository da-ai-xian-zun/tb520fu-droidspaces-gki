# Android: upstream mount -o loop first (_mount: system then busybox); loop-scan fallback.
_mount_loop_img() {
    local img="$1"
    local mnt="$2"
    shift 2
    local extra_opts="$*"

    if [ -n "$extra_opts" ]; then
        if mount -t ext4 -o loop,"$extra_opts" "$img" "$mnt" 2>/dev/null; then
            return 0
        elif [ -n "$BB" ] && "$BB" mount -t ext4 -o loop,"$extra_opts" "$img" "$mnt" 2>/dev/null; then
            return 0
        fi
    else
        if mount -t ext4 -o loop,ro "$img" "$mnt" 2>/dev/null; then
            return 0
        elif [ -n "$BB" ] && "$BB" mount -t ext4 -o loop,ro "$img" "$mnt" 2>/dev/null; then
            return 0
        fi
    fi

    _loop_scan_start() {
        local max_loop="$1"
        local skip=$((max_loop / 4))
        [ "$skip" -lt 16 ] && skip=16
        [ "$skip" -gt "$max_loop" ] && skip=$max_loop
        local s=$((max_loop - skip))
        [ "$s" -lt 0 ] && s=0
        echo "$s"
    }

    local max_loop start end i loop_dev used_max sysfs=64 block_max=0 n p
    if [ -r /sys/module/loop/parameters/max_loop ]; then
        sysfs=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null) || sysfs=64
        [ -z "$sysfs" ] && sysfs=64
    fi
    for p in /sys/block/loop[0-9]* /sys/block/loop[0-9][0-9]*; do
        [ -e "$p" ] || continue
        n=${p##*/loop}
        case $n in ''|*[!0-9]*) continue ;; esac
        [ "$n" -gt "$block_max" ] && block_max=$n
    done
    if [ $((block_max + 1)) -gt "$sysfs" ]; then
        max_loop=$((block_max + 1))
    else
        max_loop=$sysfs
    fi

    used_max=0
    if [ -r /proc/loops ]; then
        used_max=$(awk 'NR>1 {if ($2+0 > m) m=$2+0} END {print m+0}' /proc/loops 2>/dev/null)
        [ -z "$used_max" ] && used_max=0
    fi
    start=$(_loop_scan_start "$max_loop")
    if [ "$used_max" -ge "$start" ]; then
        start=$((used_max + 1))
    fi
    [ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))
    end=$((max_loop - 1))
    if [ "$used_max" -gt "$end" ]; then
        end=$used_max
    fi
    [ "$end" -gt 255 ] && end=255

    i=$end
    while [ "$i" -ge "$start" ]; do
        loop_dev="/dev/block/loop$i"
        if losetup "$loop_dev" 2>/dev/null; then
            i=$((i - 1))
            continue
        fi
        if losetup "$loop_dev" "$img" 2>/dev/null; then
            if [ -n "$extra_opts" ]; then
                mount -t ext4 -o "$extra_opts" "$loop_dev" "$mnt" 2>/dev/null && return 0
            else
                mount -t ext4 "$loop_dev" "$mnt" 2>/dev/null && return 0
            fi
            umount "$mnt" 2>/dev/null || true
            losetup -d "$loop_dev" 2>/dev/null || true
        fi
        i=$((i - 1))
    done

    error "mount: loop and high-minor losetup both failed for $img"
    return 1
}