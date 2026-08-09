#Requires -Version 5.1
<#
.SYNOPSIS
  一鍵整理 E:\：超級生命密碼 → 學校 → 公司 → 公司併入學校 → 清空白搬移資料夾（預設 Dry-run）。

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
  $code = $LASTEXITCODE
  # Windows PowerShell 有時會留下前一個原生命令的 exit code；只有明確非 0 才中止
  if ($null -ne $code -and $code -ne 0) {
    Write-Warning ("腳本結束碼非 0: {0} exit={1}（若後面步驟仍繼續可忽略）" -f $scriptName, $code)
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
Write-Host "======== 3/4 公司（私人→E:\公司） ========"
Invoke-Step 'move-company-from-private.ps1' @(
  '-PrivateRoot', (Join-Path $DriveRoot '私人'),
  '-CompanyRoot', (Join-Path $DriveRoot '公司')
)

Write-Host ""
Write-Host "======== 4/5 E:\公司 → 併入學校並清空 ========"
Invoke-Step 'move-clear-e-company.ps1' @(
  '-DriveRoot', $DriveRoot,
  '-CompanyRoot', (Join-Path $DriveRoot '公司'),
  '-SchoolRoot', (Join-Path $DriveRoot '學校')
)

Write-Host ""
Write-Host "======== 5/5 清除搬移日誌／衝突內空白資料夾 ========"
Invoke-Step 'clear-empty-move-folders.ps1' @(
  '-DriveRoot', $DriveRoot
)

Write-Host ""
Write-Host "======== 完成後 E:\ 第一層 ========"
Get-ChildItem -LiteralPath $DriveRoot -Force | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host

if (-not $Execute) {
  Write-Host "以上是 Dry-run。若 Candidates 有項目且路徑正確，再執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\organize-e-drive.ps1 -Execute"
} else {
  Write-Host "已執行搬移。請在檔案總管按 F5 重新整理 E:\ 。"
  Write-Host "應看到：私人、學校、超級生命密碼（不應再有「公司」；公司內容已併入學校）。"
}
