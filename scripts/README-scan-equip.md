# 掃具台｜手機 PWA（繁體中文）

## 用途

校園掃具請領管理：各班導師掃描王拍照登記，或手動輸入請領紀錄，統計各掃具種類累積數量。

## 手機版

https://copyshae.github.io/hello-world/directory/apps/scan-equip/

Safari → 分享 → 加入主畫面

## 主要功能

| 功能 | 說明 |
|------|------|
| 拍照掃描登記 | 掃描王拍照辨識手寫請領單，自動解析班級、數量 |
| 手動輸入 | 直接填寫日期、班級、各掃具數量（支援負數扣回） |
| CSV 匯入 | 從 Excel 或 Numbers 匯出 CSV，整批匯入請領紀錄 |
| 匯出備份 | 匯出 JSON 備份；匯出 CSV 供 Excel 統計 |
| 請領列表 | 依日期顯示各班請領紀錄，可編輯或刪除 |
| 統計頁 | 各掃具種類累計數量一覽 |

## 今日（2026-08-19）修正

- CSV 匯入時負數數量（如 `-2`，代表扣回）不再被截為 `0`

## 設定

- 掃具種類可在設定頁新增或刪除
- 班級導師名單依 115 學年度官方來源維護

## 安裝桌面捷徑

```powershell
cd $env:USERPROFILE\Desktop\hello-world
powershell -ExecutionPolicy Bypass -File .\scripts\install-scan-equip.ps1
```
