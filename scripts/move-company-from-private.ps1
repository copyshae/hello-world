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
# 天圓／弟子規／身心靈／超級生命密碼改由 move-super-life-code.ps1 → E:\超級生命密碼
$companySubs = @(
  '公文合約', '財務報銷', '掃描檔', '_搬移衝突', '_搬移日誌'
)
foreach ($s in $companySubs) { Ensure-Dir (Join-Path $CompanyRoot $s) }

# 名稱關鍵字 → 目的子目錄（先匹配先生效）；未命中子規則但命中「公司」則放根層
$rules = @(
  @{ Re = '公文|合約|契約|勞保|健保投保|離職|到職|人事'; Dest = '公文合約' },
  @{ Re = '報銷|請款|發票|收據|薪資條|扣繳'; Dest = '財務報銷' },
  @{ Re = '掃描|scan'; Dest = '掃描檔' },
  @{ Re = '公司|上班|職場|辦公'; Dest = '' }
)

# 私人分類骨架與工具目錄：不整包當「公司」搬走
$privateSkeletonRe = '^(財務|家庭|證件合約|掃描檔|車禍事故|密碼與金鑰|醫療健康|_搬移衝突|_搬移日誌|_搬移)'

# 修行／天圓類留給 E:\超級生命密碼；學校類留給 E:\學校
$superLifeSkipRe = '超級生命密碼|生命密碼|天圓|鳴馨|文化事業|太陽盛德|弟子規|身心靈|修行|滋養研究'
$schoolSkipRe = '^(school|\d{3}學年school)$|學年school|\d{3}學年|衛生組|健促|健康促進|科展|科學營|試題|教案|公開課|請假|打掃|掃地|教室分佈|學校|班級|教室|彰安|配課|課表|班親'

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
  if ($name -match $superLifeSkipRe) { return $true }
  if ($name -match $schoolSkipRe) { return $true }
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
    if ($_.Name -match $superLifeSkipRe) { return }
    if ($_.Name -match $schoolSkipRe) { return }
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
  # 搬完內容後，清除「私人\公司」空殼（刪除，不留在 E:\）
  Add-Candidate $nestedCompany $CompanyRoot 'remove-shell-private\公司' $true
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
  # 來源資料夾名已與分類同名時，直接放到 E:\公司，避免 公文合約\公文合約
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

$removedShells = 0

foreach ($c in $candidates) {
  $name = Split-Path -Leaf $c.Source

  # 私人\公司 空殼：搬完後直接刪除
  if ($c.Reason -eq 'remove-shell-private\公司') {
    $line = "[REMOVE] {0} ({1})" -f $c.Source, $c.Reason
    Write-Host $line
    $log.Add($line)
    if (-not $Execute) { continue }
    try {
      if (Test-Path -LiteralPath $c.Source) {
        Remove-Item -LiteralPath $c.Source -Recurse -Force
        $removedShells++
        $log.Add("REMOVED $($c.Source)")
        Write-Host "已清除: $($c.Source)"
      }
    } catch {
      $skipped++
      $log.Add("ERR-REMOVE $($c.Source) :: $($_.Exception.Message)")
      Write-Warning $_.Exception.Message
    }
    continue
  }

  $dest = Join-Path $c.DestDir $name
  $line = "[{0}] {1} -> {2} ({3})" -f $(if ($c.IsDir) { 'DIR' } else { 'FILE' }), $c.Source, $dest, $c.Reason
  Write-Host $line
  $log.Add($line)

  if (-not $Execute) { continue }

  try {
    Ensure-Dir $c.DestDir
    if (Test-Path -LiteralPath $dest) {
      $destItem = Get-Item -LiteralPath $dest -Force
      # 目的已是資料夾（含預建骨架）：合併內容，避免同名骨架假衝突
      if ($c.IsDir -and $destItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $c.Source -Force | ForEach-Object {
          $childDest = Join-Path $dest $_.Name
          if (Test-Path -LiteralPath $childDest) {
            $conflictDir = Join-Path $CompanyRoot '_搬移衝突'
            Ensure-Dir $conflictDir
            $alt = Join-Path $conflictDir ($_.Name + '_fromPrivate_' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
            Move-Item -LiteralPath $_.FullName -Destination $alt -Force
            $conflicted++
            $log.Add("MERGE-CONFLICT $($_.FullName) -> $alt")
          } else {
            Move-Item -LiteralPath $_.FullName -Destination $childDest -Force
            $log.Add("MERGE $($_.FullName) -> $childDest")
          }
        }
        # 合併後來源空殼直接刪除
        if (Test-Path -LiteralPath $c.Source) {
          $left = @(Get-ChildItem -LiteralPath $c.Source -Force -ErrorAction SilentlyContinue)
          if ($left.Count -eq 0) {
            Remove-Item -LiteralPath $c.Source -Force
            $removedShells++
            $log.Add("REMOVED-EMPTY-SOURCE $($c.Source)")
          } else {
            Remove-Item -LiteralPath $c.Source -Recurse -Force
            $removedShells++
            $log.Add("REMOVED-SOURCE-RECURSE $($c.Source)")
          }
        }
        $moved++
        continue
      }
      $conflictDir = Join-Path $CompanyRoot '_搬移衝突'
      Ensure-Dir $conflictDir
      $dest = Join-Path $conflictDir ($name + '_fromPrivate_' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
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

# 搬移結束後再清一次：若 E:\私人\公司 仍在且無內容則刪
function Clear-PrivateCompanyShell {
  $shell = Join-Path $PrivateRoot '公司'
  if (-not (Test-Path -LiteralPath $shell)) { return }
  $left = @(Get-ChildItem -LiteralPath $shell -Force -ErrorAction SilentlyContinue)
  $line = "post-clear private\公司 leftover={0}" -f $left.Count
  Write-Host $line
  $log.Add($line)
  if (-not $Execute) { return }
  if ($left.Count -eq 0) {
    Remove-Item -LiteralPath $shell -Force
    $script:removedShells++
    $log.Add("REMOVED $shell")
    Write-Host "已清除: $shell"
  } else {
    Write-Warning "E:\私人\公司 尚有 $($left.Count) 項，未強制刪除。請檢查後再清。"
  }
}
Clear-PrivateCompanyShell

if ($Execute) {
  Ensure-Dir $logDir
  $log.Add("done moved=$moved conflicted=$conflicted err=$skipped removedShells=$removedShells")
  $log | Set-Content -LiteralPath $logPath -Encoding UTF8
  Write-Host ""
  Write-Host "moved=$moved conflicted=$conflicted err=$skipped removedShells=$removedShells"
  Write-Host "log=$logPath"
} else {
  Write-Host ""
  Write-Host "Dry-run 結束。確認列表無誤後執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-company-from-private.ps1 -Execute"
  Write-Host "Execute 後會清除已搬空的 E:\私人\公司。"
}
