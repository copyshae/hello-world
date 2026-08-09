#Requires -Version 5.1
<#
.SYNOPSIS
  將 Google 相簿下載到 E:\GOOGLE相簿（預設 Dry-run）。

.DESCRIPTION
  Google 相簿不是 G: Google Drive，無法用 robocopy 直接拷。
  本腳本用 rclone（官方 Google Photos API）下載到本機。

  第一次請先 -Setup（瀏覽器登入 Google 授權）。
  預設只列出；加 -Execute 才真正下載。

  限制（Google API）：
  - 部分項目可能不是「原始檔」畫質
  - 共用相簿／對方分享內容可能抓不到
  - 若要官方完整打包，改用 Google Takeout（見 README）

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Setup
  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DestRoot = 'E:\GOOGLE相簿',
  [string]$RemoteName = 'gphotos',
  [ValidateSet('all', 'albums', 'both')]
  [string]$Scope = 'both',
  [switch]$Setup,
  [switch]$Execute,
  [switch]$InstallRclone
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Find-Rclone {
  $cmd = Get-Command rclone.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links\rclone.exe",
    "$env:ProgramFiles\rclone\rclone.exe",
    "${env:ProgramFiles(x86)}\rclone\rclone.exe",
    "$env:USERPROFILE\scoop\shims\rclone.exe",
    "$env:USERPROFILE\AppData\Local\Programs\rclone\rclone.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

function Install-RcloneIfNeeded {
  param([string]$Existing)
  if ($Existing) { return $Existing }

  Write-Host '找不到 rclone。'
  if (-not $InstallRclone) {
    Write-Host '請擇一安裝後重跑，或加 -InstallRclone 嘗試自動安裝：'
    Write-Host '  winget install --id Rclone.Rclone -e'
    Write-Host '  或 https://rclone.org/downloads/'
    throw '缺少 rclone.exe'
  }

  $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw '找不到 winget，請手動安裝 rclone：https://rclone.org/downloads/'
  }
  Write-Host '正在以 winget 安裝 Rclone.Rclone ...'
  & winget.exe install --id Rclone.Rclone -e --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $found = Find-Rclone
  if (-not $found) {
    throw 'rclone 安裝後仍找不到。請關閉並重開 PowerShell 後再跑一次。'
  }
  return $found
}

function Test-RcloneRemote {
  param([string]$Rclone, [string]$Name)
  $list = & $Rclone listremotes 2>$null
  if (-not $list) { return $false }
  foreach ($line in $list) {
    if ($line.Trim() -eq ($Name + ':')) { return $true }
  }
  return $false
}

if (-not (Test-Path -LiteralPath 'E:\')) {
  throw '找不到 E:\。請插入外接碟。'
}

$rclone = Install-RcloneIfNeeded -Existing (Find-Rclone)
Write-Host ("rclone: {0}" -f $rclone)
Write-Host ("Dest:   {0}" -f $DestRoot)
Write-Host ("Remote: {0}:" -f $RemoteName)
Write-Host ("Scope:  {0}" -f $Scope)
Write-Host ("Mode:   {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ''

if ($Setup -or -not (Test-RcloneRemote -Rclone $rclone -Name $RemoteName)) {
  Write-Host '=== rclone 授權 Google 相簿（瀏覽器會開啟）==='
  Write-Host '依畫面操作：n → 名稱填下方 RemoteName → 選 Google Photos → 依提示登入。'
  Write-Host ("建議 remote 名稱：{0}" -f $RemoteName)
  Write-Host ''
  Write-Host '若要用非互動快速建立（仍會開瀏覽器），也可手動執行：'
  Write-Host ("  rclone config create {0} google photos" -f $RemoteName)
  Write-Host ''
  if ($Setup -or -not (Test-RcloneRemote -Rclone $rclone -Name $RemoteName)) {
    Write-Host '啟動：rclone config'
    & $rclone config
  }
  if (-not (Test-RcloneRemote -Rclone $rclone -Name $RemoteName)) {
    throw ("仍找不到 remote「{0}:」。請在 rclone config 建立 Google Photos remote，名稱設為 {0}" -f $RemoteName)
  }
}

if (-not (Test-Path -LiteralPath $DestRoot)) {
  if ($Execute) {
    New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
    Write-Host "MKDIR $DestRoot"
  } else {
    Write-Host "(dry-run) 將建立: $DestRoot"
  }
}

$jobs = @()
if ($Scope -eq 'all' -or $Scope -eq 'both') {
  $jobs += [pscustomobject]@{ Src = ($RemoteName + ':media/all'); Dst = (Join-Path $DestRoot '全部媒體') }
}
if ($Scope -eq 'albums' -or $Scope -eq 'both') {
  $jobs += [pscustomobject]@{ Src = ($RemoteName + ':album'); Dst = (Join-Path $DestRoot '相簿') }
}

foreach ($j in $jobs) {
  Write-Host ''
  Write-Host ("--- {0}  ->  {1}" -f $j.Src, $j.Dst)
  if ($Execute) {
    if (-not (Test-Path -LiteralPath $j.Dst)) {
      New-Item -ItemType Directory -Path $j.Dst -Force | Out-Null
    }
    # --track-renames 不適用 photos；用 copy 不刪本機多餘檔
    & $rclone copy $j.Src $j.Dst --progress --transfers 4 --checkers 8 --retries 3 --low-level-retries 10
    if ($LASTEXITCODE -ne 0) {
      throw ("rclone copy 失敗 exit={0}  src={1}" -f $LASTEXITCODE, $j.Src)
    }
  } else {
    Write-Host '預覽（lsf，可能較久／需已授權）：'
    & $rclone lsf $j.Src --max-depth 1 2>&1 | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
    Write-Host '(只顯示前 40 筆；加 -Execute 才下載)'
  }
}

Write-Host ''
if ($Execute) {
  Write-Host '下載完成（可重跑同一指令續傳）。'
  Write-Host ("目的: {0}" -f $DestRoot)
  Get-ChildItem -LiteralPath $DestRoot -Force -ErrorAction SilentlyContinue |
    Select-Object Mode, LastWriteTime, Name |
    Format-Table -AutoSize | Out-String | Write-Host
} else {
  Write-Host '以上為預覽。確認授權與路徑後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Execute'
  Write-Host '第一次若尚未授權：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -Setup'
}

