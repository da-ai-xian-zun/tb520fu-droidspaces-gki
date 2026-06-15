$checks = @(
  @{ Name = 'boot_completed'; Cmd = 'getprop sys.boot_completed' },
  @{ Name = 'bootanim'; Cmd = 'getprop init.svc.bootanim' },
  @{ Name = 'vbstate'; Cmd = 'getprop ro.boot.verifiedbootstate' },
  @{ Name = 'kernel'; Cmd = 'uname -r' },
  @{ Name = 'config'; Cmd = 'su -c "zcat /proc/config.gz | grep -E SYSVIPC|IPC_NS|PID_NS|POSIX_MQUEUE"' },
  @{ Name = 'wifi_mods'; Cmd = 'su -c "lsmod | grep -E rfkill|cfg80211|qca"' },
  @{ Name = 'droidspaces'; Cmd = 'su -c droidspaces check' }
)
foreach ($c in $checks) {
  Write-Host "=== $($c.Name) ==="
  adb shell $c.Cmd
}