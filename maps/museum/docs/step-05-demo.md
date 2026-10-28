# Bước 5 — Vòng chơi có nhiệm vụ, thắng và thua

Mở `res://maps/museum/scenes/museum.tscn`, nhấn **F6**. Scene hiện có ba tác phẩm thử, một hộp đại diện dây, điểm thoát xanh, HUD nhiệm vụ và bảo vệ của bước 4.

## Cách chơi

1. Dùng WASD và chuột để di chuyển/nhìn; C hoặc Ctrl để cúi, Shift để chạy.
2. Tiếp cận vật phẩm trong khoảng 2.2 m tính từ camera, nhìn vào vật phẩm để thấy lời nhắc **E**.
3. Nhấn E lấy các tác phẩm T1–T3 và dây theo thứ tự bất kỳ. Mỗi vật chỉ lấy một lần; HUD đánh dấu mục tiêu đã hoàn thành.
4. Khi đủ ba tác phẩm và dây, đến điểm xanh **THOÁT**, tránh tầm nhìn và cắt đuôi bảo vệ, rồi nhấn E.
5. Thắng sẽ hiện menu ESCAPED với lời chúc mừng của bảo tàng. Nhân vật và guard dừng lại. **Play again** tải lại phòng để chơi từ đầu.
6. Nếu bị bắt, màn hình CAUGHT hiện trong khoảng 2.5 giây rồi tải lại toàn scene: tác phẩm, dây, nhiệm vụ, guard và Player đều trở về ban đầu.
7. Esc mở menu pause; **Restart level** cũng tải lại toàn scene.

## Vị trí trong phòng thử

| Node | Vị trí | Mục tiêu |
|---|---|---|
| `Interactables/Painting_T1` | Tường tây, `(-5.65, 1.5, 0)` | `take_t1` |
| `Interactables/Painting_T2` | Tường đông, `(5.65, 1.5, 0)` | `take_t2` |
| `Interactables/Painting_T3` | Tường bắc, `(0, 1.5, -5.65)` | `take_t3` |
| `Interactables/Rope` | Gần góc tây nam, `(-3.8, 0.9, 5.2)` | `take_rope` |
| `Interactables/EscapeWindow` | Tường nam bên phải, `(3.8, 1.1, 5.6)` | `escape` |

HUD chung đếm năm nhiệm vụ: ba tranh, dây và thoát. Lấy đủ bốn vật phẩm chỉ mở nhiệm vụ thoát; cần tương tác tại điểm thoát để thắng. Điểm xanh ở bản này là đại diện của cửa sổ, chưa có chuyển động leo dây.

## Tệp triển khai

| Tệp | Vai trò |
|---|---|
| `scripts/museum_demo.gd` | Cấu hình dữ liệu nhiệm vụ trước khi ObjectiveManager khởi tạo; nối hoàn thành sang trạng thái kết thúc; tải lại map sau màn bị bắt |
| `scripts/demo_pickup.gd` | Kế thừa Interactable; hoàn thành đúng ID rồi ẩn vật phẩm và bỏ layer tương tác |
| `scripts/demo_exit.gd` | Kiểm tra đủ đồ, trạng thái game và cảm nhận hiện tại của guard; phát thông báo từ chối lên HUD hoặc hoàn thành escape |
| `scenes/painting_demo.tscn` | Scene Area3D tái sử dụng với MeshInstance3D, CollisionShape3D và nhãn |
| `scenes/museum.tscn` | Ghép vật phẩm, Environment, ObjectiveManager, ObjectiveHud và lời chúc mừng mới |

Các script ObjectiveManager, ObjectiveHud, GameFlow, GameMenus và AI trong phần dùng chung được sử dụng trực tiếp. Runtime không phụ thuộc vào tài liệu/ảnh trong `docs/`.

Sau khi đổi Geometry, công cụ `tools/bake_navigation.gd` vẫn bake được: nó loại logic map và các node gameplay trước khi lấy hình học của region. Vật phẩm mới là Area3D và mesh hiển thị, không thay đổi hình học collision của sàn/bệ nên không cần đổi navmesh ở bước này.

## Những chi tiết của vòng chơi

- Bốn mục tiêu lấy đồ đều active từ đầu. Escape yêu cầu cả bốn mục tiêu đã hoàn thành.
- Pickup chỉ dùng được khi game đang PLAYING. Vật ẩn đã lấy cũng mất collision layer tương tác để không che tia chọn vật khác.
- Điểm thoát phát tín hiệu `rejected(reason)`; ObjectiveHud hiện thông báo. Có đủ đồ nhưng còn bị nhìn thấy hoặc đang CHASE thì chưa thoát.
- Khi hoàn tất, `StealthDirector.finish_level()` đóng băng actor và chuyển trạng thái stealth sang ESCAPED. Điều này tránh bị guard bắt sau khi menu thắng đã hiện.
- Khi thua, đợi vòng bị bắt hiện có rồi tải lại scene, thay vì chỉ đưa Player về vị trí cũ. Toàn bộ tiến trình lượt chơi được làm mới.
- Khi thêm checkpoint thật sau này, thay cơ chế tải lại cả scene bằng lưu/khôi phục đồng bộ nhiệm vụ, vật phẩm và các trạng thái liên quan.

## Chạy kiểm tra

Công cụ kiểm tra riêng của map được chạy trực tiếp, không đăng ký bảo tàng vào menu chung:

```powershell
& '.local/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file 'D:/IT/SE_GAME_3D/.local/logs/museum-demo-verification.log' --script res://maps/museum/tools/verify_demo.gd
```

Kiểm tra tương tác, các điều kiện thoát, hoàn thành, chơi lại và khôi phục sau khi bị bắt. Công cụ trả mã khác 0 nếu có kiểm tra thất bại. Log cục bộ nằm ở `.local/logs/museum-demo-verification.log`.

Đã chạy trên Godot 4.7.2: **38 kiểm tra đạt, mã thoát 0**. Bao gồm tia tương tác thực và nhấn E cho cả bốn vật phẩm/điểm thoát, không tương tác xuyên bệ/tường, 24 thứ tự lấy đồ, HUD thông báo thiếu đồ, các điều kiện bị nhìn thấy/truy đuổi, trạng thái WIN đóng băng actor, nút Play Again/Restart tải lại scene và bị bắt thật rồi khôi phục toàn bộ lượt chơi.
