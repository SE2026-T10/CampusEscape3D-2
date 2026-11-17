# Docs cleanup v1 — ISG Museum

Ngày kiểm tra: 2026-11-17. Nhánh `hgmanh-work`, Godot **4.7.2 stable**. Đã hoàn thành migration sâu và kiểm tra teardown Post-B; không commit/push.

[Mục lục tài liệu](../../README.md) · [Manifest](data/path-migration.json) · [VALIDATION](VALIDATION.json)

## 1. Cấu trúc trước / sau

Trước: 14 bộ thiết kế/báo cáo và các step nằm ngang ở gốc docs; ảnh, video, log, JSON, script và baseline lẫn trong mỗi đợt. Tổng **1.268 tệp / 1,115,195,725 byte**.

```text
docs/
  .gdignore, .gitkeep, README.md
  design/       concept-v1/v2/v3, asset-design-preview-v1/v2
  guides/steps/ tài liệu step và ảnh cùng bộ
  reports/
    <đợt>/REPORT.md, VALIDATION.json
          images/, videos/, logs/, data/, snapshots/
          reproduce/ hoặc revisions/ khi có nội dung
    docs-cleanup-v1/       báo cáo và bằng chứng đợt này
```

**1.266 tệp đã chuyển**, hai tệp `.gdignore` / `.gitkeep` giữ tại gốc. Không xóa, nén hoặc đưa tệp ra ngoài workspace. Mỗi tệp gốc có đúng một mapping; đã kiểm tra đích tồn tại, trùng tên theo Windows case-insensitive và giới hạn đường dẫn trước khi chuyển bằng `Path.rename`. Chỉ xóa thư mục cũ sau khi kiểm tra rỗng.

Các báo cáo chính có `REPORT.md` / `VALIDATION.json`; phần bổ sung BENCHMARK/ATTRIBUTION đặt ở `data/`, không thay kết luận. A2 chuyển vào `courtyard-palette-v1/revisions/revision-a2`; các iteration cũ ở `environment-art-v1_1/revisions/iterations`. Bundle `before-source`, `baseline-source`, `a1-reference` giữ nguyên nội bộ dưới `snapshots/`, gồm cả ảnh/JSON phụ thuộc. Không rebuild snapshot từ sản phẩm hiện tại.

## 2. Nội dung đã chuẩn hóa

- README map rút gọn thành scene/F6, authoring hiện hành, tác giả hgmanh và kiến trúc nhóm; lịch sử chi tiết vẫn trong guides/reports và byte gốc README nằm trong manifest.
- [docs/README.md](../../README.md) chia thiết kế/hướng dẫn/báo cáo; làm nổi bật concept hiện hành, Gardner B, guard art, NPC art và Post-B.
- Mọi report cũ có liên kết được resolve từ **vị trí nguồn cũ**, chuyển qua mapping rồi tính lại tương đối. Giữ anchor và web link; code fence chứa lệnh lịch sử không bị thay hàng loạt. Thêm điều hướng nhóm bằng chứng vào report, giữ nguyên kết luận/check count/exit code/số đo.
- Editing-mode và iteration chưa có VALIDATION chính được bổ sung **index lịch sử**, trỏ tới records gốc; không giả tạo kết quả chạy.
- **34 tệp văn bản gốc trong docs** đã chỉnh có ghi lý do/byte gốc; các sửa ngoài docs chỉ là tham chiếu, tổ chức output hoặc teardown fixture. [Danh sách và lý do](data/content-edits.json). Giữ quy ước newline/BOM gốc cho tệp đã có.

## 3. Toàn vẹn và phụ thuộc

