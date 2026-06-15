# TB520FU 9008 刷机包 — Droidspaces phase-1 minimal

## 构建

```bash
cd tb520fu-droidspaces-gki
source tools/env.local
bash tools/build_tb520fu_droidspaces_minimal.sh
```

仅重打包：bash tools/pack_tb520fu_droidspaces_triplet.sh

## 刷入

flash_full.cmd COMx           :: 新手：init_boot + 三件套
flash_triplet_test.cmd COMx   :: 仅三件套

详见 ../README.md 与 ../../docs/BUILD.md