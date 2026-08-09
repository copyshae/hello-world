#Requires -Version 5.1
<#
.SYNOPSIS
  恢復 E:\私人：若第一層沒有「私人」，搜尋後搬回／重建。

.DESCRIPTION
  1) 若 E:\ 已有「私人」→ 結束
  2) 若别处有名為「私人」的資料夾 → 搬回 E:\私人
  3) 若沒有，但根層或他處有財務／家庭／備份／影音歸檔等骨架 → 新建 E:\私人 並移入
  4) 都沒有 → 只建立空的 E:\私人

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) { throw "找不到 $DriveRoot" }

$privateRoot = Join-Path $DriveRoot '私人'
$skeleton = @('財務','家庭','證件合約','掃描檔','備份','影音歸檔','文件歸檔','桌面歸檔','下載歸檔','圖片歸檔','工具軟體','從學校移入')

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host '======== E:\ 第一層 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  ForEach-Object { Write-Host ("  {0}" -f $_.Name) }

if (Test-Path -LiteralPath $privateRoot) {
  Write-Host ("已存在: {0}" -f $privateRoot)
  exit 0
}

Write-Host 'E:\ 沒有「私人」，搜尋中…'
$named = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq '私人' -and $_.FullName -ne $privateRoot })

if ($named.Count -gt 0) {
  Write-Host ("找到 {0} 個「私人」：" -f $named.Count)
  foreach ($n in $named) { Write-Host ("  {0}" -f $n.FullName) }
  $src = $named[0].FullName
  Write-Host ("將搬回: {0} -> {1}" -f $src, $privateRoot)
  if ($Execute) {
    Move-Item -LiteralPath $src -Destination $privateRoot -Force
    Write-Host '完成：E:\私人 已恢復。'
  } else {
    Write-Host 'Dry-run。確認後加 -Execute'
  }
  exit 0
}

Write-Host '沒有名為「私人」的資料夾。改蒐集骨架目錄…'
$toMove = New-Object System.Collections.Generic.List[object]
foreach ($name in $skeleton) {
  # 先看 E:\ 根層
  $atRoot = Join-Path $DriveRoot $name
  if (Test-Path -LiteralPath $atRoot) {
    $toMove.Add((Get-Item -LiteralPath $atRoot -Force)) | Out-Null
    continue
  }
  $hit = Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq $name } | Select-Object -First 1
  if ($null -ne $hit) { $toMove.Add($hit) | Out-Null }
}

Write-Host ("找到可收回骨架: {0}" -f $toMove.Count)
foreach ($t in $toMove) { Write-Host ("  {0}" -f $t.FullName) }

Write-Host ("將建立: {0}" -f $privateRoot)
if (-not $Execute) {
  Write-Host 'Dry-run。確認後：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute'
  exit 0
}

New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
$moved = 0
foreach ($t in $toMove) {
  if (-not (Test-Path -LiteralPath $t.FullName)) { continue }
  if ($t.FullName.StartsWith($privateRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
  $dest = Join-Path $privateRoot $t.Name
  if (Test-Path -LiteralPath $dest) {
    Write-Host ("SKIP 已存在: {0}" -f $dest)
    continue
  }
  Write-Host ("[MOVE] {0} -> {1}" -f $t.FullName, $dest)
  Move-Item -LiteralPath $t.FullName -Destination $dest -Force
  $moved++
}
Write-Host "done created E:\私人 moved=$moved"
