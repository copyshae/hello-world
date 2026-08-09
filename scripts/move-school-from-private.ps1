#Requires -Version 5.1
<#
.SYNOPSIS
  從 E:\私人 找出學校相關資料夾／檔案，搬到上層 E:\學校。

.DESCRIPTION
  - 只搬移，不刪檔；目的資料夾已存在則合併；檔名衝突進 _搬移衝突。
  - 預設 DryRun；加上 -Execute 才真正 Move-Item。
  - 略過私人骨架、公司／超級生命密碼相關關鍵字（那些另有腳本）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$PrivateRoot = 'E:\私人',
  [string]$SchoolRoot = 'E:\學校',
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

$schoolSubs = @(
  '學年資料', '衛生健促', '科展科學營', '試題教案',
  '請假', '打掃區域', '其他學校', '_搬移衝突', '_搬移日誌'
)
foreach ($s in $schoolSubs) { Ensure-Dir (Join-Path $SchoolRoot $s) }

# 先匹配先生效
$rules = @(
  @{ Re = '^(school|\d{3}學年school)$|學年school|\d{3}學年'; Dest = '學年資料' },
  @{ Re = '衛生|健促|健康促進'; Dest = '衛生健促' },
  @{ Re = '科展|科學營'; Dest = '科展科學營' },
  @{ Re = '試題|教案|公開課|習作|評量|段考|模擬考'; Dest = '試題教案' },
  @{ Re = '請假'; Dest = '請假' },
  @{ Re = '打掃|掃地|教室分佈|清潔區'; Dest = '打掃區域' },
  @{ Re = '學校|班級|教室|導師|數學|國文|英文|自然|社會|綜合|彰安|科任|配課|課表|導師費|班親'; Dest = '其他學校' }
)

# 私人骨架不整包搬走
$privateSkeletonRe = '^(財務|家庭|證件合約|掃描檔|車禍事故|密碼與金鑰|醫療健康|公司|超級生命密碼|_搬移衝突|_搬移日誌|_搬移)$'

# 留給其他腳本
$otherScriptSkipRe = '超級生命密碼|生命密碼|天圓|鳴馨|文化事業|太陽盛德|弟子規|身心靈|修行|滋養研究|公司|上班|職場|辦公|報銷|請款'

function Resolve-SchoolDest([string]$name) {
  if ($name -match $otherScriptSkipRe) { return $null }
  foreach ($r in $rules) {
    if ($name -match $r.Re) { return $r.Dest }
  }
  return $null
}

function Test-UnderPath([string]$full, [string]$root) {
  $r = $root.TrimEnd('\', '/')
  if ([string]::IsNullOrEmpty($full) -or [string]::IsNullOrEmpty($r)) { return $false }
  if ($full.Equals($r, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $sep1 = $r + [System.IO.Path]::DirectorySeparatorChar
  $sep2 = $r + '\'
  $sep3 = $r + '/'
  return (
    $full.StartsWith($sep1, [StringComparison]::OrdinalIgnoreCase) -or
    $full.StartsWith($sep2, [StringComparison]::OrdinalIgnoreCase) -or
    $full.StartsWith($sep3, [StringComparison]::OrdinalIgnoreCase)
  )
}

function Get-DepthRelative([string]$full, [string]$root) {
  $normRoot = $root.TrimEnd('\', '/')
  if ($full.Length -le $normRoot.Length) { return 0 }
  $rel = $full.Substring($normRoot.Length).TrimStart('\', '/')
  if ([string]::IsNullOrEmpty($rel)) { return 0 }
  return ($rel -split '[\\/]').Count
}

function Should-Skip([System.IO.FileSystemInfo]$item) {
  if (Test-UnderPath $item.FullName $SchoolRoot) { return $true }
  if ($item.Name -match $privateSkeletonRe) { return $true }
  if ($item.Name -match $otherScriptSkipRe) { return $true }
  return $false
}

if (-not (Test-Path -LiteralPath $PrivateRoot)) {
  throw "找不到私人根目錄: $PrivateRoot（請在本機 Windows、外接碟已插入時執行）"
}
Ensure-Dir $SchoolRoot

$candidates = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

function Add-Candidate([string]$source, [string]$destDir, [string]$reason, [bool]$isDir) {
  if (Test-UnderPath $source $SchoolRoot) { return }
  if (-not $seen.Add($source)) { return }
  $candidates.Add([pscustomobject]@{
    Source  = $source
    DestDir = $destDir
    Reason  = $reason
    IsDir   = $isDir
  })
}

$maxDepth = 3
Get-ChildItem -LiteralPath $PrivateRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  $depth = Get-DepthRelative $_.FullName $PrivateRoot
  if ($depth -lt 1 -or $depth -gt $maxDepth) { return }
  if (Should-Skip $_) { return }

  $rootNorm = $PrivateRoot.TrimEnd('\', '/')
  $relPath = $_.FullName.Substring($rootNorm.Length).TrimStart('\', '/')
  $parts = $relPath -split '[\\/]'

  $hitName = $null
  foreach ($p in $parts) {
    if ($p -match $privateSkeletonRe) { continue }
    if ($p -match $otherScriptSkipRe) { continue }
    if ($null -ne (Resolve-SchoolDest $p)) { $hitName = $p; break }
  }
  if ($null -eq $hitName) { return }

  $idx = [array]::IndexOf($parts, $hitName)
  if ($idx -lt 0) { return }
  $topRel = ($parts[0..$idx] -join '\')
  $topFull = Join-Path $PrivateRoot $topRel
  if (-not (Test-Path -LiteralPath $topFull)) { return }

  $topItem = Get-Item -LiteralPath $topFull -Force
  if (Should-Skip $topItem) { return }

  $destSub = Resolve-SchoolDest $topItem.Name
  if ($null -eq $destSub) { $destSub = Resolve-SchoolDest $hitName }
  if ($null -eq $destSub) { return }

  if ($topItem.PSIsContainer -and ($topItem.Name -eq $destSub)) {
    $destDir = $SchoolRoot
  } else {
    $destDir = Join-Path $SchoolRoot $destSub
  }
  Add-Candidate $topItem.FullName $destDir ("name->$hitName") $topItem.PSIsContainer
}

$logDir = Join-Path $SchoolRoot '_搬移日誌'
Ensure-Dir $logDir
$logPath = Join-Path $logDir ("move-school_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$log = New-Object System.Collections.Generic.List[string]
$log.Add(("mode={0} private={1} school={2}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRYRUN' }), $PrivateRoot, $SchoolRoot)))
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
      $destItem = Get-Item -LiteralPath $dest -Force
      if ($c.IsDir -and $destItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $c.Source -Force | ForEach-Object {
          $childDest = Join-Path $dest $_.Name
          if (Test-Path -LiteralPath $childDest) {
            $conflictDir = Join-Path $SchoolRoot '_搬移衝突'
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
        $shellDest = Join-Path $logDir ('_已合併_' + $name + '_' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
        if (Test-Path -LiteralPath $c.Source) {
          Move-Item -LiteralPath $c.Source -Destination $shellDest -Force
          $log.Add("MERGED-SHELL -> $shellDest")
        }
        $moved++
        continue
      }
      $conflictDir = Join-Path $SchoolRoot '_搬移衝突'
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
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute"
}
