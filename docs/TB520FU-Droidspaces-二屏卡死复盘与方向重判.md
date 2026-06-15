# TB520FU Droidspaces 内核实验复盘与方向重判

> 更新时间：2026-06-15
> 当前设备状态：**9008 三件套（stamped vanilla + 自编 system_dlkm + SukiSU hashtree-disabled vbmeta）已成功过二屏**；`slot=_a`，`boot_completed=1`，`verifiedbootstate=green`，Wi-Fi 链与 audioserver 正常。
> 数据状态：未清 userdata；`init_boot_a` 仍为 SukiSU/LKM，未动。

---

## 1. 最终结论（2026-06-15 修订）

**旧结论已部分推翻**：二屏卡死的主因不是「自编 kernel 二进制必然不兼容」，而是 **只换 boot、不配套 system_dlkm** 导致 GKI protected modules 身份断裂。

核心结论：

- TB520FU stock kernel 缺 Droidspaces 所需 `SYSVIPC`/`IPC_NS`/`PID_NS` 等，改内核方向仍然正确。
- **只刷自编 boot（无配套 system_dlkm）**：二屏卡死（audio/CNE/Wi-Fi 链异常是后果）。
- **9008 三件套（自编 boot + 同构建 system_dlkm + live vbmeta Flags=1）**：stamped vanilla 已实机过二屏（2026-06-15）。
- 社区 OKI 6.1.118 仍不推荐（更早 CrashDump/900E）。
- 官方 certified R13 = stock kernel，不是新方案。

一句话：**自编 GKI 可以启动，但必须 boot 与 system_dlkm 同构建成套；Droidspaces 配置是下一层验证。**

---

## 2. 版本概念校正

这里之前最容易写乱，必须拆开：

| 名称 | 含义 | 本案里的实际值 |
|---|---|---|
| `android14-6.1.112_r00` | Google common 某个具体 tag | 实际 kernel release 是 `6.1.112-android14-11-*` |
| `android14-6.1-2024-11_r13` | Google GKI 发布批次 tag | 实际 kernel release 仍是 `6.1.112-android14-11-*` |
| TB520FU stock `boot_a` | 当前可启动 stock kernel | `6.1.112-android14-11-g75d944e80501-ab13981564` |
| TB520FU stock `boot_b` 备份 | 设备备份中的另一个 slot boot | `6.1.118-android14-11-g5ae0bfe2d916-ab12884444` |
| 社区 OKI 包 | 预编译 AnyKernel 里的 Image | `6.1.118-Gold_bug` |

重要更正：

- `R13` 和 `6.1.112` 同时出现不矛盾；R13 是 GKI 发布批次，`6.1.112` 是实际内核版本。
- 社区 OKI 6.1.118 没有被当成源码 patch 打进 6.1.112；它是单独的预编译 `Image`。
- 文档旧表格里的 `R13 + Droidspaces | 6.1.112_r00` 是混乱写法，应改成“R13 tag，实际 kernel release 为 6.1.112”。

---

## 3. 实机实验矩阵

| # | 镜像/方案 | tag/来源 | kernel release | Droidspaces 修改 | 结果 |
|---|---|---|---|---|---|
| 1 | 早期 Droidspaces 自编 | `android14-6.1.112_r00` | `6.1.112-android14-11-maybe-dirty` | 有 | AVB 过，卡第二屏 |
| 2 | R13 + Droidspaces 自编 | `android14-6.1-2024-11_r13` | `6.1.112-android14-11-maybe-dirty` | 有 | AVB 过，第二屏 + ADB，卡 audio/soundtrigger |
| 3 | R13 纯净自编 | `android14-6.1-2024-11_r13` | `6.1.112-android14-11-maybe-dirty` | 无 | AVB 过，第二屏 + ADB，卡 audio/soundtrigger |
| 4 | R13 stamped 纯净自编 | `android14-6.1-2024-11_r13` | `6.1.112-android14-11-g75d944e80501-ab13981564` | 无 | AVB 过，第二屏 + ADB，卡 audio/soundtrigger |
| 5 | Google certified R13 | 官方 `gki-certified-boot-android14-6.1-2024-11_r13.zip` | `6.1.112-android14-11-g75d944e80501-ab13981564` | 无 | 未刷；离线确认 kernel 与 stock 完全一致 |
| 6 | Lenovo 本地开源包 | `android_kernel_lenovo_sm8650-main` | `6.1.68-android14-11-maybe-dirty` | 无 | 第一屏死，已回滚 |
| 7 | 社区 OKI 6.1.118 | `AnyKernel3_oki_6.1.118_Gold_bug.zip` | `6.1.118-Gold_bug` | 预编译包已含 Droidspaces 关键配置 | CrashDump / 900E，后经 recovery 进 bootloader 并回滚 |

