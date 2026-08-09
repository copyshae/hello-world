#Requires -Version 5.1
<#
.SYNOPSIS
  將 Google 相簿下載到 E:\GOOGLE相簿（預設 Dry-run）。

.DESCRIPTION
  Google 相簿不是 G: Google Drive，無法用 robocopy 直接拷。
  本腳本用 rclone（官方 Google Photos API）下載到本機。

  第一次請先 -Setup（瀏覽器登入 Google 授權）。
  預設只列出；加 -Execute 才真正下載。
  加 -InstallRclone 會下載免安裝版 rclone 到本工具目錄（不依賴 PATH）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -InstallRclone -Setup
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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsRoot = Split-Path -Parent $ScriptDir
$PortableDir = Join-Path $ToolsRoot 'tools\rclone'
$PortableExe = Join-Path $PortableDir 'rclone.exe'

function Refresh-PathEnv {
  $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  if ($machine -and $user) { $env:Path = "$machine;$user" }
  elseif ($machine) { $env:Path = $machine }
  elseif ($user) { $env:Path = $user }
}

function Find-Rclone {
  if (Test-Path -LiteralPath $PortableExe) { return $PortableExe }

  Refresh-PathEnv
  $cmd = Get-Command rclone.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links\rclone.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "$env:ProgramFiles\rclone\rclone.exe",
    "${env:ProgramFiles(x86)}\rclone\rclone.exe",
    "$env:USERPROFILE\scoop\shims\rclone.exe",
    "$env:USERPROFILE\AppData\Local\Programs\rclone\rclone.exe",
    "C:\ProgramData\chocolatey\bin\rclone.exe"
  )
  foreach ($c in $candidates) {
    if (-not $c) { continue }
    if ((Test-Path -LiteralPath $c) -and $c.ToLower().EndsWith('rclone.exe')) {
      return (Resolve-Path -LiteralPath $c).Path
    }
    if ((Test-Path -LiteralPath $c) -and ((Get-Item -LiteralPath $c).PSIsContainer)) {
      $hit = Get-ChildItem -LiteralPath $c -Filter rclone.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
      if ($hit) { return $hit.FullName }
    }
  }

  # where.exe 有時比 Get-Command 準
  try {
    $where = & where.exe rclone.exe 2>$null
    if ($where) {
      $first = ($where | Select-Object -First 1)
      if ($first -and (Test-Path -LiteralPath $first)) { return $first }
    }
  } catch {}

  return $null
}

function Install-RclonePortable {
  Write-Host ("下載免安裝 rclone 到: {0}" -f $PortableDir)
  New-Item -ItemType Directory -Force -Path $PortableDir | Out-Null
  $zip = Join-Path $env:TEMP ("rclone-windows-amd64-{0}.zip" -f ([guid]::NewGuid().ToString('n')))
  $url = 'https://downloads.rclone.org/rclone-current-windows-amd64.zip'
  Write-Host ("URL: {0}" -f $url)
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

  $extract = Join-Path $env:TEMP ("rclone-extract-{0}" -f ([guid]::NewGuid().ToString('n')))
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

  $exe = Get-ChildItem -LiteralPath $extract -Filter rclone.exe -Recurse | Select-Object -First 1
  if (-not $exe) { throw 'zip 內找不到 rclone.exe' }
  Copy-Item -LiteralPath $exe.FullName -Destination $PortableExe -Force
  # 一併複製同目錄說明檔（可有可無）
  $sibling = Join-Path $exe.DirectoryName 'rclone.1'
  if (Test-Path -LiteralPath $sibling) {
    Copy-Item -LiteralPath $sibling -Destination (Join-Path $PortableDir 'rclone.1') -Force -ErrorAction SilentlyContinue
  }

  Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue

  if (-not (Test-Path -LiteralPath $PortableExe)) {
    throw '免安裝 rclone 安裝失敗'
  }
  return $PortableExe
}

function Install-RcloneIfNeeded {
  param([string]$Existing)
  if ($Existing) { return $Existing }

  Write-Host '找不到 rclone。'
  if (-not $InstallRclone) {
    Write-Host '請加 -InstallRclone（會下載免安裝版，不依賴 PATH）：'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\download-google-photos-to-e.ps1 -InstallRclone -Setup'
    Write-Host '或手動：winget install --id Rclone.Rclone -e 後重開 PowerShell'
    throw '缺少 rclone.exe'
  }

  # 優先免安裝下載（避開 winget PATH 未刷新問題）
  try {
    return (Install-RclonePortable)
  } catch {
    Write-Host ("免安裝下載失敗: {0}" -f $_.Exception.Message)
  }

  $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host '改試 winget 安裝 Rclone.Rclone ...'
    & winget.exe install --id Rclone.Rclone -e --accept-package-agreements --accept-source-agreements
    Refresh-PathEnv
    $found = Find-Rclone
    if ($found) { return $found }
  }

  throw 'rclone 仍找不到。請重開 PowerShell，或手動從 https://rclone.org/downloads/ 下載 windows amd64 zip，解壓後把 rclone.exe 放到 Desktop\hello-world-tools\tools\rclone\'
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

# 用完整路徑呼叫，避免 PATH 問題
$rcloneExe = $rclone

if ($Setup -or -not (Test-RcloneRemote -Rclone $rcloneExe -Name $RemoteName)) {
  Write-Host '=== rclone 授權 Google 相簿（瀏覽器會開啟）==='
  Write-Host '在選單選 n (New remote)：'
  Write-Host ("  name = {0}" -f $RemoteName)
  Write-Host '  Storage = Google Photos'
  Write-Host '  其餘可一路 Enter／依提示用瀏覽器登入'
  Write-Host ''
  Write-Host '啟動：rclone config'
  & $rcloneExe config
  if (-not (Test-RcloneRemote -Rclone $rcloneExe -Name $RemoteName)) {
    throw ("仍找不到 remote「{0}:」。請確認 config 裡名稱正好是 {0}" -f $RemoteName)
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
    & $rcloneExe copy $j.Src $j.Dst --progress --transfers 4 --checkers 8 --retries 3 --low-level-retries 10
    if ($LASTEXITCODE -ne 0) {
      throw ("rclone copy 失敗 exit={0}  src={1}" -f $LASTEXITCODE, $j.Src)
    }
  } else {
    Write-Host '預覽（lsf，可能較久／需已授權）：'
    & $rcloneExe lsf $j.Src --max-depth 1 2>&1 | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
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
}

