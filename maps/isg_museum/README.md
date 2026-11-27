# ISG Museum — hgmanh

Người phụ trách: **hgmanh**, nhánh **hgmanh-work**, map ID `isg_museum`.
Workspace bắt đầu từ `main` tại `13807bd` ngày 27/10/2026. Godot **4.7.2 stable**, GL Compatibility.

- Nhấn **F5** để mở menu Campus Escape 3D, chọn **ISG Museum — Phi vụ bảo tàng** hoặc **ISG Museum — Chỉnh map không bảo vệ**. [Kiểm tra tích hợp menu](docs/reports/menu-integration-v1/REPORT.md).
- Gameplay/stealth: mở [museum.tscn](scenes/museum.tscn), nhấn **F6**; có đủ chín guard.
- Chỉnh đồ họa và tương tác: mở [museum_editing.tscn](scenes/museum_editing.tscn), nhấn **F6**; scene kế thừa, loại guard trước khởi tạo, giữ NPC và luật nhiệm vụ.
- [Mục lục tài liệu](docs/README.md): thiết kế, hướng dẫn và toàn bộ báo cáo/bằng chứng.

## Authoring hiện hành

[Layout môi trường](resources/environment_art_layout.json) và [bảng vật liệu Gardner B](resources/courtyard_palette.json) là nguồn cấu hình.
[Builder hình học](tools/build_geometry.gd), [art helper](tools/environment_art_builder.gd) và [palette](tools/courtyard_palette.gd) lưu kết quả offline vào scene.
Sau sửa nguồn, dùng [apply_materials.gd](tools/apply_materials.gd), [apply_environment_art.gd](tools/apply_environment_art.gd) rồi kiểm tra art bằng `-- --check`.
Builder ghi đè đầu ra; sửa nguồn sinh tương ứng để kết quả tồn tại sau rebuild. Chỉ bake navigation khi đổi collision.

Xem [Gardner B](docs/reports/courtyard-palette-stage-b/REPORT.md), [sửa vòm/ngưỡng/cửa](docs/reports/post-b-fixes-v1/REPORT.md), [guard art](docs/reports/guard-art-v1/REPORT.md) và [NPC art](docs/reports/npc-art-v1/REPORT.md).
Capture/benchmark xuất vào `docs/reports/<đợt>/images`, `videos`, `logs`, `data`; các tool hỗ trợ `--output` nhận report root riêng để QA.

## Kiến trúc nhóm

Giữ khung `assets/`, `docs/`, `resources/`, `scenes/`, `scripts/`, `tests/`, `tools/`.
Dùng controller/interaction/AI chung từ `shared/` và cơ chế từ `features/`; logic museum nằm tại map.
Giữ attribution và giấy phép tại [assets/README.md](assets/README.md).
Hướng dẫn nhóm: [MAP_LAYOUT.md](../../docs/architecture/MAP_LAYOUT.md).

Kiểm tra từ gốc repository: import Godot, `tools/ci/check_scripts.gd`, runner `tests/test_scene.tscn` và `python tools/ci/check_layout.py`.
Không cần chạy preview hoặc F7 để thấy bảng vật liệu sản phẩm.
