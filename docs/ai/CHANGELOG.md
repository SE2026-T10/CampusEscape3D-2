# Changelog cho AI Agent

Ghi các thay đổi đã xác minh, không dùng file này thay cho release notes. Dùng ngày ISO `YYYY-MM-DD`; liệt kê file/module bị ảnh hưởng, test đã chạy và test chưa chạy. Với thay đổi source, cập nhật registry/architecture/flow/testing trước hoặc cùng entry changelog.

## 2026-11-04 — Khởi tạo bộ tài liệu ngữ cảnh AI

- **Nội dung:** Tạo chỉ dẫn agent và tài liệu project context, architecture, module index, data flow, feature registry, testing guide và ADR index dựa trên cấu trúc/source/catalog/test hiện tại.
- **File thêm:** `AGENTS.md`, `docs/ai/PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `MODULE_INDEX.md`, `DATA_FLOW.md`, `FEATURE_REGISTRY.md`, `TESTING_GUIDE.md`, `CHANGELOG.md`, `decisions/README.md`.
- **Module liên quan:** Không đổi source runtime; chỉ ghi nhận shared/features/maps/tests/tools.
- **Kiến/API:** Gameplay, architecture, API không đổi.
- **Kiểm tra:** `git status`/tree/source review. Godot import, test runner, QA flow, map flow và CI scripts **chưa chạy**; Godot executable không có trong PATH.
- **Kết quả/giới hạn:** README gốc chưa liệt kê K17; `maps/museum/README.md` vẫn ghi Museum chưa có scene/catalog, trái với scene/catalog/flow tool hiện tại. Mô tả Museum graybox trong README gốc phù hợp với source. Changelog này ghi nhận độ lệch; source/catalog/flow tools được dùng làm căn cứ. Các chi tiết chưa xác minh runtime không được tuyên bố là đã test trong phiên này.

## 2026-11-04 — Nâng cấp cảnh quan Museum Heist

- **Nội dung:** Tăng cường layout bảo tàng bằng lobby, exhibition hall, restricted archive, security desk và các vật trang trí/điều kiện phải kiểm tra bằng collision và phạm vi di chuyển; không thay đổi flow nhiệm vụ hoặc logic top-level của map.
- **File liên quan:** `maps/museum/scenes/museum_heist.tscn`, `maps/museum/README.md`, `maps/museum/docs/MUSEUM_HEIST.md`, `docs/ai/PROJECT_CONTEXT.md`, `docs/ai/MODULE_INDEX.md`, `docs/ai/DATA_FLOW.md`, `docs/ai/FEATURE_REGISTRY.md`, `docs/ai/TESTING_GUIDE.md`.
- **Module liên quan:** Map-local scene và tài liệu; không chỉnh sửa shared systems / LevelCatalog / menu.
- **Kiến/API:** Không đổi gameplay contract; chỉ thêm vật thể trang trí và phân khu cảnh quan trong scene hiện có.
- **Kiểm tra:** `python tools/ci/check_layout.py` (chạy trong phiên này) để xác nhận tất cả resource `res://` được tham chiếu hợp lệ. Không có Godot executable để chạy scene hoặc full suite headless.
- **Kết quả/giới hạn:** Map vẫn là graybox gameplay cơ bản với 5 guard và chuỗi objective chung; các trục/props mới tăng cảm giác bảo tàng nhưng không thay thế việc playtest Gold/QA trong môi trường Godot đầy đủ.

## 2026-11-04 — Thay block Museum bằng prop scene có cấu trúc

- **Nội dung:** Thay các hộp placeholder bằng 12 scene prop tái sử dụng, gồm display case kính/khung/đế/artifact có collision, tượng bust, bệ, tranh abstract và landscape, quầy lễ tân, bench, planter, security station, archive shelf, cột và rope barrier. Thêm collision shape sát hình học chính, `NavigationObstacle3D` avoidance cho vật cản lớn, và đèn chiếu điểm.
- **File mới:** `maps/museum/scenes/props/display_case.tscn`, `statue_bust.tscn`, `art_pedestal.tscn`, `painting.tscn`, `painting_landscape.tscn`, `reception_desk.tscn`, `museum_bench.tscn`, `plant_pot.tscn`, `security_station.tscn`, `archive_shelf.tscn`, `rope_barrier.tscn`, `decorative_column.tscn`.
- **File cập nhật:** `maps/museum/scenes/museum_heist.tscn`, `maps/museum/README.md`, `maps/museum/docs/MUSEUM_HEIST.md`, `docs/ai/PROJECT_CONTEXT.md`, `MODULE_INDEX.md`, `FEATURE_REGISTRY.md`, `TESTING_GUIDE.md`.
- **Module liên quan:** Scene Museum-only; reused shared chair scene; không đổi shared gameplay systems, map catalog, objective chain, guard routes hoặc LevelCatalog.
- **Collision/navigation:** StaticBody props dùng collision layer mặc định 1, nằm trong `GuardVision.sight_mask = 3`. Props chính thêm avoidance obstacles; navmesh thủ công vẫn chưa được rebake/carve, do đó guard pathfinding chưa được xác minh runtime.
- **Kiểm tra:** `python tools/ci/check_layout.py` — **đã chạy sau chỉnh sửa cuối; passed với 527 runtime references**. Godot import, full tests, `map_flow.gd`, CI Bash scripts và screenshot/playtest chưa chạy vì không có Godot executable trong PATH.
- **Giới hạn:** Geometry là low-poly primitive composition, không phải asset/texture artwork ngoài. Bảo toàn flow hiện tại; cần kiểm tra trực tiếp trong Godot độ trong của kính, collision, vision, guard avoidance/pathing, player clearances và hình ảnh từ góc nhìn thứ nhất.
