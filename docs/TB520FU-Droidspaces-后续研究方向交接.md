# TB520FU Droidspaces/GKI 后续研究方向交接

> 目标读者：接手研究的 agent。  
> 当前日期：2026-06-15
> 设备：Lenovo TB520FU / Yoga Tab Plus，Qualcomm SM8650，平台名出现 `pineapple/lapis`。  
> 当前安全状态：已回滚 stock `boot_a`，设备正常启动，slot `_a`，userdata 未清。

### GitHub 发布仓库（2026-06-15 更新）

- **Git 仓库**：脚本、`patches/`、文档、`release/` 文本模板 — 供 clone 审查与复现（`docs/BUILD.md`）
- **系统**：维护者实机为 **国际版（ROW）** ZUI，**非国行系统**
- **GitHub Release**：`tb520fu-droidspaces-phase2-images.zip` — **四镜像**（`init_boot_a` SukiSU + 三件套）+ README，无脚本
- **联想固件**：维护者用 LOLINET ROW 包；国行 ZUI 用户自备国内渠道固件，未在国行上验证
- **不进 Release**：xbl/9008 工具、脚本、stock ROM
- **未解决（本仓库）**：Droidspaces sparse 容器安装失败 → 目录模式规避；见 §5.18
- 许可研究见 `docs/COMPLIANCE.md`

## 0. 当前不可再重复的低价值动作

不要继续盲刷这些东西：

- 自编 vanilla/stamped/Droidspaces R13 boot。
- OKI/社区通用 AnyKernel 包，除非明确有人验证 TB520FU 或同 ZUI/lapis 设备可用。
- 旧 Lenovo `6.1.68` 开源包产物。

这些都已经实机验证过，不是“可能没刷对”的状态。

## 1. 已证实事实

### 1.1 stock/certified kernel

`stock boot_a`、完整 9008 包 `boot.img`、Google official certified R13 的 kernel 二进制完全相同：

```text
kernel SHA256:
a9f8c34f2b6758ad737e7488c30ad5a842757ca472791b56208714c8d7b9add7

release:
6.1.112-android14-11-g75d944e80501-ab13981564
```

因此“刷官方 certified R13”不是新方案，等价于 stock kernel。

### 1.2 stock kernel 不满足 Droidspaces

stock `/proc/config.gz` 缺 Droidspaces 关键项：

```text
# CONFIG_SYSVIPC is not set
# CONFIG_POSIX_MQUEUE is not set
# CONFIG_PID_NS is not set
CONFIG_IPC_NS absent / not enabled
```

### 1.3 自编 R13 卡死不是 Droidspaces patch 导致

实测：

- R13 + Droidspaces：二屏卡死，ADB 可用。
- R13 vanilla：二屏卡死，ADB 可用。
- R13 stamped vanilla：版本串对齐 stock 后仍二屏卡死，ADB 可用。
- 模块全关、`su` 不可见后，再刷 stamped vanilla R13，仍二屏卡死。

所以 Droidspaces patch、`maybe-dirty`、root 模块/LSP 都不是主因。

### 1.4 full IKCONFIG 不是解释

full config diff 结果：

```text
stock vs official certified: identical
stock vs selfbuilt vanilla: identical
stock vs selfbuilt stamped: identical
stock vs selfbuilt Droidspaces: only expected IPC/PID namespace changes
```

因此不要再只靠 `.config` 搜漏项。

### 1.5 二屏失败的可见症状包括 audio/soundtrigger/AGM，但不再视为唯一主因

失败时典型表现：

```text
sys.boot_completed: empty
bootanim: running
media.audio_flinger: not found
media.audio_policy: not found
audioserver / android.hardware.audio.service_64 进程存在
```

旧 debuggerd 栈显示关键链：

```text
/vendor/lib64/libagm.so device_init
/vendor/lib64/hw/audio.primary.pineapple.so
/vendor/lib64/hw/sound_trigger.primary.pineapple.so
android.hardware.soundtrigger@2.3-impl.so
audioserver AudioFlinger / AudioPolicyService
```

### 1.6 vendor 模块 CRC 简单不匹配也不是解释

抽取 stock 正常系统里的 audio vendor modules，与自编 R13 `Module.symvers` 对比：

```text
模块引用且存在于 selfbuilt Module.symvers 的符号：CRC 全部匹配
缺失项：主要是音频模块之间互相导出的符号，不是 vmlinux 主内核符号
```

并且失败时音频相关模块已经在 `/proc/modules` 中 loaded。

### 1.7 最新主线：自编 boot 没有配套 system_dlkm，导致 GKI protected modules 身份断裂

最新离线研究把主线从“audio/杜比单点卡死”推进到了 **boot Image 与 system_dlkm 不成套**：

- stock/certified kernel 启动时，`system_dlkm/modules.load` 里 60 个模块约 55 个已加载。
- stamped vanilla 自编 boot 二屏环境里，同一份 `system_dlkm/modules.load` 只有约 5 个已加载。
- 早期 Droidspaces 自编 boot 二屏环境里，`system_dlkm/modules.load` 甚至约 0 个已加载。
- 同时 vendor_dlkm 仍能加载大量模块，所以这不是“模块加载系统整体坏了”，而更像 GKI/system_dlkm 保护链断了。

关键机制见第 5.10 节。当前判断：此前只替换 `boot.img` 里的 kernel Image 是不完整实验；对自编 GKI 来说，至少应把同一次构建产出的 `system_dlkm.img` 一起作为候选验证对象。

## 2. 主要研究问题

### 2.1 Google certified Image 与本地 source-build Image 为什么运行行为不同？

同 tag、同 IKCONFIG，本地构建出的 Image hash 不同且会卡：

```text
certified/stock kernel:
a9f8c34f2b6758ad737e7488c30ad5a842757ca472791b56208714c8d7b9add7

local vanilla source-build:
b1034193d2f54ee789ce91ff3f2a67bc09677245ffc3328a67ac1756ed20db8a

local stamped source-build:
7108d678afed15afb94375198d37eda5a2fb2dadb44ff60cf9e8741e173a299c
```

需要研究：

- 官方 certified R13 的真实 manifest / build number / Kleaf 参数。
- 本地 manifest 是否与官方发布完全一致，尤其 `.repo/manifests`、`kernel/build`、`kernel/configs`、prebuilts。
- `kernel_aarch64` 目标是否足够，还是官方发布使用了 CI 特定参数。
- LTO、trim、KMI symbol list、additional KMI list 是否在构建产物层面产生运行时差异。

### 2.2 audio/soundtrigger/AGM 具体卡在哪个内核交互？

建议在失败环境中抓：

```text
logcat -b all -d -v threadtime
dmesg / pstore / ramoops
tombstones /data/tombstones
ANR /data/anr
lshal / hwservicemanager audio/soundtrigger service 状态
/proc/modules
/proc/interrupts
/sys/kernel/debug/tracing/trace 如果可用
```

重点 grep：

```text
agm
soundtrigger
AudioFlinger
AudioPolicy
pal
q6
adsp
lpass
gpr
spf
SSR
subsys
firmware
Dolby
DAX
```

### 2.3 Dolby/DAX 是否只是乘客还是触发点？

设备有 Dolby 音效。它可能在 audio effect / policy / HAL 扩展里参与初始化，但目前证据更指向 QCOM AGM/soundtrigger。建议只做日志和配置确认，不要先改 vendor/product 分区。

可查：

```text
getprop | grep -iE 'dolby|dax|ds|audio'
find /vendor/etc /odm/etc /product/etc -iname '*dolby*' -o -iname '*dax*' -o -iname '*audio_effect*' -o -iname '*audio_policy*'
logcat -d | grep -iE 'dolby|dax|audio_effect|agm|soundtrigger'
```

### 2.4 b 槽 / 6.1.118 是否有研究价值？

设备备份里 `boot_b` 是 6.1.118，但 b slot 标记 unbootable，用户切 b 后回退 a。理论上可能有 OTA 残留组合：

