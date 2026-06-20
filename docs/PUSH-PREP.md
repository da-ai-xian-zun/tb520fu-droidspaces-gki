# Push preparation checklist

Two separate git roots:

| Repo | Path | Remote (intended) | Role |
|------|------|-------------------|------|
| TB520FU GKI + research | `.` (this repo) | `da-ai-xian-zun/tb520fu-droidspaces-gki` | patches, tools, docs, kernel build notes |
| Droidspaces-OSS working tree | `vendor/Droidspaces-OSS/` | fork: `da-ai-xian-zun/Droidspaces-OSS` | upstream PR branch (apply patches → commit → PR to `ravindu644`) |

`vendor/` and `output/` are **gitignored** in the kernel repo — patches under `patches/` are the canonical diff.

---

## 1. Kernel / research repo (`tb520fu-droidspaces-gki`)

### Before commit

```powershell
# Review what will be tracked (respects .gitignore)
git status
git diff --stat

# Optional: stage upstream docs + patches + sparse tools only
git add docs/UPSTREAM-ISSUE-PR.md docs/UPSTREAM-ISSUE-PR-EN.md docs/PUSH-PREP.md
git add docs/UPSTREAM-SUBMISSION-SAMPLE.md patches/
git add tools/sparse_*.sh tools/*loopfix* tools/install_loopfix_persistent.sh
git add tools/build_droidspaces_apk_loopfix.ps1 tools/build_droidspaces_apk_loopfix.sh
git add "docs/app内按按钮"*.txt
```

### Intentionally ignored (see `.gitignore`)

- `output/` — APK, logs, precheck dumps
- `vendor/` — Droidspaces clone
- `release/oneplus-pkr110/` — kernel zip binaries
- `tools/anland*` / KDE experiment scripts
- `glm5.2*.txt`, `agent-tools/`, `mcps/`, `terminals/`

### When ready (manual)

```powershell
git commit -m "docs: upstream sparse loop issue/PR drafts and patch stack"
git push origin main   # YOU run this — not automated
```

---

## 2. Droidspaces-OSS fork (`vendor/Droidspaces-OSS`) — ✅ 已备好，待 push

详见 [`PUSH-PREP-DROIDSPACES.md`](PUSH-PREP-DROIDSPACES.md)。

| 项 | 状态 |
|----|------|
| `fork` remote | ✅ |
| 分支 `android/sparse-loop-scan` | ✅ 3 commits @ `76cbd21` |
| 工作区 | ✅ clean |

```powershell
cd vendor\Droidspaces-OSS
git push fork android/sparse-loop-scan
```

然后按 `UPSTREAM-ISSUE-PR-EN.md` 开 Issue → PR 到 `ravindu644/Droidspaces-OSS`。

---

## 3. GitHub Issue (separate from git push)

1. Open issue on `ravindu644/Droidspaces-OSS` using English body from `docs/UPSTREAM-ISSUE-PR-EN.md`.
2. Upload `.txt` logs (drag-drop) — do not rely on `output/` URLs (not in git).
3. After issue number exists, fill `Fixes #NNN` in PR body.