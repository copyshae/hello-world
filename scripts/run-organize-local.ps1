#Requires -Version 5.1
<#
.SYNOPSIS
  本機一鍵：找到 hello-world → pull → checkout → 預覽 → 確認後整理 E:\

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\run-organize-local.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\run-organize-local.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute,
  [switch]$SkipConfirm
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Find-HelloWorldRepo {
  $candidates = @(
    (Join-Path $env:USERPROFILE 'Desktop\hello-world'),
    (Join-Path $env:USERPROFILE 'Documents\hello-world'),
    (Join-Path $env:USERPROFILE 'hello-world'),
    'D:\hello-world',
    'C:\hello-world'
  )
  foreach ($p in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $p '.git')) { return (Resolve-Path -LiteralPath $p).Path }
  }
  $hit = Get-ChildItem -Path @($env:USERPROFILE, 'D:\', 'C:\') -Filter 'hello-world' -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } |
    Select-Object -First 1
  if ($hit) { return $hit.FullName }
  return $null
}

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot 。請確認外接碟已插入，且磁碟代號是 E:。"
}

$repo = Find-HelloWorldRepo
if (-not $repo) {
  throw @"
找不到本機 hello-world 倉庫。
請先：
  cd `$env:USERPROFILE\Desktop
  git clone https://github.com/copyshae/hello-world.git
再重跑本腳本。
"@
}

Write-Host "REPO: $repo"
Set-Location -LiteralPath $repo

Write-Host 'git fetch / checkout cursor/move-company-from-private-f39f ...'
git fetch origin cursor/move-company-from-private-f39f
if ($LASTEXITCODE -ne 0) { throw 'git fetch 失敗' }
git checkout cursor/move-company-from-private-f39f
if ($LASTEXITCODE -ne 0) { throw 'git checkout 失敗' }
git pull origin cursor/move-company-from-private-f39f
if ($LASTEXITCODE -ne 0) { throw 'git pull 失敗' }

$runner = Join-Path $repo 'scripts\organize-e-drive.ps1'
if (-not (Test-Path -LiteralPath $runner)) {
  throw "找不到 $runner"
}

Write-Host ''
Write-Host '======== Dry-run 預覽 ========'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -DriveRoot $DriveRoot
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
  throw "Dry-run 失敗 exit=$LASTEXITCODE"
}

if (-not $Execute) {
  Write-Host ''
  Write-Host '預覽結束。若 Candidates 正常，再執行：'
  Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Execute"
  exit 0
}

if (-not $SkipConfirm) {
  Write-Host ''
  $ans = Read-Host '確認要真正搬移 E:\ 嗎？輸入 Y 繼續'
  if ($ans -ne 'Y' -and $ans -ne 'y') {
    Write-Host '已取消，未搬移。'
    exit 0
  }
}

Write-Host ''
Write-Host '======== Execute 搬移 ========'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -DriveRoot $DriveRoot -Execute
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
  throw "Execute 失敗 exit=$LASTEXITCODE"
}

Write-Host ''
Write-Host '======== 完成後 E:\ 第一層 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize
Write-Host '請在檔案總管按 F5。應看到：私人、學校、超級生命密碼、公司（若有匹配）。'