```text
boot_b 6.1.118 + vendor_boot_b + dtbo_b + vbmeta_b
```

但这是高风险方向，不能直接实机尝试。若研究，先离线解包比较：

- `boot_a` vs `boot_b` kernel/config/version。
- `vendor_boot_a` vs `vendor_boot_b` ramdisk/bootconfig/modules load order。
- `dtbo_a` vs `dtbo_b`。
- slot metadata 为什么 b unbootable。

### 2.5 社区适配方向

关键词：

```text
TB520FU Droidspaces
Yoga Tab Plus Droidspaces
pineapple lapis GKI 6.1.112 6.1.118
SukiSU Ultra Droidspaces pineapple
AGM soundtrigger GKI selfbuilt
Qualcomm SM8650 android14-6.1 GKI audio HAL
```

需要找的是“明确验证过同平台/同 vendor audio 栈”的 patch 或包，不是泛用 AnyKernel。

## 3. 关键本地路径

```text
主复盘文档:
D:\project\新建文件夹\TB520FU-Droidspaces-二屏卡死复盘与方向重判.md

分析目录:
C:\tb520fu-kernel-diff-20260614

stock boot backup:
D:\project\新建文件夹\tb520fu-droidspaces-images3\images\boot_a.img

stock init_boot backup/current SukiSU backup:
D:\project\新建文件夹\tb520fu-droidspaces-images3\images\init_boot_a.img

完整 9008 包 stock init_boot:
D:\TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127\image\init_boot.img

失败诊断目录:
D:\project\新建文件夹\tb520fu-no-su-modules-off-stamped-diag-20260614-015524
D:\project\新建文件夹\tb520fu-stamped-vanilla-second-screen-diag-20260613-192643
```

## 4. 当前建议（2026-06-15 更新）

**已证实可行路径**：不解锁 + 9008 三件套（`boot_a` + `super_5/system_dlkm` + `vbmeta_a`）。

**当前状态**：**二阶段三件套已刷入并过二屏**（§5.17–5.18）；`max_loop=64` 与全量 GKI 推荐 defconfig 已实机验证。**sparse 容器安装仍失败**（§5.18）——根因已从「缺 loop」修正为「APEX 占槽 + App `mount -o loop` 自动 losetup 失败」；**目录模式**安装容器为当前可行路径。

短期路线：

1. Droidspaces 用 **目录模式**装 Debian（不要用 sparse/image 模式）。
2. 容器跑通后再考虑：phase-3 `max_loop=128` 实验，或向 Droidspaces 上游提 issue（App 应改用 CLI 的 `ioctl loop_attach`，见 §5.18）。
3. 继续用 9008 最小 rawprogram；不要只刷 boot；不要刷 `init_boot_a`（SukiSU）。
4. 保留 `rollback_triplet.cmd`；vbmeta 回滚用 live SukiSU 65536B 版本。
5. GitHub 开源仓库：`D:\project\tb520fu-droidspaces-gki\`（脚本 + 文档，镜像走 Release 另传）。

---

## 5. 2026-06-14 研究：自编 GKI 与 certified GKI 差异根因分析

> 本轮为离线分析，未连接设备，未刷机。

### 5.1 编译器/构建参数层面：排除

从 `C:\tb520fu-kernel-diff-20260614\summary.tsv` 提取的 `Linux version` 字符串显示：

| 镜像 | 编译器 | 优化标志 |
|------|--------|----------|
| stock / certified R13 | clang 17.0.2 (`d9f89f4d...`) | `+pgo +bolt +lto -mlgo` |
| selfbuilt vanilla R13 | clang 17.0.2 (`d9f89f4d...`) | `+pgo +bolt +lto -mlgo` |
| selfbuilt stamped R13 | clang 17.0.2 (`d9f89f4d...`) | `+pgo +bolt +lto -mlgo` |

编译器版本、LLVM commit、优化标志完全一致。仅有的表面差异：
- 自编 vanilla 版本串含 `maybe-dirty`，构建时间戳为 epoch zero (1970-01-01)
- stamped 版本串对齐 stock，但 kernel Image hash 仍不同

因此编译器/优化参数差异不是根因。

### 5.2 ABI 符号列表：关键差异方向

通过对 OnePlus SM8650 开源 manifest 和 Lenovo 本地内核源码的研究，发现 GKI 构建涉及三层 ABI 符号列表：

**Lenovo 本地内核**（`android_kernel_lenovo_sm8650-main/android/`）包含：
- `abi_gki_aarch64_qcom`：~4150 个符号，含 217 个 vendor hook tracepoint
- `abi_gki_aarch64_oplus`：~380 个符号
- `abi_gki_aarch64`（基础 GKI）：Google 通用符号
- `gki_aarch64_protected_modules`：受保护模块列表

**OnePlus SM8650 开源**（`github.com/OnePlusOSS/android_kernel_common_oneplus_sm8650`）结构相同，分支覆盖所有 SM8650 设备（OnePlus 12、13R、Pad2、Ace3 Pro 等 15 个分支）。

**关键推论**：当 Google CI 构建 certified GKI 时，KMI 符号保护流程会合并所有 vendor ABI 列表（`abi_gki_aarch64_qcom` + `abi_gki_aarch64_oplus` + ...）作为 trim 白名单。我们本地从 `kernel/common` 裸仓库构建时，只使用基础 `abi_gki_aarch64`，不包含这些厂商额外符号。

### 5.3 CONFIG_TRIM_UNUSED_KSYMS 的角色

所有构建（除 OKI 外）都启用了 `CONFIG_TRIM_UNUSED_KSYMS=y`。trim 机制根据 ABI 符号列表决定保留哪些 EXPORT_SYMBOL。但：

- CRC 分析确认 vendor audio 模块引用的所有 vmlinux 符号 CRC 完全匹配
- 缺失项（`gpr_send_pkt`、`audio_notifier_register` 等）是模块间互导符号，不受 vmlinux trim 影响
- 失败时音频模块已在 `/proc/modules` 中显示 `Live`

因此 trim 导致"符号直接被裁掉"的概率不高，但 trim 改变符号布局导致的**间接运行时行为差异**（如 vendor hook 注册回调时的内存布局偏移）仍有嫌疑。

### 5.4 OnePlus SM8650 构建流水线参考

OnePlus SM8650 的 GKI 构建（`kernel_manifest` 仓库）使用三 repo 结构：

```xml
<!-- 结构简化 -->
<project name="android_kernel_common_oneplus_sm8650" path="kernel_platform/common" />
<project name="android_kernel_oneplus_sm8650" path="kernel_platform/msm-kernel" />
<project name="android_kernel_modules_and_devicetree_oneplus_sm8650" path="./" />
<!-- + CodeLinaro prebuilts (bazel, clang, build-tools, etc.) -->
```

构建命令：`./kernel_platform/oplus/build/oplus_build_kernel.sh pineapple gki`

其中 `android_kernel_common_oneplus_sm8650` 是 Google `kernel/common` 的 fork，包含：
- OPlus/QCOM vendor hook 实现（`drivers/android/vendor_hooks.c`）
- ABI 符号列表更新
- Android GKI 版本合并（`android14-6.1.118_r00` 等 tag）

这意味着**OnePlus 不是用 Google 原版 `kernel/common` 构建，而是用打过 vendor hook/ABI patch 的 fork**。同样的逻辑应该适用于 Lenovo/TB520FU。

### 5.5 Lenovo 本地内核的 lapis 构建配置

`build.config.msm.lapis` 关键参数：
- `MSM_ARCH=lapis`，`VARIANTS=(consolidate gki)`
- `BUILD_VENDOR_DLKM=1`，`TRIM_UNUSED_MODULES=1`
- 从 `msm-kernel/build.config.common` 和 `build.config.msm.gki` 继承基础配置

`arch/arm64/configs/vendor/lapis_GKI.config` 定义了 lapis 特定的模块配置（`CONFIG_*=m`），不含 Droidspaces 所需的 IPC/namespace 选项。

### 5.6 audioserver 卡死精确位置

从 `23-debuggerd-audioserver.txt` 提取的栈：

```
audioserver main thread:
  __ioctl → ioctl → IPCThreadState::talkWithDriver
  → BpHwDevicesFactory::openPrimaryDevice_7_1
  → DevicesFactoryHalHidl::openDevice
  → AudioFlinger::loadHwModule
  → AudioPolicyService::onFirstRef → main

