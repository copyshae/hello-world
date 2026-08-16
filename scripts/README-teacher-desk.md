# 習作台｜電腦完整版＋手機版（繁體中文）

## 電腦完整版包含

| 捷徑 | 用途 |
|------|------|
| **習作台.cmd** | 掌握程度／發送狀態／篩選／管道／LINE 文案／匯入匯出／掃描夾 |
| **習作批改.vbs** | 載入答案、批閱、自產練習、數位發放循環 |

## 另一台電腦也有 Cursor

1. 同一 Cursor 帳號登入（帶回 User Rules）。
2. Cursor 開啟 `桌面\hello-world`（沒有就 clone `https://github.com/copyshae/hello-world.git`）。
3. 對 Agent 說：**裝習作台和習作批改**。  
   或在終端機執行：

```powershell
irm https://raw.githubusercontent.com/copyshae/hello-world/master/scripts/bootstrap-desktop-apps.ps1 | iex
```

4. 雙擊桌面 **習作台.cmd**、**習作批改.vbs**。  
5. 金鑰從密碼管理器放到 `桌面\MathGrading\gemini-api-key.txt`，不要 git。

線上步驟：https://copyshae.github.io/hello-world/directory/apps/desktop-install.html

## 一鍵安裝（已有倉庫）

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
