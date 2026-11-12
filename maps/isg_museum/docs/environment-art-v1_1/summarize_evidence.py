"""Summarize actual local logs; run after validation and benchmarks finish."""
import hashlib
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def load(name):
    return json.loads(read(OUT / name))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


validation = load('validation-run.json')
checks = []
for item in validation:
    log = read(OUT / (item['id'] + '.log'))
    matches = re.findall(r'(\d+) checks, (\d+) failures', log)
    checks.append({**item, 'log': item['id'] + '.log',
                   'checks': int(matches[-1][0]) if matches else None,
                   'failures': int(matches[-1][1]) if matches else None,
                   'all_tests_passed': 'All tests passed' in log if item['id'] == 'integrated' else None})

nav = ROOT / 'maps/isg_museum/resources/museum_navigation.tres'
source_paths = [
    'architecture/gothic_architectural_structures/gothic_architectural_structures.glb',
    'architecture/balustrade_balcony/balustrade_balcony.glb',
    'exhibits/terpsichore_lyran/terpsichore_lyran_by_canova.glb',
]
source_hashes = {path: sha(ROOT / 'maps/isg_museum/assets/models' / path) for path in source_paths}
before, after, game = [load(name + '.json') for name in ['before-render', 'after-render', 'after-gameplay']]
data = {
    'schema_version': 1, 'generated_at': datetime.now().astimezone().isoformat(),
    'baseline_commit': '35fe3f8', 'engine': after['engine'], 'renderer': after['renderer'],
    'baseline_layout_rerun': {'date': '2026-11-12', 'references': 779, 'exit_code': 0,
                            'note': 'Initial pre-edit execution recorded in session; v1 report remains unchanged.'},
    'historical_count_correction': {'date': '2026-11-12', 'v1_report_total': 652,
                                    'v1_actual_log_total': 552, 'unchanged_gameplay_checks': 490,
                                    'v1_art_checks': 62, 'v1_1_art_checks': 87,
                                    'note': 'Historical report overcounted by 100; v1 files are preserved.'},
    'validation': checks, 'rebuild': load('rebuild-results.json'),
    'museum_checks': sum(item['checks'] or 0 for item in checks if item['id'].startswith('verify-')),
    'museum_failures': sum(item['failures'] or 0 for item in checks if item['id'].startswith('verify-')),
    'readonly_art_check': load('readonly-check.json')['unchanged'],
    'navmesh': {'rebaked': False, 'sha256': sha(nav), 'matches_v1': sha(nav) == '0DB27200B0C97F1B8E1E784C95EBECDF3F1C0FA5DAB2BCC3DD3641BA8C0ACF4E'},
    'source_glb_sha256': source_hashes,
    'column_batch_comparison': load('column-batch-comparison.json'),
    'final_integrity': load('final-integrity.json'),
    'benchmark_files': ['before-render.json', 'after-render.json', 'after-gameplay.json'],
    'benchmark_commands': load('benchmark-run.json'),
    'course_check': {'file': 'course-check.json', 'valid': load('course-check.json')['course_valid'],
                     'not_a_performance_measurement': True},
    'benchmark_course_valid': game['course_valid'],
    'benchmark_settings_restored': all(item['settings_restored'] for item in [before, after, game]),
    'render_diagnostics': {key: load('after-render-' + key + '.json') for key in ['no-fill', 'no-new-foliage', 'v1-sun']},
    'not_run': ['Linux/WSL CI', 'Windows export', 'Lower-spec GPU', 'Overdraw heatmap', 'Whole-process RAM'],
    'baseline_diagnostics': ['Windows root certificate store diagnostic persists; exit codes and behavior checks pass.',
                             'Staff suite shutdown resource warnings are also present in v1.'],
}
(OUT / 'VALIDATION.json').write_text(json.dumps(data, ensure_ascii=False, indent='\t') + '\n', encoding='utf-8')