"binder:6013_1" 等 binder 线程：正常在 ioctl/talkWithDriver 等待
"ApmAudio" / "ApmOutput" 线程：在 pthread_cond_wait 等待
"AudioFlinger_Pa" 线程：在 condition_variable::wait 等待
```

audioserver 主线程卡在 HIDL 跨进程调用 `openPrimaryDevice_7_1` → vendor HAL 进程存在但不响应 → vendor HAL 自身初始化时阻塞（推测在 `libagm.so device_init` → ADSP/GPR 通信）。

system_server 侧：
```
ExternalCaptureStateTracker.run: Assertion failed: status != NO_ERROR
```
soundtrigger middleware 等不到 audio 服务就绪，触发断言失败。

### 5.7 研究结论与行动建议

**当前最可信假设**：
```
同 tag、同 IKCONFIG、同编译器下，本地 Kleaf/Bazel build 的 Image
与 Google certified/Lenovo stock Image 不等价。
差异来源（按概率排序）：
1. ABI 符号列表范围不同（本地仅基础列表，certified 含 QCOM/OPlus 扩展列表）
   → TRIM_UNUSED_KSYMS 保留的符号集合不同
2. LTO 链接决策受构建环境影响（SOURCE_DATE_EPOCH、prebuilt 精确版本）
3. Google CI 使用了不同于 kernel_aarch64_dist 的内部构建目标
```

**短期可尝试（离线构建，不刷机）**：

1. **关闭 TRIM_UNUSED_KSYMS 构建**（消除 trim 作为变量）：
   ```bash
   # 在 WSL ~/tb520fu-gki-r13/common 中
   # 方法 A：修改 .config
   scripts/config --disable CONFIG_TRIM_UNUSED_KSYMS
   tools/bazel run //common:kernel_aarch64_dist
   # 方法 B：Bazel flag（如果支持）
   tools/bazel run --notrim //common:kernel_aarch64_dist
   ```
   对比产物 Image hash 和 `Module.symvers`。

2. **用 Lenovo 本地内核源码构建**：Lenovo 的 `android_kernel_lenovo_sm8650-main` 包含 lapis 构建配置和完整的 QCOM ABI 列表。虽然是 6.1.68 旧版本（已实机验证第一屏死），但可以作为参考了解正确的构建流程。

3. **研究 OnePlus SM8650 构建**：clone `OnePlusOSS/android_kernel_common_oneplus_sm8650`（分支 `oneplus/sm8650_b_16.0.0_pad2`），对比与 Google `kernel/common` 的 diff，提取 vendor hook 和 ABI 符号列表变更，评估是否可以应用到我们的 R13 构建。

**中长期方向**：

- 从 Lenovo 当前 ROM（ZUI 17.5.10.096，Android 16 / SDK 36）对应的 kernel release tag 出发，寻找 Lenovo 是否公开了匹配当前 ROM 的内核源码
- OnePlus SM8650 的 LineageOS 适配（`LineageOS/android_kernel_oneplus_sm8650`）可能有直接可参考的 GKI + vendor 兼容方案
- 如果 trim 关闭后产物仍不等价 → 研究 Google CI 的 `download_or_build` 路径

**关键参考仓库**：

| 仓库 | 用途 |
|------|------|
| `OnePlusOSS/kernel_manifest` | SM8650 构建 manifest（15 个设备分支） |
| `OnePlusOSS/android_kernel_common_oneplus_sm8650` | SM8650 GKI common kernel fork |
| `OnePlusOSS/android_kernel_oneplus_sm8650` | SM8650 msm-kernel |
| `LineageOS/android_kernel_oneplus_sm8650` | LineageOS 适配 |
| 本地 `android_kernel_lenovo_sm8650-main` | Lenovo lapis 旧源码（6.1.68） |

### 5.8 简单验证：`--notrim` 离线构建

按第 5.7 节建议做了一次不刷机的最小验证：

```bash
cd ~/tb520fu-gki-r13
./tools/bazel build --config=local --notrim --jobs=2 --local_cpu_resources=2 --local_ram_resources=6144 //common:kernel_aarch64/Image
```

构建成功：

```text
Creating build environment (lto=default;notrim)
Build completed successfully
```

产物：

```text
Image SHA256:
961a51b10bf681aaab95bf395fcd5467c6bafad090f64d32a7d4c15703aa5b3c

Module.symvers SHA256:
ea1ef037e7964ec6d3f7f0e80061b037e1a126df84a8c517b5588a248931dcbe

vmlinux.symvers SHA256:
a2d14edfcb130489d8d8726d1291322538e7c94178641ff792ad6dc0c9ca77d8

Image size:
35M

Module.symvers lines:
15544

vmlinux.symvers lines:
15186
```

版本串仍是：

```text
Linux version 6.1.112-android14-11-maybe-dirty ... clang version 17.0.2 ... #1 SMP PREEMPT Thu Jan  1 00:00:00 UTC 1970
```

对第 5.2 节的修正：当前 WSL 里的 R13 `common/BUILD.bazel` 并不是只挂基础 `abi_gki_aarch64`。`kernel_aarch64` 目标已经包含：

```text
additional_kmi_symbol_lists = [":aarch64_additional_kmi_symbol_lists"]
protected_modules_list = "android/gki_aarch64_protected_modules"
```

其中 `aarch64_additional_kmi_symbol_lists` 包含 `abi_gki_aarch64_qcom`、`abi_gki_aarch64_oplus` 等厂商 ABI 列表。因此“本地裸仓库构建只使用基础 ABI list”这个说法对当前源码不成立，至少需要改成：**本地构建是否以与 Google certified/Lenovo stock 完全一致的方式使用这些列表，仍未证明**。

本次验证结论：

```text
--notrim 确实能改变产物和符号集合，但 no-trim Image 仍不等于 stock/certified Image。
trim 是可疑变量之一，但不是一个已被证明的单点根因。
```

当前不建议刷这个 no-trim Image。它只是离线对照产物，不是安全候选。

### 5.9 追加发现：失败环境 Wi-Fi 主驱动栈没有进入 stock 状态

本轮继续离线复核 `tb520fu-no-su-modules-off-stamped-diag-20260614-015524`、`tb520fu-stamped-vanilla-second-screen-diag-20260613-192643` 与 `tb520fu-stock-live-baseline-20260614-041011`，没有操作设备、没有刷机。

#### 现象 1：失败环境 `vendor.cnd` 崩溃前已有 NL80211 失败

`tb520fu-no-su-modules-off-stamped-diag-20260614-015524/04-logcat.txt` 中，`wificond` 在 `cnd` 大量崩溃前已经报：

```text
wificond: Failed to poll netlink fd:10time out, sequence is 3
wificond: NL80211_CMD_GET_PROTOCOL_FEATURES failed
wificond: Received error message: No such file or directory
wificond: Failed to get NL80211 family info
```

随后 `vendor.cnd` 反复：

```text
QCNEA: Cne Version 4.9
Scudo ERROR: invalid chunk state when deallocating address ...
/vendor/lib64/libcne.so (CneDriverInterface::~CneDriverInterface()+48)
/vendor/lib64/libcne.so (WifiQosProvider::initialize()+404)
/vendor/lib64/libcne.so (Cne::run()+152)
/system/vendor/bin/cnd (main.cfi+3108)
```

因此 CNE/MWQEM 线不只是“binder lazy service 没起来”，更早有一个可观察的 Wi-Fi/nl80211 初始化异常。

#### 现象 2：stock 与失败环境的 Wi-Fi 模块状态不一致

正常 stock baseline `/proc/modules` 有：

```text
qca_cld3_kiwi_v2
mac80211
cfg80211
rfkill
```

并且依赖关系显示：

```text
cfg80211 1081344 2 qca_cld3_kiwi_v2,mac80211
cnss2 372736 1 qca_cld3_kiwi_v2
cnss_nl 24576 1 qca_cld3_kiwi_v2
```

失败的 stamped vanilla second-screen `/proc/modules` 有 `cnss2`、`cnss_nl`、`wlan_firmware_service` 等底座，但没有看到：

```text
qca_cld3_kiwi_v2
mac80211
cfg80211
rfkill
```

这比“CNE 用户态自己崩”更具体：自编 GKI 环境下，同一套 vendor/userspace 没有把 Wi-Fi 主驱动栈拉到 stock 状态；CNE 的 `WifiQosProvider::initialize()` 很可能是在这个异常前提下进入错误清理路径，最后被 Scudo 抓到 invalid free。

#### 现象 3：`libcne.so` 反汇编支持这个调用链

`readelf -Ws libcne.so | c++filt` 中可见：

```text
WifiQosProvider::initialize() @ 0x10ffdc, size 644
CneDriverInterface::~CneDriverInterface() @ 0x1692c0, size 88
CneDriverInterface::NetlinkInterface::initialize(...) @ 0x16c778
CneDriverInterface::IoctlInterface::initialize() @ 0x16c600
CneDriverInterface::findWlanChipset() @ 0x176f30
```

`llvm-objdump` 显示 `WifiQosProvider::initialize()` 会构造 `CneDriverInterface`，调用 `CneDriverInterface::initialize(...)`，若返回值不是成功值，就记录错误并析构该对象；tombstone 正好落在析构函数。

#### 新判断

此前把主要故障写成 audio/soundtrigger/AGM 是不完整的。现在更合理的模型是：

```text
自编 GKI 与 stock/certified GKI 的差异
  → vendor_dlkm 某些关键模块/接口没有进入正常状态
  → Wi-Fi/nl80211 侧表现为 qca_cld3_kiwi_v2/cfg80211/mac80211 未加载或未注册 nl80211 family
  → wificond 失败，CNE WifiQosProvider 初始化失败并崩溃
  → 同时 audio/AGM/soundtrigger 也卡在 vendor 初始化链路
  → boot_completed 不达成，停在第二屏
