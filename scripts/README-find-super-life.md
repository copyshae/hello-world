# 找回超碼／超級生命密碼／天圓相關檔

整碟搜尋 `E:\`（含備份、`_搬移衝突`），可搬回 `E:\超級生命密碼`。

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull

# 只搜尋（報告：E:\_清點報告\superlife_find_*.txt）
powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1

# 搬到 E:\超級生命密碼\（超碼／天圓／身心靈等子夾）
powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1 -Execute
```

建議與弟子規一起跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\find-dizigui-episodes-on-e.ps1 -Execute
powershell -ExecutionPolicy Bypass -File .\scripts\find-super-life-on-e.ps1 -Execute
powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute
```
