# Danh mục tính năng

Trạng thái biểu thị mức độ triển khai trong source hiện tại, không phải xác nhận chất lượng sản phẩm. `COMPLETE` có nghĩa phạm vi được nêu đã có implementation và đường kiểm chứng tương ứng; không thay cho playtest/đánh giá phát hành. `PARTIAL` nghĩa có phần chơi được nhưng giới hạn rõ dưới đây. `PLANNED` nghĩa chưa có implementation hiện hành.

## Core Systems

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Chọn map và load scene — COMPLETE | `shared/scripts/game/level_catalog.gd`, `shared/scripts/ui/main_menu.gd`, `shared/scripts/game/game_flow.gd` | Bốn map catalog và K17 test variant; `tests/map_selection_tests.gd`, `tools/map_flow.gd`. | Catalog là danh sách runtime; thêm map cần scene hợp lệ và coverage chuyển map. |
| Game lifecycle — COMPLETE | `shared/scripts/game/game_flow.gd`, `game_state_machine.gd`, `shared/scripts/ui/game_menus.gd` | Tất cả map; `tests/game_flow_tests.gd`, `tests/qa_playthrough_tests.gd`, `tools/qa_flow.gd`, `tools/map_flow.gd`. | Scene-specific menu có thể override script; kiểm tra từng map trước thay đổi menu/state. |
| Player movement/interaction — COMPLETE | `shared/scripts/player/`, `shared/scripts/interaction/interactable.gd` | Tất cả map dùng player; `tests/player_tests.gd`, `tests/hold_interaction_tests.gd`, suites gameplay. | Không có jump; API E/hold/prompt ảnh hưởng mọi interactable. |
| Navigation/patrol — COMPLETE | `shared/scripts/npc/patrol_route.gd`, `patrol_point.gd`, `navigation_utils.gd`, `shared/scripts/npc/guard.gd` | Scene map cung cấp navmesh/route; `tests/navigation_tests.gd`, `tests/guard_tests.gd`, library/K17 suites, `tools/map_flow.gd`. | Navmesh/route phải đúng map; thay navigation có thể ảnh hưởng tất cả guards. |
| Audio/settings/presentation — COMPLETE | `shared/scripts/presentation/`, `shared/scripts/game/game_settings.gd`, `shared/scripts/ui/settings_panel.gd` | Map có AudioDirector; `tests/presentation_tests.gd`, `tests/qa_regression_tests.gd`. | UX/audio asset không được bao phủ hoàn toàn bởi headless test. |

## Player Systems

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Crouch/visibility — COMPLETE | `shared/scripts/player/player.gd`: body height, camera, stance, `get_visibility_factor()` | GuardVision và PlayerNoise; `tests/player_tests.gd`, `tests/vision_tests.gd`, suites AI. | Stance ảnh hưởng visibility/noise; sửa đồng bộ cả hai. |
| Footstep/noise emission — COMPLETE | `shared/scripts/player/player_noise.gd`, `shared/scripts/noise/noise_system.gd`, `noise_event.gd` | Tutorial, library, museum, K17 scenes; `tests/hearing_tests.gd`, `tests/loop_tests.gd`, `tests/ai_behavior_tests.gd`. | Mỗi map cần NoiseSystem và listeners phù hợp. |
| Stamina — COMPLETE, cấu hình theo map | `features/stamina/player_stamina.gd`, `FirstPersonPlayer.use_stamina` | Bật trong Expanded Library; `maps/library/tests/expanded_mechanics_tests.gd`. | Tắt nghĩa unlimited sprint; K17 README nêu stamina chưa bật. |
| Inventory/journal/distraction — COMPLETE, cấu hình theo map | `features/inventory/player_inventory.gd`, `item_catalog.gd`, pickup/storage/document/mechanism/thrown item scripts | Expanded Library và K17 dùng inventory; `expanded_mechanics_tests.gd`, `expanded_puzzle_tests.gd`, K17 mission/security tests. | Tutorial/Museum không bật inventory; checkpoint snapshot giữ slot, journal là knowledge; test map không đồng nghĩa mọi item logic đều có test riêng. |

## NPC & AI, Stealth Systems

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Guard patrol/investigate/chase — COMPLETE | `shared/scripts/npc/guard.gd`, `shared/scripts/npc/ai/` | Map có guard; `tests/ai_state_tests.gd`, `ai_behavior_tests.gd`, `guard_tests.gd`, `maps/library/tests/expanded_ai_tests.gd`. | Expanded security là cấu hình bổ sung; không đồng nghĩa state machine thứ hai. |
| Vision/detection — COMPLETE | `shared/scripts/npc/guard_vision.gd` | Guards; `tests/vision_tests.gd`, AI suites, library/K17 security tests. | Line of sight phụ thuộc layer/mask, nav/geometry map và visibility points. |
| Hearing/investigation — COMPLETE | `shared/scripts/npc/guard_hearing.gd`, `noise_system.gd`, `noise_event.gd` | Guards/noise listeners; `tests/hearing_tests.gd`, `ai_behavior_tests.gd`. | Hearing báo vị trí ước lượng; không giả định guard biết vị trí chính xác của nguồn noise. |
| Stealth status/capture/reset — COMPLETE | `shared/scripts/stealth/stealth_director.gd` | Tất cả map có stealth loop; `tests/loop_tests.gd`, `qa_playthrough_tests.gd`, K17 tests. | Hiding/expanded security tùy scene/config; custom mission failure có thể dùng GameFlow FAILED. |
| Hiding — COMPLETE trong các map đã cấu hình | `shared/scripts/stealth/hiding_spot.gd`, guard `expanded_security` | Expanded Library và K17 có hiding content; `expanded_security_tests.gd`, K17 security/expansion tests. | Hành vi guard phụ thuộc cấu hình `expanded_security` và việc người chơi có bị thấy khi vào chỗ nấp. |

