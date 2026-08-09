#Requires -Version 5.1
<#
.SYNOPSIS
  將學校相關資料夾／檔案整理到 E:\學校（第一層）。

.DESCRIPTION
  來源（依序）：
    1) E:\私人（深度 1～5）
    2) E:\文件歸檔\學校、E:\私人\文件歸檔\學校（內容合併進 E:\學校）
    3) E:\ 根層、文件／桌面／下載歸檔（含私人底下同名歸檔）中名稱命中學校關鍵字者
  - 只搬移，不刪檔；目的已存在則合併；檔名衝突進 _搬移衝突。
  - 預設 DryRun；加上 -Execute 才真正 Move-Item。
  - 注意：資料夾名「學校」本身要合併內容，不可當略過名稱。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
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

$rules = @(
  @{ Re = '^(school|\d{3}學年school)$|學年school|\d{3}學年'; Dest = '學年資料' },
  @{ Re = '衛生|健促|健康促進'; Dest = '衛生健促' },
  @{ Re = '科展|科學營'; Dest = '科展科學營' },
  @{ Re = '試題|教案|公開課|習作|評量|段考|模擬考'; Dest = '試題教案' },
  @{ Re = '請假'; Dest = '請假' },
  @{ Re = '打掃|掃地|教室分佈|清潔區'; Dest = '打掃區域' },
  @{ Re = '學校|班級|教室|導師|數學|國文|英文|自然|社會|綜合|彰安|科任|配課|課表|導師費|班親'; Dest = '其他學校' }
)

$privateSkeletonRe = '^(財務|家庭|證件合約|掃描檔|車禍事故|密碼與金鑰|醫療健康|公司|超級生命密碼|_搬移衝突|_搬移日誌|_搬移)$'
$otherScriptSkipRe = '超級生命密碼|生命密碼|天圓|鳴馨|文化事業|太陽盛德|弟子規|身心靈|修行|滋養研究|公司|上班|職場|辦公|報銷|請款'
# 不可把「學校」放進略過：E:\私人\文件歸檔\學校 必須能命中。目的地 E:\學校 改用 Test-UnderPath 排除。
$archiveSkipRe = '^(備份|工具軟體|私人|公司|超級生命密碼|影音歸檔|圖片歸檔|System Volume Information|\$RECYCLE\.BIN|_搬移衝突|_搬移日誌)$'

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

function Should-SkipName([string]$name) {
  if ($name -match $privateSkeletonRe) { return $true }
  if ($name -match $otherScriptSkipRe) { return $true }
  if ($name -match $archiveSkipRe) { return $true }
  return $false
}

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到磁碟: $DriveRoot（請在本機 Windows、外接碟已插入時執行）"
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

function Register-SchoolFolderContents([string]$schoolFolder, [string]$reasonPrefix) {
  if (-not (Test-Path -LiteralPath $schoolFolder)) { return }
  if (Test-UnderPath $schoolFolder $SchoolRoot) { return }
  Write-Host "Found school folder: $schoolFolder"
  Get-ChildItem -LiteralPath $schoolFolder -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -match '^(_搬移|_搬移衝突|_搬移日誌)$') { return }
    $destSub = Resolve-SchoolDest $_.Name
    if ($null -eq $destSub) { $destSub = '其他學校' }
    if ($_.PSIsContainer -and ($_.Name -eq $destSub)) {
      $destDir = $SchoolRoot
    } else {
      $destDir = Join-Path $SchoolRoot $destSub
    }
    Add-Candidate $_.FullName $destDir ("$reasonPrefix\to-school") $_.PSIsContainer
  }
  Add-Candidate $schoolFolder (Join-Path $SchoolRoot '_搬移日誌') "empty-shell-$reasonPrefix" $true
}

function Register-Hit([System.IO.FileSystemInfo]$item, [string]$hitName, [string]$reasonPrefix) {
  # 名為「學校」的資料夾：合併其內容，避免變成 E:\學校\其他學校\學校
  if ($item.PSIsContainer -and ($item.Name -eq '學校')) {
    Register-SchoolFolderContents $item.FullName $reasonPrefix
    return
  }

  $destSub = Resolve-SchoolDest $item.Name
  if ($null -eq $destSub) { $destSub = Resolve-SchoolDest $hitName }
  if ($null -eq $destSub) { $destSub = '其他學校' }

  if ($item.PSIsContainer -and ($item.Name -eq $destSub)) {
    $destDir = $SchoolRoot
  } else {
    $destDir = Join-Path $SchoolRoot $destSub
  }
  Add-Candidate $item.FullName $destDir ("$reasonPrefix->$hitName") $item.PSIsContainer
}

