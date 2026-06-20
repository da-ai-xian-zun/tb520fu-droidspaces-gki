# Build Droidspaces loopfix debug APK (Windows). No adb.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Android = Join-Path $Root "vendor\Droidspaces-OSS\Android"
$OutDir = Join-Path $Root "output\droidspaces-apk-loopfix"
$Jbr = "C:\Program Files\Android\Android Studio\jbr\bin\java.exe"
$Sdk = "$env:LOCALAPPDATA\Android\Sdk"

if (-not (Test-Path $Jbr)) { throw "JBR not found: $Jbr" }
if (-not (Test-Path $Sdk)) { throw "Android SDK not found: $Sdk" }

$localProps = Join-Path $Android "local.properties"
"sdk.dir=$($Sdk -replace '\\','\\')" | Set-Content -Encoding ASCII $localProps

function Assert-ShLfLineEndings {
    param([string]$AssetsDir)
    $bad = @()
    Get-ChildItem -Path $AssetsDir -Filter "*.sh" -Recurse -File | ForEach-Object {
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        if ($bytes -contains 13) {
            $rel = $_.FullName.Substring($AssetsDir.Length).TrimStart('\')
            $bad += $rel
        }
    }
    if ($bad.Count -gt 0) {
        throw "CRLF in shell assets breaks Android sh (set -eu fails). LF-only: $($bad -join ', ')"
    }
    Write-Host "[OK] asset *.sh are LF-only ($((Get-ChildItem -Path $AssetsDir -Filter '*.sh' -Recurse -File).Count) files)"
}

$assetsRoot = Join-Path $Android "app\src\main\assets"
Assert-ShLfLineEndings $assetsRoot

$sparsemgr = Join-Path $Android "app\src\main\assets\sparsemgr.sh"
if (-not (Select-String -Path $sparsemgr -Pattern "_mount_loop_img" -Quiet)) {
    throw "sparsemgr.sh missing _mount_loop_img — run: git apply patches/sparsemgr-loop-scan.patch"
}
$mountScript = Join-Path $Android "app\src\main\assets\mount_loop_scan.sh"
if (-not (Test-Path $mountScript)) {
    throw "mount_loop_scan.sh missing in assets"
}
$installer = Join-Path $Android "app\src\main\java\com\droidspaces\app\util\SparseImageInstaller.kt"
if (-not (Select-String -Path $installer -Pattern "mount_loop_scan.sh" -Quiet)) {
    throw "SparseImageInstaller.kt missing mount_loop_scan.sh hook"
}

$assetsBin = Join-Path $Android "app\src\main\assets\binaries"
New-Item -ItemType Directory -Force -Path $assetsBin | Out-Null
$loopfix = Join-Path $Root "output\droidspaces-loopfix\droidspaces-aarch64-loopfix"
if (-not (Test-Path $loopfix)) {
    throw "Build CLI first: bash tools/build_droidspaces_loopfix.sh → $loopfix"
}
Copy-Item -Force $loopfix (Join-Path $assetsBin "droidspaces-aarch64")
Write-Host "[*] Bundled droidspaces-aarch64: $((Get-Item (Join-Path $assetsBin 'droidspaces-aarch64')).Length) bytes"

Push-Location $Android
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
& $Jbr -version
& $Jbr -classpath "gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain assembleDebug --no-daemon
Pop-Location

$apkSrc = Join-Path $Android "app\build\outputs\apk\debug\app-debug.apk"
if (-not (Test-Path $apkSrc)) { throw "Build failed: no app-debug.apk" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$apkDst = Join-Path $OutDir "Droidspaces-loopfix-debug.apk"
Copy-Item -Force $apkSrc $apkDst
$hash = Get-FileHash $apkDst -Algorithm SHA256
"$($hash.Hash)  Droidspaces-loopfix-debug.apk" | Set-Content (Join-Path $OutDir "SHA256SUMS")
Write-Host "[+] APK: $apkDst ($((Get-Item $apkDst).Length) bytes)"
Write-Host "[+] SHA256: $($hash.Hash)"