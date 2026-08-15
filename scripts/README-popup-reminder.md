﻿# 彈跳式視窗提醒

本機中央置頂小視窗，按「知道了」關閉。

## 立刻提醒

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull

powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 `
  -Title "Google 相簿" `
  -Message "請檢查 Takeout 郵件，下載後解壓到 E:\GOOGLE相簿"
```

## 延遲 N 分鐘再跳

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 `
  -Title "休息提醒" `
  -Message "站起來活動一下" `
  -DelayMinutes 25
```

## 自動關閉

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-popup-reminder.ps1 `
  -Message "備份腳本可重跑續傳" `
  -AutoCloseSeconds 15
```

靜音：加 `-NoSound`。
