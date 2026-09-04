# 感覺檔案不見了？先清點再歸位

整理用的是 **搬移**，不是刪除。檔案常在：

- `E:\學校\_搬移衝突`
- `E:\超級生命密碼\_搬移衝突`
- `E:\私人\備份\…` 深處
- 各分類子資料夾裡

## 1) 先清點（必跑）

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\inventory-e-drive.ps1
```

報告在 `E:\_清點報告\`。看各第一層 `files=` 數量，確認檔案還在碟上。

## 2) 從衝突區／備份依關鍵字重新分類

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\reclassify-misplaced-on-e.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\reclassify-misplaced-on-e.ps1 -Execute
```

會把命中「弟子規／天圓／生命密碼／學校關鍵字…」的項目搬回：

- `E:\超級生命密碼\…`
- `E:\學校\…`
- `E:\私人\掃描檔`（公司掃描類）

## 3) 再補一次正式分類（可選）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1 -Execute
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
```
