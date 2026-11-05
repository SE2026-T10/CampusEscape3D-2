# Hướng dẫn kiểm thử

## Môi trường và lệnh cơ bản

Dùng **Godot 4.7.2 official stable** (hash `ed1daf0bf`), như khai báo trong `project.godot` và kiểm tra trong CI. Các lệnh chạy từ repository root, với executable Godot có trong `PATH`:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/ci/check_scripts.gd
python tools/ci/check_layout.py
godot --headless --path . --script res://tools/ci/check_map_contract.gd
godot --headless --path . res://tests/test_scene.tscn
godot --headless --path . --script res://tools/qa_flow.gd
godot --headless --path . --script res://tools/map_flow.gd
```

`check_layout.py` có thể cần Python 3; CI dùng `python3`. `validate.sh`, `run_tests.sh`, `export_windows.sh` là Bash scripts (CI chạy bằng `bash`); chúng ghi log vào `ci-logs/` và dùng biến môi trường `GODOT`.

## Lệnh kiểm tra và phạm vi

| Kiểm tra | Lệnh/entry point | Xác minh |
|---|---|---|
| Import project | `godot --headless --path . --editor --quit` | Import resource và script ở engine. |
| Biên dịch GDScript | `godot --headless --path . --script res://tools/ci/check_scripts.gd` | Tất cả script trong phạm vi checker biên dịch. |
| Runtime paths/layout | `python tools/ci/check_layout.py` | Tham chiếu resource/layout mà checker nhận biết. |
| HUD/exit map contract | `godot --headless --path . --script res://tools/ci/check_map_contract.gd` | Provider/exit integration và lifecycle contract. |
| Unit/integration suite | `godot --headless --path . res://tests/test_scene.tscn` | Các suite được preload và gọi trong `tests/test_scene.gd`; cần khoảng thời gian dài (CI ghi khoảng 17 phút). |
| Game flow thật | `godot --headless --path . --script res://tools/qa_flow.gd` | Scene transition thật: menu, play, pause/resume, restart, caught/respawn, win, menu/quit. |
| Chuyển map thật | `godot --headless --path . --script res://tools/map_flow.gd` | Mọi entry catalog, optional test scene, restart, rời map và lặp ba chu kỳ; kiểm tra scene/group/connection/node cleanup. |
| Windows PCK/package | Xem `tools/ci/export_windows.sh`, sau đó `check_pack.gd` theo flow CI | Export Windows, load map trực tiếp từ PCK trong thư mục trống và loại test/tools khỏi package. |

CI thực hiện `tools/ci/validate.sh` → `tools/ci/run_tests.sh` → export Windows; workflow nằm ở `.github/workflows/build.yml`. `run_tests.sh` ngoài full suite còn chạy `qa_flow.gd`, `map_flow.gd` và `maps/intelligence/tools/check_art.gd`. Chỉ export sau khi validate/tests qua.

## Suite hiện được runner gọi

`tests/test_scene.gd` trực tiếp gọi:

- Shared: `player_tests`, `navigation_tests`, `guard_tests`, `vision_tests`, `ai_state_tests`, `ai_behavior_tests`, `hearing_tests`, `loop_tests`, `objective_tests`, `game_flow_tests`, `level_design_tests`, `presentation_tests`, `performance_tests`, `qa_playthrough_tests`, `qa_regression_tests`, `hold_interaction_tests`, `map_selection_tests`.
- Expanded Library: `expanded_graybox_tests`, `expanded_ai_tests`, `expanded_mission_tests`, `expanded_baseline_tests`, `expanded_layout_expansion_tests`, `expanded_mechanics_tests`, `expanded_puzzle_tests`, `expanded_security_tests`, `expanded_escape_tests`, `expanded_hud_tests`, `expanded_e2e_tests`, `expanded_polish_tests`.
- K17: `k17_mission_tests`, `k17_security_tests`, `k17_test_mode_tests`, `k17_expansion_tests`, `k17_v4_tests`.

`tests/map_hud_provider_tests.gd` không nằm trong `tests/test_scene.gd`; CI chạy riêng qua `tools/ci/check_map_contract.gd`. Các file `maps/intelligence/tests/k17_navigation_tests.gd` và `k17_sabotage_tests.gd` hiện cũng không được preload/gọi trong `tests/test_scene.gd`. Không báo chúng là đã chạy khi chỉ chạy full runner; hãy kiểm tra cách gọi phù hợp hoặc đăng ký suite khi sửa runner.

## Kiểm thử theo phạm vi thay đổi

### Khi sửa `shared/` hoặc `features/`

1. Chạy import, `check_scripts.gd` và `check_layout.py`.
2. Chạy test suite liên quan đến contract (ví dụ player, AI, hearing, objectives, checkpoints, HUD).
3. Chạy full `tests/test_scene.tscn` nếu thay đổi hành vi shared/feature; kiểm tra cả map dùng feature đó.
4. Chạy `qa_flow.gd` và `map_flow.gd` khi đổi GameFlow, menu, scene lifecycle, group/signal hookup hoặc catalog.
5. Với contract HUD/exit, chạy `check_map_contract.gd`; với package/resource/export, theo dõi packaging flow CI.

### Khi sửa map riêng

1. Import/compile và `check_layout.py`.
2. Chạy test suite trong `maps/<id>/tests/` nếu runner đã đăng ký; nếu chưa, xác định lệnh của map/tool và báo rõ coverage.
3. Chạy `map_flow.gd` để kiểm tra scene catalog, restart và quay về menu nếu map đã đăng ký.
4. Chạy playthrough/tool chuyên biệt nếu thay đổi mục tiêu, puzzle, security hoặc escape; kiểm tra thủ công hình ảnh/độ khó nếu yêu cầu liên quan UX.

Museum hiện không có `maps/museum/tests/`; `map_flow.gd` kiểm tra chọn/restart/rời map và một số điều kiện guard, không thay thế gameplay test hoặc playtest thủ công. K17 có suites riêng; chỉ một phần đang được gọi bởi full runner như liệt kê phía trên.

## Chạy riêng một map

- Chạy game/menu: `godot --path .`.
- Mở scene map trực tiếp bằng `F6` trong Godot Editor hoặc chạy scene resource (ví dụ `godot --path . res://maps/museum/scenes/museum_heist.tscn`).
- Để kiểm tra map từ menu/catalog và lifecycle thay vì chỉ tải scene, dùng `godot --headless --path . --script res://tools/map_flow.gd`.
- Với K17, map có test variant riêng trong menu; kiểm tra `maps/intelligence/tools/` và `maps/intelligence/tests/` cho các checker/test chuyên biệt.

## Kết quả hiện tại của lần tạo tài liệu

Không có test Godot chạy trong phiên tạo tài liệu này: executable `godot`/`godot4` không được tìm thấy trong `PATH`. Các kết quả trong tài liệu lịch sử như `docs/architecture/VALIDATION.md` và `docs/architecture/MAIN_SYNC.md` là kết quả của lần chạy ghi trong chính tài liệu đó, không phải xác nhận mới của phiên này.
