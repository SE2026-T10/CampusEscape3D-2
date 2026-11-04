# Chỉ mục module

Các đường dẫn dưới đây tương đối từ repository root. “Dùng bởi/tác động” nêu consumer hoặc hành vi chính, không phải danh sách đầy đủ mọi call site. Scene của mỗi map có thể cấu hình cùng module theo cách khác nhau.

## Runtime và điều phối

| Module | Source và scene liên quan | Vai trò, dependency và consumer | Phạm vi ảnh hưởng khi đổi |
|---|---|---|---|
| `LevelCatalog` | `shared/scripts/game/level_catalog.gd` | Danh sách id, title, scene, mô tả và test scene tùy chọn; được `MainMenu`, map-selection tests và map-flow QA đọc. | Menu, tải map, restart/test-map coverage và thứ tự hiển thị. |
| `MainMenu` | `shared/scripts/ui/main_menu.gd`; `shared/scenes/ui/main_menu.tscn` | Dựng nút map từ `LevelCatalog`, tải scene, mở settings và thoát game. | Điểm vào ứng dụng, chọn map, keyboard focus và scene transition. |
| `GameFlow` / `GameStateMachine` | `shared/scripts/game/game_flow.gd`; `shared/scripts/game/game_state_machine.gd` | State cấp game, pause/resume, focus mất, caught/respawn, victory/failure, restart/menu; nghe `StealthDirector`, `ObjectiveManager`, yêu cầu thay scene qua SceneTree. | Tất cả map có GameFlow; pause, win/loss, mouse, restart và lifecycle. |
| `GameMenus` / settings | `shared/scripts/ui/game_menus.gd`, `shared/scripts/ui/settings_panel.gd`, `shared/scripts/game/game_settings.gd`; menu dùng `shared/scenes/ui/main_menu.tscn`, còn GameMenus được instance trong level scenes | UI điều khiển state do `GameFlow` sở hữu; game settings áp dụng âm lượng, captions và kích thước giao diện. | Menu chính và từng map; kiểm tra scene-local script override trước khi đổi API. |

## Player và tương tác

| Module | Source và scene liên quan | Vai trò, dependency và consumer | Phạm vi ảnh hưởng khi đổi |
|---|---|---|---|
| `FirstPersonPlayer` | `shared/scripts/player/player.gd`; `shared/scenes/player/player.tscn` | CharacterBody góc nhìn thứ nhất: movement/crouch/look, spawn/respawn, điểm visibility/noise; điều phối `Stamina` và `Inventory` nếu map bật. | Mọi map dùng scene player; movement, detection, noise, interaction reach và respawn. |
| `PlayerInteractor` / `Interactable` | `shared/scripts/player/player_interactor.gd`; `shared/scripts/interaction/interactable.gd`; player scene | Raycast từ camera, focus/prompt, instant hoặc hold E; gọi `can_interact()`/`interact()` trên feature/map object. | Mọi pickup/door/puzzle/interactable và HUD prompt; không đổi contract nếu map cũ chưa được kiểm tra. |
| `PlayerNoise` / feedback | `shared/scripts/player/player_noise.gd`, `shared/scripts/presentation/player_feedback.gd` | Chuyển stride/movement thành footsteps và feedback; noise được gửi tới `NoiseSystem`. | Nghe của guard, captions/feedback và nhịp gameplay trong các map dùng noise. |
| `PlayerInventory` / `ItemCatalog` | `features/inventory/player_inventory.gd`, `features/inventory/item_catalog.gd`; node `Inventory` trong player scene | Slot item, journal, use/throw, checkpoint state; được pickup, storage, door/tool mechanism và HUD dùng. | Map bật inventory (Expanded Library, K17); item IDs và interaction/UI contract. |
| `PlayerStamina` | `features/stamina/player_stamina.gd`; node `Stamina` trong player scene | Giới hạn sprint/regen; được `FirstPersonPlayer` gọi mỗi physics frame và HUD đọc. | Map bật stamina; tốc độ/thoát đuổi và HUD. |

## NPC, perception và stealth

