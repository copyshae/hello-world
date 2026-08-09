# 清空 E:\學校 → 歸到同層其他目錄

| 內容 | 目的 |
|------|------|
| 超碼／生命密碼／天圓／弟子規／身心靈 | `E:\超級生命密碼\…` |
| 其餘（學年、試題、衝突區等） | `E:\私人\從學校移入` |

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-school-to-siblings.ps1 -Execute
```

殘留要連資料夾刪掉：加 `-Force`。

