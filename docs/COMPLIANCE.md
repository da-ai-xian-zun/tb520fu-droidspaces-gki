# 合规性与开源许可研究

> 研究日期：2026-06-15  
> 范围：本仓库脚本/文档、GitHub Release 刷机包、构建链涉及的第三方项目。  
> **非法律意见**；发布前建议由熟悉 GPL/固件分发的顾问复核。

---

## 1. 我们实际分发什么

| 渠道 | 内容 | 许可性质 |
|------|------|----------|
| **Git 仓库** | 构建脚本、kernel diff、文档、`docs/MANUAL_FLASH.md` | 脚本 MIT；diff 衍生 GPL-2.0 内核 |
| **GitHub Release zip** | `init_boot_a` + `boot_a` + `super_5` + `vbmeta` + README/NOTICES | init_boot：**GPL-3.0**（SukiSU）；内核：**GPL-2.0**；无刷机脚本 |
| **不分发** | Lenovo `xbl`/9008 工具、stock ROM、SukiSU APK/LKM zip | 版权/许可限制 |

---

## 2. 各依赖项目许可摘要

### 2.1 Linux GKI kernel (`common/`)

| 项 | 说明 |
|----|------|
| 许可 | **GPL-2.0**（仅 v2，不含 “or later” 的常见内核文件头） |
| 来源 | https://android.googlesource.com/kernel/common/ |
| 我们做的 | `patches/tb520fu-r13-droidspaces-minimal.diff` + Bazel defconfig fragment |
| 义务 | 分发 **修改后的内核二进制** 时，须提供 **对应源码**（含我们的 diff），并保留 GPL 声明 |

**建议做法：**

- Release 页面除 zip 外，附 **源码 tag**（与构建 commit 一致）或 `Source code` 自动归档。
- `release/THIRD_PARTY_NOTICES.txt` 写明基线 tag 与补丁路径。
- 在 Release notes 写：`boot_a.img` / `super_5.img` 对应仓库 tag `vX.Y.Z` 的 `bash tools/build_tb520fu_droidspaces_phase2.sh` 产物。

### 2.2 Droidspaces-OSS

| 项 | 说明 |
|----|------|
| 项目 | https://github.com/ravindu644/Droidspaces-OSS |
| 引用版本 | `v6.3.0` |
| 许可 | **GPL-3.0** |
| 我们用的 | `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`（构建时 clone，不进 Git） |

**关系：** 内核补丁通过 kABI slot 启用 SYSVIPC 等，与 Droidspaces 用户态配合。  
**义务：** 若分发 **包含该补丁所生成逻辑的内核镜像**，GPL-2.0（内核）与 GPL-3.0（补丁作者选择的许可）的兼容性在业界有长期讨论；保守做法：

- Release 注明使用了 Droidspaces-OSS v6.3.0 的 GKI 补丁；
- 提供完整可重建源码（GKI tree + 我们的 diff + 构建命令）；
- **不要** 声称 Droidspaces 品牌背书。

用户态 Droidspaces App/CLI **不在本仓库分发**；用户自行从上游安装。

### 2.3 SukiSU-Ultra

| 项 | 说明 |
|----|------|
| 项目 | https://github.com/SukiSU-Ultra/SukiSU-Ultra |
| 许可 | **GPL-3.0** |
| 我们做的 | Release 捆绑 **SukiSU v4.1.3/40796** 修补的 `init_boot_a.img` |

**义务：**

