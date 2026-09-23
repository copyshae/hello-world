# 搬移並清空 E:\公司 → 併入 E:\學校

把 `E:\公司` 內容**搬移併入** `E:\學校`，然後刪除 `E:\公司`。

| 來源 | 目的 |
|------|------|
| 公文合約／財務報銷／掃描檔（內容） | `E:\學校\其他學校`（子項名稱若命中學年／試題等則進對應分類） |
| 名稱含學年／試題／衛生… | 對應 `E:\學校\…` 分類 |
| `_搬移*` | `E:\學校\_搬移日誌` |
| 其他 | `E:\學校\其他學校` |

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\move-clear-e-company.ps1 -Execute
```
