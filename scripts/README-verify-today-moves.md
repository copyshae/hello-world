# 確認今日搬移是否都在、檔名是否可用

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\verify-today-moves-on-e.ps1
```

會檢查：
1. 今日 `_搬移日誌` 裡的目的路徑是否還在（換過位置會補搜檔名）
2. 是否仍有 `_fromE_`／怪副檔名等不可用檔名
3. `E:\` 第一層檔案數摘要

報告在 `E:\_清點報告\verify_today_*.txt`。

若還有壞檔名：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
```
