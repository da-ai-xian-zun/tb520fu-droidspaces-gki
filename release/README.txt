TB520FU Droidspaces GKI — 镜像包（GitHub Release）
==================================================

型号: Lenovo TB520FU
维护者系统: 国际版（ROW）ZUI 17.5.10.096 (UKQ1.240826.001) — 非国行系统
Android 14, slot _a
Bootloader: locked（不解锁）— 本包按此环境验证

本 zip 含四个镜像（无刷机脚本，请自行用 9008 工具写入）:

  init_boot_a.img — SukiSU v4.1.3 (40796) 修补版 root
  boot_a.img      — 自编 GKI 内核 (phase-2, max_loop=64)
  super_5.img     — 配套 system_dlkm (0xBA0000)
  vbmeta.img      — SukiSU hashtree-disabled vbmeta (65536 B)

另有: SHA256SUMS.txt, init_boot_a.metadata.txt, THIRD_PARTY_NOTICES.txt

校验: sha256sum -c SHA256SUMS.txt

---
维护者路径：不解锁 BL + 9008 四镜像
---

本 Release 在 **bootloader 保持 locked** 的前提下验证通过。

原因：locked 设备上 fastbootd 无法写入 system_dlkm（会触发 resize 被拒绝），
因此必须用 9008 写入 super_5（system_dlkm 切片）及 boot / init_boot / vbmeta。

刷机概要（一次会话写完四个分区再 reset）:

  init_boot_a  +  boot_a  +  super_5 (system_dlkm)  +  vbmeta_a

分区表: 源码仓库 docs/MANUAL_FLASH.md
四分区 XML: packages/triplet-phase2/rawprogram_release_quad.xml
（init_boot: LUN4 start_sector=340102, 2048 sectors）

fh_loader 必须加: --memoryname=UFS
不要只刷 boot；不要刷 vendor_boot / userdata / 全量 super。

---
系统版本要求（不解锁 BL 时必读）
---

本包仅在与维护者相同的 ZUI 小版本上验证：

  ZUI 17.5.10.096 (ROW)
  构建号 UKQ1.240826.001
  init_boot AVB 指纹含 ZUI_17.5.10.096_251127_ROW（见 init_boot_a.metadata.txt）

Release 内 init_boot / vbmeta 绑定维护者本机的 AVB 链快照。

  - 其他 ROW 小版本（OTA 后构建号不同）、国行或其他地区：勿直接套用整包四镜像。
  - 刷后请查: adb shell getprop ro.boot.verifiedbootstate
  - 不匹配时：用本机 stock init_boot 重打 SukiSU，并从本机 live 备份生成 vbmeta
    （hashtree-disabled）；或只刷 boot_a + super_5，自备 init_boot / vbmeta。

若 bootloader 已解锁：

  - 可自行 fastboot / fastbootd 刷写，对 bundled AVB 版本绑定较宽松。
  - 仍建议自备与本机匹配的 init_boot / vbmeta；boot 与 system_dlkm 必须配套。
  - 9008 四镜像路径并非唯一，但仍是 locked 设备的可行方案。

联想固件（9008 工具 / xbl，非本仓库托管）:
  https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/
  与本包对应: TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip

国行 ZUI 用户请从联想国内渠道获取匹配固件，勿直接套用 ROW 包。

---
Droidspaces 容器与 GPU
---

  - 容器请用「目录模式」安装；App sparse 镜像安装未解决。
  - GPU：Turnip 已测（FD750）；App 开 GPU Access、关 VirGL，
    环境变量 MESA_LOADER_DRIVER_OVERRIDE=kgsl（可选 TU_DEBUG=noconform）。
  - VirGL 未测试。

---
源码: https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki