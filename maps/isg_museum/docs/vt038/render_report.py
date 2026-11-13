"""Render the editable VT-038 report as an A4 PDF with embedded Unicode fonts."""

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from urllib.parse import quote
from xml.sax.saxutils import escape, quoteattr

from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Spacer, Table, TableStyle

from report_content import PAGES, REPOSITORY, TEST_FILES, TITLE


DOCS = Path(__file__).resolve().parent
REPO_ROOT = DOCS.parents[3]
INK = HexColor('#18283B')
ACCENT = HexColor('#126459')
MUTED = HexColor('#475B6B')
RULE = HexColor('#DAE4E8')
PANEL = HexColor('#EEF6F4')
PAGE_WIDTH, PAGE_HEIGHT = A4
MARGIN = 40
WIDTH = PAGE_WIDTH - 2 * MARGIN
FOOTER = 53
SECTION_HEADING_SIZE = 21


def register_fonts(folder):
    for family, filename in (
        ('Report', 'arial.ttf'), ('Report-Bold', 'arialbd.ttf'),
        ('Report-Italic', 'ariali.ttf'), ('Report-BoldItalic', 'arialbi.ttf'),
    ):
        pdfmetrics.registerFont(TTFont(family, str(folder / filename)))
    pdfmetrics.registerFontFamily('Report', normal='Report', bold='Report-Bold',
                                  italic='Report-Italic', boldItalic='Report-BoldItalic')


def integrated_status():
    status_file = DOCS / 'evidence' / 'integrated-writable.json'
    if not status_file.is_file():
        raise RuntimeError('Missing integrated-writable.json. Wait for the integrated run to finish.')
    status = json.loads(status_file.read_text(encoding='utf-8'))
    stdout = status_file.with_suffix('.stdout.log').read_text(encoding='utf-8', errors='replace')
    if status.get('timed_out'):
        return (f'Windows cục bộ: hết thời gian chờ {status["timeout_seconds"]} giây.',
                'Bộ tích hợp chưa hoàn tất. Xem log kết thúc và phân loại trong README. Chưa chạy CI Linux/WSL.')
    if status['exit_code'] == 0 and 'All tests passed' in stdout:
        return ('Windows cục bộ, APPDATA riêng: exit 0, runner in “All tests passed”.',
                'Stderr còn chẩn đoán kho chứng chỉ Windows và cảnh báo guard/navigation. Chưa chạy CI Linux/WSL.')
    return (f'Windows cục bộ, APPDATA riêng: exit {status["exit_code"]}.',
            'Xem log kết thúc và phân loại trong README. Chưa chạy CI Linux/WSL.')


def style(name, size, *, font='Report', color=INK, leading=None, **kwargs):
    return ParagraphStyle(name, fontName=font, fontSize=size, leading=leading or 1.33 * size,
                          textColor=color, allowWidows=0, allowOrphans=0, **kwargs)


def paragraph(value, kind, scale):
    if kind == 'section':
        return Paragraph(value, style('section-heading', SECTION_HEADING_SIZE,
                                      font='Report-Bold', leading=SECTION_HEADING_SIZE + 3))
    sizes = {'p': 10.6, 'note': 10.2, 'h': 12.2, 'code': 9.8, 'link': 9.5}
    fonts = {'h': 'Report-Bold', 'note': 'Report-Bold'}
    colors = {'h': ACCENT, 'note': INK, 'link': ACCENT}
    return Paragraph(value, style(kind, sizes[kind] * scale, font=fonts.get(kind, 'Report'),
                                  color=colors.get(kind, INK)))


def make_table(headers, rows, widths, scale):
    widths = [WIDTH * w / sum(widths) for w in widths] if widths else [WIDTH / len(headers)] * len(headers)
    head = style('table-heading', 9.4 * scale, font='Report-Bold', color=white, leading=11.5 * scale)
    cell = style('table-cell', 9.35 * scale, leading=12.15 * scale)
    data = [[Paragraph(str(v), head) for v in headers]]
    data.extend([Paragraph(str(v), cell) for v in row] for row in rows)
    table = Table(data, colWidths=widths, hAlign='LEFT')
    table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BACKGROUND', (0, 0), (-1, 0), INK),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, PANEL]),
        ('LINEBELOW', (0, 0), (-1, -1), 0.4, RULE),
        ('LEFTPADDING', (0, 0), (-1, -1), 6), ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 4.6 * scale),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4.6 * scale),
    ]))
    return table


def hyperlink(label, target):
    return f'<link href={quoteattr(target)}><u>{escape(label)}</u></link>'


