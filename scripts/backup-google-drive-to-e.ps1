#Requires -Version 5.1
<#
.SYNOPSIS
  將 G: 上的 Google Drive 全部備份到 E:\google_drive（預設 Dry-run）。

.DESCRIPTION
  - 自動偵測常見路徑：G:\我的雲端硬碟、G:\My Drive、G:\
  - 使用 robocopy 複製（保留時間戳；可續傳）
  - 預設只列出；加 -Execute 才真正複製
  - 不加 /MIR：不會刪 E: 多餘檔（安全備份）。若要鏡像可加 -Mirror

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute
  powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute -Mirror
#>
[CmdletBinding()]
param(
  [string]$SourceRoot = '',
  [string]$DestRoot = 'E:\google_drive',
  [switch]$Execute,
  [switch]$Mirror
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Find-GoogleDriveRoot {
  $candidates = @(
    'G:\我的雲端硬碟',
    'G:\My Drive',
    'G:\Shared drives',
    'G:\共用雲端硬碟',
    'G:\'
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
  }
  return $null
}

if (-not (Test-Path -LiteralPath 'G:\')) {
  throw '找不到 G:\。請確認 Google Drive 桌面版已登入，且磁碟代號是 G:。'
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
  $SourceRoot = Find-GoogleDriveRoot
}
if ([string]::IsNullOrWhiteSpace($SourceRoot) -or -not (Test-Path -LiteralPath $SourceRoot)) {
  throw '找不到 Google Drive 來源資料夾。請用 -SourceRoot 指定，例如 -SourceRoot "G:\我的雲端硬碟"'
}

if (-not (Test-Path -LiteralPath 'E:\')) {
  throw '找不到 E:\。請插入外接碟。'
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })))
Write-Host ("Source: {0}" -f $SourceRoot)
Write-Host ("Dest:   {0}" -f $DestRoot)
Write-Host ("Mirror: {0}  (Mirror=會刪目的多餘檔，一般備份請保持 false)" -f [bool]$Mirror)
Write-Host ''

# 來源大概量
Write-Host '正在統計來源（可能較久）...'
$srcFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force -ErrorAction SilentlyContinue)
$srcBytes = ($srcFiles | Measure-Object Length -Sum).Sum
if ($null -eq $srcBytes) { $srcBytes = 0 }
Write-Host ("來源檔案約: {0} 個，{1} GB" -f $srcFiles.Count, [math]::Round($srcBytes / 1GB, 2))

if (-not $Execute) {
  Write-Host ''
  Write-Host '以上為預覽。確認 G: 已「串流/鏡像」可讀後執行：'
  Write-Host ('  powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute')
  Write-Host '若來源不是自動偵測到的路徑：'
  Write-Host ('  powershell -ExecutionPolicy Bypass -File .\scripts\backup-google-drive-to-e.ps1 -Execute -SourceRoot "G:\我的雲端硬碟"')
  exit 0
}

if (-not (Test-Path -LiteralPath $DestRoot)) {
  New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
  Write-Host "MKDIR $DestRoot"
}

# robocopy：/E 含空目錄；/COPY:DAT 資料+屬性+時間；/R:2 /W:3 重試；/XD 略過系統垃圾
$xd = @('.tmp', 'System Volume Information', '$RECYCLE.BIN')
$roboArgs = @(
  $SourceRoot, $DestRoot,
  '/E',
  '/COPY:DAT',
  '/DCOPY:T',
  '/R:2',
  '/W:3',
  '/XJ',
  '/FFT',
  '/NP',
  '/NDL',
  '/NFL'
)
if ($Mirror) { $roboArgs += '/MIR' }
foreach ($d in $xd) { $roboArgs += @('/XD', $d) }

Write-Host ''
Write-Host ('RUN: robocopy ' + ($roboArgs -join ' '))
$p = Start-Process -FilePath 'robocopy.exe' -ArgumentList $roboArgs -Wait -PassThru -NoNewWindow
$code = $p.ExitCode
# robocopy: 0-7 多為成功／有差異；>=8 才是錯誤
Write-Host ("robocopy exit={0}" -f $code)
if ($code -ge 8) {
  throw "robocopy 失敗 exit=$code"
}

Write-Host ''
Write-Host '備份完成。抽樣目的：'
Get-ChildItem -LiteralPath $DestRoot -Force -ErrorAction SilentlyContinue |
  Select-Object -First 30 Mode, LastWriteTime, Name |
  Format-Table -AutoSize | Out-String | Write-Host
Write-Host ("目的: {0}" -f $DestRoot)
Write-Host '注意：若 Google Drive 是「串流」模式，未下載的雲端檔可能複製不到；請在 Drive 設定改「鏡像」或先釘選離線。'
