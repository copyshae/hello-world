#Requires -Version 5.1
<#
.SYNOPSIS
  將 E:\學校 內所有內容歸類到同層其他目錄（私人／超級生命密碼等），並清空學校目錄。

.DESCRIPTION
  目的同層（E:\ 第一層；不重建 E:\私人）：
    - 超碼／生命密碼／天圓／弟子規／身心靈 → E:\超級生命密碼\（對應子夾）
    - 其餘 → E:\從學校移入（同層新資料夾）
  搬完後刪除空的 E:\學校（含殘留則 -Force 才整包刪）。
  預設 Dry-run；加 -Execute 才搬／刪。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute -Force
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [string]$SchoolRoot = 'E:\學校',
  [switch]$Execute,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) { throw "找不到 $DriveRoot" }
if (-not (Test-Path -LiteralPath $SchoolRoot)) {
  Write-Host '沒有 E:\學校，無需處理。'
  exit 0
}

$superRoot = Join-Path $DriveRoot '超級生命密碼'
# 不重建 E:\私人；其餘學校內容放到同層 E:\從學校移入
$schoolIngest = Join-Path $DriveRoot '從學校移入'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    if ($Execute) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Write-Host "MKDIR $p"
  }
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

function Resolve-Dest([string]$name) {
  if ($name -match '天圓|鳴馨|太陽盛德|文化事業') {
    return (Join-Path $superRoot '天圓文化')
  }
  if ($name -match '弟子規|弟子歸') {
    return (Join-Path $superRoot '弟子規')
  }
  if ($name -match '超級生命密碼|生命密碼|超碼') {
    return (Join-Path $superRoot '超級生命密碼')
  }
  if ($name -match '身心靈|修行|滋養研究|人生成長實作') {
    return (Join-Path $superRoot '身心靈修行')
  }
  # 其餘學校內容 → E:\從學校移入（同層，不經私人）
  return $schoolIngest
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("SchoolRoot: {0}" -f $SchoolRoot)
Write-Host '規則: 超碼／天圓／弟子規 → E:\超級生命密碼\… ；其餘 → E:\從學校移入（不重建私人）'
Write-Host ''

# 同層目錄一覽
Write-Host '======== E:\ 同層目錄 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.PSIsContainer } |
  ForEach-Object { Write-Host ("  {0}" -f $_.Name) }

Ensure-Dir $superRoot
foreach ($s in @('超級生命密碼', '天圓文化', '弟子規', '身心靈修行')) {
  Ensure-Dir (Join-Path $superRoot $s)
}
Ensure-Dir $schoolIngest

$items = @(Get-ChildItem -LiteralPath $SchoolRoot -Force -ErrorAction SilentlyContinue)
Write-Host ("E:\學校 第一層項目: {0}" -f $items.Count)

$moved = 0
$err = 0

foreach ($item in $items) {
  # 略過純日誌文字可跟著走；空殼分類夾也搬／合併
  $destDir = Resolve-Dest $item.Name

  # 若是學校骨架子夾（學年資料等），整包進 私人\從學校移入\原名
  if ($item.PSIsContainer -and ($item.Name -match '^(學年資料|衛生健促|科展科學營|試題教案|請假|打掃區域|其他學校|_搬移衝突|_搬移日誌)$')) {
    $destDir = $schoolIngest
  }

  Ensure-Dir $destDir

  # 目的已有同名資料夾 → 合併子項
  $dest = Join-Path $destDir $item.Name
  Write-Host ("[{0}] {1}" -f ($(if ($item.PSIsContainer) { 'DIR' } else { 'FILE' }), $item.FullName))
  Write-Host ("     -> {0}" -f $dest)

  if (-not $Execute) { continue }

  try {
    if ($item.PSIsContainer -and (Test-Path -LiteralPath $dest)) {
      Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $childDest = Get-UniqueDest $dest $_.Name
        Move-Item -LiteralPath $_.FullName -Destination $childDest -Force
      }
      Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
    } else {
      if (Test-Path -LiteralPath $dest) {
        $dest = Get-UniqueDest $destDir $item.Name
        Write-Host ("     改名避開衝突: {0}" -f $dest)
      }
      Move-Item -LiteralPath $item.FullName -Destination $dest -Force
    }
    $moved++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
# 清空學校
$left = @()
if (Test-Path -LiteralPath $SchoolRoot) {
  $left = @(Get-ChildItem -LiteralPath $SchoolRoot -Force -ErrorAction SilentlyContinue)
}
Write-Host ("搬完後 E:\學校 殘留: {0} 項" -f $left.Count)

if ($Execute) {
  if ($left.Count -eq 0) {
    Remove-Item -LiteralPath $SchoolRoot -Force
    Write-Host '已刪除空的 E:\學校'
  } elseif ($Force) {
    Remove-Item -LiteralPath $SchoolRoot -Recurse -Force
    Write-Host '已 -Force 刪除 E:\學校（含殘留）'
  } else {
    Write-Host '尚有殘留，未刪 E:\學校。確認後可加 -Force：'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute -Force'
    foreach ($x in $left) { Write-Host ("  LEFT {0}" -f $x.FullName) }
  }
  Write-Host "done moved=$moved err=$err"
} else {
  Write-Host 'Dry-run 結束。確認後：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute'
}
