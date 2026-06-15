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

## 6. 已知：sparse 容器安装未解决

构建/刷机成功后，Droidspaces **目录模式**可装容器；**sparse 模式**在 TB520FU 上仍失败，原因未完全弄清。见 [`MANUAL_FLASH.md`](MANUAL_FLASH.md) §5。