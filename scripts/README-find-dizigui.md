# 找回弟子規（弟子歸）第 1～41 集文字檔／MP4

整碟搜尋 `E:\`（含 `私人\備份`、`_搬移衝突`），列出後可搬到 `E:\超級生命密碼\弟子規`。

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull

# 只搜尋（會寫報告到 E:\_清點報告\dizigui_find_*.txt）
powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1

# 搜到後搬到 E:\超級生命密碼\弟子規
powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1 -Execute

# 若副檔名被改壞打不開
powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute
```

先前曾出現路徑：
`E:\私人\備份\另一硬碟備份\1100519 桌機備份\弟子規`
