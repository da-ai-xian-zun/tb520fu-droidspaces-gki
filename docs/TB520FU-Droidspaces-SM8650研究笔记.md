# TB520FU Droidspaces SM8650 vendor-aware GKI research notes

Date: 2026-06-14
Scope: offline research only. No device operation, no flashing.

## Repositories inspected

- Google/common local R13: `/home/acer/tb520fu-gki-r13/common`
  - commit: `75d944e80501`
  - version: `6.1.112`, branch string `android14-6.1`
- OnePlus common Pad2 Android 16: `/home/acer/research-sm8650/oneplus-common-pad2`
  - branch: `oneplus/sm8650_b_16.0.0_pad2`
  - commit: `fe279280d`
  - version: `6.1.118`
- OnePlus common OnePlus 12 Android 14: `/home/acer/research-sm8650/oneplus-common-oneplus12-u`
  - branch: `oneplus/sm8650_u_14.0.0_oneplus12`
  - commit: `e02429a7e`
  - version: `6.1.57`
- LineageOS OnePlus SM8650: `/home/acer/research-sm8650/lineage-oneplus-sm8650`
  - branch: `lineage-22.2`
  - commit: `67066f8b7`
  - version: `6.1.155`, ACK tag noted as `android14-6.1-2025-04_r9`

## Immediate conclusion

The available OnePlus/LineageOS SM8650 kernels are useful as vendor-aware GKI examples, but none is a safe direct base for TB520FU:

- OnePlus 12 Android 14 is too old: `6.1.57`.
- OnePlus Pad2 Android 16 is newer: `6.1.118`.
- LineageOS is much newer: `6.1.155`.
- TB520FU stock/certified is `6.1.112`.

Therefore the next useful work is patch/diff extraction, not direct boot image construction from these trees.

## OnePlus Pad2 common vs Google R13 common

### BUILD/KMI wiring

`BUILD.bazel` diff is small but real:

- OnePlus adds `android/abi_gki_aarch64_paragon` to `aarch64_additional_kmi_symbol_lists`.
- OnePlus removes `android/abi_gki_aarch64_zebra`.
- OnePlus adds `consolidate.bzl` and `define_consolidate()`.

Important correction to the previous hypothesis: Google R13 local common already wires `additional_kmi_symbol_lists` for `kernel_aarch64`, including `qcom` and `oplus`. The difference is not simply “local build only uses base ABI list”.

### Vendor hooks

OnePlus Pad2 adds or moves several exported Android vendor hooks relative to Google R13:

- `android_vh_slab_alloc_node`
- `android_vh_slab_free`
- `android_rvh_hw_protection_shutdown`
- `android_rvh_vmscan_kswapd_wake`
- `android_rvh_vmscan_kswapd_done`
- `android_vh_io_statistics`
- `android_vh_mmc_blk_reset`
- `android_vh_mmc_attach_sd`
- `android_vh_sdhci_get_cd`
- `android_vh_mmc_gpio_cd_irqt`
- `android_vh_init_adjust_zone_wmark`

New hook call sites confirmed in OnePlus Pad2:

- `mm/readahead.c` and `mm/filemap.c`: `trace_android_vh_io_statistics(...)`
- `mm/slub.c`: `trace_android_vh_slab_alloc_node(...)`, `trace_android_vh_slab_free(...)`
- `mm/vmscan.c`: `trace_android_rvh_vmscan_kswapd_wake/done(...)`
- `kernel/reboot.c`: `trace_android_rvh_hw_protection_shutdown(...)`
- `mm/page_alloc.c`: `trace_android_vh_init_adjust_zone_wmark(...)`

These are not audio-named hooks, but they show that OnePlus common carries additional vendor hook surface beyond Google R13.

### ABI list delta

OnePlus Pad2 `abi_gki_aarch64_qcom + abi_gki_aarch64_oplus` contains 56 symbols not present in the Google R13 equivalents. Relevant-looking subset:

- `android_vh_pcpu_rwsem_handler`
- `iommu_device_unlink`
- `of_clk_get`
- `of_get_compatible_child`
- `of_get_phy_mode`
- `__of_reset_control_get`
- `reset_control_put`
- `__traceiter_android_vh_init_adjust_zone_wmark`
- `__traceiter_android_vh_meminfo_proc_show`
- `__traceiter_android_vh_task_ux_op`
- `__traceiter_android_vh_tune_scan_type`
- `__tracepoint_android_vh_init_adjust_zone_wmark`
- `__tracepoint_android_vh_meminfo_proc_show`
- `__tracepoint_android_vh_task_ux_op`
- `__tracepoint_android_vh_tune_scan_type`