| Module | Source và scene liên quan | Vai trò, dependency và consumer | Phạm vi ảnh hưởng khi đổi |
|---|---|---|---|
| `Guard` | `shared/scripts/npc/guard.gd`; `shared/scenes/npc/guard.tscn` | Actor dùng chung: navigation, avoidance, state tick, movement, patrol, hearing/vision, checkpoint tùy cấu hình. | Tất cả map có guard; AI, navigation, catch/reset và scene guards. |
| `GuardStateMachine` và các state | `shared/scripts/npc/ai/guard_state_machine.gd`, `guard_state.gd`, `patrol_state.gd`, `investigate_state.gd`, `chase_state.gd` | Ưu tiên perception rồi chuyển PATROL → INVESTIGATE/CHASE, INVESTIGATE → PATROL/CHASE, CHASE → INVESTIGATE. Được `Guard` cung cấp actor/snapshot. | Hành vi guard chung, stealth loop và các test state/behavior. |
| `GuardPerception` | `shared/scripts/npc/ai/guard_perception.gd` | Snapshot dữ liệu sighting/noise tách state machine khỏi reference player trực tiếp. | Contract nội bộ giữa guard sensors và AI state machine. |
| `GuardVision` | `shared/scripts/npc/guard_vision.gd` | FOV, line of sight, detection meter/awareness, target points và last known position; đóng góp sighting cho `Guard.build_perception()`. | Mọi guard có vision; stealth detect, chase và hiding. |
| `GuardHearing` / noise hub | `shared/scripts/npc/guard_hearing.gd`, `shared/scripts/noise/noise_event.gd`, `noise_system.gd`, `noise_maker.gd` | Noise event có lifetime/radius; `NoiseSystem` phát cho `noise_listeners`, hearing lọc range/occlusion/stale/duplicate và báo vị trí ước lượng qua `Guard.hear_noise()`. | Footsteps, distractions, tiếng động môi trường và mọi map dùng hearing. |
| Patrol/navigation | `shared/scripts/npc/patrol_route.gd`, `patrol_point.gd`, `navigation_probe.gd`; `shared/scripts/utilities/navigation_utils.gd` | Route/marker do scene map cấp; guard chờ, điều tra và điều hướng trên navmesh map. | Patrol routes, navigation readiness và tính hợp lệ của navmesh từng map. |
| `StealthDirector` / hiding | `shared/scripts/stealth/stealth_director.gd`, `hiding_spot.gd` | Tổng hợp status player, xác định catch, respawn/reset và freeze khi escape; hiding spot tham gia hidden/concealment. | Tất cả map có stealth director; catch timing, checkpoint respawn và trạng thái HUD. |

## Objectives, checkpoints và HUD

| Module | Source và scene liên quan | Vai trò, dependency và consumer | Phạm vi ảnh hưởng khi đổi |
|---|---|---|---|
| `ObjectiveManager` | `features/objectives/objective_manager.gd` | Quản lý objective tuyến tính hoặc đồ thị (requirements, optional, hidden), lưu/khôi phục progress, phát `level_completed`; được trigger, pickup, exit, HUD và GameFlow dùng. | Luồng nhiệm vụ của tutorial, library, museum, K17; UI, checkpoint, exits và test data. |
| Objective interactables | `features/objectives/objective_trigger.gd`, `access_card.gd`, `access_door.gd`, `exit_door.gd` | Kết nối vùng kích hoạt, card/door và escape với manager; ExitDoor có thể là walk-through, yêu cầu power/extra objective/unlock và checkpoint state. | Các map instance các feature này; objective contract và thắng map. |
| `CheckpointManager` | `features/checkpoints/checkpoint_manager.gd`, `checkpoint.gd` | Snapshot objective, `checkpoint_state` nodes và guard tùy cấu hình; restore sau `StealthDirector.level_reset`. | Các map đặt checkpoint; inventory/door/security mission state và respawn. |
| `MapHudProvider` / `ObjectiveHud` | `shared/scripts/ui/map_hud_provider.gd`, `objective_hud.gd`, `stealth_hud.gd`; scene UI được level scenes instance | HUD dùng chung đọc objective/interactor/checkpoint/inventory; provider tùy chọn đưa status/hint/results map-specific. | HUD của mọi map và API được provider implement. |
| Provider Expanded Library | `maps/library/scripts/escape/escape_routes.gd` | Kế thừa `MapHudProvider`; trả trạng thái đường thoát, power/exit info cho HUD/exit. | HUD và escape logic Expanded Library. |
| Provider K17 | `maps/intelligence/scripts/mission_controller.gd` | Kế thừa `MapHudProvider`; mission state K17 được các script map lấy qua `find_for()`, HUD/menus dùng thông tin mission. | Chỉ K17 và biến thể test của nó, nhưng phụ thuộc base provider chung. |

