# Làm việc theo từng map

Nhóm phát triển các map độc lập trong cùng một project Godot. Người chơi chọn map từ menu; các map không cần nối tiếp nhau. Mỗi thành viên phụ trách nội dung và kiểm thử của map riêng, cùng sử dụng AI NPC, điều khiển, tương tác và HUD.

Cấu trúc hiện tại đã tích hợp bản cập nhật `main` tại `504ce2e`, gồm phần hoàn thiện thư viện và navmesh 1.244 đa giác. Xem [biên bản đồng bộ](MAIN_SYNC.md) để đối chiếu nội dung nguồn và kết quả kiểm tra mới.

## Cấu trúc hiện hành

```text
shared/                 scene, script và tài nguyên dùng chung
features/               inventory, stamina, nhiệm vụ, checkpoint, puzzle, security
maps/tutorial/          map tutorial hiện có và công cụ đo bản đồ
maps/library/           map thư viện, expansion, logic, test, công cụ và tài liệu
maps/intelligence/      map tình báo K17 V1 của Nguyễn Đình Phiên
maps/bank/              ví dụ thư mục cho map mới, chưa có nội dung chơi
maps/museum/            ví dụ thư mục cho map mới, chưa có nội dung chơi
templates/map/          khung thư mục để sao chép khi bắt đầu một map
tests/                  test dùng chung và runner tích hợp
tools/                  CI, benchmark và kiểm tra scene lifecycle
docs/                   hướng dẫn chung và bằng chứng lịch sử
```

`bank` và `museum` chưa được phân công cho thành viên và chưa đăng ký trong menu. `intelligence` đã có V1 chơi được: bốn NPC dùng chung, giấy thông hành, checkpoint, hồ sơ và đếm ngược rút lui. Xem [README K17](../../maps/intelligence/README.md). Tutorial được giữ làm mẫu và phục vụ kiểm thử, không mặc định thay thế một trong năm map của nhóm.

## Phạm vi dùng chung

- `shared/scenes/player/player.tscn` và `shared/scripts/player/`: điều khiển, camera, tiếng bước chân và tìm đối tượng tương tác.
- `shared/scenes/npc/guard.tscn` và `shared/scripts/npc/`: AI, thị giác, thính giác và tuần tra.
- `shared/scripts/interaction/interactable.gd`: nền tảng cho đối tượng dùng bằng phím E.
- `shared/scripts/ui/`: HUD, menu, captions và giao diện cài đặt.
- `shared/scripts/game/`: danh sách map, pause, restart và chuyển về menu.
- `shared/scripts/noise/`, `stealth/`, `utilities/`, `presentation/`: hạ tầng được các hệ thống trên sử dụng.

`features/` là nơi chứa các cơ chế có thể lựa chọn. Player hiện có các cờ `use_stamina` và `use_inventory`; tắt chúng sẽ giữ hành vi tutorial. Các lớp feature vẫn được đóng gói để những scene dùng chung có thể tham chiếu chúng. Đây là cơ chế bật/tắt theo map, chưa phải hệ thống plugin có thể xóa từng thư mục khỏi project.

## Thư mục của một map

| Thư mục | Nội dung |
|---|---|
| `scenes/` | Scene chính và các scene con riêng của map |
| `scripts/` | Cơ chế, quy tắc nhiệm vụ và điều phối riêng |
| `resources/` | Navmesh và dữ liệu cấu hình |
| `assets/` | Model, ảnh, vật liệu và âm thanh riêng |
| `tests/` | Kiểm thử của map |
| `tools/` | Builder, bake navmesh và công cụ riêng |
| `docs/` | Thiết kế, log, ảnh và kết quả đo; có `.gdignore` để Godot bỏ qua |

Mỗi map có một scene chính làm điểm vào. Scene đó instance player/guard dùng chung, khai báo navmesh của chính mình và chứa các hệ thống scene-local cần dùng. Node thuộc nhóm `player`, `guards`, `game_flow` hoặc các manager phải được giải phóng khi rời map. Hệ thống hiện tại giả định chỉ một map hoạt động tại một thời điểm.

## Thêm một map

