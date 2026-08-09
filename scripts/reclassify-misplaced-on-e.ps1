#Requires -Version 5.1
<#
.SYNOPSIS
  從 _搬移衝突／_搬移日誌／備份等處，依關鍵字把檔案／資料夾重新分類到
  E:\超級生命密碼、E:\學校、E:\私人（預設 Dry-run）。

.DESCRIPTION
  用途：整理後「感覺不見了」——多數在衝突區或備份深處。
  不刪檔；目的同名則合併或進 _搬移衝突。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\reclassify-misplaced-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\reclassify-misplaced-on-e.ps1 -Execute
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

$superRoot = Join-Path $DriveRoot '超級生命密碼'
$schoolRoot = Join-Path $DriveRoot '學校'
$privateRoot = Join-Path $DriveRoot '私人'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    if ($Execute) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Write-Host "MKDIR $p"
  }
}

function Test-UnderPath([string]$full, [string]$root) {
  if ([string]::IsNullOrWhiteSpace($full) -or [string]::IsNullOrWhiteSpace($root)) { return $false }
  $r = $root.TrimEnd('\')
  if ($full.Equals($r, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  return $full.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Get-UniqueDest([string]$dir, [string]$name) {
  $dest = Join-Path $dir $name
  if (-not (Test-Path -LiteralPath $dest)) { return $dest }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
  $ext = [System.IO.Path]::GetExtension($name)
  for ($i = 2; $i -le 999; $i++) {
    $c = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $c)) { return $c }
  }
  throw "無法唯一命名: $name"
}

# 先清檔名上的 fromE 殘段，再判斷分類
function Get-LogicalName([string]$name) {
  if ($name -match '(?i)^(.*)([_-]from[A-Za-z]+[_-]?\d+)(\.[A-Za-z0-9]{1,16})?$') {
    return ($Matches[1] + $(if ($Matches[3]) { $Matches[3] } else { '' })).TrimEnd('_', '-')
  }
  if ($name -match '(?i)[_-]from') {
    return ($name -replace '(?i)[_-]from[A-Za-z0-9].*$', '').TrimEnd('_', '-')
  }
  return $name
}

function Resolve-Bucket([string]$name) {
  $n = Get-LogicalName $name
  if ($n -match '超級生命密碼|生命密碼') {
    return @{ Root = $superRoot; Sub = '超級生命密碼' }
  }
  if ($n -match '天圓|鳴馨|文化事業|太陽盛德') {
    return @{ Root = $superRoot; Sub = '天圓文化' }
  }
  if ($n -match '弟子規') {
    return @{ Root = $superRoot; Sub = '弟子規' }
  }
  if ($n -match '身心靈|修行|滋養研究|人生成長實作') {
    return @{ Root = $superRoot; Sub = '身心靈修行' }
  }
  if ($n -match '學年|試題|教案|衛生|健促|科展|請假|打掃|掃地|教室|班級|學校|彰安|配課|課表') {
    return @{ Root = $schoolRoot; Sub = '其他學校' }
  }
  if ($n -match '公文|合約|報銷|請款|掃描|公司|上班') {
    return @{ Root = $privateRoot; Sub = '掃描檔' }
  }
  return $null
}

Ensure-Dir $superRoot
foreach ($s in @('超級生命密碼', '天圓文化', '弟子規', '身心靈修行', '_搬移衝突', '_搬移日誌')) {
  Ensure-Dir (Join-Path $superRoot $s)
}
Ensure-Dir $schoolRoot
foreach ($s in @('學年資料', '衛生健促', '科展科學營', '試題教案', '請假', '打掃區域', '其他學校', '_搬移衝突', '_搬移日誌')) {
  Ensure-Dir (Join-Path $schoolRoot $s)
}
Ensure-Dir (Join-Path $privateRoot '掃描檔')

# 來源：衝突區、日誌區空殼旁的檔、以及私人\備份裡已命中關鍵字者
$sourceRoots = New-Object System.Collections.Generic.List[string]
Get-ChildItem -LiteralPath $DriveRoot -Recurse -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @('_搬移衝突', '搬移衝突', '_搬移日誌', '搬移日誌') } |
  ForEach-Object { $sourceRoots.Add($_.FullName) | Out-Null }

$backup = Join-Path $privateRoot '備份'
if (Test-Path -LiteralPath $backup) { $sourceRoots.Add($backup) | Out-Null }

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("掃描來源根: {0}" -f $sourceRoots.Count)

$candidates = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($root in $sourceRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  $isBackup = Test-UnderPath $root $backup

  Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.FullName)) { return }
    if ($_.Name -match '^(_搬移衝突|_搬移日誌|搬移衝突|搬移日誌)$') { return }
    if ($_.Name -match '^move-.*\.txt$') { return }
    if ($_.Name -match '^_已合併_|^_已清空_') { return }

    # 備份：只收關鍵字命中；衝突／日誌區：全部嘗試分類，分不出就進學校\其他學校（衝突區）或略過（日誌）
    $bucket = Resolve-Bucket $_.Name
    $inConflict = ($root -match '搬移衝突')
    $inLog = ($root -match '搬移日誌')

    if ($isBackup) {
      if ($null -eq $bucket) { return }
    } elseif ($inConflict) {
      if ($null -eq $bucket) {
        $bucket = @{ Root = $schoolRoot; Sub = '其他學校' }
      }
    } elseif ($inLog) {
      if ($null -eq $bucket) { return }
    } else {
      if ($null -eq $bucket) { return }
    }

    # 已在正確目的樹內則略過
    $destRoot = $bucket.Root
    if (Test-UnderPath $_.FullName $destRoot) {
      # 若已在正確大類下，不再動
      if (-not $inConflict -and -not $inLog -and -not $isBackup) { return }
      if (-not $inConflict -and -not $inLog) { return }
    }

    # 只搬「命中名稱那一層」：對備份用關鍵字資料夾／檔；對衝突用該項目本身
    $item = $_
    if ($isBackup) {
      # 若路徑更深，盡量抬到關鍵字那層資料夾
      $rel = $_.FullName.Substring($root.Length).TrimStart('\')
      $parts = $rel -split '[\\/]'
      $hit = $null
      foreach ($p in $parts) {
        if ($null -ne (Resolve-Bucket $p)) { $hit = $p; break }
      }
      if ($null -ne $hit) {
        $idx = [array]::IndexOf($parts, $hit)
        $topRel = ($parts[0..$idx] -join '\')
        $topFull = Join-Path $root $topRel
        if (Test-Path -LiteralPath $topFull) {
          $item = Get-Item -LiteralPath $topFull -Force
          $bucket = Resolve-Bucket $item.Name
          if ($null -eq $bucket) { return }
        }
      }
    }

    if (-not $seen.Add($item.FullName)) { return }
    if (Test-UnderPath $item.FullName $destRoot -and -not $inConflict) { return }

    $destDir = Join-Path $bucket.Root $bucket.Sub
    # 資料夾名已等於分類名 → 併入該分類根
    $logical = Get-LogicalName $item.Name
    if ($item.PSIsContainer -and ($logical -eq $bucket.Sub)) {
      $destDir = $bucket.Root
    }

    $candidates.Add([pscustomobject]@{
      Source  = $item.FullName
      DestDir = $destDir
      Name    = $logical
      IsDir   = [bool]$item.PSIsContainer
      Reason  = ("{0}->{1}\{2}" -f $root, $bucket.Root, $bucket.Sub)
    }) | Out-Null
  }
}

