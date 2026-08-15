#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate per-student grading note PDF; optionally append after original exam PDF."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, PageBreak


def find_cjk_font() -> str | None:
    candidates = [
        Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/truetype/arphic/uming.ttc"),
        Path("C:/Windows/Fonts/msjh.ttc"),
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/mingliu.ttc"),
        Path("C:/Windows/Fonts/kaiu.ttf"),
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return None


def register_font() -> str:
    path = find_cjk_font()
    if path:
        try:
            pdfmetrics.registerFont(TTFont("CJK", path, subfontIndex=0))
            return "CJK"
        except Exception:
            try:
                pdfmetrics.registerFont(TTFont("CJK", path))
                return "CJK"
            except Exception:
                pass
    return "Helvetica"


def md_to_flowables(text: str, font_name: str):
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontName=font_name,
        fontSize=16,
        leading=22,
        spaceAfter=10,
    )
    h2 = ParagraphStyle(
        "H2",
        parent=styles["Heading2"],
        fontName=font_name,
        fontSize=13,
        leading=18,
        spaceBefore=10,
        spaceAfter=6,
    )
    body = ParagraphStyle(
        "B",
        parent=styles["Normal"],
        fontName=font_name,
        fontSize=11,
        leading=16,
    )
    small = ParagraphStyle(
        "S",
        parent=body,
        fontSize=9,
        leading=13,
        textColor="gray",
    )

    story = []
    story.append(Paragraph("批閱註記（初核｜人工終核前）", title))
    story.append(
        Paragraph(
            "原則：接受合理等價解法。✓ 可快速打勾；? 存疑待老師確認／重謄。練習解答另頁，做完題再看。",
            small,
        )
    )
    story.append(Spacer(1, 0.3 * cm))

    for raw in text.splitlines():
        line = raw.rstrip()
        if not line:
            story.append(Spacer(1, 0.15 * cm))
            continue
        # 解答與題目分頁：解答一律從新頁開始
        if (
            line.startswith("---")
            or line.startswith("#### 解答")
            or line.startswith("### 解答")
            or line.startswith("## 解答")
            or ("解答（全部題目完成後" in line)
            or line.startswith("#### 解答（")
        ):
            story.append(PageBreak())
            if line.startswith("---"):
                continue
        if line.startswith("# "):
            story.append(Paragraph(_esc(line[2:]), title))
        elif line.startswith("## "):
            story.append(Paragraph(_esc(line[3:]), h2))
        elif line.startswith("### ") or line.startswith("#### "):
            story.append(Paragraph(_esc(line.lstrip("#").strip()), h2))
        elif line.startswith("- "):
            story.append(Paragraph("• " + _esc(line[2:]), body))
        else:
            story.append(Paragraph(_esc(line), body))
    return story


def _esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def split_practice_questions_answers(md_text: str) -> tuple[str, str]:
    """Split practice block into questions-only and answers-only."""
    if "## 依程度自學／補救練習" in md_text:
        block = md_text.split("## 依程度自學／補救練習", 1)[1]
        if "\n## " in block:
            block = block.split("\n## ", 1)[0]
    elif "## 需再練習" in md_text:
        block = md_text.split("## 需再練習", 1)[1]
        if "\n## " in block:
            block = block.split("\n## ", 1)[0]
    else:
        return "", ""

    # Prefer explicit answer heading
    for marker in (
        "\n#### 解答",
        "\n### 解答",
        "\n## 解答",
        "\n---\n",
    ):
        if marker in block:
            q, a = block.split(marker, 1)
            if marker.strip().startswith("---"):
                a = a.lstrip()
            else:
                a = marker.strip() + a
            return q.strip(), a.strip()
    return block.strip(), ""


def write_simple_pdf(title: str, body: str, pdf_path: Path) -> None:
    font = register_font()
    md = f"# {title}\n\n{body}\n"
    # reuse flowables but without double title noise: feed as md
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.6 * cm,
        bottomMargin=1.6 * cm,
    )
    doc.build(md_to_flowables(md, font))