```

这里的关键不再是“Droidspaces patch 是否对”，也不只是“音频是否被 Dolby 卡住”，而是 **stock/certified kernel 与本地 source-build kernel 在 vendor module bring-up 上存在系统性差异**。

#### 下一步优先级

1. 不刷机，先离线抽取 `super_8.img` / `vendor_dlkm_a` 中的 `qca_cld3_kiwi_v2.ko`、`cfg80211.ko`、`mac80211.ko`、`modules.dep`、`modules.load`、`modules.alias`。
2. 用 `modinfo` / `readelf` / `llvm-readelf` 对比这些模块的 `vermagic`、`depends`、`__versions`、导入符号，重点看它们依赖 stock/certified Image 的哪些符号或 CRC。
3. 若未来需要接线，优先在 stock 正常系统抓一份更完整的早期 Wi-Fi bring-up：`dmesg -T | grep -iE 'qca|cld|cfg80211|mac80211|cnss|wlan|nl80211|firmware|module'`、`logcat -b all -d | grep -iE 'wificond|nl80211|qca|cld|cnss|cnd|mwqem'`、`lsmod`、`ls -l /sys/module/{qca_cld3_kiwi_v2,cfg80211,mac80211}`。
4. 若未来控制失败环境，不急着 debuggerd audio；先抓同样的 Wi-Fi 模块/日志状态，确认是“模块未加载”、“加载失败但日志被遗漏”，还是“模块加载后又卸载/崩溃”。
5. 在没有解释 Wi-Fi 主驱动栈为什么不一致之前，不建议刷 `--notrim` 或新的 community OKI。

这个方向比继续扩 KMI 符号列表更可验证：先找出 `qca_cld3_kiwi_v2` 为什么不在失败环境出现，再决定是否是 KMI/CRC、module loader 条件、设备树/firmware 状态、还是内核行为差异。

#### 5.9.1 离线抽取 vendor_dlkm 与 CRC 初查

已从完整 9008 包 `image/super_8.img` 解出 `vendor_dlkm_a`：

```text
D:\project\新建文件夹\tb520fu-vendor-dlkm-extract
```

关键文件存在：

```text
lib/modules/qca_cld3_kiwi_v2.ko  19M
lib/modules/cfg80211.ko          2.0M
lib/modules/mac80211.ko          1.9M
lib/modules/modules.dep          47K
lib/modules/modules.load
```

`modules.load` 中确实列出：

```text
cfg80211.ko
mac80211.ko
qca_cld3_kiwi_v2.ko
cnss2.ko
cnss_nl.ko
cnss_prealloc.ko
cnss_utils.ko
```

`modinfo qca_cld3_kiwi_v2.ko`：

```text
vermagic: 6.1.78-android14-11-maybe-dirty SMP preempt mod_unload modversions aarch64
depends: cfg80211,cnss_prealloc,qcom_iommu_util,ipam,sched-walt,qcom_va_minidump,cnss_nl,cnss_utils,cnss2
```

注意：这个 `vermagic` 和 stock `6.1.112` 不同，但 stock 能加载它，所以不能把版本串不一致当成直接失败原因。这里应按 GKI/KMI/modversions 逻辑看导入符号 CRC。

已用 `modprobe --dump-modversions` 抽出三份模块 CRC：

```text
D:\project\新建文件夹\qca_cld3_kiwi_v2.modvers.txt
D:\project\新建文件夹\cfg80211.modvers.txt
D:\project\新建文件夹\mac80211.modvers.txt
```

对比自编 R13：

```text
D:\project\新建文件夹\selfbuilt-r13-Module.symvers
```

结果文件：

```text
D:\project\新建文件夹\tb520fu-wifi-module-crc-check.tsv
```

当前长度为 0，含义是：这三个 Wi-Fi 关键模块对自编 R13 `Module.symvers` 没有发现缺符号或 CRC mismatch。

因此“qca_cld3/cfg80211/mac80211 没起来”的根因暂时不像最直白的 KMI/CRC 不匹配。下一步更应看：

- 失败环境里 `vendor_modprobe` 是否尝试加载过这些模块，是否有 early log 被截断。
- `modules.load` 加载顺序与实际 `/proc/modules` 差异。
- `qca_cld3_kiwi_v2` 是否因为 probe 条件、PCI/CNSS 状态、firmware、device tree/bootconfig、module parameter、内核 runtime 行为而跳过或失败。
- 失败环境中 `wificond` 的 `NL80211_CMD_GET_PROTOCOL_FEATURES failed` 是否发生在 `cfg80211.ko` 未加载之后；如果是，它更像结果而不是根因。

### 5.10 新主线：system_dlkm/GKI protected modules 与自编 boot 不配套

本节是当前最重要的新增结论。它解释了为什么“同 tag、同 IKCONFIG、只换 boot kernel Image”仍然会出现 vendor bring-up 系统性异常。

#### 5.10.1 现象：失败环境不是单个 Wi-Fi 模块缺失，而是 system_dlkm 大面积没加载

对比 stock baseline 与 stamped vanilla 二屏日志：

```text
stock baseline:
system_dlkm/modules.load: 60 total, about 55 loaded
vendor_dlkm/modules.load: 423 total, about 414 loaded

stamped vanilla second-screen:
system_dlkm/modules.load: 60 total, about 5 loaded
vendor_dlkm/modules.load: 423 total, about 405 loaded

