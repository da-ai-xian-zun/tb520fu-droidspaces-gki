@echo off
setlocal

set "ORIGINAL_9008_DIR=D:\TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127"

if "%~1"=="" (
  echo Usage: rollback_triplet.cmd COMx
  echo Example: rollback_triplet.cmd COM4
  exit /b 2
)

set "PORT=%~1"
set "PKG=%~dp0"

echo [1/2] Loading EDL programmer on %PORT%
"%ORIGINAL_9008_DIR%\QSaharaServer.exe" -k -t 30 -p \\.\%PORT% -s 13:%PKG%image\xbl_s_devprg_ns.melf
if errorlevel 1 exit /b %errorlevel%

echo [2/2] Rolling back triplet: stock boot_a + stock system_dlkm + live SukiSU vbmeta
"%ORIGINAL_9008_DIR%\fh_loader.exe" --port=\\.\%PORT% --sendxml=%PKG%rawprogram_triplet_rollback.xml --search_path=%PKG%rollback --noprompt --showpercentagecomplete --memoryname=UFS --reset
exit /b %errorlevel%