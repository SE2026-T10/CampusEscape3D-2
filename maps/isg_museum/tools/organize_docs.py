"""Reversible, stdlib-only museum documentation migration (run from any cwd).

Historical JSON/logs/media are immutable. Markdown links are resolved from their
OLD location before either endpoint moves; only executable resource paths change
in source/snapshots. --plan never moves files; --verify never writes files.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[3]
MAP = ROOT / "maps/isg_museum"
DOCS = MAP / "docs"
CLEANUP = DOCS / "reports/docs-cleanup-v1"
MANIFEST = CLEANUP / "data/path-migration.json"
DESIGNS = {"concept-v1", "concept-v2", "concept-v3", "asset-design-preview-v1", "asset-design-preview-v2"}
REPORTS = {"editing-mode", "environment-art-v1", "environment-art-v1_1", "guard-art-v1", "npc-art-v1", "courtyard-palette-v1", "courtyard-palette-stage-b", "visual-feedback-2026-11-15", "post-b-fixes-v1"}
GROUPS = {"images", "videos", "logs", "data", "snapshots", "reproduce"}
MEDIA = {".png", ".jpg", ".jpeg", ".svg", ".webp", ".bmp", ".gif"}
VIDEO = {".avi", ".mp4", ".webm", ".mov", ".mkv", ".ogv"}
SCRIPTS = {".gd", ".ps1", ".py"}
MD_LINK = re.compile(r'(?P<open>!?\[[^\]\n]*\]\()(?P<target><[^>\n]+>|[^\s)]+)(?P<close>(?:\s+"[^"\n]*")?\))')
MD_REF = re.compile(r'(?m)^(?P<open>\s*\[[^\]\n]+\]:\s*)(?P<target><[^>\n]+>|\S+)(?P<close>.*)$')


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def safe(path: Path, base: Path = ROOT) -> Path:
    resolved = path.resolve()
    resolved.relative_to(base.resolve())
    return resolved


def write_json(path: Path, value: object) -> None:
    safe(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name+".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    temporary.replace(path)


def report_destination(path: Path) -> tuple[Path, str]:
    parts = list(path.parts)
    report = parts.pop(0)
    # Accept an already normalized report without nesting reports/reports.
    base = DOCS / "reports" / report
    if parts and parts[0] == "revisions":
        base = base / parts.pop(0) / parts.pop(0)
    elif parts and (parts[0].startswith("revision-") or parts[0] == "iterations"):
        base = base / "revisions" / parts.pop(0)
    if parts and parts[0] in GROUPS:
        return base.joinpath(*parts), parts[0]
    # Baseline bundles are indivisible: textures/config stay beside their scene.
    for index, part in enumerate(parts[:-1]):
        if "source" in part and ("before" in part or "baseline" in part) or part in {"baseline", "a1-reference"}:
            return base / "snapshots" / Path(*parts), "snapshot"
    leaf = Path(parts[-1])
    if len(parts) == 1 and leaf.name in {"REPORT.md", "VALIDATION.json"}:
        return base / leaf, "main-report" if leaf.suffix == ".md" else "historical-validation"
    if leaf.name == "README.md" and base.name == "iterations":
        return base / "REPORT.md", "revision-report"
    suffix = leaf.suffix.lower()
    if suffix in MEDIA:
        group = "images"
    elif suffix in VIDEO:
        group = "videos"
    elif suffix == ".log" or leaf.name in {"baseline-git.txt", "source-audit.txt"}:
        group = "logs"
    elif suffix in SCRIPTS or leaf.name.endswith(".gd.uid"):
        group = "reproduce"
    elif suffix in {".tscn", ".tres", ".scn", ".res"}:
        group = "snapshots"
    elif suffix in {".json", ".csv", ".txt", ".sha256", ".md"}:
        group = "data"
    else:
        raise ValueError(f"Unclassified report artifact: {path}")
    return base / group / Path(*parts), group


def destination(path: Path) -> tuple[Path, str]:
    rel = path.relative_to(DOCS)
    head = rel.parts[0]
    if head in {".gdignore", ".gitkeep", "README.md"}:
        return path, "documentation-root"
    if head in {"design", "guides"}:
        return path, head
    if head in DESIGNS:
        return DOCS / "design" / rel, "design"
    if head.startswith("step-"):
        return DOCS / "guides/steps" / rel, "development-guide"
    if head == "reports":
        return report_destination(Path(*rel.parts[1:]))
    if head in REPORTS:
        return report_destination(rel)
    raise ValueError(f"Unclassified docs file: {rel}")


def plan_migration(map_root: Path = MAP) -> list[dict]:
    if map_root.resolve() != MAP.resolve():
        raise ValueError("This migration is scoped to maps/isg_museum")
    operations = []
    for path in sorted(DOCS.rglob("*")):
        if not path.is_file() or path.is_relative_to(CLEANUP):
            continue
        safe(path, DOCS)
        if path.is_symlink():
            raise ValueError(f"Symlink needs an explicit migration decision: {path}")
        target, category = destination(path)
        operations.append(dict(old_path=relative(path), new_path=relative(target), size_before=path.stat().st_size,
                               sha256_before=sha(path), sha256_after=None, category=category,
                               content_changed=False, change_reason="Relocate by artifact role; preserve bytes" if target != path else "Already in canonical location"))
    return operations


def validate_plan(plan: list[dict], applied: bool = False) -> list[str]:
    errors = []
    targets = {}
    for row in plan:
        old, new = ROOT / row["old_path"], ROOT / row["new_path"]
        try:
            safe(old, DOCS)
            safe(new, DOCS)
        except ValueError:
            errors.append(f"Path escapes docs/workspace: {row}")
            continue
        key = str(new.resolve()).casefold()
        if key in targets:
            errors.append(f"Windows destination collision: {row['old_path']} / {targets[key]}")
        targets[key] = row["old_path"]
        source = new if applied else old
        if not source.is_file():
            errors.append(f"Missing file: {source}")
        elif not applied and sha(source) != row["sha256_before"]:
            errors.append(f"Source changed after plan: {source}")
        if not applied and new != old and new.exists():
            errors.append(f"Destination already exists: {new}")
    return errors


def resolve_reference(source_file: Path, target: str) -> Path | None:
    target = unquote(target.strip("<>"))
    if not target or target.startswith("#") or re.match(r"^(?:https?|mailto|data|plugin|app|uid|skill)://", target):
        return None
    target = target.split("#", 1)[0].split("?", 1)[0]
    if target.startswith("res://"):
        return safe(ROOT / target[6:])
    if target.startswith("/D:/"):
        target = target[1:]
    if re.match(r"^[A-Za-z]:[/\\]", target):
        return Path(target).resolve()
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
        return None
    return (source_file.parent / target).resolve()


def directory_mapping(target: Path, mapping: dict[Path, Path]) -> Path | None:
    children = [(old,new) for old,new in mapping.items() if old.is_relative_to(target)]
    if not children:
        return None
    # Folder links in reports normally open a gallery; retain that useful intent.
    media = [(old,new) for old,new in children if old.suffix.lower() in MEDIA]
    candidates = media or children
    return Path(os.path.commonpath([str(new.parent) for _,new in candidates]))


def markdown_links(source: Path, text: str, new_source: Path, mapping: dict[Path, Path]) -> tuple[str, list[str]]:
    changed = []
    fences = [m.span() for m in re.finditer(r"(?ms)^```.*?^```[^\n]*$", text)]
    def rewrite(match):
        if any(a <= match.start() < b for a,b in fences):
            return match.group(0)
        raw = match["target"]
        target = resolve_reference(source, raw)
        if target is None:
            return match.group(0)
        new_target = mapping.get(target)
        if new_target is None and target.is_relative_to(DOCS) and target.is_dir():
            new_target = directory_mapping(target, mapping)
        if source == new_source and new_target is None:
            return match.group(0)
        new_target = new_target or target
        fragment = "#"+raw.strip("<>").split("#",1)[1] if "#" in raw else ""
        result = Path(os.path.relpath(new_target, new_source.parent)).as_posix()+fragment
        if " " in result or raw.startswith("<"):
            result = "<"+result+">"
        if result != raw:
            changed.append(raw+" -> "+result)
        return match["open"]+result+match["close"]
    text = MD_LINK.sub(rewrite, text)
    text = MD_REF.sub(rewrite, text)
    return text, changed


def resource_replacements(plan: list[dict]) -> list[tuple[str,str]]:
    pairs = set()
    for row in plan:
        old,new = row["old_path"],row["new_path"]
        if old==new:
            continue
        pairs.add((old,new))
        pairs.add((old.removeprefix("maps/isg_museum/"),new.removeprefix("maps/isg_museum/")))
        if row["category"] == "snapshot":
            old_bundle = re.match(r"(.*?/(?:before-source|baseline-source|baseline|a1-reference))/",old)
            if old_bundle:
                old_base=old_bundle[1]+"/"
                new_base=new[:-(len(old)-len(old_base))]
                pairs.add((old_base.removeprefix("maps/isg_museum/"),new_base.removeprefix("maps/isg_museum/")))
    for name in DESIGNS:
        pairs.add(("docs/"+name+"/","docs/design/"+name+"/"))
    return sorted(pairs, key=lambda pair:len(pair[0]), reverse=True)


def remember_edit(manifest: dict, path: Path, before: bytes, reason: str) -> dict:
    rel = relative(path)
    row = next((r for r in manifest["files"] if r["new_path"]==rel), None)
    if row is None:
        row = next((r for r in manifest["reference_edits"] if r["new_path"]==rel), None)
    if row is None:
        row = dict(old_path=rel,new_path=rel,size_before=len(before),sha256_before=hashlib.sha256(before).hexdigest(),sha256_after=None,category="reference-source",content_changed=True,change_reason=reason)
        manifest["reference_edits"].append(row)
    if "original_bytes_base64" not in row:
        row["original_bytes_base64"] = base64.b64encode(before).decode("ascii")
    row["content_changed"] = True
    if reason not in row["change_reason"]:
        row["change_reason"] += "; "+reason
    return row


def rewrite_references(manifest: dict) -> list[str]:
    mapping = {(ROOT/r["old_path"]).resolve():(ROOT/r["new_path"]).resolve() for r in manifest["files"]}
    pairs = resource_replacements(manifest["files"])
    candidates = [(ROOT/r["old_path"],ROOT/r["new_path"]) for r in manifest["files"]]
    for folder, directories, filenames in os.walk(ROOT):
        directories[:] = [name for name in directories if name not in {".git",".godot",".local",".codex",".agents","node_modules"}]
        for name in filenames:
            path=Path(folder)/name
            if path.suffix==".md" and not path.is_relative_to(DOCS): candidates.append((path,path))
    candidates += [(p,p) for folder in [MAP/"tools",MAP/"tests",MAP/"scripts"] for p in folder.glob("*.gd")]
    candidates += [(MAP/"assets/catalog.json",MAP/"assets/catalog.json")]
    changed_files = []
    for old,path in candidates:
        if path.suffix.lower() not in {".md",".gd",".tscn",".tres",".py",".ps1",".json"}:
            continue
        # JSON contains historical argv/measurements/hashes: only catalog is live navigation.
        if path.suffix == ".json" and path != MAP/"assets/catalog.json":
            continue
        raw = path.read_bytes()
        try:
            text = raw.decode("utf-8-sig")
        except UnicodeDecodeError:
            continue
        edits = []
        if path.suffix == ".md":
            text, edits = markdown_links(old,text,path,mapping)
        elif path.name == "catalog.json":
            def catalog_link(match):
                target = resolve_reference(old,match[1])
                if target not in mapping: return match[0]
                result = Path(os.path.relpath(mapping[target],path.parent)).as_posix()
                edits.append(match[1]+" -> "+result)
                return json.dumps(result)
            text = re.sub(r'"([^"\n]+\.md)"',catalog_link,text)
        elif "docs/" in text:
            for source,target in pairs:
                if source in text:
                    text = text.replace(source,target)
                    edits.append(source+" -> "+target)
        if edits:
            row=remember_edit(manifest,path,raw,"Update resolved Markdown links or executable/snapshot resource paths; preserve historical results")
            row["reference_changes"]=edits
            path.write_bytes(text.encode("utf-8-sig" if raw.startswith(b'\xef\xbb\xbf') else "utf-8"))
            changed_files.append(relative(path))
    return changed_files


def check_markdown(paths: list[Path]) -> list[dict]:
    broken=[]
    for path in paths:
        text=path.read_text(encoding="utf-8-sig")
        fences=[m.span() for m in re.finditer(r"(?ms)^```.*?^```[^\n]*$",text)]
        for pattern in [MD_LINK,MD_REF]:
            for match in pattern.finditer(text):
                if any(a<=match.start()<b for a,b in fences): continue
                target=resolve_reference(path,match['target'])
                if target is not None and not target.exists():
                    broken.append(dict(source=relative(path),target=match['target'],resolved=str(target)))
    return broken


def refresh_hashes(manifest: dict) -> None:
    for row in manifest["files"]+manifest["reference_edits"]:
        row["sha256_after"] = sha(ROOT/row["new_path"])
        row["content_changed"] = row["sha256_before"] != row["sha256_after"]


def verify_migration(manifest: dict) -> list[str]:
    errors=validate_plan(manifest['files'],applied=True)
    for row in manifest['files']+manifest['reference_edits']:
        try:
            path=safe(ROOT/row['new_path'])
            safe(ROOT/row['old_path'])
        except ValueError:
            errors.append('Reference edit escapes workspace: '+row['new_path'])
            continue
        if not path.is_file(): errors.append('Missing migrated file: '+str(path)); continue
        if sha(path)!=row['sha256_after']: errors.append('Hash differs: '+row['new_path'])
        if not row['content_changed'] and row['sha256_before']!=row['sha256_after']: errors.append('Unrecorded content change: '+row['new_path'])
        if row['content_changed'] and ('original_bytes_base64' not in row or not row['change_reason']): errors.append('Missing reversible text edit: '+row['new_path'])
        if row['old_path']!=row['new_path'] and (ROOT/row['old_path']).exists(): errors.append('Old path recreated: '+row['old_path'])
    md=[ROOT/r['new_path'] for r in manifest['files']+manifest['reference_edits'] if r['new_path'].endswith('.md')]
    md += [p for p in [DOCS/'README.md',MAP/'README.md',CLEANUP/'REPORT.md'] if p.is_file() and p not in md]
    errors += ['Broken Markdown link: '+str(item) for item in check_markdown(md)]
    remaining=[r for r in plan_migration() if r['old_path']!=r['new_path']]
    if remaining: errors.append(f'Repeated plan proposes {len(remaining)} further moves')
    return errors


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--plan',action='store_true')
    mode.add_argument('--apply',action='store_true')
    mode.add_argument('--verify',action='store_true')
    parser.add_argument('--manifest',type=Path,default=MANIFEST)
    args=parser.parse_args()
    path=safe(args.manifest)
    if args.plan:
        plan=plan_migration()
        errors=validate_plan(plan)
        if errors: print('\n'.join(errors)); return 1
        if path.exists():
            previous=json.loads(path.read_text(encoding='utf-8'))
            if previous.get('applied'):
                count=sum(r['old_path']!=r['new_path'] for r in plan)
                write_json(CLEANUP/'data/repeat-plan.json',dict(files=len(plan),moves=count))
                print(f'Repeat plan: {len(plan)} files; {count} moves. Original manifest preserved.')
                return 0 if count==0 else 1
            raise ValueError('Existing unapplied manifest retained; review it before replacing the plan')
        manifest=dict(schema_version=1,created_at=dt.datetime.now().astimezone().isoformat(),applied=False,root='maps/isg_museum/docs',files=plan,reference_edits=[])
        write_json(path,manifest)
        print(f'Planned {len(plan)} files, {sum(r["old_path"]!=r["new_path"] for r in plan)} moves, {sum(r["size_before"] for r in plan)} bytes; no files moved.')
        return 0
    manifest=json.loads(path.read_text(encoding='utf-8'))
    if args.apply:
        if manifest['applied']:
            errors=verify_migration(manifest)
            print('Already applied; verification only.')
        else:
            errors=validate_plan(manifest['files'])
            if errors: print('\n'.join(errors)); return 1
            for row in manifest['files']:
                source,target=ROOT/row['old_path'],ROOT/row['new_path']
                if source==target: continue
                target.parent.mkdir(parents=True,exist_ok=True)
                source.rename(target)
            changed=rewrite_references(manifest)
            # Persist the reversible edits before removing any empty directory.
            refresh_hashes(manifest)
            manifest['applied']=True
            manifest['applied_at']=dt.datetime.now().astimezone().isoformat()
            write_json(path,manifest)
            for directory in sorted((p for p in DOCS.rglob('*') if p.is_dir()),key=lambda p:len(p.parts),reverse=True):
                safe(directory,DOCS)
                if not any(directory.iterdir()): directory.rmdir()
            print(f'Applied migration; {len(changed)} reference files updated.')
            errors=verify_migration(manifest)
    else:
        errors=verify_migration(manifest)
    for error in errors: print(error)
    print(f'Migration verification: {len(manifest["files"])} original files; {len(errors)} errors')
    return 1 if errors else 0


if __name__=='__main__':
    raise SystemExit(main())