There are 0 symbols present in Google R13 qcom/oplus lists but missing from OnePlus Pad2 qcom/oplus, by the same rough parser.

### OPlus scheduler/percpu-rwsem changes

OnePlus common contains much larger scheduler changes:

- `CONFIG_SCHED_CLASS_EXT` integration in `kernel/sched/core.c`.
- `CONFIG_OPLUS_SCHED_TUNE` hooks in `kernel/sched/*`.
- `android_vh_task_ux_op` declared/exported.
- `android_vh_pcpu_rwsem_handler` callouts in percpu rwsem paths.

These are too broad to transplant blindly into TB520FU R13.

## Audio hypothesis status

The OnePlus diff did not reveal an obvious audio-specific common-kernel patch.

Existing TB520FU audio module CRC evidence remains important:

- vmlinux symbols referenced by stock audio vendor modules mostly match the selfbuilt R13 `Module.symvers`.
- Missing symbols are mainly QCOM audio module inter-exports, e.g. `gpr_send_pkt`, `spf_core_apm_close_all`, `msm_audio_*`.
- This supports the idea that module load succeeds and failure is later in runtime interaction: vendor HAL / `libagm.so` / ADSP-GPR path.

## Current best interpretation

OnePlus/LineageOS supports the broad model that successful SM8650 vendor kernels are not just plain Google common; they carry extra vendor hook/KMI surface and sometimes large scheduler/vendor changes. However, the specific TB520FU second-screen audio failure is not yet explained by a found OnePlus audio patch.

Most useful next steps:

1. Compare TB520FU failing logs against OnePlus/LineageOS common for remoteproc/slimbus/qcom-ngd behavior, especially ADSP audio PD handling.
2. Extract all OnePlus Pad2-vs-Google changes touching `drivers/slimbus`, `drivers/remoteproc`, `drivers/soc/qcom`, `drivers/rpmsg`, `kernel/module`, `include/linux/remoteproc`, and hook declarations.
3. Do not transplant the full OnePlus scheduler/sched_ext/OPLUS patchset.
4. If trying a build later, prefer a minimal patch series on Google R13, each patch justified by a TB520FU log symptom or vendor module dependency.

## 2026-06-14 追加：CNE / Wi-Fi QoS 作为第二个 vendor 兼容断点

本轮继续把 SM8650 兄弟机型经验和 TB520FU 二屏日志对照，发现除 audio/soundtrigger 外，还有一个更稳定、可重复的 vendor 用户态崩溃点：`vendor.cnd` / Qualcomm CNE。

### 现象

在 stock baseline 中：

```text
media.audio_flinger: found
media.audio_policy: found
sys.boot_completed=1
```

并且 CNE/QCNEJ 正常发网络状态通知，例如：

```text
QCNEJ/DefaultNetworkInfoRelay: Default network available: 100
QCNEJ/NativeAidlConnector: -> SND notifyWifiAvailable(...)
QCNEJ/WlanStaInfoRelay: AndroidValidate from false to true
```

在 stamped vanilla / no-su-modules-off 自编 GKI 失败环境中：

```text
vendor.cnd 反复 SIGABRT
sys.init.updatable_crashing=1
sys.init.updatable_crashing_process_name=vendor.cnd
```

典型 tombstone：

```text
Cmdline: /system/vendor/bin/cnd
Abort message: 'Scudo ERROR: invalid chunk state when deallocating address ...'
#06 /vendor/lib64/libcne.so (CneDriverInterface::~CneDriverInterface()+48)
#07 /vendor/lib64/libcne.so (WifiQosProvider::initialize()+404)
#08 /vendor/lib64/libcne.so (Cne::run()+152)
#09 /vendor/bin/cnd (main.cfi+3108)
```

计数对比：

```text
stock baseline 185424: 0
stock baseline 185530: 0
stamped vanilla second-screen: 305
no-su-modules-off stamped: 43
Droidspaces/early second-screen run: 1634
```

### 判断

