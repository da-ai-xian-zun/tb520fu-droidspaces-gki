# Droidspaces-OSS 上游提交示例（单 Issue + 单 PR）

> **对外粘贴稿（中文）**：见 [`UPSTREAM-ISSUE-PR.md`](UPSTREAM-ISSUE-PR.md)。本文档含复核清单与证据索引。  
> **用途**：供维护者或另一 agent 复核后，再贴 GitHub。  
> **策略**：证据聚焦 **联想 TB520FU**；补丁为 **Android 通用修法**（无机型分支），一加仅作对照；小米不写入 repro 表（busybox 同错见专档 §5.5 一句带过）。  
> **与 `UPSTREAM-ISSUE-DRAFT.md`**：DRAFT 证据更全（含跨机型表）；**对外提交以本 SAMPLE 为准**（单 Issue + 单 PR）。  
> **补丁参考**：[`patches/`](../patches/) · base **`76cbd21`** · 专档 [`SPARSE-MOUNT-RESEARCH.md`](SPARSE-MOUNT-RESEARCH.md)  
> **实机复验日志**（2026-06-20/21）  
> - TB520FU primary：`tb520fu-2026-06-20-mount-chain-test.txt` · `tb520fu-stock-apk-mount-smoke-2026-06-20.txt` · `tb520fu-stock-cli-dirty-pool-2026-06-20.txt`  
> - OnePlus contrast：`oneplus-pkr110-2026-06-20-mount-chain-test.txt` · `oneplus-pkr110-2026-06-21-scheme-a-selinux.txt`  
> 路径均在 `output/sparse-precheck/`

---

## 0. 提交前自检（复核 agent 用）

| 项 | 要求 |
|----|------|
| Issue 范围 | 只把 **TB520FU** 当 primary repro；可加 **一句** read-only「DS busybox 同错非联想独家」 |
| 一加 | **one paragraph contrast**；写明 **Gold_bug 社区内核** + 裸 busybox 仍失败 |
| 小米 thor | **不进 repro 表**；可链专档 §5.5（busybox 烟雾，未跑容器） |
| PR 姿态 | 参考实现；维护者要再开 PR，不要强推多 PR 栈 |
| 措辞 | 不说 kernel doesn't support loop / 联想独毒 / SELinux 主因；**标题不写机型** |
| 根因 | 写清 stock 已有 `busybox \|\| mount`，TB520FU 上**两条自动分配均失败** |
| 附件 | `sparse_issue_bundle` + `sparse_cli_app_compare` / `sparse_upstream_mount_chain` 输出 |

### 0.1 实机复验状态（2026-06-20，agent 已跑）

| 项目 | TB520FU | OnePlus PKR110 | 备注 |
|------|---------|----------------|------|
| `sparse_upstream_mount_chain`（stock 链） | ✅ 1–3 FAIL / 4 OK（干净池） | ✅ busybox FAIL；脏池时 system 也 FAIL；**toybox 对照 SUCCESS** | 一加 contrast 关键差异 |
| 官方 APK + stock CLI | ✅ APK 无 `mount_loop_scan`；链 FAIL | — | 仅 TB520FU |
| 魔改 APK + loopfix E2E | ✅ PASS | — | 仅 TB520FU |
| stock CLI 脏池 stress | ✅ 未 reboot → `LOOP_SET_FD`；reboot 后 50/50 | — | 仅 TB520FU |
| stock App sparse + CLI 10/10 | — | ✅ 早前 PASS（Gold_bug） | 见 scheme-a 日志 |
| DS busybox 孤立 `mount -o loop` | ✅ FAIL | ✅ FAIL（permissive 亦 FAIL） | 跨机型一致 |
| strace ioctl 对比 | ⚠️ blocked（主机无 strace） | ⚠️ 未跑 | 非阻塞 |
| max_loop=48 原厂 ROM 复刷 | ⏭️ 跳过 | — | 用户决定不刷机 |

---

## 1. GitHub Issue（粘贴用 · 英文）

### Title

```text
android: sparse image mount unreliable on tight loop pool (App installer + CLI dirty pool)
```

### Labels (suggested)

`bug` · `android`

