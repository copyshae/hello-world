# 搬移衝突檔名去掉 fromE 等英文後綴

把 `_搬移衝突` 內檔名／**資料夾名**的 `fromE`／`fromPrivate` 等英文及其後文字去掉。

例：
- `報告_fromE_20260809123456789.pdf` → `報告.pdf`
- `10402_fromE_20260809160546951`（資料夾）→ `10402`

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
```
