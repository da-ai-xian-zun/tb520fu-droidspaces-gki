# TB520FU 自定义 GKI 内核（Droidspaces）

我不是科班出身的开发者，整个项目的开发完全基于codex、claude code、grok build。我只能说我看起来没什么大问题，事实上ai们有没有埋雷我实在是没能力排查。文档也是agent写的

为 **联想 Yoga Tab Plus（TB520FU）** 构建并刷入带 [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 容器支持的 Android GKI 内核。

> 维护者系统：**国际版（ROW）** ZUI，非国行系统  
> 手动刷机：[`docs/MANUAL_FLASH.md`](docs/MANUAL_FLASH.md)  
> 自行编译：[`docs/BUILD.md`](docs/BUILD.md)  
> 许可：[`docs/COMPLIANCE.md`](docs/COMPLIANCE.md)  
> Agent 接手：[`README-agent.md`](README-agent.md)

---

## GitHub Release 含什么

`tb520fu-droidspaces-phase2-images.zip` — **四个镜像**，无刷机脚本：

| 文件 | 说明 |
|------|------|
| `init_boot_a.img` | **SukiSU v4.1.3 (40796)** 修补版（root） |
| `boot_a.img` | 自编 GKI phase-2 内核 |
| `super_5.img` | 配套 system_dlkm |
| `vbmeta.img` | SukiSU hashtree-disabled vbmeta |

另含 `SHA256SUMS.txt`、`init_boot_a.metadata.txt`、许可说明。  
固件需自行从联想原厂包获取，见下方固件链接。

---

## 设备与版本

| 项目 | 值 |
|------|-----|
| 型号 | Lenovo **TB520FU** |
| 维护者系统 | **国际版（ROW）**，ZUI **17.5.10.096** `UKQ1.240826.001`（**非国行**） |
| Android | 14，slot `_a` |

**版本说明：** 本项目在维护者 **ROW 国际版** 系统上开发与验证（非国行 ZUXOS）。Release 中 `init_boot` 指纹为 `...ZUI_17.5.10.096_251127_ROW...`（见 `release/init_boot_a.metadata.txt`）。**若你使用国行 ZUX 或其他地区/版本**，刷前请核对构建号与 `verifiedbootstate`，必要时用本机 stock `init_boot` 重打 SukiSU。

### 维护者验证环境（重要）

| 项 | 值 |
|------|-----|
| Bootloader | **不解锁（locked）** |
| 刷写方式 | **9008 四镜像**（见 [`MANUAL_FLASH.md`](docs/MANUAL_FLASH.md)） |
| 验证系统 | 仅 **ZUI 17.5.10.096 ROW** `UKQ1.240826.001` |
| AVB | Release 内 `init_boot` / `vbmeta` 绑定维护者本机 AVB 链；**其他小版本或国行勿直接套用整包** |

**不解锁 BL 时：** locked 设备无法用 fastbootd 写入 `system_dlkm`，因此本 Release 走 9008 一次写入 `init_boot_a` + `boot_a` + `super_5` + `vbmeta_a`。bundled `init_boot`/`vbmeta` 必须与你的 ZUI 小版本、地区匹配，否则可能无法过校验或无法启动。

**已解锁 BL 时：** 可自行用 fastboot 刷 `boot_a` + `super_5`（及自备 `init_boot`/vbmeta），对 bundled AVB 快照的版本绑定**较宽松**；但仍须保证 `boot` 与 `system_dlkm` 配套。详见 Release 包内 `README.txt`。

### 联想原厂固件

本仓库不分发联想 ROM。第三方镜像：

[https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/](https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/)

与维护者系统对应的 ROW 包：`TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip`

---

## 使用方式

| 路径 | 适合谁 |
|------|--------|
| **GitHub Release** | 下载四镜像，按 [`MANUAL_FLASH.md`](docs/MANUAL_FLASH.md) 手动 9008 刷入 |
| **`git clone`** | 审查源码、复现构建 |

---

## 自行构建

```bash
git clone https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki.git tb520fu-droidspaces-gki
cp tools/env.example tools/env.local   # STOCK_BOOT, PAIR_DIR, INIT_BOOT_IMG
source tools/env.local
bash tools/build_tb520fu_droidspaces_phase2.sh
bash tools/pack_release_zip.sh phase2
```

---

## Droidspaces 使用说明

| 项 | 状态 |
|------|------|
| `droidspaces check` | 通过 |
| 容器安装 | 请用 **目录模式**；App **sparse** 安装未解决 |
| GPU 加速 | **Turnip** 已测（Adreno FD750，`glxgears` ~95 FPS）；需 App 开 GPU Access、关 VirGL，容器环境变量 `MESA_LOADER_DRIVER_OVERRIDE=kgsl` |
| VirGL | **未测试**（高通机推荐 Turnip，见 [Droidspaces 图形指南](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Graphics-and-Audio.md)） |

---

## 已知问题：sparse 容器安装（未解决）

`droidspaces check` 可通过，但 App 用 **sparse 镜像** 装容器**仍会失败**——**本项目尚未研究清楚**（`max_loop=64` 已试过无效）。请用 **目录模式** 安装。

---

## 许可

脚本/文档 MIT；内核镜像 GPL-2.0；`init_boot` 含 SukiSU 修补（GPL-3.0），见 [`release/THIRD_PARTY_NOTICES.txt`](release/THIRD_PARTY_NOTICES.txt)。

---

## 免责声明

仅供学习研究。刷机可能变砖，风险自负。