TB520FU Droidspaces GKI — 镜像包（GitHub Release）
==================================================

型号: Lenovo TB520FU
维护者系统: 国际版（ROW）ZUI 17.5.10.096 (UKQ1.240826.001) — 非国行系统
Bootloader: locked（不解锁）— 本包按此环境验证

本 zip 含四个镜像（无刷机脚本，请自行用 9008 工具写入）:

  init_boot_a.img — SukiSU v4.1.3 (40796) 修补版 root
  boot_a.img      — 自编 GKI 内核 (phase-2, max_loop=64)
  super_5.img     — 配套 system_dlkm (0xBA0000)
  vbmeta.img      — SukiSU hashtree-disabled vbmeta (65536 B)

另有: SHA256SUMS.txt, init_boot_a.metadata.txt, THIRD_PARTY_NOTICES.txt

校验: sha256sum -c SHA256SUMS.txt

---
Bootloader：不解锁 vs 已解锁（请先读）
---

本 Release 在「bootloader 保持 locked、不清 userdata」的前提下验证通过。
请先确认自己属于哪一种，再决定刷哪些镜像、版本要求有多严。

【情况 A — bootloader 未解锁（locked）← 维护者路径，本 zip 主要面向此情况】

  为什么必须 9008:
    locked 设备上 fastbootd 写 system_dlkm 会走 resize，被策略拒绝，
    无法用 fastboot 单独替换 system_dlkm。只能走 9008 写 super 内切片。

  须刷什么:
    一次 9008 会话内写完四个目标后 reset，不可只刷 boot:
      init_boot_a + boot_a + super_5 (system_dlkm) + vbmeta_a

  版本 / AVB 要求（严）:
    仅在与维护者相同 ZUI 小版本验证:
      ZUI 17.5.10.096 (ROW)，UKQ1.240826.001
    本 zip 内 init_boot / vbmeta 为维护者本机 AVB 链快照。
    其他 ROW 小版本、国行或其他地区: 勿直接套用整包四镜像。
    刷后查: adb shell getprop ro.boot.verifiedbootstate
    不匹配时: 用本机 stock init_boot 重打 SukiSU + 自备 live vbmeta；
              或仅刷 boot_a + super_5，init_boot / vbmeta 用本机版本。

【情况 B — bootloader 已解锁（unlocked）】

  刷写方式:
    可用 fastboot / fastbootd，不必依赖 9008（9008 仍可用）。

  须刷什么（灵活）:
    至少 boot_a + 配套 system_dlkm（本 zip 的 super_5.img）必须成套。
    init_boot / vbmeta 可不使用本 zip 内文件，建议自备与本机匹配的版本。

  版本 / AVB 要求（松）:
    bundled init_boot / vbmeta 的版本绑定不再那么关键；
    你可自行重打 SukiSU、从本机备份 vbmeta。
    但 boot 与 system_dlkm 仍须同次构建、配套，否则可能二屏或模块链异常。

【对照】

  项目              locked（不解锁）          unlocked（已解锁）
  ----------------  ------------------------  ---------------------------
  推荐刷法          9008 四镜像               fastboot 或 9008
  本 zip 四镜像     建议整包同次写入          至少 boot + super_5；init_boot/vbmeta 可自备
  init_boot/vbmeta  须匹配 ZUI 小版本/AVB     可自备，限制较宽松
  维护者是否验证    是                        未单独验证 fastboot 路径

---
刷机概要（情况 A：不解锁 BL，9008 四镜像）
---

【本 zip 含什么】四个 .img，无刷机脚本、无 rawprogram XML。
  完整图文步骤见源码仓库:
  https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/blob/main/docs/MANUAL_FLASH.md

【你还须自备】联想 ROW 原厂包解压后的 9008 工具（本 zip 不含）:
  QSaharaServer.exe, fh_loader.exe, image/xbl_s_devprg_ns.melf
  推荐固件包: TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip
  （见下文「联想固件」链接）

【镜像文件 -> 写入目标】（slot _a）

  zip 内文件          写入分区/位置              大小
  ----------------    ------------------------  ----------
  init_boot_a.img  -> init_boot_a  (LUN4)       8 MiB
  boot_a.img       -> boot_a       (LUN4)       96 MiB
  super_5.img      -> super 内 system_dlkm 切片 (LUN0)  ~11.6 MiB
  vbmeta.img       -> vbmeta_a     (LUN4)       64 KiB (65536 B)

  注意: super_5.img 是 system_dlkm 的 super 切片，不是名为 super_5 的独立分区。
  vbmeta.img 须写满 65536 B；勿用原厂 9008 包里 8192 B 的 stock vbmeta 替代。

【扇区参数】（fh_loader / 自写 XML 时用；扇区大小 4096 B）

  init_boot_a:  LUN=4, start_sector=340102,  sectors=2048
  boot_a:       LUN=4, start_sector=112006,  sectors=24576
  super_5:      LUN=0, start_sector=3055240, sectors=2976
  vbmeta_a:     LUN=4, start_sector=136634,  sectors=16

【rawprogram XML】本 Release zip 不含 XML。
  可从源码仓库获取四分区模板（须与上述四个 .img 同目录）:
  https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/blob/main/packages/triplet-phase2/rawprogram_release_quad.xml
  将 zip 内四个 .img 与 XML 放同一英文路径，search_path 指向该目录。

【推荐流程】

  1. 校验 zip: sha256sum -c SHA256SUMS.txt
  2. 四镜像放到同一英文路径（路径勿含中文）
  3. 平板进 EDL: adb reboot edl（或按键进 9008）
  4. Sahara 加载 xbl_s_devprg_ns.melf
  5. fh_loader 一次会话写入四个分区，参数须含:
       --memoryname=UFS
       --reset
     （具体命令示例见 MANUAL_FLASH.md）
  6. 开机后检查:
       adb shell getprop sys.boot_completed
       adb shell getprop ro.boot.verifiedbootstate
       adb shell su -c droidspaces check

【禁止】

  - 不要只刷 boot_a（须与 super_5、vbmeta 等同次写完）
  - 不要刷 vendor_boot、dtbo、userdata、全量 super
  - 不要在一次会话里漏写 super_5 或 vbmeta（会半改坏）

---
init_boot AVB 指纹（核对用）
---

  见 init_boot_a.metadata.txt
  示例: ...ZUI_17.5.10.096_251127_ROW...

---
联想固件（非本仓库托管）
---
  https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/
  与本包对应: TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip


---
Droidspaces 容器与 GPU
---

  - 容器请用「目录模式」安装；App sparse 镜像安装未解决。
  - GPU：Turnip 已测（FD750）；App 开 GPU Access、关 VirGL，
    环境变量 MESA_LOADER_DRIVER_OVERRIDE=kgsl（可选 TU_DEBUG=noconform）。
  - VirGL 未测试。