earlier Droidspaces second-screen:
system_dlkm/modules.load: 60 total, about 0 loaded
vendor_dlkm/modules.load: 423 total, about 171 loaded
```

这比“Wi-Fi 没起来”更底层：Wi-Fi 只是最容易观察到的一条受害链。`cfg80211.ko` 依赖 `rfkill.ko`，`mac80211.ko` 依赖 `cfg80211.ko` 和 `libarc4.ko`，而 `rfkill.ko` / `libarc4.ko` 属于 GKI `system_dlkm` 模块。它们没起来后，`qca_cld3_kiwi_v2`、`nl80211`、`wificond`、`vendor.cnd` 依次异常就很自然。

#### 5.10.2 Android GKI 的关键代码路径

源码位置：

```text
/home/acer/tb520fu-gki-r13/common/kernel/module/signing.c
/home/acer/tb520fu-gki-r13/common/kernel/module/gki_module.c
/home/acer/tb520fu-gki-r13/common/kernel/module/main.c
/home/acer/tb520fu-gki-r13/common/kernel/module/Makefile
```

`CONFIG_MODULE_SIG_PROTECT=y` 下，模块签名不是简单的“无签名即拒绝”。`signing.c` 中：

```text
#ifdef CONFIG_MODULE_SIG_PROTECT
#define sig_enforce false
#endif
```

所以普通 unsigned/vendor 模块可以继续加载。但 `main.c` 里有额外保护：

```text
if (!mod->sig_ok && gki_is_module_protected_export(kernel_symbol_name(s))) {
    pr_err("%s: exports protected symbol %s\n", mod->name, kernel_symbol_name(s));
    return -EACCES;
}
```

并且 unsigned 模块引用 signed GKI 模块导出的非 unprotected 符号时也会被拒绝：

```text
if (!mod->sig_ok &&
    !gki_is_module_unprotected_symbol(name) &&
    fsa.owner && fsa.owner->sig_ok) {
    fsa.sym = ERR_PTR(-EACCES);
}
```

含义：GKI system_dlkm 模块必须被当前 boot kernel 识别为 `sig_ok=true`，否则它们一旦导出 protected exports，就会被拒绝。

#### 5.10.3 为什么只刷自编 boot 会破坏它

stock `rfkill.ko`：

```text
vermagic: 6.1.112-android14-11-g75d944e80501-ab13981564 SMP preempt mod_unload modversions aarch64
signer: Build time autogenerated kernel key
sig_key: 45:0A:21:4F:E2:CB:FA:C4:67:31:2D:F0:51:1F:56:17:BB:CD:6C:EE
```

本地自编 `rfkill.ko`：

```text
vermagic: 6.1.112-android14-11-maybe-dirty SMP preempt mod_unload modversions aarch64
signer: Build time autogenerated kernel key
sig_key: 72:BF:78:0E:70:08:88:9E:7C:0A:F5:33:68:A2:A8:4C:F9:CA:7E:AB
```

`rfkill` 导出的符号同时出现在本地构建生成的：

```text
gki_module_unprotected.h
gki_module_protected_exports.h
```

例如：

```text
rfkill_alloc
rfkill_register
rfkill_unregister
rfkill_set_sw_state
rfkill_blocked
```

因此只刷自编 `boot.img` 时，设备上的 stock `system_dlkm` 模块仍由 Lenovo/Google stock kernel key 签名；自编 kernel 不认识这个 key，模块签名验证会变成 `sig_ok=false`。在 `SIG_PROTECT` 模式下这不会直接禁止所有模块，但会禁止这些模块导出 protected exports，最终表现为 system_dlkm 大面积加载失败。

这条机制比“杜比音效导致二屏”更能解释当前所有现象：

```text
只换 boot Image
  → stock system_dlkm 模块签名 key 与新 kernel 不匹配
  → GKI protected modules 失去 sig_ok 身份
  → rfkill/libarc4/bluetooth/nfc 等 system_dlkm 模块加载被拒或依赖链断裂
  → cfg80211/mac80211/qca_cld3/nl80211 不达 stock 状态
  → wificond/CNE 崩溃
  → audio/AGM 等 vendor bring-up 也可能受同类模块/时序/服务链影响
  → boot_completed 不达成，停第二屏
```

#### 5.10.4 本地已有配套 system_dlkm 产物

本地 Bazel 构建已经产出同一 kernel key 签名的 system_dlkm：

```text
/home/acer/tb520fu-gki-r13/bazel-bin/common/kernel_aarch64_images_system_dlkm_image/system_dlkm.img
/home/acer/tb520fu-gki-r13/bazel-bin/common/kernel_aarch64_images_system_dlkm_image/system_dlkm.erofs.img
/home/acer/tb520fu-gki-r13/bazel-bin/common/kernel_aarch64_images_system_dlkm_image/system_dlkm.flatten.erofs.img
/home/acer/tb520fu-gki-r13/bazel-bin/common/kernel_aarch64_images_system_dlkm_image/system_dlkm_staging_archive.tar.gz
```

记录到的 hash：

```text
system_dlkm.img:
db3455d321a77e5804cd08d8c94e810f171e17daadca7cc9e2017fba4ce79558

system_dlkm.erofs.img:
81668ae034363b8634abd6fa18c2d55597c8acecc41a07563fa849bfda0aa2fb

system_dlkm.flatten.erofs.img:
0e72d1d5713861231f817a48797c011aa2c0be065280097b8ec3eed1c9e3cd9b
```

离线复核 stock 与自编 system_dlkm 的模块清单：

```text
stock system_dlkm_modules.load: 60
selfbuilt system_dlkm.modules.load: 60
normalized module list: identical
```

`rfkill.ko` 的导入 CRC 集合和导出符号数量也一致：

```text
stock rfkill imports sha256:     45fe471a08fae92915da4eeed5853fe5bdf93c0e69c4456e610ff5e16868136c
selfbuilt rfkill imports sha256: 45fe471a08fae92915da4eeed5853fe5bdf93c0e69c4456e610ff5e16868136c
exports count: 16 vs 16
```

所以这不是“自编 system_dlkm 少模块”。它主要验证的是同一 kernel key / same-build GKI module set 是否恢复 `sig_ok` 和 protected exports 行为。

Kleaf 文档也明确给过类似用法：

```text
fastboot flash system_dlkm out/dist/system_dlkm.img
```

但 TB520FU 的 `system_dlkm` 在动态分区/super 里，设备属性显示：

```text
dev.mnt.dev.system_dlkm: dm-12
partition.system_dlkm.verified: 2
partition.system_dlkm.verified.hash_alg: sha256
```

所以后续实机实验必须确认：

- 当前 slot 是 `_a` 还是 `_b`。
- fastboot bootloader 模式能否直接刷 `system_dlkm_a`，还是必须进 fastbootd。
- `system_dlkm` 的 hashtree descriptor 在顶层 `vbmeta.img` 里，不在 `vbmeta_system.img` 里；如果 verity/digest 拦启动，应处理顶层 `vbmeta_a/b`。
- 完整 9008 包中 `image/super_5.img` 已用 `file(1)` 确认是 ext4 风格 `system_dlkm` 镜像；`image/super_8.img` 是 `vendor_dlkm` EROFS，不要混用。

候选目录已准备：

```text
D:\project\新建文件夹\tb520fu-next-test-system-dlkm-pair
```

其中 `vbmeta.test-hashtree-disabled.img` 是备选，不是默认必刷。它保留原顶层 vbmeta descriptors/chain，用 GKI testkey 重新签名，`Public key (sha1)` 仍为：

```text
2597c218aae470a130f61162feaae70afd97f011
```

该值与 stock 顶层 vbmeta 的 public key sha1 相同；`Flags: 1`，含义是关闭 hashtree/verity。只有当 `system_dlkm` digest/verity 明确阻止启动时才考虑刷这个顶层 `vbmeta_<slot>`。

#### 5.10.5 当前推荐的下一步实验，不是盲刷

当前最有价值的实验候选是：

```text
selfbuilt boot Image + 同一次构建的 system_dlkm.img
```

它比继续试新的 `boot.img` 更合理，因为它直接验证第 5.10 节的机制。如果这组能过二屏，再把 Droidspaces patch 加回来才有意义；如果这组仍卡，再抓 early dmesg 看 system_dlkm 是否恢复加载。

执行前必须准备回滚路径：

```text
stock boot_a / stock init_boot_a / stock vbmeta_a / stock vbmeta_system_a / stock system_dlkm_a
```

其中 `stock system_dlkm_a` 已确认可用完整 9008 包的 `image/super_5.img` 回滚；顶层 `vbmeta` 若被改过，用 `image/vbmeta.img` 回滚。`vbmeta_system` 当前不属于 system_dlkm 这轮实验的默认改动对象。

#### 5.10.6 对“荣耀官方支持但不开源”的启发

荣耀能被项目支持，不代表“随便刷通用 GKI 就行”。更可能的经验是：

- 它们使用 Google/common GKI 作为底座。
- 项目维护了能让 vendor KMI 通过的 ABI/patch 组合。
- 关键是 boot kernel 与 GKI module set 必须成套，尤其 system_dlkm/protected modules 不能混用。

这也解释了为什么 TB520FU 上社区通用包会早期 CrashDump：如果它只替换 kernel/boot，而没有和 Lenovo 当前系统的 system_dlkm、vendor_dlkm、AVB 状态严密配套，就可能比本地 vanilla 更早炸。

### 5.11 2026-06-14 实机验证：fastbootd 无法在 locked 状态写 system_dlkm

本轮目标是验证第 5.10 节的假设：自编 boot 必须配套同构建的 `system_dlkm`。设备接线后先确认当前状态：slot `_a`、`boot_completed=1`、`verifiedbootstate=green`，`system_dlkm` root digest 为 stock 值 `dba0ca8bf22e559248bb5d2bb5e934238b2d8bea095edd780a23ada2cc52c227`。

fastboot/fastbootd 只读探测结果：

```text
bootloader fastboot:
current-slot: a
boot_a size: 0x6000000
vbmeta_a size: 0x10000
system_dlkm_a: not visible

