$dev = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*VID_05C6&PID_9008*' }
if (-not $dev) { Write-Error '9008 device not found'; exit 1 }
$dev | Format-Table FriendlyName, InstanceId, Status -AutoSize
Write-Host 'Disabling...'
Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
Start-Sleep -Seconds 3
Write-Host 'Enabling...'
Enable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
Start-Sleep -Seconds 5
Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
    Where-Object { $_.PNPDeviceID -like '*05C6*' } |
    Select-Object DeviceID, Name