### Body

```markdown
## Summary

On **Lenovo TB520FU** (Yoga Tab Plus, ROW ZUI 17.5.10.096, **Android 16 / SDK 36**), **sparse image containers are unreliable** with the stock v6.3.x App + CLI:

1. **App — Sparse Image installer**: auto loop allocation fails when creating a new sparse container.
2. **CLI — `--rootfs-img` / `start`**: after repeated stop/start without reboot, loop attach may fail (`LOOP_SET_FD: Resource busy` / failed attach).

On the **same device and boot session**, **explicit high-minor `losetup` + `mount` succeeds**. This is **not** "kernel lacks loop support."

**Important:** stock `SparseImageInstaller.kt` @ [`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5) already tries:

```text
busybox mount -o loop,...  ||  system mount -o loop,...
```

On TB520FU (2026-06-20 live test, `max_loop=64`, 48/64 loops bound, APEX ~47), **both** auto-alloc paths fail; only explicit `losetup` on `loop48+` works. Expanding the pool from stock `max_loop=48` to **64 did not fix** the App installer path — this is a **userspace auto loop-alloc** issue, not only OEM pool sizing.

We are **not** claiming all Android devices are broken. On **OnePlus Ace 5 Pro PKR110** with the **community** Droidspaces kernel (`6.6.89-Gold_bug` — stock ColorOS kernel lacks PID/IPC namespaces and cannot run containers), **stock App sparse creation and stock CLI stop/start stress passed** (CLI: 10/10 rounds). **2026-06-20 live mount-path test on PKR110:** isolated Droidspaces **busybox** `mount -o loop` **still fails** (same `can't setup loop device`); **system/toybox** `mount -o loop` **succeeds** on a fresh 64 MiB test image (`sparse_selinux_loop_test`). Stock `busybox \|\| mount` can therefore work on OnePlus when the second half succeeds — unlike TB520FU where **both** halves fail. Contrast driver: **pool headroom + which auto-alloc path succeeds**, not "busybox works on OnePlus."

