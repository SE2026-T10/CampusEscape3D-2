# Quyết định lấy 04-B tại ngăn hồ sơ

Sổ bàn giao và lời nhắc tại ngăn nói rõ tuyến chính của đoàn sơ tán đóng sớm 20 phút. Bản đính chính cho đoàn căn cứ để chuyển sang đường dự phòng. Khi nhìn vào ngăn đã mở, HUD hiện thao tác giữ E trong 3 giây từ cấu hình tương tác thực. Thời gian giữ nằm trong 120 giây rút lui bắt đầu từ lúc lấy Mật lệnh 04.

## Kết quả tập kết

| Lựa chọn | Kết quả hiển thị | Lượt toàn nhiệm vụ qua B |
| --- | --- | --- |
| Lấy và bàn giao 04-B | Xác nhận tuyến chính đóng sớm 20 phút và đoàn sơ tán đã chuyển sang đường dự phòng. | Thoát, còn 63,6 giây |
| Rút với Mật lệnh 04 | Hoàn thành nhiệm vụ. Xác nhận chỉ nhận Mật lệnh 04 và đoàn sơ tán chờ xác minh giờ phong tỏa. | Thoát, còn 67,0 giây |

Hai lượt qua B đi 128 waypoint mỗi lượt, với 0 lần bị bắt hoặc chạm cảm biến và đủ bốn tiếp viện. V8 chạy cả hai lựa chọn trong cả bản thường và bản không lính. Phép kiểm xác nhận HUD ghi thời lượng trước khi nhấn E, thao tác thật yêu cầu đúng 3 giây, và kết quả hiển thị đúng lựa chọn sau khi vào vùng tập kết.

- V8 đạt 122 phép kiểm headless và 134 phép kiểm có render ở cả 1280 × 720 lẫn 1024 × 768. Lời nhắc tại ngăn, kết quả và hai nút kết thúc nằm trong khung hình ở cả hai kích thước.
- Gói Windows Desktop PCK nạp từ ngoài dự án và đạt lại 122 phép kiểm V8, gồm lấy và bỏ 04-B ở cả hai chế độ.
- K17 621 phép kiểm, V7 73, B1 65, luồng map 100, hợp đồng map và 269 script đều đạt.

## Chạy lại

Chạy từ thư mục dự án bằng Godot 4.7.2.

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_v8.gd
godot --path . --resolution 1280x720 --script res://maps/intelligence/tools/check_v8.gd -- --out=D:/CNPM/output/k17-04b-frames
```

Hai lượt toàn nhiệm vụ dùng cùng đường B, pha B1 +9 giây, có lính và có đọc sổ bàn giao. Thêm `--annex` vào lệnh dưới để lấy 04-B. Lượt bỏ qua giữ các cờ còn lại.

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --camera-off --radio --wait-radio --sprint-exfil --watch-patrol --utilities-north --prepare --route=maintenance --projection-delay=9 --handover
```
