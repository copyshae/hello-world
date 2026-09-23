#Requires -Version 5.1
<#
.SYNOPSIS
  清除 E:\ 底下「_搬移日誌」「_搬移衝突」內的空白資料夾（預設 Dry-run）。

.DESCRIPTION
  - 搜尋範圍：E:\ 全碟名為 _搬移日誌 / _搬移衝突 的目錄樹
  - 只刪「完全空白」的資料夾（無檔案、無子資料夾；由深到淺）
  - 不刪 _搬移日誌 / _搬移衝突 根目錄本身（即使空也不刪）
  - 預設 Dry-run；加 -Execute 才 Remove-Item

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\clear-empty-move-folders.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\clear-empty-move-folders.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot 。請在本機 Windows、外接碟已插入時執行。"
}

$targetNames = @('_搬移日誌', '_搬移衝突', '搬移日誌', '搬移衝突')
$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN|FOUND\.\d+)$'

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的刪）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)

$roots = New-Object System.Collections.Generic.List[string]
Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if (Test-UnderSkipped $_.FullName) { return }
  if ($targetNames -contains $_.Name) {
    $roots.Add($_.FullName) | Out-Null
  }
}

Write-Host ("找到目標根目錄: {0}" -f $roots.Count)
foreach ($r in $roots) { Write-Host "  ROOT $r" }

if ($roots.Count -eq 0) {
  Write-Host '沒有找到 _搬移日誌 / _搬移衝突。'
  exit 0
}

# 收集各根底下所有子資料夾，深度由深到淺刪
$emptyDirs = New-Object System.Collections.Generic.List[string]
foreach ($root in $roots) {
  $dirs = @(Get-ChildItem -LiteralPath $root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Sort-Object { $_.FullName.Length } -Descending)
  foreach ($d in $dirs) {
    # 不刪根本身
    if ($d.FullName.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $kids = @(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue)
    if ($kids.Count -eq 0) {
      $emptyDirs.Add($d.FullName) | Out-Null
    }
  }
}

# 多輪：刪子層後父層可能變空
$removed = 0
$pass = 0
$maxPass = 20
$pending = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($e in $emptyDirs) { [void]$pending.Add($e) }

Write-Host ("初步空白資料夾: {0}" -f $pending.Count)

do {
  $pass++
  $removedThisPass = 0
  $list = @($pending) | Sort-Object { $_.Length } -Descending
  foreach ($path in $list) {
    if (-not (Test-Path -LiteralPath $path)) {
      [void]$pending.Remove($path)
      continue
    }
    # 仍須落在某個 _搬移* 根底下，且不是根本身
    $under = $false
    foreach ($root in $roots) {
      if ($path.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { $under = $false; break }
      $prefix = $root.TrimEnd('\') + '\'
      if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $under = $true; break }
    }
    if (-not $under) {
      [void]$pending.Remove($path)
      continue
    }
    $kids = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)
    if ($kids.Count -gt 0) {
      [void]$pending.Remove($path)
      continue
    }
    Write-Host ("[REMOVE-EMPTY] {0}" -f $path)
    if ($Execute) {
      try {
        Remove-Item -LiteralPath $path -Force
        $removed++
        $removedThisPass++
        [void]$pending.Remove($path)
        # 父目錄若變空且仍在 _搬移* 下，下一輪再收
        $parent = Split-Path -Parent $path
        foreach ($root in $roots) {
          if ($parent.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { break }
          $prefix = $root.TrimEnd('\') + '\'
          if ($parent.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $pk = @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction SilentlyContinue)
            if ($pk.Count -eq 0) { [void]$pending.Add($parent) }
            break
          }
        }
      } catch {
        Write-Warning $_.Exception.Message
        [void]$pending.Remove($path)
      }
    } else {
      [void]$pending.Remove($path)
      $removedThisPass++
    }
  }
} while ($Execute -and $removedThisPass -gt 0 -and $pass -lt $maxPass)

Write-Host ""
if ($Execute) {
  Write-Host "done removedEmptyDirs=$removed passes=$pass"
} else {
  Write-Host ("Dry-run 結束，將清除約 {0} 個空白資料夾（實際以 -Execute 為準）。" -f $removedThisPass)
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\clear-empty-move-folders.ps1 -Execute'
}
