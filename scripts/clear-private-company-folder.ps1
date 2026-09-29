#Requires -Version 5.1
<#
.SYNOPSIS
  清除 E:\ 下已搬空的「私人\公司」資料夾（預設 Dry-run）。

.DESCRIPTION
  移動完成後使用。預設只刪 E:\私人\公司（空或加 -Force 連殘留一起刪）。
  不會刪 E:\公司（那是搬移目的地）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\clear-private-company-folder.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\clear-private-company-folder.ps1 -Execute
  powershell -ExecutionPolicy Bypass -File .\scripts\clear-private-company-folder.ps1 -Execute -Force
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$PrivateRoot = 'E:\私人',
  [switch]$Execute,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$shell = Join-Path $PrivateRoot '公司'
Write-Host ("Target: {0}" -f $shell)
Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))

if (-not (Test-Path -LiteralPath $shell)) {
  Write-Host '沒有 E:\私人\公司，無需清除。'
  exit 0
}

$items = @(Get-ChildItem -LiteralPath $shell -Force -ErrorAction SilentlyContinue)
Write-Host ("目前內含: {0} 項" -f $items.Count)
$items | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host

if (-not $Execute) {
  Write-Host '確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\clear-private-company-folder.ps1 -Execute'
  if ($items.Count -gt 0) {
    Write-Host '若要連殘留一併刪：加上 -Force'
  }
  exit 0
}

if ($items.Count -gt 0 -and -not $Force) {
  throw "E:\私人\公司 尚有 $($items.Count) 項。先確認已搬完，或加 -Force 強制刪除。"
}

Remove-Item -LiteralPath $shell -Recurse -Force
Write-Host "已清除: $shell"
Write-Host '請在檔案總管按 F5。'