## Puzzle, an ninh, presentation và map modules

| Module | Source và scene liên quan | Vai trò, dependency và consumer | Phạm vi ảnh hưởng khi đổi |
|---|---|---|---|
| Inventory items/storage | `features/inventory/item_pickup.gd`, `item_storage.gd`, `document_pickup.gd`, `tool_mechanism.gd`, `thrown_item.gd` | Pickup, shelf, journal documents, tool interaction và distraction noise dựa vào `PlayerInventory`, `ItemCatalog`, `Interactable`, `NoiseSystem`. | Chủ yếu map có inventory/puzzles; item persistence và throw behavior. |
| Puzzle / security reusable | `features/puzzles/*.gd`, `features/security/*.gd` | Bao gồm code lock, breaker/power, alarm/circuit và security camera; contract tương tác/objective/noise/HUD tùy node. | Map nào instance chúng; camera/alarm/puzzle feedback và mission state. Kiểm tra từng scene trước khi giả định đã dùng. |
| Audio/presentation | `shared/scripts/presentation/audio_director.gd`, `sound_bank.gd`, `guard_presentation.gd`, `ambient_emitter.gd`, `player_feedback.gd`; `shared/scripts/ui/sound_captions.gd` | Âm thanh/caption, state feedback và âm môi trường; lắng nghe gameplay signals. | Tất cả scene có AudioDirector; UX/feedback, không phải logic objective. |
| Expanded Library map | `maps/library/scenes/expanded_library.tscn`, `expanded_library_expansion.tscn`; `maps/library/scripts/escape/`; `maps/library/tests/expanded_*_tests.gd` | Ghép map chính và expansion, dùng shared player/guard/features, có map provider và escape routes. | Riêng Expanded Library và các test map-specific. |
| K17 map | `maps/intelligence/scenes/intelligence_k17.tscn`, `intelligence_k17_test.tscn`; `maps/intelligence/scripts/`, `resources/`, `tests/` | Scene nhiều sector, dùng shared player/guard base cùng nhiều controller/security/presentation riêng; test variant thay đổi chế độ guard. | K17 và test variant; kiểm tra script kế thừa/cast sang K17MissionController trước khi đổi provider. |
| Museum/tutorial map | `maps/museum/scenes/museum_heist.tscn`; `maps/museum/scenes/props/*.tscn`; `maps/tutorial/scenes/library_graybox.tscn` | Tutorial là fixture của shared tests. Museum đặt reusable local props (display case, sculpture, paintings, reception/security furniture, archive shelf, planter, column, rope barrier) và dùng shared player/guard/objective systems. | Museum props có collision layer 1 và obstacle avoidance; `museum_navmesh.tres` vẫn là polygon thủ công chưa carve quanh props; chưa có automated gameplay suite riêng. |
| Test/CI registry | `tests/test_scene.gd`, `tests/*.gd`, `maps/library/tests/*.gd`, `maps/intelligence/tests/*.gd`, `tools/ci/`, `tools/map_flow.gd`, `tools/qa_flow.gd` | `test_scene.gd` preload và gọi suites; tools CI kiểm tra import/scripts/layout/contracts/pack; flow tools chuyển scene thật. | Mức độ bao phủ và tiêu chí merge/release; file test không được runner gọi không tự chạy trong full suite. |

Xem [`ARCHITECTURE.md`](ARCHITECTURE.md) để biết luồng giao tiếp; [`FEATURE_REGISTRY.md`](FEATURE_REGISTRY.md) để xem trạng thái/map/test của từng nhóm tính năng.
