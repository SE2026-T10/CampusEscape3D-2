# Ngữ cảnh dự án

## Tổng quan

Campus Escape 3D là game hành động lén lút 3D góc nhìn thứ nhất, đồ họa low-poly. Người chơi chọn một nhiệm vụ/map độc lập, hoàn thành mục tiêu và tìm đường thoát trong khi tránh guard. Dự án dùng Godot **4.7.2 Stable**, GDScript và cấu hình Windows Desktop x86_64; tên, phiên bản và scene khởi động được khai báo trong [`project.godot`](../../project.godot). Phiên bản hiện khai báo là `1.2.0`.

Các map là scene độc lập, chạy một map tại một thời điểm. Nhân vật, guard AI, tương tác, stealth, menu và HUD dùng chung nằm trong `shared/`; các cơ chế tái sử dụng nằm trong `features/`; nội dung, quy tắc và công cụ riêng nằm trong `maps/<map_id>/`.

## Map có trong source và menu

Danh sách runtime có thẩm quyền là [`LevelCatalog.LEVELS`](../../shared/scripts/game/level_catalog.gd). Hiện tại có bốn map thường và một biến thể test được catalog cung cấp:

| Map | Scene | Trạng thái đã xác minh trong repository |
|---|---|---|
| Library Tutorial (`library_tutorial`) | `maps/tutorial/scenes/library_graybox.tscn` | Map hướng dẫn và fixture của nhiều test dùng chung; luồng nhiệm vụ tuyến tính. |
| Expanded Library (`expanded_library`) | `maps/library/scenes/expanded_library.tscn` | Map có nội dung gameplay mở rộng, nhiều guard, inventory/stamina, puzzle, an ninh, checkpoint và nhiều đường thoát. Mục tiêu thời gian chơi vẫn cần xác nhận qua playtest. |
| Museum Heist (`museum`) | `maps/museum/scenes/museum_heist.tscn` | Graybox có thể chơi đã được nâng cấp về cảnh quan: lobby, exhibition hall, restricted archive, security desk, nhiều vật trang trí và chướng ngại vật; vẫn giữ 5 guard, thẻ nhân viên, cửa nhân viên và một cửa thoát; chưa có vault, artifact, camera hay puzzle chuyên biệt. |
| K17 — 120 giây cuối (`intelligence_k17`) | `maps/intelligence/scenes/intelligence_k17.tscn` | Map tình báo K17 có nhiều khu vực, mission controller riêng, checkpoint, thiết bị an ninh, minimap và nhiệm vụ rút lui; xem `maps/intelligence/README.md` và các test K17. |
| K17 — Test map không lính gác | `maps/intelligence/scenes/intelligence_k17_test.tscn` | Biến thể test tùy chọn trong catalog của K17; không phải map thứ năm. Kiểm tra scene và `maps/intelligence/tests/k17_test_mode_tests.gd` trước khi dựa vào chi tiết chế độ. |

`maps/bank/` là khung trống chưa đăng ký. Tài liệu `maps/museum/README.md` đã được cập nhật để mô tả map đang đăng ký và bộ prop hiện tại. Các tài liệu/README khác có thể chưa phản ánh đầy đủ catalog; dùng `LevelCatalog`, scene và test hiện tại làm căn cứ, không tự động coi mọi README/map log cũ là trạng thái runtime.

## Các hệ thống cốt lõi

- **Menu và vòng đời map:** `MainMenu` dựng các nút theo catalog; `GameFlow` xử lý pause, restart, thắng/thua và về menu. Mỗi scene map tự chứa các hệ thống runtime của mình.
- **Player và tương tác:** `FirstPersonPlayer`, `PlayerInteractor` và lớp `Interactable` dùng chung; scene map có thể bật inventory/stamina.
- **Guard AI và stealth:** `Guard`, perception, state machine PATROL/INVESTIGATE/CHASE, vision, hearing, noise và `StealthDirector`.
- **Mục tiêu và hồi sinh:** `ObjectiveManager` hỗ trợ luồng tuyến tính hoặc đồ thị; `CheckpointManager` lưu objective và state của các node có checkpoint contract.
- **HUD:** HUD chung đọc ObjectiveManager, checkpoint, interactor và inventory; `MapHudProvider` là giao diện tùy chọn để map cung cấp trạng thái/kết quả riêng.
- **Nội dung có thể tái sử dụng:** `features/` chứa inventory, stamina, objectives, checkpoints, puzzles và security. Đây là mã được cấu hình/bật theo scene, không phải plugin có thể xóa từng thư mục tùy ý.

## Quy tắc dự án cần giữ

1. Dùng scene/script dùng chung thay vì sao chép player hoặc guard sang map riêng.
2. Map tự khai báo navmesh, objectives và các hệ thống scene-local cần dùng; chỉ một map hoạt động tại một thời điểm.
3. Việc đặt test vào thư mục không đảm bảo test được chạy. Suite phải được gọi từ `tests/test_scene.gd` hoặc được chạy bằng lệnh/tool riêng.
4. Kiểm tra tác động liên-map khi đổi `shared/`, `features/`, catalog, test runner hoặc CI.
5. Tài liệu này là chỉ mục ban đầu. Khi task chạm tới hành vi hoặc API, xác minh code đang chạy và cập nhật tài liệu bị ảnh hưởng.

## Điểm vào tra cứu

- Kiến trúc: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Module/source: [`MODULE_INDEX.md`](MODULE_INDEX.md)
- Tính năng và map sử dụng: [`FEATURE_REGISTRY.md`](FEATURE_REGISTRY.md)
- Luồng dữ liệu: [`DATA_FLOW.md`](DATA_FLOW.md)
- Kiểm thử: [`TESTING_GUIDE.md`](TESTING_GUIDE.md)
- Thay đổi tài liệu theo thời gian: [`CHANGELOG.md`](CHANGELOG.md)