def evidence_path(target):
    relative = PurePosixPath(target)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError(f'Expected a path relative to the report source: {target}')
    local = DOCS.joinpath(*relative.parts)
    if not local.is_file():
        raise FileNotFoundError(local)
    return local.relative_to(REPO_ROOT).as_posix()


def published_revision(branch):
    ref = f'refs/heads/{branch}'
    subprocess.run(['git', 'check-ref-format', ref], cwd=REPO_ROOT, check=True)
    result = subprocess.run(['git', 'ls-remote', '--exit-code', '--refs', REPOSITORY + '.git', ref],
                            cwd=REPO_ROOT, check=True, capture_output=True, text=True, timeout=45)
    commit, remote_ref = result.stdout.strip().split('\t')
    if remote_ref != ref or not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise ValueError(f'GitHub did not return the exact requested branch: {ref}')
    files = set(TEST_FILES)
    for _, _, blocks in PAGES:
        for block in blocks:
            if block[0] == 'links':
                files.update(evidence_path(target) for _, target in block[1])
    for path in sorted(files):
        object_id = f'{commit}:{path}'
        kind = subprocess.check_output(['git', 'cat-file', '-t', object_id], cwd=REPO_ROOT, text=True).strip()
        if kind != 'blob':
            raise ValueError(f'Expected a file in the published commit: {path}')
        # Compare the Git-normalized worktree file with the immutable tree entry.
        blob = subprocess.check_output(['git', 'rev-parse', object_id], cwd=REPO_ROOT, text=True).strip()
        local = subprocess.check_output(['git', 'hash-object', f'--path={path}', '--', path],
                                        cwd=REPO_ROOT, text=True).strip()
        if local != blob:
            raise ValueError(f'Worktree file differs from the published commit: {path}')
    return commit


def evidence_link(label, target, commit):
    path = evidence_path(target)
    if commit:
        return hyperlink(label, f'{REPOSITORY}/blob/{commit}/{quote(path)}')
    return f'{escape(label)} <font color="#475B6B">({escape(target)})</font>'


def make_blocks(blocks, scale, replacements, commit):
    flow = []
    for kind, *values in blocks:
        if kind == 'table':
            widths, data = values
            headers, *rows = data
            rows = [[replace_tokens(str(cell), replacements) for cell in row] for row in rows]
            flow.extend((make_table(headers, rows, widths, scale), Spacer(1, 10 * scale)))
        elif kind == 'links':
            pairs = values[0]
            links = ' &nbsp;·&nbsp; '.join(evidence_link(label, target, commit) for label, target in pairs)
            flow.extend((paragraph(links, 'link', scale), Spacer(1, 7 * scale)))
        elif kind in {'p', 'h', 'section', 'note', 'code'}:
            content = replace_tokens(values[0], replacements)
            if kind == 'code':
                content = escape(content).replace('\n', '<br/>')
            item = paragraph(content, kind, scale)
            if kind in {'note', 'code'}:
                item = Table([[item]], colWidths=[WIDTH], style=[
                    ('BACKGROUND', (0, 0), (-1, -1), PANEL),
                    ('LINEBEFORE', (0, 0), (0, 0), 2, ACCENT),
                    ('LEFTPADDING', (0, 0), (0, 0), 11), ('RIGHTPADDING', (0, 0), (0, 0), 10),
                    ('TOPPADDING', (0, 0), (0, 0), 8), ('BOTTOMPADDING', (0, 0), (0, 0), 8),
                ])
            flow.extend((item, Spacer(1, (4.5 if kind == 'h' else 8) * scale)))
        else:
            raise ValueError(f'Unknown block kind {kind!r}')
    return flow


def replace_tokens(value, replacements):
    for name, text in replacements.items():
        value = value.replace('{{' + name + '}}', text)
    return value


