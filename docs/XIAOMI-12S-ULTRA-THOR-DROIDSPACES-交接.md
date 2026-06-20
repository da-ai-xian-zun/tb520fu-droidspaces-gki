# 小米 12S Ultra（thor）Droidspaces 内核适配 — 交接文档

> **用途**：给新对话 / 新 agent 单独接手「thor 内核 + Droidspaces + 稀疏挂载 #9」用。  
> **母项目**：`tb520fu-droidspaces-gki`（联想平板稀疏挂载研究）；thor 为**旁路设备**，证据链见 `docs/SPARSE-MOUNT-RESEARCH.md` §5.5、§12.4。  
> **日期**：2026-06-21

---

## 0. 先读结论（别重复踩坑）

| 问题 | 结论 |
|------|------|
| Droidspaces 社区表有 thor 吗？ | **没有** `2203121C` / thor 条目 |
| 能刷 diting（12T Pro）社区 OKI 吗？ | **不能盲刷**；同 SM8475 但设备树/厂商模块不同，变砖风险高 |
| 小米官方开源 thor 内核了吗？ | **没有**；[MiCode #8279](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/8279) 仍 Open（2022 至今） |
| 原厂 thor 能跑 Droidspaces 容器吗？ | **不能**；`droidspaces check` 缺 PID/IPC namespace |
| 原厂 busybox sparse 失败吗？ | **是**；与 TB520FU 同错（已测，非联想独家） |
| 目标是什么？ | ① 让 `droidspaces check` 通过；② 跑完整容器；③ 补稀疏挂载清单 **#9**（stock CLI 脏池，证「非自编 GKI 搞坏」） |

**不要写进 issue/对外表述**：「刷 diting 包就能用」「小米没开源所以 Droidspaces 不支持」——应写「社区无 thor 条目，需设备专属 GKI/内核构建」。

---

## 1. 设备清单（维护者实机）

| 键 | 值 |
|----|-----|
| 机型 | Xiaomi 12S Ultra |
| codename | **thor** |
| 型号 | **2203121C**（国行） |
| SoC | **SM8475** Snapdragon 8+ Gen 1 |
| adb serial | `86be9132`（会话时；以 `adb devices` 为准） |
| 系统（实测） | **Android 15**（非 16） |
| 内核（实测） | `5.10.236`（**非 GKI** 原厂树） |
| loop 池（实测） | 45 设备 / 44 绑定，APEX≈43 |
| Root | 已 root（KernelSU 系；具体版本接手后 `adb shell su -c id` 确认） |
| Droidspaces | App **v6.3.0** stock 已装；`busybox` 对比已做 |
| `droidspaces check` | ❌ 缺 PID/IPC ns |

---

## 2. 社区与源码现状（2026-06-21 调研）

### 2.1 Droidspaces 官方社区表

- 文档：[community-supported-devices.md](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/community-supported-devices.md)
- **无 thor / 12S Ultra / 2203121C**
- **邻近条目**（同代 8+，勿混为 thor）：

| 设备 | codename | 内核 | 维护者 | 能否刷 thor |
|------|----------|------|--------|-------------|
| Redmi K50 Ultra / 12T Pro | **diting** | GKI `5.10.252` | Star-ZER0 | ❌ 禁止盲刷 |
| Redmi K60 / POCO F5 Pro | mondrian | GKI `5.10.252` | Star-ZER0 | ❌ |
| Xiaomi Pad 6 Pro | liuqin | GKI `5.10.252` | Star-ZER0 | ❌ |

Star-ZER0 发布：[android_gki_kernel_5.10_common releases](https://github.com/Star-ZER0/android_gki_kernel_5.10_common/releases/latest)（AnyKernel3 形态，面向上表机型）。

### 2.2 小米官方内核开源

- 组织：[MiCode/Xiaomi_Kernel_OpenSource](https://github.com/MiCode/Xiaomi_Kernel_OpenSource)
- **thor 完整树未发布**；issue [#4782](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/4782)、[#8279](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/issues/8279) 长期未关
- 同族已开源机型（参考用，**不等于 thor 可直接用**）：12 Pro（zeus）、12T Pro（diting）等

### 2.3 第三方内核树（非 Droidspaces 成品）

| 来源 | 仓库 | 说明 |
|------|------|------|
| LineageOS | [android_kernel_xiaomi_sm8450](https://github.com/LineageOS/android_kernel_xiaomi_sm8450) + [android_device_xiaomi_thor](https://github.com/LineageOS/android_device_xiaomi_thor) | thor 官方 Lineage 支持；[build 文档](https://wiki.lineageos.org/devices/thor/build/) |
| 社区 SM8475 | [LowTension/android_kernel_xiaomi_sm8475](https://github.com/LowTension/android_kernel_xiaomi_sm8475) | CLO 5.10 全量树，**非** Droidspaces 预置 |

### 2.4 推荐技术路线（按优先级）

```text
路线 1（推荐）  Star-ZER0 5.10 GKI 工作流 + thor 厂商模块/DTB
                从 stock boot 解包 vendor_dlkm、dtbo，对齐 kABI
                打 Droidspaces 5.10 kABI patch + 容器相关 defconfig

路线 2（备选）  Lineage android_kernel_xiaomi_sm8450 为底
                叠加 Droidspaces 补丁；工作量大，且与 HyperOS 原厂分区差异大

路线 3（禁止）  直接刷 diting/mondrian AnyKernel3 到 thor
```

---

## 3. 接手目标与验收

### 3.1 阶段目标

| 阶段 | 目标 | 验收命令 |
|------|------|----------|
| P0 | 摸清 BL / slot / 分区 / 当前 boot 指纹 | `getprop ro.boot.verifiedbootstate`、`uname -r`、`ls -l /dev/block/by-name/boot*` |
| P1 | 产出可启动的 Droidspaces 内核（thor） | 重启进系统，`uname -r` 含预期版本串 |
| P2 | Droidspaces 能力 | `adb shell su -c droidspaces check` → **全绿** |
| P3 | 稀疏挂载 #9 | stock CLI（~461544 B）`loop_stress_no_reboot.sh` 10 轮；记录是否 `LOOP_SET_FD` |
| P4 | 可选：社区表 PR | 向 Droidspaces-OSS 提交 thor 行 + 下载链接 |

### 3.2 稀疏挂载专用（P3 细节）

母项目脚本（可 push 到 thor）：

- `tools/loop_stress_no_reboot.sh` — stock CLI 脏池
- `tools/sparse_cli_app_compare.sh` — busybox/toybox/CLI 对照
- `tools/sparse_issue_bundle.sh` — 只读采集

**必须**用 **stock** `droidspaces` 二进制测 #9，不要用 loopfix。

---

## 4. 构建参考（路线 1 详述）

### 4.1 依赖与参考仓库

```bash
# 上游 GKI 5.10（Star-ZER0 维护）
git clone https://github.com/Star-ZER0/android_gki_kernel_5.10_common.git
cd android_gki_kernel_5.10_common
#  checkout 与社区 diting 包一致的 tag，例如 android12-5.10-2026-04_r1（以 release 说明为准）

# Droidspaces 补丁来源
git clone https://github.com/ravindu644/Droidspaces-OSS.git
#  查看 Documentation/ 与 v6.3.0 的 GKI 5.10 kABI patch（非 6.1 的 001.GKI-below-6.12-...）
```

### 4.2 从 thor 原厂提取（无 MiCode 树时的关键）

在 **已 root 的 thor** 上或从 **完整原厂 boot.img**：

```bash
# 示例：解包 boot（在 PC 上）
# unpack_bootimg --boot_img boot_thor_stock.img --out boot_unpacked

# 需对齐并留存：
# - Image（kernel）
# - vendor_boot / vendor_dlkm（若有）
# - dtbo.img
# - 内核 vermagic / cmdline / androidboot 相关属性
adb shell su -c "uname -r"
adb shell su -c "zcat /proc/config.gz"   # 若可读
adb shell su -c "ls -l /vendor_dlkm/lib/modules/ 2>/dev/null | head"
```

**TB520FU 母项目**的 Bazel GKI 流程（6.1）**不能原样套用**；thor 走 **5.10 GKI + AnyKernel3** 或 fastboot `boot.img`，参考 Star-ZER0 / Goldzxcbug 的 OKI 打包方式，但 **device.mk / 模块列表必须 thor 化**。

### 4.3 Droidspaces 内核配置要点

对照 Droidspaces-OSS `Documentation/Installation-Android.md` 与 TB520FU 母项目 `patches/tb520fu-r13-droidspaces-minimal.diff` 的**意图**（不是照抄文件）：

- PID/IPC namespace 相关配置必须启用（原厂缺此项 → check 失败）
- `CONFIG_BLK_DEV_LOOP`、容器、cgroup、namespace 等按官方 checklist
- kABI：使用 **5.10 对应** 的 Droidspaces patch，勿用 6.1 的 `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`
- loop 池：thor APEX≈43/45，可考虑 `CONFIG_BLK_DEV_LOOP_MIN_COUNT` + cmdline `max_loop=`（参考 TB520FU phase-2 思路，但 **不保证** 修 App busybox）

### 4.4 刷入与回滚

| 项 | 说明 |
|----|------|
| Bootloader | Droidspaces 社区内核通常要求 **BL 解锁**；接手前先 `fastboot oem device-info` 或小米解锁状态 |
| 备份 | 维护者自行 **9008 / fastboot 备份当前 boot**（接手文档不代做） |
| 刷入形态 | 优先 **AnyKernel3 zip**（与 diting 发布同形态）或 fastboot flash boot |
| 回滚 | 保留 stock `boot.img` + 已知能启动的 slot；刷失败用 fastboot 写回 |

---

## 5. 与母项目稀疏研究的接口

| 母项目证据 | thor 适配后要补什么 |
|------------|---------------------|
| busybox 跨机型失败 ✅ | 可选：GKI 机上再跑一次 `sparse_cli_app_compare.sh` |
| SELinux 证伪 ✅ | 不必重复 |
| #9 stock CLI 脏池 ⏳ | **thor 刷通后首要补项**（原厂 5.10 非 GKI 上跑不了容器，GKI 后测） |
| 「非自编 GKI」 | thor 用 **社区/自构建 GKI**，与 TB520FU phase-2 **独立**；证的是上游 stock CLI 行为 |

日志建议目录：`output/sparse-precheck/thor/`（本地，gitignore）。

---

## 6. 禁止事项（避免丢脸）

1. ❌ 说「刷 diting 的 Star-ZER0 包到 thor 就行」
2. ❌ 说「小米没开源内核所以 loop/sparse 是小米独毒」
3. ❌ 用 TB520FU 的 6.1 GKI 镜像或 `tb520fu-droidspaces-phase2-images.zip` 刷 thor
4. ❌ 在 `#9` 测试中使用 loopfix 二进制
5. ❌ 未 `droidspaces check` 通过就跑 `loop_stress` 并宣称 CLI 脏池结论

---

## 7. 接手后第一步（复制执行）

```bash
# 1) 确认设备
adb devices -l
adb -s 86be9132 shell getprop ro.product.device          # 期望 thor
adb -s 86be9132 shell getprop ro.product.model
adb -s 86be9132 shell su -c "uname -r"
adb -s 86be9132 shell su -c "droidspaces check" || true

# 2) 只读采集（安全）
adb push tools/sparse_issue_bundle.sh /data/local/tmp/
adb -s 86be9132 shell su -c "sh /data/local/tmp/sparse_issue_bundle.sh"

# 3) 确认 BL / 备份状态（维护者口头确认 9008 boot 备份后再刷写）
fastboot -s 86be9132 getvar unlocked
```

---

## 8. 相关链接

- [Droidspaces Installation-Android](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Installation-Android.md)
- [Star-ZER0 GKI 5.10](https://github.com/Star-ZER0/android_gki_kernel_5.10_common)
- [LineageOS thor](https://wiki.lineageos.org/devices/thor/)
- 母项目专档：[SPARSE-MOUNT-RESEARCH.md](SPARSE-MOUNT-RESEARCH.md)
- 母项目 issue 草稿：[UPSTREAM-ISSUE-DRAFT.md](UPSTREAM-ISSUE-DRAFT.md)

---

## 9. 待维护者确认后写入

- [ ] Bootloader 是否已解锁
- [ ] Root 方案（KernelSU / SukiSU 版本）
- [ ] 当前 HyperOS 版本号 / 完整 build fingerprint
- [ ] 是否接受「先解锁 BL 再刷 Droidspaces 内核」
- [ ] stock `boot.img` 9008 备份路径（本地）