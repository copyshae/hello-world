#Requires -Version 5.1
<#
.SYNOPSIS
  找出「私人」資料夾或原私人骨架（財務／家庭／備份／影音歸檔等）現在在 E:\ 哪裡。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\find-private-on-e.ps1
#>
[CmdletBinding()]
param([string]$DriveRoot = 'E:\')

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) { throw "找不到 $DriveRoot" }

Write-Host '======== E:\ 第一層 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  Select-Object Mode, LastWriteTime, Name, @{n='Items';e={
    if ($_.PSIsContainer) {
      @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count
    } else { '-' }
  }} | Format-Table -AutoSize | Out-String | Write-Host

Write-Host '======== 搜尋名為「私人」的資料夾 ========'
$named = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq '私人' })
Write-Host ("找到: {0}" -f $named.Count)
foreach ($n in $named) {
  $files = @(Get-ChildItem -LiteralPath $n.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
  $bytes = ($files | Measure-Object Length -Sum).Sum
  if ($null -eq $bytes) { $bytes = 0 }
  Write-Host ("  {0}  files={1}  size={2} GB" -f $n.FullName, $files.Count, [math]::Round($bytes/1GB,2))
}

Write-Host '======== 搜尋私人骨架關鍵名（財務／家庭／備份／影音歸檔／從學校移入）========'
$keys = @('財務','家庭','證件合約','備份','影音歸檔','文件歸檔','桌面歸檔','下載歸檔','圖片歸檔','從學校移入','掃描檔')
foreach ($k in $keys) {
  $hits = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq $k } | Select-Object -First 8)
  if ($hits.Count -eq 0) {
    Write-Host ("  [{0}] 無" -f $k)
  } else {
    foreach ($h in $hits) { Write-Host ("  [{0}] {1}" -f $k, $h.FullName) }
  }
}

Write-Host ''
Write-Host '若「私人」只是被改名：把正確資料夾改回名為 私人 即可。'
Write-Host '若整包被搬進別處：把路徑貼回來，我幫你寫搬回 E:\私人 的指令。'
