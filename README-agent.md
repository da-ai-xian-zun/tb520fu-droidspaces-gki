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
| android | **16**（SDK 36；GKI 版本串仍含 `android14-6.1`） |
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

### 3.4 Droidspaces sparse 挂载（**分层结论，2026-06-21**）

专档：[`docs/SPARSE-MOUNT-RESEARCH.md`](docs/SPARSE-MOUNT-RESEARCH.md) · 上游草稿：[`docs/UPSTREAM-ISSUE-DRAFT.md`](docs/UPSTREAM-ISSUE-DRAFT.md) · 交接 §5.21–§5.22

**现状**

| 项 | 状态 |
|----|------|
| `debian-cli` | 已迁 **32G sparse**（CLI `--rootfs-img` + **loopfix**）；`apt update` 约 **−69%** |
| App **Sparse Image 新建** | **stock APK** ❌（跨 3 OEM）；**魔改 APK** ✅ **联想现阶段正常**（手装 + `full_apk_sparse_install_e2e.sh` + `post_apk_e2e_check.sh` PASS，§5.4.1–§5.4.2 / §5.24）；跨机型 ⏳ |
| `debian13` | 目录模式（11G），未迁 |
| `droidspaces check` | ✅（TB520FU phase-2） |

**根因分层**（勿混为一谈）

1. **联想原厂 loop 池偏紧**：`max_loop=48` + APEX≈47 → 零余量；phase-2 `max_loop=64` 已缓解（~16 空闲）。
2. **phase-2 自编 GKI**：**非** loop 编译问题；显式 `losetup loop48+` + `mount` 成功。
3. **Droidspaces 上游缺口**：App 硬编码 `.../Droidspaces/bin/busybox mount -o loop`，自动 losetup 在 loop 高占用机上不可靠（`SparseImageInstaller.kt`）。
4. **stock CLI 脏池**：`ioctl(LOOP_CTL_GET_FREE)` 多轮 stop/start 后可能 `LOOP_SET_FD: Resource busy`；**loopfix**（`patches/droidspaces-android-loop-scan.patch`）扫描高 minor，**8–20 轮停启无需 reboot**。
5. **已排除**：KernelSU `magic_mount_rs`（模块逐一隔离后仍失败）；**SELinux**（TB520FU / 小米 / 一加 `setenforce 0` 后 busybox **仍**失败，toybox 成功）；**联想独家**（见跨机型表）。

**跨机型 Droidspaces v6.3.0 自带 busybox**（方案 A，原厂系统，2026-06-21）

| 设备 | DS busybox | toybox | `droidspaces check` |
|------|------------|--------|---------------------|
| TB520FU phase-2 | ❌ `can't setup loop device` | ✅（干净重启后） | ✅ |
| 小米 12S Ultra thor | ❌ **同上** | ✅ | ❌ 缺 PID/IPC ns |
| 一加 Ace 5 Pro PKR110（原厂） | ❌ **同上** | ✅ | ❌ 缺 PID/IPC ns |
| 一加 PKR110（`6.6.89-Gold_bug`） | ❌ 仍失败 | ✅ | ✅ · **#9 10/10** stock CLI |
| Pixel 8 shiba | —（未装 DS） | ✅ 近满池仍 OK | — |

小米上 `/data/adb/ksu/bin/busybox` 可成功，但 App 安装器**不用**该路径。

**loopfix 指纹（TB520FU，当前部署）**：stock **461544 B** `3538a2b7…` · loopfix **410168 B** `e0a80f9c…3b5c4584d`

**规避 / 日常**

- **新建**容器：**魔改 APK**（`build_droidspaces_apk_loopfix.ps1`）、CLI + `migrate_debian_cli_sparse.sh`，或目录模式；**stock APK** 勿 Sparse 新建。
- App 升级可能覆盖 `droidspaces` 为 stock → `apply-loopfix.sh` 或 `install_loopfix_persistent.sh`。
- **装魔改 APK 后必查 CLI SHA256**（不能只看 410168 B）：两版 loopfix 同体积时 `apply-loopfix` 不升级；一加曾需多传一次 `install_loopfix_persistent.sh`（`849250a4…` → `e0a80f9c…`）。CLI 补丁**仅** `mount.c`；见 `patches/README.md`。
- stock CLI 报 `LOOP_SET_FD` → 确认 loopfix 体积，或 **reboot** 再 start。
- 小米 thor：社区表**无** `2203121C` 内核条目；一加 PKR110 已刷 `Gold_bug`，线 2 完成（见 `ONEPLUS-PKR110-COMMUNITY-KERNEL-交接.md`）。

**诊断**：`sparse_cli_app_compare.sh`、`sparse_oem_loop_smoke.sh`、`sparse_selinux_loop_test.sh`、`diag_magic_mount_readonly.sh`

### 3.5 Droidspaces GPU

- **Turnip**：已测（FD750，`glxgears` ~95 FPS）；GPU Access 开、VirGL 关、`MESA_LOADER_DRIVER_OVERRIDE=kgsl`。
- **VirGL**：未测试。
记录：交接 §5.18、`docs/MANUAL_FLASH.md` §6。

### 3.6 NetProxy + `debian-cli`（NAT）— 已联调（2026-06-18）

