# TB520FU Droidspaces GKI — Agent 接手说明

> 面向自动化 agent / 后续维护者。面向人类的简版见 [`README.md`](README.md)。  
> 维护者非科班出身，仓库由 Codex / Claude Code / Grok Build 等辅助完成；**接手后请用脚本与实机验证，勿盲信历史结论。**

---

## 1. 设备与固件上下文（必读）

| 键 | 值 |
|----|-----|
| device | Lenovo TB520FU / Yoga Tab Plus |
| system | **国际版（ROW）** ZUI — 维护者实机，**非国行系统** |
| soc | Qualcomm SM8650（pineapple / lapis） |
| tested_build | ZUI **17.5.10.096** `UKQ1.240826.001` |
| android | 14 |
| slot | `_a` |
| bl | **locked** |
| root | SukiSU on **`init_boot_a`** — **随 GitHub Release 分发** v4.1.3/40796 |
| stock_kernel | `6.1.112-android14-11-g75d944e80501-ab13981564` |
| selfbuilt_kernel | `6.1.112-android14-11-maybe-dirty`（Bazel R13） |
| avb_key_sha1 | `2597c218aae470a130f61162feaae70afd97f011`（GKI testkey） |

### 国际版 vs 国行

- 维护者使用 **ROW 国际版** 系统（`ZUI_17.5.10.096_251127_ROW`），**不是国行 ZUI**。
- Release 中 `init_boot` / `vbmeta` 的 AVB 指纹与 ROW 包一致（见 `release/init_boot_a.metadata.txt`）。
- **国行或其他地区用户**：构建号/指纹可能不同，刷后须查 `verifiedbootstate`，必要时用本机 stock `init_boot` 重打 SukiSU。
- 9008 工具与维护者固件包：[LOLINET TB520FU](https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/) → `TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127.zip`（与国行包不是同一个）。

---

## 2. 分发模型

| 渠道 | 内容 |
|------|------|
| **Git** | 脚本、`patches/`、文档、`release/` 文本模板；**无**二进制镜像 |
| **GitHub Release** | `tb520fu-droidspaces-phase2-images.zip`：**四镜像** + README/NOTICES/SHA256；**无刷机脚本** |
| **不分发** | `xbl`、Lenovo ROM 整包、刷机 `.cmd`（避免脚本环境差异） |

Release 四镜像：

1. `init_boot_a.img` — SukiSU v4.1.3 (40796)
2. `boot_a.img` — 自编 GKI phase-2
3. `super_5.img` — 同次构建 system_dlkm（0xBA0000）
4. `vbmeta.img` — live SukiSU hashtree-disabled 65536B

打 Release：`INIT_BOOT_IMG` + `PAIR_DIR` + 已构建 dist → `bash tools/pack_release_zip.sh phase2`

手动刷机说明：[`docs/MANUAL_FLASH.md`](docs/MANUAL_FLASH.md)  
四分区 XML（仅 Git）：`packages/triplet-phase2/rawprogram_release_quad.xml`

---

## 3. 已验证结论（不要重复踩坑）

### 3.1 可行路径

**9008 四镜像**（一次会话写完再 reset）：

- `init_boot_a` ← Release  bundled SukiSU（或用户自备兼容版）
- `boot_a` ← 自编 GKI + `pack_boot_a_gki.sh`
- `super_5` ← 同次 dist 的 `system_dlkm`（resize `0xBA0000`）
- `vbmeta_a` ← **65536B** hashtree-disabled（**非** 9008 stock 8192B vbmeta）

刷后：`boot_completed=1`，`verifiedbootstate=green`，Wi-Fi / system_dlkm 模块链正常。

**必须** `fh_loader --memoryname=UFS`。三/四镜像须同次写完；**只刷 boot** 会半改坏。

**版本/AVB（locked 路径）**：仅 **ZUI 17.5.10.096 ROW** 验证；bundled `init_boot`/`vbmeta` 绑定维护者 AVB 链，其他小版本/国行勿直接套用整包。

**已解锁 BL**：可 fastboot 刷写，AVB 版本绑定较宽松；自备 `init_boot`/vbmeta 更稳妥。见 `release/README.txt`、`docs/MANUAL_FLASH.md`。

### 3.2 不可再做的低价值动作

见 `docs/TB520FU-Droidspaces-后续研究方向交接.md` §0：单独刷 boot、社区 OKI 通用包、旧 6.1.68 联想包等。

### 3.3 二屏/audio 旧主线（已降级）

早期「只换 boot 不换 system_dlkm」会导致 GKI protected modules 断裂、二屏卡住。默认解释已是 **boot + system_dlkm 成套**；见交接 §5.10–5.11。

### 3.4 Droidspaces sparse 安装（**本项目未解决**）

phase-2 `max_loop=64` 已刷入，App `SparseImageInstaller` 的 sparse/rootfs.img 安装**仍失败**。  
**明确归因：本项目尚未研究清楚**（非简单说上游必然如此）。可能与 APEX ~47/64 loop 占用、App `mount -o loop` 实现有关。

**规避**：安装容器用 **目录模式**，不要用 sparse/image 模式。

### 3.5 Droidspaces GPU

- **Turnip**：已测（FD750，`glxgears` ~95 FPS）；GPU Access 开、VirGL 关、`MESA_LOADER_DRIVER_OVERRIDE=kgsl`。
- **VirGL**：未测试。
记录：交接 §5.18、`docs/MANUAL_FLASH.md` §6。

---

## 4. 仓库布局

