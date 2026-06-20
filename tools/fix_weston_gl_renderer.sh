#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c 'grep -n weston /opt/weston-anland/start_kde_zink.sh | head -3
sed -i "s|--no-config \&|--renderer=gl --no-config \&|" /opt/weston-anland/start_kde_zink.sh
grep weston /opt/weston-anland/start_kde_zink.sh | grep disp-sock'