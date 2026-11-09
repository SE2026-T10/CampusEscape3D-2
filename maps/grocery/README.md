# Khung map độc lập

Sao chép nội dung thư mục này vào `maps/<map_id>/`, đặt tên người phụ trách, mục tiêu và phạm vi vào README của map. Các thư mục rỗng chưa phải scene chơi được và không được đăng ký trong menu.

- `scenes/`: scene chính và scene con.
- `scripts/`: logic riêng; sử dụng AI, điều khiển, tương tác và HUD dùng chung.
- `resources/`: navmesh và dữ liệu cấu hình.
- `assets/`: tài nguyên riêng.
- `tests/`: suite kiểm thử; cần đăng ký vào runner.
- `tools/`: công cụ riêng.
- `docs/`: thiết kế và bằng chứng; giữ `.gdignore` trong thư mục này.

Không sao chép `templates/.gdignore` vào gốc map. Chi tiết và giao diện HUD: [Hướng dẫn làm việc theo map](../../docs/architecture/MAP_LAYOUT.md).
