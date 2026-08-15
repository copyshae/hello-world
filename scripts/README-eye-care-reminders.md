# 護眼／用藥／飲水彈跳提醒

依個人保養需求的本機提醒（**非醫療指示**；點藥、用藥劑量請依醫師）。

## 預設時程

| 時間 | 提醒 |
|------|------|
| **07:30** | 早餐後點眼藥水、服用百恩晴、開始日間補水 |
| **07:30–17:00** | 每 **20 分** 遠眺／閉眼約 20 秒；每 **60 分** 離開螢幕約 5 分；每 **60 分** 喝水 |
| **12:00** | 午餐、點眼藥水、喝水 |
| **18:00** | 晚餐、點眼藥水 |
| **21:00** | 服用益生菌 |
| **22:00** | 睡前點眼藥水 |

可改 `scripts/eye-care-reminders.config.json` 的時間與間隔。

## 本機啟動

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/eye-care-reminders-433c

# 常駐（開著一個最小化 PowerShell；關了就不再提醒）
powershell -ExecutionPolicy Bypass -File .\scripts\start-eye-care-reminders.ps1

# 登入自動開
powershell -ExecutionPolicy Bypass -File .\scripts\install-eye-care-reminders.ps1
```

視窗為**大字、高對比、置頂**。同一則每日只跳一次（狀態在 `%LOCALAPPDATA%\hello-world-eye-care\`）。

## 說明

- 用眼休息採常見「20-20-20」精神（每 20 分鐘遠眺約 20 秒），並加每小時較長休息；若醫師有不同囑咐，請改設定檔。
- 不記錄病歷細節到雲端；本 README 只寫提醒項目。
