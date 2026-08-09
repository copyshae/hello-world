# 恢復 E:\私人（子目錄被提到 E:\ 同層時）

當 `E:\私人` 已刪、底下的「財務／備份／影音歸檔…」出現在 `E:\` 根層：

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\restore-private-root-on-e.ps1 -Execute
```

會重建 `E:\私人`，並把根層那些原子目錄移回去。  
不搬：`學校`、`超級生命密碼`、系統資料夾。
