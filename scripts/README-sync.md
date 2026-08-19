# 兩台電腦＋手機：完整同步指南

權威分工（不要搞混）：

| 資料 | 權威來源 | 檔案 |
|------|----------|------|
| 程度（跟上／略落後…） | **習作批改** | `習作批改進度.json` |
| 發送／回傳／期限／管道 | **習作台** | `班級狀態.json` |
| 掃描圖／試卷本體 | 各端資料夾／IndexedDB | 不進 JSON；用 `05-R01.pdf` 傳檔 |

## 日常（同一手機瀏覽器、同源）

1. 習作批改自動批／連續批 → 程度會寫入習作台（亦可按「全部程度寫入習作台」）
2. 習作台按「從習作批改同步程度」再確認
3. 習作台複製群發文 → 標未發／已發／待回

正式網址請固定用：  
https://copyshae.github.io/hello-world/directory/apps/math-grader/  
https://copyshae.github.io/hello-world/directory/apps/teacher-desk/

（預覽網址與正式站 **localStorage 不互通**。）

## 換手機／換電腦／兩台電腦

每端各匯出兩份，傳到另一端再匯入：

1. **習作批改** →「匯出批改進度」→ `習作批改進度.json`
2. **習作台** →「匯出班級資料」→ `班級狀態.json`
3. 另一端：批改「匯入批改進度」；習作台「匯入班級資料」
4. 若只要程度：習作台「匯入批改進度（只更新程度）」；批改「從班級狀態匯入程度」

掃描檔另傳：`座號-R次數.ext` → 電腦 `習作台資料\掃描匯入`。

## 桌面批改 ↔ 桌面習作台

- 習作批改按 **「同步程度→習作台」**：把註記程度寫入 `桌面\習作台資料\班級狀態.json`
- 習作批改按 **「匯出批改進度JSON」**：給手機／另一台匯入
- 習作台按 **「從批改進度匯入程度」**：讀手機或另一台匯出的進度檔

## 套用本更新

```powershell
cd $env:USERPROFILE\Desktop\hello-world
# 用 pull-export-from-dash-repo.ps1 或 apply 套用 _export 後：
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-apps.ps1
```

手機請強制重新整理或清掉該站快取後再開（SW：math-grader-v15、teacher-desk-v6）。