---

## 4. 已确认的关键证据

### 4.1 Stock kernel 不满足 Droidspaces

stock `/proc/config.gz` 缺少核心项：

```text
# CONFIG_SYSVIPC is not set
# CONFIG_POSIX_MQUEUE is not set
# CONFIG_PID_NS is not set
CONFIG_IPC_NS 不存在或未启用
```

因此 stock boot 能正常启动，但不能满足 Droidspaces 原生 namespace / IPC 需求。

### 4.2 Droidspaces R13 修改确实生效

R13 + Droidspaces 实机卡第二屏时，运行时 config 显示：

```text
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_IPC_NS=y
CONFIG_PID_NS=y
```

所以它不是“配置没打开”。

### 4.3 纯净 R13 也卡同一条链

第三份纯净 R13 不含 Droidspaces patch/config，但仍卡第二屏；第四份 stamped 纯净 R13 甚至把版本串、build number、构建时间对齐 stock 后仍然卡同一类 audio/soundtrigger 链路。

这说明二屏问题不能主要归咎于 Droidspaces patch/config，也不能主要归咎于 `maybe-dirty`。

### 4.4 官方 certified R13 等于 stock kernel

离线解包比对：

```text
official-unpack/kernel  a9f8c34f2b6758ad737e7488c30ad5a842757ca472791b56208714c8d7b9add7
stock-unpack/kernel     a9f8c34f2b6758ad737e7488c30ad5a842757ca472791b56208714c8d7b9add7
```

二者版本串一致：

```text
6.1.112-android14-11-g75d944e80501-ab13981564
```

因此 TB520FU stock boot 内核本来就是 Google certified R13 那颗 kernel。问题不是“Google 官方 GKI 不兼容”，而是“我们本地从 common 源码重新编出来的二进制不等于 stock/certified 二进制”。

---

## 5. kABI patch 选择复核

TB520FU/R13 相关 `sched.h` 中有：

```text
ANDROID_KABI_USE(1, unsigned int saved_state)
```

所以 `1_2_3` patch 不能用于这条 6.1.112/R13 树。它会占用已经被 `saved_state` 使用的 slot 1。

本地准备脚本的选择逻辑是：

```text
use 3_4_5 if it applies cleanly; otherwise use 6_7_8
never use 1_2_3 when slot 1 is occupied by saved_state
```

当前可确认：

- 没有证据表明社区 OKI 6.1.118 的 patch 被打到了 6.1.112 上。
- 社区 OKI 方案是直接使用预编译 `6.1.118-Gold_bug Image`，不是源码 patch。
- 由于当时的 `tb520fu-patch-dry-run.txt` / build summary 没完整保留在本机，不能仅凭残留文件 100% 复原 R13 + Droidspaces 当时实际选了 `3_4_5` 还是 `6_7_8`。
- 但运行时 config 已证明 R13 + Droidspaces 的目标配置确实打开；而纯净 R13 也复现卡二屏，所以 kABI patch 不是当前 audio/soundtrigger 卡死链路的主嫌疑。

后续如果重做构建，必须保留：

```text
git tag / commit
selected kABI patch
patch dry-run result
final .config
Image SHA256
boot.img SHA256
```

---

## 6. 共同故障链

自编 R13 系列不是早期 bootloader 崩溃，而是已进入 Android 用户态：

