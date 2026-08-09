#Requires -Version 5.1
<#
.SYNOPSIS
  一鍵整理 E:\：超級生命密碼 → 學校 → 公司（預設 Dry-run）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot 。請確認外接碟已插入，且磁碟代號是 E:。"
}

Write-Host "======== E:\ 目前第一層 ========"
Get-ChildItem -LiteralPath $DriveRoot -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host

$private = Join-Path $DriveRoot '私人'
if (Test-Path -LiteralPath $private) {
  Write-Host "======== E:\私人 目前第一層 ========"
  Get-ChildItem -LiteralPath $private -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host
} else {
  Write-Host "警告：沒有 E:\私人"
}

function Invoke-Step([string]$scriptName, [string[]]$scriptArgs) {
  $scriptPath = Join-Path $here $scriptName
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "找不到腳本: $scriptPath （請先 git pull 並 checkout 正確分支）"
  }
  $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $scriptArgs
  if ($Execute) { $allArgs += '-Execute' }
  Write-Host ("RUN: powershell {0}" -f ($allArgs -join ' '))
  & powershell.exe @allArgs
  if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    throw "腳本失敗: $scriptName exit=$LASTEXITCODE"
  }
}

Write-Host ""
Write-Host "======== 1/3 超級生命密碼 ========"
Invoke-Step 'move-super-life-code.ps1' @(
  '-DriveRoot', $DriveRoot,
  '-TargetRoot', (Join-Path $DriveRoot '超級生命密碼')
)

Write-Host ""
Write-Host "======== 2/3 學校 ========"
Invoke-Step 'move-school-from-private.ps1' @(
  '-DriveRoot', $DriveRoot,
  '-PrivateRoot', (Join-Path $DriveRoot '私人'),
  '-SchoolRoot', (Join-Path $DriveRoot '學校')
)

Write-Host ""
Write-Host "======== 3/3 公司 ========"
Invoke-Step 'move-company-from-private.ps1' @(
  '-PrivateRoot', (Join-Path $DriveRoot '私人'),
  '-CompanyRoot', (Join-Path $DriveRoot '公司')
)

Write-Host ""
Write-Host "======== 完成後 E:\ 第一層 ========"
Get-ChildItem -LiteralPath $DriveRoot -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host

if (-not $Execute) {
  Write-Host "以上是 Dry-run。若 Candidates 有項目且路徑正確，再執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1 -Execute"
} else {
  Write-Host "已執行搬移。請在檔案總管按 F5 重新整理 E:\ 。"
  Write-Host "應看到：私人、學校、超級生命密碼、公司（若有匹配項目）。"
}
