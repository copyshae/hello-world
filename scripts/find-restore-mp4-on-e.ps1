#Requires -Version 5.1
<#
.SYNOPSIS
  檢視 E:\ 全部 MP4（含被改壞檔名／隱藏在衝突區、備份者），並可修復副檔名、取消隱藏、彙整到影音歸檔。

.DESCRIPTION
  1) 全碟找出 .mp4 與「.mp4_fromE_…」「…_fromE_….mp4」等壞名
  2) 修復成可用 .mp4
  3) 取消 Hidden
  4) 可選：把「_搬移衝突／_搬移日誌」裡的 MP4 搬到 E:\私人\影音歸檔\_找回的MP4
     （若無私人\影音歸檔則用 E:\影音歸檔\_找回的MP4 或 E:\_找回的MP4）

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute
  powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute -GatherFromConflict
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute,
  [switch]$GatherFromConflict
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN)$'

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

function Test-IsMp4Name([string]$name) {
  if ($name -match '(?i)\.mp4([_-]|$)') { return $true }
  if ($name -match '(?i)\.mp4_') { return $true }
  if ($name -match '(?i)_from[A-Za-z]+.*\.mp4$') { return $true }
  return $false
}

function Repair-Mp4Name([string]$name) {
  # a.mp4_fromE_123 / a.mp4_衝突_123
  if ($name -match '(?i)^(.+?)(\.mp4)([_-](?:from[A-Za-z]+|衝突).+)$') {
    return $Matches[1] + $Matches[2]
  }
  # a_fromE_123.mp4
  if ($name -match '(?i)^(.+?)([_-](?:from[A-Za-z]+|衝突)[_-]?\d+)(\.mp4)$') {
    return $Matches[1] + $Matches[3]
  }
  # Windows Extension = .mp4_fromE_123
  $ext = [IO.Path]::GetExtension($name)
  $base = [IO.Path]::GetFileNameWithoutExtension($name)
  if ($ext -match '(?i)^(\.mp4)([_-].+)$') {
    return $base + $Matches[1]
  }
  return $null
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

function Get-GatherRoot {
  $candidates = @(
    (Join-Path (Join-Path $DriveRoot '私人') '影音歸檔'),
    (Join-Path $DriveRoot '影音歸檔'),
    $DriveRoot
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
      return (Join-Path $c '_找回的MP4')
    }
  }
  return (Join-Path $DriveRoot '_找回的MP4')
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("GatherFromConflict: {0}" -f [bool]$GatherFromConflict)
Write-Host '正在掃描 E:\ 所有 MP4…'

$reportDir = Join-Path $DriveRoot '_清點報告'
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir ("mp4_find_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$all = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $DriveRoot -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.FullName)) { return }
  if (Test-UnderSkipped $_.FullName) { return }
  if (-not (Test-IsMp4Name $_.Name)) { return }

  $broken = $null -ne (Repair-Mp4Name $_.Name)
  $hidden = ($_.Attributes -band [IO.FileAttributes]::Hidden) -ne 0
  $inConflict = ($_.FullName -match '搬移衝突|搬移日誌')
  $all.Add([pscustomobject]@{
    FullName   = $_.FullName
    Name       = $_.Name
    LengthMB   = [math]::Round($_.Length / 1MB, 2)
    BrokenName = $broken
    Hidden     = $hidden
    InConflict = $inConflict
    Dir        = $_.DirectoryName
  }) | Out-Null
}

$brokenList = @($all | Where-Object BrokenName)
$hiddenList = @($all | Where-Object Hidden)
$conflictList = @($all | Where-Object InConflict)
$totalMB = ($all | Measure-Object -Property LengthMB -Sum).Sum
if ($null -eq $totalMB) { $totalMB = 0 }

Write-Host ("找到 MP4（含壞名）: {0} 個，約 {1} MB" -f $all.Count, [math]::Round($totalMB, 1))
Write-Host ("  檔名需修復: {0}" -f $brokenList.Count)
Write-Host ("  目前隱藏: {0}" -f $hiddenList.Count)
Write-Host ("  在衝突／日誌區: {0}" -f $conflictList.Count)

# 依資料夾統計
Write-Host ''
Write-Host '--- 各區數量（路徑前兩層）---'
$all | ForEach-Object {
  $rel = $_.FullName.Substring($DriveRoot.TrimEnd('\').Length).TrimStart('\')
  $parts = $rel -split '[\\/]'
  if ($parts.Count -ge 2) { '{0}\{1}' -f $parts[0], $parts[1] } else { $parts[0] }
} | Group-Object | Sort-Object Count -Descending | Select-Object -First 30 | ForEach-Object {
  Write-Host ("  {0,5}  {1}" -f $_.Count, $_.Name)
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add(("mp4 find {0}" -f (Get-Date)))
$out.Add(("total={0} broken={1} hidden={2} conflict={3} mb={4}" -f $all.Count, $brokenList.Count, $hiddenList.Count, $conflictList.Count, [math]::Round($totalMB, 1)))
foreach ($a in ($all | Sort-Object FullName)) {
  $out.Add(("{0}`t{1}MB`tbroken={2}`thidden={3}`tconflict={4}" -f $a.FullName, $a.LengthMB, $a.BrokenName, $a.Hidden, $a.InConflict))
}
$out | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ("報告: {0}" -f $report)

if ($all.Count -eq 0) {
  Write-Host ''
  Write-Host '整顆 E:\ 掃不到 MP4。請檢查：'
  Write-Host '  1) 是否插對硬碟'
  Write-Host '  2) 資源回收桶'
  Write-Host '  3) 是否其實在其他碟（D: / OneDrive）'
  exit 0
}

if (-not $Execute) {
  Write-Host ''
  Write-Host '預覽結束。修復檔名＋取消隱藏：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute'
  Write-Host '若要把衝突區 MP4 集中到影音歸檔\_找回的MP4：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\find-restore-mp4-on-e.ps1 -Execute -GatherFromConflict'
  exit 0
}

$repaired = 0
$unhidden = 0
$gathered = 0
$err = 0

foreach ($a in $all) {
  if (-not (Test-Path -LiteralPath $a.FullName)) { continue }
  try {
    $item = Get-Item -LiteralPath $a.FullName -Force
    $path = $item.FullName

    # 修檔名
    $newName = Repair-Mp4Name $item.Name
    if ($null -ne $newName -and $newName -ne $item.Name) {
      $unique = Split-Path -Leaf (Get-UniqueDest $item.DirectoryName $newName)
      Write-Host ("[REPAIR] {0} -> {1}" -f $item.Name, $unique)
      Rename-Item -LiteralPath $path -NewName $unique -Force
      $path = Join-Path $item.DirectoryName $unique
      $item = Get-Item -LiteralPath $path -Force
      $repaired++
    }

    # 取消隱藏
    if (($item.Attributes -band [IO.FileAttributes]::Hidden) -ne 0) {
      $item.Attributes = $item.Attributes -band (-bnot [IO.FileAttributes]::Hidden)
      $unhidden++
      Write-Host ("[UNHIDE] {0}" -f $item.FullName)
    }

    # 從衝突區彙整
    if ($GatherFromConflict -and ($item.FullName -match '搬移衝突|搬移日誌')) {
      $gatherRoot = Get-GatherRoot
      if (-not (Test-Path -LiteralPath $gatherRoot)) {
        New-Item -ItemType Directory -Path $gatherRoot -Force | Out-Null
      }
      $dest = Get-UniqueDest $gatherRoot $item.Name
      Write-Host ("[GATHER] {0} -> {1}" -f $item.FullName, $dest)
      Move-Item -LiteralPath $item.FullName -Destination $dest -Force
      $gathered++
    }
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
Write-Host "done repaired=$repaired unhidden=$unhidden gathered=$gathered err=$err totalSeen=$($all.Count)"
Write-Host '請在檔案總管對 E:\ 搜尋 *.mp4，或打開報告路徑核對。'
if ($GatherFromConflict) {
  Write-Host ("衝突區已集中到: {0}" -f (Get-GatherRoot))
}