- ADB 可连。
- `init`、`system_server`、`audioserver` 等进程进入启动流程。
- 卡点集中在 `AudioService`、`AudioFlinger`、vendor audio HAL、Qualcomm AGM / soundtrigger。

关键栈特征：

```text
audioserver -> AudioPolicyService::onFirstRef
            -> AudioFlinger::loadHwModule
            -> DevicesFactoryHalHidl::openDevice
            -> vendor audio / libagm / sound_trigger.primary.pineapple.so
```

stock boot 同一套 vendor/userspace/audio 栈可以正常注册：

```text
media.audio_flinger 正常
media.audio_policy 正常
soundtrigger@2.3 正常
```

因此差异集中在 kernel 二进制与 vendor audio/soundtrigger 相关接口、符号、vendor hooks、配置或行为上。

---

## 7. 社区 OKI 6.1.118 重新判断

### 7.1 发生了什么

社区 OKI 测试包的做法：

- 不直接刷 AnyKernel zip。
- 只取 `AnyKernel3_oki_6.1.118_Gold_bug.zip` 中的 `Image`。
- 塞进 TB520FU stock `boot_a` 壳。
- 外层 AVB、rollback index、fingerprint 等沿用 TB520FU stock boot。
- 只刷 `boot_a`，未动 `init_boot`、`vendor_boot`、`dtbo`、`vbmeta`、`userdata`。

结果：

- 启动后进入 Qualcomm CrashDump / 900E。
- 起初 fastboot 进不去。
- 经过多次电源键、音量键组合尝试后，设备进入 recovery。
- 从 recovery 进入 bootloader。
- fastboot 可用后刷回 stock `boot_a`，系统正常启动。

### 7.2 这是不是说明 OKI 还有希望

结论：**只能说它不是永久硬砖风险；不能说明它有较高启动希望。**

更合理的解释：

- OKI kernel 启动路径很早崩了，触发 crashdump / 900E。
- 长按电源和音量键可能让设备从 crashdump 状态彻底掉电，再重新进入 PBL/ABL/recovery 路径。
- recovery/bootloader 能进，说明 bootloader、recovery 分区、fastboot 链路都没坏。
- 这不代表 OKI kernel 曾经接近正常启动，也不代表它只差一个小配置。

它仍然是比自编 R13 更差的信号：

| 镜像 | 最远到达阶段 | 可诊断性 |
|---|---|---|
| 自编 R13 / 纯净 R13 | Android 用户态，ADB 可连 | 可抓 logcat/dmesg/debuggerd |
| 社区 OKI 6.1.118 | 早期 CrashDump / 900E | 几乎没有 Android 侧诊断空间 |

### 7.3 OKI 唯一仍可讨论的变量

OKI 6.1.118 与 TB520FU `boot_b` 的 `6.1.118` 有表面版本接近性，但这次刷的是：

```text
boot_a = OKI 6.1.118 kernel
vendor_boot_a / dtbo_a / init_boot_a = 原 a 槽组合
```

理论上仍有一个变量没有验证：

```text
6.1.118 kernel 是否必须配套 boot_b 时代的 vendor_boot_b / dtbo_b
```

但这个方向风险明显更高，因为会从“只换 boot kernel”扩展到 slotted boot 组件组合实验。当前不建议马上做，除非先准备好：

- boot_a/boot_b、vendor_boot_a/vendor_boot_b、dtbo_a/dtbo_b 的完整回滚包。
- 明确 slot 切换和回滚命令。
- 接受再次 crashdump，甚至需要 9008 救机的风险。

所以 OKI 的重新评价是：**有“可被救回”的操作空间，但没有“值得继续优先投入”的技术信号。**

---

## 8. 前面做得不好的地方

### 8.1 不该在 bootloader 可用时继续扩大实验

社区 OKI 是高风险变量，且前面已经有多次自编 R13 失败。刷 OKI 前应该更明确地把它定位成“强风险探针”，并把 recovery/9008 救援路径提前写成固定流程。