- Release 注明 SukiSU 版本与 [SukiSU-Ultra 源码](https://github.com/SukiSU-Ultra/SukiSU-Ultra) 获取方式（GPL-3.0）。
- `init_boot_a.metadata.txt` 记录 SHA256 与 AVB 指纹；维护者为 **ROW 国际版** 系统（非国行），国行用户需自行核对兼容性。
- 不暗示 SukiSU/Lenovo 官方背书。

### 2.4 LTBox

| 项 | 说明 |
|----|------|
| 项目 | https://github.com/miner7222/LTBox |
| 许可 | **GPL-3.0** |
| 我们用的 | 开发阶段可选 GUI（EDL/AVB/镜像处理）；**不捆绑进 Git 或 Release** |

**义务：** 仅作开发工具时无需随 Release 分发 LTBox 二进制；文档中致谢即可。若将来把 LTBox 代码嵌入本仓库，则整段衍生代码需 **GPL-3.0** 开源。

### 2.5 AOSP 工具链（avbtool、mkbootimg、GKI testkey）

| 项 | 说明 |
|----|------|
| 许可 | 多为 **Apache-2.0** |
| 我们用的 | `pack_boot_a_gki.sh` 调用 GKI 树内 `avbtool`、`certify_bootimg.py` |
| 义务 | 保留 NOTICE；testkey 仅用于与 GKI 链兼容的测试签名，文档已说明 |

### 2.6 Lenovo 原厂固件

| 项 | 说明 |
|----|------|
| 内容 | ZUI ROM、9008 包、`xbl_s_devprg_ns.melf`、`fh_loader` 等 |
| 许可 | **专有**；联想开发者网站 / ROM 包许可 |
| 义务 | **不得** 在 GitHub 托管或 re-distribute；文档可链接第三方镜像（如 [LOLINET TB520FU](https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/)），并注明非官方、用户自负 |

### 2.7 vbmeta.img（Release 内含）

| 项 | 说明 |
|----|------|
| 性质 | 从 **已 root（SukiSU）设备** live 备份的 `vbmeta_a`（hashtree disabled） |
| 风险 | 含设备指纹/签名元数据；非联想官方再分发物 |

**建议：**

- Release notes 标明：仅适用于 **TB520FU + ZUI 17.5.10.096 + 已接受同 AVB 链** 的环境；
- 长期更稳妥：文档教用户从本机 live 备份生成 vbmeta，Release 仅含 `boot_a`+`super_5`，vbmeta 让用户自备（但会增加上手难度）。

---

## 3. 本仓库自身许可策略（建议）

| 部分 | 许可 |
|------|------|
| `tools/`、`docs/`（原创脚本与文档） | **MIT**（见根目录 `LICENSE`） |
| `patches/*.diff` | 衍生 **GPL-2.0** 内核修改；随仓库提供，满足源码可获得性 |
| GitHub Release 内核镜像 | **GPL-2.0** 分发义务；通过 Git tag + 构建文档履行 |

在 README 增加简短声明：

> 本仓库脚本为 MIT。构建产生的内核镜像为 GPL-2.0 衍生作品。第三方商标（Lenovo、Droidspaces、SukiSU）归各自所有者。

---

## 4. 发布检查清单

发布 Release zip 前：

- [ ] `bash tools/pack_release_zip.sh phase2` 生成 zip
- [ ] `SHA256SUMS.txt` 在 zip 内
- [ ] `THIRD_PARTY_NOTICES.txt` 在 zip 内
- [ ] Git **tag** 与构建 commit 一致
- [ ] Release notes：设备型号、ZUI 版本、GPL 源码获取方式、不含 Lenovo/SukiSU 二进制
- [ ] 未包含 `xbl_s_devprg_ns.melf`、stock ROM
- [ ] 已包含 `init_boot_a.img` + `init_boot_a.metadata.txt` + SukiSU 源码链接
- [ ] 免责声明（变砖、保修、地区锁）

---

## 5. 风险分级

| 风险 | 项 | 缓解 |
|------|-----|------|
| 低 | 分发 MIT 脚本 + GPL diff | 已有 LICENSE + COMPLIANCE |
| 中 | 分发 GPL 内核镜像 | Tag 对应源码 + NOTICES |
| 中 | 分发 live vbmeta 备份 | 版本说明 + 可选改为用户自备 |
| 高 | 分发 Lenovo xbl/ROM | **禁止**；已不纳入 zip |
| 中 | 分发 SukiSU 修补 init_boot | 已纳入 Release；ROW 指纹；国行/其他地区用户须自行核对 |

---

## 6. 参考链接

- [Droidspaces-OSS LICENSE (GPL-3.0)](https://github.com/ravindu644/Droidspaces-OSS/blob/v6.3.0/LICENSE)
- [SukiSU-Ultra LICENSE (GPL-3.0)](https://github.com/SukiSU-Ultra/SukiSU-Ultra/blob/main/LICENSE)
- [LTBox LICENSE (GPL-3.0)](https://github.com/miner7222/LTBox/blob/main/LICENSE)
- [Android kernel GPL requirements](https://source.android.com/docs/setup/about/licenses)
- [GPL-2.0 text](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)