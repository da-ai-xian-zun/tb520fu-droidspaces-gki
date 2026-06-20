# 从零构建与复现指南

> 刷机见 [`MANUAL_FLASH.md`](MANUAL_FLASH.md)。Release 仅含四镜像，无脚本。

---

## 1. 前置条件

| 组件 | 说明 |
|------|------|
| WSL2 | Bazel 编译 GKI |
| `STOCK_BOOT` | 本机 stock `boot_a.img` |
| `PAIR_DIR` | live `vbmeta` 备份（打 Release 用） |
| 联想 9008 包 | [LOLINET TB520FU 目录](https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/) → `...17.5.10.096_ST_251127.zip` |

---

## 2. 克隆与配置

```bash
git clone https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki.git tb520fu-droidspaces-gki
cd tb520fu-droidspaces-gki
bash tools/verify_repo.sh
cp tools/env.example tools/env.local
```

```bash
export STOCK_BOOT=/path/to/stock/boot_a.img
export PAIR_DIR=/path/to/vbmeta-backup-dir
```

---

## 3. 准备 GKI 树

```bash
bash tools/prepare_tb520fu_gki_remote.sh --workdir $HOME/tb520fu-gki-r13
cp patches/tb520fu-r13-droidspaces-minimal.diff $HOME/tb520fu-gki-r13/
```

---

## 4. 构建

```bash
source tools/env.local
bash tools/build_tb520fu_droidspaces_phase2.sh
```

---

## 5. 打 Release zip（四镜像）

```bash
bash tools/pack_release_zip.sh phase2
```

产出：`out/tb520fu-droidspaces-phase2-images.zip`

含 `init_boot_a` + `boot_a` + `super_5` + `vbmeta` + README + NOTICES + SHA256SUMS。  
打包前在 `env.local` 设置 `INIT_BOOT_IMG`（SukiSU 修补 init_boot，不进 Git）。

上传 GitHub Releases 时打与构建一致的 **Git tag**（GPL 义务，见 [`COMPLIANCE.md`](COMPLIANCE.md)）。

---

## 6. 稀疏挂载与魔改 APK

构建/刷机成功后：**联想 TB520FU 现阶段 Droidspaces 正常**（`debian-cli` = CLI 迁移 + loopfix，32G，`apt` 约 −69%）。**stock APK** Sparse 新建仍不可用（busybox，§5.5）；本仓库 **魔改 APK** 在 TB520FU **手装 + 完整安装 E2E + 3×启停** ✅（§5.4.1–§5.4.2）：

```powershell
bash tools/build_droidspaces_loopfix.sh   # WSL：先编 loopfix CLI
powershell -File tools/build_droidspaces_apk_loopfix.ps1   # 含 asset *.sh LF 门禁
powershell -File tools/verify_apk_loopfix.ps1              # 含 APK 内 CRLF 扫描
```

产物：`output/droidspaces-apk-loopfix/Droidspaces-loopfix-debug.apk`（debug 签名，须卸 stock App；当次 SHA256 见 `SHA256SUMS`）。**勿**在 Windows 直接保存 CRLF 的 `mount_loop_scan.sh` / `sparsemgr.sh`。

**刷机/装 APK 后（必做）**：核对并部署 CLI——魔改 APK 捆绑 loopfix，但设备若已有 **同体积 410168 B 旧 loopfix**，覆盖安装可能不替换二进制；`apply-loopfix.sh` 也只按体积恢复，**不能**旧→新升级。见 `patches/README.md`「装 APK 后必查 CLI 指纹」；一加 PKR110 必跑 `install_loopfix_persistent.sh`。

装后验证：`tools/post_apk_e2e_check.sh`（启停+网络）、`tools/full_apk_sparse_install_e2e.sh`（从零模拟 App 安装）、`tools/oneplus_fresh_cycle.sh`（一加：官方 rootfs 全新安装→压测→清理）。**一加** 魔改 APK + 新 CLI ✅（`ONEPLUS-PKR110-COMMUNITY-KERNEL-交接.md` §6）。

专档：[`SPARSE-MOUNT-RESEARCH.md`](SPARSE-MOUNT-RESEARCH.md)；上游草稿：[`UPSTREAM-ISSUE-DRAFT.md`](UPSTREAM-ISSUE-DRAFT.md)；刷机后见 [`MANUAL_FLASH.md`](MANUAL_FLASH.md) §6。