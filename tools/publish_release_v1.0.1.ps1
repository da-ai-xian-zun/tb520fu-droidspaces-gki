# Publish GitHub Release v1.0.1 (loopfix APK). Requires: gh auth login
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Notes = Join-Path $Root "release\RELEASE_NOTES-v1.0.1-apk.md"
$Apk = Join-Path $Root "release\Droidspaces-loopfix-tb520fu.apk"
$Sums = Join-Path $Root "release\SHA256SUMS-apk.txt"
$Readme = Join-Path $Root "release\APK-README.txt"

if (-not (Test-Path $Apk)) {
    $src = Join-Path $Root "output\droidspaces-apk-loopfix\Droidspaces-loopfix-debug.apk"
    if (-not (Test-Path $src)) { throw "APK missing: $Apk and $src" }
    Copy-Item -Force $src $Apk
}

gh auth status | Out-Null
gh release view v1.0.1 --repo da-ai-xian-zun/tb520fu-droidspaces-gki 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[*] Release v1.0.1 exists; uploading assets..."
    gh release upload v1.0.1 $Apk $Sums $Readme --repo da-ai-xian-zun/tb520fu-droidspaces-gki --clobber
} else {
    gh release create v1.0.1 `
        --repo da-ai-xian-zun/tb520fu-droidspaces-gki `
        --title "v1.0.1 - Droidspaces loopfix APK (TB520FU)" `
        --notes-file $Notes `
        $Apk $Sums $Readme
}
Write-Host "[+] Done: https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/releases/tag/v1.0.1"