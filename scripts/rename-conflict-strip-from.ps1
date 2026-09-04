#Requires -Version 5.1
<#
.SYNOPSIS
  將 _搬移衝突 內「檔名／資料夾名」的 fromE / fromPrivate 等英文及其後文字刪去（預設 Dry-run）。

.DESCRIPTION
  常見兩種：
    報告_fromE_20260809123456789.pdf           → 報告.pdf
    嘉獎名單.xls_fromE_20260809160544254       → 嘉獎名單.xls
    10402_fromE_20260809160546951              → 10402
  - 範圍：E:\ 底下 _搬移衝突 / 搬移衝突
  - 檔案與資料夾都處理；由深到淺改名
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

function Get-CleanName([string]$name) {
  # 對完整名稱動手：
  #   a.xls_fromE_時間戳     → a.xls
  #   a_fromE_時間戳.pdf     → a.pdf
  #   資料夾_fromE_時間戳    → 資料夾
  if ($name -notmatch '(?i)[_-]?from') { return $null }

  $s2 = $null
  if ($name -match '(?i)^(.*)([_-]from[A-Za-z]+[_-]?\d+)(\.[A-Za-z0-9]{1,16})?$') {
    $s2 = $Matches[1] + $(if ($Matches[3]) { $Matches[3] } else { '' })
  } elseif ($name -match '(?i)[_-]from') {
    $s2 = $name -replace '(?i)[_-]from[A-Za-z0-9].*$', ''
  } else {
    $s2 = $name -replace '(?i)from[A-Za-z][A-Za-z0-9_].*$', ''
  }

  $s2 = $s2.TrimEnd('_', '-', ' ')
  if ([string]::IsNullOrWhiteSpace($s2)) { return $null }
  if ($s2 -eq $name) { return $null }
  return $s2
}

function Get-ParentDir([System.IO.FileSystemInfo]$item) {
  if (-not $item.PSIsContainer) {
    if (-not [string]::IsNullOrWhiteSpace($item.DirectoryName)) {
      return $item.DirectoryName
    }
  } else {
    if ($null -ne $item.Parent -and -not [string]::IsNullOrWhiteSpace($item.Parent.FullName)) {
      return $item.Parent.FullName
    }
  }
  $parent = Split-Path -Parent $item.FullName
  if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
  return $parent
}

function Get-UniqueName([string]$dir, [string]$fileName) {
  if ([string]::IsNullOrWhiteSpace($dir)) { throw '父目錄路徑是空的' }
  if ([string]::IsNullOrWhiteSpace($fileName)) { throw '新檔名是空的' }
  $dest = Join-Path -Path $dir -ChildPath $fileName
  if (-not (Test-Path -LiteralPath $dest)) { return $fileName }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $ext = [System.IO.Path]::GetExtension($fileName)
  if ([string]::IsNullOrWhiteSpace($base)) { $base = '未命名' }
  for ($i = 2; $i -le 999; $i++) {
    $candidate = '{0}_{1}{2}' -f $base, $i, $ext
    if (-not (Test-Path -LiteralPath (Join-Path -Path $dir -ChildPath $candidate))) { return $candidate }
  }
  throw "無法產生唯一名稱: $fileName"
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的改名）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)
Write-Host '規則: 刪去檔名後的 _fromE_時間戳 / _fromPrivate_時間戳（例：a.xls_fromE_123 → a.xls）'

$roots = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object {
    ($null -ne $_) -and
    (-not [string]::IsNullOrWhiteSpace($_.FullName)) -and
    (-not (Test-UnderSkipped $_.FullName)) -and
    ($conflictNames -contains $_.Name)
  } | ForEach-Object { $_.FullName } |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

Write-Host ("找到搬移衝突根目錄: {0}" -f $roots.Count)
foreach ($r in $roots) { Write-Host "  ROOT $r" }

if ($roots.Count -eq 0) {
  Write-Host '沒有找到搬移衝突資料夾。'
  exit 0
}

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($root in $roots) {
  if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) { continue }

  Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($null -eq $_) { return }
    if ([string]::IsNullOrWhiteSpace($_.FullName)) { return }
    if ($_.FullName.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { return }
    if ([string]::IsNullOrWhiteSpace($_.Name)) { return }

    # 用完整 Name，才能處理「.xls_fromE_時間戳」
    $newName = Get-CleanName $_.Name
    if ($null -eq $newName) { return }
    if ($newName -eq $_.Name) { return }

    $parent = Get-ParentDir $_
    if ([string]::IsNullOrWhiteSpace($parent)) {
      Write-Warning ("略過（無父路徑）: {0}" -f $_.FullName)
      return
    }

    $unique = Get-UniqueName $parent $newName
    $candidates.Add([pscustomobject]@{
      Source = $_.FullName
      Dir    = $parent
      Old    = $_.Name
      New    = $unique
      IsDir  = [bool]$_.PSIsContainer
      Depth  = $_.FullName.Length
    }) | Out-Null
  }
}

$ordered = @($candidates | Sort-Object Depth -Descending)

Write-Host ("Candidates: {0}（含資料夾與檔案）" -f $ordered.Count)
$renamed = 0
$err = 0
foreach ($c in $ordered) {
  $kind = if ($c.IsDir) { 'DIR' } else { 'FILE' }
  Write-Host ("[RENAME {0}] {1}" -f $kind, $c.Old)
  Write-Host ("          -> {0}" -f $c.New)
  if (-not $Execute) { continue }
  try {
    if (-not (Test-Path -LiteralPath $c.Source)) {
      Write-Warning ("來源已不存在（可能上層已改名）: {0}" -f $c.Source)
      continue
    }
    $parent = Split-Path -Parent $c.Source
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent)) {
      Write-Warning ("父目錄不存在: {0}" -f $parent)
      $err++
      continue
    }
    $unique = Get-UniqueName $parent $c.New
    Rename-Item -LiteralPath $c.Source -NewName $unique -Force
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
