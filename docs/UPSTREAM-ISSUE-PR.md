# Droidspaces-OSS 上游提交稿（Issue + PR）

相关补丁：[`patches/`](../patches/)（基于 upstream `76cbd21`）

---

## Issue 标题

```text
android：loop 池紧张时 sparse 镜像挂载失败（App 安装器与 CLI）
```

---

## Issue 正文

### 现象

在联想 TB520FU（Yoga Tab Plus，ZUI 17.5.10.096，Android 16）上，使用 stock Droidspaces v6.3.x App 与 CLI 时，观察到两类失败：

1. App：新建 Sparse Image 容器时，挂载阶段失败。
2. CLI：不重启设备、反复执行 stop / start 后，sparse 容器有时无法再次启动（`LOOP_SET_FD: Resource busy` 等 loop 附着错误）。

同一次启动会话内，手动对较高 loop 次设备（如 loop48 及以上）执行 `losetup` 再 `mount` 可以成功。

上游 `SparseImageInstaller.kt`（[`76cbd21`](https://github.com/ravindu644/Droidspaces-OSS/commit/76cbd21ee29646d100852adfcbe9bcc1e9a39bd5)）执行的挂载链为：

```text
busybox mount -o loop,...  ||  system mount -o loop,...
```

在 TB520FU 上（`max_loop=64`，约 48 个 loop 已被占用），上述两条分支均失败。将 `max_loop` 从原厂 48 提高到 64 之后，App 安装器仍失败。

关联：[Issue #81](https://github.com/ravindu644/Droidspaces-OSS/issues/81)、[PR #207](https://github.com/ravindu644/Droidspaces-OSS/pull/207)

### 环境

| 项目 | 值 |
|------|-----|
| 设备 | 联想 TB520FU（SM8650） |
| 系统 | Android 16（SDK 36），ZUI 17.5.10.096 ROW |
| Root | KernelSU（SukiSU） |
| 内核 | `6.1.112-android14-11-maybe-dirty`，`max_loop=64`（原厂 `max_loop=48` 时亦出现同类失败） |
| Droidspaces | Stock 正式版 App + CLI（v6.3.x） |

### 复现步骤与输出

#### A — App sparse 安装器

1. 安装 stock Droidspaces 正式版 App，由 App 部署后端 CLI。
2. 新建容器，选择 Sparse Image（例如 4 GiB）。

App 日志：

```text
[SPARSE] Mounting sparse image (Minimal loop,rw)...
Failed to mount sparse image. Your kernel might not support loop mounts here.
```

ADB 测试（与 App 相同挂载选项，新建 512 MiB ext4 镜像）：

```bash
BB=/data/local/Droidspaces/bin/busybox
OPTS=loop,rw,nodelalloc,noatime,nodiratime,init_itable=0

$BB mount -t ext4 -o $OPTS IMG MNT
# can't setup loop device: No such file or directory

mount -t ext4 -o $OPTS IMG MNT
# losetup: Too many open files

$BB mount -t ext4 -o $OPTS IMG MNT || mount -t ext4 -o $OPTS IMG MNT
# 两步均失败

losetup /dev/block/loop48 IMG && mount -t ext4 -o rw,... /dev/block/loop48 MNT
# 成功
```

#### B — CLI sparse 生命周期

1. 通过 CLI 运行 sparse 容器（`--rootfs-img` 或已有 sparse 配置）。
2. 不重启设备，多次执行 `droidspaces stop` 后 `droidspaces start`。

TB520FU，stock CLI（461544 B）：

| 条件 | 结果 |
|------|------|
| 前序会话未 reboot，脏 loop 池（`losetup` 绑定约 49） | 出现 `LOOP_SET_FD: Resource busy` |
| 干净 reboot 后（`max_loop=64`），两轮各 25 次 stop/start | 50/50 成功 |
| reboot 之后，App sparse 安装器（症状 A） | 仍失败 |

### TB520FU 挂载路径实测汇总

| 方式 | 结果 |
|------|------|
| `busybox mount -o loop` | 失败 |
| `system mount -o loop` | 失败 |
| stock 链 `busybox \|\| mount` | 失败 |
| 手动高 minor `losetup` + `mount` | 成功 |
| stock CLI 反复 stop/start | reboot 后成功；脏池且无 reboot 时失败 |
| stock App + loopfix CLI（仅换 CLI 二进制） | App 挂载链仍失败；`debian-cli` stop/start 5/5 成功 |
| 含高 minor `losetup` 扫描改动的构建 | App sparse 安装、联网检查、反复 stop/start 均成功 |

SELinux 为 permissive 时，上述自动分配路径的结果与 enforcing 一致。

### 其他设备上的实测

一加 Ace 5 Pro（PKR110），内核 `6.6.89-Gold_bug`：

| 项目 | 结果 |
|------|------|
| stock App sparse 创建 | 成功 |
| stock CLI stop/start 压测（10 轮） | 成功 |
| 孤立 DS `busybox mount -o loop` | 失败（`can't setup loop device`） |
| `system/toybox mount -o loop`（64 MiB 测试镜像） | 成功 |

TB520FU 上 stock 链两条分支均失败；PKR110 上 stock 链在后半段（system/toybox）成功时整体可通过。

### 上游代码路径（`76cbd21`）

| 功能 | 主要文件 |
|------|----------|
| App sparse 挂载 | `SparseImageInstaller.kt`、`assets/sparsemgr.sh` |
| CLI sparse 挂载 | `src/mount.c` |

TB520FU 上已实测 **stock App + stock CLI** 组合下 sparse 创建失败（见上文症状 A 与挂载链表）。

2026-06-21 另测 **stock App + loopfix CLI**（仅替换 `/data/local/Droidspaces/bin/droidspaces` 为 410168 B loopfix，APK 仍为官方 v6.3.0、资产含 stock `sparsemgr.sh`、无 `mount_loop_scan.sh`）：

| 项目 | 结果 |
|------|------|
| App 挂载链 `busybox \|\| mount`（`sparse_upstream_mount_chain`） | 失败 |
| CLI `debian-cli` stop/start ×5（loopfix 二进制） | 5/5 成功 |
| App UI 新建 Sparse（`sb`，4 GiB） | 挂载阶段失败（见 `docs/app内按按钮安装失败日志.txt`） |
| App UI 启动 `debian-cli`（stock CLI 会话） | `LOOP_SET_FD: Resource busy` ×3（见 `docs/app内按按钮启动失败日志.txt`） |

App 安装器走 `sparsemgr.sh`，不调用已替换的 CLI 二进制；上述挂载链失败与 stock App + stock CLI 时一致。

### 附件

提交到 GitHub Issue 时：**正文放短摘录**（见上），**完整 `.txt` 拖进 Issue 附件区**（与 [#213](https://github.com/ravindu644/Droidspaces-OSS/issues/213) 同类做法；不必用 `<details>` 折叠）。英文说明见 [`UPSTREAM-ISSUE-PR-EN.md`](UPSTREAM-ISSUE-PR-EN.md) 开头。

- `docs/app内按按钮安装失败日志.txt`
- `docs/app内按按钮启动失败日志.txt`
- TB520FU 挂载链测试输出（`sparse_upstream_mount_chain.sh`）
- TB520FU CLI stop/start 压测输出
- `sparse_issue_bundle.txt`（`tools/sparse_issue_bundle.sh`）
- PKR110 挂载路径 / stock E2E 输出（本地 `output/sparse-precheck/`，提交时复制选定 `.txt` 上传）

---

## PR 标题

```text
android：sparse loop 附着失败时回退至高 minor 扫描
```

---

## PR 正文

Fixes #(issue-number)

### 变更内容

stock 挂载链为：

```text
busybox mount -o loop,...  ||  system mount -o loop,...
```

本 PR 在上述两步均失败后，增加高 minor `losetup` 扫描回退；前两步的执行顺序与条件不变。

`ContainerInstaller.kt`：sparse 安装成功时，先写入 `container.config`，再卸载 sparse 挂载。

扫描起点：`max(0, max_loop - max(16, max_loop/4))`。未按机型名分支。

### 文件与 commit 划分

| 序号 | 文件 | 变更涉及的场景 |
|------|------|----------------|
| 1 | `src/mount.c` | CLI：`LOOP_CTL_GET_FREE` / attach 失败 |
| 2 | `SparseImageInstaller.kt`、`sparsemgr.sh`、`mount_loop_scan.sh` | App sparse 安装挂载 |
| 3 | `ContainerInstaller.kt` | 安装成功后的 config 写入与 umount 顺序 |

### 实测记录

联想 TB520FU，Android 16，`max_loop=64`：

| 构建 | App sparse 创建 | `busybox \|\| mount` | 手动 `losetup loop48+` | 反复 stop/start |
|------|-----------------|----------------------|-------------------------|-----------------|
| stock v6.3.x | 失败 | 失败 | 成功 | reboot 后成功；脏池无 reboot 时失败 |
| 本 PR | 成功 | （回退路径启用） | 成功 | 成功 |

一加 PKR110，内核 `6.6.89-Gold_bug`：

| 构建 | App sparse 创建 | 孤立 busybox `mount -o loop` | system mount |
|------|-----------------|------------------------------|--------------|
| stock v6.3.x | 成功 | 失败 | 成功 |
| 本 PR | （未单独回归） | — | — |

`assets/*.sh` 为 CRLF 时，Android `sh` 在 `set -eu` 处退出；LF 时正常。

补丁目录（基于 `76cbd21`）：<https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/tree/main/patches>

### commit message

```text
mount: android loop attach via high-minor scan when GET_FREE fails

android: sparse installer loop-scan fallback after stock mount chain

android: write container.config before sparse umount (ContainerInstaller)
```