1. Sao chép `templates/map/` thành `maps/<map_id>/`. Chỉ sao chép thư mục bên trong, không chép `templates/.gdignore` vào gốc map mới.
2. Tạo scene chính trong `scenes/`; có thể tham khảo tutorial. Tạo hình học, collision và navmesh riêng; giữ player/NPC là instance dùng chung.
3. Đặt cơ chế đặc trưng ở `scripts/`. Đối tượng tương tác kế thừa `Interactable` và triển khai prompt, điều kiện, hành động.
4. Khi dùng HUD nhiệm vụ, thêm `ObjectiveManager` từ `features/objectives/` và khai báo mảng `objectives` của map. Mảng rỗng dùng nhiệm vụ tutorial mặc định để tương thích; map mới phải cung cấp dữ liệu riêng.
5. Khi dùng checkpoint, thêm manager, điểm hồi sinh và các node `checkpoint_state` theo giao diện feature. Dữ liệu trong group được giữ theo scene, không phải save game ra đĩa.
6. Nếu cần bảng trạng thái riêng, thêm subclass `MapHudProvider` như mục tiếp theo.
7. Sau khi scene chơi được, thêm một entry `{id, title, scene, description}` vào `shared/scripts/game/level_catalog.gd`. Menu tạo nút từ catalog; không có yêu cầu mở khóa tuần tự.
8. Viết test trong `maps/<map_id>/tests/`. Đăng ký suite có `run(host)` trong `tests/test_scene.gd` để CI thực sự chạy nó; việc đặt file trong thư mục chỉ làm nó được biên dịch, chưa tự chạy test hành vi.
9. Chạy kiểm tra import, script, test, đổi map và export trước khi gửi PR. Thêm scene mới vào kiểm tra tích hợp/catalog nếu có tiêu chí riêng.

## Kết nối HUD với nội dung map

`MapHudProvider` nằm ở `shared/scripts/ui/map_hud_provider.gd`. Một map có thể gắn đúng một subclass vào scene chính. `_ready()` của subclass gọi `super()` để đăng ký group.

```gdscript
extends MapHudProvider

func _ready() -> void:
    super()

func get_status_lines() -> Array[String]:
    return ["Objective: retrieve the intelligence file"]
```

Các hàm tùy chọn:

- `get_status_lines()`: dữ liệu văn bản cho trạng thái riêng của map.
- `get_status_bbcode(accent, done, todo)`: định dạng panel; mặc định dùng các dòng văn bản trên.
- `get_exit_hint(exit)`: lý do chưa thể rời map; trả chuỗi rỗng để dùng thông báo đã cấu hình tại cửa.
- `get_result_lines()`: các dòng tổng kết bổ sung vào màn thắng chung; mặc định rỗng.

HUD vẫn lấy mục tiêu từ `ObjectiveManager`, lời nhắc từ `PlayerInteractor`, kết quả từ `GameFlow`/`GameMenus`. Trong map thư viện, `EscapeRoutes` cung cấp WAYS OUT, POWER và thông báo từ chối; HUD chung không tham chiếu trực tiếp lớp riêng này. Map mới có thể cung cấp trạng thái khác mà không sửa HUD thư viện.

## Kiểm tra và build

Kết quả lần tổ chức lại ban đầu được ghi trong [VALIDATION.md](VALIDATION.md); lần cập nhật từ `main` ngày 26/10/2026 được ghi riêng trong [MAIN_SYNC.md](MAIN_SYNC.md).

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/ci/check_scripts.gd
python tools/ci/check_layout.py
godot --headless --path . res://tests/test_scene.tscn
godot --headless --path . --script res://tools/qa_flow.gd
godot --headless --path . --script res://tools/map_flow.gd
```

Dùng Godot 4.7.2 official như project hiện tại. CI chạy các bước tương ứng trong `tools/ci/validate.sh`, `run_tests.sh`, `export_windows.sh`. Preset loại `tests/`, `tools/`, test/tool/docs trong map và `templates/` khỏi bản phát hành. Navmesh và scene con nằm trong thư mục map vẫn được đóng gói. Bước export còn tải menu và mọi map đã đăng ký trực tiếp từ PCK trong thư mục trống, giúp phát hiện tài nguyên thiếu mà source checkout có thể che lấp.

## Phối hợp và lịch sử

Mỗi người chủ yếu sửa `maps/<map_id>/`. Thay đổi `shared/`, `features/`, catalog, test runner hoặc build cần review vì có thể tác động map khác. Tránh nhân bản player/AI thành năm phiên bản độc lập. Giữ file `.uid` cùng script khi di chuyển bằng Git.

Các log, JSON, CSV, screenshot và báo cáo phase cũ là bằng chứng lịch sử. Một số câu lệnh/đường dẫn ghi trong chúng thuộc bố cục trước đây; dùng hướng dẫn hiện hành này và `docs/BUILD.md` để chạy project. File `path-migration.json` ghi đường dẫn cũ → mới và checksum trước di chuyển. Sắp xếp thư mục không thay đổi tác giả hoặc kết quả kiểm thử lịch sử.

`path-migration.json` là ảnh chụp của lần tổ chức lại ban đầu tại `3e11644`; `path-migration-main.json` ghi dữ liệu nguồn của lần cập nhật từ `main` tại `504ce2e`. Kiểm chứng lần cập nhật mới bằng:

```text
python tools/ci/check_layout.py --verify-migration --migration-manifest docs/architecture/path-migration-main.json
```

Lệnh này kiểm tra đủ file và checksum của dữ liệu nhị phân, UID, navmesh theo ảnh chụp đã chọn. Chỉnh sửa map hoặc tạo lại navmesh về sau có thể làm checksum khác. CI thường chỉ chạy `check_layout.py` để kiểm tra đường dẫn và ranh giới mã dùng chung, cho phép các map tiếp tục phát triển.
