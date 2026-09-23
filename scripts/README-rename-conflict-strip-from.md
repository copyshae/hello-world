# 搬移衝突檔名去掉 fromE 等英文後綴

把 `_搬移衝突` 內檔名／**資料夾名**的 `fromE`／`fromPrivate` 等英文及其後文字去掉。

例（刪的是檔名**後面**的 `_fromE_時間戳`）：
- `報告_fromE_20260809123456789.pdf` → `報告.pdf`
- `嘉獎名單.xls_fromE_20260809160544254` → `嘉獎名單.xls`
- `10402_fromE_20260809160546951`（資料夾）→ `10402`

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\rename-conflict-strip-from.ps1 -Execute
```
