param(
    [Parameter(Mandatory = $false)]
    [string]$ImageDir = "",

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ImageDir)) {
    $latest = Get-ChildItem -Directory -Filter "tb520fu-droidspaces-*" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latest) {
        $candidate = Join-Path $latest.FullName "images"
        if (Test-Path -LiteralPath $candidate) {
            $ImageDir = $candidate
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ImageDir) -or -not (Test-Path -LiteralPath $ImageDir)) {
    throw "ImageDir not found. Pass -ImageDir .\tb520fu-droidspaces-...\images after running collect_tb520fu_droidspaces_info.ps1 -WithImageBackups."
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = $ImageDir
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Read-U32BE {
    param([byte[]]$Bytes, [int]$Offset)
    return ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
}

function Read-U64BE {
    param([byte[]]$Bytes, [int]$Offset)
    $v = [uint64]0
    for ($i = 0; $i -lt 8; $i++) {
        $v = ($v -shl 8) -bor [uint64]$Bytes[$Offset + $i]
    }
    return $v
}

function Get-AlgorithmName {
    param([uint32]$AlgorithmType)
    switch ($AlgorithmType) {
        0 { "NONE" }
        1 { "SHA256_RSA2048" }
        2 { "SHA256_RSA4096" }
        3 { "SHA256_RSA8192" }
        4 { "SHA512_RSA2048" }
        5 { "SHA512_RSA4096" }
        6 { "SHA512_RSA8192" }
        default { "UNKNOWN_$AlgorithmType" }
    }
}

function Convert-BytesToHex {
    param([byte[]]$Bytes)
    return (($Bytes | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Find-LinuxVersion {
    param([string]$Path)

    $data = [System.IO.File]::ReadAllBytes($Path)
    $marker = [System.Text.Encoding]::ASCII.GetBytes("Linux version ")
    for ($i = 0; $i -le $data.Length - $marker.Length; $i++) {
        $hit = $true
        for ($j = 0; $j -lt $marker.Length; $j++) {
            if ($data[$i + $j] -ne $marker[$j]) {
                $hit = $false
                break
            }
        }
        if ($hit) {
            $start = $i + $marker.Length
            $chars = New-Object System.Collections.Generic.List[char]
            for ($k = $start; $k -lt [Math]::Min($data.Length, $start + 80); $k++) {
                $c = [char]$data[$k]
                if (($c -ge '0' -and $c -le '9') -or $c -eq '.') {
                    $chars.Add($c)
                } else {
                    break
                }
            }
            $version = -join $chars
            if (($version.ToCharArray() | Where-Object { $_ -eq '.' }).Count -ge 2) {
                return $version
            }
        }
    }
    return ""
}

function Read-AvbInfo {
    param([string]$Path)

    $data = [System.IO.File]::ReadAllBytes($Path)
    if ($data.Length -lt 256) {
        return $null
    }

    $vbmetaOffset = [uint64]0
    $vbmetaSize = [uint64]0
    $hasFooter = $false
    $footerOriginalSize = [uint64]0

    $firstMagic = [System.Text.Encoding]::ASCII.GetString($data, 0, 4)
    if ($firstMagic -eq "AVB0") {
        $vbmetaOffset = 0
        $vbmetaSize = [uint64]$data.Length
    } elseif ($data.Length -ge 64) {
        $footerOffset = $data.Length - 64
        $footerMagic = [System.Text.Encoding]::ASCII.GetString($data, $footerOffset, 4)
        if ($footerMagic -eq "AVBf") {
            $hasFooter = $true
            $footerOriginalSize = Read-U64BE $data ($footerOffset + 12)
            $vbmetaOffset = Read-U64BE $data ($footerOffset + 20)
            $vbmetaSize = Read-U64BE $data ($footerOffset + 28)
        } else {
            return $null
        }
    } else {
        return $null
    }

    if ($vbmetaOffset + 256 -gt $data.Length) {
        return [pscustomobject]@{
            HasAvb = $true
            AvbError = "vbmeta offset outside image"
        }
    }

    $magic = [System.Text.Encoding]::ASCII.GetString($data, [int]$vbmetaOffset, 4)
    if ($magic -ne "AVB0") {
        return [pscustomobject]@{
            HasAvb = $true
            HasFooter = $hasFooter
            AvbError = "AVB footer exists but vbmeta header not found"
            VbmetaOffset = $vbmetaOffset
            VbmetaSize = $vbmetaSize
        }
    }

    $base = [int]$vbmetaOffset
    $authSize = Read-U64BE $data ($base + 12)
    $auxSize = Read-U64BE $data ($base + 20)
    $algorithmType = Read-U32BE $data ($base + 28)
    $publicKeyOffset = Read-U64BE $data ($base + 64)
    $publicKeySize = Read-U64BE $data ($base + 72)
    $descriptorsSize = Read-U64BE $data ($base + 104)
    $rollbackIndex = Read-U64BE $data ($base + 112)
    $flags = Read-U32BE $data ($base + 120)
    $rollbackLocation = Read-U32BE $data ($base + 124)
    $releaseRaw = $data[($base + 128)..($base + 175)]
    $releaseString = [System.Text.Encoding]::ASCII.GetString($releaseRaw).Trim([char]0).Trim()

    $publicKeySha1 = ""
    $auxStart = $base + 256 + [int]$authSize
    if ($publicKeySize -gt 0 -and $auxStart + [int]$publicKeyOffset + [int]$publicKeySize -le $data.Length) {
        $pkStart = $auxStart + [int]$publicKeyOffset
        $pk = New-Object byte[] ([int]$publicKeySize)
        [Array]::Copy($data, $pkStart, $pk, 0, [int]$publicKeySize)
        $sha1 = [System.Security.Cryptography.SHA1]::Create()
        $publicKeySha1 = Convert-BytesToHex ($sha1.ComputeHash($pk))
    }

    return [pscustomobject]@{
        HasAvb = $true
        HasFooter = $hasFooter
        AvbError = ""
        Algorithm = Get-AlgorithmName $algorithmType
        RollbackIndex = $rollbackIndex
        RollbackIndexLocation = $rollbackLocation
        Flags = $flags
        PublicKeySha1 = $publicKeySha1
        ReleaseString = $releaseString
        VbmetaOffset = $vbmetaOffset
        VbmetaSize = $vbmetaSize
        AuthBlockSize = $authSize
        AuxBlockSize = $auxSize
        DescriptorsSize = $descriptorsSize
        OriginalImageSize = $footerOriginalSize
    }
}

$images = Get-ChildItem -LiteralPath $ImageDir -Filter "*.img" -File | Sort-Object Name
if ($images.Count -eq 0) {
    throw "No .img files found in $ImageDir"
}

$rows = foreach ($img in $images) {
    $hash = Get-FileHash -LiteralPath $img.FullName -Algorithm SHA256
    $avb = Read-AvbInfo $img.FullName
    $linux = ""
    if ($img.Name -match "boot") {
        $linux = Find-LinuxVersion $img.FullName
    }

    [pscustomobject]@{
        Image = $img.Name
        Size = $img.Length
        SHA256 = $hash.Hash
        LinuxVersion = $linux
        HasAvb = [bool]$avb
        HasFooter = if ($avb) { $avb.HasFooter } else { "" }
        Algorithm = if ($avb) { $avb.Algorithm } else { "" }
        RollbackIndex = if ($avb) { $avb.RollbackIndex } else { "" }
        RollbackIndexLocation = if ($avb) { $avb.RollbackIndexLocation } else { "" }
        Flags = if ($avb) { $avb.Flags } else { "" }
        PublicKeySha1 = if ($avb) { $avb.PublicKeySha1 } else { "" }
        ReleaseString = if ($avb) { $avb.ReleaseString } else { "" }
        AvbError = if ($avb) { $avb.AvbError } else { "" }
    }
}

$summaryPath = Join-Path $OutputDir "image-summary.txt"
$rows | Format-Table -AutoSize | Out-File -LiteralPath $summaryPath -Encoding UTF8
$rows | ConvertTo-Json -Depth 4 | Out-File -LiteralPath (Join-Path $OutputDir "image-summary.json") -Encoding UTF8

$avbtool = Get-Command avbtool -ErrorAction SilentlyContinue
if ($avbtool) {
    $avbDir = Join-Path $OutputDir "avbtool-info"
    New-Item -ItemType Directory -Force -Path $avbDir | Out-Null
    foreach ($img in $images) {
        & avbtool info_image --image $img.FullName 2>&1 |
            Out-File -LiteralPath (Join-Path $avbDir "$($img.BaseName).txt") -Encoding UTF8
    }
} else {
    "avbtool not found in PATH. The built-in parser only reports header/footer summary; use LTBox Advanced AVB info or install avbtool for full descriptor output." |
        Out-File -LiteralPath (Join-Path $OutputDir "avbtool-info.txt") -Encoding UTF8
}

Write-Host "Wrote image summary: $summaryPath" -ForegroundColor Green