def write_note_pdf(md_path: Path, pdf_path: Path) -> None:
    font = register_font()
    text = md_path.read_text(encoding="utf-8")
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.6 * cm,
        bottomMargin=1.6 * cm,
    )
    doc.build(md_to_flowables(text, font))

    # Also emit student handout: questions PDF + answers PDF (separate files)
    sid = md_path.name.replace("-註記.md", "")
    q, a = split_practice_questions_answers(text)
    out_dir = md_path.parent
    if q:
        write_simple_pdf(
            f"座號 {sid}｜自學練習題（先做完再看解答）",
            q,
            out_dir / f"{sid}-練習題.pdf",
        )
    if a:
        write_simple_pdf(
            f"座號 {sid}｜練習解答（全部題目完成後再看）",
            a,
            out_dir / f"{sid}-練習解答.pdf",
        )


def merge_original_then_note(original: Path, note_pdf: Path, out_pdf: Path) -> None:
    writer = PdfWriter()
    if original.exists() and original.suffix.lower() == ".pdf":
        reader = PdfReader(str(original))
        for page in reader.pages:
            writer.add_page(page)
    note = PdfReader(str(note_pdf))
    for page in note.pages:
        writer.add_page(page)
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    with out_pdf.open("wb") as f:
        writer.write(f)


def parse_unclear_from_md(md_text: str, student_id: str, source: str) -> list[dict]:
    """Extract lines containing ? or 存疑 as unclear items."""
    items = []
    section = ""
    if "## 題號註記" in md_text:
        section = md_text.split("## 題號註記", 1)[1]
        if "## " in section:
            section = section.split("## ", 1)[0]
    for line in section.splitlines():
        line = line.strip()
        if not line:
            continue
        if ("?" in line) or ("？" in line) or ("存疑" in line):
            m = re.match(r"^(\d+)\s*", line)
            q = m.group(1) if m else ""
            items.append(
                {
                    "studentId": student_id,
                    "source": source,
                    "question": q,
                    "note": line.lstrip("- ").strip(),
                }
            )
    return items


def build_unclear_list(out_dir: Path) -> Path:
    rows = ["座號,來源檔,題號,存疑說明,建議老師處理"]
    md_lines = [
        "# 全班存疑清單（初核後｜待人工輔助）",
        "",
        "全班試卷檢閱後，下列項目需要老師辨認學生寫了什麼，或提供重謄掃描 PDF。",
        "",
        "處理方式：",
        "1. 看懂後：在 `認知輸入\\座號-Qn.txt` 寫入你確認的內容",
        "2. 或把重謄掃描放到 `重謄補充\\座號-Qn.pdf`（或 `座號-重謄.pdf`）",
        "3. 再跑一次補註／重產 PDF",
        "",
    ]
    for md in sorted(out_dir.glob("*-註記.md")):
        sid = md.name.replace("-註記.md", "")
        text = md.read_text(encoding="utf-8")
        source = ""
        m = re.search(r"來源檔[：:]\s*(.+)", text)
        if m:
            source = m.group(1).strip()
        unclear = parse_unclear_from_md(text, sid, source)
        for u in unclear:
            rows.append(
                f"{u['studentId']},{u['source']},{u['question']},{u['note'].replace(',', '，')},認知輸入或重謄PDF"
            )
            md_lines.append(
                f"- **座號 {u['studentId']}**｜題 {u['question'] or '？'}｜{u['note']}｜來源 `{u['source']}`"
            )
    if len(rows) == 1:
        md_lines.append("（目前沒有標 ?／存疑 的項目）")

    csv_path = out_dir / "全班存疑清單.csv"
    md_path = out_dir / "全班存疑清單.md"
    csv_path.write_text("\n".join(rows) + "\n", encoding="utf-8-sig")
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    return md_path


