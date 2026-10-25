# Thành phần dùng chung

`scenes/` chứa player, NPC, props và main menu. `scripts/` chứa điều khiển, AI, tương tác, HUD, game flow và các tiện ích hỗ trợ. `assets/` giữ tài nguyên âm thanh hiện có cùng các thư mục tài nguyên chung.

Chỉ thêm nội dung có thể dùng cho nhiều map. Cơ chế riêng thuộc `maps/<map_id>/scripts/`; cơ chế lựa chọn dùng lại thuộc `features/`. Không tham chiếu scene/script riêng của map từ đây. Player và HUD hiện vẫn hỗ trợ các feature tùy chọn đã có, bật/tắt theo cấu hình map.

Xem [hướng dẫn tổ chức map](../docs/architecture/MAP_LAYOUT.md).
