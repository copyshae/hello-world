#Requires -Version 5.1
<#
.SYNOPSIS
  把「護眼提醒」安裝到桌面：VBS 靜音啟動（不閃黑窗）；路徑用英文資料夾較穩。
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'eye-care-reminder-app.ps1'
if (-not (Test-Path -LiteralPath $src)) {
  throw "找不到 $src ；請先用 git 取出此檔"
}

$desk = [Environment]::GetFolderPath('Desktop')
# 用英文資料夾，避免 .cmd / .vbs 編碼把中文路徑弄壞
$appDir = Join-Path $desk 'EyeCareReminder'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
$appPs1 = Join-Path $appDir 'eye-care-reminder-app.ps1'
Copy-Item -LiteralPath $src -Destination $appPs1 -Force

# 若舊的中文資料夾有 reminders.json，搬過來
$oldDir = Join-Path $desk '護眼提醒'
$jsonPath = Join-Path $appDir 'reminders.json'
$oldJson = Join-Path $oldDir 'reminders.json'
if ((-not (Test-Path -LiteralPath $jsonPath)) -and (Test-Path -LiteralPath $oldJson)) {
  Copy-Item -LiteralPath $oldJson -Destination $jsonPath -Force
}
if (Test-Path -LiteralPath $jsonPath) {
  try {
    $cfg = Get-Content -LiteralPath $jsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($it in @($cfg.items)) { $it.autoCloseSeconds = 0 }
    $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
  } catch {}
}

# VBS（ASCII 安全：路徑只有英文）
$vbsBody = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
ps1 = desk & "\EyeCareReminder\eye-care-reminder-app.ps1"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
sh.Run cmd, 0, False
"@
$vbs = Join-Path $appDir 'launch.vbs'
Set-Content -LiteralPath $vbs -Value $vbsBody -Encoding ASCII
$deskVbs = Join-Path $desk '護眼提醒.vbs'
Set-Content -LiteralPath $deskVbs -Value $vbsBody -Encoding ASCII

# 除錯 CMD：寫死英文路徑
$dbgLines = @(
  '@echo off'
  'chcp 65001 >nul'
  "cd /d `"%USERPROFILE%\Desktop\EyeCareReminder`""
  'echo Current folder:'
  'cd'
  'dir /b'
  'echo.'
  'echo Starting app...'
  'powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\Desktop\EyeCareReminder\eye-care-reminder-app.ps1"'
  'echo.'
  'echo If you saw red errors, take a photo. Press any key.'
  'pause'
)
$dbg = Join-Path $appDir 'debug.cmd'
$dbgLines | Set-Content -LiteralPath $dbg -Encoding ASCII
$deskDbg = Join-Path $desk '護眼提醒-除錯.cmd'
$dbgLines | Set-Content -LiteralPath $deskDbg -Encoding ASCII

foreach ($old in @(
    (Join-Path $desk '護眼提醒.cmd')
  )) {
  if (Test-Path -LiteralPath $old) {
    Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Installed to: $appDir"
Write-Host "Script: $appPs1"
Write-Host "Double-click Desktop: 護眼提醒.vbs"
Write-Host "Debug: 護眼提醒-除錯.cmd"
