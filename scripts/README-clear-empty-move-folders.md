# 清除搬移日誌／搬移衝突內的空白資料夾

只刪 `E:\` 底下 `_搬移日誌`、`_搬移衝突`（亦相容無底線名稱）**裡面的空白資料夾**；不刪這兩個根目錄本身，也不刪有檔案的目錄。

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\clear-empty-move-folders.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\clear-empty-move-folders.ps1 -Execute
```
