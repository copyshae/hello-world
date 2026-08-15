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
- **練習發放（省紙，工具可複選）**：
  - **快**：發＝LINE 班級群組；回＝LINE 個別傳老師（勿全班圖塞群組）
  - **整齊**：Classroom 或 雲端「發放／回傳」兩夾
  - 程式內「工具選擇」可勾選／改偏好，日後再抉擇
  - 沒裝置 → `列印專用\需列印座號.txt` →「無裝置列印包」
- **練習回傳循環**：`練習回傳\` 收 PDF／圖 → 針對問題點回饋 → 調題再練 → `練習歷程\` 看分數進步至達標

## 資料夾

```
Desktop\MathGrading\
  標準答案\
  輸入\           ← 05.pdf、06.pdf（一人一檔）
  輸出\           ← 05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf
  數位練習\       ← 手機 HTML／TXT、LINE訊息、歷程頁
  練習回傳\       ← 學生回傳 05-R01.jpg／.pdf（供抓取批閱）
  練習歷程\       ← 分數進步、每次回饋、待批清單
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
