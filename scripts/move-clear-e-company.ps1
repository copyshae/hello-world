#Requires -Version 5.1
<#
.SYNOPSIS
  將 E:\公司 內容搬移併入 E:\學校 後，刪除 E:\公司（預設 Dry-run）。

.DESCRIPTION
  - E:\公司 第一層分類／檔案 → 併入 E:\學校（依名稱分類；分不出放「其他學校」）
  - 公文合約／財務報銷／掃描檔等公司骨架子項：整包內容併入對應或「其他學校」
  - _搬移* → E:\學校\_搬移日誌
  - 全部搬完後刪除 E:\公司

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$CompanyRoot = 'E:\公司',
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

function Get-UniqueDest([string]$dir, [string]$name) {
  $dest = Join-Path $dir $name
  if (-not (Test-Path -LiteralPath $dest)) { return $dest }
  $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
  $ext = [System.IO.Path]::GetExtension($name)
  for ($i = 2; $i -le 999; $i++) {
    $candidate = Join-Path $dir ('{0}_{1}{2}' -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  throw "無法產生唯一路徑: $name"
}

$schoolRules = @(
  @{ Re = '^(school|\d{3}學年school)$|學年school|\d{3}學年'; Dest = '學年資料' },
  @{ Re = '衛生|健促|健康促進'; Dest = '衛生健促' },
  @{ Re = '科展|科學營'; Dest = '科展科學營' },
  @{ Re = '試題|教案|公開課|習作|評量|段考|模擬考'; Dest = '試題教案' },
  @{ Re = '請假'; Dest = '請假' },
  @{ Re = '打掃|掃地|教室分佈|清潔區'; Dest = '打掃區域' },
  @{ Re = '學校|班級|教室|導師|數學|國文|英文|自然|社會|綜合|彰安|科任|配課|課表|導師費|班親'; Dest = '其他學校' }
)

function Resolve-SchoolDest([string]$name) {
  if ($name -match '^(_搬移|_搬移衝突|_搬移日誌)') { return '_搬移日誌' }
  # 原公司骨架資料夾：併入「其他學校」
  if ($name -in @('公文合約', '財務報銷', '掃描檔', '公司')) { return '其他學校' }
  foreach ($r in $schoolRules) {
    if ($name -match $r.Re) { return $r.Dest }
  }
  return '其他學校'
}

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的搬／刪）' })))
Write-Host ("CompanyRoot: {0}" -f $CompanyRoot)
Write-Host ("SchoolRoot: {0}" -f $SchoolRoot)

if (-not (Test-Path -LiteralPath $CompanyRoot)) {
  Write-Host '沒有 E:\公司，無需搬移清空。'
  exit 0
}

Ensure-Dir $SchoolRoot
foreach ($s in @('學年資料', '衛生健促', '科展科學營', '試題教案', '請假', '打掃區域', '其他學校', '_搬移衝突', '_搬移日誌')) {
  Ensure-Dir (Join-Path $SchoolRoot $s)
}

$items = @(Get-ChildItem -LiteralPath $CompanyRoot -Force -ErrorAction SilentlyContinue)
Write-Host ("E:\公司 目前第一層: {0} 項" -f $items.Count)
$items | Select-Object Mode, LastWriteTime, Name | Format-Table -AutoSize | Out-String | Write-Host

$moved = 0
$err = 0

function Move-One([string]$source, [string]$destDir, [string]$name, [bool]$isDir) {
  $script:destDir = $destDir
  Ensure-Dir $destDir
  $dest = Join-Path $destDir $name

  if ($Execute -and (Test-Path -LiteralPath $dest) -and $isDir) {
    $destItem = Get-Item -LiteralPath $dest -Force
    if ($destItem.PSIsContainer) {
      Write-Host ("[MERGE] {0} -> {1}" -f $source, $dest)
      Get-ChildItem -LiteralPath $source -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $childDest = Get-UniqueDest $dest $_.Name
        Write-Host ("  [MOVE] {0} -> {1}" -f $_.FullName, $childDest)
        try {
          Move-Item -LiteralPath $_.FullName -Destination $childDest -Force
          $script:moved++
        } catch {
          $script:err++
          Write-Warning $_.Exception.Message
        }
      }
      if (Test-Path -LiteralPath $source) {
        Remove-Item -LiteralPath $source -Recurse -Force -ErrorAction SilentlyContinue
      }
      return
    }
  }

  if ($Execute -and (Test-Path -LiteralPath $dest)) {
    $dest = Get-UniqueDest $destDir $name
  }
  Write-Host ("[MOVE] {0} -> {1}" -f $source, $dest)
  if (-not $Execute) { return }
  try {
    Ensure-Dir (Split-Path -Parent $dest)
    Move-Item -LiteralPath $source -Destination $dest -Force
    $script:moved++
  } catch {
    $script:err++
    Write-Warning $_.Exception.Message
  }
}

foreach ($item in $items) {
  $destSub = Resolve-SchoolDest $item.Name
  $destDir = Join-Path $SchoolRoot $destSub

  # 公司骨架資料夾：把「內容」併入學校分類，不要多一層「掃描檔\掃描檔」
  if ($item.PSIsContainer -and ($item.Name -in @('公文合約', '財務報銷', '掃描檔', '證件合約', '財務') -or $item.Name -match '^_搬移')) {
    $children = @(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue)
    Write-Host ("[MERGE-DIR] {0} ({1} 項) -> {2}" -f $item.FullName, $children.Count, $destDir)
    foreach ($child in $children) {
      $childSub = Resolve-SchoolDest $child.Name
      # 子項若無更佳分類，跟父資料夾同一個 destSub
      if ($childSub -eq '其他學校' -and $destSub -ne '其他學校') { $childSub = $destSub }
      if ($child.Name -match '^_搬移') { $childSub = '_搬移日誌' }
      $childDestDir = Join-Path $SchoolRoot $childSub
      Move-One $child.FullName $childDestDir $child.Name $child.PSIsContainer
    }
    if ($Execute -and (Test-Path -LiteralPath $item.FullName)) {
      Remove-Item -LiteralPath $item.FullName -Recurse -Force
      Write-Host ("[REMOVE-EMPTY] {0}" -f $item.FullName)
    } elseif (-not $Execute) {
      Write-Host ("[REMOVE-AFTER] {0}" -f $item.FullName)
    }
    continue
  }

  Move-One $item.FullName $destDir $item.Name $item.PSIsContainer
}

Write-Host ""
if ($Execute) {
  if (Test-Path -LiteralPath $CompanyRoot) {
    Remove-Item -LiteralPath $CompanyRoot -Recurse -Force
    Write-Host '已清除 E:\公司'
  }
  Write-Host "done moved=$moved err=$err"
  Write-Host '請按 F5：E:\ 第一層不應再有「公司」；內容在 E:\學校。'
} else {
  Write-Host 'Dry-run 結束。確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1 -Execute'
}