def apply_clarifications(work_dir: Path) -> int:
    """Append teacher clarifications / re-transcript notes into student md files."""
    out_dir = work_dir / "輸出"
    cog_dir = work_dir / "認知輸入"
    rescan_dir = work_dir / "重謄補充"
    cog_dir.mkdir(parents=True, exist_ok=True)
    rescan_dir.mkdir(parents=True, exist_ok=True)
    updated = 0

    clar_map: dict[str, list[str]] = {}

    for p in cog_dir.glob("*.txt"):
        # 05-Q3.txt or 05.txt
        stem = p.stem
        sid = stem.split("-")[0]
        body = p.read_text(encoding="utf-8").strip()
        clar_map.setdefault(sid, []).append(f"- 認知輸入（{p.name}）：{body}")

    for p in rescan_dir.glob("*.pdf"):
        stem = p.stem
        sid = stem.split("-")[0]
        clar_map.setdefault(sid, []).append(f"- 重謄掃描：`重謄補充/{p.name}`")

    for sid, bullets in clar_map.items():
        md = out_dir / f"{sid}-註記.md"
        if not md.exists():
            continue
        text = md.read_text(encoding="utf-8")
        block = "## 老師輔助辨認／重謄\n" + "\n".join(bullets) + "\n"
        if "## 老師輔助辨認／重謄" in text:
            # replace section
            pre, rest = text.split("## 老師輔助辨認／重謄", 1)
            if "## " in rest[1:]:
                _, after = rest.split("## ", 1)
                text = pre + block + "\n## " + after
            else:
                text = pre + block
        else:
            text = text.rstrip() + "\n\n" + block + "\n"
        # soften unclear marks if clarification provided
        text = text.replace("總評：存疑多", "總評：已補認知／重謄（待終核）")
        md.write_text(text, encoding="utf-8")
        updated += 1
    return updated


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work-dir", required=True, help="MathGrading work folder")
    ap.add_argument("--student", default="", help="student id e.g. 05; empty = all")
    ap.add_argument("--merge-original", action="store_true", help="original PDF + note pages")
    ap.add_argument("--unclear-list", action="store_true", help="build class unclear list")
    ap.add_argument("--apply-clarifications", action="store_true")
    args = ap.parse_args()

    work = Path(args.work_dir)
    out_dir = work / "輸出"
    in_dir = work / "輸入"
    out_dir.mkdir(parents=True, exist_ok=True)
    (work / "認知輸入").mkdir(parents=True, exist_ok=True)
    (work / "重謄補充").mkdir(parents=True, exist_ok=True)

    if args.apply_clarifications:
        n = apply_clarifications(work)
        print(f"applied clarifications to {n} students")

    if args.unclear_list:
        p = build_unclear_list(out_dir)
        print(f"unclear list: {p}")

    md_files = sorted(out_dir.glob("*-註記.md"))
    if args.student:
        md_files = [p for p in md_files if p.name.startswith(args.student + "-")]

    for md in md_files:
        sid = md.name.replace("-註記.md", "")
        note_pdf = out_dir / f"{sid}-批閱註記.pdf"
        write_note_pdf(md, note_pdf)
        print(f"note pdf: {note_pdf}")

        if args.merge_original:
            # find original
            original = None
            for ext in (".pdf", ".PDF", ".jpg", ".jpeg", ".png"):
                cand = in_dir / f"{sid}{ext}"
                if cand.exists():
                    original = cand
                    break
            if original is None:
                # fuzzy: starts with sid
                hits = list(in_dir.glob(f"{sid}.*")) + list(in_dir.glob(f"{int(sid):d}.*"))
                original = hits[0] if hits else None
            merged = out_dir / f"{sid}-試卷含批閱.pdf"
            if original and original.suffix.lower() == ".pdf":
                merge_original_then_note(original, note_pdf, merged)
                print(f"merged: {merged}")
            else:
                # image-only: just copy note pdf as final deliverable name
                merged.write_bytes(note_pdf.read_bytes())
                print(f"merged(note-only): {merged}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