function Scan-Tree([string]$root, [int]$minDepth, [int]$maxDepth, [string]$reasonPrefix) {
  if (-not (Test-Path -LiteralPath $root)) {
    Write-Host "SKIP missing: $root"
    return
  }

  Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if (Test-UnderPath $_.FullName $SchoolRoot) { return }
    $depth = Get-DepthRelative $_.FullName $root
    if ($depth -lt $minDepth -or $depth -gt $maxDepth) { return }
    if (Should-SkipName $_.Name) { return }

    $rootNorm = $root.TrimEnd('\', '/')
    $relPath = $_.FullName.Substring($rootNorm.Length).TrimStart('\', '/')
    if ([string]::IsNullOrEmpty($relPath)) { return }
    $parts = $relPath -split '[\\/]'

    $hitName = $null
    foreach ($p in $parts) {
      if (Should-SkipName $p) { continue }
      if ($null -ne (Resolve-SchoolDest $p)) { $hitName = $p; break }
    }
    if ($null -eq $hitName) { return }

    $idx = [array]::IndexOf($parts, $hitName)
    if ($idx -lt 0) { return }
    $topRel = ($parts[0..$idx] -join '\')
    $topFull = Join-Path $root $topRel
    if (-not (Test-Path -LiteralPath $topFull)) { return }

    $topItem = Get-Item -LiteralPath $topFull -Force
    if (Should-SkipName $topItem.Name) { return }
    if (Test-UnderPath $topItem.FullName $SchoolRoot) { return }

    Register-Hit $topItem $hitName $reasonPrefix
  }
}

# 1) 私人（加深：文件歸檔\學校\子項 常在深度 3～4）
Scan-Tree $PrivateRoot 1 5 '私人'

# 2) 常見「…\文件歸檔\學校」整包合併
$legacySchoolPaths = @(
  (Join-Path (Join-Path $DriveRoot '文件歸檔') '學校'),
  (Join-Path (Join-Path $PrivateRoot '文件歸檔') '學校'),
  (Join-Path (Join-Path $PrivateRoot '桌面歸檔') '學校'),
  (Join-Path (Join-Path $PrivateRoot '下載歸檔') '學校')
)
foreach ($legacySchool in $legacySchoolPaths) {
  Register-SchoolFolderContents $legacySchool ($legacySchool.Substring($DriveRoot.TrimEnd('\').Length).TrimStart('\'))
}

# 3) E:\ 根層（略過目的地 E:\學校 本身）
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if (Test-UnderPath $_.FullName $SchoolRoot) { return }
  if ($_.Name -eq '學校') { return }
  if (Should-SkipName $_.Name) { return }
  $destSub = Resolve-SchoolDest $_.Name
  if ($null -eq $destSub) { return }
  Register-Hit $_ $_.Name 'E-root'
}

# 4) 其他歸檔樹（E:\ 與 E:\私人 底下）
foreach ($name in @('文件歸檔', '桌面歸檔', '下載歸檔')) {
  Scan-Tree (Join-Path $DriveRoot $name) 1 4 $name
  Scan-Tree (Join-Path $PrivateRoot $name) 1 4 ("私人\$name")
}

$logDir = Join-Path $SchoolRoot '_搬移日誌'
Ensure-Dir $logDir
$logPath = Join-Path $logDir ("move-school_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$log = New-Object System.Collections.Generic.List[string]
$log.Add(("mode={0} drive={1} school={2}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRYRUN' }), $DriveRoot, $SchoolRoot)))
$log.Add(("candidates={0}" -f $candidates.Count))

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的搬）' })))
Write-Host ("SchoolRoot: {0}" -f $SchoolRoot)
Write-Host ("Candidates: {0}" -f $candidates.Count)

if ($candidates.Count -eq 0) {
  Write-Host ""
  Write-Host "沒有找到可搬的學校項目。請在本機檢查："
  Write-Host "  Get-ChildItem E:\私人\文件歸檔 -ErrorAction SilentlyContinue"
  Write-Host "  Get-ChildItem E:\私人\文件歸檔\學校 -ErrorAction SilentlyContinue"
  Write-Host "  Get-ChildItem E:\私人 -Recurse -Depth 3 | Where-Object Name -Match '學校|試題|衛生|科展|請假|學年'"
}

$moved = 0
$skipped = 0
$conflicted = 0

foreach ($c in $candidates) {
  $name = Split-Path -Leaf $c.Source
  if ($c.Reason -like 'empty-shell-*') {
    $name = '_已清空_原學校資料夾_' + (Get-Date -Format 'yyyyMMddHHmmssfff')
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
      if ($c.IsDir -and $destItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $c.Source -Force | ForEach-Object {
          $childDest = Join-Path $dest $_.Name
          if (Test-Path -LiteralPath $childDest) {
            $conflictDir = Join-Path $SchoolRoot '_搬移衝突'
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
      $conflictDir = Join-Path $SchoolRoot '_搬移衝突'
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
  Write-Host "請重新開啟 E:\學校 查看子目錄。"
} else {
  Write-Host ""
  Write-Host "Dry-run 結束。確認列表無誤後執行："
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\move-school-from-private.ps1 -Execute"
}
