#Requires -Version 5.1
<#
.SYNOPSIS
  將 Google 相簿下載到 E:\GOOGLE相簿。

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
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsRoot = Split-Path -Parent $ScriptDir
$PortableDir = Join-Path $ToolsRoot 'tools\rclone'
$PortableExe = Join-Path $PortableDir 'rclone.exe'

function Refresh-PathEnv {
  $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @()
  if ($machine) { $parts += $machine }
  if ($user) { $parts += $user }
  if ($parts.Count -gt 0) { $env:Path = ($parts -join ';') }
}

function Find-Rclone {
  if (Test-Path -LiteralPath $PortableExe) { return (Resolve-Path -LiteralPath $PortableExe).Path }
  Refresh-PathEnv
  $cmd = Get-Command rclone.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $searchRoots = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "$env:ProgramFiles\rclone",
    "${env:ProgramFiles(x86)}\rclone",
    "$env:USERPROFILE\scoop\shims",
    "$env:USERPROFILE\AppData\Local\Programs\rclone",
    "C:\ProgramData\chocolatey\bin"
  )
  foreach ($root in $searchRoots) {
    if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
    $hit = Get-ChildItem -LiteralPath $root -Filter rclone.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  return $null
}

function Install-RclonePortable {
  Write-Host ("下載免安裝 rclone -> {0}" -f $PortableDir)
  New-Item -ItemType Directory -Force -Path $PortableDir | Out-Null
  $zip = Join-Path $env:TEMP 'rclone-windows-amd64.zip'
  $extract = Join-Path $env:TEMP 'rclone-extract-hw'
  Invoke-WebRequest -Uri 'https://downloads.rclone.org/rclone-current-windows-amd64.zip' -OutFile $zip -UseBasicParsing
  if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
  Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
  $exe = Get-ChildItem -LiteralPath $extract -Filter rclone.exe -Recurse | Select-Object -First 1
  if (-not $exe) { throw 'zip 內找不到 rclone.exe' }
  Copy-Item -LiteralPath $exe.FullName -Destination $PortableExe -Force
  if (-not (Test-Path -LiteralPath $PortableExe)) { throw '免安裝 rclone 複製失敗' }
  Write-Host ("OK {0}" -f $PortableExe)
  return $PortableExe
}

function Get-RcloneExe {
  $found = Find-Rclone
  if ($found) { return $found }
  Write-Host '找不到 rclone，改下載免安裝版（不走 winget）...'
  if (-not $InstallRclone) {
    Write-Host '也可加 -InstallRclone；此次因缺少 rclone，仍自動下載免安裝版。'
  }
  return (Install-RclonePortable)
}

function Test-RcloneRemote {
  param([string]$Rclone, [string]$Name)
  $list = & $Rclone listremotes 2>$null
  foreach ($line in @($list)) {
    if ($null -ne $line -and $line.Trim() -eq ($Name + ':')) { return $true }
  }
  return $false
}

if (-not (Test-Path -LiteralPath 'E:\')) {
  throw '找不到 E:\。請插入外接碟。'
}

$rcloneExe = Get-RcloneExe
Write-Host ("rclone: {0}" -f $rcloneExe)
Write-Host ("Dest:   {0}" -f $DestRoot)
Write-Host ("Remote: {0}:" -f $RemoteName)
Write-Host ("Scope:  {0}" -f $Scope)
Write-Host ("Mode:   {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ''

if ($Setup -or -not (Test-RcloneRemote -Rclone $rcloneExe -Name $RemoteName)) {
  Write-Host '=== rclone 授權 Google 相簿 ==='
  Write-Host '選 n (New remote)'
  Write-Host ("  name = {0}" -f $RemoteName)
  Write-Host '  Storage = Google Photos'
  Write-Host '  其餘 Enter，用瀏覽器登入'
  & $rcloneExe config
  if (-not (Test-RcloneRemote -Rclone $rcloneExe -Name $RemoteName)) {
    throw ("仍找不到 remote「{0}:」" -f $RemoteName)
  }
}

if ($Execute -and -not (Test-Path -LiteralPath $DestRoot)) {
  New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
  Write-Host "MKDIR $DestRoot"
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
      throw ("rclone copy 失敗 exit={0}" -f $LASTEXITCODE)
    }
  } else {
    Write-Host '(dry-run) 加 -Execute 才下載。先確認 remote 可用：'
    & $rcloneExe lsf $j.Src --max-depth 1 2>&1 | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
  }
}

Write-Host ''
if ($Execute) {
  Write-Host '下載完成。'
  Write-Host ("目的: {0}" -f $DestRoot)
} else {
  Write-Host '預覽結束。下載請加 -Execute'
}
