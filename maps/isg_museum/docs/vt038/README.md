# BT3 — VT-038: gửi lại yêu cầu nhập mã cửa kho phụ

**Hoàng Gia Mạnh · 23001903 · SE2026-T10 · GAME-3D-01**. Sinh viên đã duyệt nội dung, bố cục và phạm vi 105 file, đồng ý commit/push nhánh cá nhân; không merge. Baseline `c9bf5d63080c86b67f9581b4bc15bb515b180816`. [Nhánh nộp BT3 VT-038](https://github.com/SE2026-T10/CampusEscape3D-2/tree/bt3/23001903-vt038-idempotency) · [Commit code/test/harness a61014093896](https://github.com/SE2026-T10/CampusEscape3D-2/commit/a61014093896bb78da42941d04c50e0ed0525479) · [Repository CampusEscape3D-2](https://github.com/SE2026-T10/CampusEscape3D-2). Hồ sơ và source báo cáo được đóng gói trong commit tài liệu kế tiếp; PDF cuối ghi SHA chứa cả code và evidence sau khi xác minh nhánh trên remote. Không tạo PR trong bước xuất bản này.

Phạm vi: một người chơi local, một instance cửa trong một lượt, main thread. `submit_code_request(scope, request_id, code, by)` lưu cả kết quả mã sai; retry cùng ID và mã không đếm lại, không phát lại âm thanh hay báo động. API cũ vẫn nhận mã và trả `bool`. Không có bảo đảm qua crash, restart hoặc network. UI tạo ID mới cho xác nhận mới; các test retry qua API nội bộ.

## Chạy lại

Từ thư mục dự án, dùng Godot chính thức `4.7.2.stable.official.ed1daf0bf`. `$g` dưới đây trỏ tới executable console đúng bản. `--log-file` trỏ vào thư mục ghi được nếu môi trường không cho ghi `user://logs`. Các lệnh Python cần executable Python 3 thực. Nếu `python` trỏ tới alias Microsoft Store, thay bằng đường dẫn tuyệt đối tới Python đã cài. Các lệnh đã chạy và exit code nằm trong `evidence/*.json`.

```powershell
& $g --version
& $g --headless --path . --editor --quit
& $g --headless --path . --script res://maps/isg_museum/tools/run_storage_submission_tests.gd
& $g --headless --path . --script res://maps/isg_museum/tools/run_storage_submission_tests.gd -- --flaky
& $g --headless --path . --script res://maps/isg_museum/tools/verify_storage.gd
& $g --headless --path . --script res://maps/isg_museum/tools/verify_room_feedback.gd
python tools/ci/check_layout.py
```

**RED:** dùng một checkout sạch tại baseline. Đặt `evidence/storage_submission_tests.red.gd` vào `maps/isg_museum/tests/storage_submission_tests.gd`; lấy focused runner RED (đính kèm) đặt tại `maps/isg_museum/tools/run_storage_submission_tests.gd`. Dùng lệnh focused. Cùng envelope trong test được giao ba lần qua `submit_code()` thật; legacy không nhận ID. Dự kiến T02 pass và T03 fail trên side effect. Đây là **characterization của đường xử lý legacy dưới replay mô phỏng**, không phải test receipt hoặc bằng chứng UI tự gửi lại. Bản sao test RED giữ đúng SHA-256 được ghi trước patch. GREEN giữ oracle side effect, thay adapter bằng API keyed và kiểm tra thêm giá trị receipt.

**Mutation:** áp dụng `evidence/mutation.diff` trên bản production đúng trong một worktree tạm, dùng runner focused, sau đó đảo riêng diff và chạy lại. Không để mutation trên nhánh nộp. Chỉ thay nguồn của `wrong_attempts_after` trong `_receipt()`, từ `wrong_attempts` thành `alarm_count`. T02/T03 phát hiện `expected=1` / `actual=0` trong receipt lần sai đầu, trong khi bộ đếm thật là `1`. Control `0`, mutant `1` (12 assertion receipt fail; không có parse error), restored `0`. Hash file khôi phục trùng file nhánh nộp. Xem log `mutation-*` và `restored-sha256.txt`.

```powershell
# Chạy trong checkout tạm có patch GREEN, test và resources đã import.
$diff = (Resolve-Path 'maps/isg_museum/docs/vt038/evidence/mutation.diff').Path
git apply --check $diff
if ($LASTEXITCODE -ne 0) { throw 'Mutation diff does not match this checkout.' }
git apply $diff
if ($LASTEXITCODE -ne 0) { throw 'Mutation diff did not apply.' }
try {
    & $g --headless --path . --script res://maps/isg_museum/tools/run_storage_submission_tests.gd
    "Mutant exit: $LASTEXITCODE"
} finally {
    git apply --reverse $diff
    if ($LASTEXITCODE -ne 0) { throw 'Mutation could not be reversed in the temporary checkout.' }
}
& $g --headless --path . --script res://maps/isg_museum/tools/run_storage_submission_tests.gd
"Restored exit: $LASTEXITCODE"
```

**Flaky:** 15 trials trong một tiến trình: 5 thứ tự gốc, 5 đảo, 5 shuffle với seed và order ghi trong log. Các bước bên trong T05–T12 giữ nguyên; T02/T03 dùng chung một khối kiểm chứng scope giữa hai fixture. Mỗi ca tạo scene, cửa, ledger, lịch và counters mới; dọn scene trước ca tiếp theo, kiểm tra không còn node nhóm cũ. `time_provider` được gắn trước `_ready`, thay ngày chủ động để thử cả qua ngày và qua năm; không đợi nửa đêm thật, không dùng mạng. 75 fixtures; 15 lượt chuyển ngày và 15 lượt chuyển năm; 0 failure quan sát được. Đây là số lượt đã kiểm tra, không chứng minh không bao giờ flaky.

**Tải T15:** chạy lệnh sau; đặt `$csv` là đường dẫn tuyệt đối đến file CSV trong thư mục có quyền ghi.

```powershell
& $g --headless --path . --script res://maps/isg_museum/tools/benchmark_storage_submission.gd -- "--out=$csv"
python maps/isg_museum/docs/vt038/evidence/validate_load_csv.py $csv
```

Một burst có 50 ID mới nhập sai và 50 lần retry cùng ID/mã, theo lịch cố định: mới 1–25, retry 1–25, mới 26–50, retry 26–50. Cả 100 coroutine caller được nộp và giữ ở chốt trước lần gọi cửa đầu tiên. Main thread mở chốt cho tối đa 10 tác vụ mỗi frame (60 FPS cap), gọi API production trên cửa thật; lịch và hàng đợi là phần kiểm soát của harness. Mỗi task đo `Time.get_ticks_usec()` từ submit đến receipt, gồm chờ hàng đợi. Timeout 10 giây/task và 120 giây cho lệnh đã ghi log. Một warm-up được giữ trong CSV nhưng loại khỏi p95; 10 burst đo × 100 = 1.000 mẫu. p95 nearest rank: lấy phần tử thứ `ceil(0.95*n)` trong dãy đã sắp xếp tăng.

Kết quả: [CSV thô](evidence/load-t15-final-latencies.csv), [lệnh/exit](evidence/load-t15-final.json), [log](evidence/load-t15-final.stdout.log). Exit `0`, peak `100` trước mở chốt ở cả 11 burst, 0 lỗi/timeout. p95 gộp **150.024 µs = 0,150024 giây**, dưới 3,0 giây; từng burst đo **148.487–154.645 µs**. Mỗi burst kết thúc ở `[số lần sai còn lại=2, báo động cửa=16, báo động hợp đồng=16, tín hiệu từ chối=50, tiếng động keypad=50]`, cửa vẫn khóa và đóng. Windows 10.0.26300, Intel Core 5 210H, 12 CPU logic, khoảng 16,8 GB RAM, Godot chính thức 4.7.2. Đây là 100 tác vụ chờ ở biên submit→receipt trong một tiến trình, không phải 100 người chơi/luồng, không đo network hoặc FPS gameplay.

**Tích hợp ban đầu.** Run giai đoạn 5 kết thúc với exit `1`, không timeout. VT-038 đi qua, hai assertion lưu/đọc lại HUD thư viện fail. Trên checkout baseline, probe chạy nguyên `ExpandedHudTests` và tái hiện đúng hai assertion. `ConfigFile.save()` trả `12 / Can't open file` ở `user://` và `0 / OK` ở workspace cùng tiến trình. Với `APPDATA` mới ghi được, probe lưu `user://` thành công và suite HUD trên baseline exit `0`. Điều này xác định hạn chế ghi dữ liệu ở lần chạy ban đầu. [Lệnh và exit](evidence/integrated.json) · [Probe baseline](evidence/baseline_hud_probe.gd) · [Hai assertion](evidence/baseline-hud.stderr.log) · [HUD với APPDATA riêng](evidence/baseline-hud-writable.stdout.log) · [Log có trước VT-038](../environment-art-v1/integrated.log).

**Tích hợp giai đoạn 7.** Mở một PowerShell mới, ở thư mục dự án sau khi import tài nguyên, và chạy khối sau. Khối tạo một thư mục dữ liệu riêng và hoàn trả giá trị `APPDATA` của PowerShell. File engine log nằm trong thư mục đó. Giá trị `--fixed-fps 60` theo cách chạy đã ghi của map, giữ nhịp mô phỏng 60 bước/giây. `run_capture.py` ghi command, thời điểm bắt đầu/kết thúc, timeout, exit code và hai stream gốc vào thư mục evidence cạnh script. Dùng tên capture mới để giữ nguyên log nộp.

```powershell
$g = (Get-Command godot -ErrorAction Stop).Source
& $g --version
# Kiểm tra output là 4.7.2.stable.official.ed1daf0bf trước khi chạy.
$docs = (Resolve-Path 'maps/isg_museum/docs/vt038').Path
$runDir = Join-Path (Get-Location).Path ('.local/vt038-appdata-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $runDir -Force
$capture = 'integrated-rerun-' + [guid]::NewGuid().ToString('N')
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = $runDir
    & python "$docs/evidence/run_capture.py" $capture 2400 $g --headless --path . --fixed-fps 60 --log-file (Join-Path $runDir 'godot.log') res://tests/test_scene.tscn
    $testExit = $LASTEXITCODE
} finally {
    $env:APPDATA = $oldAppData
}
"Integrated suite exit: $testExit"
```

Lần chạy nộp ngày 13/11/2026, 16:57:29–17:02:32 (+07:00) trả exit `0`, runner in `All tests passed`. Các mục HUD lưu/đọc và VT-038 đều đi qua. `stderr` còn chẩn đoán đọc kho chứng chỉ Windows và cảnh báo guard/navigation; runner không báo assertion fail. Kết quả chỉ áp dụng cho Windows cục bộ. Chưa chạy CI Linux/WSL. [Môi trường](evidence/integrated-writable.environment.json) · [Command và exit](evidence/integrated-writable.json) · [Stdout](evidence/integrated-writable.stdout.log) · [Stderr](evidence/integrated-writable.stderr.log).

Để lặp đối chiếu HUD trên **checkout baseline**, dùng `--script` trỏ đến bản sao của `baseline_hud_probe.gd` (đường dẫn tuyệt đối); đặt `VT038_PROBE_FILE` tới một file mới có thể ghi trong workspace. Lần thứ hai đặt thêm `APPDATA` trỏ tới một thư mục trống có thể ghi trước khi khởi chạy Godot. Không đổi code để làm pass.

Sau khi đưa harness và suite vào nhánh nộp, kiểm tra focused cuối exit `0` (0 failures), layout exit `0` (795 tham chiếu), compile exit `0` (343 script). Xem `evidence/stage6-*.json` và log tương ứng. `git diff --check` sạch; file production khớp patch GREEN đã được duyệt.

## Dựng PDF bản nháp

Sửa nội dung trong `report_content.py`. Dùng Python 3 có ReportLab và thư mục Arial Unicode có các file `arial.ttf`, `arialbd.ttf`, `ariali.ttf`, `arialbi.ttf`. Trên Windows, `render_report.py` mặc định dùng `C:/Windows/Fonts`. Nếu font ở chỗ khác, truyền `--fonts` với đường dẫn phù hợp.

```powershell
python -B maps/isg_museum/docs/vt038/render_report.py --out .local/BT3_23001903_VT-038.pdf
```

Bản nháp ghi đường dẫn evidence tương đối trong PDF và dùng HTTPS cho liên kết repository. Link GitHub branch/PR và cột Commit/PR hiển thị trạng thái chờ xuất bản. Đường dẫn worktree trong JSON là đường dẫn thực của lần chạy.

Sau khi sinh viên duyệt báo cáo và cho phép xuất bản, dùng nhánh GitHub đã chứa code, test và evidence. Chạy từ checkout có commit đã xuất bản và các file trùng với commit đó. Chế độ cuối xác minh nhánh trên repository chính thức, đối chiếu file tại SHA, ghim liên kết evidence theo SHA và bỏ dấu bản nháp. Dùng tên nhánh thực đã xuất bản làm giá trị `--published-branch`.

```powershell
python -B maps/isg_museum/docs/vt038/render_report.py --final --published-branch $publishedBranch --out .local/BT3_23001903_VT-038.pdf
```

[Kế hoạch và test strategy](plan.md) · [Truy vết](traceability.md) · [AI Usage Log](AI-Usage-Log.md) · [Bản nháp commit và PR](PR-review.md) · [Danh sách file đề xuất](COMMIT-MANIFEST.md).
