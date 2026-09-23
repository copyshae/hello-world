#Requires -Version 5.1
<#
.SYNOPSIS
  取消 E:\ 底下所有檔案／資料夾的「隱藏」屬性（預設 Dry-run）。

.DESCRIPTION
  - 清除 Hidden 屬性（必要時一併清 System，否則部分項目仍可能被檔案總管藏起）
  - 略過 System Volume Information、\$RECYCLE.BIN
  - 預設 Dry-run；加 -Execute 才真正改屬性
  - 另外會提示如何開啟「顯示隱藏的項目」

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1 -Execute
#>
[CmdletBinding()]
param(
  [string]$DriveRoot = 'E:\',
  [switch]$Execute,
  [switch]$AlsoClearSystem
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $DriveRoot)) {
  throw "找不到 $DriveRoot"
}

$skipSegRe = '^(System Volume Information|\$RECYCLE\.BIN)$'

function Test-UnderSkipped([string]$full) {
  foreach ($seg in ($full -split '[\\/]')) {
    if ($seg -match $skipSegRe) { return $true }
  }
  return $false
}

Write-Host ("Mode: {0}" -f ($(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN（加 -Execute 才會真的改）' })))
Write-Host ("DriveRoot: {0}" -f $DriveRoot)
Write-Host '目標: 取消 Hidden（可加 -AlsoClearSystem 一併取消 System）'
Write-Host ''

# 先設定檔案總管顯示隱藏項目（目前使用者）
function Enable-ExplorerShowHidden {
  $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  if (-not (Test-Path -LiteralPath $key)) { return }
  if ($Execute) {
    New-ItemProperty -Path $key -Name Hidden -PropertyType DWord -Value 1 -Force | Out-Null
    # 1 = 顯示隱藏的檔案、資料夾及驅動器
    New-ItemProperty -Path $key -Name ShowSuperHidden -PropertyType DWord -Value 1 -Force | Out-Null
    # 顯示受保護的作業系統檔案（搭配上面）
    Write-Host '已設定：檔案總管顯示隱藏項目（可能需重開檔案總管視窗才生效）'
  } else {
    Write-Host 'DRY-RUN 將設定：檔案總管 → 顯示隱藏的項目'
  }
}

Enable-ExplorerShowHidden

$hiddenItems = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
  if ($null -eq $_ -or [string]::IsNullOrWhiteSpace($_.FullName)) { return }
  if (Test-UnderSkipped $_.FullName) { return }
  $attr = $_.Attributes
  $isHidden = ($attr -band [IO.FileAttributes]::Hidden) -ne 0
  $isSystem = ($attr -band [IO.FileAttributes]::System) -ne 0
  if (-not $isHidden -and -not ($AlsoClearSystem -and $isSystem)) { return }
  $hiddenItems.Add([pscustomobject]@{
    Path     = $_.FullName
    IsDir    = [bool]$_.PSIsContainer
    Hidden   = $isHidden
    System   = $isSystem
    Attr     = $attr
  }) | Out-Null
}

Write-Host ("目前帶隱藏／系統屬性的項目: {0}" -f $hiddenItems.Count)
$cleared = 0
$err = 0
foreach ($item in $hiddenItems) {
  $flags = @()
  if ($item.Hidden) { $flags += 'Hidden' }
  if ($item.System) { $flags += 'System' }
  Write-Host ("[UNHIDE] ({0}) {1}" -f ($flags -join ','), $item.Path)
  if (-not $Execute) { continue }
  try {
    $entry = Get-Item -LiteralPath $item.Path -Force
    $newAttr = $entry.Attributes
    if ($item.Hidden) {
      $newAttr = $newAttr -band (-bnot [IO.FileAttributes]::Hidden)
    }
    if ($AlsoClearSystem -and $item.System) {
      $newAttr = $newAttr -band (-bnot [IO.FileAttributes]::System)
    }
    $entry.Attributes = $newAttr
    $cleared++
  } catch {
    $err++
    Write-Warning $_.Exception.Message
  }
}

Write-Host ''
if ($Execute) {
  Write-Host "done cleared=$cleared err=$err"
  Write-Host '請關閉後重開檔案總管，或按 F5。若仍看不到，在檔案總管「檢視」勾選「隱藏的項目」。'
} else {
  Write-Host 'Dry-run 結束。確認後執行：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1 -Execute'
  Write-Host '若仍有受保護系統檔被藏：'
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\unhide-all-on-e.ps1 -Execute -AlsoClearSystem'
}
