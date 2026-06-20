# 建议

有 agent 的话 clone 本仓库让它帮你装；只想刷机再用 [v1.0.0 四镜像 Release](https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/releases/tag/v1.0.0)。

本 Release **只有 App**，不含内核镜像。

# 这是什么

**Droidspaces-loopfix-tb520fu.apk** — 在官方 v6.3.0 上加 sparse loop 高 minor 扫描回退（见仓库 `patches/`）。

联想 TB520FU 上：**stock 官方 App 点 Sparse 新建会挂**；这个魔改版在维护者机上 sparse 安装 + 启停 E2E 已过。其他机型自己试，不打包票。

# 使用方法

0. 已刷 [v1.0.0 GKI](https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/releases/tag/v1.0.0) 或自编译同等内核（`max_loop=64` 那套）
1. **先卸载** Play/GitHub 官方 `com.droidspaces.app`（签名不同，不能直接覆盖装）
2. 安装本 Release 的 `Droidspaces-loopfix-tb520fu.apk`
3. 可选但建议：用仓库 `tools/install_loopfix_persistent.sh` 钉住 loopfix CLI（见 `APK-README.txt`）
4. App 里新建 Sparse 容器；勿再用 stock APK 点 Sparse

校验：`sha256sum -c SHA256SUMS-apk.txt`

# 和 v1.0.0 的关系

| Release | 内容 |
|---------|------|
| v1.0.0 | 四镜像 9008 刷机包 |
| **v1.0.1**（本页） | loopfix 魔改 App，**单独下、单独装** |

上游 [Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) 若合并同类修复，请改回官方 App。

# 仓库新增（相对 v1.0.0 tag）

- `patches/` — 拟 upstream 的 loop-scan 补丁栈
- `docs/UPSTREAM-ISSUE-PR*.md` — Issue/PR 草稿
- `docs/SPARSE-MOUNT-RESEARCH.md` — 实测专档
- sparse/loopfix 相关 `tools/`