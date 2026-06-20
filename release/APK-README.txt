Droidspaces loopfix APK — TB520FU（非官方构建）
================================================

文件: Droidspaces-loopfix-tb520fu.apk
基于: Droidspaces-OSS v6.3.0 + patches/ @ 76cbd21（高 minor losetup 回退）
构建: tools/build_droidspaces_apk_loopfix.ps1（debug 签名）

校验:
  sha256sum -c SHA256SUMS-apk.txt

安装（须先卸官方 App，签名不同）:
  adb install Droidspaces-loopfix-tb520fu.apk

装后建议（持久化 loopfix CLI，防官方覆盖）:
  adb push tools/install_loopfix_persistent.sh /data/local/tmp/
  adb push output/droidspaces-loopfix/droidspaces-aarch64-loopfix /data/local/tmp/droidspaces-loopfix
  adb shell su 0 sh /data/local/tmp/install_loopfix_persistent.sh /data/local/tmp/droidspaces-loopfix

验证范围:
  联想 TB520FU（ZUI 17.5.10.096 ROW）— App sparse 新建 + stop/start E2E 已验
  其他机型未作为本 Release 承诺

说明:
  - 非 ravindu644 官方 Release；上游合并 loop-scan 后请改回官方 App
  - stock GitHub/Play 版 App 在 TB520FU 上 Sparse 新建仍会失败
  - 补丁源码: https://github.com/da-ai-xian-zun/tb520fu-droidspaces-gki/tree/main/patches
  - 专档: docs/SPARSE-MOUNT-RESEARCH.md §5.4

许可: 遵循 Droidspaces-OSS GPL-3.0；本构建为研究/自用分发，风险自负