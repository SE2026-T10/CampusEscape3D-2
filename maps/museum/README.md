# Museum Heist

Museum Heist là map bảo tàng graybox có thể chơi, được đăng ký trong `LevelCatalog` và dùng chung player/guard/objectives/stealth systems của dự án. Map hiện tập trung vào một chuỗi nhiệm vụ tuyến tính: vào sảnh, tới khu vực hạn chế, lấy thẻ nhân viên, tới cửa thoát chính và thoát.

## Trạng thái hiện tại

- `scenes/museum_heist.tscn`: scene chính; giữ nguyên player, objective, stealth, menu và guard flow.
- `scenes/props/`: các prop có thể tái sử dụng gồm display case, bust, pedestal, hai painting, reception/security desks, bench, planter, archive shelf, rope barrier và decorative column.
- Vật liệu và hình học prop được tạo từ primitive mesh/`StandardMaterial3D`; ghế nhân viên tái sử dụng scene ghế dùng chung, không thêm dependency lên asset của map khác.
- `resources/museum_navmesh.tres`: navmesh thủ công cho sàn rộng; prop obstacle avoidance hỗ trợ cục bộ nhưng không carve navmesh.
- `docs/MUSEUM_HEIST.md`: layout, prop footprint, collision/vision, navigation limitation và trạng thái kiểm thử.

## Hướng phát triển

- Bake/rebuild navmesh quanh prop và playtest patrol/investigate/chase quanh chướng ngại vật.
- Kiểm tra hình ảnh, tỷ lệ, collision, vision rays và các lối đi trong Godot từ góc nhìn thứ nhất.
- Kiểm tra playtest thủ công toàn bộ map trước khi thêm camera, vault, puzzle hoặc nhiều exit mới.
