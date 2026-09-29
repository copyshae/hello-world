#Requires -Version 5.1
# 一次性：下載 rclone 免安裝版 + 授權 + 下載 Google 相簿到 E:\GOOGLE相簿
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Join-Path $env:USERPROFILE 'Desktop\hello-world-tools'
$RcloneDir = Join-Path $Root 'tools\rclone'
$RcloneExe = Join-Path $RcloneDir 'rclone.exe'
$DestRoot = 'E:\GOOGLE相簿'
$RemoteName = 'gphotos'

if (-not (Test-Path -LiteralPath 'E:\')) { throw '找不到 E:\，請插入外接碟' }
New-Item -ItemType Directory -Force -Path $RcloneDir | Out-Null
New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

if (-not (Test-Path -LiteralPath $RcloneExe)) {
  Write-Host '下載 rclone 免安裝版...'
  $zip = Join-Path $env:TEMP 'rclone-windows-amd64.zip'
  $extract = Join-Path $env:TEMP 'rclone-extract'
  Invoke-WebRequest -Uri 'https://downloads.rclone.org/rclone-current-windows-amd64.zip' -OutFile $zip -UseBasicParsing
  if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
  Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
  $exe = Get-ChildItem -LiteralPath $extract -Filter rclone.exe -Recurse | Select-Object -First 1
  if (-not $exe) { throw 'zip 內找不到 rclone.exe' }
  Copy-Item -LiteralPath $exe.FullName -Destination $RcloneExe -Force
  Write-Host "OK: $RcloneExe"
} else {
  Write-Host "已有: $RcloneExe"
}

& $RcloneExe version

$remotes = & $RcloneExe listremotes 2>$null
$has = $false
foreach ($r in @($remotes)) { if ($r.Trim() -eq ($RemoteName + ':')) { $has = $true } }
if (-not $has) {
  Write-Host ''
  Write-Host '=== 請設定 Google Photos remote ==='
  Write-Host "選 n → name 填: $RemoteName"
  Write-Host 'Storage 選: Google Photos → 瀏覽器登入'
  Write-Host ''
  & $RcloneExe config
}

$remotes = & $RcloneExe listremotes 2>$null
$has = $false
foreach ($r in @($remotes)) { if ($r.Trim() -eq ($RemoteName + ':')) { $has = $true } }
if (-not $has) { throw "找不到 remote ${RemoteName}: ，請重跑並完成 config" }

$allDst = Join-Path $DestRoot '全部媒體'
$albDst = Join-Path $DestRoot '相簿'
New-Item -ItemType Directory -Force -Path $allDst, $albDst | Out-Null

Write-Host "下載全部媒體 -> $allDst"
& $RcloneExe copy ($RemoteName + ':media/all') $allDst --progress --transfers 4 --checkers 8 --retries 3
Write-Host "下載相簿 -> $albDst"
& $RcloneExe copy ($RemoteName + ':album') $albDst --progress --transfers 4 --checkers 8 --retries 3
Write-Host "完成: $DestRoot"
Get-ChildItem -LiteralPath $DestRoot | Format-Table Name, Mode, LastWriteTime