### 8.2 文档混淆了 R13、R00、6.1.112、6.1.118

旧文档里 `R13 + Droidspaces | 6.1.112_r00` 这种写法是错的。正确写法必须拆成：

```text
GKI tag: android14-6.1-2024-11_r13
kernel release: 6.1.112-android14-11-maybe-dirty
patch/config: Droidspaces kABI + config
```

### 8.3 没有保留足够构建元数据

后续无法从本机完整复原某次构建实际选择了哪个 kABI patch，这是流程问题。每次构建必须落盘：

```text
selected patch
patch sha256
apply log
.config diff
Image sha256
boot sha256
```

### 8.4 对 Windows 驱动问题判断绕了远路

一开始把 `qcusbser.sys` 当成签名/驱动版本问题处理，后来才确认是 WDAC `driversipolicy.p7b` 哈希白名单策略。正确判断应是：

```text
Code Integrity 3077 + policy id + file hash not found
=> 优先怀疑 WDAC/driver policy，而不是普通签名过期
```

### 8.5 900E 上不应期待直接刷写

WSL + usbipd + edlclient 证明能和 900E Sahara memory dump mode 握手，但不能进入 firehose。这个结果应尽早收敛为：

```text
900E = crashdump/memory dump，可读但基本不可刷
9008 = EDL/firehose，才是刷写入口
```

---

## 9. 当前安全基线

当前已恢复：

```text
slot: _a
boot_a: stock
kernel: 6.1.112-android14-11-g75d944e80501-ab13981564
sys.boot_completed: 1
bootanim: stopped
userdata: 未清
init_boot_a: 仍为 SukiSU/LKM 修补版
```

stock `boot_a` 回滚镜像：

```text
tb520fu-community-oki-6.1.118-boot_a-only\rollback\boot_a.stock-from-device.img
SHA256: 34672e14195f2ee01f346753815116d2d865abd7d3f9b00ddd8f45975328bed4
```

---

## 10. 后续建议

短期不建议继续刷：

- 社区通用包。
- 随机 Google common tag。
- 旧 Lenovo 6.1.68 源码产物。

如果继续研究，优先级应改成：

1. 找 Lenovo 当前 ROM 对应的真实 kernel 构建材料：源码、manifest、defconfig、Module.symvers、构建脚本、vendor hook 配置。
2. 对比 stock/certified kernel 与本地自编 R13 的 `.config`、KMI、符号、vendor hooks、audio/soundtrigger 相关配置差异。
3. 如果再做实机探针，必须先写清楚回滚命令和 9008/fastboot 救援路径。
4. 若要重新评估 OKI，只能作为“b 槽 6.1.118 组合实验”来设计，而不是再把 OKI kernel 单独刷进 `boot_a`。

当前最稳结论：**TB520FU 不是没有机会跑 Droidspaces，但机会不在继续碰通用 GKI 包，而在复现 Lenovo stock/certified kernel 的真实构建条件后，再最小化加入 Droidspaces 所需配置。**

---

## 11. 新操作边界与下一步尝试（2026-06-14）

用户当前允许继续连接设备并由 Codex 操作。数据不是绝对不可丢，但原则仍是：

- 优先保数据和保可启动状态。
- 不把每一步都升级成“万不得已”。
- 能用 fastboot 回滚 boot 的，不走 9008 全量。
- 能只读研究的，不先刷机。
- 只有在设备无法通过 fastboot/recovery 恢复时，才考虑 9008 或清数据保机。

下一步不再盲刷社区包，而是研究：为什么 TB520FU stock/certified kernel 可以启动，而本地自编 R13 即使版本串对齐 stock 仍卡 audio/soundtrigger。

待尝试路线：

1. 抽取 stock/完整包/certified kernel 的 IKCONFIG 和版本信息。
2. 抽取自编 R13、stamped R13、Droidspaces R13 的 IKCONFIG 和版本信息。
3. diff 配置，优先看 audio/soundtrigger/Qualcomm/vendor hook/KMI trimming/LTO/模块导出相关项。
4. 如果发现自编 R13 与 stock/certified 的关键配置差异，先尝试构建“纯净但更贴近 stock/certified”的 R13，而不是直接加 Droidspaces。
5. 只有纯净自编 R13 能进系统后，再做最小 Droidspaces patch/config 实验。