- **宿主代理**：[NetProxy-Magisk](https://github.com/Fanju6/NetProxy-Magisk) TPROXY；须在 **KernelSU Ultra / NetProxy 管理器** 开启后重启，勿仅用 `cli service start`。
- **bypass**：`tproxy.conf` 设 `OTHER_BYPASS_INTERFACES="ds-br0"`（脚本 `tools/netproxy_bypass_droidspaces.sh`）；`BYPASS_IPv4_LIST` 可显式加 `172.28.0.0/16`。
- **验证**：NetProxy 运行时宿主 `github.com` → `198.18.x.x`；`debian-cli`（NAT）→ 真实 IP；`iptables` `BYPASS_INTERFACE` 含 `ds-br0`。
- **容器**：`debian13`=host（anland，受代理）；`debian-cli`=nat `172.28.1.2`（CLI 开发）；重启后 `debian-cli` 需手动 start（`run_at_boot=0`）。
- **内置终端虚拟键**：Droidspaces v6.3.0 **无隐藏开关**（源码写死两排 VirtualKeys）；用 **Copy Login + Termux**，Termux 侧 `extra-keys = []`。
- 详见交接 **§5.20**；诊断 `tools/post_reboot_check.sh`、`tools/diag_netproxy_droidspaces.sh`。

---

## 4. 仓库布局

```text
tb520fu-droidspaces-gki/
  README.md / README-agent.md
  LICENSE (MIT 脚本) / docs/COMPLIANCE.md
  docs/BUILD.md / docs/MANUAL_FLASH.md
  docs/TB520FU-Droidspaces-*.md     # 完整交接与技术笔记
  docs/SPARSE-MOUNT-RESEARCH.md     # 稀疏挂载专档（§5.21）
  docs/UPSTREAM-ISSUE-DRAFT.md      # 上游 issue/PR 草稿
  patches/tb520fu-r13-droidspaces-minimal.diff
  patches/droidspaces-android-loop-scan.patch
  patches/sparsemgr-loop-scan.patch
  patches/sparseimageinstaller-loop-scan.patch
  release/                          # Release 文本模板（打进 zip，非 Git 镜像）
  tools/
    env.example → env.local
    repo_paths.sh / repo_bootstrap.sh
    pack_boot_a_gki.sh
    build_tb520fu_droidspaces_{minimal,phase2}.sh
    pack_release_zip.sh
    pack_tb520fu_droidspaces_phase2_triplet.sh
    verify_repo.sh
    netproxy_bypass_droidspaces.sh   # NetProxy bypass ds-br0（§5.20）
    setup_debian_cli_nat.sh
    post_reboot_check.sh / diag_netproxy_droidspaces.sh
    migrate_debian_cli_sparse.sh   # 目录 → sparse 生产迁移
    build_droidspaces_loopfix.sh / deploy_droidspaces_loopfix.sh
    build_droidspaces_apk_loopfix.ps1 / verify_apk_loopfix.ps1
    sparse_cli_app_compare.sh / sparse_oem_loop_smoke.sh / sparse_selinux_loop_test.sh
    sparse_issue_bundle.sh / xiaomi_scheme_a_install.sh
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
| §4 | 研究方案总览（2026-06-20） |
| §5.10–5.11 | system_dlkm 配套根因 |
| §5.14 | 构建规格 |
| §5.15–5.16 | minimal 刷入与 sparse 失败 |
| §5.17 | phase-2 编译打包 |
| §5.18 | phase-2 刷入后 sparse 仍失败（根因重判） |
| §5.19 | 排除 magic_mount_rs；adb loop 烟雾测试；剩余方向 |
| §5.20 | NetProxy-Magisk + Droidspaces NAT bypass；`debian-cli`；内置终端虚拟键 |
| §5.21 | 稀疏挂载研究摘要（**专档** [`docs/SPARSE-MOUNT-RESEARCH.md`](docs/SPARSE-MOUNT-RESEARCH.md)） |
| §5.22 | 跨机型 busybox + SELinux 证伪；stock/loopfix 指纹；issue 前置收尾 |
| §5.23–§5.24 | 魔改 APK（双 App 补丁）TB520FU 安装+启停 E2E；CRLF/安装器踩坑；跨机型待测 |

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

**稀疏挂载（§5.21–§5.24）**：联想 TB520FU **现阶段正常** ✅ — `debian-cli` 32G sparse + loopfix；魔改 APK 手装 + 完整安装 E2E + 3×启停均 PASS（§5.4.2 CRLF、先写 config 再 umount）；跨机型 busybox / SELinux 证伪 ✅；**一加线 2 ✅**（#9 stock 10/10）；魔改 APK 跨机型 ⏳；issue 清单剩 **thor #9**。

1. **稀疏日常化**（P1）：确认 `debian-cli` 稳定后删 `rootfs.dir.bak`；App 升级后跑 `apply-loopfix.sh`
2. **上游 issue/PR**（P2）：草稿 [`docs/UPSTREAM-ISSUE-DRAFT.md`](docs/UPSTREAM-ISSUE-DRAFT.md) — CLI PR 优先，App 路径附 `sparsemgr-loop-scan.patch`；**用户确认后再 push**
3. **`debian-cli` 内网开发链**（P1）：EasyTier + 容器内 sing-box → Gitea — §5.20
4. **I/O 并行缓解**（P1）：tmpfs 挂 apt 缓存与编译目录；无 SD 槽见 §4.4
5. **#9 stock CLI 脏池**：一加线 2 ✅；**thor** 仍待社区 GKI 内核；魔改 APK 跨机型 ⏳
6. 社区设备表 TB520FU Partial 备注更新（本地，非阻塞）
7. 国行 ZUI 兼容性 — 未验证；需自备匹配固件/init_boot
8. phase-3：`max_loop=128`（低优先级；**不保证**修 App busybox）
9. 接手 agent：`verify_repo.sh` + `test_phase2_config.sh`；sparse：`sparse_cli_app_compare.sh`、`sparse_issue_bundle.sh`