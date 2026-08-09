#Requires -Version 5.1
<#
.SYNOPSIS
  在 E:\ 建立第一層「超級生命密碼」，並將相關資料夾／檔案移入。

.DESCRIPTION
  - 涵蓋：超級生命密碼、天圓文化、弟子規、身心靈修行相關。
  - 來源：E:\ 根層、私人、公司、文件／影音／圖片／桌面／下載歸檔（有限深度）。
  - 略過：備份整樹、私人骨架目錄本身、已在目的地底下。
  - 只搬移不刪；目的資料夾已存在則合併；檔名衝突進 _搬移衝突。
  - 預設 DryRun；加上 -Execute 才真正 Move-Item。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$TargetRoot = 'E:\超級生命密碼',
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

$subs = @(
  '超級生命密碼', '天圓文化', '弟子規', '身心靈修行',
  '_搬移衝突', '_搬移日誌'
)
foreach ($s in $subs) { Ensure-Dir (Join-Path $TargetRoot $s) }

# 先匹配先生效
$rules = @(
  @{ Re = '超級生命密碼|生命密碼'; Dest = '超級生命密碼' },
  @{ Re = '天圓|鳴馨|文化事業|太陽盛德'; Dest = '天圓文化' },
  @{ Re = '弟子規'; Dest = '弟子規' },
  @{ Re = '身心靈|修行|滋養研究|人生成長實作'; Dest = '身心靈修行' }
)

# 不整包搬走的私人骨架／工具名
$skipNameRe = '^(財務|家庭|證件合約|掃描檔|車禍事故|密碼與金鑰|醫療健康|公司|備份|工具軟體|桌面歸檔|下載歸檔|文件歸檔|圖片歸檔|影音歸檔|_搬移衝突|_搬移日誌|_搬移|System Volume Information|\$RECYCLE\.BIN)$'

function Resolve-DestSub([string]$name) {
  foreach ($r in $rules) {
    if ($name -match $r.Re) { return $r.Dest }
  }
  return $null
}

# 路徑邊界比對，避免「超級生命密碼課程.pptx」被誤判已在目標內
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
  $normRoot = $root.TrimEnd('\')
  if ($full.Length -le $normRoot.Length) { return 0 }
  $rel = $full.Substring($normRoot.Length).TrimStart('\')
  if ([string]::IsNullOrEmpty($rel)) { return 0 }
  return ($rel -split '[\\/]').Count
}

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到磁碟根目錄: $DriveRoot（請在本機 Windows、外接碟已插入時執行）"
}
Ensure-Dir $TargetRoot

$candidates = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

function Add-Candidate([string]$source, [string]$destDir, [string]$reason, [bool]$isDir) {
  if (Test-UnderPath $source $TargetRoot) { return }
  if (-not $seen.Add($source)) { return }
  $candidates.Add([pscustomobject]@{
    Source  = $source
    DestDir = $destDir
    Reason  = $reason
    IsDir   = $isDir
  })
}

function Register-Hit([System.IO.FileSystemInfo]$item, [string]$hitName, [string]$reasonPrefix) {
  $destSub = Resolve-DestSub $item.Name
  if ($null -eq $destSub) { $destSub = Resolve-DestSub $hitName }
  if ($null -eq $destSub) { $destSub = '' }

  if ($destSub -and $item.PSIsContainer -and ($item.Name -eq $destSub)) {
    $destDir = $TargetRoot
  } elseif ($destSub) {
    $destDir = Join-Path $TargetRoot $destSub
  } else {
    $destDir = $TargetRoot
  }
  Add-Candidate $item.FullName $destDir ("$reasonPrefix->$hitName") $item.PSIsContainer
}

function Scan-Tree([string]$root, [int]$minDepth, [int]$maxDepth, [string]$reasonPrefix) {
  if (-not (Test-Path -LiteralPath $root)) { return }

  Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if (Test-UnderPath $_.FullName $TargetRoot) { return }

    $depth = Get-DepthRelative $_.FullName $root
    if ($depth -lt $minDepth -or $depth -gt $maxDepth) { return }
    if ($_.Name -match $skipNameRe) { return }

    $rootNorm = $root.TrimEnd('\', '/')
    if ($_.FullName.TrimEnd('\', '/').Equals($rootNorm, [StringComparison]::OrdinalIgnoreCase)) { return }

    $parts = @($_.Name)
    if ($_.FullName.Length -gt $rootNorm.Length) {
      $relPath = $_.FullName.Substring($rootNorm.Length).TrimStart('\', '/')
      if (-not [string]::IsNullOrEmpty($relPath)) { $parts = $relPath -split '[\\/]' }
    }

    $hitName = $null
    foreach ($p in $parts) {
      if ($p -match $skipNameRe) { continue }
      if ($null -ne (Resolve-DestSub $p)) { $hitName = $p; break }
    }
    if ($null -eq $hitName) { return }

    $idx = [array]::IndexOf($parts, $hitName)
    if ($idx -lt 0) { return }
    $topRel = ($parts[0..$idx] -join '\')
    $topFull = Join-Path $root $topRel
    if (-not (Test-Path -LiteralPath $topFull)) { return }

    $topItem = Get-Item -LiteralPath $topFull -Force
    if ($topItem.Name -match $skipNameRe) { return }
    if (Test-UnderPath $topItem.FullName $TargetRoot) { return }

    Register-Hit $topItem $hitName $reasonPrefix
  }
}

# 1) E:\ 第一層直接項目
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if (Test-UnderPath $_.FullName $TargetRoot) { return }
  if ($_.Name -match $skipNameRe) { return }
  if ($_.Name -eq '超級生命密碼') { return }
  $destSub = Resolve-DestSub $_.Name
  if ($null -eq $destSub) { return }
  Register-Hit $_ $_.Name 'E-root'
}

# 2) 常見歸檔樹（有限深度）
$scanRoots = @(
  (Join-Path $DriveRoot '私人'),
  (Join-Path $DriveRoot '公司'),
  (Join-Path $DriveRoot '文件歸檔'),
  (Join-Path $DriveRoot '影音歸檔'),
  (Join-Path $DriveRoot '圖片歸檔'),
  (Join-Path $DriveRoot '桌面歸檔'),
  (Join-Path $DriveRoot '下載歸檔')
)
foreach ($r in $scanRoots) {
  $label = Split-Path -Leaf $r
  Scan-Tree $r 1 3 $label
}

$logDir = Join-Path $TargetRoot '_搬移日誌'
Ensure-Dir $logDir
$logPath = Join-Path $logDir ("move-super-life_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$log = New-Object System.Collections.Generic.List[string]
$log.Add(("mode={0} drive={1} target={2}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRYRUN' }), $DriveRoot, $TargetRoot)))
$log.Add(("candidates={0}" -f $candidates.Count))

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的搬）' })))
Write-Host ("Target: {0}" -f $TargetRoot)
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
            $conflictDir = Join-Path $TargetRoot '_搬移衝突'
            Ensure-Dir $conflictDir
            $alt = Join-Path $conflictDir ($_.Name + '_fromE_' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
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
      $conflictDir = Join-Path $TargetRoot '_搬移衝突'
      Ensure-Dir $conflictDir
      $dest = Join-Path $conflictDir ($name + '_fromE_' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
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
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1 -Execute"
}
