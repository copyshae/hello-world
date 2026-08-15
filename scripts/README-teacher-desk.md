# 習作台｜老師掌握與發送（繁體中文）

桌面視窗與 iPhone 網頁 App 皆為**繁體中文介面**。功能：程度／發送狀態、篩選、發放與回傳管道、LINE 文案、批次改狀態、班級資料互通、掃描匯入。只用座號，不存姓名。

## 桌面安裝（一定要跑）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull origin master
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-apps.ps1
```

桌面捷徑：
- **習作台.vbs**
- **習作批改.vbs**（若一併安裝）

資料夾：
- `桌面\習作台程式\`
- `桌面\習作台資料\`（班級狀態.json、掃描匯入）

## 手機

https://copyshae.github.io/hello-world/directory/apps/teacher-desk/

Safari → 分享 → **加入主畫面**

## 手機 ↔ 電腦同步

一端「匯出班級資料」→ AirDrop／雲端傳檔 → 另一端「匯入班級資料」
