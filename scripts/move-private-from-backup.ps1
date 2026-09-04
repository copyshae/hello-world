#Requires -Version 5.1
<#
.SYNOPSIS
  從 E:\備份 移出私人類檔案／資料夾，整理進 E:\私人（可自行增設子目錄）。

.DESCRIPTION
  - 只搬移，不刪檔（除非目的地已有同名且內容較新，來源改放 E:\私人\_搬移衝突）。
  - 預設 DryRun；加上 -Execute 才真正 Move-Item。
  - 略過 school／學年school 等明顯公務樹（避免誤搬整包學校備份）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-private-from-backup.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-private-from-backup.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$BackupRoot = 'E:\備份',
  [string]$PrivateRoot = 'E:\私人',
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    if ($Execute) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Write-Host "MKDIR $p"
  }
}

# 私人骨架＋可增設分類
$subDirs = @(
  '財務', '家庭', '證件合約', '掃描檔',
  '車禍事故', '密碼與金鑰', '醫療健康', '_搬移衝突', '_搬移日誌'
)
foreach ($s in $subDirs) { Ensure-Dir (Join-Path $PrivateRoot $s) }

# 名稱關鍵字 → 目的子目錄（先匹配先生效）
$rules = @(
  @{ Re = 'vault|bitwarden|復原碼|ical|密碼|金鑰|token|credential'; Dest = '密碼與金鑰' },
  @{ Re = '車禍|行車影像|事故|保險理賠'; Dest = '車禍事故' },
  @{ Re = '存摺|報稅|薪資|銀行|匯款|發票|收據|收執聯|財務|帳務|所得'; Dest = '財務' },
  @{ Re = '身分|戶籍|護照|健保|證件|合約|契約|印章|駕照'; Dest = '證件合約' },
  @{ Re = '掃描|scan'; Dest = '掃描檔' },
  @{ Re = '醫療|病歷|診斷|處方|健檢(?!.*學校)|健康檢查'; Dest = '醫療健康' },
  @{ Re = '家庭|私人|個人|小孩|子女|宇涵'; Dest = '家庭' }
)

# 整包略過（公務／已分類大樹）
$skipNameRe = '^(school|\d{3}學年school|多餘檔案夾|_搬移|_merge|_delete|Sp Service|衛生組|健促|科展|科學營|打掃|請假|試題)'

function Resolve-DestSub([string]$name) {
  foreach ($r in $rules) {
    if ($name -match $r.Re) { return $r.Dest }
  }
  return $null
}

function Should-SkipItem([System.IO.FileSystemInfo]$item, [string]$backupRoot) {
  $rel = $item.FullName.Substring($backupRoot.Length).TrimStart('\')
  $parts = $rel -split '[\\/]'
  foreach ($p in $parts) {
    if ($p -match $skipNameRe) { return $true }
  }
  # 已在私人底下則略過
  if ($item.FullName.StartsWith($PrivateRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  return $false
}

if (-not (Test-Path -LiteralPath $BackupRoot)) {
  throw "找不到備份根目錄: $BackupRoot（請在本機 Windows、E: 外接碟已插入時執行）"
}
Ensure-Dir $PrivateRoot

$candidates = New-Object System.Collections.Generic.List[object]

# 1) 備份根下一層資料夾／檔案
Get-ChildItem -LiteralPath $BackupRoot -Force | ForEach-Object {
  if (Should-SkipItem $_ $BackupRoot) { return }
  $destSub = Resolve-DestSub $_.Name
  if ($destSub) {
    $candidates.Add([pscustomobject]@{
      Source = $_.FullName
      DestDir = Join-Path $PrivateRoot $destSub
      Reason = "name->$destSub"
      IsDir = $_.PSIsContainer
    })
  }
}

# 2) 另一硬碟備份：只掃「非 school 樹」的頂層項目
$other = Join-Path $BackupRoot '另一硬碟備份'
if (Test-Path -LiteralPath $other) {
  Get-ChildItem -LiteralPath $other -Force | ForEach-Object {
    if ($_.Name -match '^(school|\d{3}學年school|多餘檔案夾)$') { return }
    if (Should-SkipItem $_ $BackupRoot) { return }
    $destSub = Resolve-DestSub $_.Name
    if (-not $destSub) {
      # 名稱不明但明顯非學年資料夾：先放家庭／待整理
      if ($_.PSIsContainer -and $_.Name -notmatch '學年|衛生|健促|學校|數學|教室') {
        $destSub = '家庭'
      }
    }
    if ($destSub) {
      $candidates.Add([pscustomobject]@{
        Source = $_.FullName
        DestDir = Join-Path $PrivateRoot $destSub
        Reason = "other-backup->$destSub"
        IsDir = $_.PSIsContainer
      })
    }
  }
}

$logPath = Join-Path (Join-Path $PrivateRoot '_搬移日誌') ("move-private_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$log = New-Object System.Collections.Generic.List[string]
$log.Add(("mode={0} backup={1} private={2}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRYRUN' }), $BackupRoot, $PrivateRoot)))
$log.Add(("candidates={0}" -f $candidates.Count))

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的搬）' })))
Write-Host ("Candidates: {0}" -f $candidates.Count)

$moved = 0
$skipped = 0
$conflicted = 0

foreach ($c in $candidates) {
  $name = Split-Path -Leaf $c.Source
  $dest = Join-Path $c.DestDir $name
  $line = "[{0}] {1} -> {2} ({3})" -f $(if ($c.IsDir) { 'DIR' } else { 'FILE' }), $c.Source, $dest, $c.Reason
  Write-Host $line
  $log.Add($line)

  if (-not $Execute) { continue }

  try {
    Ensure-Dir $c.DestDir
    if (Test-Path -LiteralPath $dest) {
      $conflictDir = Join-Path $PrivateRoot '_搬移衝突'
      Ensure-Dir $conflictDir
      $dest = Join-Path $conflictDir ($name + '_fromBackup_' + (Get-Date -Format 'yyyyMMddHHmmss'))
      $conflicted++
      $log.Add("CONFLICT -> $dest")
    }
    Move-Item -LiteralPath $c.Source -Destination $dest -Force
    $moved++
  } catch {
    $skipped++
    $log.Add("ERR $($c.Source) :: $($_.Exception.Message)")
    Write-Warning $_.Exception.Message
  }
}

if ($Execute) {
  Ensure-Dir (Join-Path $PrivateRoot '_搬移日誌')
  $log.Add("done moved=$moved conflicted=$conflicted err=$skipped")
  $log | Set-Content -LiteralPath $logPath -Encoding UTF8
  Write-Host ""
  Write-Host "moved=$moved conflicted=$conflicted err=$skipped"
  Write-Host "log=$logPath"
} else {
  Write-Host ""
  Write-Host "Dry-run 結束。確認列表無誤後執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-private-from-backup.ps1 -Execute"
}