fastbootd:
is-userspace: yes
has-slot:system_dlkm: yes
partition-size:system_dlkm_a: 0xBA0000
partition-type:system_dlkm_a: raw
is-logical:system_dlkm_a: yes
```

完整 live `vbmeta_a` 已备份并确认等于 SukiSU 目录里的当前修补态版本：

```text
D:\project\新建文件夹\tb520fu-next-test-system-dlkm-pair\vbmeta.current-sukisu-rollback.img
size: 65536
sha256: 3c61a1cd3cc15f97fe041381de610218a5a7c37b8a964fcfd12fd6b22b20cc1d
```

不要把 9008 stock `vbmeta.img` 当作当前回滚基准；它不是当前可启动的 SukiSU 修补态。

实际测试：`boot_a.selfbuilt-stamped.img` 和 `vbmeta.current-sukisu-hashtree-disabled.img` 可刷入，但 `system_dlkm_a` 在 locked fastbootd 下无法写入：

```text
fastboot flash system_dlkm_a system_dlkm.selfbuilt.ext4.img
Resizing 'system_dlkm_a' FAILED (remote: 'Command not available on locked devices')
```

为排除“镜像比分区小导致 resize”，已用 avbtool 把自编 system_dlkm 扩到 0xBA0000：

```text
system_dlkm.selfbuilt.ext4.resized-0xBA0000.img
size: 12189696
sha256: f76ba90b823bda17d2c5f32e6743d493a26ef92c5b23cb3fd901b66bd691d1b8
```

但同尺寸镜像仍触发同样失败；`--force` 刷 stock 同尺寸 `system_dlkm.stock-rollback.ext4.img` 也同样失败。因此结论是：当前 locked fastbootd 对 logical partition flash 会走 resize 事务，而该事务被 locked 设备策略拒绝。fastbootd 路径当前不可用于写 `system_dlkm_a`。

root/ADB 低层写入也不可行：

```text
su context: u:r:ksu:s0
getenforce: Enforcing
dd if=/dev/block/dm-3 of=/dev/null bs=4096 count=1 -> Permission denied
dd if=/dev/block/mapper/system_dlkm_a of=/dev/null bs=4096 count=1 -> Permission denied
setenforce 0 -> Permission denied
```

本轮所有已写分区已回滚，回滚后确认：

```text
boot_completed: 1
slot: _a
verifiedbootstate: green
vbmeta digest: 9ec66d3c40a4966767a9eaffe2a92e3e0c7c96471817f52f5985069bdd0ea53d
system_dlkm root digest: dba0ca8bf22e559248bb5d2bb5e934238b2d8bea095edd780a23ada2cc52c227
Wi-Fi module chain present: rfkill/cfg80211/mac80211/qca_cld3_kiwi_v2
```

当前可行路径只剩：解锁 bootloader 后用 fastbootd 写 `system_dlkm_a`，或走 9008/EDL 写 super 中的 `system_dlkm` 子镜像。不解锁、不走 9008 的情况下，本轮目标无法继续实机验证。

### 5.12 2026-06-15 规划：不解锁下的 9008 三件套验证包

> 本轮仅离线打包与通道验证，**尚未实机刷入三件套**。

#### 5.12.1 为什么选 9008 而不是解锁

- 设备 `unlocked: no`，fastbootd 写 logical partition 会触发 resize 并被拒绝（5.11 已实测）。
- root 下写 `/dev/block/mapper/system_dlkm_a` 被 SELinux/ksu 拒绝。
- 本机 rare 优势：**GKI testkey 公钥链**（`2597c218...`）已被 SukiSU/live vbmeta 接受；自编 boot 也用同一 testkey footer。
- 因此可在 **不解锁、不清 userdata** 前提下，用 9008 写 `super_5`（system_dlkm 切片）+ `boot_a` + `vbmeta_a`。

#### 5.12.2 9008 通道状态（2026-06-15 实测）

```text
adb reboot edl                          -> 成功
枚举                                    -> 05c6:9008 COM4, driver OK (oem157.inf)
QSaharaServer + xbl_s_devprg_ns.melf    -> Sahara protocol completed
fh_loader --memoryname=UFS              -> MICRON MT512GAYAX4U40, All Finished Successfully
fh_loader --reset                       -> 正常回系统, boot_completed=1, green
```

注意：必须 `--memoryname=UFS`；默认 eMMC 会报 `Failed to open the SDCC Device`。

#### 5.12.3 三件套组成

| 刷入文件 | 物理目标 | 测试镜像 | 回滚镜像 |
|----------|----------|----------|----------|
| `boot_a.img` | boot_a, LUN4 | `boot_a.selfbuilt-stamped.img` | `boot_a.stock-rollback.img` |
| `super_5.img` | super 内 system_dlkm 切片, LUN0 | `system_dlkm.selfbuilt.ext4.resized-0xBA0000.img` | `system_dlkm.stock-rollback.ext4.img` |
| `vbmeta.img` | vbmeta_a, LUN4, **65536B** | `vbmeta.current-sukisu-hashtree-disabled.img` (Flags=1) | `vbmeta.current-sukisu-rollback.img` |

**明确不刷**：`init_boot_a`（SukiSU，用户自备）、`vendor_boot_a`、`vbmeta_system_a`、userdata、全量 super、任何 wipe XML。  
**Release 路径**：四镜像（init_boot + 三件套），无脚本；见 `docs/MANUAL_FLASH.md`。

#### 5.12.4 分区扇区映射（来自 9008 port_trace + 实机）

```text
boot_a:     LUN=4, start_sector=112006,  sectors=24576,  size=0x6000000
super_5:    LUN=0, start_sector=3055240, sectors=2976,   size=0xBA0000
vbmeta_a:   LUN=4, start_sector=136634,  sectors=16,     size=0x10000
```

9008 原厂 `vbmeta.img` 仅 8192 字节；本机 live/SukiSU `vbmeta_a` 分区为 65536 字节。本包写满 16 sectors。**不要用 9008 stock `vbmeta.img` 回滚。**

#### 5.12.5 已打包目录

```text
D:\project\新建文件夹\tb520fu-9008-triplet-system-dlkm-test\
  image\boot_a.img, super_5.img, vbmeta.img, xbl_s_devprg_ns.melf
  rollback\boot_a.img, super_5.img, vbmeta.img
  rawprogram_triplet_test.xml
  rawprogram_triplet_rollback.xml
  flash_triplet_test.cmd
  rollback_triplet.cmd
  README.txt
  SHA256SUMS.txt
