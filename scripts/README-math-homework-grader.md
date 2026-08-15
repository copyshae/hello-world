# 數學習作批改（一人一檔 → 一人一註記）

## 流程

```
Desktop\MathGrading\
  標準答案\     ← 放正確解答
  輸入\         ← 每位學生一個 PDF 或圖檔（建議 05.pdf）
  輸出\         ← 批完自動／手動輸出
    05-註記.md
    06-註記.md
    全班總表.csv
```

1. 全班掃描檔（每人一檔）放入 **輸入**
2. 標準答案放入 **標準答案**
3. 雙擊桌面 **習作批改.vbs**
4. 左側選人 → 開啟此生檔案 → 填題號 ✓✗? → **輸出此生註記**
5. 需要 AI 初核：按 **複製給 Cursor 初核提示**，到 Cursor 貼上並附檔

## 安裝

```powershell
cd $env:USERPROFILE\Desktop\hello-world
git fetch origin cursor/math-homework-grader-433c
git checkout origin/cursor/math-homework-grader-433c -- `
  scripts/math-homework-grader-app.ps1 `
  scripts/install-math-homework-grader.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-math-homework-grader.ps1
```

## 原則

- 接受其他合理等價解法
- ✓ 可快速打勾；? 留給人工終核
- 可再為需補救者加「個別建議／練習與解答」