## Objectives & Checkpoints

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Linear/graph objectives — COMPLETE | `features/objectives/objective_manager.gd`, `objective_hud.gd` | Tutorial/Museum linear; Library graph; K17 custom mission bên cạnh manager; `tests/objective_tests.gd`, `expanded_mission_tests.gd`, `expanded_puzzle_tests.gd`, `k17_mission_tests.gd`. | Graph mode kích hoạt khi objective có `requires` hoặc `optional`; dữ liệu từng map cần validate. |
| Access card/door/exit — COMPLETE cho scene đang dùng | `features/objectives/access_card.gd`, `access_door.gd`, `exit_door.gd`, `objective_trigger.gd` | Tutorial, Expanded Library, Museum, K17; objective, checkpoint và map e2e suites. | Mỗi scene cấu hình key/objective/power/exit riêng; Museum chỉ có một exit cơ bản. |
| Checkpoint and restore — COMPLETE cho shared contract | `features/checkpoints/checkpoint_manager.gd`, `checkpoint.gd` | Maps có manager/checkpoints; `tests/objective_tests.gd`, `expanded_escape_tests.gd`, K17 mission tests. | Chỉ node trong `checkpoint_state`/`checkpoint_guards` được snapshot qua contract; mission riêng cần logic riêng. |

## Security & Puzzles

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Puzzles, power network, locks — COMPLETE trong Expanded Library/K17 | `features/puzzles/*.gd`, `features/security/circuit_switch.gd`; map-specific puzzle code ở `maps/intelligence/scripts/` | Expanded Library puzzle/security suites; K17 `k17_security_tests.gd`, `k17_expansion_tests.gd`, `k17_v4_tests.gd`. | Không áp dụng cho Museum; xác minh instance trong scene thay vì chỉ dựa feature file có tồn tại. |
| Reusable security camera — COMPLETE as feature module | `features/security/security_camera.gd`; K17 có camera-specific scripts/scene | K17 security suites và art check; Library security coverage nếu scene instance. | Museum scene hiện không có camera; reusable implementation không chứng minh mọi map dùng nó. |
| Alarm/distraction mechanisms — COMPLETE in configured maps | `features/puzzles/security_alarm.gd`, inventory distraction scripts, K17 mission scripts | Library/K17; puzzle/security/mission tests. | Cách kích hoạt, reset và tác động cảnh vệ có cấu hình theo map. |

## Map-specific Features

| Map / trạng thái | Implementation | Dependencies, tests | Giới hạn / note |
|---|---|---|---|
| Library Tutorial — COMPLETE như tutorial/fixture | `maps/tutorial/scenes/library_graybox.tscn`; công cụ ở `maps/tutorial/tools/` | Shared player/guard/objectives/checkpoints; nhiều root tests, `tools/qa_flow.gd`. | Fixture hướng dẫn; không phải map member mới. |
| Expanded Library — COMPLETE về gameplay được triển khai; playtest còn mở | `maps/library/scenes/expanded_library.tscn`, `expanded_library_expansion.tscn`, `maps/library/scripts/escape/` | Shared systems, features; mọi suite `maps/library/tests/expanded_*_tests.gd`, được runner preload. | Thời lượng/mục tiêu thiết kế cần playtest; builder có giới hạn lịch sử theo `maps/library/README.md`. |
| Museum Heist — PARTIAL graybox playable | `maps/museum/scenes/museum_heist.tscn`, `resources/museum_navmesh.tres` | Shared player/guard/noise/objectives/exit; kiểm tra gián tiếp trong `tests/map_selection_tests.gd` và `tools/map_flow.gd`. | Không có `maps/museum/tests/` hay script riêng hiện tại; 5 guards, thẻ, cửa và một exit; không có artifact/vault/camera/puzzle. `maps/museum/README.md` đã cũ. |
| K17 — COMPLETE cho flow/feature hiện được mô tả; cần playtest cho xác nhận trải nghiệm | `maps/intelligence/scenes/intelligence_k17.tscn`, `scripts/`, `resources/`, `tests/`, `tools/` | Shared systems + provider/controller K17; `k17_mission_tests.gd`, `k17_security_tests.gd`, `k17_test_mode_tests.gd`, `k17_expansion_tests.gd`, `k17_v4_tests.gd`; `tools/ci/run_tests.sh` gọi art check. | Map README mô tả nhiều iteration; xác minh source/scene hiện tại khi sửa cơ chế. `k17_navigation_tests.gd` và `k17_sabotage_tests.gd` hiện không được gọi từ `tests/test_scene.gd`. |
| Bank — PLANNED | `maps/bank/README.md` | Không có runtime scene/catalog/test. | Khung thư mục; không đăng ký menu. |

## UI & Presentation

| Tính năng / trạng thái | Mô tả và source chính | Dependencies, map sử dụng, tests | Giới hạn đã biết |
|---|---|---|---|
| Objective/stealth HUD — COMPLETE | `shared/scripts/ui/objective_hud.gd`, `stealth_hud.gd`, `map_hud_provider.gd` | Các level scenes; `tools/ci/check_map_contract.gd` chạy `tests/map_hud_provider_tests.gd`, `expanded_hud_tests.gd`, K17 art check. | Map-specific panel cần provider; HUD chung không biết route logic của từng map. |
| Menu, captions, feedback — COMPLETE | `shared/scripts/ui/`, `shared/scripts/presentation/` | Main menu và level scenes; `tests/presentation_tests.gd`, QA flow. | Visual/accessibility review không được chứng minh hoàn toàn bởi headless tests. |