当前判断：所谓“反编译 boot 再编译回来”不可行；boot.img 能解包和重签，但不能把 Lenovo stock kernel 还原成可加配置的源码。实际可做的是从 stock/certified Image 中抽取 config 和构建元信息，反推构建条件。

---

## 12. 2026-06-14 追加：自编 R13 与 stock/certified 的差异定位

本轮只做只读诊断和离线分析，没有再次刷机。

### 12.1 设备当前确认

```text
adb: HA2452JQ device
slot: _a
sys.boot_completed: 1
kernel: 6.1.112-android14-11-g75d944e80501-ab13981564
su: uid=0(root)
```

### 12.2 full IKCONFIG 结论

对 `stock-device-boot_a`、完整 9008 包 `boot.img`、Google official certified R13、自编 vanilla R13、自编 stamped vanilla R13 做 full config diff：

```text
diff-stock-vs-stamped-fullconfig.diff: 0 行
diff-stock-vs-vanilla-fullconfig.diff: 0 行
diff-stock-vs-droidspaces-fullconfig.diff: 27 行
```

含义：

- stock / official certified / 自编 vanilla / 自编 stamped 的 IKCONFIG 完全一致。
- Droidspaces 版只多了预期的 `SYSVIPC`、`POSIX_MQUEUE`、`IPC_NS`、`PID_NS` 相关配置。
- 因此二屏卡死不能再解释成“漏了某个 `.config` 选项”。

### 12.3 源码 tag 结论

WSL 里的 `~/tb520fu-gki-r13/common` 确认在：

```text
75d944e805019befc0f8db3c5331baea6657e0e5
android14-6.1-2024-11_r13
```

该 commit 与 stock/certified 的版本串 `g75d944e80501` 对得上。也就是说，“自编时拿错 tag”不是主因。

### 12.4 vendor audio 模块结论

从当前 stock 正常系统用 root + base64 抽取了音频相关 vendor 模块，避免 `adb exec-out cat` 的二进制污染：

```text
machine_dlkm.clean.ko   vermagic 6.1.78-android14-11-g1637fb1e48f9
里程碑：这些模块在 6.1.112 stock GKI 上正常加载，说明它们依赖 GKI KMI/modversions，而不是依赖相同 kernel release。
```

将模块 `__versions` 与自编 R13 `Module.symvers` 对比：

```text
存在于 selfbuilt Module.symvers 的符号：CRC 全部匹配
缺失项：主要是音频模块之间互相导出的符号，如 gpr/audio_prm/spf/snd_event/wcd 等，不是 vmlinux 主内核符号
```

同时，自编 stamped R13 卡二屏时 `/proc/modules` 显示音频模块已经 loaded：

```text
machine_dlkm / audio_pkt_dlkm / audio_prm_dlkm / spf_core_dlkm / gpr_dlkm / q6_dlkm ... Live
```

含义：

- “vendor 模块 CRC 不匹配导致模块根本加载失败”这一假设被削弱。
- 卡死点更靠后：模块已加载，用户态 audio HAL / soundtrigger 在 `libagm.so -> device_init` 链路睡死或阻塞，继而 `audioserver` 注册不起来。

### 12.5 新的主假设

现在最可信的主假设是：

```text
同 tag、同 IKCONFIG 下，本地 Kleaf/Bazel build 出来的 Image 仍不等价于 Google certified/Lenovo stock Image。
差异不体现在 /proc/config.gz，而体现在构建流程产物、KMI 保护方式、LTO/trim 细节、符号布局、运行时行为或未记录的官方发布构建环境。
```

这也解释了为什么 Honor 这类不一定有完整厂商源码的机型仍可能被社区支持：关键不是“有没有荣耀源码”，而是社区包是否正确覆盖该设备 vendor 模块所需的 GKI KMI、vendor hooks 和运行时行为。TB520FU 目前没有现成适配包，通用包 OKI 又已造成早期 crashdump，不能类比为“荣耀能行所以这个通用包也能行”。

