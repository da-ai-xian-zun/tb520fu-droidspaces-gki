param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "stock_config.txt",

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$configLines = Get-Content -LiteralPath $ConfigPath -Encoding UTF8

if (-not ($configLines | Where-Object { $_ -match "^(CONFIG_|# CONFIG_)" } | Select-Object -First 1)) {
    throw "Input does not look like a kernel .config: $ConfigPath. If /proc/config.gz is unavailable, extract IKCONFIG from boot.img or rely on runtime probes instead."
}

function Get-KconfigValue {
    param([string]$Name)

    $setPattern = "^CONFIG_$([regex]::Escape($Name))=(.+)$"
    $unsetPattern = "^# CONFIG_$([regex]::Escape($Name)) is not set$"

    foreach ($line in $configLines) {
        if ($line -match $setPattern) {
            return $Matches[1]
        }
        if ($line -match $unsetPattern) {
            return "n"
        }
    }

    return "missing"
}

function New-Check {
    param(
        [string]$Group,
        [string]$Name,
        [string]$Required,
        [string]$Why,
        [switch]$ModuleOk,
        [switch]$DoNotNewlyEnable
    )

    $value = Get-KconfigValue $Name
    $ok = $false
    $level = "info"
    $note = ""

    if ($DoNotNewlyEnable.IsPresent) {
        $ok = $true
        if ($value -eq "y" -or $value -eq "m") {
            $level = "warn"
            $note = "Already enabled in this config. Do not add it manually in a custom GKI build unless you have a separate reason."
        } else {
            $level = "ok"
            $note = "Not enabled. Good for the minimal GKI route."
        }
    } elseif ($Required -eq "y") {
        if ($value -eq "y") {
            $ok = $true
            $level = "ok"
        } elseif ($ModuleOk.IsPresent -and $value -eq "m") {
            $ok = $true
            $level = "warn"
            $note = "Module build. Usually acceptable only if the matching module is available and loadable."
        } else {
            $level = "fail"
            $note = "Expected CONFIG_$Name=y."
        }
    } elseif ($Required -eq "m_or_y") {
        if ($value -eq "y" -or $value -eq "m") {
            $ok = $true
            $level = "ok"
        } else {
            $level = "warn"
            $note = "Optional feature unavailable."
        }
    } else {
        $ok = $true
        $level = "info"
    }

    [pscustomobject]@{
        Group = $Group
        Option = "CONFIG_$Name"
        Value = $value
        Expected = $Required
        Level = $level
        OK = $ok
        Why = $Why
        Note = $note
    }
}

$checks = @()

# Current Droidspaces v6.3.0 runtime MUSTs are functional checks, not all direct
# config checks. These config options are the closest build-time proxies.
$checks += New-Check "core" "NAMESPACES" "y" "Base namespace support."
$checks += New-Check "core" "PID_NS" "y" "PID namespace; Droidspaces cannot boot a real init as PID 1 without it."
$checks += New-Check "core" "UTS_NS" "y" "Hostname namespace; runtime checker treats UTS namespace as MUST."
$checks += New-Check "core" "IPC_NS" "y" "IPC namespace; runtime checker treats IPC namespace as MUST."
$checks += New-Check "core" "SYSVIPC" "y" "Droidspaces GKI guide enables System V IPC; requires kABI-safe SYSVIPC patch on GKI 6.1."
$checks += New-Check "core" "POSIX_MQUEUE" "y" "Current Droidspaces GKI config still enables POSIX message queues. On GKI 6.1 this is a config requirement; the separate POSIX_MQUEUE kABI patch is documented for 5.10 and below only."
$checks += New-Check "core" "SECCOMP" "y" "Runtime checker treats seccomp as MUST."
$checks += New-Check "core" "SECCOMP_FILTER" "y" "Needed for practical seccomp filtering."

