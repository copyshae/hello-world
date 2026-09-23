#Requires -Version 5.1
<#
.SYNOPSIS
  確認今日 E:\ 搬移記錄的檔案是否還在，並檢查是否仍有不可用的壞檔名。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\verify-today-moves-on-e.ps1
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$DatePrefix = (Get-Date -Format 'yyyyMMdd')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$reportDir = Join-Path $DriveRoot '_清點報告'
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $reportDir ("verify_today_{0}.txt" -f $stamp)
$missingPath = Join-Path $reportDir ("verify_missing_{0}.txt" -f $stamp)
$brokenPath = Join-Path $reportDir ("verify_broken_names_{0}.txt" -f $stamp)

$lines = New-Object System.Collections.Generic.List[string]
function L([string]$s) { Write-Host $s; $lines.Add($s) | Out-Null }

L ("======== 今日搬移驗證 {0} ========" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
L ("DriveRoot: {0}" -f $DriveRoot)
L ("DatePrefix: {0}" -f $DatePrefix)
L ''

# --- 1) 讀今日搬移日誌 ---
$logDirs = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @('_搬移日誌', '搬移日誌') })

$logFiles = New-Object System.Collections.Generic.List[string]
foreach ($d in $logDirs) {
  Get-ChildItem -LiteralPath $d.FullName -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -match '^move-' -and (
        $_.Name -match $DatePrefix -or
        $_.LastWriteTime.ToString('yyyyMMdd') -eq $DatePrefix -or
        $_.LastWriteTime.Date -eq (Get-Date).Date
      )
    } |
    ForEach-Object { $logFiles.Add($_.FullName) | Out-Null }
}

L ("找到今日搬移日誌: {0}" -f $logFiles.Count)
foreach ($f in $logFiles) { L ("  LOG {0}" -f $f) }
L ''

$destExpected = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$pairCount = 0

foreach ($logPath in $logFiles) {
  $content = Get-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($null -eq $content) { $content = Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue }
  foreach ($line in $content) {
    $dst = $null
    if ($line -match '^\[(DIR|FILE)\]\s+(.+?)\s+->\s+(.+?)(\s+\(.*\))?\s*$') {
      $dst = $Matches[3].Trim()
    } elseif ($line -match '^MERGE\s+(.+?)\s+->\s+(.+)\s*$') {
      $dst = $Matches[2].Trim()
    } elseif ($line -match '^MERGE-CONFLICT\s+(.+?)\s+->\s+(.+)\s*$') {
      $dst = $Matches[2].Trim()
    } elseif ($line -match '^CONFLICT\s+->\s+(.+)\s*$') {
      $dst = $Matches[1].Trim()
    }
    if ($null -ne $dst -and -not [string]::IsNullOrWhiteSpace($dst)) {
      [void]$destExpected.Add($dst)
      $pairCount++
    }
  }
}

L ("日誌記錄的目的路徑（去重後）: {0}（原始列約 {1}）" -f $destExpected.Count, $pairCount)

$missing = New-Object System.Collections.Generic.List[string]
$present = 0
foreach ($p in ($destExpected | Sort-Object)) {
  if (Test-Path -LiteralPath $p) {
    $present++
  } else {
    # 目的不在：可能又被二次搬移。試著用檔名在 E:\ 搜尋一次（較慢，只對 missing 做）
    $missing.Add($p) | Out-Null
  }
}

L ("目的仍存在: {0}" -f $present)
L ("目的目前找不到: {0}" -f $missing.Count)

# 對 missing 做檔名索引補搜（只掃一次 E:\）
$relocated = 0
$reallyMissing = New-Object System.Collections.Generic.List[string]
if ($missing.Count -gt 0) {
  L '正在建立 E:\ 檔名索引以便補搜換位項目（可能需幾分鐘）...'
  $nameIndex = @{}
  Get-ChildItem -LiteralPath $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.Name)) { return }
    $key = $_.Name.ToLowerInvariant()
    if (-not $nameIndex.ContainsKey($key)) {
      $nameIndex[$key] = $_.FullName
    }
  }
  L ("索引完成，條目約: {0}" -f $nameIndex.Count)

  foreach ($m in $missing) {
    $leaf = Split-Path -Leaf $m
    if ([string]::IsNullOrWhiteSpace($leaf)) {
      $reallyMissing.Add($m) | Out-Null
      continue
    }
    $logical = $leaf -replace '(?i)([_-](?:from[A-Za-z]+|衝突)[_-]?\d+.*)$', ''
    if ([string]::IsNullOrWhiteSpace($logical)) { $logical = $leaf }

    $hit = $null
    foreach ($cand in @($leaf, $logical)) {
      $k = $cand.ToLowerInvariant()
      if ($nameIndex.ContainsKey($k)) { $hit = $nameIndex[$k]; break }
    }
    if ($null -ne $hit) {
      $relocated++
      if ($relocated -le 30) {
        L ("  RELOCATED 原預期: {0}" -f $m)
        L ("             現在在: {0}" -f $hit)
      }
    } else {
      $reallyMissing.Add($m) | Out-Null
    }
  }
  if ($relocated -gt 30) { L ("  ... 另有 {0} 筆換位略不列印" -f ($relocated - 30)) }
}

