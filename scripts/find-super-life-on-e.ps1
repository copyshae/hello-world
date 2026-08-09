#Requires -Version 5.1
<#
.SYNOPSIS
  在整個 E:\ 搜尋「超碼／超級生命密碼／天圓」相關檔案（含備份、衝突區），可搬回 E:\超級生命密碼。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$DestRoot = 'E:\超級生命密碼',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN)$'
# 超碼＝超級生命密碼簡稱
$nameRe = '超碼|超級生命密碼|生命密碼|天圓|鳴馨|太陽盛德|文化事業|身心靈|滋養研究|人生成長實作'
$mediaExt = @('.txt', '.text', '.md', '.doc', '.docx', '.pdf', '.ppt', '.pptx', '.xls', '.xlsx',
  '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.mp3', '.wav', '.m4a', '.jpg', '.jpeg', '.png', '.zip', '.rar', '.7z')

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

function Resolve-Sub([string]$name) {
  if ($name -match '天圓|鳴馨|太陽盛德|文化事業') { return '天圓文化' }
  if ($name -match '弟子規|弟子歸') { return '弟子規' }
  if ($name -match '身心靈|修行|滋養研究|人生成長實作') { return '身心靈修行' }
  return '超級生命密碼'
}

function Get-UniqueDest([string]$dir, [string]$name) {
  $dest = Join-Path $dir $name
  if (-not (Test-Path -LiteralPath $dest)) { return $dest }
  $base = [IO.Path]::GetFileNameWithoutExtension($name)
  $ext = [IO.Path]::GetExtension($name)
  for ($i = 2; $i -le 999; $i++) {
    $c = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $c)) { return $c }
  }
  throw "無法唯一命名: $name"
}

