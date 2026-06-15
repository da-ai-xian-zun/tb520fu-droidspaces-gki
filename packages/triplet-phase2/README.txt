开发者本地包 — phase-2。终端用户请用 GitHub Release zip。

构建:
  source tools/env.local
  bash tools/build_tb520fu_droidspaces_phase2.sh

打 Release:
  bash tools/pack_release_zip.sh phase2

本地刷机 (需 image/ 已 staging):
  flash_triplet_test.cmd COMx