这说明自编 GKI 的问题不是单一 audio HAL 特例。至少还有 Qualcomm CNE / Wi-Fi QoS / data networking 用户态栈在自编 GKI 下稳定进入异常路径。

这条线索和 OnePlus Pad2 common vs Google R13 common 的 ABI diff 有一定呼应：OnePlus 的 `abi_gki_aarch64_qcom/oplus` 相比 Google R13 多出一批网络/QoS 相关 KMI 符号，例如：

```text
default_qdisc_ops
dev_activate
dev_deactivate
dev_graft_qdisc
gnet_stats_add_basic
gnet_stats_basic_sync_init
mq_change_real_num_tx
netdev_txq_to_tc
qdisc_watchdog_init_clockid
rtnl_kfree_skbs
sock_create
sock_queue_err_skb
tcp_cong_avoid_ai
```

注意：`vendor.cnd` 是用户态进程，不是 `.ko`，所以它的崩溃不能直接解释为“缺导出符号”。更合理的解释是：CNE 通过 binder/netlink/qmi/厂商服务查询或配置 Wi-Fi QoS/网络状态时，自编 GKI 的行为和 stock/certified 不一致，触发了 Lenovo/QCOM 用户态库里的错误路径，最终在 `libcne.so` 析构里 double-free/invalid-free。

### 新优先级

接下来比继续盯 audio 更有效的验证路径：

1. 专门对比 stock vs failing 的 CNE 启动时序：`vendor.cnd`、`vendor.qti.hardware.mwqemadapteraidlservice`、`vendor.qti.data.factoryservice`、QCNEJ、DPM/QMI。
2. 对比 OnePlus/Lenovo 旧源码中网络 QoS/qdisc/netdev 相关 ABI/KMI 与 Google R13 的差异。
3. 如果后续做实验，优先考虑“网络/CNE 兼容小补丁”或“扩 KMI/启用相关 net scheduler config”的离线构建；不要直接套 OnePlus sched_ext/OPLUS 大补丁。
4. audio 仍是桌面无法进入的关键症状，但 CNE 崩溃提供了另一个更容易定位的 vendor 行为差异入口。

## 2026-06-14 追加：9008 包 super/vendor 与 vmlinux 复核

本轮继续做离线复核，没有操作设备、没有刷机。

### 1. 9008 包里的 `vmlinux` 不能当作 TB520FU stock boot 的符号真相

完整 9008 包 `image` 目录下确实有一个未剥离 ELF：

```text
D:\TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127\image\vmlinux
BuildID: e9e6f5ed40fabf4c8ecc2f912cf5abfed0bcf308
SHA256: 3313c408ce046b3220060732d41bc6d96861ad9018c9ef6366ea8d635df0eaae
```

但它的版本串是：

```text
Linux version 6.1.128-android14-11-maybe-dirty ... Thu Jan 1 00:00:00 UTC 1970
```

同一 9008 包 `boot.img` 里实际启动 kernel 的版本串仍是：

```text
Linux version 6.1.112-android14-11-g75d944e80501-ab13981564 ... Fri Aug 22 18:57:56 UTC 2025
```

结论：`image\vmlinux` 很可能是包内遗留/调试/错配文件，不能直接拿来代表 TB520FU 当前 stock/certified kernel 的 `vmlinux`。后续比较 stock vs selfbuilt 时，仍应以 `boot.img` 解出的 Image 为准；除非能从 Google certified artifact 或设备侧拿到匹配 `6.1.112-g75d944e80501-ab13981564` 的真实 vmlinux。

### 2. Qualcomm super 分片实际对应动态分区 payload

直接解析 `super_1.img` 中 0x3000 处的 liblp metadata，得到 slot A 的 extent 映射：

```text
odm_a         sectors 2048     + 1512
product_a     sectors 4096     + 4341528
system_a      sectors 4345856  + 19370440
system_dlkm_a sectors 23717888 + 23808
system_ext_a  sectors 23742464 + 900248
vendor_a      sectors 24643584 + 2928968
vendor_dlkm_a sectors 27574272 + 79720
```

这些 extent 的长度与 9008 包中的 `super_2.img` 到 `super_8.img` 高度对应。用 `file/blkid` 复核：

```text
super_6.img: EROFS filesystem  -> system_ext_a
super_7.img: EROFS filesystem  -> vendor_a
super_8.img: EROFS filesystem  -> vendor_dlkm_a
```