function Test-UnderPath([string]$full, [string]$root) {
  $r = $root.TrimEnd('\')
  if ($full.Equals($r, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  return $full.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE → ' + $DestRoot } else { 'SEARCH-ONLY' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)
Write-Host '關鍵字: 超碼／超級生命密碼／生命密碼／天圓…'

$reportDir = Join-Path $DriveRoot '_清點報告'
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir ("superlife_find_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$folderHits = New-Object System.Collections.Generic.List[string]
$fileHits = New-Object System.Collections.Generic.List[object]

Write-Host '正在掃描 E:\（可能需要幾分鐘）...'

Get-ChildItem -LiteralPath $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.FullName)) { return }
  if (Test-UnderSkipped $_.FullName) { return }
  # 已在目的地的正常分類下：搜尋仍列出，Execute 時不重搬
  if ($_.PSIsContainer) {
    if ($_.Name -match $nameRe) { $folderHits.Add($_.FullName) | Out-Null }
    return
  }

  $under = ($_.FullName -match $nameRe)
  $nameHit = ($_.Name -match $nameRe)
  if (-not $under -and -not $nameHit) { return }

  $ext = $_.Extension.ToLowerInvariant()
  if ($ext -match '(?i)^(\.[a-z0-9]{1,8})_') { $ext = $Matches[1].ToLowerInvariant() }
  $extOk = ($mediaExt -contains $ext) -or ($_.Name -match '(?i)\.(mp4|txt|mp3|pdf|docx?)([_-]|$)')
  if (-not $extOk -and -not $under) { return }
  if (-not $extOk -and $under -and -not $nameHit) {
    # 在超碼資料夾內：收常見媒體／文件
    if ($mediaExt -notcontains $ext -and $ext -notmatch '^\.(mp4|txt|pdf)') { return }
  }

  $fileHits.Add([pscustomobject]@{
    FullName = $_.FullName
    Name     = $_.Name
    LengthMB = [math]::Round($_.Length / 1MB, 2)
    Sub      = Resolve-Sub ($_.Name + ' ' + $_.DirectoryName)
  }) | Out-Null
}

Write-Host ("命中資料夾: {0}" -f $folderHits.Count)
foreach ($f in $folderHits) { Write-Host "  DIR  $f" }
Write-Host ("命中檔案: {0}" -f $fileHits.Count)
foreach ($h in ($fileHits | Sort-Object FullName | Select-Object -First 80)) {
  Write-Host ("  FILE {0} ({1} MB)" -f $h.FullName, $h.LengthMB)
}
if ($fileHits.Count -gt 80) { Write-Host ("  ... 其餘 {0} 筆見報告" -f ($fileHits.Count - 80)) }

$out = New-Object System.Collections.Generic.List[string]
$out.Add(("superlife find {0}" -f (Get-Date)))
$out.Add(("folders={0} files={1}" -f $folderHits.Count, $fileHits.Count))
$out.Add('--- FOLDERS ---')
foreach ($f in $folderHits) { $out.Add($f) }
$out.Add('--- FILES ---')
foreach ($h in ($fileHits | Sort-Object FullName)) {
  $out.Add(("{0}`t{1} MB`t{2}" -f $h.FullName, $h.LengthMB, $h.Sub))
}
$out | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ("報告: {0}" -f $report)

if ($folderHits.Count -eq 0 -and $fileHits.Count -eq 0) {
  Write-Host '沒找到。請確認碟片，或到資源回收桶／其他硬碟找「超碼」「生命密碼」。'
  exit 0
}

if (-not $Execute) {
  Write-Host ''
  Write-Host '確認後搬回 E:\超級生命密碼：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1 -Execute'
  exit 0
}

foreach ($s in @('超級生命密碼', '天圓文化', '弟子規', '身心靈修行')) {
  $p = Join-Path $DestRoot $s
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

$moved = 0
$err = 0
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($dir in $folderHits) {
  if (-not (Test-Path -LiteralPath $dir)) { continue }
  if (Test-UnderPath $dir $DestRoot) { continue }
  $sub = Resolve-Sub (Split-Path -Leaf $dir)
  $destDir = Join-Path $DestRoot $sub
  if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
  $leaf = Split-Path -Leaf $dir
  # 資料夾名已是分類名 → 合併進該分類
  if ($leaf -eq $sub) {
    Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | ForEach-Object {
      $d = Get-UniqueDest $destDir $_.Name
      Write-Host ("[MERGE] {0} -> {1}" -f $_.FullName, $d)
      try {
        Move-Item -LiteralPath $_.FullName -Destination $d -Force
        $script:moved++
      } catch { $script:err++; Write-Warning $_.Exception.Message }
    }
    try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    [void]$seen.Add($dir)
    continue
  }
  $dest = Get-UniqueDest $destDir $leaf
  Write-Host ("[MOVE DIR] {0} -> {1}" -f $dir, $dest)
  try {
    Move-Item -LiteralPath $dir -Destination $dest -Force
    [void]$seen.Add($dir)
    $moved++
  } catch { $err++; Write-Warning $_.Exception.Message }
}

foreach ($h in $fileHits) {
  if (-not (Test-Path -LiteralPath $h.FullName)) { continue }
  if (Test-UnderPath $h.FullName $DestRoot) { continue }
  $skip = $false
  foreach ($s in $seen) {
    if ($h.FullName.StartsWith($s.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
  }
  if ($skip) { continue }
  $destDir = Join-Path $DestRoot $h.Sub
  if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
  $dest = Get-UniqueDest $destDir $h.Name
  Write-Host ("[MOVE FILE] {0} -> {1}" -f $h.FullName, $dest)
  try {
    Move-Item -LiteralPath $h.FullName -Destination $dest -Force
    $moved++
  } catch { $err++; Write-Warning $_.Exception.Message }
}

Write-Host ''
Write-Host "done moved=$moved err=$err"
Write-Host "請打開: $DestRoot"
Write-Host '若副檔名打不開，再跑 restore-usable-extensions-on-e.ps1 -Execute'
