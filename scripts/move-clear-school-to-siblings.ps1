#Requires -Version 5.1
<#
.SYNOPSIS
  將 E:\學校 內檔案搬到合適的同層目錄，並清空學校（不重建私人）。

.DESCRIPTION
  - 超碼／天圓／弟子規／身心靈 → E:\超級生命密碼\…
  - 影音類名稱／影音骨架 → E:\影音歸檔（若存在）否則 E:\從學校移入\影音
  - 圖片類 → E:\圖片歸檔（若存在）
  - 文件／學年／試題／衛生等學校公務 → E:\文件歸檔\學校（若有文件歸檔）否則 E:\從學校移入
  - 其餘 → E:\從學校移入
  預設 Dry-run；-Execute 才搬；搬空後刪 E:\學校（殘留加 -Force）

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute
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
$ingestRoot = Join-Path $DriveRoot '從學校移入'
$docRoot = Join-Path $DriveRoot '文件歸檔'
$avRoot = Join-Path $DriveRoot '影音歸檔'
$imgRoot = Join-Path $DriveRoot '圖片歸檔'
$deskRoot = Join-Path $DriveRoot '桌面歸檔'

function Ensure-Dir([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
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

function Resolve-Dest([System.IO.FileSystemInfo]$item) {
  $name = $item.Name
  $ext = if ($item.PSIsContainer) { '' } else { $item.Extension.ToLowerInvariant() }

  # 1) 超碼體系
  if ($name -match '天圓|鳴馨|太陽盛德|文化事業') { return (Join-Path $superRoot '天圓文化') }
  if ($name -match '弟子規|弟子歸') { return (Join-Path $superRoot '弟子規') }
  if ($name -match '超級生命密碼|生命密碼|超碼') { return (Join-Path $superRoot '超級生命密碼') }
  if ($name -match '身心靈|修行|滋養研究|人生成長實作') { return (Join-Path $superRoot '身心靈修行') }

  # 2) 影音
  if ($name -match '影音|影片|歌曲|音樂|錄音' -or $ext -in @('.mp4', '.mkv', '.avi', '.mov', '.mp3', '.wav', '.m4a', '.wmv')) {
    if (Test-Path -LiteralPath $avRoot) { return $avRoot }
    return (Join-Path $ingestRoot '影音')
  }

  # 3) 圖片
  if ($name -match '圖片|相片|照片' -or $ext -in @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tif', '.webp')) {
    if (Test-Path -LiteralPath $imgRoot) { return $imgRoot }
    return (Join-Path $ingestRoot '圖片')
  }

  # 4) 學校公務／文件
  if ($name -match '學年|試題|教案|衛生|健促|科展|請假|打掃|掃地|教室|班級|學校|課表|配課|彰安|文件|公文|掃描' -or
      $name -match '^(學年資料|衛生健促|科展科學營|試題教案|請假|打掃區域|其他學校|_搬移衝突|_搬移日誌)$' -or
      $ext -in @('.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf', '.txt')) {
    if (Test-Path -LiteralPath $docRoot) { return (Join-Path $docRoot '學校') }
    return $ingestRoot
  }

  # 5) 桌面相關
  if ($name -match '桌面' -and (Test-Path -LiteralPath $deskRoot)) {
    return $deskRoot
  }

  return $ingestRoot
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("SchoolRoot: {0}" -f $SchoolRoot)
Write-Host '規則: 超碼→超級生命密碼；影音/圖片→對應歸檔（若有）；學校文件→文件歸檔\學校 或 從學校移入；不重建私人'
Write-Host ''

Write-Host '======== E:\ 同層目錄 ========'
Get-ChildItem -LiteralPath $DriveRoot -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.PSIsContainer } |
  ForEach-Object { Write-Host ("  {0}" -f $_.Name) }

Ensure-Dir $superRoot
foreach ($s in @('超級生命密碼', '天圓文化', '弟子規', '身心靈修行')) {
  Ensure-Dir (Join-Path $superRoot $s)
}
Ensure-Dir $ingestRoot
if (Test-Path -LiteralPath $docRoot) { Ensure-Dir (Join-Path $docRoot '學校') }

$items = @(Get-ChildItem -LiteralPath $SchoolRoot -Force -ErrorAction SilentlyContinue)
Write-Host ("E:\學校 第一層項目: {0}" -f $items.Count)

$moved = 0
$err = 0

foreach ($item in $items) {
  $destDir = Resolve-Dest $item
  Ensure-Dir $destDir
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
    Write-Host '已 -Force 刪除 E:\學校'
  } else {
    Write-Host '尚有殘留。可加 -Force 刪除資料夾：'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute -Force'
    foreach ($x in $left) { Write-Host ("  LEFT {0}" -f $x.FullName) }
  }
  Write-Host "done moved=$moved err=$err"
} else {
  Write-Host 'Dry-run 結束。確認後：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute'
}
