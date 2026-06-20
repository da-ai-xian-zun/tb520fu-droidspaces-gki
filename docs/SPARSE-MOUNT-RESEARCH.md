# TB520FU Droidspaces 稀疏挂载（Sparse Image）研究专档

> 设备：Lenovo TB520FU / Yoga Tab Plus，ROW ZUI 17.5.10.096（**Android 16 / SDK 36**），phase-2 GKI（`max_loop=64`）  
> 整理日期：2026-06-20；**2026-06-21 增补**：跨机型 loop 池、责任分层、loopfix、魔改 APK E2E、一加线 2 完成、Partial 标注说明  
> **2026-06-20 晚增补**：CRLF 打包陷阱、安装器 `finally` 卡死、完整 App 安装 + 启停 E2E（§5.4.2）
> 相关交接：[`TB520FU-Droidspaces-后续研究方向交接.md`](TB520FU-Droidspaces-后续研究方向交接.md) §5.18–§5.19、§5.21

---

## 1. 为什么要研究稀疏挂载

### 1.1 痛点

`debian-cli` / `debian13` 最初用 **目录模式**（`rootfs/` 直接铺在 `/data` f2fs 上）。Debian 含海量小文件，`apt` / `git` / `stat` 等 **元数据 I/O** 体感卡顿。

### 1.2 设备约束

| 约束 | 说明 |
|------|------|
| 无 SD 卡槽 | 零售机未引出卡槽；`lapis-qrd.dts` 仅有 `sd_card_det` 参考设计脚 |
| 存储在 `/data` f2fs | 容器与 Android 应用共享同一分区 |
| APEX 占 loop | 常态约 **47/64** 个 loop 被 APEX 占用，空闲槽在 **loop48+** |

### 1.3 上游建议

[Droidspaces Installation-Android](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Installation-Android.md) 明确推荐 Android 上使用 **Sparse Image**：

> for better **performance and stability** on Android's **f2fs** storage, as well as to prevent weird **SELinux/Keyring** issues.

---

## 2. 稀疏镜像是什么（澄清误区）

### 2.1 两层结构

```text
/data (f2fs) 上的单个文件 rootfs.img     ← 「稀疏」指此文件可打洞、用多少占多少
    └── loop 挂载
          └── ext4 文件系统               ← 容器内的「根」，Debian 看到的世界
```

- **Sparse Image**：Droidspaces 术语，指用 `.img` 文件承载 rootfs，而非百万文件直接落 f2fs。
- **内层文件系统**：**ext4**（不是 FAT32，也不是 f2fs）。

### 2.2 没有「ext4 单文件不能超过 4GB」这回事

| 格式 | 单文件 / 卷限制 |
|------|----------------|
| **FAT32** | 单文件 ≤ 4GB−1（U 盘常见坑） |
| **ext4 卷** | 可达 TB 级 |
| **`rootfs.img` 在 f2fs** | 可为 4G / 32G / 64G 等（本机 `/data` 448G） |

App 安装日志里 `Creating sparse image: 4GB` 是 **默认容量选项**，不是格式上限。

### 2.3 日后扩容（32G → 64G）

**可以。** 停容器后：

```bash
droidspaces --name=debian-cli stop
truncate -s 64G /data/local/Droidspaces/Containers/debian-cli/rootfs.img
e2fsck -f /data/local/Droidspaces/Containers/debian-cli/rootfs.img
resize2fs /data/local/Droidspaces/Containers/debian-cli/rootfs.img
droidspaces --name=debian-cli start
```