| Kiểm tra | Kết quả |
|---|---|
| Media gốc | **501 tệp** giữ nguyên SHA-256 |
| Log, JSON, CSV, text evidence, hash và nav baseline | **667 tệp** giữ nguyên SHA-256 |
| Runtime scene/script/asset/resource và shared/features được bảo vệ | **886 tệp** không đổi byte |
| Snapshot scene/resource | **41** load/instantiate offline, dependency tồn tại |
| Script GD reproduce | **3** compile trực tiếp thành công |
| Python/PowerShell reproduce | **4 entry point**, repo/report/log/data root đúng khi chạy từ CWD khác |
| Markdown | **56 tệp**, **0 liên kết nội bộ gãy** |
| Plan lần hai | **0 di chuyển**; manifest gốc không bị ghi đè |
| Apply lần hai | Chỉ verify, **0 lỗi**, không di chuyển/chỉnh lại |

[Hash bảo vệ](data/protected-after.json), [load snapshot](data/snapshot-load-check.json), [liên kết](data/link-check.json), [check root reproduce](data/reproduce-path-checks.json), [repeat plan](data/repeat-plan.json).

Đã cập nhật baseline ở `verify_environment_art.gd`, `post_b_fixes_tests.gd`, benchmark/capture environment/vegetation và các resource path nội bộ của snapshot. Catalog và README asset trỏ tới report mới. Giữ mọi `.gd.uid` đã có; helper mới có UID riêng. Khung map `assets/docs/resources/scenes/scripts/tests/tools/README.md` giữ nguyên.

## 4. Công cụ migration và output

`tools/organize_docs.py` dùng stdlib, có `--plan`, `--apply`, `--verify`. Plan gốc lưu trước khi di chuyển; manifest có size, hash trước/sau, category, lý do và `original_bytes_base64` cho mọi chỉnh văn bản. Manifest được ghi atomically, đường dẫn được resolve trong workspace, không shell-built move/delete.

`tools/report_paths.gd` phân nhóm output theo loại tệp. Capture step xuất vào `guides/steps`; các capture/benchmark xuất vào report `images/videos/logs/data`. Baseline input là hằng riêng dưới `snapshots/`, không đổi khi truyền `--output`. Capture metadata mới trỏ tới ảnh thực tế, còn JSON metadata lịch sử giữ nguyên. Reproduce tìm repository bằng `project.godot`, không phụ thuộc số tầng cha cũ; `-CheckPaths` / `--check-paths` chỉ đọc.

Smoke capture dùng `--output=res://maps/isg_museum/docs/reports/docs-cleanup-v1/revisions/capture-smoke`: **23 ảnh Godot**, metadata/collision đúng nhóm, không ghi đè bằng chứng cũ và không tạo lại thư mục cũ. [Báo cáo QA](revisions/capture-smoke/REPORT.md), [ảnh sân](revisions/capture-smoke/images/smoke-arcade-lower.png), [log](logs/capture-smoke.log).

## 5. Cảnh báo dọn tài nguyên Post-B

Đã tái hiện với `--verbose`; một lượt đầu không xuất hiện, lượt lặp lại có **8 ObjectDB / 3 resource**, cho thấy tính phụ thuộc thời điểm thoát. Log chỉ ra **3 AudioStreamWAV + 5 AudioStreamPlaybackWAV**, các stream `guard_keys.wav`, `guard_radio.wav`, `guard_step_4.wav`, cùng StringName SFX. [Log trước](logs/post_verbose_repeat.log).

Audit WeakRef xác nhận **7.199 node, 9 AI machine, 27 state** đều giải phóng, không phải guard/rig/fixture node bị giữ. Vấn đề nằm ở audio playback còn được mixer giữ khi runner thoát ngay sau free fixture.

Sửa **map-local trong `post_b_fixes_tests.gd`**: tắt process của fixture khi teardown, dừng AudioStreamPlayer/2D/3D và xóa stream reference, free fixture, quan sát **hai nhịp mixer bằng wall clock** với giới hạn 250 ms. Không tắt warning, không sửa shared runtime, không chỉ trì hoãn theo số frame mô phỏng. Audit ghi nhận dừng **7 player audio ở editing / 25 ở scene thường**, hai nhịp mixer đều được quan sát.

