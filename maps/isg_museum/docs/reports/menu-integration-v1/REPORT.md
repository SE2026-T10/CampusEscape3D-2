# ISG Museum — tích hợp menu chính

Ngày kiểm tra: 17/11/2026. Nhánh `hgmanh-work`. Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility.

ISG Museum đã được đăng ký sau K17 trong menu Campus Escape 3D. F5 vẫn mở menu chung; có hai lựa chọn **ISG Museum — Phi vụ bảo tàng** và **ISG Museum — Chỉnh map không bảo vệ**, với mô tả theo yêu cầu. Bản thường giữ 9 guard, bản chỉnh map giữ 0 guard; cả hai giữ N0, tiếp đón và luật hợp đồng/vé.

## Thay đổi

| File | Nội dung |
|---|---|
| `shared/scripts/game/level_catalog.gd` | ID `isg_museum`, scene thường và scene chỉnh map; giữ các entry cũ và thứ tự trước Museum. |
| `tests/map_selection_tests.gd` | Probe navigation Museum, kiểm tra từng manager theo khả năng của map; kiểm tra callback riêng, cả hai biến thể, singleton và giải phóng qua nhiều lần tải. Giữ kiểm tra focus/scroll ở 1280×720, 1024×768 và bốn mức UI scale. |
| `tests/map_scene_checks.gd` và UID | Helper QA dùng chung cho suite chọn map và runner scene flow: tìm manager thuộc scene, đếm từng callback đúng target/method, giữ contract của thư viện/K17. |
| `tools/map_flow.gd` | Tạo tiến trình Museum bằng `accept_contract()` và `grant_ticket()`; kiểm tra reset hợp đồng/vé/hiện vật, `take_key` là nhiệm vụ phụ, đúng scene sau Restart. Thêm lượt Resume và kiểm cursor. |
| `maps/isg_museum/tools/capture_menu_integration.gd` và UID | Capture native bắt đầu từ entry scene F5, chọn bằng GUI chuột/bàn phím; kiểm N0, quiz/vé, Pause/Resume/Restart/Menu trong cả hai chế độ. |
| `maps/isg_museum/README.md`, `docs/README.md` | Hướng dẫn F5 và liên kết báo cáo. |

Danh sách đầy đủ: [CHANGED_FILES.txt](CHANGED_FILES.txt). Không commit hoặc push.

## Scene và contract tích hợp

Hai PackedScene được tải và đưa vào SceneTree **trước khi đăng ký catalog**: [preflight.json](data/preflight.json), [log](logs/preflight.log).

- `ObjectiveManager` nằm trực tiếp dưới root. Museum không có `CheckpointManager` hoặc `AudioDirector`; test kiểm riêng từng khả năng, không thêm manager vào sản phẩm.
- `player_caught`: `GameFlow._on_player_caught` và `MuseumContract._caught`, mỗi callback đúng một connection.
- `level_reset`: `GameFlow._on_level_reset` và `museum_demo._restart_demo`, mỗi callback đúng một connection.
- `ObjectiveManager.level_completed → GameFlow._on_level_completed` cũng được kiểm đúng một lần.
- Probe `(18, 0.05, 35)` khớp X/Z điểm navmesh `(18, 0.45, 35)` ở cả hai scene, 402 polygon. Chênh Y 0.4 m là cao độ bề mặt navigation đã bake; không đổi navmesh.
- Restart: chưa nhận hợp đồng, chưa có vé/chưa quét vé, không có hiện vật và objective hoàn thành; nhiệm vụ hiện tại `escape`, `take_key` vẫn optional. Không ép hợp đồng ngẫu nhiên lượt sau khác lượt trước.

## Kết quả kiểm tra

Lệnh chạy từ repository root. `godot` dưới đây là `.local/godot/Godot_v4.7.2-stable_win64_console.exe`; Python là interpreter uv có sẵn tại `C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe`.

<!-- command-results:start -->
| Lệnh | Exit | Kết quả | Log |
|---|---:|---|---|
| `godot --headless --path . --editor --quit` | 0 | Import project | [log](logs/import-attempt-1.log) |
| `python -B tools/ci/check_layout.py` | 0 | 900 runtime references | [log](logs/layout-attempt-1.log) |
| `godot --headless --path . --script res://tools/ci/check_scripts.gd` | 0 | 371 scripts | [log](logs/scripts-attempt-4.log) |
| `godot --headless --path . --fixed-fps 60 --script res://.local/verify_menu_selection.gd` | 0 | 0 failure; suite đã đăng ký trong runner chung | [log](logs/selection.log) |
| `godot --headless --path . --script res://tools/map_flow.gd` | 0 | MAP FLOW PASSED — 184 checks / 36 loads / 3 cycles | [log](logs/flow.log) |
| `godot --headless --path . --fixed-fps 60 res://tests/test_scene.tscn` | 0 | All tests passed; chạy bổ sung ở bước thời gian cố định | [log](logs/runner.log) |
| `godot --headless --path . res://tests/test_scene.tscn` | 0 | All tests passed; đúng lệnh yêu cầu, không fixed-fps | [log](logs/runner-requested.log) |
| `godot --path . --script res://maps/isg_museum/tools/capture_menu_integration.gd` | 0 | 28 checks / 0 failures, native GUI | [log](logs/capture.log) |
<!-- command-results:end -->

