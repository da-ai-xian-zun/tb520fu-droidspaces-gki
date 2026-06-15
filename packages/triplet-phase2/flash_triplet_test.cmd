@echo off
setlocal

set "ORIGINAL_9008_DIR=D:\TB520FU_ROW_OPEN_USER_Q00002.0_W_ZUI_17.5.10.096_ST_251127"

if "%~1"=="" (
  echo Usage: flash_triplet_test.cmd COMx
  echo Example: flash_triplet_test.cmd COM4
  echo.
  echo This flashes ONLY boot_a + super_5(system_dlkm) + vbmeta_a.
  echo End users: see docs/MANUAL_FLASH.md (Release has images only, no scripts).
  echo Does NOT flash init_boot, vendor_boot, userdata, wipe XMLs, or full super.
  exit /b 2
)

set "PORT=%~1"
set "PKG=%~dp0"

echo [1/2] Loading EDL programmer on %PORT%
"%ORIGINAL_9008_DIR%\QSaharaServer.exe" -k -t 30 -p \\.\%PORT% -s 13:%PKG%image\xbl_s_devprg_ns.melf
if errorlevel 1 exit /b %errorlevel%

echo [2/2] Flashing triplet test: boot_a + super_5 + vbmeta_a
"%ORIGINAL_9008_DIR%\fh_loader.exe" --port=\\.\%PORT% --sendxml=%PKG%rawprogram_triplet_test.xml --search_path=%PKG%image --noprompt --showpercentagecomplete --memoryname=UFS --reset
exit /b %errorlevel%