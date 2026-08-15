# 習作台｜老師掌握與發送（手機＝電腦同功能）

桌面 WinForms 與 iPhone PWA **功能對齊**：程度／發送狀態、篩選、發放與回傳管道、LINE 文案預覽與複製、批次改狀態、**class-state.json 匯入匯出互通**。只用座號，不存姓名。

## 桌面安裝（一定要跑這段，捷徑才會出現）

在電腦 **PowerShell** 執行：

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull origin master
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-apps.ps1
```

完成後桌面會有：
- **習作台.vbs**（掌握／發送）
- **習作批改.vbs**（若腳本存在）

或只裝習作台：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-teacher-desk.ps1
```

雙擊 **習作台.vbs**。資料在 `Desktop\TeacherDesk\class-state.json`。

## 手機（與電腦相同操作）

https://copyshae.github.io/hello-world/directory/apps/teacher-desk/

Safari → 分享 → **加入主畫面**。

## 手機 ↔ 電腦同步

1. 一端按「匯出 class-state.json」  
2. AirDrop／OneDrive／LINE 傳檔  
3. 另一端「匯入 JSON（覆蓋）」

## 與「習作批改」分工

| 程式 | 做什麼 |
|------|--------|
| **習作批改.vbs** | 載入答案、批閱、自產練習 PDF／數位檔 |
| **習作台.vbs／手機習作台** | 掌握誰該發、貼 LINE、追蹤回傳 |

批改在電腦完成後，用習作台（手機或桌面）發送與追蹤即可。
