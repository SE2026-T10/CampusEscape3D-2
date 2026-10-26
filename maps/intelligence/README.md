# K17 — 120 giây cuối · V1

Người phụ trách: Nguyễn Đình Phiên. Một người lính thâm nhập cơ sở tình báo trong chiến tranh hư cấu, thu hồi Mật lệnh 04 rồi mang hồ sơ về điểm tập kết.

[Cốt truyện gốc](https://docs.google.com/document/d/1JnYON8pKSkMLtzYODPYOhB-96hSxaVUOpCYgm020JS8/edit). V1 hiện thực hóa vòng nhiệm vụ bằng bản đồ khối đơn giản; xem [phạm vi và kiểm tra V1](docs/v1/VALIDATION.md).

## Chơi V1

Dùng Godot **4.7.2 official**, mở `project.godot`, chạy project và chọn **K17 — 120 giây cuối (V1)** trong menu. Có thể mở trực tiếp `scenes/intelligence_k17.tscn` và nhấn F6.

```text
godot --path . res://maps/intelligence/scenes/intelligence_k17.tscn
```

WASD di chuyển, chuột nhìn, Shift chạy, C/Ctrl cúi, E tương tác, Esc/P tạm dừng. F3 bật/tắt thông tin gỡ lỗi trong bản phát triển.

1. Vào cơ sở qua sân phía tây hoặc lối kỹ thuật phía đông.
2. Đến bàn trong phòng trực phía tây và lấy giấy thông hành bằng E.
3. Mở cửa khu hồ sơ bằng E. Đi đến ô checkpoint sáng xanh bên phải, vòng qua tủ che.
4. Đến giá hồ sơ cuối phòng. Nhấn E lấy Mật lệnh 04; đồng hồ 120 giây bắt đầu.
5. Mang hồ sơ đến một trong hai vùng đèn xanh bên ngoài hàng rào: lối sân phía tây hoặc bảo trì phía đông.

Bị bắt sẽ quay về checkpoint đã kích hoạt; trước checkpoint sẽ trở về điểm đầu. Hết giờ hiện màn thất bại với nút thử lại checkpoint, chơi lại từ đầu và về menu. Khôi phục trước phòng hồ sơ giữ giấy thông hành/cửa đã mở, trả hồ sơ về giá và đưa đồng hồ về trạng thái chưa chạy. Đi qua checkpoint trong lúc rút lui không ghi đè lần lưu này.

## Phạm vi đã có

- Một tầng, sân tiếp vận, phòng trực, khu thông tin, khu hồ sơ và lối kỹ thuật/bảo trì.
- Hai tuyến tiếp cận, hai điểm tập kết, bốn NPC với tuyến tuần tra riêng và navmesh đã bake.
- Player, tương tác E, AI nhìn/nghe và HUD đều dùng phần chung; `features/` cung cấp nhiệm vụ, giấy thông hành, cửa và checkpoint.
- Trạng thái hồ sơ và đồng hồ thuộc `mission_controller.gd`; HUD nhận dữ liệu qua `MapHudProvider`.
- Pause dừng đồng hồ; hết giờ không tăng số lần bị lính bắt; thắng ghi nhận đường rút và số giây còn lại.

V1 dùng thao tác E tức thời để hoàn thành vòng chơi trước. Cảm biến theo chu kỳ, giữ E/thanh tiến trình, radio tương tác, lịch cửa phong tỏa và asset/âm thanh quân sự chi tiết sẽ được thêm theo từng feature. Đồng hồ 120 giây hiện là thông số khởi đầu, chưa được cân bằng thành độ khó cuối cùng hoặc xác nhận thời lượng 10–15 phút bằng người chơi.

## Dựng lại và kiểm tra

Builder là nguồn bố cục của V1; sửa builder rồi dựng lại thay vì sửa riêng scene đã sinh. Nó tạo scene và navmesh, không chạy khi chơi game.

```text
godot --headless --path . --script res://maps/intelligence/tools/build_k17.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/intelligence/tools/check_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd
```

`playthrough_k17.gd` dùng bộ điều khiển và tương tác thật để kiểm tra va chạm của cả hai tuyến, chủ động tắt NPC chỉ trong lượt QA này. `guard_soak_k17.gd` kiểm tra riêng bốn NPC đang hoạt động trong scene thật. Scene phát hành luôn giữ NPC hoạt động.

Suite nhiệm vụ được đăng ký trong `tests/test_scene.gd`; `tools/map_flow.gd` kiểm tra việc chọn, restart và rời cả ba map. Build/export dùng quy trình chung. Không có phụ thuộc runtime vào scene hay script của thư viện.
