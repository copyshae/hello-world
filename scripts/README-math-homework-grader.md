# 數學習作／試卷批改：一人一檔、一檔一檔來

## 開始時兩種模式

1. **載入正確答案**（可多檔）→ 供對照  
2. 選擇批閱方式：
   - **自己對照批**：開啟答案＋學生卷，你填 ✓✗?  
   - **請 Cursor 直接批閱**：複製提示、開啟檔案，到 Cursor 貼上並附檔；結果貼回右側後再「輸出此生PDF」

然後仍是 **一人一檔、一檔一檔**：開始批此生 → 輸出PDF → 下一位未批。

每位輸出 PDF／註記末段固定含：
- **個別診斷結果**（弱點、是否跟上）
- **程度**：跟上／略落後／明顯落後／需補先備
- **依程度自學／補救練習**（題目＋解答；明顯落後採降階少而精）

## 資料夾

```
Desktop\MathGrading\
  標準答案\
  輸入\           ← 05.pdf、06.pdf（一人一檔）
  輸出\           ← 05-註記.md、05-批閱註記.pdf、05-試卷含批閱.pdf
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
