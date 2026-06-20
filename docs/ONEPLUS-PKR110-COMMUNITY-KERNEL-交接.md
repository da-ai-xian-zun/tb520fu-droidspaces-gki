# 一加 Ace 5 Pro（PKR110）社区 Droidspaces 内核 — 交接文档

> **用途**：备份 boot → 刷社区适配内核 → 跑通容器 + 稀疏挂载 **#9**（stock CLI 脏池）。  
> **母项目**：`tb520fu-droidspaces-gki` · 稀疏专档 `SPARSE-MOUNT-RESEARCH.md` §12.5、§5.5  
> **日期**：2026-06-21 · **线 2 状态**：✅ **已完成**（2026-06-20 实机）

---

## 0. 结论速览

| 项 | 原厂（方案 A） | 刷 `6.6.89-Gold_bug` 后 |
|----|----------------|---------------------------|
| 社区表 | ✅ PKR110 / ColorOS 16 + `6.6.89` | — |
| `droidspaces check` | ❌ 缺 PID/IPC ns | ✅ **全 required 通过** |
| 裸 **busybox** `mount -o loop` | ❌ 与 TB520FU 同错 | ❌ **仍失败**（非联想独家） |
| toybox `mount -o loop` | ✅ | ✅ |
| App sparse 容器 | 未测完整容器（缺 ns） | ✅ **4G `test` 容器可建可跑** |
| **#9** stock CLI 脏池 10 轮 | 无法测（缺 ns） | ✅ **10/10**（无 loopfix） |

**分层勿混**（见专档 §5.1、§5.4）：

| 路径 | 联想 TB520FU | 一加 PKR110（Gold_bug） |
|------|--------------|-------------------------|
| **App busybox** 安装器 `mount -o loop` | ❌ **有 loopfix 仍失败** | ❌ 裸测仍失败；App 建 `test` 可走 **CLI 挂载** |
| **CLI** stop/start 脏池（#9） | stock ❌ → **loopfix** 8–20 轮 OK | stock **10/10**（无 loopfix） |

**证伪**：自编 GKI 不是脏池唯一变量；联想「特殊」在 **loop 池更紧 + CLI 脏池需 loopfix**，**不是** loopfix 能修好 App busybox 安装。

---

## 1. 设备信息

| 键 | 值 |
|----|-----|
| 型号 | OnePlus Ace 5 Pro **PKR110** |
| SoC | SM8750（8 Elite） |
| 系统 | ColorOS 16 / Android 16 · `PKR110_16.0.7.200(CN01)` |
| adb serial | `3B1F58E9B8L79PTQ` |
| 活动槽（实测） | **`_b`** |
| loop（DS 内核当次） | sysfs `max_loop=16`，实际绑定 **~55**（动态扩池） |

| 内核 | 字串 |
|------|------|
| 原厂 B 槽 | `6.6.89-android15-8-g7e1f3c083cc6-...` |
| 社区 B 槽 | **`6.6.89-Gold_bug`** |
| A 槽（未动） | `6.6.66-...`（OTA 遗留，勿作回退指望） |

---

## 2. 社区资源

来源：[community-supported-devices.md](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md)

