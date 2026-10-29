"""Fetch the selected CC0 originals, verifying Poly Haven's published MD5s.

Run with --cache <directory outside the project>. The Blender art builder
uses that cache; only selected, optimized derivatives are shipped in assets/.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

TEXTURES = ['concrete_wall_001', 'concrete_floor_02', 'asphalt_02', 'corrugated_iron', 'rusty_metal_04']
MODELS = ['modular_chainlink_fence', 'industrial_caged_sconce', 'modular_industrial_pipes_01']


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 K17AssetBuilder', 'Accept': '*/*'})
    return urllib.request.urlopen(request, timeout=90)


def download(url, path, digest=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and (not digest or hashlib.md5(path.read_bytes()).hexdigest() == digest):
        return
    content = fetch(url).read()
    if digest and hashlib.md5(content).hexdigest() != digest:
        raise RuntimeError('Checksum mismatch: ' + url)
    path.write_bytes(content)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', required=True, type=Path)
    parser.add_argument('--metadata', type=Path, help='Optional directory of already fetched API JSONs')
    args = parser.parse_args()
    jobs = []
    for asset in TEXTURES + MODELS:
        metadata = args.metadata / (asset + '-files.json') if args.metadata else None
        info = json.loads(metadata.read_text(encoding='utf-8-sig')) if metadata and metadata.exists() else json.load(fetch('https://api.polyhaven.com/files/' + asset))
        folder = args.cache / asset
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'source.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
        if asset in TEXTURES:
            for key in ['Diffuse', 'nor_gl', 'Rough', 'Metal']:
                if key not in info:
                    continue
                file = info[key]['1k']['jpg']
                jobs.append((file['url'], folder / (key + '.jpg'), file['md5']))
        else:
            file = info['gltf']['1k']['gltf']
            jobs.append((file['url'], folder / (asset + '.gltf'), file['md5']))
            for relative, included in file['include'].items():
                path = (folder / relative).resolve()
                if not path.is_relative_to(folder.resolve()):
                    raise ValueError('Unexpected dependency path')
                jobs.append((included['url'], path, included['md5']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for result in pool.map(lambda job: download(*job), jobs):
            pass
    print('CC0 ASSETS: %d verified files in %s' % (len(jobs), args.cache))


if __name__ == '__main__':
    main()
