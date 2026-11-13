# BT3 VT-040 · Nhập cài đặt theo lô

Nhập cài đặt của một hồ sơ Campus Escape 3D từ mảng JSON. Ví dụ có trong [sample-settings.json](sample-settings.json). Mỗi phần tử chứa cặp `key` và `value`.

| Khóa | Giá trị chấp nhận |
| --- | --- |
| `hud_scale` | Một trong các mức trong `GameSettings.HUD_SCALES` |
| `master_volume` | Số hữu hạn trong khoảng [0, 1] |
| `captions` | Boolean JSON |

Bản ghi hợp lệ đầu tiên của mỗi khóa được giữ. Mỗi dòng sai được báo bằng vị trí tính từ 1 và lý do. Các khóa và mục khác trong tệp đích được giữ nguyên giá trị. Tệp hỏng, lô toàn lỗi và lỗi lưu có số bản ghi đã lưu bằng 0. Một tệp đầu vào có thể chứa tối đa 256 KiB và 1.000 bản ghi.

Từ thư mục gốc repo, dùng Godot 4.7.2 official. Trên Windows, đặt đường dẫn tới bản Godot console trong biến PowerShell sau.

~~~powershell
$godot = (Get-Command godot -ErrorAction Stop).Source
# Nếu Godot chưa có trong PATH, thay dòng trên bằng đường dẫn tệp *_console.exe.
& $godot --headless --editor --path . --import
& $godot --headless --path . --script res://tools/vt040/import_settings.gd -- tools/vt040/sample-settings.json user://vt040-demo.cfg
~~~

Tệp mẫu lưu HUD và phụ đề, báo lỗi ở bản ghi 2 vì âm lượng vượt giới hạn. Có thể bỏ tham số đích để cập nhật `user://settings.cfg` mà game đọc ở lần mở tiếp theo. Đóng game trước khi nhập vào tệp thật và chạy tuần tự các lần ghi cùng một hồ sơ. Nếu lưu thất bại và hệ thống cũng chặn khôi phục tệp cũ, nhật ký ghi đường dẫn bản sao `.previous` để phục hồi thủ công.

CLI trả một đối tượng JSON gồm `status`, `saved`, `rejected` và `error`. Mã thoát `0` cho `success` và `partial_success`, `1` khi không có gì được lưu và `2` khi gọi sai cú pháp. `input_error` và `read_error` lần lượt báo lỗi đọc nguồn và đích. `storage_error` báo lỗi lưu.

~~~powershell
& $godot --headless --path . --script res://tests/vt040/check_settings_import.gd
& $godot --headless --path . --script res://tests/vt040/check_settings_import.gd -- 140040
python tests/vt040/check_cli.py $godot
& $godot --headless --path . --script res://tools/vt040/load_settings_import.gd
~~~

Test T08 cố ý nạp tệp đích hỏng, vì vậy Godot in một chẩn đoán `ConfigFile parse error` trong lần chạy đạt. Kết quả bộ test nằm ở dòng tổng kết `VT-040`. Ba seed mặc định được in trước các ca sinh dữ liệu. Lệnh có seed chạy lại 80 mẫu của seed đó. CLI test cần Python 3 và chỉ dùng thư viện chuẩn.

Bài đo tải chạy 5 đợt, mỗi đợt thả đồng thời 120 luồng vào cùng hàm nhập. Mỗi luồng đọc một tệp 100 dòng, ghi tệp hồ sơ riêng, rồi xác minh lại dữ liệu trên đĩa. p95 lấy theo thứ hạng gần nhất trên thời gian từ khi mở cổng đến khi lời gọi nhập trả kết quả. Phép đo tính thời gian chờ CPU và I/O trong lời gọi. Chuẩn bị dữ liệu, khởi tạo tiến trình Godot và bước đọc đối chiếu nằm ngoài khoảng đo. Kết quả mô tả 120 tác vụ trên hồ sơ độc lập ở máy đo.
