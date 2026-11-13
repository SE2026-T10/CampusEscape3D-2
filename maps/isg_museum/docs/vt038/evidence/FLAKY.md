# VT-038 — kiểm tra tính ổn định theo thời gian và thứ tự

Mã test ở `maps/isg_museum/tests/storage_submission_tests.gd`; tùy chọn `--flaky` ở `maps/isg_museum/tools/run_storage_submission_tests.gd`. Baseline `c9bf5d63080c86b67f9581b4bc15bb515b180816` cùng patch GREEN đã được sinh viên chấp nhận. Kết quả dưới đây chạy trong worktree kiểm chứng tách biệt `D:/IT/SE_GAME_3D/.local/vt038/verify-worktree` để không đụng lần chạy suite tích hợp đang có. Không sửa mã game cho kiểm tra này.

Từ thư mục gốc của một checkout đã import resource, dùng Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
& '<đường dẫn Godot console.exe>' --headless --path . --log-file '<đường dẫn log cục bộ>' --script res://maps/isg_museum/tools/run_storage_submission_tests.gd -- --flaky
$LASTEXITCODE
```

[Lệnh và exit code thật](flaky-trials-final.json) · [stdout](flaky-trials-final.stdout.log) · [stderr](flaky-trials-final.stderr.log). Exit `0`, **15/15 lượt không failure**, 75 scene bảo tàng thật được tạo và dọn trong một tiến trình. Chỉ một thông báo lỗi đọc kho CA Windows trong stderr, đã xuất hiện trước patch; không có parse/script error trong lần chạy hợp lệ. Bản thử triển khai trước đó mắc lỗi suy kiểu của biến đổi vị trí trong shuffle, dừng do watchdog 180 giây và không chạy lượt nào; đã sửa bằng kiểu rõ ràng. Bản thử này không được tính là một lượt flaky hợp lệ.

## Hai nhóm rủi ro

**Thứ tự và trạng thái chia sẻ.** 5 lượt thứ tự gốc, 5 lượt đảo toàn bộ danh sách, 5 lượt Fisher–Yates với RNG cục bộ và seed ghi trong bảng. Chỉ hoán đổi bốn khối scenario độc lập; không đảo bước trong một scenario. T02/T03/T11 cùng một khối vì T03 cần scope thật từ cửa ở fixture T02 để kiểm tra scope cũ. Trong mỗi lượt có năm fixture: hai cho khối lifecycle và mỗi khối còn lại một. Mỗi fixture tạo scene/cửa/ledger mới, dùng contract override cố định, không chạy physics của guard/player và chỉ đếm tiếng động tại nguồn keypad. Kiểm tra group `game_flow`, `staff_calendar`, `museum_contract`, `noise_system`, `player` trống trước khi dựng fixture và sau lượt; tắt audio và `queue_free` scene rồi chờ lifecycle theo frame. Số lượt và seed không chứng minh không thể flaky dưới mọi thứ tự hay môi trường.

| Lượt | Chế độ / seed | Thứ tự scenario | Failures mỗi lượt |
|---|---|---|---:|
| 01–05 | Gốc / 0 (không dùng RNG) | Lifecycle → T04 → Ngày → Năm | 0 |
| 06–10 | Đảo / 0 (không dùng RNG) | Năm → Ngày → T04 → Lifecycle | 0 |
| 11 | Shuffle / 17 | Ngày → Năm → Lifecycle → T04 | 0 |
| 12 | Shuffle / 38 | T04 → Năm → Lifecycle → Ngày | 0 |
| 13 | Shuffle / 73 | Năm → Ngày → T04 → Lifecycle | 0 |
| 14 | Shuffle / 103 | Ngày → T04 → Lifecycle → Năm | 0 |
| 15 | Shuffle / 903 | Ngày → T04 → Lifecycle → Năm | 0 |

**Thời gian.** `staff_calendar.gd` mặc định dùng thời gian hệ thống và làm mới trong `_ready()`/`get_code()`. Test gắn `time_provider` giả trước `add_child` để khóa thời gian ngay từ `_ready`, chuyển trực tiếp từ `23:59:59` sang `00:00:00` trong fixture, không gọi sleep hay mạng. Cả 15 lượt đều chạy hai mốc giả: **07/11/2026 → 08/11/2026** và **31/12/2026 → 01/01/2027**. Cùng ID/mã đã xử lý tiếp tục nhận receipt sai mã gốc; ID mới dùng mã hợp lệ theo ngày sau khi đổi. Không kiểm chứng đồng hồ thật nhảy bất ngờ, múi giờ, DST hoặc môi trường khác.
