#Requires -Version 5.1
<#
.SYNOPSIS
  將 _搬移衝突 內檔名的 fromE / fromPrivate 等英文及其後文字刪去（預設 Dry-run）。

.DESCRIPTION
  例：
    報告_fromE_20260809123456789.pdf      → 報告.pdf
    掃描_fromPrivate_20260809123456789.pdf → 掃描.pdf
  - 範圍：E:\ 底下名為 _搬移衝突 / 搬移衝突 的目錄樹
  - 已符合目標名則略過；改名衝突時加 _2、_3
  - 預設 Dry-run；加 -Execute 才 Rename-Item

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$conflictNames = @('_搬移衝突', '搬移衝突')
$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN|FOUND\.\d+)$'

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

function Get-CleanBase([string]$baseName) {
  $s = $baseName
  # 優先：_fromE_… / _fromPrivate_… / -fromE…
  if ($s -match '(?i)[_-]from') {
    $s = $s -replace '(?i)[_-]from[A-Za-z0-9].*$', ''
  } elseif ($s -match '(?i)from[A-Za-z]') {
    $s = $s -replace '(?i)from[A-Za-z][A-Za-z0-9_].*$', ''
  } else {
    return $null
  }
  $s = $s.TrimEnd('_', '-', ' ', '.')
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  return $s
}

function Get-UniqueName([string]$dir, [string]$fileName) {
  $dest = Join-Path $dir $fileName
  if (-not (Test-Path -LiteralPath $dest)) { return $fileName }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $ext = [System.IO.Path]::GetExtension($fileName)
  for ($i = 2; $i -le 999; $i++) {
    $candidate = '{0}_{1}{2}' -f $base, $i, $ext
    if (-not (Test-Path -LiteralPath (Join-Path $dir $candidate))) { return $candidate }
  }
  throw "無法產生唯一檔名: $fileName"
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的改名）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)

$roots = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object {
    -not (Test-UnderSkipped $_.FullName) -and ($conflictNames -contains $_.Name)
  } | Select-Object -ExpandProperty FullName)

Write-Host ("找到搬移衝突根目錄: {0}" -f $roots.Count)
foreach ($r in $roots) { Write-Host "  ROOT $r" }

if ($roots.Count -eq 0) {
  Write-Host '沒有找到搬移衝突資料夾。'
  exit 0
}

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($root in $roots) {
  Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $clean = Get-CleanBase $_.BaseName
    if ($null -eq $clean) { return }
    $newName = $clean + $_.Extension
    if ($newName -eq $_.Name) { return }
    $unique = Get-UniqueName $_.DirectoryName $newName
    $candidates.Add([pscustomobject]@{
      Source  = $_.FullName
      Dir     = $_.DirectoryName
      Old     = $_.Name
      New     = $unique
    }) | Out-Null
  }
}

Write-Host ("Candidates: {0}" -f $candidates.Count)
$renamed = 0
$err = 0
foreach ($c in $candidates) {
  Write-Host ("[RENAME] {0} -> {1}" -f $c.Old, $c.New)
  Write-Host ("         {0}" -f $c.Source)
  if (-not $Execute) { continue }
  try {
    Rename-Item -LiteralPath $c.Source -NewName $c.New -Force
    $renamed++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ""
if ($Execute) {
  Write-Host "done renamed=$renamed err=$err"
} else {
  Write-Host 'Dry-run 結束。確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute'
}