因此后续要抽 `/vendor/bin/cnd`、`/vendor/lib64/libcne.so`、`audio.primary.pineapple.so`、`libagm.so` 等文件时，不需要先全量拼接 14GB super；优先从 `super_7.img` 这个 vendor_a EROFS 里抽取即可。

### 3. CNE 线索与 vendor_a 二进制字符串吻合

对 `super_7.img` 做只读字符串检索，出现了与失败日志高度一致的关键词：

```text
mwqemadapter
vendor.qti.hardware.mwqemadapteraidlservice
IMwqemAdapter/MwqemAdapter
IDpmService/default
wifinl80211
netlink / generic netlink / nl80211
qdisc / tc
QOS / SET_QOS_MAP / MARK / IPTABLE
Cne Version 4.9
```

这与失败日志中的顺序吻合：

```text
vendor.qti.hardware.mwqemadapteraidlservice.IMwqemAdapter/MwqemAdapter 等待/启动失败
wifinl80211 被访问
QCNEA: Cne Version 4.9
cnd 在 WifiQosProvider::initialize() -> CneDriverInterface::~CneDriverInterface() 中 Scudo invalid free
```

这进一步支持“自编 GKI 与 Lenovo/QCOM vendor 用户态运行时不兼容”的判断。它不是单纯 Dolby 或 audio policy 配置问题；audio 是阻塞桌面完成启动的显眼症状，CNE 是第二个独立可复现断点。

### 4. 下一步最值得做的离线工作

1. 安装/准备 EROFS 提取工具，从 `super_7.img` 抽出：
   - `/vendor/bin/cnd`
   - `/vendor/lib64/libcne.so`
   - `/vendor/etc/init/*cnd*`
   - `/vendor/etc/vintf/manifest*.xml`
   - `/vendor/lib64/hw/audio.primary.pineapple.so`
   - `/vendor/lib64/libagm.so`
   - `/vendor/lib64/hw/sound_trigger.primary.pineapple.so`
2. 对 `libcne.so/cnd` 做 `strings/readelf/objdump`，重点看 `WifiQosProvider` 附近引用的 AIDL、netlink、tc/qdisc、wifinl80211、DPM/MWQEM 接口。
3. 对 `audio.primary.pineapple.so/libagm.so` 做同类分析，重点看 `openPrimaryDevice_7_1`、ADSP/GPR/SPF、soundtrigger 初始化链。
4. 暂不建议继续刷任何通用 GKI。下一次构建实验应有明确靶点，例如网络 QoS/CNE 兼容或音频 ADSP 交互差异，而不是“再试一个包”。

## 2026-06-14 追加：stock/SukiSU live baseline 对照

设备接线后抓取一份正常系统 live baseline，目录：

```text
D:\project\新建文件夹\tb520fu-stock-live-baseline-20260614-041011
```

本轮只做只读 ADB 诊断，没有刷机、没有重启、没有改分区。

### 正常系统状态

```text
adb devices: HA2452JQ device
sys.boot_completed=1
su 可用：uid=0(root), context=u:r:ksu:s0
```

关键 init/service 状态：

```text
[init.svc.audioserver]: [running]
[init.svc.vendor.audio-hal]: [running]
[init.svc.vendor.audioadsprpcd_audiopd]: [running]
[init.svc.dpmQmiMgr]: [running]
[init.svc.vendor.dpmd]: [running]
[init.svc.vendor.cnd]: [running]
[init.svc.wpa_supplicant]: [running]
```

关键进程：

```text
audioadsprpcd
android.hardware.audio.service_64
audioserver
vendor.dolby.hardware.dms@2.0-service
vendor.dolby.media.c2-default-service-dax
media.audio.qc.codec
dpmQmiMgr
vendor.dpmd
cnd
ims-dataservice-daemon
```

关键 binder/service manager 项：

```text
dpmservice: [com.qti.dpm.IDpmServiceApi]
media.audio_flinger: [android.media.IAudioFlingerService]
media.audio_policy: [android.media.IAudioPolicyService]
soundtrigger: [com.android.internal.app.ISoundTriggerService]
soundtrigger_middleware: [android.media.soundtrigger_middleware.ISoundTriggerMiddlewareService]
vendor.dolby.dvs.IDvs/default
vendor.qti.data.factoryservice.IFactory/default
vendor.qti.hardware.dpmaidlservice.IDpmService/default
vendor.qti.hardware.mwqemadapteraidlservice.IMwqemAdapter/MwqemAdapter
wifinl80211
```