L ("補搜後：已換位置仍找得到: {0}" -f $relocated)
L ("仍完全找不到: {0}" -f $reallyMissing.Count)
L ''

# --- 2) 壞檔名掃描 ---
L '======== 壞檔名檢查（fromE / fromPrivate / 衝突尾巴 / 怪副檔名）========'
$broken = New-Object System.Collections.Generic.List[string]
Get-ChildItem -LiteralPath $DriveRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_) { return }
  $n = $_.Name
  $ext = $_.Extension
  $bad = $false
  if ($n -match '(?i)[_-]from[A-Za-z]') { $bad = $true }
  elseif ($n -match '(?i)[_-]衝突[_-]?\d') { $bad = $true }
  elseif ($ext -match '(?i)[_-]from') { $bad = $true }
  elseif ($ext -match '(?i)^\.[A-Za-z0-9]{1,16}_') { $bad = $true }
  if ($bad) { $broken.Add($_.FullName) | Out-Null }
}

L ("仍含壞檔名的檔案: {0}" -f $broken.Count)
if ($broken.Count -gt 0) {
  L '（前 40 筆）'
  foreach ($b in ($broken | Select-Object -First 40)) { L ("  BAD {0}" -f $b) }
  if ($broken.Count -gt 40) { L ("  ... 另有 {0} 筆見報告" -f ($broken.Count - 40)) }
}
L ''

# --- 3) 第一層容量摘要 ---
L '======== E:\ 第一層摘要 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notin @('System Volume Information', '$RECYCLE.BIN', 'FOUND.000') } |
  ForEach-Object {
    if ($_.PSIsContainer) {
      $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
      $bytes = ($files | Measure-Object Length -Sum).Sum
      if ($null -eq $bytes) { $bytes = 0 }
      L ("[DIR] {0,-20} files={1,7} size={2} GB" -f $_.Name, $files.Count, [math]::Round($bytes / 1GB, 2))
    } else {
      L ("[FILE] {0}" -f $_.Name)
    }
  }

L ''
L '======== 結論 ========'
if ($logFiles.Count -eq 0) {
  L '沒有今日搬移日誌，無法逐筆核對搬移結果；請看第一層摘要與壞檔名數量。'
} else {
  $okRate = 0
  if ($destExpected.Count -gt 0) {
    $okRate = [math]::Round(100.0 * ($present + $relocated) / $destExpected.Count, 1)
  }
  L ("日誌目的可追蹤率約: {0}% （存在 {1} + 換位 {2}）／預期 {3}" -f $okRate, $present, $relocated, $destExpected.Count)
  if ($reallyMissing.Count -eq 0) {
    L '就日誌而言：沒有「完全找不到」的目的路徑。'
  } else {
    L ("仍有 {0} 筆日誌目的目前找不到（可能曾還原、再搬、或日誌含空殼路徑）。" -f $reallyMissing.Count)
  }
}

if ($broken.Count -eq 0) {
  L '壞檔名：未發現 fromE／衝突尾巴等不可用檔名。'
} else {
  L ("壞檔名：仍有 {0} 個，建議再跑：" -f $broken.Count)
  L '  powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute'
  L '  powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute'
}

$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
$reallyMissing | Set-Content -LiteralPath $missingPath -Encoding UTF8
$broken | Set-Content -LiteralPath $brokenPath -Encoding UTF8

L ''
L ("完整報告: {0}" -f $reportPath)
L ("找不到清單: {0}" -f $missingPath)
L ("壞檔名清單: {0}" -f $brokenPath)
