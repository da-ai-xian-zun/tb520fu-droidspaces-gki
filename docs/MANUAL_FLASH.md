# 9008 手动刷入镜像

Release zip 含 **四个镜像**（无脚本）：

`init_boot_a.img` + `boot_a.img` + `super_5.img` + `vbmeta.img`

---

## 1. 设备说明

| 项 | 值 |
|----|-----|
| 型号 | TB520FU |
| 维护者系统 | **国际版（ROW）** — 非国行 ZUI |
| 参考 ZUI | **17.5.10.096** `UKQ1.240826.001`（ROW）— **仅该小版本验证** |
| Bootloader | **locked（不解锁）** — 本仓库主路径 |
| Slot | `_a` |

### 不解锁 BL 时的版本与 AVB 要求

Release 四镜像在 **locked bootloader + 上述 ZUI 小版本** 上验证。bundled `init_boot_a` / `vbmeta` 为维护者本机 AVB 链快照：

- **其他 ZUI 小版本**（OTA 后构建号不同）或 **国行/其他地区**：勿直接套用整包；刷后查 `ro.boot.verifiedbootstate`。
- 不匹配时：用本机 stock `init_boot` 重打 SukiSU；`vbmeta` 从本机 live 备份生成 hashtree-disabled 版；或仅刷 `boot_a` + `super_5` 并自备 `init_boot` / `vbmeta`。

locked 设备无法用 fastbootd 写 `system_dlkm`，故必须用 **9008** 写 `super_5` 切片（见下文）。

### 已解锁 BL

可自行 **fastboot / fastbootd** 刷 `boot_a`、`system_dlkm` 等；对 bundled AVB 版本绑定**较宽松**，但仍须 `boot` 与 `system_dlkm` 配套。`init_boot` / `vbmeta` 建议自备本机版本。

维护者固件包（9008 工具）：[LOLINET](https://mirrors.lolinet.com/firmware/lenowow/2024/Yoga_Tab_Plus_2025/TB520FU/) → `...17.5.10.096_ST_251127.zip`。  
**国行 ZUI 用户**请用联想国内渠道匹配包，勿直接套用 ROW；`init_boot` 指纹见 `init_boot_a.metadata.txt`。

---

## 2. 准备文件

### Release 四镜像

| 文件 | 分区 | 大小 |
|------|------|------|
| `init_boot_a.img` | `init_boot_a` LUN4 | 8388608 B |
| `boot_a.img` | `boot_a` LUN4 | 100663296 B |
| `super_5.img` | system_dlkm @ super LUN0 | 12189696 B |
| `vbmeta.img` | `vbmeta_a` LUN4 | 65536 B |

### 联想 9008 工具（自备）

解压原厂包后需要：`QSaharaServer.exe`、`fh_loader.exe`、`image/xbl_s_devprg_ns.melf`。

### 不刷

`vendor_boot`、`userdata`、全量 super

---

## 3. 分区扇区

```text
init_boot_a: LUN=4, start_sector=340102, sectors=2048,   size=8192 KiB
boot_a:      LUN=4, start_sector=112006,  sectors=24576, size=0x6000000
super_5:     LUN=0, start_sector=3055240, sectors=2976,   size=0xBA0000
vbmeta_a:    LUN=4, start_sector=136634,  sectors=16,     size=0x10000
```

四分区 XML（clone 仓库可用）：`packages/triplet-phase2/rawprogram_release_quad.xml`  
仅三件套（已有 init_boot）：`rawprogram_triplet_test.xml`

---

## 4. 刷机步骤（Windows 示例）

1. 四镜像放同一英文路径
2. `adb reboot edl`
3. Sahara：

```bat
QSaharaServer.exe -k -t 30 -p \\.\COM4 -s 13:D:\lenovo\image\xbl_s_devprg_ns.melf
```

4. fh_loader（XML 需包含要写的分区；`search_path` 指向镜像目录）：

```bat
fh_loader.exe --port=\\.\COM4 ^
  --sendxml=D:\path\to\rawprogram.xml ^
  --search_path=D:\path\to\images ^
  --noprompt --showpercentagecomplete --memoryname=UFS --reset
```

**必须** `--memoryname=UFS`。四个分区建议**同一次会话**写完再 reset。

---

## 5. 刷后检查

```bash
adb shell getprop sys.boot_completed
adb shell getprop ro.boot.verifiedbootstate
adb shell su -c droidspaces check
```

---

## 6. 已知未解决：sparse 容器安装

本项目在 TB520FU（维护者 ROW 国际版）上**尚未解决** Droidspaces App 用 **sparse/rootfs.img** 安装容器失败的问题。

- `droidspaces check` 可通过
- phase-2 `max_loop=64` 已验证刷入，sparse 安装**仍失败**
- 原因我们还没完全弄清（loop 占用、App 挂载实现等）

**请用目录模式安装容器，不要用 sparse/image 模式。**

---

## 7. Droidspaces GPU（Turnip）

| 项 | 状态 |
|----|------|
| Turnip（Adreno FD750） | 已测，`glxgears` ~95 FPS |
| VirGL | **未测试** |

容器配置建议：开 **Termux:X11**、**GPU Access**；**关 VirGL**。环境变量：

```text
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
```

详见 [Droidspaces 图形指南](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Graphics-and-Audio.md)。