def draw_header(pdf, index, title, subtitle, main_pages, draft):
    pdf.setFillColor(ACCENT)
    pdf.rect(0, PAGE_HEIGHT - 7, PAGE_WIDTH, 7, fill=1, stroke=0)
    pdf.setFont('Report-Bold', 9.6)
    pdf.drawString(MARGIN, PAGE_HEIGHT - 39, 'BT3 / VT-038')
    if draft:
        pdf.drawRightString(PAGE_WIDTH - MARGIN, PAGE_HEIGHT - 39, 'BẢN NHÁP CHỜ DUYỆT')
    y = PAGE_HEIGHT - 53
    heading_size = 22 if index == 1 else SECTION_HEADING_SIZE
    heading = Paragraph(title, style('page-heading', heading_size, font='Report-Bold', leading=heading_size + 3))
    _, height = heading.wrap(WIDTH, y)
    heading.drawOn(pdf, MARGIN, y - height)
    y -= height + 6
    sub = Paragraph(subtitle, style('subtitle', 10.5, color=MUTED))
    _, height = sub.wrap(WIDTH, y)
    sub.drawOn(pdf, MARGIN, y - height)
    y -= height + 10
    pdf.setStrokeColor(RULE)
    pdf.line(MARGIN, y, PAGE_WIDTH - MARGIN, y)
    pdf.line(MARGIN, 45, PAGE_WIDTH - MARGIN, 45)
    pdf.setFont('Report', 9)
    pdf.setFillColor(MUTED)
    pdf.drawString(MARGIN, 29, 'Hoàng Gia Mạnh · 23001903 · SE2026-T10')
    page = f'{index}/{main_pages} · Nội dung chính' if index <= main_pages else f'A{index - main_pages} · Phụ lục'
    pdf.drawRightString(PAGE_WIDTH - MARGIN, 29, page)
    return y - 12


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--fonts', type=Path, default=Path('C:/Windows/Fonts'))
    parser.add_argument('--final', action='store_true', help='Export only after the student has approved the report.')
    parser.add_argument('--published-branch', help='Existing GitHub branch to verify for final export.')
    args = parser.parse_args()
    if args.final != bool(args.published_branch):
        parser.error('--final and --published-branch must be used together after approval and publication.')
    commit = published_revision(args.published_branch) if args.final else None
    register_fonts(args.fonts)
    result, limit = integrated_status()
    submission_link = 'Chưa xuất bản. Link GitHub branch hoặc PR chưa hoàn tất.'
    submission_ref = 'Chưa có'
    trace_status = 'Chưa có commit của bài tập hoặc PR. Baseline xác định phiên bản trước patch.'
    if commit:
        branch_url = f'{REPOSITORY}/tree/{quote(args.published_branch)}'
        submission_link = hyperlink(args.published_branch, branch_url)
        submission_ref = hyperlink(commit[:12], f'{REPOSITORY}/commit/{commit}')
        trace_status = f'Commit đã xác minh trên GitHub: {commit}.'
    replacements = {
        'INTEGRATED_RESULT': escape(result), 'INTEGRATED_LIMIT': escape(limit),
        'REPOSITORY_LINK': hyperlink(REPOSITORY, REPOSITORY), 'SUBMISSION_LINK': submission_link,
        'SUBMISSION_REF': submission_ref, 'TRACE_STATUS': trace_status,
        'REPORT_REVIEW_STATUS': ('Sinh viên đã duyệt báo cáo và cho phép commit/push nhánh cá nhân; không merge.'
                                 if args.final else 'Bản báo cáo đang chờ sinh viên duyệt.'),
    }
    main_pages = next((i for i, (title, _, _) in enumerate(PAGES) if 'phụ lục' in title.casefold()), len(PAGES))
    if main_pages > 8 or main_pages == len(PAGES):
        raise RuntimeError('Expected at most eight main pages followed by an appendix.')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(args.out), pagesize=A4, pageCompression=1)
    pdf.setTitle(TITLE)
    pdf.setAuthor('Hoàng Gia Mạnh')
    pdf.setCreator('BT3 VT-038 report source')
    pdf.setSubject('Bài tập cá nhân 3' if args.final else 'Bài tập cá nhân 3, bản nháp chờ sinh viên duyệt')
    for index, (title, subtitle, blocks) in enumerate(PAGES, 1):
        y = draw_header(pdf, index, title, subtitle, main_pages, draft=not args.final)
        for scale in (1.0, 0.97, 0.94, 0.91, 0.88):
            flow = make_blocks(blocks, scale, replacements, commit)
            heights = [item.wrap(WIDTH, PAGE_HEIGHT)[1] for item in flow]
            if sum(heights) <= y - FOOTER:
                break
        else:
            raise RuntimeError(f'Page {index} overflows by {sum(heights) - (y - FOOTER):.1f} pt')
        for item, height in zip(flow, heights):
            y -= height
            item.drawOn(pdf, MARGIN, y)
        print(f'Page {index}: scale={scale:.2f}, lowest content y={y:.1f}pt')
        pdf.showPage()
    pdf.save()
    print(f'{main_pages} main pages, {len(PAGES) - main_pages} appendix pages: {args.out}')


if __name__ == '__main__':
    main()
