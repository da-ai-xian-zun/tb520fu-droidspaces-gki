# Droidspaces-OSS 上游 Issue / PR 草稿

> **⚠️ 归档 / 证据库**：对外 GitHub 提交请用 **[`UPSTREAM-SUBMISSION-SAMPLE.md`](UPSTREAM-SUBMISSION-SAMPLE.md)**（单 Issue + 单 PR）。本文件保留更全的跨机型表、双 Issue 草案与验证清单，供复核 agent 查阅，**不要与 SAMPLE 并行执行**。  
> 目的：在实机数据齐全、措辞保守的前提下向上游报告 sparse 挂载问题，**避免**把 OEM loop 池配置、自编内核、或自评 Partial 误写成「上游/联想独毒」。  
> 专档：[`SPARSE-MOUNT-RESEARCH.md`](SPARSE-MOUNT-RESEARCH.md)  
> 补丁：[`patches/`](../patches/)  
> 采集：`tools/sparse_issue_bundle.sh`（只读）、`tools/sparse_cli_app_compare.sh`（会改 loop，仅测试机）

---

## 1. 建议拆成两条 Issue（或 1 issue + 2 PR）

| ID | 范围 | 标题草案 |
|----|------|----------|
| **A** | Android App 安装器 | `Android: SparseImageInstaller busybox mount -o loop fails on loop-heavy devices (APEX)` |
| **B** | Linux CLI `mount.c` | `Android: CLI loop auto-alloc via LOOP_CTL_GET_FREE unreliable when pool is dirty; scan high minors` |

**不要合并成一条「kernel doesn't support loop」**——我们已有证据表明 **显式 `losetup` + `mount` 成功**，内核并非不支持 loop。

---

## 2. Issue A 正文（英文，可直接贴 GitHub）

### Summary

On some Android 16 GKI devices with a **tight or heavily used loop pool** (APEX + OEM modules), **creating a new container via the App's Sparse Image installer always fails**, even immediately after a clean reboot. The failure is **not** reproduced when using explicit `losetup` on a high minor (`loop48+`) followed by `mount`.

### Environment

- **Primary device**: Lenovo TB520FU (Yoga Tab Plus), ROW ZUI 17.5.10.096, **Android 16 / SDK 36**
- **Kernel**: custom GKI phase-2 with `max_loop=64` in cmdline (stock Lenovo ROM used `max_loop=48`)
- **Root**: KernelSU (SukiSU) on `init_boot`
- **Droidspaces**: stock App from Play/GitHub release (v6.3.x era)
- **Cross-check (read-only, no Droidspaces installed)**: OnePlus Ace 5 Pro PKR110, ColorOS 16 — also **53/53 loops bound** (dynamic pool expansion); shows high loop usage is **not Lenovo-specific**

### Steps to reproduce

1. Install Droidspaces App + CLI on a loop-heavy Android 16 device (APEX ~40–47 loops in use).
2. In App, create a new container using **Sparse Image** (default 4GB).
3. Observe mount step failure.

### Expected

Sparse image mounts and tarball extracts (as documented in Installation-Android.md).

### Actual

App log:

```text
[SPARSE] Mounting sparse image (Minimal loop,rw)...
Failed to mount sparse image. Your kernel might not support loop mounts here.
```

ADB equivalent:

```bash
busybox mount -t ext4 -o loop,rw,... /path/rootfs.img /mnt
# → can't setup loop device: No such file or directory
```

### What works on the same device (same boot session)

| Path | Result after clean reboot |
|------|---------------------------|
| `toybox mount -o loop` | ✅ |
| `droidspaces --rootfs-img` (stock CLI) | ✅ |
| `losetup /dev/block/loop48 IMG && mount` | ✅ |
| **App / busybox `mount -o loop`** | ❌ **always** |

After stress (repeated container stop/start without reboot), stock CLI may fail with `LOOP_SET_FD: Resource busy` until reboot — **separate bug (Issue B)**.

### Root cause (our analysis)

`SparseImageInstaller.kt` uses:

```kotlin
"${Constants.BUSYBOX_BINARY_PATH} mount -t ext4 -o loop,... \"$imgPath\" \"$mountPoint\""
```

Busybox's `mount -o loop` auto-allocation does not reliably pick a free high minor when low minors are occupied by APEX. **This is independent of KSU modules** (we bisected modules; App path still fails with all modules enabled after reboot).

### Proposed fix

**Upstream-first, Android-universal fallback** (no OEM / model branching):