```text
tb520fu-droidspaces-gki/
  README.md / README-agent.md
  LICENSE (MIT 脚本) / docs/COMPLIANCE.md
  docs/BUILD.md / docs/MANUAL_FLASH.md
  docs/TB520FU-Droidspaces-*.md     # 完整交接与技术笔记
  patches/tb520fu-r13-droidspaces-minimal.diff
  release/                          # Release 文本模板（打进 zip，非 Git 镜像）
  tools/
    env.example → env.local
    repo_paths.sh / repo_bootstrap.sh
    pack_boot_a_gki.sh
    build_tb520fu_droidspaces_{minimal,phase2}.sh
    pack_release_zip.sh
    pack_tb520fu_droidspaces_phase2_triplet.sh
    verify_repo.sh
  packages/
    triplet-phase2/
      rawprogram_release_quad.xml   # 四分区参考
      rawprogram_triplet_test.xml   # 三件套（已有 init_boot 时）
```

WSL GKI 树（不在 Git）：`~/tb520fu-gki-r13`

---

## 5. 构建流水线

### phase-2（当前推荐）

1. `patches/tb520fu-r13-droidspaces-minimal.diff` → GKI 根（`ensure_minimal_diff_in_gki_tree`）
2. Droidspaces-OSS `v6.3.0` kABI patch `001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`
3. `gki_defconfig`：仅 `CONFIG_BLK_DEV_LOOP_MIN_COUNT=64`（savedefconfig-safe）
4. Bazel `--defconfig_fragment=//tb520fu:tb520fu_droidspaces_phase2_defconfig`
5. `BOOT_CMDLINE=max_loop=64` → `pack_boot_a_gki.sh`
6. `common` 刷机前 `make mrproper`（Bazel 要求干净树）

验证：`bash tools/test_phase2_config.sh`  
自检：`bash tools/verify_repo.sh`

### phase-1 minimal

仅 minimal kABI diff + Bazel dist，无 phase-2 defconfig fragment。

---

## 6. boot / vbmeta / system_dlkm 签名规格

### boot_a（`tools/pack_boot_a_gki.sh`）

```text
size:           100663296 (0x6000000)
algorithm:      SHA256_RSA4096
key:            GKI testkey_rsa4096.pem（构建树内）
pubkey sha1:    2597c218aae470a130f61162feaae70afd97f011
rollback_index: 1762300800
fingerprint:    Lenovo/TB520FU/...ZUI_17.5.10.096_251127_ROW...
flow:           mkbootimg → certify_bootimg → erase_footer → add_hash_footer
phase-2 cmdline: max_loop=64
```

### system_dlkm（super_5）

```text
source:  bazel-bin/.../system_dlkm.img
size:    12189696 (0xBA0000)
must:    与 boot 内 Image 同一次 dist
```

### vbmeta_a

```text
source:  PAIR_DIR/vbmeta.current-sukisu-hashtree-disabled.img
size:    65536 (16 sectors), Flags=1
rollback: 勿用 9008 stock 8192B vbmeta
```

### init_boot_a（Release）

```text
source:  INIT_BOOT_IMG（打包时指定，不进 Git）
version: SukiSU v4.1.3 (40796)
size:    8388608
sha256:  364931fe27743c2bf2d42d4ca7ac198f7b51804305ddba93d3da08448dc7dc23
metadata: release/init_boot_a.metadata.txt
```

---

## 7. 9008 分区扇区（TB520FU）

```text
init_boot_a: LUN=4, start_sector=340102, sectors=2048
boot_a:      LUN=4, start_sector=112006,  sectors=24576
super_5:     LUN=0, start_sector=3055240, sectors=2976
vbmeta_a:    LUN=4, start_sector=136634,  sectors=16
```

Sahara 建议：`-k -t 30`。刷机包路径用 **纯 ASCII**。

开发者本地脚本（非 Release）：`packages/triplet-phase2/flash_triplet_test.cmd`（仅三件套，**不**含 init_boot）。

---

## 8. 文档章节索引（交接 md）

| § | 内容 |
|---|------|
| §0 | 禁止重复的低价值实验 |
| §4 | 当前建议路线 |
| §5.10–5.11 | system_dlkm 配套根因 |
| §5.14 | 构建规格 |
| §5.15–5.16 | minimal 刷入与 sparse 失败 |
| §5.17 | phase-2 编译打包 |
| §5.18 | phase-2 刷入后 sparse 仍失败（根因重判） |

---

## 9. 环境变量速查

```bash
source tools/env.local
export ROOT=$HOME/tb520fu-gki-r13
export STOCK_BOOT=...        # 必填：stock boot_a（AVB 参考）
export PAIR_DIR=...            # 必填：vbmeta（打包/Release）
export INIT_BOOT_IMG=...     # 必填：打 Release zip 时
export BASE9008_DIR=...        # 可选：本地 dev 包 xbl
```

---

## 10. 合规要点

见 [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md)。摘要：

- 脚本 MIT；内核镜像 GPL-2.0；`init_boot` 含 SukiSU（GPL-3.0）
- **禁止** 在 Git/Release 分发 Lenovo `xbl`/ROM
- Release 打 tag 对应源码（GPL 义务）

---

## 11. 待办 / 可选下一步

1. **sparse 容器安装**：本项目未解决；用户侧用目录模式
2. 国行 ZUI 用户兼容性 — 未在国行系统上验证；需自备匹配固件/init_boot
3. 向 Droidspaces-OSS 提 issue：安装器改用 `ioctl(LOOP_CTL_GET_FREE)` 而非 `mount -o loop`
4. phase-3：`max_loop=128`（不保证修 sparse）
5. 接手 agent：跑 `verify_repo.sh` + `test_phase2_config.sh`，对照实机再改文档