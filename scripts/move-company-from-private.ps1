#Requires -Version 5.1
<#
.SYNOPSIS
  從 E:\私人 找出公司類資料夾／檔案，搬到上層 E:\公司。

.DESCRIPTION
  - 只搬移，不刪檔；同名衝突改放 E:\公司\_搬移衝突。
  - 預設 DryRun；加上 -Execute 才真正 Move-Item。
  - 會處理：
    1) E:\私人\公司（整包或內容）→ E:\公司
    2) 私人底下各層名稱符合公司關鍵字的項目 → E:\公司（或對應子目錄）
  - 略過私人分類骨架本身（財務／家庭／證件合約等）與 _搬移* 目錄。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$PrivateRoot = 'E:\私人',
  [string]$CompanyRoot = 'E:\公司',
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

# 公司目錄骨架（可增設）
$companySubs = @(
  '天圓文化', '公文合約', '財務報銷', '掃描檔', '_搬移衝突', '_搬移日誌'
)
foreach ($s in $companySubs) { Ensure-Dir (Join-Path $CompanyRoot $s) }

# 名稱關鍵字 → 目的子目錄（先匹配先生效）；未命中子規則但命中「公司」則放根層
$rules = @(
  @{ Re = '天圓|文化事業|太陽盛德'; Dest = '天圓文化' },
  @{ Re = '公文|合約|契約|勞保|健保投保|離職|到職|人事'; Dest = '公文合約' },
  @{ Re = '報銷|請款|發票|收據|薪資條|扣繳'; Dest = '財務報銷' },
  @{ Re = '掃描|scan'; Dest = '掃描檔' },
  @{ Re = '公司|上班|職場|辦公'; Dest = '' }
)

# 私人分類骨架與工具目錄：不整包當「公司」搬走
$privateSkeletonRe = '^(財務|家庭|證件合約|掃描檔|車禍事故|密碼與金鑰|醫療健康|_搬移衝突|_搬移日誌|_搬移)'

function Resolve-CompanyDest([string]$name) {
  foreach ($r in $rules) {
    if ($name -match $r.Re) { return $r.Dest }
  }
  return $null
}