$checks += New-Check "recommended" "DEVTMPFS" "m_or_y" "Important for hardware access mode; current checker can fall back to tmpfs for basic containers." -ModuleOk
$checks += New-Check "recommended" "OVERLAY_FS" "m_or_y" "Needed for volatile mode." -ModuleOk
$checks += New-Check "recommended" "CGROUPS" "y" "Cgroup base support; Droidspaces prefers cgroup v2 on modern kernels."
$checks += New-Check "recommended" "CGROUP_NS" "m_or_y" "Runtime checker treats cgroup namespace as recommended, not mandatory." -ModuleOk
$checks += New-Check "recommended" "CGROUP_FREEZER" "m_or_y" "Useful cgroup controller on legacy/v1 paths." -ModuleOk
$checks += New-Check "recommended" "TMPFS_POSIX_ACL" "m_or_y" "Recommended by current GKI guide for Nix/NixOS-style workloads." -ModuleOk
$checks += New-Check "recommended" "TMPFS_XATTR" "m_or_y" "Recommended by current GKI guide for Nix/NixOS-style workloads." -ModuleOk

$checks += New-Check "network" "NET_NS" "m_or_y" "Needed for --net=nat and --net=none." -ModuleOk
$checks += New-Check "network" "VETH" "m_or_y" "Needed for NAT mode; no fallback if absent." -ModuleOk
$checks += New-Check "network" "BRIDGE" "m_or_y" "Needed for bridge NAT mode; Droidspaces has a bridgeless fallback." -ModuleOk
$checks += New-Check "network" "BRIDGE_NETFILTER" "m_or_y" "Useful for firewall/bridge filtering." -ModuleOk
$checks += New-Check "network" "NETFILTER_XT_MATCH_ADDRTYPE" "m_or_y" "Recommended for enhanced NAT support." -ModuleOk
$checks += New-Check "network" "NETFILTER_XT_TARGET_REJECT" "m_or_y" "Optional UFW support." -ModuleOk
$checks += New-Check "network" "NETFILTER_XT_TARGET_LOG" "m_or_y" "Optional UFW/logging support." -ModuleOk
$checks += New-Check "network" "NETFILTER_XT_MATCH_RECENT" "m_or_y" "Optional UFW/fail2ban support." -ModuleOk
$checks += New-Check "network" "IP_SET" "m_or_y" "Optional fail2ban support." -ModuleOk
$checks += New-Check "network" "IP_SET_HASH_IP" "m_or_y" "Optional fail2ban support." -ModuleOk
$checks += New-Check "network" "IP_SET_HASH_NET" "m_or_y" "Optional fail2ban support." -ModuleOk
$checks += New-Check "network" "NETFILTER_XT_SET" "m_or_y" "Optional fail2ban support." -ModuleOk

$checks += New-Check "do-not-add-first" "CGROUP_DEVICE" "avoid" "Not part of the current minimal GKI route; issue history links extra cgroup knobs with boot/crash risk." -DoNotNewlyEnable
$checks += New-Check "do-not-add-first" "CGROUP_PIDS" "avoid" "Not required by current Droidspaces GKI minimal route; do not add in the first experiment." -DoNotNewlyEnable

$summary = [pscustomobject]@{
    ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
    FailCount = ($checks | Where-Object { $_.Level -eq "fail" }).Count
    WarnCount = ($checks | Where-Object { $_.Level -eq "warn" }).Count
    CoreMissing = @($checks | Where-Object { $_.Group -eq "core" -and $_.Level -eq "fail" } | Select-Object -ExpandProperty Option)
    GeneratedAt = (Get-Date).ToString("s")
}

if ($Json) {
    [pscustomobject]@{
        Summary = $summary
        Checks = $checks
    } | ConvertTo-Json -Depth 5
    exit
}

Write-Host "Droidspaces kernel config analysis" -ForegroundColor Cyan
Write-Host "Config: $($summary.ConfigPath)"
Write-Host "Failures: $($summary.FailCount)  Warnings: $($summary.WarnCount)"
Write-Host ""

$checks |
    Sort-Object Group, Option |
    Format-Table Group, Option, Value, Expected, Level, Note -AutoSize

Write-Host ""
if ($summary.FailCount -gt 0) {
    Write-Host "Verdict: stock/custom config is missing core Droidspaces options." -ForegroundColor Red
    Write-Host "Missing core options: $($summary.CoreMissing -join ', ')"
    Write-Host "Do not flash anything yet. Compare with runtime droidspaces check and confirm the exact KMI branch first."
} else {
    Write-Host "Verdict: core build-time proxies are present." -ForegroundColor Green
    Write-Host "Next: run 'droidspaces check' on the device before deciding whether a custom kernel is needed."
}
