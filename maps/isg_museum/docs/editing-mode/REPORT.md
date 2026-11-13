# Chế độ chỉnh map không có bảo vệ

Ngày kiểm tra: **12/11/2026**, Godot **4.7.2 Stable**. Chỉ thay đổi trong `maps/isg_museum/`.

## Cách mở

- Duyệt đồ họa, nội thất và tương tác: mở `scenes/museum_editing.tscn`, nhấn **F6**.
- Thử stealth: mở `scenes/museum.tscn`, nhấn **F6**.

Scene editing kế thừa trực tiếp scene chính, giữ `museum_demo.gd` trên root. Inspector có `disable_guards_for_editing`, mặc định false; scene editing bật true. Cờ được đọc khi khởi động. `_enter_tree()` gỡ/free đồng bộ các child kiểu Guard trước khi chúng hoặc perception, collider, navigation agent vào SceneTree; không dùng group hoặc `queue_free()`.

Node G1–G9 vẫn nằm trong nguồn scene để bố trí bằng editor. Kết nối notice của G3/G6 chỉ thực hiện khi node tồn tại. Scene chính giữ đủ chín guard, route và cơ chế phát hiện. Không sửa shared AI, controller, điều kiện nhiệm vụ, renderer hoặc ProjectSettings/user settings.

Player, manager, StealthDirector, NoiseSystem, N0, tiếp đón, HUD, cửa, lịch, keypad, hiện vật, T2, dây và thoát dùng nguyên bản. Người chơi tự nhận hợp đồng, lấy K, trả lời nhận V và giải mã DDMM. Nhãn nhỏ “CHẾ ĐỘ CHỈNH MAP — BẢO VỆ TẮT” chỉ ở scene thử, không chặn input. Restart/Play Again tải lại scene editing bằng đường dẫn của owner GameFlow; không có cờ toàn cục.

## Kết quả

Chạy từ gốc repo với `.local/godot/Godot_v4.7.2-stable_win64_console.exe`. APPDATA tạm đặt trong `.local/godot-art-userdata-v11` để Godot không cần ghi settings ngoài workspace.

| Lệnh | Kết quả | Log |
|---|---|---|
| `godot --headless --path . --editor --quit` | exit 0 | [import.log](import.log) |
| `godot --headless --path . --script res://tools/ci/check_scripts.gd` | exit 0; 340 scripts | [check-scripts.log](check-scripts.log) |
| `godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_editing_mode.gd` | **75 checks, 0 failures** | [log](verify-editing_mode.log) |
| `godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_blockout.gd` | **106 checks, 0 failures** | [log](verify-blockout.log) |
| `godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_staff_room.gd` | **55 checks, 0 failures** | [log](verify-staff_room.log) |
| `godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_empty_frame.gd` | **48 checks, 0 failures** | [log](verify-empty_frame.log) |
| Python đã có sẵn, `-B tools/ci/check_layout.py` | exit 0 | [check-layout.log](check-layout.log) |
| `git diff --check` | exit 0 | Không có lỗi whitespace |

Tổng bốn suite: **284 checks, 0 failures**. Thời điểm/exit code: [results.json](results.json), [preflight-results.json](preflight-results.json).

Test mới kiểm tra source vẫn có chín guard, toàn bộ ID subtree guard bị giải phóng trước tree-enter, không có collider NPC/avoidance/listener, không tự cấp đồ. Sau đó dùng UI N0/tiếp đón, lấy K, đọc lịch, chạm chai thật, phá kính, nhập sai ba lần rồi giải keypad, lấy dây, chạy qua cửa chính, đi hai nhịp thang, lấy T1/T3, mang T2 theo hành lang tới depot và thoát bằng dây. StealthDirector/NoiseSystem luôn hoạt động; không tắt chúng trong test editing. Pause/Resume, menu Restart, kết quả Play Again và reset từ StealthDirector đều tải lại scene thử. Test cuối mở scene chính, xác nhận listener/agent và G3/G6; G3 ngủ với sight tắt rồi thức khi có tiếng động thật. Các suite cũ kiểm tra đủ hai thang, hai vòng tuần tra, G3 tìm/về ghế và G6 kiểm tra khung trống.

Lượt test mới đầu tiên có một kỳ vọng sai: yêu cầu sight của G3 đang ngủ phải bật. Đã sửa test theo state ngủ thực tế, bổ sung kiểm tra thức vì tiếng động; không sửa AI. Log thử ban đầu lưu ở `verify-editing-mode.log`, kết quả cuối là file dùng dấu gạch dưới trong bảng. Root certificate store diagnostic của Windows và cảnh báo resource khi thoát staff suite là các diagnostic đã có từ đợt trước; không làm thất bại kiểm tra hành vi.

Không bake lại navmesh. SHA256 giữ nguyên: `0DB27200B0C97F1B8E1E784C95EBECDF3F1C0FA5DAB2BCC3DD3641BA8C0ACF4E`.

File triển khai: `scenes/museum_editing.tscn`, `tools/verify_editing_mode.gd` và UID, `scripts/museum_demo.gd`, `README.md`; kèm hồ sơ kiểm tra trong thư mục này. Scene chính, geometry, asset art và shared giữ nguyên.
