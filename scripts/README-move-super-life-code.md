# 私人／學校 → E:\超級生命密碼

把 `E:\私人`、`E:\學校` 裡與**超級生命密碼、天圓文化、弟子規**（及身心靈修行）相關的子資料夾／檔案，搬到 `E:\超級生命密碼`。

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull
git checkout cursor/move-company-from-private-f39f

# 預覽
powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1

# 真的搬
powershell -ExecutionPolicy Bypass -File .\scripts\move-super-life-code.ps1 -Execute
```

## 目的結構

| 匹配關鍵字 | 進到 |
|------------|------|
| 超級生命密碼、生命密碼 | `E:\超級生命密碼\超級生命密碼` |
| 天圓、鳴馨、太陽盛德、文化事業 | `E:\超級生命密碼\天圓文化` |
| 弟子規 | `E:\超級生命密碼\弟子規` |
| 身心靈、修行、滋養研究… | `E:\超級生命密碼\身心靈修行` |

## 行為

| 項目 | 說明 |
|------|------|
| 預設來源 | **`E:\私人`、`E:\學校`**（深度 1～6，含歸檔／其他學校／`_搬移衝突`） |
| 加 `-AllArchives` | 另掃公司、根層文件／影音／圖片／桌面／下載歸檔 |
| 略過 | `備份` 骨架名、已在 `E:\超級生命密碼` 底下 |
| 刪檔 | **不刪**；同名合併；衝突進 `_搬移衝突` |