删容器内大文件后若要缩小 **实占**，须在容器内 `fstrim -av`（见 [Droidspaces Issue #81](https://github.com/ravindu644/Droidspaces-OSS/issues/81)）。

---

## 3. 研究过程与结论总览

```text
社区调研（无定量 benchmark，官方定性推荐 sparse）
        ↓
TB520FU 实机 A/B（apt 约 −69%，stat 持平）
        ↓
挂载路径分层（App busybox / toybox / CLI / 手动 losetup）
        ↓
KSU 模块隔离（排除单模块致因；App busybox 仍失败）
        ↓
debian-cli 迁移 32G sparse（CLI --rootfs-img，重启后成功）
        ↓
loop-scan 补丁二进制（CLI 脏池 8–20 轮停启无需 reboot；见 §5.4）
        ↓
跨机型只读对照（§12）→ 方案 A + busybox 复现（§5.5）→ SELinux 证伪（§5.6）
```

| 问题 | 结论 |
|------|------|
| sparse 比目录快吗？ | **apt 类明显快**；单次 stat/ls 微基准差距不大 |
| TB520FU 硬件坏了？ | **否** |
| 某个 Magisk 模块弄坏的？ | **无单模块证据**；magic_mount_rs 再次排除 |
| 自编 GKI 弄坏的？ | **否**；phase-2 `max_loop=64` 实机生效，手动 loop 可用（见 §13） |
| 联想原厂独有 bug？ | **否**；busybox 在小米/一加原厂也同错（§5.5）；OEM 差异在 **池子策略** |
| SELinux 导致 busybox 失败？ | **否**；`setenforce 0` 后 busybox 仍失败（§5.6） |
| App sparse 安装为何失败？ | **stock APK** 内嵌 busybox `mount -o loop` 跨机型不可靠（§5.5）；**魔改 APK** 已用 loop-scan 绕过（§5.4.1） |
| 日常怎么用 sparse？ | **CLI 迁移** + loopfix CLI；或装 **魔改 APK** 在 App 里新建 sparse（TB520FU ✅；其他机型待测） |

---

## 4. 社区调研（2026-06-20）

**检索**：官方文档、Troubleshooting、GitHub Issues/PR、Reddit/XDA、loopback 通用讨论。

**结论**：**无公开 apt/git/stat 的 sparse vs directory 定量对比**。

### 4.1 官方 / Troubleshooting 要点

| 主题 | 目录模式 | sparse / `rootfs.img` |
|------|----------|------------------------|
| SELinux 损坏 symlink/库 | 易发生 | img 内 xattr 封装，**推荐 img** |
| FBE `ENOKEY` / Keyring | 可能有问题 | **推荐 img** |
| `--volatile` + OverlayFS on f2fs | 失败 | ext4 img 作 lower **可用** |
| 空间回收 | 删文件即释 f2fs | 需 `fstrim -av` 缩 sparse 洞 |

### 4.2 Issue 板摘要

| 来源 | 要点 |
|------|------|
| [#81](https://github.com/ravindu644/Droidspaces-OSS/issues/81) | sparse 更 isolated/stable；可改镜像上限；删包不自动缩小 |
| [#179](https://github.com/ravindu644/Droidspaces-OSS/issues/179) | 外置 SD 存容器仍为 feature request |
| [PR #207](https://github.com/ravindu644/Droidspaces-OSS/pull/207) | 维护者自提交 TB520FU；当时自标 **Partial**（目录可用，App sparse 未解决） |

### 4.3 关于社区表里的「Partial」

- **Partial 是维护者本人提交 PR #207 时的自评**，不是社区独立验收结论，**不能**当作「联想独一份坏」的铁证。
- 标注时 loopfix 尚未部署、sparse 日常路径也未完全理清；若 loop/CLI 已稳定，应更新社区表状态与备注，而非沿用旧标签。

---

## 5. 挂载路径分层（TB520FU 实机）

loop 池：`max_loop=64`，APEX 常态占 **~47**，测试/容器用 **loop48+**。

### 5.1 四条路径对比

| 路径 | 典型报错 | 干净重启后 | loop 池脏时 | 谁在用 |
|------|----------|------------|-------------|--------|
| **App busybox** `mount -o loop` | `can't setup loop device: No such file or directory` | ❌ **仍失败** | ❌ | Droidspaces **App 安装器** |
| **toybox** `mount -o loop` | `losetup: Too many open files` | ✅ 成功 | ❌ | 系统 toybox（非 App 路径） |
| **CLI** `--rootfs-img`（**stock** 二进制） | `LOOP_SET_FD: Resource busy` | ✅ 成功 | ❌ | `droidspaces` CLI |
| **CLI** `--rootfs-img`（**loopfix** 二进制） | （脏池扫描 loop63→48） | ✅ 成功 | ✅ **8–20 轮停启 OK** | 补丁 `mount.c` |
| **手动** `losetup loop48` + `mount` | 偶发 `> 64 bytes` 但 mount 可成 | ✅ 成功 | ✅ 往往仍成功 | adb / 变通脚本 |

**要点**：

1. **App 安装 sparse 失败** 与 **CLI 在脏状态下失败** 不是同一错误，但都与 **自动 loop 分配** 有关。
2. **stock APK**：即使用户刚重启，busybox 路径仍失败 → 勿用官方 App Sparse 新建；**魔改 APK** 已绕过（§5.4.1）。
3. **完整重启** 可恢复 CLI `--rootfs-img`；繁忙测试/多次失败重试后易回到 `LOOP_SET_FD` / `Too many open files`。

### 5.2 历史根因演变（勿重复踩坑）

| 阶段 | 当时判断 | 现在修正 |
|------|----------|----------|
| phase-1 | loop 池 48 满 → sparse 失败 | 扩 `max_loop=64` **必要但不充分** |
| phase-2 | `mount -o loop` → Too many open files | **仍成立**；非 fd 真满（`ulimit -n`=32768） |
| §5.19 | 显式 `losetup loop48` 可挂载 | **仍成立** |
| 模块隔离后 | 曾怀疑 KSU 模块 | **单模块逐一排除**；见 §6 |
| App `sb` 安装复现 | busybox 永久失败 | **App 安装器硬伤** |

### 5.3 用户 App 安装 `sb` 失败日志（2026-06-20）

```text
[SPARSE] Creating sparse image: 4GB
[SPARSE] Mounting sparse image (Minimal loop,rw)...
Failed to mount sparse image. Your kernel might not support loop mounts here.
```

同期 adb 对比：`busybox mount -o loop` → `can't setup loop device: No such file or directory`（与 App 一致）。

### 5.4 loopfix：CLI loop 扫描补丁（2026-06-21）

**问题**：stock CLI 在 Android 上用 `ioctl(LOOP_CTL_GET_FREE)`，APEX 占满低号槽 + 池子脏时易 `LOOP_SET_FD: Resource busy`；一加等机 sysfs `max_loop=16` 与实际 `/sys/block/loop50+` 不一致时，仅读 sysfs 会扫错范围。

**补丁范围**：**仅** `patches/droidspaces-android-loop-scan.patch` → **`src/mount.c` 一个文件**（`build_droidspaces_loopfix.sh` 编进 `droidspaces` 二进制）。**未改** App Kotlin、未改 `busybox`、未改内核。

**`mount.c` 改了什么**（`loop_attach` 路径）：

1. **`read_max_loop()`**：`max(sysfs max_loop, scan_block_loop_max()+1)`，避免一加 sysfs=16 漏扫高 minor。
2. **Android 上不再只靠 `LOOP_CTL_GET_FREE`**：从 `loop(max-1)` 向下扫，优先 **loop48+**（`DS_ANDROID_LOOP_RESERVE_MIN`），再扫低号。
3. **`loop_is_free()`**：`LOOP_GET_STATUS64` + `ENXIO` 判空闲槽。
4. **`loop_attach_one()`**：`LOOP_SET_FD` 遇 `EBUSY` 时 `LOOP_CLR_FD` 后重试。
5. **桌面 Linux**：仍走 `LOOP_CTL_GET_FREE`（行为与 upstream 一致）。

| 项 | 值 |
|----|-----|
| 产物 | `output/droidspaces-loopfix/droidspaces-aarch64-loopfix`（~410168 B；stock ~461544 B） |
| 当前 SHA256 | `e0a80f9c1287c5e67e796379dfa94db7594d5f3970fe7e96a2884363b5c4584d` |
| 部署 | `/data/local/Droidspaces/bin/droidspaces` + `install_loopfix_persistent.sh` / `apply-loopfix.sh` |
| 验证 | 8–20 轮 `debian-cli` stop/start **无需 reboot** 成功 |
| **stock APK 未覆盖** | 官方 App 安装器仍走 **busybox `mount -o loop`**；见 §5.4.1 魔改 APK |

**装魔改 APK 后为何有时还要「多传一次 CLI」**：APK 虽 bundle 新 CLI，但 `/data/local/Droidspaces/bin/droidspaces` 若已是 **410168 B 旧 loopfix**（如 `849250a4…`），App 覆盖安装与 `apply-loopfix.sh`（只比体积）都**不会**换成 `e0a80f9c…`。须显式 `install_loopfix_persistent.sh`。**不能只看 410168 B，要对 SHA256。**

构建/持久化：`tools/build_droidspaces_loopfix.sh`、`tools/install_loopfix_persistent.sh`  
App 升级把 CLI 盖回 **stock 461544 B** 后：`su -c 'sh /data/local/Droidspaces/bin/apply-loopfix.sh'`

### 5.4.1 魔改 APK（upstream-first + loop-scan fallback，TB520FU E2E ✅）

仅替换 `/data/local/Droidspaces/bin/droidspaces` **不能**修 App 新建 sparse（安装器走 Kotlin + `sparsemgr.sh`，与 CLI 二进制无关）。本仓库本地构建 **loopfix debug APK**，打入两枚 App 补丁并捆绑 loopfix CLI。

**挂载策略（尊重上游）**：先走与 upstream 相同的 **busybox / system `mount -o loop`**；仅在失败时 fallback 到 **高 minor 显式 `losetup` 扫描**（`mount_loop_scan.sh` / `_mount_loop_img`）。**全 Android 通用**，不做机型分支。

| 补丁（base `76cbd21`，见 `patches/README.md`） | 目标 |
|------|------|
| `droidspaces-android-loop-scan.patch` | `src/mount.c`（CLI 脏池；`max(sysfs, /sys/block/loopN+1)`，无 OEM 分支） |
| `sparsemgr-loop-scan.patch` | `assets/sparsemgr.sh`（migrate/resize → `_mount_loop_img`） |
| `sparseimageinstaller-loop-scan.patch` | `SparseImageInstaller.kt` + `assets/mount_loop_scan.sh` |
| `sparseimageinstaller-unmount-after-config.patch` | `ContainerInstaller.kt`（先写 config 再 umount） |

| 项 | 值 |
|----|-----|
| 构建 | `bash tools/apply_loopfix_vendor.sh`（WSL，重打补丁）→ `build_droidspaces_loopfix.sh` → `build_droidspaces_apk_loopfix.ps1` |
| 离线校验 | `tools/verify_apk_loopfix.ps1` |
| 产物 | `output/droidspaces-apk-loopfix/Droidspaces-loopfix-debug.apk` |
| 大小 / SHA256（当次） | **23157618 B** · `E05CC7D3A7618587A000D390733A72D436C8A28E6BEF3F46A1840696678EDD9B`（见 `SHA256SUMS`；改 Kotlin/资产后须重编） |
| 内含 CLI | loopfix **410168 B** · SHA256 `e0a80f9c1287c5e67e796379dfa94db7594d5f3970fe7e96a2884363b5c4584d` |
| 安装注意 | **debug 签名**；须先卸 Play/GitHub 版 App；KSU 给 `com.droidspaces.app` root |
| **LF 门禁** | `build_droidspaces_apk_loopfix.ps1` / `.sh` 构建前拒绝 asset `*.sh` 含 CRLF；`verify_apk_loopfix.ps1` 解包后同样扫描 |

**TB520FU 现阶段结论（2026-06-20 晚，HA2452JQ）**：**联想平板 Droidspaces 正常可用**——用户手测 + 自动化复验均 PASS。魔改 APK 已装；CLI loopfix 410168 B 持久化；`debian-cli` / `debian13` 保留。

| 验证项 | 脚本 / 方式 | 结果 |
|--------|-------------|------|
| App 手装 4G sparse `sb` | 用户 UI | `Installation completed successfully!` |
| 已有 sparse 启停 + 网络 | `post_apk_e2e_check.sh` | check 全绿；ping/curl 200；**3× stop/start** |
| **从零模拟 App 安装**（mount 脚本 → 解压 ~916MB tar → 先 config 再 umount → start） | `full_apk_sparse_install_e2e.sh` | **PASS**（容器 `sb-e2e`，测完已删） |

曾踩坑见 **§5.4.2**（CRLF、`finally` 卡死）；当前构建已含修复。

**跨机型**：一加 PKR110（`Gold_bug`）✅ — 魔改 APK + 新 loopfix CLI；`post_apk_e2e` / `full_apk_sparse_install_e2e` / `loop_stress_named sb 10` 均 PASS（§12.5、`ONEPLUS-PKR110-COMMUNITY-KERNEL-交接.md` §6）。**注意** sysfs `max_loop=16` 时旧 loopfix（同 410168 B）仍会挂载失败，须 `e0a80f9c…` 构建。一加线 2 stock APK #9 10/10 仍成立（无 loopfix）。

**stock vs loopfix 指纹（TB520FU 实机，2026-06-21）**

| 二进制 | 大小 | SHA256 |
|--------|------|--------|
| stock（`droidspaces.bak.pre-loopfix`） | 461544 B | `3538a2b7…9b5df` |
| loopfix（当前部署） | 410168 B | `e0a80f9c…3b5c4584d` |

### 5.4.2 魔改 APK 实机踩坑：CRLF 与安装器收尾（2026-06-20）

专档记录两次**与 mount 策略无关**的失败，避免误判为「busybox-first 不行」或「内核不支持 loop」。

#### 现象 A：`Failed to mount sparse image`（光速失败）

| 项 | 内容 |
|----|------|
| 日志 | `[SPARSE] Mounting sparse image...` → 数秒内 `Failed to mount sparse image` |
| 实机 trace | `mount_loop_scan.sh[4]: set: -: unknown option`（`set -eu\r`） |
| 根因 | `assets/mount_loop_scan.sh`、`sparsemgr.sh` 在 Windows 上被保存为 **CRLF**；Android `/system/bin/sh` 在 `set -eu` 即退出，**busybox / system mount 与 loop-scan fallback 均未执行** |
| 对照 | 同机 `ds_mount_loop.sh`（LF）→ loop63 挂载 ✅ |
| 修复 | 以 `patches/mount_loop_scan.sh`（LF）覆盖 vendor 资产；`sparsemgr.sh` 转 LF；`.gitattributes` 已设 `*.sh text eol=lf`；构建脚本 **CRLF 门禁**（§5.4.1 表） |

#### 现象 B：安装界面 30+ 分钟无变化（`sb2`，旧魔改 APK）

| 项 | 内容 |
|----|------|
| 最后一行 | `[SPARSE] Unmounting sparse image...` 后停滞 |
| 已完成 | 解压、`[POST-FIX] Fixes applied successfully` |
| 缺失 | `Writing container configuration...`（`ContainerInstaller` 第 5 步在 `extract()` 之后） |
| 根因 | `SparseImageInstaller.extract()` 的 `finally` 在写 config **之前** umount；`busybox sync` 在挂载仍有效时可能长时间阻塞 |
| 修复（vendor Kotlin） | 成功路径：**先** `ContainerInstaller` 写 `container.config`，**再** `unmountSparseImage()`；去掉 umount 前阻塞性 `sync`；`buildLoopDetachCmd` 改用 `losetup -a`（TB520FU `/proc/loops` 为空） |
| 救场 | `tools/recover_sb2_minimal.sh` 仅写 config（镜像已完好）；`tools/delete_containers.sh` 删测试容器 |

#### 验证脚本（TB520FU）

| 脚本 | 用途 |
|------|------|
| `post_apk_e2e_check.sh` | check + 启停 + ping/curl（`droidspaces show` 用 `grep -F sb`，勿用 ASCII `\|` 匹配 Unicode 表格） |
| `full_apk_sparse_install_e2e.sh` | **完整安装链路**：`mount_loop_scan.sh` → 解压 → 先 config 再 umount → start → 网络 → 3× stop/start → 清理 |
| `verify_sb_stopstart.sh` | 3× stop/start + ping 重试 |
| `delete_containers.sh` | stop + umount + losetup + `rm -rf` |
| `cleanup_loop_e2e.sh` / `detach_stale_loops.sh` | 清 `apk-e2e-sparse` / 幽灵 loop 绑定 |

#### 测试容器清理（2026-06-20）

用户验证通过后删除 **`sb`**、**`sba`** 两个 4G sparse 测试容器（各约 **967M** 实占，合计约 **1.9GB**）。保留 **`debian-cli`**、**`debian13`**。

### 5.5 跨机型：Droidspaces 自带 busybox（v6.3.0 方案 A，2026-06-21）

在 **未刷 Droidspaces 社区内核** 的原厂系统上，仅装 App v6.3.0、解压 **stock** `busybox-aarch64`（460280 B），用 `sparse_cli_app_compare.sh` / `sparse_selinux_loop_test.sh` 测试。

| 设备 | loop 池（当次） | Droidspaces **busybox** `mount -o loop` | toybox `mount -o loop` | `droidspaces check` |
|------|-----------------|----------------------------------------|------------------------|---------------------|
| **TB520FU** phase-2 | 48/64，APEX≈47 | ❌ `can't setup loop device`（重启后仍然） | ✅ 干净重启后成功 | ✅ |
| **小米 12S Ultra** thor | 44/45，APEX≈43 | ❌ **同上** | ✅ | ❌ 缺 PID/IPC ns |
| **一加 Ace 5 Pro** PKR110（原厂） | 53/54，APEX≈42 | ❌ **同上** | ✅ | ❌ 缺 PID/IPC ns |
| **一加 Ace 5 Pro** PKR110（**`6.6.89-Gold_bug`**） | ~55 bound，sysfs 16 | ❌ **仍同上** | ✅ | ✅ |
| **Pixel 8** shiba | 50/51，APEX=50 | （未装 DS） | ✅ | — |

**区分 busybox 来源（小米）**

| busybox 路径 | `mount -o loop` |
|--------------|-----------------|
| `/data/local/Droidspaces/bin/busybox`（App 自带） | ❌ 与 TB520FU 同错 |
| `/data/adb/ksu/bin/busybox`（SukiSU） | ✅ 成功 |

**结论**：失败集中在 **Droidspaces APK 内嵌 busybox** 的 loop 自动分配，**不是**联想独有问题，也**不是**换 KSU busybox 就能在 App 安装器里自动生效（安装器硬编码 App 路径，见上游 `SparseImageInstaller.kt`）。

**小米 12S Ultra 社区内核**：[`community-supported-devices.md`](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md) **无** `2203121C/thor` 条目；邻近机型为 **12T Pro / K50 Ultra（diting）** 的 GKI `5.10.252`（Star-ZER0），**不能**刷到 thor。方案 A 已证原厂 thor 缺 namespace，无法在本机跑容器或 #9 脏池 CLI 测试。

**一加 PKR110**：社区表有 ColorOS 16 + `6.6.89` 内核包；原厂缺 PID/IPC ns。**2026-06-20** 已刷 `Gold_bug`：App 4G sparse 容器 + **stock CLI #9 十轮 10/10**（无 loopfix）；裸 busybox 仍 ❌。见 §12.5、`ONEPLUS-PKR110-COMMUNITY-KERNEL-交接.md`。

原始日志目录：`output/sparse-precheck/`（gitignore，本地留存）。

### 5.6 SELinux permissive 证伪（2026-06-21）

脚本：`tools/sparse_selinux_loop_test.sh`（`setenforce 0` → 测 busybox/toybox → `setenforce 1` 恢复）。

| 设备 | permissive 后 Droidspaces busybox | permissive 后 toybox |
|------|-----------------------------------|----------------------|
| TB520FU | ❌ 不变 | ❌（当次池脏 `Too many open files`，非 SELinux） |
| 小米 12S Ultra | ❌ 不变 | ✅ |
| 一加 Ace 5 Pro | ❌ 不变 | ✅ |

**结论**：**不是 SELinux enforcing 拒绝挂载**；issue/PR 中勿写「permissive 可解」。

### 5.7 TB520FU 重启后对照（2026-06-21）

重启后 loop 仍 **48/64 已绑定**（APEX 开机即占满），但 toybox 路径恢复：

| 路径 | 重启后 |
|------|--------|
| Droidspaces busybox | ❌ 仍失败 |
| toybox `mount -o loop` | ✅ |
| 显式 `losetup loop48+` | ✅ |

---

## 6. KernelSU 模块隔离实验（2026-06-21）

### 6.1 方法

- **保留**：`droidspaces`（Daemon）、`zygisksu`、`zygisk-sui`
- **批量禁用后重启**：RescueBrick、magic_mount_rs、netproxy、scene_*、virtual-drm-daemon、zygisk_lsposed
- **逐一只开单模块**复测 smoke

### 6.2 结果

| 阶段 | toybox `mount -o loop` | CLI `--rootfs-img` |
|------|------------------------|---------------------|
| 仅 droidspaces+zygisk | SUCCESS | SUCCESS |
| 全部模块恢复 + 重启 | SUCCESS | SUCCESS |
| 单独 magic_mount_rs / netproxy / LSPosed / virtual-drm | SUCCESS | SUCCESS |

**结论**：

- **不是某一个 KSU 模块长期弄坏 loop**。
- 早期失败更符合 **loop 池瞬时脏状态** + **APEX 占槽边际**；重启可清零 CLI 路径。
- **但 App busybox 在「全模块开启 + 干净重启」下仍失败** → 与模块无关，是 **安装器实现问题**。

脚本：`tools/sparse_ab_module_isolate.sh`、`tools/sparse_ab_bisect_run.sh`

---

## 7. 性能 A/B（目录 vs sparse）

**环境**：`debian-cli` 同内容 rootfs；NAT；单次运行（2026-06-20）。

| 指标 | 目录（f2fs） | sparse（loop ext4） | 变化 |
|------|--------------|---------------------|------|
| `stat` ×500 `/etc/passwd` | 2197 ms | 2172 ms | ≈ 持平 |
| `ls -1 /usr/share` | 15 ms | 16 ms | ≈ 持平 |
| `find /usr/share -maxdepth 2` | 27 ms | 43 ms | sparse 略慢 |
| `find /root -maxdepth 2` | 7 ms | 8 ms | ≈ 持平 |
| **`apt-get update -qq`** | **14588 ms** | **4490 ms** | **约 −69%** |

**解读**：收益集中在 **apt / 大量小文件元数据**；微基准 `stat` 看不出差别。与上游「f2fs 上推荐 sparse」一致。

---

## 8. 无 SD 卡时的相关讨论（摘要）

| 手段 | 作用 |
|------|------|
| **sparse img** | 减轻 f2fs 百万 inode 压力；apt 明显改善 |
| **tmpfs** 挂 apt 缓存 / 编译目录 | 不改 rootfs 结构下的低成本提速 |
| **USB-C OTG ext4 U 盘** bind `~/projects` | 近似外置盘 |
| 换机带 SD 槽 | 块设备 ext4 直通容器（Droidspaces CLI 支持 `--rootfs-img` 块设备） |

---

## 9. 生产迁移：`debian-cli` → 32G sparse（2026-06-20）

### 9.1 执行

```bash
# 干净重启后
SIZE_G=32 sh /data/local/tmp/migrate_debian_cli_sparse.sh
```

脚本：`tools/migrate_debian_cli_sparse.sh`

### 9.2 结果

| 项 | 值 |
|----|-----|
| 镜像路径 | `/data/local/Droidspaces/Containers/debian-cli/rootfs.img` |
| 逻辑大小 | **32G** ext4（`df` 可见） |
| 实占 `/data` | **~2.1G** sparse（随使用增长） |
| 容器内已用 | ~1.9G / 32G |
| 网络 | NAT `172.28.1.2`（未变） |
| 配置 | `use_sparse_image=1`，`rootfs_path=.../rootfs.img` |
| 挂载 | CLI `--rootfs-img` 成功（`loop48`） |

### 9.3 备份（验证后可删）

```text
/data/local/Droidspaces/Containers/debian-cli/rootfs.dir.bak   (~1.8G)
/data/local/Droidspaces/Containers/debian-cli/container.config.pre-sparse
```

确认正常后释放空间：

```bash
droidspaces --name=debian-cli stop
rm -rf /data/local/Droidspaces/Containers/debian-cli/rootfs.dir.bak
droidspaces --name=debian-cli start
```

### 9.4 日常注意

- 已部署 **loopfix** 时：`start` 报 `LOOP_SET_FD` 可先确认二进制为 loopfix 体积（~410168 B），再 `apply-loopfix.sh`；**不必**每次先 reboot。
- 仍为 **stock** CLI 或 loopfix 未生效时：失败报 `LOOP_SET_FD` → **重启** 再 start（旧流程）。
- **stock APK**：勿在 App 里 Sparse 新建；用 CLI + `migrate`、目录模式，或改装 **魔改 APK**（§5.4.1）。
- **魔改 APK**：可 App 新建 sparse（TB520FU 已验）；重装/覆盖时注意仍捆绑 loopfix CLI。
- stock App 升级可能覆盖 `droidspaces` 为 stock → 跑 `apply-loopfix.sh` 或依赖模块 hook 恢复。
- `debian13` 仍为目录模式（11G），未迁移。

---

## 10. 工具脚本索引

| 脚本 | 用途 |
|------|------|
| `migrate_debian_cli_sparse.sh` | **生产迁移**目录 rootfs → sparse img |
| `cleanup_test_containers.sh` | 删除 A/B 测试容器释放空间 |
| `sparse_cli_app_compare.sh` | App busybox vs toybox vs CLI 对比 |
| `sparse_ab_phase0_check.sh` | 环境 + loop 烟雾测试 |
| `sparse_ab_manual_mount.sh` | 手动 losetup + 目录模式（变通） |
| `sparse_ab_cleanup_loops.sh` | 清理 loop48–63 |
| `sparse_ab_module_isolate.sh` | KSU 模块批量禁用/恢复 |
| `sparse_ab_bisect_run.sh` | 单模块隔离复测 |
| `build_droidspaces_loopfix.sh` | 编译 loop-scan 补丁 CLI |
| `build_droidspaces_apk_loopfix.ps1` / `.sh` | 构建魔改 debug APK（双 App 补丁 + 捆绑 loopfix CLI） |
| `verify_apk_loopfix.ps1` / `.sh` | 离线校验 APK（`sparsemgr`、LF-only `*.sh`、CLI、DEX） |
| `post_apk_e2e_check.sh` | 装后 E2E：check、启停、ping/curl、3× stop/start |
| `verify_sb_stopstart.sh` | 单容器多轮 stop/start + ping |
| `delete_containers.sh` | 按名删容器（先 `droidspaces stop`） |
| `cleanup_loop_e2e.sh` / `detach_stale_loops.sh` | 清 e2e 残留 loop |
| `recover_sb2_minimal.sh` | 安装卡在 umount 后仅补写 `container.config` |
| `deploy_droidspaces_loopfix.sh` / `install_loopfix_persistent.sh` | 部署并持久化 loopfix |
| `loop_stress_no_reboot.sh` | 多轮 stop/start（默认 `debian-cli`；联想常需 loopfix） |
| `loop_stress_named.sh` | 同上，参数：`<容器名> <轮数>`（#9 实测用） |
| `sparse_busybox_quick.sh` | 裸 busybox vs toybox `mount -o loop` |
| `check_boot_slots.sh` | A/B 槽 boot 内核字串与 MD5 |
| `ds_mount_loop.sh` | 启动前手动 losetup 变通 |
| `sparse_issue_bundle.sh` | 只读 loop/设备信息采集（附 issue） |
| `sparse_oem_loop_smoke.sh` | 通用 busybox/toybox/losetup 烟雾（自动扫 loop 编号） |
| `sparse_selinux_loop_test.sh` | permissive 下 busybox vs toybox 证伪 |
| `xiaomi_scheme_a_install.sh` | 方案 A：装 APK + 等后端 + check/compare（host） |
| `diag_stat_compare.sh` / `diag_file_io*.sh` | 容器内 I/O 微基准 |

推送实机示例：

```powershell
$env:ANDROID_ADB_SERVER_PORT=5041
adb push tools/migrate_debian_cli_sparse.sh /data/local/tmp/
adb shell su -c "SIZE_G=32 sh /data/local/tmp/migrate_debian_cli_sparse.sh"
```

---

## 11. 待办与上游

| 优先级 | 项 |
|--------|-----|
| P1 | 用户确认后删除 `rootfs.dir.bak` |
| P1 | loopfix 已部署；文档化「App 升级后 `apply-loopfix.sh`」 |
| P2 | 向 [Droidspaces-OSS Issues](https://github.com/ravindu644/Droidspaces-OSS/issues) 提交：见草稿 [`UPSTREAM-ISSUE-DRAFT.md`](UPSTREAM-ISSUE-DRAFT.md)（跨机型 §5.5 + SELinux §5.6 已齐） |
| P1 | 魔改 APK 跨机型（PKR110 等）实机验证 | ⏳ 可选 |
| P2 | 上游合入：`sparsemgr` + `SparseImageInstaller` + CLI `mount.c` 三补丁 |
| P2 | 更新社区设备表 TB520FU 状态/备注（勿沿用过时 Partial 自评） |
| — | #9 stock CLI 脏池：PKR110 ✅（Gold_bug + stock CLI）；**thor 仍待**社区内核 |
| P2 | 可选：2–3 轮 `apt update` 取中位数；补 `git status` 基准 |
| P3 | phase-3 `max_loop=128`（低优先级；不保证修 App busybox 路径） |
| P3 | `tmpfs` apt 缓存 vs sparse 对照（目录模式优化上限） |

---

## 12. 跨机型 loop 池对比（2026-06-21，只读 adb）

**方法**：未刷 Droidspaces 的 root 机亦可采集（见 §15）。下同 Android **16** 对比更有意义；勿用社区表里过时的「Android 14」标签代指 TB520FU。

### 12.1 一加 Ace 5 Pro（PKR110，ColorOS 16，主力机只读）

| 项 | 值 |
|----|-----|
| 芯片 | SM8750（8 Elite；与 TB520FU 的 SM8650 **不同代**） |
| 内核 | `6.6.89-android15-8-...` |
| sysfs `max_loop` | **16**（= GKI `MIN_COUNT`，**不是**运行时池子上限） |
| 实际 loop 设备 / 已绑定 | **53 / 53**（见 loop52） |
| APEX 占用（`backing_file`） | **42** |
| 其余 | ColorOS **OPEX** 等（`system_ext/opex/*.opex`、`/data/oplus/os/opex/...`） |
| cmdline `max_loop=` | **无** |

**解读**：一加上 A16 也是 loop **高占用常态**（53/53 满），但内核通过 `LOOP_CTL_ADD` **把池子扩到 53**，不像联想原厂把上限 **卡在 48**。sysfs 写 16 易误导，应以 `ls /sys/block/loop*` / `losetup -a` 为准。

### 12.2 TB520FU（本仓库 phase-2，同期只读）

| 项 | 原厂 ZUI（历史） | phase-2（当前实测） |
|----|------------------|---------------------|
| sysfs `max_loop` | **48** | **64** |
| 已绑定 | ~47 | **48**（当次 adb） |
| APEX | ~47 | ~47（历史常态） |
| 空闲（粗算） | **~0** | **~16** |
| 池子行为 | 封顶 48，几乎无余量 | cmdline+`MIN_COUNT=64` 生效 |

### 12.3 Google Pixel 8（shiba，A16 原厂，2026-06-21）

| 项 | 值 |
|----|-----|
| 内核 | `6.1.145` GKI |
| sysfs `max_loop` | 16（误导） |
| loop 设备 / 已绑定 | **51 / 50** |
| APEX | **50** |
| `mount -o loop`（KSU busybox / toybox） | ✅ 近满池仍成功 |
| Droidspaces | 未装（设备自签名回锁，未继续方案 A） |

### 12.4 小米 12S Ultra（thor，`2203121C`，A15 原厂，2026-06-21）

| 项 | 值 |
|----|-----|
| 内核 | `5.10.236`（**非 GKI**） |
| loop / 绑定 | **45 / 44**，APEX **43** |
| sysfs `max_loop` | 0（误导） |
| toybox / KSU busybox `mount -o loop` | ✅ |
| Droidspaces busybox | ❌ 与 TB520FU 同错（§5.5） |
| 社区 Droidspaces 内核 | **无 thor 条目** |

### 12.5 一加 Ace 5 Pro（PKR110，2026-06-20/21）

**方案 A（原厂）**：App v6.3.0 stock 后端；loop **53/54**，APEX **42**；busybox/toybox/Selinux 见 §5.5–§5.6；`check` 缺 PID/IPC ns。

**刷社区内核后（`6.6.89-Gold_bug`，B 槽，SukiSU + AK3）**

| 项 | 结果 |
|----|------|
| `droidspaces check` | ✅ 全 required |
| App sparse 容器 `test`（4G） | ✅ 建容器 + `start` |
| **#9** `loop_stress_named.sh test 10` | ✅ **10/10**（stock CLI **461544**，无 loopfix） |
| 裸 DS busybox `mount -o loop` | ❌ `can't setup loop device` |
| toybox `mount -o loop` | ✅ |
| loop 绑定当次 | **~55**（sysfs `max_loop` 仍写 16） |

**对比联想（勿混两条路径）**：

- **App busybox 安装器（stock APK）**：TB520FU 上仅换 loopfix CLI **仍不可用**（§5.4）。**魔改 APK** 已 E2E ✅（§5.4.1）；`debian-cli` 日常仍靠 CLI 迁移 + loopfix。
- **CLI 停启脏池（#9）**：联想 stock CLI 需 **loopfix** 才稳 8–20 轮；一加 stock **10/10** → OEM loop 池差异，非「联想独毒」。

完整交接：`ONEPLUS-PKR110-COMMUNITY-KERNEL-交接.md`。

### 12.6 对比结论

| 维度 | 联想 TB520FU | 一加 PKR110 | 小米 thor | Pixel 8 |
|------|--------------|-------------|-----------|----------|
| 池子策略 | 紧（48→64） | 动态扩池 | ~45 封顶 | 动态扩池 |
| 高占用常态 | 是 | 是 | 是 | 是 |
| toybox auto loop | ✅（重启后） | ✅ | ✅ | ✅ |
| **DS busybox**（裸 `mount -o loop`） | ❌ | ❌（Gold_bug 仍 ❌） | ❌ | — |
| **App sparse 新建** | ✅ **魔改 APK**（§5.4.1）；stock ❌ | ✅ stock App 建 `test`（CLI 挂载） | 未测完整容器 | — |
| CLI #9 十轮 stop/start | stock ❌ → **loopfix** OK | stock **10/10** | 待 GKI 内核 | — |
| 说明「联想独毒」？ | **不能**（busybox 三家同错；联想特殊在池紧+CLI 脏池） | 同左 | 同左 | 同左 |

---

## 13. 责任分层（谁的问题）

| 层级 | 有没有问题 | 证据摘要 |
|------|------------|----------|
| **联想原厂内核** | 配置 **偏紧** | `max_loop=48` + APEX≈47 → 零余量；OEM 策略，非硬件坏 |
| **我们 phase-2 自编 GKI** | loop **未见编错** | `max_loop=64` 实机可读；~17 空闲；手动 `losetup`+`mount` 成功；`droidspaces check` 通过 |
| **Droidspaces 上游** | **有缺口** | **App 内嵌 busybox** 在 TB520FU/小米/一加同错（含 PKR110 Gold_bug）；**非 SELinux**（§5.6） |
| **loopfix（本仓库）** | **CLI `mount.c`** + **魔改 APK**（双 App 补丁） | CLI：联想脏池 8–20 轮 OK；App：TB520FU 魔改 APK E2E ✅；一加 stock CLI 无 loopfix 亦 10/10 |
| **使用方式** | 放大问题 | 频繁停启不重启易脏池；原厂 48 池更敏感 |
| **社区 Partial 标签** | 过时自评 | 提交时保守标注，**非**第三方定论 |

**不是**「联想坏了所以我们 kernel 编错了」：phase-2 有自由 loop 仍 `mount -o loop` 失败，证明瓶颈在 **用户态挂载路径**，不单在 kernel。自编 GKI 的大坑在 **boot+system_dlkm 成套 / AVB**（二屏类），与 loop sysfs 读数 64 矛盾时不混为一谈。

---

## 14. 只读采集命令（跨机型 / 主力机安全）

**仅读**，不 `dd` / `mount` / `losetup -d`。建议逐条执行：

```bash
adb shell su -c getprop ro.product.model
adb shell su -c getprop ro.build.version.release
adb shell su -c uname -r
adb shell su -c cat /sys/module/loop/parameters/max_loop
adb shell su -c "losetup -a 2>/dev/null | wc -l"
adb shell su -c "grep -h . /sys/block/loop*/loop/backing_file 2>/dev/null | grep -c apex || echo 0"
adb shell su -c "ls -d /sys/block/loop* 2>/dev/null | wc -l"
```

`free ≈ max(实际 loop 数, sysfs max_loop) - bound`；一加等机型 **sysfs max_loop 可能远小于实际 loop 数**，须看 `ls /sys/block/loop*`。

---

## 15. 一句话总结

**稀疏挂载在 TB520FU 上值得用（apt 约快 69%）**。**stock APK** 勿点 Sparse 新建（busybox 路径）；**CLI 迁移 + loopfix** 或 **魔改 APK**（§5.4.1–§5.4.2，本机安装+启停 E2E ✅）均可。魔改包另须 **LF-only shell 资产** 与 **先写 config 再 umount** 的安装器顺序。根因是「联想 loop 池偏紧 + Droidspaces **stock busybox** loop 分配弱」，非 SELinux、非联想独家。一加线 2 ✅：`Gold_bug` + stock CLI #9 10/10；魔改 APK 跨机型 ⏳（§12.5–§12.6）。**