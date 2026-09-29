#Requires -Version 5.1
<#
.SYNOPSIS
  在整個 E:\ 搜尋「弟子規／弟子歸」第 1～41 集相關的文字檔與 MP4（含備份、衝突區）。

.DESCRIPTION
  會列出命中路徑，並可選擇搬到 E:\超級生命密碼\弟子規。
  預設只搜尋；加 -Execute 才搬移（不刪原檔以外的東西，只 Move）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$DestRoot = 'E:\超級生命密碼\弟子規',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN)$'
$extOk = @('.txt', '.text', '.md', '.doc', '.docx', '.pdf', '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.mp3', '.wav', '.m4a')

# 弟子規／弟子歸 + 集數樣式
$nameRe = '弟子規|弟子歸|弟子规'
$epRe = '第\s*([0-9]{1,2})\s*集|第([0-9]{1,2})講|([0-9]{1,2})\s*集|ep\s*([0-9]{1,2})|EP\s*([0-9]{1,2})|集數\s*([0-9]{1,2})'

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

function Test-EpisodeName([string]$name) {
  if ($name -notmatch $nameRe -and $name -notmatch '弟子') {
    # 資料夾叫弟子規時，底下檔名可能只有「第12集.mp4」
    if ($name -notmatch $epRe) { return $false }
  }
  # 有弟子關鍵字，或有集數
  if ($name -match $nameRe) { return $true }
  if ($name -match $epRe) {
    $n = $null
    foreach ($g in 1..6) {
      if ($Matches[$g]) { $n = [int]$Matches[$g]; break }
    }
    if ($null -ne $n -and $n -ge 1 -and $n -le 41) { return $true }
  }
  return $false
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

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE=搬到 ' + $DestRoot } else { 'SEARCH-ONLY（加 -Execute 才搬）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)

# 報告
$reportDir = Join-Path $DriveRoot '_清點報告'
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir ("dizigui_find_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$hits = New-Object System.Collections.Generic.List[object]
$folderHits = New-Object System.Collections.Generic.List[string]

Write-Host '正在掃描 E:\（可能需要幾分鐘）...'

Get-ChildItem -LiteralPath $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.FullName)) { return }
  if (Test-UnderSkipped $_.FullName) { return }

  if ($_.PSIsContainer) {
    if ($_.Name -match $nameRe) {
      $folderHits.Add($_.FullName) | Out-Null
    }
    return
  }

  $ext = $_.Extension.ToLowerInvariant()
  # 副檔名被改壞：.mp4_fromE_… / .txt_fromE_…
  $logicalExt = $ext
  if ($ext -match '(?i)^(\.[a-z0-9]{1,8})_') { $logicalExt = $Matches[1].ToLowerInvariant() }
  $nameForMatch = $_.Name
  if ($nameForMatch -match '(?i)([_-]from[A-Za-z]+|[_-]衝突)') {
    # 仍用原名比對關鍵字
  }

  $extOkHit = ($extOk -contains $logicalExt) -or ($extOk -contains $ext) -or ($_.Name -match '(?i)\.(mp4|txt|mp3|docx?)([_-]|$)')
  if (-not $extOkHit) {
    # 若在弟子規資料夾下，放寬：只要像集數檔
    $underDizi = ($_.FullName -match $nameRe)
    if (-not $underDizi) { return }
  }

  $underDiziPath = ($_.DirectoryName -match $nameRe) -or ($_.FullName -match $nameRe)
  $nameHit = Test-EpisodeName $_.Name
  if (-not $nameHit -and -not $underDiziPath) { return }
  if (-not $nameHit -and $underDiziPath) {
    # 在弟子規資料夾內的影音／文字都收
    if (-not $extOkHit) { return }
  }

  $hits.Add([pscustomobject]@{
    FullName = $_.FullName
    Name     = $_.Name
    LengthMB = [math]::Round($_.Length / 1MB, 2)
    Ext      = $logicalExt
    Dir      = $_.DirectoryName
  }) | Out-Null
}

Write-Host ''
Write-Host ("命中資料夾（名稱含弟子規／弟子歸）: {0}" -f $folderHits.Count)
foreach ($f in $folderHits) { Write-Host "  DIR  $f" }

Write-Host ("命中檔案: {0}" -f $hits.Count)
$mp4 = @($hits | Where-Object { $_.Ext -eq '.mp4' -or $_.Name -match '(?i)\.mp4' })
$txt = @($hits | Where-Object { $_.Ext -in @('.txt', '.text', '.md') -or $_.Name -match '(?i)\.txt' })
Write-Host ("  其中像 MP4: {0}；像文字: {1}" -f $mp4.Count, $txt.Count)

$out = New-Object System.Collections.Generic.List[string]
$out.Add(("dizigui find {0}" -f (Get-Date)))
$out.Add(("folders={0} files={1} mp4~={2} txt~={3}" -f $folderHits.Count, $hits.Count, $mp4.Count, $txt.Count))
$out.Add('--- FOLDERS ---')
foreach ($f in $folderHits) { $out.Add($f) }
$out.Add('--- FILES ---')
foreach ($h in ($hits | Sort-Object FullName)) {
  $line = "{0}`t{1} MB`t{2}" -f $h.FullName, $h.LengthMB, $h.Name
  Write-Host ("  FILE {0} ({1} MB)" -f $h.FullName, $h.LengthMB)
  $out.Add($line)
}
$out | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ''
Write-Host ("報告: {0}" -f $report)

if ($hits.Count -eq 0 -and $folderHits.Count -eq 0) {
  Write-Host ''
  Write-Host '沒找到。請再確認外接碟是否為今天整理的那顆，或到資源回收桶查看。'
  Write-Host '也可手動搜尋整個 E:\：弟子規　或　弟子歸　或　第1集'
  exit 0
}

if (-not $Execute) {
  Write-Host ''
  Write-Host '以上只是搜尋。若要全部搬到 E:\超級生命密碼\弟子規：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1 -Execute'
  exit 0
}

# Execute：優先搬整個弟子規資料夾；其餘散檔再搬
if (-not (Test-Path -LiteralPath $DestRoot)) {
  New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
}

$moved = 0
$err = 0
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($dir in $folderHits) {
  if (-not (Test-Path -LiteralPath $dir)) { continue }
  # 已在目的地底下略過
  if ($dir.StartsWith($DestRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }
  if ($dir.Equals($DestRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { continue }

  $name = Split-Path -Leaf $dir
  $dest = Get-UniqueDest $DestRoot $name
  Write-Host ("[MOVE DIR] {0} -> {1}" -f $dir, $dest)
  try {
    Move-Item -LiteralPath $dir -Destination $dest -Force
    [void]$seen.Add($dir)
    $moved++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

foreach ($h in $hits) {
  if (-not (Test-Path -LiteralPath $h.FullName)) { continue }
  # 若父層資料夾已整包搬走，檔案路徑會失效 → skip
  $already = $false
  foreach ($s in $seen) {
    if ($h.FullName.StartsWith($s.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $already = $true; break }
  }
  if ($already) { continue }
  if ($h.FullName.StartsWith($DestRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }

  $dest = Get-UniqueDest $DestRoot $h.Name
  Write-Host ("[MOVE FILE] {0} -> {1}" -f $h.FullName, $dest)
  try {
    Move-Item -LiteralPath $h.FullName -Destination $dest -Force
    $moved++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
Write-Host "done moved=$moved err=$err"
Write-Host "請打開: $DestRoot"
Write-Host '若檔名仍含 _fromE_，再跑 restore-usable-extensions-on-e.ps1 -Execute'