1. Keep existing **busybox → system `mount -o loop`** order (unchanged happy path on devices where it works).
2. On failure only, fall back to **high-minor explicit `losetup` scan** (`loop48+`, dynamic pool aware via `/proc/loops`).

Draft patches:

- [`patches/sparsemgr-loop-scan.patch`](../patches/sparsemgr-loop-scan.patch) — `_mount_loop_img` for migrate/resize
- [`patches/sparseimageinstaller-loop-scan.patch`](../patches/sparseimageinstaller-loop-scan.patch) — `mount_loop_scan.sh` asset + Kotlin caller
- [`patches/mount_loop_scan.sh`](../patches/mount_loop_scan.sh) — canonical script copy

Local debug APK (4-patch stack on `76cbd21`) **E2E verified on TB520FU** (`tools/build_droidspaces_apk_loopfix.ps1`): manual App sparse install, `post_apk_e2e_check.sh` (ping/curl, 3× stop/start), and `full_apk_sparse_install_e2e.sh` (simulated full install path). **Lenovo tablet status: OK** (2026-06-20). Cross-device pending.

**Packaging / installer notes (local fixes, suggest upstream):**

1. **Shell assets must be LF-only** — CRLF in `mount_loop_scan.sh` breaks `set -eu` on Android `sh` before any mount attempt.
2. **`SparseImageInstaller` should write `container.config` before unmount** — pre-umount `busybox sync` while the sparse mount is still active can hang 30+ minutes on some devices; umount should not run in `extract()` `finally` on the success path.
3. **Loop detach** — `/proc/loops` may be empty; use `losetup -a | grep <img>` instead of awk on `/proc/loops`.

### Attachments

- `sparse_issue_bundle.txt` from `tools/sparse_issue_bundle.sh`
- Optional: `sparse_cli_app_compare.sh` output on a **test** device

### Cross-device reproduction (stock Droidspaces v6.3.0 busybox, 2026-06-21)

| Device | Droidspaces `busybox mount -o loop` | toybox (same session) |
|--------|-------------------------------------|------------------------|
| Lenovo TB520FU (phase-2 GKI) | ❌ `can't setup loop device` | ✅ after reboot |
| Xiaomi 12S Ultra (stock 5.10) | ❌ **same error** | ✅ |
| OnePlus Ace 5 Pro PKR110 (stock 6.6.89) | ❌ **same error** | ✅ |
| OnePlus Ace 5 Pro PKR110 (`6.6.89-Gold_bug` DS 内核) | ❌ **still same** | ✅ |

`setenforce 0` does **not** change busybox outcome on any of the three (see `tools/sparse_selinux_loop_test.sh`).

### What we are **not** claiming

- ❌ "Lenovo hardware is broken"
- ❌ "Custom kernel miscompiled loop" (phase-2 shows `max_loop=64`, manual loop works)
- ❌ "Only TB520FU" (Xiaomi + OnePlus reproduce **same busybox error**)
- ❌ "SELinux enforcing blocks loop mount" (permissive tested; toybox works)

---

## 3. Issue B 正文（英文）

### Summary

The CLI path for `--rootfs-img` uses `ioctl(LOOP_CTL_GET_FREE)` (see `mount.c`). On Android with APEX occupying low loop minors, this often returns slots that still fail `LOOP_SET_FD` with **EBUSY** after repeated container stop/start cycles. A full reboot clears the state; **scanning high minors** (as `losetup /dev/block/loop48` does) remains reliable.

### Reproduce (CLI)

1. Migrate or create a sparse container via CLI (`--rootfs-img`).
2. Run 8–20 cycles: `droidspaces stop` → `droidspaces start` **without** rebooting.
3. Stock CLI may fail: `LOOP_SET_FD: Resource busy` / loop setup errors.
4. After reboot, same CLI succeeds until pool gets dirty again.

### Verified fix (local)

Patch [`patches/droidspaces-android-loop-scan.patch`](../patches/droidspaces-android-loop-scan.patch): scan from `max_loop-1` down to `DS_ANDROID_LOOP_RESERVE_MIN` (48), verify freeness via `LOOP_GET_STATUS64`, attach with `LOOP_SET_FD`.

| Binary | Size (bytes) | SHA256 (example build) |
|--------|--------------|------------------------|
| stock CLI | 461544 | `3538a2b7a174efaa1c9295617c2764adba01c1594254949437d2fa52ab69b5df` |
| loopfix CLI | 410168 | `e0a80f9c1287c5e67e796379dfa94db7594d5f3970fe7e96a2884363b5c4584d` |

Build: `tools/build_droidspaces_loopfix.sh` (base commit in [`patches/README.md`](../patches/README.md)).

