#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c 'apt-mark showhold; dpkg -l | grep -E "libgbm|mesa-libgallium|libegl-mesa"; apt-cache policy libgbm1 libgbm-dev' 2>&1