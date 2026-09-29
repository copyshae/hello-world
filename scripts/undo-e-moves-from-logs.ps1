#Requires -Version 5.1
<#
.SYNOPSIS
  依 E:\ 底下今日「_搬移日誌」盡力把檔案搬回原路徑（預設 Dry-run）。

.DESCRIPTION
  警告：無法保證回到「今天整理前」完整狀態。
  - 只還原日誌裡有記錄的 Move／MERGE
  - 已刪除的空殼、已改名的衝突檔、日誌沒寫到的操作無法還原
  - 若 Windows「以前的版本」或完整備份存在，那才是最接近原始狀態的方式

  日誌列格式例：
    [DIR] E:\私人\...\弟子規 -> E:\超級生命密碼\弟子規\弟子規 (私人->弟子規)
    MERGE E:\a\x -> E:\b\x
    MERGE-CONFLICT E:\a\x -> E:\b\_搬移衝突\x_衝突_...

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\undo-e-moves-from-logs.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\undo-e-moves-from-logs.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$DatePrefix = (Get-Date -Format 'yyyyMMdd'),
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

Write-Host '======== 重要 ========'
Write-Host '此腳本只能依搬移日誌「盡力」反向搬回，不是磁碟快照還原。'
Write-Host '請先在檔案總管對 E:\ 右鍵 → 內容 →「以前的版本」看有無今天之前的還原點。'
Write-Host ''

function Ensure-Parent([string]$path) {
  $parent = Split-Path -Parent $path
  if ([string]::IsNullOrWhiteSpace($parent)) { return }
  if (-not (Test-Path -LiteralPath $parent)) {
    if ($Execute) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-Host "MKDIR $parent"
  }
}

function Get-UniquePath([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $path }
  $dir = Split-Path -Parent $path
  $name = Split-Path -Leaf $path
  $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
  $ext = [System.IO.Path]::GetExtension($name)
  for ($i = 2; $i -le 999; $i++) {
    $candidate = Join-Path $dir ('{0}_還原{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  throw "無法產生唯一還原路徑: $path"
}

# 找今日 move-*.txt 日誌
$logDirs = @(Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @('_搬移日誌', '搬移日誌') } |
  Select-Object -ExpandProperty FullName)

$logFiles = New-Object System.Collections.Generic.List[string]
foreach ($d in $logDirs) {
  Get-ChildItem -LiteralPath $d -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match ('^move-.*_{0}_' -f [regex]::Escape($DatePrefix)) -or $_.Name -match ('_{0}_' -f [regex]::Escape($DatePrefix)) -or $_.LastWriteTime.ToString('yyyyMMdd') -eq $DatePrefix } |
    ForEach-Object { $logFiles.Add($_.FullName) | Out-Null }
}

# 若日期過濾太嚴，放寬：今天改過的 move-*.txt
if ($logFiles.Count -eq 0) {
  foreach ($d in $logDirs) {
    Get-ChildItem -LiteralPath $d -File -Filter 'move-*.txt' -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime.Date -eq (Get-Date).Date } |
      ForEach-Object { $logFiles.Add($_.FullName) | Out-Null }
  }
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("DatePrefix: {0}" -f $DatePrefix)
Write-Host ("找到日誌: {0}" -f $logFiles.Count)
foreach ($f in $logFiles) { Write-Host "  LOG $f" }

if ($logFiles.Count -eq 0) {
  Write-Host ''
  Write-Host '找不到今日搬移日誌，無法自動反向還原。'
  Write-Host '請改試：檔案總管 → E:\ → 右鍵 → 內容 →「以前的版本」。'
  exit 1
}

$ops = New-Object System.Collections.Generic.List[object]

foreach ($logPath in $logFiles) {
  $lines = Get-Content -LiteralPath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($null -eq $lines) { $lines = Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue }
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    # [DIR|FILE] source -> dest (reason)
    if ($line -match '^\[(DIR|FILE)\]\s+(.+?)\s+->\s+(.+?)(\s+\(.*\))?\s*$') {
      $src = $Matches[2].Trim()
      $dst = $Matches[3].Trim()
      # 還原：目前應在 dst，搬回 src
      $ops.Add([pscustomobject]@{ Kind = 'MOVEBACK'; From = $dst; To = $src; Log = $logPath; Raw = $line }) | Out-Null
      continue
    }
    # MERGE old -> new  （內容已在 new，搬回 old）
    if ($line -match '^MERGE\s+(.+?)\s+->\s+(.+)\s*$') {
      $ops.Add([pscustomobject]@{ Kind = 'MOVEBACK'; From = $Matches[2].Trim(); To = $Matches[1].Trim(); Log = $logPath; Raw = $line }) | Out-Null
      continue
    }
    # MERGE-CONFLICT old -> conflictPath
    if ($line -match '^MERGE-CONFLICT\s+(.+?)\s+->\s+(.+)\s*$') {
      $ops.Add([pscustomobject]@{ Kind = 'MOVEBACK'; From = $Matches[2].Trim(); To = $Matches[1].Trim(); Log = $logPath; Raw = $line }) | Out-Null
      continue
    }
    # CONFLICT -> dest（來源不明，略過）
    # REMOVED / MERGED-SHELL：空殼或已刪，無法還原內容
  }
}

# 由深到淺搬回（較長路徑先）
$ordered = @($ops | Sort-Object { $_.From.Length } -Descending)
Write-Host ("還原操作: {0}" -f $ordered.Count)

$done = 0
$skip = 0
$err = 0
foreach ($op in $ordered) {
  Write-Host ("[{0}] {1}" -f $op.Kind, $op.Raw)
  Write-Host ("     FROM {0}" -f $op.From)
  Write-Host ("     TO   {0}" -f $op.To)

  if (-not (Test-Path -LiteralPath $op.From)) {
    Write-Host '     SKIP 來源（現況）不存在'
    $skip++
    continue
  }

  $dest = $op.To
  if (Test-Path -LiteralPath $dest) {
    $dest = Get-UniquePath $dest
    Write-Host ("     DEST 已存在，改放到: {0}" -f $dest)
  }

  if (-not $Execute) { continue }

  try {
    Ensure-Parent $dest
    Move-Item -LiteralPath $op.From -Destination $dest -Force
    $done++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
if ($Execute) {
  Write-Host "done movedBack=$done skipped=$skip err=$err"
  Write-Host '請按 F5 檢查 E:\。若結構仍不對，請用「以前的版本」或完整備份。'
} else {
  Write-Host '以上是 Dry-run。確認後：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\undo-e-moves-from-logs.ps1 -Execute'
  Write-Host ''
  Write-Host '同時請檢查有無更完整還原：'
  Write-Host '  1) 檔案總管對 E:\ 右鍵 → 內容 →「以前的版本」'
  Write-Host '  2) E:\私人\備份 是否有今天之前的完整鏡像'
}
