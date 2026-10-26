# Map thư viện

Scene chính: `scenes/expanded_library.tscn`. Phần mở rộng `scenes/expanded_library_expansion.tscn` được ghép trong cùng map. Navmesh nằm ở `resources/expanded_library_navmesh.tres`.

- `scripts/escape/`: badge reader, dock và thông tin đường thoát riêng.
- `scripts/presentation/`: âm thanh cho cơ chế thư viện.
- `tools/`: builder, layout, patch và công cụ đo riêng.
- `tests/`: các suite `expanded_*`, được runner chung gọi.
- `docs/`: tài liệu và bằng chứng đã chuyển từ `docs/expanded/`.

Player/NPC/HUD tham chiếu `shared/`; các cơ chế dùng lại tham chiếu `features/`. Builder gốc vẫn có những giới hạn lịch sử; đọc báo cáo phase trước khi dựng lại scene. Hướng dẫn hiện hành: [Làm việc theo từng map](../../docs/architecture/MAP_LAYOUT.md).
