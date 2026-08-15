# 習作台｜電腦完整版＋手機版（繁體中文）

## 電腦完整版包含

| 捷徑 | 用途 |
|------|------|
| **習作台.cmd** | 掌握程度／發送狀態／篩選／管道／LINE 文案／匯入匯出／掃描夾 |
| **習作批改.vbs** | 載入答案、批閱、自產練習、數位發放循環 |

## 一鍵安裝

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull origin master
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-apps.ps1
```

若 git pull 失敗，可直接下載安裝習作台：

```powershell
$desk=[Environment]::GetFolderPath('Desktop'); $app=Join-Path $desk '習作台程式'; $work=Join-Path $desk '習作台資料'; New-Item -ItemType Directory -Force -Path $app,$work | Out-Null; $t=(Invoke-WebRequest 'https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/teacher-desk-app.ps1' -UseBasicParsing).Content; [IO.File]::WriteAllText((Join-Path $app 'teacher-desk-app.ps1'), $t, (New-Object Text.UTF8Encoding $true)); Invoke-WebRequest 'https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/install-teacher-desk.ps1' -OutFile (Join-Path $env:TEMP 'install-teacher-desk.ps1') -UseBasicParsing; powershell -ExecutionPolicy Bypass -File (Join-Path $env:TEMP 'install-teacher-desk.ps1')
```

請雙擊 **習作台.cmd**（不要只貼說明文字到 PowerShell）。

## 手機版

https://copyshae.github.io/hello-world/directory/apps/teacher-desk/  
Safari → 分享 → 加入主畫面

## 分工

- **習作批改**：電腦批閱、產練習檔  
- **習作台**（電腦或手機）：誰該發、貼 LINE、追蹤回傳、與手機互通班級資料
