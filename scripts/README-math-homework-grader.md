# 數學習作／試卷批改：一人一檔（Gemini 自動批｜對照答案或直接 AI）

## 兩種自動批（都用 Gemini API）

| 情況 | 行為 |
|------|------|
| **有載入正確答案** | 對照答案自動批 |
| **沒有正確答案** | 直接 AI 依數學正確性批 |

兩者都是 **真正自動**（呼叫 API、填分數／診斷、存註記），不是開網頁手動貼。

## 開始時批閱方式（預設＝Gemini API 自動）

1. （可選）**載入正確答案** → 有就對照，沒有也能直接 AI 批  
2. 選擇批閱方式：
   - **請 Gemini 自動批閱（API＝真正自動）** ← **預設／建議**  
   - **請 Gemini 自動手寫加強（API）** ← 字跡差時用  
   - **請 Gemini 網頁…（要手動貼）** ← 只開網頁，**不會自動批**  
   - Cursor／自己對照：備用

### 用 Gemini 自動批（免手動貼檔｜建議試發座號 00）

1. （建議）載入正確答案；沒有也可直接批  
2. 到 https://aistudio.google.com/apikey 建立 **API key**（≠ 網頁 Gemini Pro 訂閱）  
3. 習作批改 → **Gemini金鑰** → 貼上儲存  
4. 按鈕：
   - **Gemini自動批** → 批目前這份（有答案對照／無答案直接 AI）  
   - **連續自動批** → 未批學生依序全自動並存檔  
5. 模型預設 **gemini-2.5-flash**

> 舊版 `gemini-2.0-flash` 已於 2026-06-01 下線。「網頁批閱」不是自動。

## 資料夾（桌面\MathGrading）

```
標準答案\     ← 正確答案（可選；有則對照批）
輸入\         ← 學生試卷（一人一檔）
練習回傳\     ← 學生回傳 05-R01.jpg／.pdf
輸出\         ← 00-註記.md、00-Gemini回覆.md、批閱 PDF
```

## 安裝

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git pull origin master
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-apps.ps1
```

桌面捷徑：**習作批改.vbs**／**.cmd**

## 與習作台／跨裝置同步

- **同步程度→習作台**：把輸出註記的程度寫入 `桌面\習作台資料\班級狀態.json`
- **匯出批改進度JSON**：產生手機／另一台可匯入的 `習作批改進度.json`
- 完整流程見 `README-sync.md`