Related: [PR #207](https://github.com/ravindu644/Droidspaces-OSS/pull/207) (device table "Partial" was our conservative self-label when App sparse was still open; CLI migrate + workarounds exist locally now). Related theme: [Issue #81](https://github.com/ravindu644/Droidspaces-OSS/issues/81) (sparse stability).

## Environment (primary repro)

| Item | Value |
|------|--------|
| Device | Lenovo **TB520FU** / Yoga Tab Plus (SM8650) |
| OS | ROW ZUI 17.5.10.096, Android 16 |
| Root | KernelSU (SukiSU) on patched `init_boot` |
| Kernel | Custom GKI (`6.1.112-android14-11-maybe-dirty`), cmdline `max_loop=64` (stock Lenovo ROM used `max_loop=48`; **same mount-path failure class on stock ROM before kernel swap**) |
| Droidspaces | **Stock** App + CLI from release (v6.3.x era) for repro; loop-scan validation via local debug build (see patches) |

## Symptoms

### A) App sparse installer (stock)

Steps:

1. Install stock Droidspaces App + backend CLI (not a vendor-patched APK).
2. Create a new container → **Sparse Image** (e.g. 4 GiB).

Actual (App log):

```text
[SPARSE] Mounting sparse image (Minimal loop,rw)...
Failed to mount sparse image. Your kernel might not support loop mounts here.
```

ADB equivalents on TB520FU (same session, fresh test image, App mount options):

```bash
# 1) busybox only (first half of stock installer chain)
/data/local/Droidspaces/bin/busybox mount -t ext4 -o loop,rw,nodelalloc,noatime,nodiratime,init_itable=0 IMG MNT
# → can't setup loop device: No such file or directory

# 2) system mount only (second half of stock installer chain)
mount -t ext4 -o loop,rw,nodelalloc,noatime,nodiratime,init_itable=0 IMG MNT
# → losetup: Too many open files

# 3) exact stock SparseImageInstaller chain
busybox mount ... || mount -t ext4 -o loop,... IMG MNT
# → both fail (see attachment: sparse_upstream_mount_chain)

# 4) control — explicit high minor
losetup /dev/block/loop48 IMG && mount -t ext4 -o rw,... /dev/block/loop48 MNT
# → succeeds
```

### B) CLI sparse lifecycle (stock CLI binary)

After a sparse container is running (e.g. via CLI `--rootfs-img` / migrate):

1. Repeat `droidspaces stop` → `droidspaces start` **without rebooting**.
2. Stock CLI may fail: `LOOP_SET_FD: Resource busy` / loop setup errors — especially when the pool is already in a **stale/dirty state** from a prior session (we observed **immediate warmup failure** on TB520FU with stock 461544 B when `losetup` bound=49 **without** reboot).
3. **TB520FU 2026-06-20 (after clean reboot, `max_loop=64`, stock CLI, `debian-cli` sparse):** **50/50** stop/start rounds succeeded (two consecutive 25-round runs). CLI symptom B is **state-dependent** on current kernel config; loopfix remains useful to avoid reboot when the pool is dirty.
4. Full reboot clears dirty ioctl state; App auto-alloc path (A) **still fails** after reboot.

## What works on TB520FU (same session, 2026-06-20)

| Path | Result (48/64 bound, max_loop=64) |
|------|-----------------------------------|
| Manual `losetup /dev/block/loop48+` + `mount` | ✅ |
| Stock **auto** paths: busybox / system `mount -o loop` / `busybox \|\| mount` | ❌ **all fail** |
| Stock CLI `--rootfs-img` | ✅ after reboot (50/50 tested); ❌ when pool stale without reboot (B) |
| loopfix CLI + high-minor scan | ✅ (including repeated stop/start in our tests) |

`setenforce 0` does **not** fix the busybox / system auto-alloc paths on TB520FU (permissive tested previously; toybox/system mount outcome unchanged for busybox; see research repo §5.6).

## Analysis (our understanding)

- **APEX + OEM loop occupancy** leaves little margin on TB520FU stock policy (`max_loop=48`); expanding to **64 does not fix** auto-alloc — userspace must pick a free **high** minor explicitly.
- **App** (`SparseImageInstaller.kt`): upstream already uses `busybox \|\| system mount -o loop`; on TB520FU **both** fail under APEX-heavy pools — need a **third** fallback (explicit `losetup` scan).
- **CLI** (`mount.c`): uses `ioctl(LOOP_CTL_GET_FREE)`; under pool pressure / repeated cycles, returned slots may still fail attach.
- **Replacing only the CLI binary does not fix App sparse creation** — separate code paths (Kotlin + `sparsemgr.sh` vs `mount.c`).
- **Read-only cross-check (not primary repro):** Droidspaces bundled busybox shows the same isolated error on other OEMs (Xiaomi thor, OnePlus PKR110); see linked research §5.5 — not Lenovo-specific.

## Proposed direction (Android-universal, no model branches)

**Upstream-first:**

1. **Keep** existing **busybox → system `mount -o loop`** order (already in upstream; unchanged happy path).
2. **Add** on failure only: **explicit high-minor loop scan** — scan floor `max(0, max_loop - max(16, max_loop/4))` (relative to pool size; on `max_loop=64` this is **48**, on small pools it degrades to **0**). Effective range uses `max(sysfs max_loop, highest /sys/block/loopN + 1)` for dynamic pools.
3. **CLI (`mount.c`)**: on Android, same relative scan when `LOOP_CTL_GET_FREE` / attach is unreliable; bump start above highest bound minor from `/proc/loops`.
4. **Installer lifecycle**: write `container.config` **before** unmounting the sparse mount on success; avoid blocking `sync` while the sparse fs is still mounted; detach loops via `losetup -a` when `/proc/loops` is empty.

## Reference patch stack (tested locally, not yet submitted as PR unless requested)

Base: [`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5)

| Patch | Touches |
|-------|---------|
| `droidspaces-android-loop-scan.patch` | `src/mount.c` only |
| `sparsemgr-loop-scan.patch` | `assets/sparsemgr.sh` |
| `sparseimageinstaller-loop-scan.patch` | `SparseImageInstaller.kt` + `assets/mount_loop_scan.sh` |
| `sparseimageinstaller-unmount-after-config.patch` | `ContainerInstaller.kt` |

Public mirror: [tb520fu-droidspaces-gki `patches/`](https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/tree/main/patches)

**TB520FU validation (debug build with above patches):** App sparse install + network + 3× stop/start + full install-path E2E — PASS.  
**Packaging note:** shell assets must be **LF-only**; CRLF breaks `set -eu` on Android `sh` before any mount runs.

## Contrast (not a repro)

**OnePlus PKR110** + **`6.6.89-Gold_bug` community kernel** (required for PID/IPC ns): stock App 4 GiB sparse creation succeeded; stock CLI `loop_stress_named.sh` **10/10** without loopfix. **2026-06-20:** `sparse_upstream_mount_chain` — busybox leg **fails** (same isolated error as TB520FU); on a **clean 64 MiB** test image, **toybox/system** `mount -o loop` **succeeds** while busybox still fails (`oneplus-pkr110-2026-06-20-mount-chain-test.txt`). Suggests severity correlates with **pool headroom + which auto-alloc path succeeds**, not a Lenovo-only kernel defect.

## What we are not claiming

- ❌ "All OEMs fail App sparse install" (OnePlus + Gold_bug: stock App create OK for us)
- ❌ "Kernel doesn't support loop" (explicit `losetup` works)
- ❌ "SELinux blocks loop mounts" (permissive tested; auto-alloc paths unchanged)
- ❌ "Replacing `droidspaces` CLI alone fixes App sparse install"
- ❌ "Only expanding `max_loop` fixes TB520FU" (64 pool tested; auto-alloc still fails)

## Attachments

- [x] `sparse_issue_bundle.txt` — TB520FU 2026-06-20 (`tools/sparse_issue_bundle.sh`)
- [x] `sparse_cli_app_compare` + `sparse_upstream_mount_chain` — `output/sparse-precheck/tb520fu-2026-06-20-mount-chain-test.txt`
- [x] stock official APK + stock CLI mount smoke — `output/sparse-precheck/tb520fu-stock-apk-mount-smoke-2026-06-20.txt`
- [x] stock CLI dirty-pool stress — `output/sparse-precheck/tb520fu-stock-cli-dirty-pool-2026-06-20.txt` (50/50 post-reboot; pre-reboot stale pool → warmup `LOOP_SET_FD`)
- [x] OnePlus contrast mount-path — `output/sparse-precheck/oneplus-pkr110-2026-06-20-mount-chain-test.txt` + `oneplus-pkr110-2026-06-21-scheme-a-selinux.txt`

/cc @ravindu644 — happy to open **one combined PR** if useful; otherwise please treat the linked patches as a reference implementation.
```

---

## 2. GitHub PR（粘贴用 · 英文）

> **说明**：维护者未索要前，可保持 **Draft** 或仅在 Issue 中链接补丁目录。以下为 **单 PR 对应单 Issue** 的示例描述。

### Title

```text
android: sparse loop attach — high-minor scan fallback
```

### Target branch

`ravindu644/Droidspaces-OSS` → `main` (rebase on current `main`; verify `git apply --check` against `76cbd21` or newer)

### Body

```markdown
## Linked issue

Fixes #(issue-number) — sparse mount on loop-heavy Android (App + CLI). Primary repro: **TB520FU**; patches are **Android-generic** (no OEM model `if` branches).

## Summary

Single reference stack for sparse image mounting on loop-heavy / **tight-pool** Android devices:

| Commit (suggested split) | Files | Issue symptom |
|--------------------------|-------|----------------|
| 1 | `src/mount.c` | CLI dirty pool / `LOOP_CTL_GET_FREE` unreliable |
| 2 | `assets/mount_loop_scan.sh`, `SparseImageInstaller.kt`, `sparsemgr.sh` | App auto loop alloc fails (busybox **and** system `mount -o loop`) |
| 3 | `ContainerInstaller.kt` | Installer hang / missing `container.config` (umount after config write) |

**Strategy:** unchanged happy path — stock **busybox / system `mount -o loop` first** (already upstream); fallback to **explicit `losetup` scan** from high minors (dynamic pool aware).

## Tested on

- **Lenovo TB520FU**, Android 16, custom GKI `max_loop=64`, SukiSU — loop-scan debug APK + CLI: App sparse E2E + stop/start stress **PASS**.
- **Mount-path smoke (stock chain, no patched APK):** `busybox || mount` **fails**; explicit `losetup loop48+` **succeeds** (log in research repo `output/sparse-precheck/`).

**Contrast:** OnePlus PKR110 + **Gold_bug** community kernel — stock App/CLI passed stress tests without this PR; isolated DS busybox still fails; system/toybox `mount -o loop` succeeds on PKR110 when pool allows (2026-06-20 log). PR remains useful as generic hardening for tight pools (TB520FU: `max_loop=64` still broken for auto-alloc).

**Not tested in this PR:** devices without Droidspaces kernel namespaces (stock-only kernels without PID/IPC ns).

## Checklist

- [ ] `git apply --check` on current `main`
- [ ] `assets/*.sh` committed **LF-only** (CRLF breaks Android `sh` at `set -eu`)
- [ ] No device model / OEM branching (scan floor is `max_loop`-relative)
- [ ] Desktop Linux `mount.c` path still uses `LOOP_CTL_GET_FREE` (unchanged)

## How to review

Commits 1–3 are separable for cherry-pick: **commit 1** helps TB520FU CLI dirty-pool users; **commits 2–3** needed for **App sparse create** on TB520FU. Commit 2 owns all `SparseImageInstaller.kt` mount/umount helper changes; commit 3 is only the `ContainerInstaller.kt` caller.

Patches: `patches/*.patch` @ `76cbd21` in [tb520fu-droidspaces-gki](https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/tree/main/patches).
```

---

## 3. 建议的 PR commit 顺序（维护者友好）

```text
mount: android loop attach via high-minor scan when GET_FREE fails

android: sparse installer loop-scan fallback after stock mount chain

android: write container.config before sparse umount (ContainerInstaller)
```

| Commit | 补丁文件 | 说明 |
|--------|----------|------|
| 1 | `droidspaces-android-loop-scan.patch` | 仅 `mount.c` |
| 2 | `sparseimageinstaller-loop-scan.patch` + `sparsemgr-loop-scan.patch` | 含 `SparseImageInstaller.kt` + shell 资产 |
| 3 | `sparseimageinstaller-unmount-after-config.patch` | **仅** `ContainerInstaller.kt` |

---

## 4. 复核 agent 对照表（中文）

| 用户/维护者易混点 | 本文档写法 |
|-------------------|------------|
| 「三家 OEM 都测了」 | ❌ 仅 TB520FU 主 repro；专档 §5.5 一句 read-only 带过 |
| 「一加 busybox 也好」 | ❌ Contrast 写明裸 busybox 仍失败；App 成功靠 **toybox/system 后半段** + 池子余量（2026-06-20 实测） |
| 「扩 max_loop 就够」 | ❌ 写明 64 池仍失败（2026-06-20 实测） |
| 「只怪 busybox」 | ❌ 写明 stock 已有 `busybox \|\| mount`，两条都挂 |
| Issue A + Issue B 两个 | ✅ 合并为一个 issue 两小节症状 |
| 三个 PR | ✅ 一个 PR，三 commit |
| 标题带 TB520FU | ❌ 已改为 android: 通用标题 |
| 补丁角色 | ✅ 维护者需要时看的 reference |

---

## 5. 提交顺序（给人/agent 执行）

1. 复核 agent 读本文件 + `patches/` + `output/sparse-precheck/tb520fu-2026-06-20-mount-chain-test.txt` + `oneplus-pkr110-2026-06-20-mount-chain-test.txt`
2. 开 **一个 Issue**（§1 正文）  
3. 维护者回应后，再开 **一个 Draft PR**（§2 正文）或仅更新 Issue 链接  
4. 不在 Issue 中承诺「所有 Android 机必现」  
5. 内部本地物（魔改 APK、自编 GKI 镜像、部署脚本）见 `SPARSE-MOUNT-RESEARCH.md` §5.4 — **不要写进 Issue/PR 正文**