### Offer

Happy to open a PR for `mount.c` if maintainers agree with high-minor scan on Android only.

---

## 4. 提 Issue 前验证清单

| # | 项 | 状态 | 备注 |
|---|-----|------|------|
| 1 | 干净重启后 App busybox 仍失败 | ✅ | TB520FU 重启后仍失败（§5.7） |
| 2 | 同会话 toybox / CLI / 手动 losetup 成功 | ✅ | §5.1 / §5.7 |
| 3 | KSU 模块逐一隔离后 App 仍失败 | ✅ | §6 |
| 4 | loopfix 8–20 轮 stop/start 无需 reboot | ✅ | §5.4 |
| 5 | phase-2 `max_loop=64` 实机可读 | ✅ | §12.2 |
| 6 | 跨机型 loop + busybox 复现 | ✅ | 小米/一加/Pixel 见专档 §5.5、§12 |
| 7 | stock vs loopfix 体积 + sha256 | ✅ | 见 Issue B 表 + `output/sparse-precheck/` |
| 8 | 补丁 `git apply --check` on upstream `main` | ✅ | `76cbd21` |
| 9 | **stock** CLI 脏池（#9） | **PKR110 ✅** / thor ⏳ | PKR110：`Gold_bug` + stock CLI 461544，`loop_stress_named.sh test 10` → 10/10；thor 仍缺社区内核 |
| 10 | SELinux permissive 不改变 busybox | ✅ | §5.6；三台 OEM |
| 11 | `strace` busybox vs losetup | 可选 | 未做 |
| 12 | 社区设备表 TB520FU 备注 | 本地 | 非 issue 前置 |

---

## 5. 还可做的工作（提 issue 前/后）

| 优先级 | 动作 |
|--------|------|
| P0 | bundle + compare 原始日志 | ✅ `output/sparse-precheck/` |
| P0 | `git apply --check` 两枚 patch | ✅ |
| P1 | **直接提 PR（CLI）** 往往比只开 issue 更快；App 路径需改 Kotlin + `sparsemgr.sh` |
| P1 | 在 issue 中 @ 维护者并链接 PR #207，说明 Partial 是历史自评、现况已有 loopfix + migrate 路径 |
| P2 | 2–3 轮 `apt update` 中位数 benchmark 附性能段（Issue 可选，#main 是 mount） |
| — | `sparsemgr` + `SparseImageInstaller` 打进魔改 APK，TB520FU 验证 App 新建 sparse + 启停 | ✅ §5.4.1–§5.4.2；跨机型 ⏳ |
| — | CRLF 门禁 + 安装器先写 config 再 umount | ✅ 本地 vendor；建议上游 |
| P3 | phase-3 `max_loop=128` — **不保证**修 App busybox 路径 |

---

## 6. 措辞红线（避免贻笑大方）

| 避免写 | 应写 |
|--------|------|
| "Kernel doesn't support loop" | "Auto loop allocation fails; explicit losetup works" |
| "Lenovo bug / 联想独毒" | "OEM loop pool sizing + APEX occupancy; similar on other A16 devices" |
| "Partial proves device is broken" | "Partial was submitter's label in PR #207; sparse CLI path now works with workaround" |
| "Our GKI broke loop" | "phase-2 max_loop=64 verified; issue reproduces on mount path not sysfs" |
| "Replace droidspaces binary fixes App install" | "CLI loopfix alone insufficient; App needs sparsemgr + SparseImageInstaller patches (local APK E2E on TB520FU)" |
| "Set SELinux permissive to fix sparse mount" | "Tested on TB520FU/Xiaomi/OnePlus; busybox unchanged; toybox OK" |
| 未测量的 "always" on all devices | "reproduced on 3 OEMs with stock Droidspaces v6.3.0 busybox" |

---

## 7. 建议提交顺序

1. 本地跑完清单 §4 剩余 ⏳ 项  
2. 开 **Issue B** + 附 **CLI PR**（patch 已测，维护者易 review）  
3. 开 **Issue A**（App），链接 Issue B 与 `sparsemgr` patch  
4. 本仓库更新社区表 / README（与 upstream 并行，不阻塞）

---

## 8. 相关链接

- [Installation-Android.md](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Installation-Android.md)
- [Issue #81 — sparse stability](https://github.com/ravindu644/Droidspaces-OSS/issues/81)
- [PR #207 — TB520FU device entry](https://github.com/ravindu644/Droidspaces-OSS/pull/207)
- 本仓库：[`SPARSE-MOUNT-RESEARCH.md`](SPARSE-MOUNT-RESEARCH.md)