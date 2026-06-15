TB520FU Droidspaces GKI — 镜像包（GitHub Release）
==================================================

型号: Lenovo TB520FU
维护者系统: 国际版（ROW）ZUI 17.5.10.096 (UKQ1.240826.001) — 非国行系统
Android 14, slot _a

本 zip 含四个镜像（无刷机脚本，请自行用 9008 工具写入）:

  init_boot_a.img — SukiSU v4.1.3 (40796) 修补版 root
  boot_a.img      — 自编 GKI 内核 (phase-2, max_loop=64)
  super_5.img     — 配套 system_dlkm (0xBA0000)
  vbmeta.img      — SukiSU hashtree-disabled vbmeta (65536 B)

另有: SHA256SUMS.txt, init_boot_a.metadata.txt, THIRD_PARTY_NOTICES.txt

校验: sha256sum -c SHA256SUMS.txt

---
系统版本说明
---

- 维护者在 **ROW 国际版** 系统上验证（非国行 ZUI）。
- init_boot / vbmeta 的 AVB 指纹带 ROW 标记（见 init_boot_a.metadata.txt）。
- **国行或其他地区用户**：若 ZUI 构建号/指纹不一致，刷后请查 verifiedbootstate；
  必要时用本机 stock init_boot 自行重打 SukiSU。

联想固件（9008 工具 / xbl，非本仓库托管）:
  https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/
  与本包对应: TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip

国行 ZUI 用户请从联想国内渠道获取匹配固件，勿直接套用 ROW 包。

---
刷机概要（手动，一次会话写完四个分区再 reset）
---

  init_boot_a  +  boot_a  +  super_5 (system_dlkm)  +  vbmeta_a

分区表: 源码仓库 docs/MANUAL_FLASH.md
四分区 XML: packages/triplet-phase2/rawprogram_release_quad.xml
（init_boot: LUN4 start_sector=340102, 2048 sectors）

fh_loader 必须加: --memoryname=UFS
不要只刷 boot；不要刷 vendor_boot / userdata / 全量 super。

---
已知问题：Droidspaces sparse 容器安装（本项目未解决）
---

droidspaces check 可通过，但 App sparse 镜像 (rootfs.img) 装 Debian 仍可能失败。
phase-2 max_loop=64 已试过，问题仍在。请用「目录模式」安装容器。

---
源码: https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki