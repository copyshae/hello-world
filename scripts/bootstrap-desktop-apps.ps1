#Requires -Version 5.1
# 另一台 Windows 電腦：clone／更新 hello-world，再生成「習作台」與「習作批改」視窗捷徑。
# 用法（PowerShell 或 Cursor 終端機）：
#   powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-desktop-apps.ps1
# 尚未 clone 時可：
#   irm https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/bootstrap-desktop-apps.ps1 | iex
$ErrorActionPreference = 'Stop'

$desk = [Environment]::GetFolderPath('Desktop')
$repo = Join-Path $desk 'hello-world'
$remote = 'https://github.com/copyshae/hello-world.git'

function Assert-GitOk {
  param([string]$What)
  if ($LASTEXITCODE -ne 0) {
    throw "$What 失敗（結束代碼 $LASTEXITCODE）。私人倉庫請先 gh auth login，或在 Cursor 登入 GitHub。"
  }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw '請先安裝 Git。Cursor 終端機要能執行 git。'
}

Write-Host "===== 換機：生成習作台＋習作批改 ====="
Write-Host "倉庫：$repo"
Write-Host ""

if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
  if (Test-Path -LiteralPath $repo) {
    throw "已有資料夾 $repo 但不是 git 倉庫。請改名或刪除後重跑。"
  }
  Write-Host "正在 clone copyshae/hello-world …"
  & git clone $remote $repo
  Assert-GitOk 'git clone'
} else {
  Write-Host "已有倉庫，改拉 origin master …"
  & git -C $repo fetch origin
  Assert-GitOk 'git fetch'
  & git -C $repo checkout master
  Assert-GitOk 'git checkout master'
  & git -C $repo pull origin master
  Assert-GitOk 'git pull'
}

$install = Join-Path $repo 'scripts\install-desktop-apps.ps1'
if (-not (Test-Path -LiteralPath $install)) {
  throw "找不到 $install，請確認已 pull 到含安裝腳本的 master。"
}
& $install

$pip = Get-Command pip -ErrorAction SilentlyContinue
if ($pip) {
  Write-Host ""
  Write-Host "安裝 PDF 套件（pypdf、reportlab）…"
  & pip install pypdf reportlab
} else {
  Write-Host ""
  Write-Host "未偵測到 pip。習作批改要產 PDF 時請先裝 Python，再執行：pip install pypdf reportlab"
}

Write-Host ""
Write-Host "===== 下一步（這台也有 Cursor）====="
Write-Host "1. 用同一 Cursor 帳號登入（帶回 User Rules）"
Write-Host "2. Cursor 開啟資料夾：$repo"
Write-Host "3. 之後要重裝，對 Agent 說：裝習作台和習作批改"
Write-Host "4. 金鑰放桌面 MathGrading\gemini-api-key.txt（密碼管理器還原，不要 git）"
Write-Host "5. 雙擊桌面：習作台.cmd、習作批改.vbs"