```

刷入命令示例（COM 口以实机为准）：

```bat
adb reboot edl
flash_triplet_test.cmd COM4
```

回滚：

```bat
adb reboot edl
rollback_triplet.cmd COM4
```

#### 5.12.6 实验判据

**核心验证点**（比「是否过二屏」更优先）：

```text
自编 boot + 配套 system_dlkm 后，system_dlkm/modules.load 是否从 ~5/60 恢复到 stock 水平 (~55/60)
rfkill/libarc4 是否加载
cfg80211/mac80211/qca_cld3 是否恢复
```

若 system_dlkm 恢复但仍在二屏 → 说明 5.10 机制成立，根因还需继续追 certified vs source-build 差异。

若 system_dlkm 仍大面积失载 → 说明问题不只在签名配套，或 9008 写 super_5 未生效。

#### 5.12.7 残留风险

- 三件套必须在**一次** fh_loader 会话内写完再 reset；只写 boot+vbmeta 不写 super_5 会重现 5.11 半改坏状态。
- `super_5` 写的是 super 分区特定切片，不是 fastbootd logical partition；需确认写后 dynamic partition manager 能正确挂载新 system_dlkm。
- 中途断电、COM 口变化、路径含中文导致工具异常，均可能砖机；刷前确认 COM 口与 SHA256。

### 5.13 2026-06-15 实机验证：9008 三件套成功过二屏

#### 执行摘要

在 **不解锁** 前提下，通过 9008 一次写入 `boot_a + super_5(system_dlkm) + vbmeta_a` 后，设备 **首次以自编 GKI 组合正常达成 `boot_completed=1`**，不再卡在二屏。

#### 刷入过程

- 第一次失败：rawprogram XML 含 `<!-- -->` 注释，fh_loader 报 `Unrecognized tag 'program'`，仅 reset 未写入。
- 修复：去掉 XML 注释、改为单行 `<program />` 后重试成功。
- COM 口：COM4；`--memoryname=UFS`；107.69 MB 总传输；三项均 `{SUCCESS}`。

#### 刷入后状态（多次 ADB 采样）

```text
sys.boot_completed: 1
init.svc.bootanim: stopped
ro.boot.verifiedbootstate: green
uname -r: 6.1.112-android14-11-g75d944e80501-ab13981564  (stamped 版本串)
/system_dlkm/lib/modules/: 6.1.112-android14-11-maybe-dirty  (自编 system_dlkm)
init.svc.audioserver: running
init.svc.surfaceflinger: running
```

#### 核心机制验证：system_dlkm 链恢复

自编 stamped vanilla boot + 配套自编 system_dlkm 后，`lsmod` 可见：

```text
rfkill
libarc4
cfg80211
mac80211
qca_cld3_kiwi_v2
```

`wificond` logcat 正常创建 `wlan0`，无 `NL80211_CMD_GET_PROTOCOL_FEATURES failed` / `Failed to get NL80211 family info`。

对比失败样本（system_dlkm ~5/60 加载、上述模块缺失），**5.10 节「boot 与 system_dlkm 必须成套」假设被实机证实**。

#### 当前内核配置

刷入的是 `boot_a.selfbuilt-stamped.img`（**纯净 stamped vanilla**，非 Droidspaces）：

```text
# CONFIG_SYSVIPC is not set
# CONFIG_PID_NS is not set
```

因此本轮证明的是「自编 GKI 能正常启动到桌面」，尚未证明 Droidspaces 所需 IPC/namespace 已启用。

#### 下一步

1. 用同一路线（9008 三件套）刷 **R13 + Droidspaces** 自编 boot + 同构建 system_dlkm。
2. 刷前仍需基于 live vbmeta 生成 hashtree-disabled 版本；继续不动 `init_boot_a`。
3. 保留 `rollback_triplet.cmd` 回滚路径。

### 5.14 Droidspaces 最小配置 9008 三件套（构建规格）

#### 构建脚本

```text
D:\project\新建文件夹\tools\build_tb520fu_droidspaces_minimal.sh   # 全量：拉补丁 + Bazel + 打包
D:\project\新建文件夹\tools\pack_tb520fu_droidspaces_triplet.sh    # 仅重打包（已有 dist 时）
D:\project\新建文件夹\tools\pack_boot_a_gki.sh                     # 仅 boot_a 签名/padding
```

流程：

1. 从 GitHub 拉取 Droidspaces-OSS `v6.3.0` 补丁（直连，不走 proxy）。
2. 应用 `tb520fu-r13-droidspaces-minimal.diff`（kABI slot 6/7/8 + `gki_defconfig` 最小项）。
3. `gki_defconfig` 最小项：`SYSVIPC`、`POSIX_MQUEUE`；去掉 `# CONFIG_PID_NS is not set`（`IPC_NS`/`PID_NS` 由 Kconfig 推导，**不要**手动追加 `CONFIG_PID_NS=y` 行，Bazel `savedefconfig` 会拒绝）。
4. Bazel `//common:kernel_aarch64_dist`（Image + system_dlkm 同构建）。
5. 打包 `boot_a.img`：`certify_bootimg` + `erase_footer` + `add_hash_footer`（testkey `2597c218...` + 分区 padding `0x6000000` + stock rollback_index/props）。
6. `system_dlkm` resize 到 `0xBA0000`。
7. 输出到 `tb520fu-9008-triplet-droidspaces-minimal/`。

#### boot 打包踩坑（2026-06-15 已修）

| 症状 | 原因 | 修复 |
|------|------|------|
| `boot_a.img` 仅 ~35MB，`Algorithm: NONE` | `certify_bootimg` 对无 footer 的 nosig 镜像走 `--dynamic_partition_size`，且 `avbtool` 不在 PATH | `pack_boot_a_gki.sh`：PATH 含 prebuilts `avbtool`；certify 后再 `erase_footer` + 带 `--partition_size 100663296 --algorithm SHA256_RSA4096 --key testkey` 的 `add_hash_footer` |
| `avbtool: unrecognized arguments: --avbtool` | `--extra_args --avbtool` 不是合法参数 | 只通过 PATH 定位 `avbtool`，不要传 `--avbtool` |

#### 刷入后验证

```bash
adb shell su -c "zcat /proc/config.gz | grep -E 'SYSVIPC|IPC_NS|PID_NS|POSIX_MQUEUE'"
adb shell su -c lsmod | grep -E 'rfkill|cfg80211|qca'
adb shell su -c droidspaces check   # 若已安装
```

#### 二阶段（全量 GKI 推荐项 + loop 扩容）

构建脚本：

```text
D:\project\新建文件夹\tools\build_tb520fu_droidspaces_phase2.sh          # 全量：Bazel dist + 打包
D:\project\新建文件夹\tools\test_phase2_config.sh                        # 仅验证 config（快）
D:\project\新建文件夹\tools\apply_tb520fu_droidspaces_phase2_config.sh   # gki_defconfig：仅 loop 池
D:\project\新建文件夹\tools\tb520fu_droidspaces_phase2_defconfig         # Bazel defconfig fragment
D:\project\新建文件夹\tools\setup_tb520fu_phase2_bazel_fragment.sh       # 注册 //tb520fu:... fragment
D:\project\新建文件夹\tools\pack_tb520fu_droidspaces_phase2_triplet.sh   # 已有 dist 时仅重打包
```

**配置分两路**（Bazel `savedefconfig` 会丢弃多数手写 `gki_defconfig` 行，不可 tail-append）：