Write-Host ("Candidates: {0}" -f $candidates.Count)
$moved = 0
$err = 0
foreach ($c in $candidates) {
  Ensure-Dir $c.DestDir
  $dest = Join-Path $c.DestDir $c.Name
  Write-Host ("[{0}] {1}" -f ($(if ($c.IsDir) { 'DIR' } else { 'FILE' }), $c.Source))
  Write-Host ("     -> {0}  ({1})" -f $dest, $c.Reason)
  if (-not $Execute) { continue }
  try {
    if (-not (Test-Path -LiteralPath $c.Source)) { continue }

    if ($c.IsDir) {
      if (Test-Path -LiteralPath $dest) {
        Get-ChildItem -LiteralPath $c.Source -Force -ErrorAction SilentlyContinue | ForEach-Object {
          $childDest = Get-UniqueDest $dest $_.Name
          Move-Item -LiteralPath $_.FullName -Destination $childDest -Force
        }
        Remove-Item -LiteralPath $c.Source -Recurse -Force -ErrorAction SilentlyContinue
      } else {
        Move-Item -LiteralPath $c.Source -Destination $dest -Force
      }
    } else {
      if (Test-Path -LiteralPath $dest) {
        $dest = Get-UniqueDest $c.DestDir $c.Name
      }
      Move-Item -LiteralPath $c.Source -Destination $dest -Force
    }
    $moved++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
if ($Execute) {
  Write-Host "done moved=$moved err=$err"
  Write-Host '建議接著跑 inventory-e-drive.ps1 看各區檔案數。'
} else {
  Write-Host 'Dry-run 結束。確認後：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\reclassify-misplaced-on-e.ps1 -Execute'
}
