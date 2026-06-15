param([int]$TimeoutSec = 30)
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    $ports = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PNPDeviceID -like '*05C6*9008*' -or
            $_.PNPDeviceID -like '*05C6*' -or
            $_.Name -like '*QDLoader*' -or
            $_.Description -like '*QDLoader*'
        }
    if ($ports) {
        $ports | Select-Object DeviceID, Name, Description, PNPDeviceID
        exit 0
    }
    Start-Sleep -Seconds 2
}
Write-Error "No 9008/QDLoader COM port found within ${TimeoutSec}s"
exit 1