### 与失败环境的直接对照

失败环境反复出现：

```text
Unable to set property "ctl.interface_start" to "aidl/vendor.qti.hardware.dpmaidlservice.IDpmService/default"
Unable to set property "ctl.interface_start" to "aidl/vendor.qti.hardware.mwqemadapteraidlservice.IMwqemAdapter/MwqemAdapter"
Waited one second for vendor.qti.hardware.mwqemadapteraidlservice.IMwqemAdapter/MwqemAdapter
serviceName: wifinl80211
cnd -> libcne.so -> WifiQosProvider::initialize() -> Scudo invalid free
AudioSystem: getService: checking for service media.audio_flinger: 0x0
AudioSystem: getService: checking for service media.audio_policy: 0x0
```

正常系统中这些项全部存在且稳定注册。这把 CNE 断点从“疑似”推进到更明确的对照结论：**自编 GKI 失败环境下，不只是 `cnd` 自己崩，而是 DPM/MWQEM/wifinl80211 这一组 Qualcomm 网络/QoS 服务链没有进入正常注册状态，随后 `libcne.so` 的 `WifiQosProvider::initialize()` 走到异常清理路径。**

### CNE 二进制依赖确认

从 `super_7.img` 抽出的 `cnd/libcne.so` 与 tombstone BuildID 对得上：

```text
cnd BuildID: 7afd6bd3c1cb091afdc43c6343eafbc9
libcne.so BuildID: a8d79a23d40c7e04e67e40fce04545e4
```

`cnd`/`libcne.so` 动态依赖直接包含：

```text
vendor.qti.hardware.mwqemadapteraidlservice-V1-ndk.so
vendor.qti.data.factoryservice-V1-ndk.so
vendor.qti.data.mwqemaidlservice-V1-ndk.so
vendor.qti.hardware.data.cneaidlservice.*
vendor.qti.latencyaidlservice-V1-ndk.so
libandroid_net.so
libnl.so
libwpa_client.so
libqmiservices.so / libqmi_cci.so
```

`libcne.so` 字符串中直接出现：

```text
WifiQosProvider::initialize
CneDriverInterface::findWlanChipset
CneQmiDpm
dpm_get_service_object_internal_v01
SwimNetlinkSocket::NetlinkSend / NetlinkRecv
mwqemAdapterImpl
AIBinder_linkToDeath
```

### 正常系统网络/QoS 状态

root 抓取 `tc qdisc show` 显示 `wlan0` 正常挂有大量 TX queue qdisc：

```text
qdisc pfifo_fast 0: dev wlan0 parent :f ...
...
qdisc pfifo_fast 0: dev wlan0 parent :1 ...
qdisc clsact ffff: dev wlan0 parent ffff:fff1
```

这与 `libcne.so` 中 `qdisc/tc/netlink/QOS/MARK/IPTABLE` 字符串呼应。后续如果做构建实验，CNE 方向应重点核对：

1. 自编 GKI 是否保留/启用了与 `clsact`、`pfifo_fast`、多 TX queue、generic netlink/nl80211 相关的内核行为。
2. DPM/MWQEM 相关 vendor 服务是否因为内核接口或模块行为差异而没有正常注册。
3. `WifiQosProvider::initialize()` 崩溃更可能是“依赖服务/内核接口异常后的错误清理路径”，而不是 libcne 本身坏。

### Audio 二进制依赖确认

`audio.primary.pineapple.so` 依赖：

```text
libar-pal.so
vendor.qti.hardware.pal@1.0-impl.so
vendor.qti.hardware.AGMIPC@1.0-impl.so
libagm.so
```

`sound_trigger.primary.pineapple.so` 依赖：

```text
libar-pal.so
vendor.qti.hardware.ListenSoundModel@1.0-impl.so
```

字符串中可见 `LoadAudioHal`、`OpenPALStream`、`pal_stream_open/start/stop/get_param`、`PAL_STREAM_VOICE_UI` 等。它仍指向 PAL/AGM/ADSP 交互，而不是单纯 Dolby。正常系统中 Dolby DAP 确实作为 effect 存在，但它是 audio 成功启动后的参与者；目前证据不支持把 Dolby 作为主因。
