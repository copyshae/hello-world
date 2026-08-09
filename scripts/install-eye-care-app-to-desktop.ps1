#Requires -Version 5.1
<#
.SYNOPSIS
  安裝「護眼提醒」到桌面。兩台都有 Cursor 時，各跑一次即可。

.PARAMETER UseOneDrive
  提醒時間／文案（reminders.json）存到 OneDrive\EyeCareReminder，兩台登同一帳號會同步。
  「今天已提醒過」狀態仍只存在各電腦本機。
#>
param(
  [switch]$UseOneDrive
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here 'eye-care-reminder-app.ps1'
if (-not (Test-Path -LiteralPath $src)) {
  throw "找不到 $src ；請在 hello-world 執行：git fetch / git checkout 取出 scripts"
}

function Get-OneDriveRoot {
  foreach ($p in @(
      $env:OneDrive,
      $env:OneDriveConsumer,
      $env:OneDriveCommercial,
      (Join-Path $env:USERPROFILE 'OneDrive')
    )) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  return $null
}

$desk = [Environment]::GetFolderPath('Desktop')
$appDir = Join-Path $desk 'EyeCareReminder'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
$appPs1 = Join-Path $appDir 'eye-care-reminder-app.ps1'
Copy-Item -LiteralPath $src -Destination $appPs1 -Force

$syncDir = $null
$launchName = 'eye-care-reminder-app.ps1'

if ($UseOneDrive) {
  $od = Get-OneDriveRoot
  if (-not $od) { throw '找不到 OneDrive，請先登入後再加 -UseOneDrive' }
  $syncDir = Join-Path $od 'EyeCareReminder'
  New-Item -ItemType Directory -Force -Path $syncDir | Out-Null

  # 若桌面已有設定，複製到 OneDrive（不覆蓋已存在）
  $localJson = Join-Path $appDir 'reminders.json'
  $syncJson = Join-Path $syncDir 'reminders.json'
  if ((Test-Path -LiteralPath $localJson) -and -not (Test-Path -LiteralPath $syncJson)) {
    Copy-Item -LiteralPath $localJson -Destination $syncJson -Force
  }

  $launch = Join-Path $appDir 'launch-with-onedrive.ps1'
  $launchText = @"
#Requires -Version 5.1
`$ErrorActionPreference = 'Stop'
`$app = Join-Path `$PSScriptRoot 'eye-care-reminder-app.ps1'
`$od = `$env:OneDrive
if (-not `$od) { `$od = `$env:OneDriveConsumer }
if (-not `$od) { `$od = Join-Path `$env:USERPROFILE 'OneDrive' }
`$sync = Join-Path `$od 'EyeCareReminder'
New-Item -ItemType Directory -Force -Path `$sync | Out-Null
& `$app -DataDir `$PSScriptRoot -SyncDir `$sync
"@
  Set-Content -LiteralPath $launch -Value $launchText -Encoding UTF8
  $launchName = 'launch-with-onedrive.ps1'
}

# 清理 autoClose
foreach ($jp in @(
    (Join-Path $appDir 'reminders.json'),
    $(if ($syncDir) { Join-Path $syncDir 'reminders.json' } else { $null })
  )) {
  if (-not $jp -or -not (Test-Path -LiteralPath $jp)) { continue }
  try {
    $cfg = Get-Content -LiteralPath $jp -Encoding UTF8 -Raw | ConvertFrom-Json
    foreach ($it in @($cfg.items)) { $it.autoCloseSeconds = 0 }
    $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jp -Encoding UTF8
  } catch {}
}

$vbsBody = @"
Set sh = CreateObject("WScript.Shell")
desk = sh.SpecialFolders("Desktop")
ps1 = desk & "\EyeCareReminder\$launchName"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
sh.Run cmd, 0, False
"@
Set-Content -LiteralPath (Join-Path $appDir 'launch.vbs') -Value $vbsBody -Encoding ASCII
Set-Content -LiteralPath (Join-Path $desk '護眼提醒.vbs') -Value $vbsBody -Encoding ASCII

$dbgLines = @(
  '@echo off'
  'chcp 65001 >nul'
  'cd /d "%USERPROFILE%\Desktop\EyeCareReminder"'
  'dir /b'
  "powershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\Desktop\EyeCareReminder\$launchName`""
  'echo.'
  'pause'
)
$dbgLines | Set-Content -LiteralPath (Join-Path $appDir 'debug.cmd') -Encoding ASCII
$dbgLines | Set-Content -LiteralPath (Join-Path $desk '護眼提醒-除錯.cmd') -Encoding ASCII

Write-Host "Installed: $appDir"
Write-Host "Launcher:  Desktop\護眼提醒.vbs  ->  $launchName"
if ($UseOneDrive) {
  Write-Host "Synced config: $syncDir\reminders.json"
  Write-Host "兩台都用 -UseOneDrive 且登同一 OneDrive，改時間／文案會跟著同步。"
} else {
  Write-Host "Config local: $appDir\reminders.json（兩台各自獨立；要同步請加 -UseOneDrive）"
}
