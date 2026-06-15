# Kernel patches / diffs

Canonical 补丁随仓库分发；完整 `common/` GKI 源码需自行 `repo sync`。

## 仓库内文件

| 文件 | 说明 |
|------|------|
| `tb520fu-r13-droidspaces-minimal.diff` | phase-1：kABI 6/7/8 + `gki_defconfig` 最小项（**已验证**） |

构建脚本会将此 diff 复制到 GKI 树根目录（`$ROOT/tb520fu-r13-droidspaces-minimal.diff`）后 `git apply`。

## 不在仓库内的 diff

`tb520fu-r13-droidspaces-phase2.diff` 若在本地生成，可能含 GKI 树不支持的符号（如 `CONFIG_NETFILTER_XT_TARGET_REJECT`）。  
**phase-2 额外选项** 应通过 Bazel `--defconfig_fragment=//tb520fu:tb520fu_droidspaces_phase2_defconfig` 注入，见 `tools/tb520fu_droidspaces_phase2_defconfig`。

## 外部依赖

- [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) `v6.3.0`  
  `Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch`

首次准备 GKI 树：

```bash
bash tools/prepare_tb520fu_gki_remote.sh --workdir $HOME/tb520fu-gki-r13
cp patches/tb520fu-r13-droidspaces-minimal.diff $HOME/tb520fu-gki-r13/
```