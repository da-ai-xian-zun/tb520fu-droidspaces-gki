# Droidspaces-OSS upstream submission (Issue + PR) — English

Patches: [`patches/`](../patches/) (base upstream [`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5))

Chinese paste copy: [`UPSTREAM-ISSUE-PR.md`](UPSTREAM-ISSUE-PR.md)

---

## How to file on GitHub (attachment style)

Droidspaces uses a structured **Bug Report** template ([`bug_report.yml`](https://github.com/ravindu644/Droidspaces-OSS/blob/main/.github/ISSUE_TEMPLATE/bug_report.yml)):

- **English only** (non-English issues are closed).
- Fill the form fields: kernel version/source, device, Droidspaces version, execution mode, networking mode.
- **Steps to Reproduce**: numbered list; template also mentions **Settings → Generate a bug report** in the App.
- **Logs / Screenshots**: free-text field — maintainers expect evidence here.

**What other reporters do** (e.g. [#213](https://github.com/ravindu644/Droidspaces-OSS/issues/213)):

| Style | Usage in this repo |
|--------|-------------------|
| Short repro + error lines **inline** in fenced ` ``` ` blocks | Put in Issue body (symptom A/B excerpts below) |
| Full session logs | **Drag-and-drop `.txt` on the GitHub issue** (recommended), or paste a [gist](https://gist.github.com/) link |
| `<details>` collapse | Rare in this project; optional for very long ADB dumps |
| Link to external repo | OK for patch reference: `tb520fu-droidspaces-gki/tree/main/patches` — **not** for primary repro logs (reviewers want issue-attached or gist) |

**Suggested attachments** (generate before opening the issue):

```bash
# On TB520FU (read-only bundle)
adb push tools/sparse_issue_bundle.sh /data/local/tmp/
adb shell su 0 sh /data/local/tmp/sparse_issue_bundle.sh | tee sparse-bundle.txt

# Mount-chain compare (mutates test dir only)
adb push tools/sparse_upstream_mount_chain.sh /data/local/tmp/
adb shell su 0 sh /data/local/tmp/sparse_upstream_mount_chain.sh | tee tb520fu-mount-chain.txt
```

Also attach (already in this repo):

- `docs/app内按按钮安装失败日志.txt` — stock App UI sparse install
- `docs/app内按按钮启动失败日志.txt` — stock App UI start → CLI `LOOP_SET_FD`
- PKR110 contrast: paths under `output/sparse-precheck/` (local; copy selected `.txt` into the issue upload)

**PR**: link the Issue (`Fixes #NNN`), point to patches in your fork or in `tb520fu-droidspaces-gki/patches/`. Do **not** mention local魔改 APK / custom GKI images in the upstream PR body.

---

## Issue title

```text
[BUG]: sparse image mount fails on tight loop pool (App installer + CLI lifecycle)
```

---

## Issue body (paste into GitHub form + Logs field)

### Kernel Version

`6.1.112-android14-11-maybe-dirty` (Lenovo TB520FU community GKI; `max_loop=64`, stock OEM cmdline was `max_loop=48`)

### Kernel Source Link

https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki

### Droidspaces Version

6.3.0 (stock release App + CLI from GitHub releases)

### Rooting Method

KernelSU (SukiSU)

### Device OEM & Model

Lenovo Yoga Tab Plus TB520FU (SM8650, ROW)

### Android Version & ROM

Android 16 (SDK 36), ZUI 17.5.10.096 ROW

### Execution Mode

DAEMON (also reproduced via App UI and direct CLI)

### Networking Mode

NAT

### Describe the Bug

On **Lenovo TB520FU**, stock Droidspaces v6.3.x shows two related failures:

1. **App sparse installer**: creating a new Sparse Image container fails at the mount step after mkfs/e2fsck succeed.
2. **CLI sparse lifecycle**: without reboot, repeated `stop` / `start` on a sparse container sometimes fails with `LOOP_SET_FD: Resource busy`.

In the **same boot session**, explicit high-minor `losetup` (e.g. `loop48+`) followed by `mount` **succeeds**. This is not a case of the kernel lacking loop support.

Upstream `SparseImageInstaller.kt` @ [`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5) already runs:

```text
busybox mount -o loop,...  ||  system mount -o loop,...
```

On TB520FU (`max_loop=64`, ~48 loops already bound by the system), **both** auto-allocation paths fail. Raising `max_loop` from OEM 48 to 64 did **not** fix the App installer.

Related: [Issue #81](https://github.com/ravindu644/Droidspaces-OSS/issues/81), [PR #207](https://github.com/ravindu644/Droidspaces-OSS/pull/207) (TB520FU listed with sparse install open).

### Steps to Reproduce

**A — App sparse install**

1. Install stock Droidspaces v6.3.0 from releases; let the App deploy the backend CLI.
2. Create a new container → Sparse Image (e.g. 4 GiB) → install.

**B — CLI lifecycle**

1. Run an existing sparse container (`debian-cli` with `rootfs.img`).
2. Without rebooting, run `droidspaces stop` then `droidspaces start` repeatedly (or tap Start in the App).

**C — Control (same session)**

```bash
BB=/data/local/Droidspaces/bin/busybox
OPTS=loop,rw,nodelalloc,noatime,nodiratime,init_itable=0
# busybox only → can't setup loop device
# system mount only → losetup failed / too many open files
# stock chain busybox || mount → both fail
losetup /dev/block/loop48 IMG && mount -t ext4 -o rw,... /dev/block/loop48 MNT
# succeeds
```

### Logs / Screenshots

**App UI — sparse install failure** (stock v6.3.0, 2026-06-21):

```text
[SPARSE] Mounting sparse image (Minimal loop,rw)...
[SPARSE] Error: Failed to mount sparse image. Your kernel might not support loop mounts here.
```

(full log: `docs/app内按按钮安装失败日志.txt` in our research repo — attach the file on GitHub)

**App UI — start existing sparse container** (stock CLI session):

```text
[-] LOOP_SET_FD: Resource busy
[-] Failed to mount image ... after 3 attempts
Command failed (exit code: 255)
```

(full log: `docs/app内按按钮启动失败日志.txt`)

**ADB mount-chain test** (`tools/sparse_upstream_mount_chain.sh`):

```text
RESULT_busybox_only: FAILED
RESULT_system_only: FAILED
RESULT_upstream_chain: FAILED
# explicit losetup loop48+: PASS
```

Attach: `sparse-bundle.txt`, `tb520fu-mount-chain.txt`, dirty-pool stress output (see `output/sparse-precheck/` locally).

### TB520FU measured summary

| Path | Result |
|------|--------|
| `busybox mount -o loop` | FAIL |
| `system mount -o loop` | FAIL |
| stock chain `busybox \|\| mount` | FAIL |
| manual high-minor `losetup` + `mount` | PASS |
| stock CLI stop/start | PASS after clean reboot; `LOOP_SET_FD` on dirty pool without reboot |
| stock App + loopfix CLI only (replace `/data/local/Droidspaces/bin/droidspaces`) | App chain still FAIL; CLI `debian-cli` 5/5 stop/start with loopfix binary |
| build with high-minor scan fallback (local patches) | App sparse install + stop/start PASS on TB520FU |

SELinux permissive: same auto-alloc results as enforcing.

### Contrast — OnePlus Ace 5 Pro PKR110 (`6.6.89-Gold_bug`)

| Item | Result |
|------|--------|
| stock App sparse create | PASS |
| stock CLI stop/start ×10 | PASS |
| isolated DS `busybox mount -o loop` | FAIL |
| `system/toybox mount -o loop` (64 MiB test image) | PASS |

On TB520FU both halves of the stock chain fail; on PKR110 the chain can pass when the system/toybox half succeeds.

### Code paths @ `76cbd21`

| Feature | Files |
|---------|-------|
| App sparse mount | `SparseImageInstaller.kt`, `assets/sparsemgr.sh` |
| CLI sparse mount | `src/mount.c` |

Replacing only the CLI binary does not change App sparse install (App uses `sparsemgr.sh`, not the deployed CLI).

---

## PR title

```text
android: fallback to high-minor losetup scan when sparse loop attach fails
```

---

## PR body

Fixes #(issue-number)

### Summary

Stock mount chain (unchanged order):

```text
busybox mount -o loop,...  ||  system mount -o loop,...
```

After **both** fail, add high-minor `losetup` scan fallback. No OEM model branching.

`ContainerInstaller.kt`: on successful sparse install, write `container.config` **before** unmounting the sparse rootfs.

Scan start: `max(0, max_loop - max(16, max_loop/4))`.

### Commits / files

| # | File | Scenario |
|---|------|----------|
| 1 | `src/mount.c` | CLI: `LOOP_CTL_GET_FREE` / attach failure |
| 2 | `SparseImageInstaller.kt`, `sparsemgr.sh`, `mount_loop_scan.sh` | App sparse install mount |
| 3 | `ContainerInstaller.kt` | config write + umount order |

Patches (base `76cbd21`): https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/tree/main/patches

### Tested

**Lenovo TB520FU**, Android 16, `max_loop=64`:

| Build | App sparse create | `busybox \|\| mount` | manual `losetup loop48+` | stop/start |
|-------|-------------------|----------------------|---------------------------|------------|
| stock v6.3.x | FAIL | FAIL | PASS | PASS after reboot; dirty pool FAIL |
| this PR | PASS | (fallback used) | PASS | PASS |

**OnePlus PKR110**, `6.6.89-Gold_bug`: stock PASS; **this PR not separately regression-tested**.

`assets/*.sh` must be LF-only; CRLF breaks Android `sh` under `set -eu`.

### Suggested commit messages

```text
mount: android loop attach via high-minor scan when GET_FREE fails

android: sparse installer loop-scan fallback after stock mount chain

android: write container.config before sparse umount (ContainerInstaller)
```