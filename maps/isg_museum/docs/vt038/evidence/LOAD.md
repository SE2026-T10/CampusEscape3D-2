# VT-038 · T15 · Harness tải cục bộ

Kết quả chính thức ngày 13/11/2026: **exit `0`, 1.000 mẫu đo, p95 `150024 µs` (0,150024 giây) ≤ 3,0 giây, 0 lỗi và 0 timeout**. Peak outstanding là 100 trong từng burst. P95 các burst đo nằm trong `148487–154645 µs`, max toàn bộ mẫu đo `154673 µs`. Không dùng mẫu warm-up để tính số gộp.

## Chạy lại

Từ root của checkout đã import resource bằng Godot `4.7.2.stable.official.ed1daf0bf`, đặt đường dẫn executable và thư mục log hợp lệ (phải tồn tại):

```powershell
$godot = 'D:/IT/SE_GAME_3D/.local/godot/Godot_v4.7.2-stable_win64_console.exe'
$out = 'D:/IT/SE_GAME_3D/.local/vt038/stage6-load'
& $godot --headless --path . --log-file "$out/review-load.engine.log" --script res://maps/isg_museum/tools/benchmark_storage_submission.gd -- "--out=$out/review-latencies.csv"
$LASTEXITCODE
python maps/isg_museum/docs/vt038/evidence/validate_load_csv.py "$out/review-latencies.csv"
```

`load-t15-final.json` ghi lệnh thực tế, cwd và timeout tiến trình 120 giây. `load-t15-final.stdout.log` ghi môi trường, peak, số mẫu, p95 từng burst và side effects. `load-t15-final.stderr.log` giữ thông báo lỗi đọc root certificate store vốn có; harness không dùng network. `load-t15-final-latencies.csv` lưu 1.100 dòng mẫu gồm warm-up. `validate_load_csv.py` tái tính p95, kiểm tra timestamp/receipt độc lập từ CSV; `load-t15-csv-check.stdout.log` lưu kết quả (exit 0).

## Workload, mốc đo và oracle

- Mỗi burst tạo scene bảo tàng mới. Dùng cửa kho phụ, player, hệ thống tiếng động và hợp đồng production thật; tắt hành vi guard và chuyển động player bằng cấu hình fixture. Lịch cố định 07/11/2026 qua `time_provider`, mã hợp lệ là `0711`; tất cả yêu cầu tải gửi mã sai `0000` để thực sự chạy đường bộ đếm/báo động. Không dựng side effect giả. Kiểm tra nhóm đã dọn trước burst tiếp theo, cửa ban đầu còn khóa và các bộ đếm bằng 0.
- Mỗi burst có 50 ID mới và một lần gửi lại mỗi ID, cùng actor, scope và mã. Thứ tự xác định: mới 1–25, retry 1–25, mới 26–50, retry 26–50. Không dùng seed. Mỗi task có coroutine, timestamp và tín hiệu giải phóng riêng. Tất cả 100 coroutine đã chờ trước khi chốt mở (log kiểm tra `queued=100`, `outstanding=100`, `peak=100`, chưa có side effect). Sau đó xử lý tối đa 10 task mỗi `process_frame`, đặt `Engine.max_fps=60`.
- `Time.get_ticks_usec()` lúc task vào hàng đợi đến lúc nhận receipt. CSV tách thời gian chờ và chạy hàm. Timeout mỗi request 10 giây; request quá hạn trước lượt xử lý sẽ không chạy, quá hạn sau khi trả được ghi lỗi. Timeout ngoài tiến trình 120 giây. Một warm-up và mười burst đo, 100 task mỗi burst; thời gian load/cleanup scene nằm ngoài mốc đo. P95 nearest-rank = phần tử `ceil(0.95*n)` trong dãy tăng dần, tính riêng burst và gộp.
- Oracle độc lập theo luật game: với lần xử lý ID mới thứ `n`, `wrong_attempts_after = n % 3`, `alarm_count_after = floor(n/3)`, `alarm_triggered` chỉ đúng ở bội số ba. Retry phải trả đúng snapshot gốc. Kết quả mong đợi sau mỗi burst, gồm warm-up: cửa vẫn khóa, `wrong_attempts=2`, cửa và hợp đồng mỗi bên `16` báo động, `50` tín hiệu từ chối, `50` noise sự kiện keypad. Tất cả 11 burst đạt, outstanding cuối 0.

## Môi trường và giới hạn

Windows `10.0.26300`, Intel Core 5 210H (12 logical processors), 16.784.982.016 byte RAM vật lý báo bởi OS, Godot headless chính thức. Lượt chính thức 16:35:59–16:36:09 (+07:00) trên verify-worktree ở baseline `c9bf5d63080c86b67f9581b4bc15bb515b180816` + patch được duyệt. Không thấy Godot khác trong snapshot trước/sau lượt chính thức; không suy ra máy chạy độc quyền hoặc không có tải nền. P95 chịu ảnh hưởng của lịch xả 10 task/frame và môi trường này.

100 in-flight là 100 tác vụ chưa nhận kết quả **tại biên hàng đợi của harness**; thao tác trên node chạy tuần tự trên main thread. Không suy ra 100 request cùng sửa node, 100 người chơi thật, hiệu năng render hoặc network, hay khả năng phục hồi qua crash/restart. T09 kiểm tra riêng reentry khi API đang xử lý.

Hai lượt thử `load-smoke*` bị lỗi parse và không tạo mẫu. Lượt thăm dò `load-t15.*` đạt nhưng còn cảnh báo teardown audio. Sau khi dùng helper dọn audio có sẵn ngoài mốc đo, lấy `load-t15-final.*` làm kết quả chính thức. Các log thăm dò nằm trong thư mục `.local` của lần chạy, ngoài danh sách file dự kiến commit.
