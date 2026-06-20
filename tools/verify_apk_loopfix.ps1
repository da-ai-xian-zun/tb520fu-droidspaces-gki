# Offline verify loopfix APK. No adb.
param([string]$Apk = "")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $Root "output\droidspaces-apk-loopfix\Droidspaces-loopfix-debug.apk" }
$Work = Join-Path $Root "output\droidspaces-apk-loopfix\verify_unpack"

if (-not (Test-Path $Apk)) { throw "APK not found: $Apk" }
if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$zip = Join-Path $Work "..\apk.zip"
Copy-Item -Force $Apk $zip
Expand-Archive -Path $zip -DestinationPath $Work -Force
Remove-Item -Force $zip

Write-Host "========== APK verify: $(Split-Path -Leaf $Apk) =========="
Write-Host "size: $((Get-Item $Apk).Length) bytes"
Write-Host "sha256: $((Get-FileHash $Apk -Algorithm SHA256).Hash)"

$sparsemgr = Get-ChildItem -Path $Work -Recurse -Filter "sparsemgr.sh" -ErrorAction SilentlyContinue | Select-Object -First 1
$fail = 0
$dsBin = Join-Path $Work "assets\binaries\droidspaces-aarch64"
if (Test-Path $dsBin) {
    Write-Host "[OK] droidspaces-aarch64: $((Get-Item $dsBin).Length) bytes"
} else {
    Write-Host "[FAIL] assets/binaries/droidspaces-aarch64 missing (App backend install will fail)"
    $fail = 1
}

Get-ChildItem -Path $Work -Recurse -Filter "*.sh" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $bytes = [IO.File]::ReadAllBytes($_.FullName)
    if ($bytes -contains 13) {
        Write-Host "[FAIL] CRLF in $($_.Name) — Android sh will break on set -eu"
        $fail = 1
    }
}
if ($fail -eq 0) {
    $shCount = (Get-ChildItem -Path $Work -Recurse -Filter "*.sh" -File).Count
    Write-Host "[OK] all $shCount APK shell scripts are LF-only"
}

if ($sparsemgr) {
    Write-Host "[OK] sparsemgr.sh: $($sparsemgr.FullName)"
    $content = Get-Content $sparsemgr.FullName -Raw
    if ($content -match "_mount_loop_img") { Write-Host "[OK] _mount_loop_img present" } else { Write-Host "[FAIL] _mount_loop_img missing"; $fail = 1 }
    if ($content -match "start=48|RESERVE_MIN=48|loop48") { Write-Host "[OK] high-minor loop scan referenced" } else { Write-Host "[FAIL] loop scan missing"; $fail = 1 }
} else {
    Write-Host "[FAIL] sparsemgr.sh not in APK"
    $fail = 1
}

$mountAsset = Get-ChildItem -Path $Work -Recurse -Filter "mount_loop_scan.sh" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mountAsset) { Write-Host "[OK] mount_loop_scan.sh in APK" }
else { Write-Host "[FAIL] mount_loop_scan.sh missing"; $fail = 1 }

$dex = Join-Path $Work "classes.dex"
if (Test-Path $dex) {
    Write-Host "[OK] classes.dex: $((Get-Item $dex).Length) bytes"
    $raw = [System.IO.File]::ReadAllBytes($dex)
    $ascii = [System.Text.Encoding]::ASCII.GetString($raw)
    if ($ascii -match "loop-scan loop48") { Write-Host "[OK] SparseImageInstaller log string in DEX" }
    else { Write-Host "[WARN] loop-scan log string not in DEX (non-fatal if mount_loop_scan.sh present)" }
}

Write-Host "========== RESULT: $(if ($fail -eq 0) { 'PASS' } else { 'FAIL' }) =========="
exit $fail