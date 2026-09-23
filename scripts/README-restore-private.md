# 關於 E:\私人

依目前需求：**不要重建 `E:\私人`**。  
原私人子目錄（財務／備份／影音歸檔等）維持在 `E:\` 同層即可。

`restore-private-root-on-e.ps1` 請**不要執行**（那支會重建私人）。

清空學校請用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute
```
