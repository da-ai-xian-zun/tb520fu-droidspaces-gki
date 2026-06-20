# Droidspaces-OSS patches (TB520FU sparse / loop research)

Patches in this directory are meant for upstream submission or local rebuild. They are **not** applied automatically by this repo's build scripts unless you run the matching `tools/build_*.sh` script.

## Base revision

| Patch | Target path | Base commit (when generated) |
|-------|-------------|------------------------------|
| `droidspaces-android-loop-scan.patch` | `src/mount.c` | [`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5) (`main`, regen 2026-06-20) |
| `sparsemgr-loop-scan.patch` | `Android/app/src/main/assets/sparsemgr.sh` | same |
| `sparseimageinstaller-loop-scan.patch` | `SparseImageInstaller.kt` + `assets/mount_loop_scan.sh` | same |
| `sparseimageinstaller-unmount-after-config.patch` | `ContainerInstaller.kt` (umount after config write) | same |
| `mount_loop_scan.sh` | canonical copy of asset script (included in patch above) | — |

Upstream docs reference **v6.3.0+** behavior; verify `git describe` on your clone before opening a PR.

## Apply locally

```bash
git clone https://github.com/ravindu644/Droidspaces-OSS.git vendor/Droidspaces-OSS
cd vendor/Droidspaces-OSS
git checkout 76cbd21   # or current main if patch still applies
git apply ../../patches/droidspaces-android-loop-scan.patch
# optional App/migrate path:
git apply ../../patches/sparsemgr-loop-scan.patch
git apply ../../patches/sparseimageinstaller-loop-scan.patch
git apply ../../patches/sparseimageinstaller-unmount-after-config.patch
```

Refresh from vendor: `bash tools/apply_loopfix_vendor.sh` (WSL; regenerates all patches + `git apply --check` on `76cbd21`).

**Mount strategy (upstream-first):** try stock **busybox / system `mount -o loop`** first (same order as upstream `SparseImageInstaller.kt` / `sparsemgr.sh`); only on failure fall back to **high-minor `losetup` scan** with relative floor `max(0, max_loop - max(16, max_loop/4))` and dynamic `max(sysfs, /sys/block/loopN+1)`. **No OEM model branching.**

Regenerate patches after editing sources: `python tools/apply_loopfix_vendor.py` then regen script in `tools/regen_patches.sh` (or the Python block in maintainer notes — vendor tree at `vendor/Droidspaces-OSS`).

**Line endings (critical on Windows):** all `*.sh` assets and `patches/*.sh` must be **LF-only**. CRLF breaks Android `sh` at `set -eu` (`set: -: unknown option`) and makes App sparse install fail instantly. Repo root `.gitattributes` sets `*.sh text eol=lf`; `build_droidspaces_apk_loopfix.ps1` / `.sh` refuse CRLF before Gradle.

**Install-order fix (separate PR):** `sparseimageinstaller-loop-scan.patch` includes full `SparseImageInstaller.kt` delta (mount hook + deferred umount helpers). `sparseimageinstaller-unmount-after-config.patch` adds the `ContainerInstaller.kt` caller. Umount runs **after** `container.config` is written; no blocking pre-umount `sync`.

## Build loopfix APK (local, no adb)

```powershell
powershell -File tools/build_droidspaces_apk_loopfix.ps1
powershell -File tools/verify_apk_loopfix.ps1
```

Output: `output/droidspaces-apk-loopfix/Droidspaces-loopfix-debug.apk`

## Build loopfix binary

```bash
bash tools/build_droidspaces_loopfix.sh
# → output/droidspaces-loopfix/droidspaces-aarch64-loopfix (gitignored)
```

## CLI vs App：补丁分工

| 补丁 | 改什么 | 谁用 |
|------|--------|------|
| `droidspaces-android-loop-scan.patch` | **仅** `src/mount.c`（`droidspaces` CLI 二进制） | `droidspaces start/stop`、`--rootfs-img` |
| `sparsemgr-loop-scan.patch` | `assets/sparsemgr.sh` | App 迁移/resize |
| `sparseimageinstaller-loop-scan.patch` | `SparseImageInstaller.kt` + `mount_loop_scan.sh` | App 新建 sparse |
| `sparseimageinstaller-unmount-after-config.patch` | `ContainerInstaller.kt` | App 安装收尾顺序 |

**CLI 只动一个 C 文件**；App 侧是 shell + Kotlin，与 CLI 二进制无关。魔改 APK 构建时会把编好的 CLI 拷进 `assets/binaries/droidspaces-aarch64`，但**设备上已有同体积旧 loopfix 时 APK 覆盖安装未必替换** `/data/local/Droidspaces/bin/droidspaces`（见下）。

## 装 APK 后必查 CLI 指纹（尤其一加）

loopfix 与 stock 靠**体积**区分（410168 vs 461544）；**两版 loopfix 同为 410168 B 时 `apply-loopfix.sh` 不会自动升级**。

```bash
adb push output/droidspaces-loopfix/droidspaces-aarch64-loopfix /data/local/tmp/droidspaces-loopfix
adb push tools/install_loopfix_persistent.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/install_loopfix_persistent.sh /data/local/tmp/droidspaces-loopfix'
adb shell su -c 'sha256sum /data/local/Droidspaces/bin/droidspaces'
# 当前构建应为 e0a80f9c1287c5e67e796379dfa94db7594d5f3970fe7e96a2884363b5c4584d
```

旧构建 `849250a4…` 在一加（sysfs `max_loop=16`、实际 bound≈50+）上会导致 `Failed to attach … any free loop device`。