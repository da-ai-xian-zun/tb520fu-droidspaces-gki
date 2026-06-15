Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
    Select-Object DeviceID, Name, Description, PNPDeviceID |
    Format-Table -AutoSize -Wrap
Write-Host '--- USB ---'
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.Class -in @('Ports','USB','AndroidUsbDeviceClass') -or $_.FriendlyName -match 'COM|Qualcomm|QDLoader|9008|Android|ADB' } |
    Select-Object FriendlyName, Class, InstanceId, Status |
    Format-Table -AutoSize -Wrap