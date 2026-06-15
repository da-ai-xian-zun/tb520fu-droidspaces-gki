param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "",

    [Parameter(Mandatory = $false)]
    [string]$DroidspacesBin = "/data/local/Droidspaces/bin/droidspaces",

    [Parameter(Mandatory = $false)]
    [switch]$WithImageBackups
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path (Get-Location) "tb520fu-droidspaces-$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Save-Text {
    param(
        [string]$Name,
        [string[]]$Lines
    )
    $path = Join-Path $OutputDir $Name
    $Lines | Out-File -LiteralPath $path -Encoding UTF8
    return $path
}

function Run-Adb {
    param(
        [string]$Name,
        [string[]]$ToolArgs
    )
    $path = Join-Path $OutputDir $Name
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & adb @ToolArgs 2>&1 | ForEach-Object { $_.ToString() } | Out-File -LiteralPath $path -Encoding UTF8
        if ($LASTEXITCODE -ne 0) {
            "EXITCODE: $LASTEXITCODE" | Add-Content -LiteralPath $path -Encoding UTF8
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $path -Encoding UTF8
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    return $path
}

function Run-Tool {
    param(
        [string]$Name,
        [string]$Tool,
        [string[]]$ToolArgs
    )
    $path = Join-Path $OutputDir $Name
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Tool @ToolArgs 2>&1 | ForEach-Object { $_.ToString() } | Out-File -LiteralPath $path -Encoding UTF8
        if ($LASTEXITCODE -ne 0) {
            "EXITCODE: $LASTEXITCODE" | Add-Content -LiteralPath $path -Encoding UTF8
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $path -Encoding UTF8
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    return $path
}

function Run-AdbShell {
    param(
        [string]$Name,
        [string]$Command
    )
    Run-Adb $Name @("shell", $Command) | Out-Null
}

function Quote-ShSingle {
    param([string]$Value)
    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Run-AdbRootShell {
    param(
        [string]$Name,
        [string]$Command
    )
    $quoted = Quote-ShSingle $Command
    Run-Adb $Name @("shell", "su -c $quoted") | Out-Null
}

Write-Host "Collecting TB520FU/Droidspaces info into: $OutputDir" -ForegroundColor Cyan

Run-Tool "00-tool-adb-version.txt" "adb" @("version") | Out-Null
Run-Tool "00-tool-fastboot-version.txt" "fastboot" @("--version") | Out-Null
Run-Adb "00-adb-devices.txt" @("devices", "-l") | Out-Null
Run-Tool "00-fastboot-devices.txt" "fastboot" @("devices", "-l") | Out-Null

$deviceList = (& adb devices | Select-String -Pattern "`tdevice$").Count
$fastbootList = 0
try {
    $fastbootList = (& fastboot devices 2>$null | Where-Object { $_ -match "\S" }).Count
} catch {
    $fastbootList = 0
}

if ($deviceList -lt 1) {
    if ($fastbootList -gt 0) {
        Run-Tool "00-fastboot-getvar-all.txt" "fastboot" @("getvar", "all") | Out-Null
        Run-Tool "00-fastboot-current-slot.txt" "fastboot" @("getvar", "current-slot") | Out-Null
        Write-Warning "No adb device detected, but fastboot device was found. Captured fastboot getvar data only. Boot Android with USB debugging enabled for full Droidspaces/kernel collection."
        exit 4
    }
    Write-Warning "No adb or fastboot device detected. Connect the tablet with USB debugging enabled, then rerun this script."
    exit 2
}
if ($deviceList -gt 1) {
    Write-Warning "More than one adb device detected. Disconnect extras or set ANDROID_SERIAL before rerunning."
    exit 3
}

$props = @(
    "ro.product.model",
    "ro.product.device",
    "ro.product.name",
    "ro.product.board",
    "ro.hardware",
    "ro.board.platform",
    "ro.build.fingerprint",
    "ro.build.version.release",
    "ro.build.version.sdk",
    "ro.boot.slot_suffix",
    "ro.boot.verifiedbootstate",
    "ro.boot.vbmeta.device_state",
    "ro.boot.flash.locked",
    "ro.boot.bootloader"
)

$propCmd = ($props | ForEach-Object { "echo '--- $_'; getprop $_" }) -join "; "
Run-AdbShell "01-device-props.txt" $propCmd
Run-AdbShell "01b-all-props.txt" "getprop | sort"
Run-AdbShell "01c-ro-boot-props.txt" "getprop | grep '^\[ro\.boot\.' | sort"
Run-AdbShell "01d-slot-info.txt" "echo '--- bootctl'; bootctl get-number-slots 2>/dev/null; bootctl get-current-slot 2>/dev/null; echo '--- props'; getprop ro.boot.slot_suffix; getprop ro.boot.slot; getprop ro.boot.slot_index"
Run-AdbShell "02-uname-version.txt" "uname -a; echo '--- /proc/version'; cat /proc/version"
Run-AdbRootShell "02b-proc-cmdline.txt" "cat /proc/cmdline 2>/dev/null || true"
Run-AdbRootShell "03-root-id.txt" "id; whoami 2>/dev/null || true"
Run-AdbRootShell "04-proc-filesystems.txt" "cat /proc/filesystems"
Run-AdbRootShell "05-proc-cgroups.txt" "cat /proc/cgroups 2>/dev/null || true"
Run-AdbRootShell "06-namespaces.txt" "ls -l /proc/self/ns; echo '--- init ns'; ls -l /proc/1/ns 2>/dev/null || true"
Run-AdbRootShell "07-block-by-name.txt" "ls -l /dev/block/by-name 2>/dev/null || find /dev/block -maxdepth 3 -type l 2>/dev/null"
Run-AdbRootShell "08-mountinfo-cgroup.txt" "cat /proc/self/mountinfo | grep -E 'cgroup|cg2|/sys/fs/cgroup' || true"
Run-AdbRootShell "08b-mounts.txt" "mount"
Run-AdbRootShell "08c-sys-fs-cgroup.txt" "find /sys/fs/cgroup -maxdepth 3 -type d 2>/dev/null | sort | head -300"
Run-AdbRootShell "08d-selinux-root-stack.txt" "echo '--- SELinux'; getenforce 2>/dev/null || true; echo '--- uname -r'; uname -r; echo '--- root binaries'; command -v magisk 2>/dev/null || true; magisk -v 2>/dev/null || true; command -v ksud 2>/dev/null || true; ksud -V 2>/dev/null || true; command -v apd 2>/dev/null || true; apd -V 2>/dev/null || true"
Run-AdbRootShell "08e-kernel-modules.txt" "echo '--- /proc/modules'; cat /proc/modules 2>/dev/null || true; echo '--- /sys/module sample'; ls -1 /sys/module 2>/dev/null | sort | head -500"

Write-Host "Pulling /proc/config.gz via root shell..."
$configPath = Join-Path $OutputDir "stock_config.txt"
try {
    & adb shell su -c "zcat /proc/config.gz" 2>&1 | Out-File -LiteralPath $configPath -Encoding UTF8
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File -LiteralPath $configPath -Encoding UTF8
}

Run-AdbRootShell "09-droidspaces-version.txt" "'$DroidspacesBin' --version 2>/dev/null || '$DroidspacesBin' version 2>/dev/null || true"
Run-AdbRootShell "09-droidspaces-check.txt" "'$DroidspacesBin' check"

$analyzer = Join-Path $PSScriptRoot "analyze_droidspaces_config.ps1"
if ((Test-Path -LiteralPath $analyzer) -and (Test-Path -LiteralPath $configPath)) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $analyzer -ConfigPath $configPath 2>&1 |
            Out-File -LiteralPath (Join-Path $OutputDir "10-config-analysis.txt") -Encoding UTF8
        & powershell -NoProfile -ExecutionPolicy Bypass -File $analyzer -ConfigPath $configPath -Json 2>&1 |
            Out-File -LiteralPath (Join-Path $OutputDir "10-config-analysis.json") -Encoding UTF8
    } catch {
        "ERROR: $($_.Exception.Message)" |
            Out-File -LiteralPath (Join-Path $OutputDir "10-config-analysis.txt") -Encoding UTF8
    }
}

if ($WithImageBackups) {
    $imagesDir = Join-Path $OutputDir "images"
    New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null

    $parts = @(
        "boot_a", "boot_b",
        "init_boot_a", "init_boot_b",
        "vendor_boot_a", "vendor_boot_b",
        "vbmeta_a", "vbmeta_b",
        "vbmeta_system_a", "vbmeta_system_b",
        "dtbo_a", "dtbo_b"
    )

    foreach ($part in $parts) {
        Write-Host "Backing up partition if present: $part"
        $remote = "/sdcard/$part.img"
        $cmd = "if [ -e /dev/block/by-name/$part ]; then dd if=/dev/block/by-name/$part of=$remote bs=4M; ls -l $remote; else echo 'missing $part'; fi"
        Run-AdbRootShell "backup-$part.txt" $cmd
        Run-Adb "pull-$part.txt" @("pull", $remote, (Join-Path $imagesDir "$part.img")) | Out-Null
    }

    Get-ChildItem -LiteralPath $imagesDir -Filter "*.img" -File |
        Get-FileHash -Algorithm SHA256 |
        Sort-Object Path |
        Format-Table Algorithm, Hash, Path -AutoSize |
        Out-File -LiteralPath (Join-Path $OutputDir "images-sha256.txt") -Encoding UTF8
}

Save-Text "README.txt" @(
    "TB520FU Droidspaces collection",
    "Generated: $(Get-Date -Format s)",
    "",
    "Key files:",
    "- stock_config.txt: kernel config if /proc/config.gz was available",
    "- 09-droidspaces-check.txt: Droidspaces runtime requirements check",
    "- 10-config-analysis.txt: offline config verdict",
    "- 00-fastboot-getvar-all.txt: present only if the script saw fastboot instead of adb",
    "- images-sha256.txt: local image hashes if -WithImageBackups was used",
    "",
    "No flashing was performed by default.",
    "If -WithImageBackups was used, boot/vbmeta images were only read and pulled."
) | Out-Null

Write-Host "Done. Output: $OutputDir" -ForegroundColor Green
