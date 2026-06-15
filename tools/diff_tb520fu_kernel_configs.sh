#!/usr/bin/env bash
set -euo pipefail
ROOT="/mnt/c/tb520fu-kernel-diff-20260614"
cd "$ROOT"

keys='CONFIG_LOCALVERSION|CONFIG_LOCALVERSION_AUTO|CONFIG_LTO|CONFIG_LTO_CLANG|CONFIG_LTO_NONE|CONFIG_LTO_CLANG_FULL|CONFIG_LTO_CLANG_THIN|CONFIG_CFI|CONFIG_CFI_CLANG|CONFIG_TRIM_UNUSED_KSYMS|CONFIG_UNUSED_KSYMS_WHITELIST|CONFIG_KALLSYMS|CONFIG_KALLSYMS_ALL|CONFIG_ANDROID_VENDOR_HOOKS|CONFIG_ANDROID_KABI|CONFIG_MODULES|CONFIG_MODVERSIONS|CONFIG_MODULE_SIG|CONFIG_QCOM|CONFIG_SND|CONFIG_SOUND|CONFIG_SND_SOC|CONFIG_GPR|CONFIG_QCOM_APR|CONFIG_QCOM_Q6|CONFIG_QCOM_AUDIO|CONFIG_MSM|CONFIG_PINCTRL|CONFIG_REGULATOR|CONFIG_INTERCONNECT|CONFIG_RPMSG|CONFIG_REMOTEPROC|CONFIG_PDR|CONFIG_QMI|CONFIG_SYSVIPC|CONFIG_POSIX_MQUEUE|CONFIG_IPC_NS|CONFIG_PID_NS|CONFIG_DEVTMPFS|CONFIG_CGROUP'

for d in stock-device-boot_a fw-package-boot official-certified-r13 selfbuilt-vanilla-r13 selfbuilt-stamped-r13 selfbuilt-droidspaces-r13 community-oki-6.1.118; do
  if [ -f "$d/ikconfig.txt" ]; then
    grep -E "^($keys)(=| is not set)" "$d/ikconfig.txt" | sort > "$d/keyconfig.txt" || true
  fi
done

compare() {
  a="$1"; b="$2"; out="$3"
  {
    echo "# diff $a vs $b"
    echo
    diff -u "$a/keyconfig.txt" "$b/keyconfig.txt" || true
  } > "$out"
}

compare stock-device-boot_a selfbuilt-stamped-r13 diff-stock-vs-stamped-keyconfig.diff
compare stock-device-boot_a selfbuilt-vanilla-r13 diff-stock-vs-vanilla-keyconfig.diff
compare stock-device-boot_a selfbuilt-droidspaces-r13 diff-stock-vs-droidspaces-keyconfig.diff
compare stock-device-boot_a community-oki-6.1.118 diff-stock-vs-oki-keyconfig.diff
compare stock-device-boot_a official-certified-r13 diff-stock-vs-official-keyconfig.diff
compare fw-package-boot stock-device-boot_a diff-fw-vs-device-stock-keyconfig.diff

python3 - <<'PY'
from pathlib import Path
root=Path('/mnt/c/tb520fu-kernel-diff-20260614')
names=['stock-device-boot_a','fw-package-boot','official-certified-r13','selfbuilt-vanilla-r13','selfbuilt-stamped-r13','selfbuilt-droidspaces-r13','community-oki-6.1.118']
configs={}
for n in names:
    d={}
    p=root/n/'ikconfig.txt'
    for line in p.read_text(errors='ignore').splitlines():
        if line.startswith('# CONFIG_') and line.endswith(' is not set'):
            d[line[2:-11]]='n'
        elif line.startswith('CONFIG_') and '=' in line:
            k,v=line.split('=',1); d[k]=v
    configs[n]=d
interesting=[]
for k in sorted(set().union(*[set(c) for c in configs.values()])):
    vals=[configs[n].get(k,'<absent>') for n in names]
    if len(set(vals))>1 and any(s in k for s in ['QCOM','SND','SOUND','GPR','APR','AUDIO','VENDOR','KABI','LTO','TRIM','KALLSYMS','MODULE','SYSVIPC','MQUEUE','IPC_NS','PID_NS','DEVTMPFS','CGROUP']):
        interesting.append((k, vals))
with (root/'interesting-config-diff.tsv').open('w',encoding='utf-8') as f:
    f.write('CONFIG\t'+'\t'.join(names)+'\n')
    for k, vals in interesting:
        f.write(k+'\t'+'\t'.join(vals)+'\n')
print('interesting', len(interesting))
PY

for f in diff-stock-vs-official-keyconfig.diff diff-fw-vs-device-stock-keyconfig.diff diff-stock-vs-stamped-keyconfig.diff diff-stock-vs-droidspaces-keyconfig.diff; do
  echo "==== $f"
  sed -n '1,220p' "$f"
done

echo ==== interesting-config-diff.tsv
sed -n '1,160p' interesting-config-diff.tsv
