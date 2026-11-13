# Phạm vi file xuất bản — VT-038

Phạm vi được sinh viên duyệt có **105 file**, tính từ baseline `c9bf5d63080c86b67f9581b4bc15bb515b180816`, đóng gói trong hai commit chính và một commit hoàn thiện hiển thị liên kết PDF trên [nhánh cá nhân](https://github.com/SE2026-T10/CampusEscape3D-2/tree/bt3/23001903-vt038-idempotency). Không merge. [Thông tin xuất bản và nội dung PR tham khảo](PR-review.md).

## 1. `feat(isg_museum): deduplicate storage door keypad submissions`

9 file cho API keyed, đường keypad, bộ test, đăng ký runner và harness tải. Commit [a61014093896bb78da42941d04c50e0ed0525479](https://github.com/SE2026-T10/CampusEscape3D-2/commit/a61014093896bb78da42941d04c50e0ed0525479).

- `maps/isg_museum/scripts/storage_door.gd`
- `maps/isg_museum/scripts/storage_keypad.gd`
- `maps/isg_museum/tests/storage_submission_tests.gd`
- `maps/isg_museum/tests/storage_submission_tests.gd.uid`
- `maps/isg_museum/tools/benchmark_storage_submission.gd`
- `maps/isg_museum/tools/benchmark_storage_submission.gd.uid`
- `maps/isg_museum/tools/run_storage_submission_tests.gd`
- `maps/isg_museum/tools/run_storage_submission_tests.gd.uid`
- `tests/test_scene.gd`

## 2. `docs(isg_museum): record VT-038 verification and report source`

96 file gồm 86 file evidence/script thu kết quả, cùng tài liệu và source dựng báo cáo. Diff mutation chỉ xuất hiện dưới dạng evidence. PDF cuối nằm ở thư mục output cục bộ; source trong nhánh này cho phép dựng lại bản cuối. Cache, dữ liệu APPDATA và thư mục worktree không thuộc phạm vi xuất bản.

- `maps/isg_museum/docs/vt038/AI-Usage-Log.md`
- `maps/isg_museum/docs/vt038/COMMIT-MANIFEST.md`
- `maps/isg_museum/docs/vt038/GREEN.md`
- `maps/isg_museum/docs/vt038/PR-review.md`
- `maps/isg_museum/docs/vt038/README.md`
- `maps/isg_museum/docs/vt038/RED.md`
- `maps/isg_museum/docs/vt038/evidence/FLAKY.md`
- `maps/isg_museum/docs/vt038/evidence/LOAD.md`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud-writable.json`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud-writable.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud-writable.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud.json`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/baseline-hud.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/baseline_hud_probe.gd`
- `maps/isg_museum/docs/vt038/evidence/flaky-trials-final.json`
- `maps/isg_museum/docs/vt038/evidence/flaky-trials-final.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/flaky-trials-final.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-import.json`
- `maps/isg_museum/docs/vt038/evidence/green-import.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-import.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-layout.json`
- `maps/isg_museum/docs/vt038/evidence/green-layout.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-layout.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-map-contract.json`
- `maps/isg_museum/docs/vt038/evidence/green-map-contract.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-map-contract.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-map-flow.json`
- `maps/isg_museum/docs/vt038/evidence/green-map-flow.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-map-flow.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-qa-flow.json`
- `maps/isg_museum/docs/vt038/evidence/green-qa-flow.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-qa-flow.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-scripts-final.json`
- `maps/isg_museum/docs/vt038/evidence/green-scripts-final.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green-scripts-final.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/green-version-check.txt`
- `maps/isg_museum/docs/vt038/evidence/green.json`
- `maps/isg_museum/docs/vt038/evidence/green.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/green.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/integrated-writable.environment.json`
- `maps/isg_museum/docs/vt038/evidence/integrated-writable.json`
- `maps/isg_museum/docs/vt038/evidence/integrated-writable.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/integrated-writable.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/integrated.json`
- `maps/isg_museum/docs/vt038/evidence/integrated.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/integrated.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/load-t15-csv-check.json`
- `maps/isg_museum/docs/vt038/evidence/load-t15-csv-check.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/load-t15-csv-check.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/load-t15-final-latencies.csv`
- `maps/isg_museum/docs/vt038/evidence/load-t15-final.json`
- `maps/isg_museum/docs/vt038/evidence/load-t15-final.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/load-t15-final.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-control.json`
- `maps/isg_museum/docs/vt038/evidence/mutation-control.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-control.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-field.json`
- `maps/isg_museum/docs/vt038/evidence/mutation-field.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-field.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-restored.json`
- `maps/isg_museum/docs/vt038/evidence/mutation-restored.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/mutation-restored.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/mutation.diff`
- `maps/isg_museum/docs/vt038/evidence/production.diff`
- `maps/isg_museum/docs/vt038/evidence/red-storage.json`
- `maps/isg_museum/docs/vt038/evidence/red-storage.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/red-storage.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/red.json`
- `maps/isg_museum/docs/vt038/evidence/red.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/red.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/restored-sha256.txt`
- `maps/isg_museum/docs/vt038/evidence/room-feedback.json`
- `maps/isg_museum/docs/vt038/evidence/room-feedback.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/room-feedback.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/run_capture.py`
- `maps/isg_museum/docs/vt038/evidence/run_storage_submission_tests.red.gd`
- `maps/isg_museum/docs/vt038/evidence/stage6-focused-final.json`
- `maps/isg_museum/docs/vt038/evidence/stage6-focused-final.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/stage6-focused-final.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/stage6-layout.json`
- `maps/isg_museum/docs/vt038/evidence/stage6-layout.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/stage6-layout.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/stage6-scripts.json`
- `maps/isg_museum/docs/vt038/evidence/stage6-scripts.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/stage6-scripts.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/storage-regression.json`
- `maps/isg_museum/docs/vt038/evidence/storage-regression.stderr.log`
- `maps/isg_museum/docs/vt038/evidence/storage-regression.stdout.log`
- `maps/isg_museum/docs/vt038/evidence/storage_submission_tests.red.gd`
- `maps/isg_museum/docs/vt038/evidence/test-source-sha256.txt`
- `maps/isg_museum/docs/vt038/evidence/validate_load_csv.py`
- `maps/isg_museum/docs/vt038/plan.md`
- `maps/isg_museum/docs/vt038/render_report.py`
- `maps/isg_museum/docs/vt038/report_content.py`
- `maps/isg_museum/docs/vt038/traceability.md`

Một số raw log/JSON giữ nguyên tên tài khoản và đường dẫn Windows như đã thông báo khi duyệt phạm vi xuất bản. RED được chứng minh bằng baseline, snapshot, SHA-256 và log đúng thời điểm; các commit đóng gói công việc sau kiểm chứng, không dựng lại lịch sử test-first.