| 项 | 链接 |
|----|------|
| 内核源码 | [cctv18/oppo_oplus_realme_sm8750](https://github.com/cctv18/oppo_oplus_realme_sm8750) |
| 下载（6.6.89 / A16） | [AnyKernel3_oki_6.6.89_Gold_bug.zip](https://raw.githubusercontent.com/Goldzxcbug/Droidspaces-kernel/refs/heads/main/OKI%E5%86%85%E6%A0%B8/AnyKernel3_oki_6.6.89_Gold_bug.zip) |
| 维护者 | @Goldzxcbug |

本地副本：`release/oneplus-pkr110/AnyKernel3_oki_6.6.89_Gold_bug.zip`  
手机副本：`Download/droidspaces-pkr110/AnyKernel3_oki_6.6.89_Gold_bug.zip`

**勿**刷 6.6.66 包若实机系统已是 6.6.89。

---

## 3. 实测流程（2026-06-20）

### 3.1 刷前

1. **adb 备份 B 槽**（活动槽）至 PC：  
   `backups/oneplus-pkr110/boot_b.img`、`vendor_boot_b.img`、`init_boot_b.img`  
   （`boot_b.img` MD5 `c7ba16c3757a01d091d5dfb11c0ed8c5` 已与机内核对）
2. Droidspaces App + **stock** CLI v6.3.0；**未**部署 loopfix  
   `wc -c /data/local/Droidspaces/bin/droidspaces` → **461544**
3. Bootloader 已解锁（机内 `locked` 属性可能为隐藏 BL 模块所致）

### 3.2 刷内核

| 项 | 实测选择 |
|----|----------|
| 途径 | **SukiSU Ultra** 刷 AnyKernel3 zip（Recovery 亦可） |
| 槽位 | **B**（当前槽；A 槽为 6.6.66 遗留，刻意不刷） |
| KPM 弹窗 | **跟随内核** |

刷后：`uname -r` → `6.6.89-Gold_bug`；`droidspaces check` → 全 required ✅；KernelSU root 仍在。

### 3.3 稀疏挂载 #9（stock CLI）

容器：`test`（App 创建，**4G sparse**，`use_sparse_image=1`）

```bash
adb push tools/loop_stress_named.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/loop_stress_named.sh test 10"
```

**结果**：`SUMMARY: ok=10 fail=0`；无 `LOOP_SET_FD` / `Resource busy`。

补充：`tools/sparse_busybox_quick.sh` 在同机 DS 内核上仍报 busybox ❌ / toybox ✅。

### 3.4 回滚

- 优先：fastboot / SukiSU 写回 PC 备份的 `boot_b.img`（及必要时 `vendor_boot_b` / `init_boot_b`）
- **勿**指望切到 A 槽回退（A 为 6.6.66，与当前 ROM 不匹配）

---

## 4. 风险（仍适用）

| 风险 | 说明 |
|------|------|
| 变砖 | 内核与 ROM 小版本不匹配；务必备份 B 槽三分区 |
| A 槽遗留 | 自动回退到 A 可能落到 6.6.66 |
| 保修 / 银行类 app | 解锁 BL 副作用 |

---

## 5. 与三条并行线

| 线 | 状态 |
|----|------|
| **线 1 联想** | TB520FU：loopfix + 上游 PR；脏池仍比一加敏感 |
| **线 2 一加** | ✅ **本文档任务完成** |
| **线 3 小米** | `XIAOMI-12S-ULTRA-THOR-DROIDSPACES-交接.md`；#9 仍待社区内核 |

---

## 6. 魔改 APK 跨机型（2026-06-20 晚，✅ 已完成）

线 2 在 **stock APK** + `Gold_bug` 上已完成 #9；本节为 **魔改 APK + 新 loopfix CLI**（`max(sysfs, /sys/block/loopN+1)` 扫描）复测。

### 6.1 部署

| 项 | 值 |
|----|-----|
| 设备 | `3B1F58E9B8L79PTQ` · `6.6.89-Gold_bug` |
| APK | `Droidspaces-loopfix-debug.apk` **23157618 B** · SHA256 `E05CC7D3…EDD9B` |
| CLI | loopfix **410168 B** · SHA256 `e0a80f9c…3b5c4584d`（须 `install_loopfix_persistent.sh`；旧版同体积 `849250a4…` **不能**在 sysfs=16、bound≈54 时挂载） |
| 已有容器 | 用户手装 4G sparse **`sb`**（`use_sparse_image=1`） |

**注意**：仅装新 APK 不够——若 CLI 仍为旧 loopfix（同 410168 B 但 hash 不同），`sb start` 会报 `Failed to attach … any free loop device`。必须推送并执行 `tools/install_loopfix_persistent.sh`。

### 6.2 实机结果

| 测试 | 结果 |
|------|------|
| `oneplus_apk_mount_smoke.sh` | PASS（busybox ❌ → `mount_loop_scan` → loop53 ✅） |
| `post_apk_e2e_check.sh` | PASS（ping/curl + **3× stop/start**） |
| `full_apk_sparse_install_e2e.sh` | PASS（完整安装链路；`sb-e2e` 测完已删） |
| `loop_stress_named.sh sb 10` | **10/10**（loopfix CLI；sysfs max_loop=16，实际 bound≈54） |

### 6.3 与线 2 对照

| 路径 | stock（线 2） | 魔改 APK（本节） |
|------|---------------|------------------|
| App busybox 安装 | 可走 CLI 挂载建 `test` | `mount_loop_scan` fallback ✅ |
| CLI #9 脏池 | stock **10/10**（无 loopfix） | loopfix **10/10** |
| sysfs=16 陷阱 | stock CLI 当时未踩（池动态扩） | **旧 loopfix 会挂**；**新 loopfix** 扫描 `/sys/block/loopN` 后正常 |

**结论**：魔改 APK 在一加 **Gold_bug** 上与 TB520FU 同等可用；一加特殊点在于 sysfs `max_loop=16` 误导，须用含 block-scan 的新 CLI，不能只看文件体积。

### 6.4 全新安装复验（2026-06-20，`sb` 已删后）

用户从 App 仓库下载 Debian 13 Minimal rootfs（`Downloads/…385f0403.tar.xz`，101275248 B）；`tools/oneplus_fresh_cycle.sh`：

| 步骤 | 结果 |
|------|------|
| 确认无 `sb` | ✅ |
| `mount_loop_scan` smoke | ✅ |
| 4G sparse + xz 解压 + 先 config 再 umount | ✅ |
| `sb-e2e` 启停 + ping/curl + 3× stop/start | ✅ |
| `loop_stress_named.sh sb-e2e 10` | **10/10** |
| 删 `sb-e2e` + 清临时文件 | ✅（Downloads 内 rootfs 保留，用户自删） |

### 6.5 为何测试里「CLI 要多传一次」（不是漏打补丁）

补丁栈里 **CLI 只改了 `mount.c` 一个文件**（`droidspaces-android-loop-scan.patch`），其余三枚是 App shell/Kotlin。多传一次是 **部署/升级路径** 问题：

| 现象 | 原因 |
|------|------|
| 装新魔改 APK 后 CLI 仍是 `849250a4…` | 设备上已有 **同体积** 旧 loopfix（410168 B）；App 后端认为已安装，未覆盖 |
| `apply-loopfix.sh` 不帮忙 | 只在校验 **体积**（stock 461544 ↔ loopfix 410168），不比较 SHA256 |
| 一加上旧 loopfix 挂 | 缺 `read_max_loop()` 的 `/sys/block/loopN` 扫描；sysfs 写 16 时扫不到 loop50+ |

**标准动作**（装/升级魔改 APK 后）：`install_loopfix_persistent.sh` + `sha256sum` 确认为 `e0a80f9c…`。见 `patches/README.md`。

---

## 7. 相关脚本

| 脚本 | 用途 |
|------|------|
| `tools/check_boot_slots.sh` | 对比 A/B 槽内核字串与 MD5 |
| `tools/loop_stress_named.sh` | `#9` 多轮 stop/start（参数：容器名、轮数） |
| `tools/sparse_busybox_quick.sh` | 裸 busybox vs toybox `mount -o loop` |
| `tools/oneplus_fresh_cycle.sh` | 删旧容器 → 官方 rootfs 全新 sparse 安装 → 压测 → 清理 |
| `tools/install_loopfix_persistent.sh` | 部署/锁定 loopfix CLI（装 APK 后必跑） |
| `tools/build_droidspaces_apk_loopfix.ps1` | 构建魔改 APK（PC 侧，无 adb） |