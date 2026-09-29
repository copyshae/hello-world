# 恢復 E:\ 被改壞的副檔名

把像下面這種**打不開**的檔名修好：

| 壞名 | 恢復後 |
|------|--------|
| `報告.xls_fromE_20260809160544254` | `報告.xls` |
| `圖.jpg_fromPrivate_…` | `圖.jpg` |
| `簡報_fromE_….pptx` | `簡報.pptx` |
| `檔案.xls_衝突_…` | `檔案.xls` |

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\restore-usable-extensions-on-e.ps1 -Execute
```

先預覽 `Candidates`；確認都是要修的再 `-Execute`。
