#!/usr/bin/env python3
"""Check runtime paths and ownership after the map directory migration.

Historical docs/logs are intentionally excluded. No third-party packages needed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--verify-migration', action='store_true',
                    help='Audit the original move against its historical manifest (one-time check).')
args = parser.parse_args()
errors = []
checked = 0


def check_target(source, target):
    global checked
    checked += 1
    if not (ROOT / target.removeprefix('res://')).exists():
        errors.append(f'{source.relative_to(ROOT)}: missing {target}')


def ignored(file):
    for parent in file.parents:
        if parent == ROOT:
            break
        if (parent / '.gdignore').exists():
            return True
    return False


for folder in ['shared', 'features', 'maps', 'tests', 'tools']:
    for source in (ROOT / folder).rglob('*'):
        if not source.is_file() or ignored(source):
            continue
        if source.suffix in {'.tscn', '.tres'}:
            text = source.read_text(encoding='utf-8')
            for target in re.findall(r'\[ext_resource[^\n]*?path="(res://[^"]+)"', text):
                check_target(source, target)
        elif source.suffix == '.gd':
            text = source.read_text(encoding='utf-8')
            for line in text.splitlines():
                if line.lstrip().startswith('#'):
                    continue
                for target in re.findall(r'\b(?:preload|load)\("(res://[^"]+)"\)', line):
                    check_target(source, target)
            if not source.with_suffix('.gd.uid').is_file():
                errors.append(f'{source.relative_to(ROOT)}: missing paired .uid')
            if folder in {'shared', 'features'} and re.search(r'res://maps/[^/]+/(?:scenes|scripts|resources)/', text):
                # The historical tutorial restart fallback is data, not a map script dependency.
                for target in re.findall(r'"(res://maps/[^\"]+)"', text):
                    if target.endswith('.gd') or '/resources/' in target:
                        errors.append(f'{source.relative_to(ROOT)}: common code depends on a map resource {target}')

project = ROOT / 'project.godot'
main = re.search(r'^run/main_scene="([^"]+)"', project.read_text(encoding='utf-8'), re.M)
if not main:
    errors.append('project.godot: missing main scene')
else:
    check_target(project, main[1])

if args.verify_migration:
    manifest = json.loads((ROOT / 'docs/architecture/path-migration.json').read_text(encoding='utf-8'))
    for entry in manifest['files']:
        destination = ROOT / entry['to']
        if not destination.is_file():
            errors.append(f'Missing migrated file {entry["to"]}')
            continue
        # Audit preservation at migration time, without freezing later map edits in CI.
        if destination.suffix in {'.uid', '.wav', '.png', '.json', '.jsonl', '.csv', '.log', '.txt', '.tres'}:
            digest = hashlib.sha256(destination.read_bytes()).hexdigest()
            if digest != entry['sha256']:
                errors.append(f'Historical/binary content changed: {entry["to"]}')

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
details = f'{checked} runtime references'
if args.verify_migration:
    details += f'; {len(manifest["files"])} migrated files'
print(f'CHECK LAYOUT PASSED ({details})')
