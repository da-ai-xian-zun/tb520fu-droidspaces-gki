# 开发者本地刷机包目录

面向 **自行构建** 的 staging 区；`image/`、`rollback/` 内容 gitignore。

**终端用户**请用 GitHub Release：`tb520fu-droidspaces-phase2-images.zip`（四镜像，无脚本），刷机见 [`docs/MANUAL_FLASH.md`](../docs/MANUAL_FLASH.md)。

| 目录 | 变体 |
|------|------|
| `triplet-phase2/` | 推荐（phase-2） |
| `triplet-minimal/` | phase-1 minimal |

构建后 `image/` 含 `boot_a`、`super_5`、`vbmeta`；`xbl` 从联想 9008 包复制。  
四分区 XML：`triplet-phase2/rawprogram_release_quad.xml`；本地可选 `flash_triplet_test.cmd`（仅三件套，维护者自用）。