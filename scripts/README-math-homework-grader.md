# 數學習作／試卷批改：一人一檔、一檔一檔來

## 開始時兩種模式

1. **載入正確答案**（可多檔）→ 供對照  
2. 選擇批閱方式：
   - **自己對照批**：開啟答案＋學生卷，你填 ✓✗?  
   - **請 Cursor 直接批閱**：複製提示、開啟檔案，到 Cursor 貼上並附檔；結果貼回右側後再「輸出此生PDF」

然後仍是 **一人一檔、一檔一檔**：開始批此生 → 輸出PDF → 下一位未批。

全班經 Cursor＋老師反覆確認後，按 **全班學習總表** 產出給導師／家長：
- `全班學習狀況總表.pdf` / `.md` / `.csv`
- 含程度分布、常見課題、需關注座號、逐座號一覽（以座號、不含姓名）

每位輸出 PDF／註記末段固定含：
- **個別診斷結果**（弱點、是否跟上）
- **程度**：跟上／略落後／明顯落後／需補先備
- **練習依程度**：
  - **跟上（好的學生再提升）**：少鞏固 → 靈活 → **再提升挑戰（必做）** → 超前伸展（選做）；禁止只改數字的簡單重複題
  - 略落後／明顯落後／需補先備：對應錯題或降階補洞
- **練習發放（省紙）**：
  - **有通訊裝置** → `數位練習\`（手機可開的 HTML／TXT、LINE 文案、`index.html`）
  - **沒有裝置** → 在 `列印專用\需列印座號.txt` 填座號 → 按「無裝置列印包」只印那些人
- 老師批閱 PDF 仍在 `輸出\`；**不要整班列印練習題**

## 資料夾

```
Desktop\MathGrading\
  標準答案\
  輸入\           ← 05.pdf、06.pdf（一人一檔）
  輸出\           ← 05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf
  數位練習\       ← 05-練習題.html、解答、LINE訊息、index.html（優先發放）
  列印專用\       ← 需列印座號.txt ＋ 僅無裝置者之練習 PDF
  認知輸入\       ← 老師確認潦草字
  重謄補充\       ← 重謄後再掃的 PDF
```

## 安裝

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git fetch origin cursor/math-homework-grader-433c
git checkout origin/cursor/math-homework-grader-433c -- `
  scripts/math-homework-grader-app.ps1 `
  scripts/math_grade_make_note_pdf.py `
  scripts/install-math-homework-grader.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-math-homework-grader.ps1
pip install pypdf reportlab
```

雙擊桌面 **習作批改.vbs**。