### 12.6 下一步边界

继续尝试前必须先做到：

1. 用更接近官方发布的 `kernel_aarch64_dist` / `download_or_build` 路线生成 baseline，并记录 Image、Module.symvers、abi_symbollist、构建命令。
2. 不再把“版本串相同 + config 相同”当成可刷充分条件。
3. 若 baseline Image 仍不能解释与 certified 的差异，短期不再刷自编 boot。
4. 若将来刷，仍只刷 `boot_a`，保留 stock rollback，并避免覆盖当前 SukiSU `init_boot_a`。

### 12.7 dist baseline 尝试结果

已尝试用更接近发布产物的 Bazel 目标重新构建：

```text
target: //common:kernel_aarch64_dist
result: Build completed successfully
elapsed: 约 480s
```

产物结论：

```text
bazel-bin/common/kernel_aarch64/Image
SHA256: b1034193d2f54ee789ce91ff3f2a67bc09677245ffc3328a67ac1756ed20db8a
version: 6.1.112-android14-11-maybe-dirty
```

这个 hash 与之前“纯净自编 R13”完全相同，说明 `kernel_aarch64_dist` 只是把同一个本地 source-build kernel 打成发布目录，并没有变成 Google certified / Lenovo stock 那个 kernel。

对比：

```text
stock / official certified kernel SHA256:
a9f8c34f2b6758ad737e7488c30ad5a842757ca472791b56208714c8d7b9add7

local source-build vanilla R13 kernel SHA256:
b1034193d2f54ee789ce91ff3f2a67bc09677245ffc3328a67ac1756ed20db8a
```

因此 `dist` 路线没有产生新的可刷候选。当前不建议刷这个产物，因为它等价于已实机验证卡二屏的纯净自编 R13。

新的收敛结论：**下一步不是再换 boot 打包方式，而是要么拿到 Google/Lenovo certified kernel 的真实发布构建元数据，要么找到已经验证过适配 pineapple/lapis + TB520FU vendor 栈的社区补丁集。**

---

## 13. 2026-06-14 追加：关闭 root 模块后的最小复测

用户已关闭所有 root 模块/授权后，做了一次最小变量实验：

```text
只刷 boot_a: tb520fu-stamped-vanilla-gki-r13-boot_a-only\image\boot_a.img
不改 init_boot_a
不刷 Droidspaces patch
```

复测过程：

```text
刷入 stamped vanilla R13 boot_a 成功
设备进入用户态，ADB 可连接
sys.boot_completed: 空
bootanim: running
media.audio_flinger: not found
media.audio_policy: not found
```

抓取目录：

```text
tb520fu-no-su-modules-off-stamped-diag-20260614-015524
```

关键观察：

```text
adb shell command -v su: 不存在
audioserver / android.hardware.audio.service_64 进程存在
media.audio_flinger / media.audio_policy 服务仍未注册
logcat 仍出现 AudioSystem 找不到 audio_flinger/audio_policy，以及 binder 线程 SIGABRT
```

随后已通过 fastboot 刷回 stock `boot_a`，设备恢复正常：

```text
boot_a rollback SHA256:
34672e14195f2ee01f346753815116d2d865abd7d3f9b00ddd8f45975328bed4

恢复后：
sys.boot_completed=1
bootanim=stopped
slot=_a
kernel=6.1.112-android14-11-g75d944e80501-ab13981564
```

结论：

```text
“SukiSU 模块 / LSP / 音频 root 模块 / root 授权”不是 stamped vanilla R13 卡二屏的主因。
即使 su 不可见、模块关闭，自编 R13 仍在同一条 audio service 链路失败。
```

这条线的剩余意义只在于维护当前 stock boot 下的 root 可用性，例如重新制作匹配新版 SukiSU Ultra 管理器的 LKM init_boot；它不再被视为 Droidspaces/GKI 卡二屏的主要突破口。
