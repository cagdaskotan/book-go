[CmdletBinding()]
param(
  [string]$DeviceId = 'oz5lmfqwz54xj78l',
  [int]$Port = 8080,
  [string]$PackageName = 'com.cagda.bookapp'
)

$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\cagda\AppData\Local\Android\sdk\platform-tools\adb.exe'

& $adb devices | Out-Host
& $adb -s $DeviceId reverse --remove "tcp:$Port" 2>$null | Out-Null
& $adb -s $DeviceId reverse "tcp:$Port" "tcp:$Port" | Out-Host
& $adb -s $DeviceId shell am force-stop $PackageName | Out-Null
& $adb -s $DeviceId shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host