1. `gki_defconfig`（随 minimal diff）：`CONFIG_BLK_DEV_LOOP_MIN_COUNT=64`
2. `--defconfig_fragment=//tb520fu:tb520fu_droidspaces_phase2_defconfig` 合并其余 GKI 推荐项

Fragment 启用项（2026-06-15 `kernel_aarch64_config` 已验证进 `.config`）：

```makefile
CONFIG_DEVTMPFS=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_TARGET_LOG=y
CONFIG_NETFILTER_XT_MATCH_RECENT=y
CONFIG_IP_SET=y
CONFIG_IP_SET_HASH_IP=y
CONFIG_IP_SET_HASH_NET=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
CONFIG_BLK_DEV_LOOP_MIN_COUNT=64
```

**不可启**：`CONFIG_NETFILTER_XT_TARGET_REJECT` — GKI trim 树 Kconfig 未声明，Bazel fragment 校验失败。

boot 打包追加 cmdline：`max_loop=64`（`pack_boot_a_gki.sh` 的 `BOOT_CMDLINE`）。

输出包：`tb520fu-9008-triplet-droidspaces-phase2/`。仍保持 **boot + system_dlkm 同构建**，仍走 9008 三件套。

### 5.15 2026-06-15 Droidspaces 最小三件套已打包

#### 包路径

```text
D:\project\新建文件夹\tb520fu-9008-triplet-droidspaces-minimal\
  image\boot_a.img      100663296 B  SHA256 2a16a8b9...
  image\super_5.img    12189696 B  同次 Bazel dist system_dlkm
  image\vbmeta.img      65536 B     vbmeta.current-sukisu-hashtree-disabled
  flash_triplet_test.cmd
  rollback_triplet.cmd
```

#### 构建产物校验（WSL）

```text
kernel: Linux version 6.1.112-android14-11-maybe-dirty
boot_a AVB: SHA256_RSA4096, public key sha1 2597c218..., size 100663296
verify_image: vbmeta + boot hash OK（testkey_rsa4096.pem）
gki_defconfig: CONFIG_SYSVIPC=y, CONFIG_POSIX_MQUEUE=y, CONFIG_NAMESPACES=y（无 PID_NS 禁用行）
```

#### 刷入命令

```bat
adb reboot edl
flash_triplet_test.cmd COMx
```

#### 与 stamped vanilla 的差异

本轮 boot 含 Droidspaces 最小 kABI/defconfig；刷入后 `/proc/config.gz` 已见 `SYSVIPC/PID_NS/IPC_NS/POSIX_MQUEUE=y`。

### 5.16 2026-06-15 最小配置刷入与 sparse 安装失败

#### 刷入结果

9008 三件套成功；`boot_completed=1`、`verifiedbootstate=green`；Wi-Fi 链正常；Droidspaces 所需 namespace/IPC 配置已启用。

#### sparse 容器安装失败（非内核缺 loop）

Droidspaces 应用报 `Failed to mount sparse image`，实测根因：

```text
losetup: Too many open files / Can't open blockdev
```

| 项 | 值 |
|----|-----|
| loop 设备总数 | 48（loop0–loop47） |
| APEX 已占用 | 47 |
| 空闲 | 0 → sparse 安装需额外 1 个 loop |

`CONFIG_BLK_DEV_LOOP=y` 正常，不是最小 patch 缺项。临时规避：**目录模式**安装容器。

### 5.17 二阶段三件套已编译打包（2026-06-15）

目标：在 §5.14 全量 GKI 推荐项基础上，将 loop 池保守扩到 64（`CONFIG_BLK_DEV_LOOP_MIN_COUNT=64` + boot cmdline `max_loop=64`），缓解 APEX 占满 loop（48 个、APEX 占 47）导致 sparse 镜像无法 `losetup` 的问题。

#### 2026-06-15 脚本修复

| 问题 | 修复 |
|------|------|
| `apply_tb520fu_droidspaces_phase2_config.sh` 尾部 `sed` 误删半个 `gki_defconfig` | 删除该清理块；loop 仅 `replace_val` |
| 手写 `gki_defconfig` 追加项导致 `savedefconfig does not match` | 其余项改走 `--defconfig_fragment` |
| `CONFIG_NETFILTER_XT_TARGET_REJECT` fragment 校验失败 | GKI 树无此 Kconfig 符号，从 fragment 移除 |

#### config 验证（WSL）

```bash
bash /mnt/d/project/新建文件夹/tools/test_phase2_config.sh
# //common:kernel_aarch64_config SUCCESS
# .config: DEVTMPFS, IP_SET*, NETFILTER_XT_*, TMPFS_*, BLK_DEV_LOOP_MIN_COUNT=64
```

#### 全量编译（已完成）

```bash
bash /mnt/d/project/新建文件夹/tools/build_tb520fu_droidspaces_phase2.sh
# 2026-06-15 ~6min SUCCESS；boot cmdline: max_loop=64；AVB verify OK
```

#### 包路径

```text
D:\project\新建文件夹\tb520fu-9008-triplet-droidspaces-phase2\
  image\boot_a.img      100663296 B  SHA256 41e82c52...
  image\super_5.img    12189696 B  同次 Bazel dist system_dlkm
  image\vbmeta.img      65536 B     SukiSU hashtree-disabled
  flash_triplet_test.cmd  (Sahara -k -t 30)
```

#### 9008 刷入（已完成 2026-06-15）

```text
COM4 / D:\tb520fu-flash-droidspaces-phase2\
Sahara + fh_loader：100% SUCCESS
boot_completed=1；verifiedbootstate=green；Wi-Fi 链正常
cmdline 含 max_loop=64；/sys/module/loop/parameters/max_loop=64
loop 设备 64 个；APEX 占 ~47；空闲 ~17
droidspaces check：Loop device ✓；devtmpfs ✓；全部 MUST HAVE ✓
```

### 5.18 二阶段刷入后 sparse 仍失败（根因重判）

#### 现象

二阶段刷入后重试 Droidspaces sparse 安装（4GB `rootfs.img`），在 `mount -o loop` 步骤失败：

```text
[SPARSE] Mounting sparse image (Minimal loop,rw)...
Failed to mount sparse image. Your kernel might not support loop mounts here.
```

与 phase-1 不同：此时 **不是** `CONFIG_BLK_DEV_LOOP` 缺失，**不是** loop 池仅 48 且满员。

#### 实测

| 项 | phase-1（minimal） | phase-2（max_loop=64） |
|----|-------------------|------------------------|
| loop 总数 | 48 | **64** |
| APEX 占用 | 47 | **~47** |
| 空闲 | 0 | **~17** |
| cmdline `max_loop` | 无 | **64** |
| `droidspaces check` Loop | ✓ | ✓ |
| `mount -o loop`（toybox/busybox） | `losetup: Too many open files` | **仍失败** |
| 显式 `losetup /dev/block/loopN file` | adb shell 受限 | 可绑定空闲 loop |

结论：**扩到 64 缓解了「零空闲」但未修复 sparse 安装**。瓶颈在 Android 上 APEX 长期占满大部分 loop 槽位时，Droidspaces App 安装器使用的 **`busybox mount -t ext4 -o loop,...`**（内部自动 losetup）仍会失败。

#### 与 Droidspaces 上游实现差异

| 组件 | loop 挂载方式 |
|------|---------------|
| App `SparseImageInstaller.kt` | `busybox mount -o loop,...` → 易失败 |
| CLI `src/mount.c` | `ioctl(LOOP_CTL_GET_FREE)` + `mount /dev/block/loopN` → 更稳 |

建议向 [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) 提 issue：安装阶段改用 CLI 同款 `loop_attach`，不要依赖 `mount -o loop`。

#### 当前可行规避

1. **目录模式**安装容器（推荐，已验证内核配置满足 `droidspaces check`）。
2. 可选 phase-3：`max_loop=128`（不保证修复 App 安装路径）。
3. 刷机包放 GitHub **Release** 大文件；仓库只放脚本与文档（见 `D:\project\tb520fu-droidspaces-gki\`）。
