#Requires -Version 5.1
# 掃具台｜開啟手機 PWA 版（掃具請領管理）
param([string]$WorkDir = "")

$ErrorActionPreference = 'Stop'
$PhoneUrl = 'https://copyshae.github.io/hello-world/directory/apps/scan-equip/'

try {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.Clipboard]::SetText($PhoneUrl)
  [void][System.Windows.Forms.MessageBox]::Show(
    "掃具台手機版網址已複製到剪貼簿：`r`n$PhoneUrl`r`n`r`n即將開啟瀏覽器…",
    '掃具台'
  )
  Start-Process $PhoneUrl
} catch {
  Start-Process $PhoneUrl
}
