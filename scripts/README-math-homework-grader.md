# 數學習作／試卷批改：一人一檔、一檔一檔來

## 你選的流程

1. 每位學生 **一個** 試卷檔（PDF 或圖）放進 `輸入\`
2. 程式裡 **一次只批一位**：開啟 → 填 ✓✗? → **輸出此生PDF**
3. 按 **下一位未批** 繼續
4. 全班批完 → **產生全班存疑清單**
5. 看不懂的：老師寫 `認知輸入\05-Q3.txt` 或放 `重謄補充\05-Q3.pdf`
6. **套用認知／重謄並重產PDF**

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