lines = [
    '# ISG Museum v1.1 — benchmark', '',
    'Ngày đo: 12/11/2026. CPU **Intel Core 5 210H**, GPU **NVIDIA GeForce RTX 3050 6GB Laptop GPU**, driver **621.14**, Windows, Godot **' + after['engine'] + '**, **GL Compatibility**.', '',
    'V1 lấy từ snapshot scene baseline `35fe3f8`; v1.1 lấy scene hiện hành. Cùng GPU/máy, viewport **1280×720**, FOV **78°**, bốn camera benchmark v1 giữ nguyên. Chạy từng process nối tiếp, không chạy import, test hay chụp ảnh đồng thời. Mỗi góc warmup **3 giây**, lấy mẫu **6 giây** theo đồng hồ thật. Benchmark đặt **VSync disabled (0)**, **Engine.max_fps=0**, low-processor mode tắt; dùng exclusive fullscreen và khôi phục thiết lập khi xong. JSON ghi mode/viewport thực tế.', '',
    '**Frame interval** đo giữa hai process frame bằng `Time.get_ticks_usec()`, gồm CPU, scheduling và presentation. **GPU render time** do RenderingServer viewport timer cung cấp, ghi riêng; không gọi frame interval là GPU time. Không đo tổng RAM tiến trình. Render memory là monitor bộ nhớ render của Godot.', '',
    '## Render tĩnh: AI đóng băng', '',
    '| Góc | Bản | FPS TB | Interval p50 / p95 / p99 (ms) | GPU p95 (ms) | Draw p50 / p95 | Primitives p50 / p95 | Render memory peak (MiB) |',
    '|---|---|---:|---|---:|---|---|---:|',
]
for old, new in zip(before['samples'], after['samples']):
    for label, sample in [('v1', old), ('v1.1', new)]:
        interval = sample['frame_interval_ms']
        draw, primitives = sample['draw_calls'], sample['primitives']
        lines.append(f"| {sample['view']} | {label} | {sample['mean_fps']:.1f} | {interval['p50']:.3f} / {interval['p95']:.3f} / {interval['p99']:.3f} | {sample['gpu_render_ms_p95']:.3f} | {draw['p50']:,.0f} / {draw['p95']:,.0f} | {primitives['p50']:,.0f} / {primitives['p95']:,.0f} | {sample['render_memory_bytes_peak']/1048576:.1f} |")

sample = game['samples'][0]
interval = sample['frame_interval_ms']
lines += ['', '## Gameplay thực thời gian, chín guard', '',
          f"Lấy mẫu **{sample['seconds']:.0f} giây** sau warmup 3 giây, **{sample['frames']:,} frame**. Không dùng fixed-fps hoặc movie writer. Player chạy bằng input/physics thật theo waypoint cố định, dùng thử capsule để chọn hướng tránh vật và NPC; tự mở cửa qua tương tác. NavigationAgent của guard giữ nguyên. V và K được cấp trong fixture, chỉ kết thúc do bắt giữ được vô hiệu hóa ở instance benchmark để giữ thời lượng. Guard vẫn chạy vision, hearing, tìm kiếm, chase và body collision; G3 vẫn có state ngủ/nghỉ như production. Không sửa gameplay source.", '',
          f"- FPS trung bình: **{sample['mean_fps']:.1f}**.",
          f"- Frame interval p50/p95/p99: **{interval['p50']:.3f} / {interval['p95']:.3f} / {interval['p99']:.3f} ms**.",
          f"- GPU render p95: **{sample['gpu_render_ms_p95']:.3f} ms**.",
          f"- Draw calls p50/p95: **{sample['draw_calls']['p50']:,.0f} / {sample['draw_calls']['p95']:,.0f}**.",
          f"- Primitives p50/p95: **{sample['primitives']['p50']:,.0f} / {sample['primitives']['p95']:,.0f}**.",
          f"- Render memory peak: **{sample['render_memory_bytes_peak']/1048576:.1f} MiB**.",
          f"- Frame đang mang T2: **{game['carried_render_frames']:,}**; frame có chase: **{game['chase_render_frames']:,}**; T2 giao bằng production interaction: **{game.get('t2_delivered', False)}**.",
          f"- Tuyến hợp lệ: **{game['course_valid']}**. Waypoint thực đạt: `" + ' → '.join(game['visited']) + '`.', '',
          'Vị trí/thời điểm từng waypoint và trạng thái cả chín guard cuối lượt nằm trong [after-gameplay.json](after-gameplay.json); CSV giữ frame interval, draw, primitives, memory, GPU timing, số guard đang chase và cờ mang tranh ở từng frame.', '',
          '## Cách chạy và giới hạn', '',
          '```text',
          'godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --before --exclusive',
          'godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --exclusive',
          'godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --gameplay --seconds=240 --exclusive',
          '```', '',
          'Raw: [v1 render](before-render.json), [v1.1 render](after-render.json), [gameplay](after-gameplay.json), và ba CSV cùng tên. Lượt smoke 65 giây và lượt 240 giây với tuyến autopilot chưa đúng được giữ trong `iterations/`, không dùng làm benchmark nghiệm thu. Sau đó course-check headless fixed-fps xác nhận toàn tuyến trước khi chạy native lại. Video LOD và course-check không dùng để suy ra hiệu năng.', '',
          f"Thiết lập được khôi phục ở cả ba lượt: **{data['benchmark_settings_restored']}**. Chưa đo máy cấu hình thấp, heatmap overdraw, nhiệt độ/xung GPU hoặc RAM toàn tiến trình. Một cặp đo ngắn không xác định được mức tăng chất lượng còn an toàn trên mọi máy. Nếu FPS vẫn tạo plateau dù tool đã bỏ cap, chỉ dùng các khoảng thời gian và GPU timing trong phạm vi phép đo này; không coi đó là bằng chứng dư địa FPS.", '',
          'Chi phí tán mới gồm alpha-scissor atlas và ba card cong mỗi cụm; far giữ tán nhưng giảm cành/gốc rõ hơn khi ép xem sát. Hàng bụi thêm lá hình học, stone dùng normal/roughness nguồn dùng chung. Cần đọc mức tăng draw/primitives/memory cùng frame interval; không kết luận tối ưu chỉ từ ngân sách cây hoặc texture 2K.', '']

