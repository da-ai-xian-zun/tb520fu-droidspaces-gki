#!/system/bin/sh
/data/local/Droidspaces/bin/droidspaces --name=debian13 run pgrep -af 'weston|kwin|plasmashell|startplasma' 2>/dev/null
pgrep -a display_daemon