Các lượt verbose sau sửa, lượt thường và audit không còn ObjectDB/resource leak warning; **31 kiểm tra hành vi giữ nguyên và đạt**. [Log sau cuối](logs/post_verbose_after_final.log), [audit](data/post-b-lifetime-audit.json), [phân tích trước/sau](data/teardown-analysis.json). Cảnh báo trong report/raw log lịch sử vẫn được giữ, không coi exit 0 cũ là đã hết cảnh báo.

## 6. Lệnh và kết quả

Dùng `.local/godot/Godot_v4.7.2-stable_win64_console.exe`; Python thực `C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe`, chạy từ repository root. APPDATA chỉ đổi trong môi trường tiến trình con sang `.local/docs-cleanup-userdata`; không sửa settings người dùng.

| Lệnh / runner | Exit | Log |
|---|---:|---|
| `import` | 0 | [logs/import.log](logs/import.log) |
| `scripts` | 0 | [logs/scripts-attempt-4.log](logs/scripts-attempt-4.log) |
| `layout` | 0 | [logs/layout-attempt-1.log](logs/layout-attempt-1.log) |
| `verify_docs_migration` | 0 | [logs/verify_docs_migration-attempt-1.log](logs/verify_docs_migration-attempt-1.log) |
| `verify_environment_art` | 0 | [logs/verify_environment_art.log](logs/verify_environment_art.log) |
| `post_verbose_after_final` | 0 | [logs/post_verbose_after_final.log](logs/post_verbose_after_final.log) |
| `audit_post_b_teardown` | 0 | [logs/audit_post_b_teardown-attempt-2.log](logs/audit_post_b_teardown-attempt-2.log) |
| `verify_courtyard_palette` | 0 | [logs/verify_courtyard_palette.log](logs/verify_courtyard_palette.log) |
| `smoke_main` | 0 | [logs/smoke_main.log](logs/smoke_main.log) |
| `smoke_editing` | 0 | [logs/smoke_editing.log](logs/smoke_editing.log) |
| `runner` | 0 | [logs/runner.log](logs/runner.log) |
| Migration `--verify` | 0 | [log](logs/migration-verify.log) |
| Migration `--plan` lần hai | 0 | [log](logs/migration-plan.log) |
| Migration `--apply` lần hai | 0 | [log](logs/migration-apply.log) |
| Capture QA | 0 | [log](logs/capture-smoke.log) |

Runner chung có **All tests passed**, chạy `--fixed-fps 60` theo lệnh yêu cầu. Environment art **97 checks**, Post-B **31**, palette **43**, đều 0 failure; layout **896 runtime references**. Hai scene chính/editing đã smoke headless 120 frame. Lệnh đầy đủ, timestamp, thời lượng, exit code và các attempt được giữ trong [runs.json](data/runs.json), [migration-checks.json](data/migration-checks.json) và [VALIDATION.json](VALIDATION.json).

## 7. Hoàn tác và giới hạn

Manifest đủ dữ liệu để hoàn tác: trước hết kiểm hash hiện tại bằng `sha256_after`; với file đã sửa, decode `original_bytes_base64` và kiểm `sha256_before`; sau đó dùng mapping ngược để đưa file về vị trí cũ, kiểm collision/đích tồn tại như lúc plan. File được tạo mới có `new_file=true`; chỉ loại chúng khi hash còn khớp, không đè công việc mới. Chỉ bỏ thư mục đã rỗng. Không dùng git reset/clean.

- Raw log/JSON/argv/hash manifest cũ chủ ý giữ đường dẫn cũ. Dùng mapping để tra; không yêu cầu toàn repo hết mọi chuỗi cũ. Các tham chiếu thực thi và Markdown đang dùng đã cập nhật.
- Chỉ load/instantiate tài nguyên baseline và compile script reproduce; không chạy lại toàn bộ benchmark/video lịch sử hoặc rebuild baseline. Không suy ra hiệu năng từ smoke capture.
- Diagnostic Windows certificate store còn xuất hiện. Cảnh báo ObjectDB/resource của Post-B không còn trong các lượt sau sửa; không có lỗi script trong lượt đạt cuối.
- Không đổi scene/gameplay/asset runtime, không bake navmesh, không commit/push.