lines += ['## Tách nguyên nhân phần tăng chi phí', '',
          'Đo bổ sung cùng camera, warmup, thời lượng và thiết lập uncapped; chỉ đổi từng thành phần trên instance tạm, không lưu scene. `no-new-foliage` ẩn hai cây và lớp lá hedge mới, giữ các shrub nguồn; `v1-sun` chỉ trả hướng directional về v1, vẫn giữ toàn bộ art/material v1.1; `no-fill` tắt hẳn bốn Omni sân.', '',
          '| Variant | Góc | Draw p50 | Primitives p50 | GPU p95 (ms) |',
          '|---|---|---:|---:|---:|']
for key in ['no-new-foliage', 'v1-sun', 'no-fill']:
    for item in data['render_diagnostics'][key]['samples']:
        lines.append(f"| {key} | {item['view']} | {item['draw_calls']['p50']:,.0f} | {item['primitives']['p50']:,.0f} | {item['gpu_render_ms_p95']:.3f} |")
lines += ['',
          'Ở **staff**, chỉ trả hướng nắng về v1 đưa counter từ **952 / 1.014.240** về đúng **599 / 478.858** của baseline. Ẩn cây và hedge mới chỉ giảm còn **950 / 998.696**. Vì camera và mesh không đổi trong phép thử hướng nắng, phần tăng chủ yếu ở góc này là **shadow pass theo hướng directional mới**, không phải do tăng số cây hoặc Omni. GPU p95 ở staff tăng khoảng **0,146 ms** so với v1; frame interval p95 tăng khoảng **0,746 ms** trong cặp chính. Giữ hướng nắng mới để có chuyển sắc đã chụp, công khai chi phí này thay vì tuyên bố tối ưu.', '',
          'Ở **courtyard**, ẩn cây/hedge mới giảm primitives **2.070.593 → 1.673.777** và GPU p95 **2,144 → 1,714 ms**. Trả riêng hướng nắng v1 giảm còn **1.731.049** primitives. Hai tác động có tương tác shadow/culling, không cộng các mức giảm thành tổng chi phí. Tắt Omni không giảm counter hoặc GPU timing đáng kể trong các lượt này.', '',
          'So với v1, góc sân tăng draw khoảng **17%**, primitives khoảng **40%**, FPS trung bình giảm khoảng **6,7%**. Đây là chi phí chất lượng thật. Lượt gameplay cuối đạt p95/p99 dưới 10 ms trên máy đo, nhưng không chứng minh mức tăng chất lượng còn an toàn trên mọi GPU.', '',
          'Các file `after-render-<variant>.json`, CSV và log cùng tên giữ số gốc. Diagnostic `v1-sun` tải thêm snapshot để đọc transform, nên **không dùng memory peak của nó** so sánh bộ nhớ runtime. Lượt diagnostic này có hai cảnh báo texture GLES lúc thoát (349.524 byte mỗi texture); các số hiệu năng chính lấy từ các process render/gameplay riêng, không lấy lượt diagnostic làm gameplay.', '']
(OUT / 'BENCHMARK.md').write_text('\n'.join(lines), encoding='utf-8')

changed = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD', '--', 'maps/isg_museum/'], cwd=ROOT, text=True).splitlines()
changed += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', 'maps/isg_museum/'], cwd=ROOT, text=True).splitlines()
changed.append('maps/isg_museum/docs/environment-art-v1_1/CHANGED_FILES.txt')
(OUT / 'CHANGED_FILES.txt').write_text('\n'.join(sorted(set(changed))) + '\n', encoding='utf-8')
print('Museum checks:', data['museum_checks'], 'failures:', data['museum_failures'])
print('Benchmark course valid:', game['course_valid'], 'navmesh unchanged:', data['navmesh']['matches_v1'])
