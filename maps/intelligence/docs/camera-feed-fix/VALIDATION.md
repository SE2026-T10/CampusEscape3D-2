# Sửa camera quan sát B1

Ngày: 29/10/2026. Nhánh: `feature/twp`. Nền: `3e64895`.

Phản hồi chơi thử: đã chiếm kênh B1 nhưng không thấy màn hình quan sát khi đứng sau màn che, nhấn V vẫn không hiện. Đợt này xử lý các đường đi input, nắm tay đẩy và khôi phục checkpoint; không thay mặt bằng, quyền hack hoặc luật thu hồi sau hồ sơ.

- Camera trước tự bật lại khi nắm tay đẩy nếu đã hack và feed đang ẩn.
- Checkpoint đã lưu quyền hack khôi phục cả feed trước, thay vì trả quyền truy cập nhưng để feed ở trạng thái ẩn.
- Phím V/R được xử lý ở input gameplay trước GUI, vẫn bỏ qua khi pause, nhật ký mở hoặc không chơi. Phím giữ/echo không làm chuyển nhiều góc liên tục.
- Nhấn V khi chưa hack, sau thu hồi hoặc chủ động ẩn có thông báo rõ. Lời nhắc khi đẩy và menu pause bổ sung phím camera.
- Không cấp quyền hack tự động. Sau hồ sơ camera vẫn mất kết nối; bản không lính vẫn không có cảnh vệ ẩn.

## Kiểm tra

| Nhóm | Kết quả |
| --- | --- |
| Camera: input, GUI focus, nắm/thả, pause, nhật ký, checkpoint và thu hồi | 36 kiểm tra headless, không lỗi |
| Cùng các tình huống với renderer Compatibility, cả hai chế độ | 77 kiểm tra, không lỗi; có ảnh feed hiển thị |
| Hồi quy B1 | 54 kiểm tra, không lỗi |
| Biên dịch toàn dự án | 246 script nạp được |

Các fixture chủ động đặt người/thiết bị ở B1; sau đó thử phím qua viewport thật. Không tính chúng là lượt chơi toàn nhiệm vụ. Bài renderer so sánh hình khi ẩn/hiện Guard6 để xác nhận feed trước render cảnh vệ thật, không dùng nhầm ảnh hành lang trống của màn ngụy trang. Trong fixture, AI được giữ đứng yên để ảnh có thể so sánh.

Xem [ảnh bản thường](normal.png), [ảnh bản không lính](no_guards.png), [log camera logic](logs/headless.log), [log renderer](logs/native.log), [log B1](logs/b1.log) và [log biên dịch](logs/scripts.log).

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_b1_feed.gd
godot --path . --fixed-fps 60 --max-fps 240 --script res://maps/intelligence/tools/check_b1_feed.gd
```

Mở lại lượt chơi để nạp script mới. Giữ E tại bảng B1 để hack, E nắm tay đẩy; camera trước tự hiện, V chuyển trước/C1/ẩn. Các script mở nhanh test tại B1 nằm local ngoài repo, không thay điểm bắt đầu của game.