function Should-Skip([System.IO.FileSystemInfo]$item) {
  if ($item.FullName.StartsWith($CompanyRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $name = $item.Name
  if ($name -match $privateSkeletonRe) { return $true }
  return $false
}

if (-not (Test-Path -LiteralPath $PrivateRoot)) {
  throw "找不到私人根目錄: $PrivateRoot（請在本機 Windows、外接碟已插入時執行）"
}
Ensure-Dir $CompanyRoot

$candidates = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

function Add-Candidate([string]$source, [string]$destDir, [string]$reason, [bool]$isDir) {
  if (-not $seen.Add($source)) { return }
  $candidates.Add([pscustomobject]@{
    Source  = $source
    DestDir = $destDir
    Reason  = $reason
    IsDir   = $isDir
  })
}

# 1) 私人根下直接名為「公司」的資料夾：把其「內容」搬到 E:\公司（避免多一層私人\公司）
$nestedCompany = Join-Path $PrivateRoot '公司'
if (Test-Path -LiteralPath $nestedCompany) {
  Get-ChildItem -LiteralPath $nestedCompany -Force | ForEach-Object {
    $sub = Resolve-CompanyDest $_.Name
    if ($null -eq $sub) { $sub = '' }
    if ($sub -and $_.PSIsContainer -and ($_.Name -eq $sub)) {
      $destDir = $CompanyRoot
    } elseif ($sub) {
      $destDir = Join-Path $CompanyRoot $sub
    } else {
      $destDir = $CompanyRoot
    }
    Add-Candidate $_.FullName $destDir 'private\公司\to-company' $_.PSIsContainer
  }
  # 搬完內容後，空的「私人\公司」也排程移走（改名放日誌區，不刪）
  Add-Candidate $nestedCompany (Join-Path $CompanyRoot '_搬移日誌') 'empty-shell-private\公司' $true
}

# 2) 掃私人底下（深度有限）：名稱命中公司關鍵字的項目
#    深度 1～3，避免整包掃爆；已略過私人骨架目錄名稱
$maxDepth = 3
function Get-DepthRelative([string]$full, [string]$root) {
  $rel = $full.Substring($root.Length).TrimStart('\')
  if ([string]::IsNullOrEmpty($rel)) { return 0 }
  return ($rel -split '[\\/]').Count
}

Get-ChildItem -LiteralPath $PrivateRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  $depth = Get-DepthRelative $_.FullName $PrivateRoot
  if ($depth -lt 1 -or $depth -gt $maxDepth) { return }
  if ($_.FullName.StartsWith($nestedCompany, [StringComparison]::OrdinalIgnoreCase)) { return }
  if (Should-Skip $_) { return }

  # 路徑任一節含公司關鍵字，或檔名本身命中
  $rel = $_.FullName.Substring($PrivateRoot.Length).TrimStart('\')
  $parts = $rel -split '[\\/]'
  $hitName = $null
  foreach ($p in $parts) {
    if ($p -match $privateSkeletonRe) { continue }
    $d = Resolve-CompanyDest $p
    if ($null -ne $d) { $hitName = $p; break }
  }
  if ($null -eq $hitName) { return }

  # 只搬「命中那一層」的頂層項目，避免同一樹重複搬子項
  # 例如 私人\家庭\天圓文化\x → 搬 家庭\天圓文化 整包
  $idx = [array]::IndexOf($parts, $hitName)
  if ($idx -lt 0) { return }
  $topRel = ($parts[0..$idx] -join '\')
  $topFull = Join-Path $PrivateRoot $topRel
  if (-not (Test-Path -LiteralPath $topFull)) { return }

  $topItem = Get-Item -LiteralPath $topFull -Force
  if (Should-Skip $topItem) { return }

  $destSub = Resolve-CompanyDest $topItem.Name
  if ($null -eq $destSub) { $destSub = '' }
  # 若檔名本身未命中、只靠路徑中間節點命中，用該節點的分類
  if ($destSub -eq '') {
    $mid = Resolve-CompanyDest $hitName
    if ($null -ne $mid) { $destSub = $mid }
  }
  # 來源資料夾名已與分類同名時，直接放到 E:\公司，避免 天圓文化\天圓文化
  if ($destSub -and $topItem.PSIsContainer -and ($topItem.Name -eq $destSub)) {
    $destDir = $CompanyRoot
  } elseif ($destSub) {
    $destDir = Join-Path $CompanyRoot $destSub
  } else {
    $destDir = $CompanyRoot
  }
  Add-Candidate $topItem.FullName $destDir ("name->$hitName") $topItem.PSIsContainer
}

$logDir = Join-Path $CompanyRoot '_搬移日誌'
Ensure-Dir $logDir
$logPath = Join-Path $logDir ("move-company_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$log = New-Object System.Collections.Generic.List[string]
$log.Add(("mode={0} private={1} company={2}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRYRUN' }), $PrivateRoot, $CompanyRoot)))
$log.Add(("candidates={0}" -f $candidates.Count))

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的搬）' })))
Write-Host ("Candidates: {0}" -f $candidates.Count)

$moved = 0
$skipped = 0
$conflicted = 0

foreach ($c in $candidates) {
  $name = Split-Path -Leaf $c.Source
  # 私人\公司 空殼：改名標記後放日誌區，避免與真資料混淆
  if ($c.Reason -eq 'empty-shell-private\公司') {
    $name = '_已清空_原私人公司資料夾'
  }
  $dest = Join-Path $c.DestDir $name
  $line = "[{0}] {1} -> {2} ({3})" -f $(if ($c.IsDir) { 'DIR' } else { 'FILE' }), $c.Source, $dest, $c.Reason
  Write-Host $line
  $log.Add($line)

  if (-not $Execute) { continue }

  try {
    Ensure-Dir $c.DestDir
    if (Test-Path -LiteralPath $dest) {
      $conflictDir = Join-Path $CompanyRoot '_搬移衝突'
      Ensure-Dir $conflictDir
      $dest = Join-Path $conflictDir ($name + '_fromPrivate_' + (Get-Date -Format 'yyyyMMddHHmmss'))
      $conflicted++
      $log.Add("CONFLICT -> $dest")
    }
    # 若是空殼且裡面可能還有殘件，仍整包 Move
    Move-Item -LiteralPath $c.Source -Destination $dest -Force
    $moved++
  } catch {
    $skipped++
    $log.Add("ERR $($c.Source) :: $($_.Exception.Message)")
    Write-Warning $_.Exception.Message
  }
}

if ($Execute) {
  Ensure-Dir $logDir
  $log.Add("done moved=$moved conflicted=$conflicted err=$skipped")
  $log | Set-Content -LiteralPath $logPath -Encoding UTF8
  Write-Host ""
  Write-Host "moved=$moved conflicted=$conflicted err=$skipped"
  Write-Host "log=$logPath"
} else {
  Write-Host ""
  Write-Host "Dry-run 結束。確認列表無誤後執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1 -Execute"
}
