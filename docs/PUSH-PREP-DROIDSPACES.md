# Droidspaces-OSS fork — push 前状态（`vendor/Droidspaces-OSS`）

> 本目录在内核仓 `.gitignore` 中；状态以本文为准（更新于 2026-06-21）。

## Remotes

| 名 | URL | 用途 |
|----|-----|------|
| `origin` | `ravindu644/Droidspaces-OSS` | 上游 |
| `fork` | `da-ai-xian-zun/Droidspaces-OSS` | 你的 fork（push 目标） |

## 分支（已就绪，未 push）

```
android/sparse-loop-scan  (base 76cbd21)
  f7990be android: write container.config before sparse umount (ContainerInstaller)
  9058a8d android: sparse installer loop-scan fallback after stock mount chain
  c67eff7 mount: android loop attach via high-minor scan when GET_FREE fails
```

工作区：**clean**（`git status` 无未提交改动）

## 与 fork/main 的关系

- `fork/main` 仍停在较旧提交（约落后 `origin/main` 6 个 commit）
- 本分支基于当前上游 `76cbd21`，**不要** merge 进 `fork/main`；直接 push 新分支即可

## Push（你手动执行）

```powershell
cd D:\project\tb520fu-droidspaces-gki\vendor\Droidspaces-OSS
git push fork android/sparse-loop-scan
```

## 开 PR 到上游

1. 先在 `ravindu644/Droidspaces-OSS` 用 `docs/UPSTREAM-ISSUE-PR-EN.md` 开 **Issue**（英文）
2. GitHub：**Compare** `ravindu644:main` ← `da-ai-xian-zun:android/sparse-loop-scan`
3. PR 标题/正文：`docs/UPSTREAM-ISSUE-PR-EN.md` PR 段；`Fixes #NNN` 填 Issue 号
4. 不要写魔改 APK / TB520FU 内核镜像；实测摘要可引用 Issue 附件

## PR 前可选检查

```powershell
# 补丁与内核仓 patches/ 一致（在干净 76cbd21 上）
cd vendor/Droidspaces-OSS
git checkout 76cbd21 --detach
git apply --check ../../patches/droidspaces-android-loop-scan.patch
git apply --check ../../patches/sparsemgr-loop-scan.patch
git apply --check ../../patches/sparseimageinstaller-loop-scan.patch
git apply --check ../../patches/sparseimageinstaller-unmount-after-config.patch
git checkout android/sparse-loop-scan
```