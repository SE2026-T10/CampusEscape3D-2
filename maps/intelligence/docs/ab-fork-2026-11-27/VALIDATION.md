# Trạng thái cửa hậu tại ngã rẽ A/B

Biển B tại sảnh cảm biến B1, khối giữa và ngã rẽ mép sân dùng chung thông tin với dòng B trên HUD. Khi đi vào, biển cho biết cửa hậu đã chuẩn bị hay chưa. Khi có hồ sơ, biển chỉ thao tác cần dùng ở cửa hoặc xác nhận cửa đã mở. Số giây hiển thị lấy từ thời lượng tương tác hiện hành của cửa B.

## Bốn ca đổi tuyến ở khối giữa

Chạy trên Godot 4.7.2 với camera mặt đất bật và đủ 10 NPC lúc bắt đầu. Driver xác nhận biển trước khi rẽ rồi dùng điều khiển và tương tác thật tới cửa hậu.

| Mốc | Cổng A ở điểm rẽ | Biển B ở điểm rẽ | Kết quả trên tuyến B |
| --- | --- | --- | --- |
| T+70 | Đóng sau 20 giây | Đã chuẩn bị · nhấn E | Thoát, còn 37,3 giây |
| T+70 | Đóng sau 20 giây | Khóa cơ · giữ E 8 giây | Guard3 bắt sau 0,78 giây giữ E, còn 37,4 giây |
| T+90 | Đã khóa | Đã chuẩn bị · nhấn E | Thoát, còn 17,3 giây |
| T+90 | Đã khóa | Khóa cơ · giữ E 8 giây | Guard3 bắt sau 0,78 giây giữ E, còn 17,4 giây |

Hai ca đã chuẩn bị có cùng thời gian thoát với mốc `90ced44`. Hai ca còn khóa tái hiện vị trí bị bắt ở cửa hậu của mốc cũ. Mốc giữ E được đọc từ tương tác lúc phát tín hiệu bị bắt, trước khi game phục hồi checkpoint. Bốn dòng trong bảng là các ca dàn trạng thái rồi chơi tự động từ ngã rẽ.

## Hồi quy

- V7 đạt 73 phép kiểm headless và 77 phép kiểm có render, gồm trạng thái trước khi lấy hồ sơ, hai cặp ở T+70/T+90, thời lượng giữ đọc từ cửa và trạng thái cửa đã mở. Ảnh 1280 × 720 cho thấy cả biển và HUD tại ngã rẽ.
- K17 621 phép kiểm, B1 65, V8 55, luồng map 100, hợp đồng map và 269 script đều đạt. Gói Windows Desktop PCK tải được cả hai chế độ.
- Lượt đi toàn nhiệm vụ có lính qua A thoát với 73,0 giây. Lượt qua B lấy 04-B và phá hoại thoát với 57,4 giây. Lượt không lính có 04-B và phá hoại thoát qua B với 52,2 giây.

## Chạy lại

Chạy từ thư mục dự án bằng Godot 4.7.2.

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/redirect_v4.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_v7.gd
godot --path . --resolution 1280x720 --script res://maps/intelligence/tools/check_v7.gd -- --out=D:/CNPM/output/k17-ab-fork-frames
```