Runner luồng menu chạy **3 vòng, 36 lượt tải scene, 184 kiểm tra**, gồm tutorial, Expanded Library, K17 thường/test và Museum thường/editing. Nodes ở menu giữ **57 → 57**, orphan **0 → 0**, root children **1 → 1**; connection không tăng, scene cũ được giải phóng. [flow.log](logs/flow.log).

Native GUI đạt **28 kiểm tra, 0 lỗi**. Bản thường được chọn bằng chuột; bản chỉnh map được chọn bằng Down từ tutorial qua từng nút rồi Enter. Hai chế độ mở được hội thoại N0, nhận hợp đồng, hỏi đáp tiếp đón và cấp vé sau ba đáp án đúng. Esc, Resume, Restart đúng biến thể và trở về menu đều đạt. [capture.log](logs/capture.log), [metadata](data/capture.json).

APPDATA được đặt vào thư mục QA riêng trong `.local/` **chỉ trong tiến trình con**; không đổi biến môi trường của shell hoặc setting người dùng.

## Ảnh trực tiếp từ Godot

Render native 1280×720, OpenGL Compatibility, NVIDIA GeForce RTX 3050 6GB Laptop GPU. Đã xem trực tiếp ảnh để xác nhận chữ, nút và scene hiển thị.

- [Menu đầu trang](images/01-menu-top.png); [menu có hai lựa chọn Museum và mô tả](images/02-menu-museum.png). Scroll/focus đưa mọi nút vào vùng nhìn thấy.
- [Museum thường mở từ menu](images/03-museum-normal-from-menu.png); [Museum chỉnh map mở từ menu](images/03-museum-editing-from-menu.png), có nhãn chế độ không bảo vệ.
- [Hội thoại N0 — thường](images/04-n0-contract-normal.png), [chỉnh map](images/04-n0-contract-editing.png).
- [Hỏi đáp tiếp đón — thường](images/05-receptionist-quiz-normal.png), [chỉnh map](images/05-receptionist-quiz-editing.png).
- [Pause — thường](images/06-pause-normal.png), [chỉnh map](images/06-pause-editing.png).

Capture chạy đúng entry scene trong `application/run/main_scene` và gửi InputEvent tới GUI thật; không phải thao tác nhấn F5 vật lý trong editor. Fixture chỉ di chuyển Player trong instance QA tới N0/tiếp đón và chọn đáp án qua API hiện có; không đóng băng guard hay lưu thay đổi vào sản phẩm. Các pause do cửa sổ mất focus chỉ được resume trước bước kiểm scene. [Lệnh capture thực tế](data/capture-command.json).

## Bảo toàn và giới hạn

<!-- protection-results:start -->
885/885 file runtime được bảo vệ giữ nguyên SHA-256; danh sách thay đổi ngoài catalog: []. [Hash trước](data/protected-runtime.json), [đối chiếu sau](data/protected-comparison.json).
<!-- protection-results:end -->

`shared/scripts/ui/main_menu.gd` và `project.godot` giữ nguyên byte; `run/main_scene` vẫn là `res://shared/scenes/ui/main_menu.tscn`. Không sửa scene/collider/navmesh, AI, rig/animation, NPC, vật phẩm hoặc luật gameplay; không bake navigation.

Log engine có lỗi môi trường Windows `Failed to read the root certificate store`, đã có trong [preflight trước sửa](logs/preflight.log). Runner chung có các warning fixture có chủ ý (`StuckGuard`, `NoRouteGuard`, arena thị giác không có navmesh). Không tắt hoặc che những thông báo này; kết quả assertion và exit code được ghi riêng. Các lần thử lỗi biên dịch tool capture và UID chưa import được giữ trong [results.json](data/results.json); đã sửa và chạy lại đạt.

Không có lỗi tích hợp còn tồn tại sau các lượt kiểm tra đạt. Phạm vi QA là menu/lifecycle và tương tác hợp đồng/vé; không tuyên bố đây là lượt chơi hoàn thành toàn bộ hợp đồng bằng input người chơi. Các nhãn debug guard nhìn xuyên tường trong ảnh bản thường là presentation hiện có của map, được giữ nguyên.
