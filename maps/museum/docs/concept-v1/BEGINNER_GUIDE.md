# Từ lần đầu mở Godot đến demo map bảo tàng

Hướng dẫn dành riêng cho Campus Escape 3D, map `museum`, nhánh `hgmanh-work`. Ngày 29/10/2026, scene `res://maps/museum/scenes/museum.tscn` đã mở rộng thành **bản hai tầng mốc D**, thay phòng thử cũ. Xem [bước 6 đã triển khai](../step-06-blockout.md) để chạy F6, kiểm tra tọa độ, sàn/lỗ thang, chìa/cửa và vị trí vật phẩm. Các ví dụ mốc A–C bên dưới vẫn được giữ để học quá trình dựng; bản triển khai hiện tại có thêm K, cửa khóa, ba guard, giữ màn hình bị bắt trước khi tải lại toàn map và đóng băng actor khi thắng.

## 1. Đích đến của từng bản

| Mốc | Nội dung | Điều kiện hoàn thành |
|---|---|---|
| A — đi lại | Một phòng sáng, sàn, tường và Player | F6 chạy được, đi và nhìn được, không xuyên sàn |
| B — lén lút | Thêm vật che, một bảo vệ và tuyến tuần tra | Bảo vệ đi vòng, phát hiện và đuổi; bệ đặc cản tầm nhìn |
| C — nhiệm vụ | Thêm tác phẩm, dây, điểm thoát và HUD | Thu thập đủ điều kiện rồi tương tác để thắng; chơi lại được |
| D — toàn map | Mở rộng đúng mặt bằng hai tầng | Đi được mọi tuyến, lên xuống được, ba bảo vệ hoạt động |
| E — trình bày | Vật liệu, mô hình, ánh sáng, âm thanh, xuất Windows | Người khác mở bản xuất và hoàn thành một lượt |

Hoàn thành từng mốc trước khi tăng phạm vi. Mốc A có thể thực hiện chỉ bằng editor. Mốc B cần cấu hình các script có sẵn. Mốc C có thêm một ít GDScript riêng của bảo tàng. Mốc C đầu tiên có thể dùng phòng nhỏ, tác phẩm giả bằng hộp và điểm thoát ở cửa; sau đó mới chuyển sang hai tầng.

## 2. Chuẩn bị và làm quen

1. Mở PowerShell tại `D:\IT\SE_GAME_3D`, chạy `git branch --show-current`. Kết quả cần là `hgmanh-work`. Chạy `git status` để biết có thay đổi đang làm.
2. Dùng cùng phiên bản Godot với nhóm. Trong `project.godot` và `docs/BUILD.md` hiện ghi **4.7.2 stable**. Kiểm tra executable nhóm đang dùng và Help → About trước khi đổi phiên bản; dùng preset renderer Compatibility của dự án.
3. Trong Godot Project Manager chọn **Import**, trỏ đến `D:\IT\SE_GAME_3D\project.godot`, mở project và đợi import xong. Không tạo project mới bên trong project hiện tại.
4. Nhấn **F5** chạy game hiện có. Chơi thử Library Tutorial để biết di chuyển, cúi, tương tác và cách bảo vệ phản ứng. Nhấn **F8** dừng chạy và trở lại editor.
5. Nếu map sẵn có báo lỗi đỏ hoặc không chạy, xử lý môi trường trước khi thêm map. Đọc dòng lỗi đầu tiên trong Debugger, tên file và số dòng.

Các vùng editor: **Scene** là cây thành phần của scene đang mở; **FileSystem** là file trong dự án; **Inspector** là thuộc tính của node đang chọn; **3D viewport** là vùng dựng không gian; **Output/Debugger** là nơi xem thông báo và lỗi.

| Từ | Hiểu đơn giản |
|---|---|
| Node | Một thành phần, như đèn, camera, vật thể hoặc bộ điều khiển |
| Scene `.tscn` | Một cụm node lưu thành tệp; một phòng, nhân vật hay cả map đều có thể là scene |
| Instance | Đặt một scene có sẵn vào scene khác, ví dụ kéo Player vào map |
| Mesh | Hình dạng nhìn thấy |
| Collision | Hình dạng vật lý chặn chuyển động / raycast; có mesh chưa chắc có collision |
| Navmesh | Vùng sàn AI có thể tìm đường đi |
| Script `.gd` | Logic chạy trên node |
| Signal | Thông báo từ thành phần này sang thành phần khác, ví dụ lấy tranh xong |

Godot giải thích cách ghép node thành scene trong [Nodes and Scenes](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html).

Phím mặc định hữu ích: Ctrl+S lưu, Ctrl+D nhân đôi node, F chọn vật thể để focus khi con trỏ ở viewport, F5 chạy project, F6 chạy scene đang mở, F8 dừng. Có thể chọn công cụ di chuyển/xoay trên thanh công cụ thay vì học mọi phím tắt ngay. Trong viewport 3D, giữ chuột phải và dùng WASD để bay quan sát. Một số laptop cần Fn cùng phím F.

## 3. Mốc A: một căn phòng đi được

### 3.1. Tạo scene

1. Scene → New Scene, chọn **3D Scene**.
2. Đổi tên root `Node3D` thành `Museum`.
3. Ctrl+S, lưu `res://maps/museum/scenes/museum.tscn`.
4. Chọn root, Add Child Node, tạo `Node3D` tên `Geometry`.

### 3.2. Tạo sàn

1. Chọn `Geometry`, thêm **CSGBox3D**, tên `Floor_Test`.
2. Trong Inspector đặt **Size** = `(12, 0.3, 12)`.
3. Transform → Position = `(0, -0.15, 0)`.
4. Bật **Use Collision**. Đảm bảo Collision Layer có lớp 1 `world`.
5. Để Scale = `(1, 1, 1)`; chỉnh Size của khối thay vì kéo Scale.

Sàn có mặt trên ở Y=0. Godot dùng Y làm chiều cao; X/Z nằm trên mặt đất. Trong dự án này quy ước 1 đơn vị dựng = 1 m.

CSG phù hợp cho giai đoạn dựng khối thử theo [hướng dẫn prototyping của Godot](https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html). Sau khi hình học ổn có thể thay bằng mô hình modular tối ưu hơn.

### 3.3. Tạo bốn tường

Nhân đôi hoặc thêm CSGBox3D, bật Use Collision cho mỗi tường. Có thể dùng các giá trị sau cho phòng thử:

| Tên | Size (X,Y,Z) | Position (X,Y,Z) |
|---|---|---|
| Wall_N | (12, 3, 0.3) | (0, 1.5, -6) |
| Wall_S | (12, 3, 0.3) | (0, 1.5, 6) |
| Wall_W | (0.3, 3, 12) | (-6, 1.5, 0) |
| Wall_E | (0.3, 3, 12) | (6, 1.5, 0) |

Bản đầu là phòng kín cũng được. Khi cần cửa, chia tường thành hai đoạn và để một khoảng trống 1.6 m, thay vì đặt một tường liền phía sau model cửa.

### 3.4. Thêm đèn và nhân vật

1. Thêm `DirectionalLight3D` dưới `Museum`; Rotation Degrees thử `(-60, -30, 0)`. Giai đoạn này ưu tiên sáng dễ nhìn.
2. Nếu vẫn tối, thêm `WorldEnvironment`, tạo resource `Environment`; chỉnh Background và Ambient Light để có ánh sáng nền. Đây là node sẽ dùng khi tinh chỉnh ánh sáng về sau.
3. Từ FileSystem kéo `res://shared/scenes/player/player.tscn` vào root `Museum`.
4. Đặt Player Position = `(0, 0.1, 4)`. Gốc Player nằm gần bàn chân, nên không đặt cả capsule chìm trong sàn.
5. Không cần tạo thêm Camera3D; Player đã có camera current.
6. Thêm node `Node` tên `GameFlow`; gắn script **đã có** `res://shared/scripts/game/game_flow.gd`. Để gắn script có sẵn, kéo tệp `.gd` từ FileSystem thả lên node tương ứng; không tạo bản sao script.
7. Thêm `CanvasLayer` tên `GameMenus`; gắn `res://shared/scripts/ui/game_menus.gd` để có menu pause/restart.
8. Chọn GameFlow, đặt Fallback Level Scene = `res://maps/museum/scenes/museum.tscn` cho rõ map dự phòng.
9. Lưu tất cả, chọn tab `museum.tscn`, nhấn **F6**. F5 vẫn chạy menu chính của cả nhóm.

Điều khiển game: WASD di chuyển, chuột nhìn, Shift chạy, C hoặc Ctrl cúi, E tương tác, Esc pause. Nhân vật hiện không có nhảy. Nếu chuột chưa điều khiển góc nhìn, click vào cửa sổ game; nếu đang pause hãy Resume.

**Đạt mốc A khi:** đi được trong phòng, xoay camera được, tường/sàn chặn được nhân vật, Esc có menu và Restart trở lại chính phòng thử.

## 4. Mốc B: một bảo vệ đi tuần

### 4.1. Đặt vật che

Thêm một CSGBox3D vào Geometry, Size `(2, 1.2, 1.2)`, Position `(0, 0.6, 0)`, bật Use Collision. Đây là chân đế đặc để thử cúi nấp. Camera cúi của Player ở khoảng 0.95 m, nhưng AI còn lấy nhiều điểm nhìn; phải thử thực tế thay vì chỉ so chiều cao camera.

### 4.2. Tạo vùng điều hướng

1. Thêm `NavigationRegion3D` dưới Museum.
2. Kéo `Geometry` vào làm con của NavigationRegion3D. Giữ Transform của Geometry và NavigationRegion3D ở gốc để tọa độ các khối không đổi.
3. Chọn NavigationRegion3D, tại Navigation Mesh chọn **New NavigationMesh**; click resource để chỉnh.
4. Source Geometry: chọn **Root Node Children**; Parsed Geometry Type: **Static Colliders**; Collision Mask: lớp 1 `world`. Sàn, tường, bệ phải nằm trong nhánh được parse và bật collision.
5. Giá trị bắt đầu tham khảo: Agent Radius `0.4`, Agent Height `1.8`, Agent Max Climb `0.2`, Agent Max Slope `40` độ. Đây là thông số thử; capsule bảo vệ bán kính 0.35 m, NavigationAgent hiện đặt radius 0.4 m.
6. Chọn NavigationRegion3D, dùng **Bake NavigationMesh / Bake NavMesh** trên thanh công cụ. Tên có thể hơi khác theo bản editor.
7. Quan sát vùng navmesh: cần phủ sàn đi lại, chừa khoảng quanh tường/bệ; không chỉ phủ nóc bệ. Nếu không thấy, chọn region và bật hiển thị navigation trong viewport/debug khi cần.
8. Lưu resource thành `res://maps/museum/resources/museum_navigation.tres` nếu editor cho lưu resource riêng. Không dùng navmesh của thư viện cho hình học mới.

Navmesh và collision là hai hệ riêng; khi dời bệ hay đổi tường cần bake lại. [Tài liệu navigation của Godot](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html) giải thích việc chọn nguồn hình học và chừa bán kính cho agent.

### 4.3. Tạo tuyến và ghép bảo vệ

1. Thêm `Node3D` tên `PatrolRoute_Test` dưới Museum, gắn script `shared/scripts/npc/patrol_route.gd`.
2. Thêm bốn con `Marker3D`, lần lượt `P1`…`P4`; gắn `shared/scripts/npc/patrol_point.gd` cho từng node để chỉnh Wait Time.
3. Đặt tọa độ lần lượt `(-3, 0.05, -3)`, `(3, 0.05, -3)`, `(3, 0.05, 3)`, `(-3, 0.05, 3)`. Chúng phải nằm trên sàn/navmesh, không trong bệ.
4. Đặt Wait Time khoảng 1–2 giây; node route bật Loop. Thứ tự node con trong cây là thứ tự tuần tra; không chỉ dựa vào tên P1/P2.
5. Kéo `shared/scenes/npc/guard.tscn` vào Museum, tên `Guard_Test`, đặt gần P1 `( -3, 0.1, -3 )`.
6. Chọn Guard_Test. Trong Inspector thuộc tính **Patrol Route**, dùng chọn node hoặc kéo `PatrolRoute_Test` từ cây Scene vào ô đó. Không kéo script vào thuộc tính này; nó cần tham chiếu tới node route.
7. Thêm `Node3D` tên `NoiseSystem`, gắn `shared/scripts/noise/noise_system.gd` để có sự kiện tiếng bước chân.
8. Thêm `Node` tên `StealthDirector`, gắn `shared/scripts/stealth/stealth_director.gd` để quản lý phát hiện/bị bắt.
9. Thêm `CanvasLayer` tên `StealthHud`, gắn `shared/scripts/ui/stealth_hud.gd` để hiển thị trạng thái.
10. F6 thử: đứng lộ ra để bị phát hiện, chạy vòng bệ, rồi cúi sau bệ. Để bảo vệ hoàn thành ít nhất hai vòng.

Không cần sửa mã AI chung. Trước tiên chỉnh vị trí waypoint, khoảng trống, tốc độ và thời gian dừng trên instance của map.

**Đạt mốc B khi:** bảo vệ đi đúng vòng; nhìn thấy thì truy đuổi; không nhìn xuyên bệ; có thể bắt người chơi. Nếu đứng yên, kiểm tra Patrol Route và navmesh trước khi sửa script.

## 5. Mốc C: lấy đồ và thắng — bản demo tối thiểu

### 5.1. Cây scene tham khảo

```text
Museum (Node3D; museum_demo.gd)
├── NavigationRegion3D
│   └── Geometry
├── DirectionalLight3D
├── WorldEnvironment
├── Player (instance)
├── PatrolRoute_Test (Node3D + patrol_route.gd)
│   ├── P1 (Marker3D + patrol_point.gd)
│   ├── P2
│   ├── P3
│   └── P4
├── Guard_Test (instance)
├── NoiseSystem (Node3D + noise_system.gd)
├── StealthDirector (Node + stealth_director.gd)
├── ObjectiveManager (Node + objective_manager.gd)
├── GameFlow (Node + game_flow.gd)
├── GameMenus (CanvasLayer + game_menus.gd)
├── ObjectiveHud (CanvasLayer + objective_hud.gd)
├── StealthHud (CanvasLayer + stealth_hud.gd)
└── Interactables (Node3D)
    ├── Painting_T1 (Area3D; demo_pickup.gd)
    ├── Painting_T2 (Area3D; demo_pickup.gd)
    ├── Painting_T3 (Area3D; demo_pickup.gd)
    ├── Rope (Area3D; demo_pickup.gd)
    └── EscapeWindow (Area3D; demo_exit.gd)
```

Thêm ObjectiveManager và ObjectiveHud theo loại node và đường dẫn ở trên; script nằm lần lượt trong `features/objectives/` và `shared/scripts/ui/`. Trên GameMenus đổi **Win Message** thành lời chúc mừng của map bảo tàng, vì mặc định vẫn là thư viện.

### 5.2. Khởi tạo nhiệm vụ riêng

Tạo script `res://maps/museum/scripts/museum_demo.gd`, gắn vào root Museum. Mã khởi đầu:

```gdscript
extends Node3D

func _ready() -> void:
	$ObjectiveManager.setup([
		{"id": &"take_t1", "title": "Lay tac pham T1", "requires": []},
		{"id": &"take_t2", "title": "Lay tac pham T2", "requires": []},
		{"id": &"take_t3", "title": "Lay tac pham T3", "requires": []},
		{"id": &"take_rope", "title": "Tim day thoat", "requires": []},
		{"id": &"escape", "title": "Thoat qua cua so",
		 "requires": [&"take_t1", &"take_t2", &"take_t3", &"take_rope"]},
	])
	$StealthDirector.player_caught.connect(_restart_demo)

func _restart_demo(_guard: Guard) -> void:
	$GameFlow.restart.call_deferred()
```

Các tên node trong cây phải khớp ký tự với `$ObjectiveManager`, `$StealthDirector`, `$GameFlow`. Thêm trường `hint`/`done` vào từng dictionary nếu muốn có chỉ dẫn/thông báo. Viết có dấu tiếng Việt trong chuỗi được; ví dụ không dấu nhằm dễ gõ lúc đầu.

Bản đơn giản này cho lấy tranh và dây theo thứ tự bất kỳ; đủ bốn vật phẩm thì nhiệm vụ escape mới active. Khi bị bắt, nó tải lại toàn scene, nên đồ và nhiệm vụ quay về ban đầu. Cách này tránh việc nhân vật hồi sinh nhưng tranh đã biến mất mà trạng thái nhiệm vụ không được khôi phục. Khi thêm checkpoint thật ở bước sau, bỏ kết nối `_restart_demo` và triển khai lưu/khôi phục đồng bộ.

### 5.3. Một vật phẩm tương tác được

Tạo scene mới có root **Area3D**, tên Painting. Thêm `MeshInstance3D` (BoxMesh) và `CollisionShape3D` (BoxShape3D). Root dùng script mới `res://maps/museum/scripts/demo_pickup.gd`:

```gdscript
extends Interactable

@export var objective_id: StringName = &"take_t1"

func _on_interact(_by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	enabled = false
	collision_layer = 0
	hide()
	return true
```

1. Root Area3D có script trên; không gắn script này vào MeshInstance3D.
2. Ví dụ mesh size `(1, 0.8, 0.08)`, shape `(1.1, 0.9, 0.15)`; đặt mesh và shape trùng nhau. Hộp bắt tương tác nên nhô ra khỏi mặt tường.
3. Chọn root, đặt **Prompt** = `Lay tac pham T1`, **Objective Id** = `take_t1`.
4. Lưu scene `res://maps/museum/scenes/painting_demo.tscn`, instance nó vào Interactables. Đặt cách mặt tường một chút và ngang tầm mắt.
5. F6, đến gần trong khoảng 2.2 m tính từ camera, nhìn vào tranh, bấm E. HUD phải đổi trạng thái, vật phẩm ẩn đi.
6. Nhân bản ba instance; đặt ID lần lượt `take_t1`, `take_t2`, `take_t3`. Một instance khác dùng `take_rope`, đổi mesh tạm thành hộp/ống nhỏ và Prompt phù hợp.
7. Khi nhân bản rồi sửa riêng resource Mesh/Shape/Material, chọn **Make Unique** nếu không muốn thay đổi lan sang instance khác.

Interactable đã tự đặt physics layer 4 (`interactable`, giá trị bitmask 8). Không nhầm số layer với giá trị bitmask. Area chỉ giúp bắt tương tác, không tạo vật cản vật lý. Bệ/tường đặc vẫn phải dùng CSG collision hoặc StaticBody3D.

Đây là nhấn E để lấy ngay. Cơ chế giữ E ba giây cần thêm logic theo dõi lúc nhấn/giữ/thả; PlayerInteractor hiện chỉ xử lý lần nhấn. Để sau khi bản nhấn E hoạt động ổn.

### 5.4. Điểm thoát

Tạo một Area3D có mesh dễ thấy và CollisionShape3D, gắn `res://maps/museum/scripts/demo_exit.gd`:

```gdscript
extends Interactable

func get_prompt(_by: Node) -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null:
		return "Thieu ObjectiveManager"
	if objectives.get_state(&"escape") != ObjectiveManager.State.ACTIVE:
		return "Can du 3 tac pham va day"
	var director := StealthDirector.find(self)
	if director and director.status in [StealthDirector.Status.CHASE, StealthDirector.Status.CAUGHT]:
		return "Hay cat duoi bao ve truoc"
	return "Gan day va thoat"

func _on_interact(_by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	if objectives == null:
		return false
	var director := StealthDirector.find(self)
	if director and director.status in [StealthDirector.Status.CHASE, StealthDirector.Status.CAUGHT]:
		return false
	return objectives.complete(&"escape")
```

Đặt điểm thoát ở vị trí tiếp cận an toàn. Trong bản phòng nhỏ, có thể dùng một hộp xanh làm điểm thoát, chưa cần cửa sổ hay leo dây. GameFlow đã theo dõi tín hiệu hoàn tất ObjectiveManager để chuyển sang WIN; GameMenus hiện màn thắng. Không cần sửa GameFlow.

**Đạt mốc C khi:** chưa lấy đủ đồ thì chưa thoát; lấy tranh theo các thứ tự khác nhau vẫn được; đủ đồ và mất truy đuổi thì thắng; Restart / Play Again trả scene về trạng thái ban đầu; bị bắt cũng khởi động lại đúng map.

## 6. Mốc D: mở rộng thành mặt bằng hai tầng

**Đã có bản chạy được:** [hướng dẫn và ảnh Godot bước 6](../step-06-blockout.md).
Bốn dải sàn ở ví dụ 6.1 đã được chia thành tám khối để chừa cả hai lỗ thang;
không tạo thêm bốn tấm sàn kín chồng lên scene hiện tại.

### 6.1. Chuyển sang đúng hệ tọa độ

Mặt bằng nằm trong [floorplans.png](floorplans.png); tọa độ phòng/cửa trong [floorplan-notes.md](floorplan-notes.md). Bản phòng thử ở quanh gốc chỉ để học. Khi dựng bản đầy đủ, thay/di chuyển hình học phòng thử, không giữ tường phòng thử chắn giữa bảo tàng.

- Gốc góc tây bắc; X tăng về đông, Z tăng về nam, Y là chiều cao.
- Khung nhà X=0…36, Z=0…30.
- Tầng 1 mặt sàn Y=0; tầng 2 mặt sàn Y=4.5.
- Sân trong X=12…24, Z=9…21. Tầng 2 là khoảng rỗng, không có sàn tại vùng này.
- Player khởi đầu gần `(18, 0.1, 28.5)`, hướng về phía -Z.

Sàn tầng 1 có thể dùng một khối 36 × 0.3 × 30 m, tâm `(18, -0.15, 15)`. Để tạo khoảng rỗng tầng 2, bắt đầu bằng bốn dải sau:

| Dải sàn | Size | Position |
|---|---|---|
| Bắc | (36, 0.3, 9) | (18, 4.35, 4.5) |
| Nam | (36, 0.3, 9) | (18, 4.35, 25.5) |
| Tây giữa | (12, 0.3, 12) | (6, 4.35, 15) |
| Đông giữa | (12, 0.3, 12) | (30, 4.35, 15) |

Đây mới là tấm sàn tổng quát. **Cần chia nhỏ dải bắc/nam để chừa lỗ thang B/A**, không đặt sàn kín ngang đầu dốc/cầu thang. Chừa lỗ tới nơi nhân vật đã lên hết cao độ, kể cả khoảng trống cho chiều cao đầu.

### 6.2. Thứ tự dựng

1. Sàn tầng 1 → tường ngoài → sân trong.
2. Hành lang vòng và các phòng tầng 1, đặt cửa theo bản vẽ.
3. Dải sàn tầng 2 có khoảng thông tầng và hai lỗ thang.
4. Hai đường lên xuống, thử bằng Player trước khi thêm lan can/trang trí.
5. Phòng tranh A, B, C, kho phục chế; giữ đủ cửa và lối vòng.
6. Lan can quanh khoảng thông tầng, cao khoảng 1.1–1.2 m, có collision.
7. Chuyển tác phẩm/dây/điểm thoát từ phòng thử sang các vị trí T1–T3/R/E.
8. Tạo tuyến G1/G2/G3 theo mặt bằng, thêm hai instance guard, gán đúng route.
9. Bake lại navmesh toàn map; kiểm tra cầu thang và cửa có nối thành vùng đi liên tục.

Tường thử dày 0.25–0.3 m, cửa rộng khoảng 1.6 m, hành lang 3 m theo bản vẽ. Chiều cao tầng là 4.5 m; đừng dùng lại tường cao 3 m của phòng thử nếu nó làm hở giữa hai tầng ngoài ý muốn.

### 6.3. Dốc và cầu thang

Player dùng CharacterBody3D và hiện không có nhảy hay thuật toán tự bước bậc. Navmesh có Agent Max Climb cũng không tự giúp capsule bước qua bậc vật lý.

- Giai đoạn đầu dùng dốc có collision, độ dốc thấp hơn giới hạn leo dốc của cả Player/guard và Agent Max Slope khi bake.
- Nối Y=0 lên Y=4.5 cần chiều dài chạy hợp lý; đường chạy 8 m cho góc khoảng 29.4 độ. Không dựng dốc dựng đứng chỉ để vừa góc nhà.
- Với thang chữ U, chia thành hai vế với chiếu nghỉ; khoảng thang và lỗ sàn phải cho nhân vật cao 1.8 m đi qua.
- Khi trang trí thành bậc, dùng bậc chỉ để nhìn, đặt mặt dốc collision mượt bên dưới; không để collision bậc tiếp tục chặn capsule.
- Nguồn bake navigation nên dùng static colliders để AI đi theo mặt dốc vật lý, thay vì bị phân mảnh bởi bậc trang trí.

### 6.4. Cửa khóa và lối tắt

Bản demo nhấn E ở mốc C chưa có chìa hay cửa khóa. Sau khi đi lại ổn, thêm các phần này lần lượt:

1. Chìa K ở phòng nhân viên: một tương tác lưu trạng thái đã có chìa.
2. Cửa phòng B: điều kiện mở là có K; khi mở phải dời/tắt collision của cánh cửa, không chỉ đổi hình ảnh.
3. Cửa B → kho phục chế: chỉ mở chốt từ phía B trước lần mở đầu. Dùng vùng kiểm tra phía tiếp cận hoặc tương tác chốt đặt trong B.
4. Kho vẫn có đường vào từ phòng phía nam để lấy dây sớm.
5. Giữ tuyến G3 trong phòng B; không ép guard đi qua cửa khóa mà chưa có xử lý navigation tương ứng.

Có thể tham khảo AccessDoor/PlayerInventory của nhóm, nhưng cần đọc các điều kiện và ID của chúng; không gắn script cửa thư viện rồi giả định nó tự hiểu chìa bảo tàng. Bản demo đơn giản dùng nhiệm vụ làm cờ tiến trình, chưa cần bật inventory. Nếu muốn hiện vật trong túi đồ, bật `use_inventory` trên Player và cấu hình item riêng.

## 7. Mốc E: hình ảnh, âm thanh và hoàn thiện

1. Dựng một phòng đẹp trước: sàn gỗ, tường đỏ trầm, cột đá sáng, khung tranh vàng, đèn ấm; sân dùng ánh xanh lạnh.
2. Tạo material dùng chung trong `maps/museum/assets/`; mô hình và texture phục vụ runtime cũng đặt ở assets. **Không để tài nguyên game cần tải trong docs**, vì docs bị loại khi export.
3. Hai PNG concept là ảnh tham khảo; không thể kéo chúng vào Godot để biến thành nhà 3D. Hình học phải dựng bằng khối hoặc import model 3D.
4. Thay dần khối bằng `.glb`/scene modular có collision phù hợp. Kiểm tra scale và hướng model. Khi chỉ có mesh thì tự thêm StaticBody3D/CollisionShape3D cho phần cần chặn.
5. Phần kính trong suốt nên không có collision chặn ray thị giác; chân đế đặc vẫn chặn. Nếu muốn kính cản di chuyển mà không cản thị giác, cần thiết kế collision layer/raycast riêng — đó là thay đổi có chủ đích, không chỉ đổi transparency.
6. Ánh sáng tối là hình ảnh; AI hiện kiểm tra khoảng cách, góc nhìn và raycast, chưa tự giảm phát hiện theo độ tối của material/đèn. Thiết kế nơi nấp bằng vật cản thực.
7. Thêm tiếng bước chân, nền đêm, tiếng lấy đồ, âm thanh bị phát hiện. AudioDirector dùng chung là phần có thể tích hợp sau; mẫu node trong tutorial là tài liệu tham khảo.
8. Thêm thao tác giữ E, animation gỡ tranh, dây xuất hiện tại cửa sổ. Chuyển cảnh thoát ngắn là đủ cho demo, chưa cần điều khiển leo dây tự do.
9. Chỉ thêm checkpoint khi có lưu/khôi phục cả nhiệm vụ, vật phẩm đã lấy, chìa, cửa, dây và vị trí guard. Tham khảo `features/checkpoints/`; đăng ký object có trạng thái theo giao diện của hệ thống. Bỏ cơ chế tải lại cả scene ở ví dụ mốc C khi chuyển sang checkpoint.

## 8. Chơi thử trước khi demo

| Kiểm tra | Kết quả cần có |
|---|---|
| F6 ở museum.tscn | Mở đúng bảo tàng |
| Đi khắp map, đi sát góc | Không lọt sàn/tường, không mắc cửa |
| Lên xuống cả A và B | Không kẹt bậc, đầu không đụng sàn kín |
| Nhìn xuống sân từ tầng 2 | Có lan can, không có mặt sàn che sân |
| Chờ bảo vệ đi ít nhất hai vòng | Không đứng yên, không xuyên bệ, không đổi tầng sai |
| Nấp sau bệ rồi đứng lộ | Phản ứng thị giác phù hợp |
| Thử các thứ tự lấy tranh | Không bị khóa tiến trình do thứ tự không dự kiến |
| Thử thoát thiếu đồ / khi đang bị đuổi | Có lời nhắc, chưa thắng |
| Đủ đồ, cắt đuôi, dùng điểm thoát | Hiện màn thắng |
| Bị bắt / Restart / Play Again | Các trạng thái khôi phục nhất quán |
| Pause / Resume | Guard và player cùng dừng/chạy lại |
| Debugger | Không còn lỗi đỏ khi hoàn thành một lượt |
| Cho bạn khác chơi không hướng dẫn | Biết mục tiêu, tìm được đường, hiểu vì sao thất bại |

Ghi lại nơi người chơi lạc, đoạn chờ quá lâu và chỗ bị bắt không hiểu lý do. Điều chỉnh một nhóm vấn đề rồi chơi lại. Mục tiêu thời lượng 12–18 phút chỉ là ý định thiết kế, cần xác nhận bằng người chơi thật.

## 9. Đưa vào menu và xuất demo Windows

### 9.1. Chạy riêng trong editor

Ở mọi giai đoạn có thể chọn `museum.tscn` → F6 để demo map riêng. Chưa cần thêm menu để đạt mốc A–D.

### 9.2. Thêm vào menu khi scene đã chạy ổn

`shared/scripts/game/level_catalog.gd` có `LEVELS`. Phối hợp với nhóm để thêm một phần tử vào mảng:

```gdscript
{"id": &"museum", "title": "Museum Escape",
 "scene": "res://maps/museum/scenes/museum.tscn",
 "description": "Retrieve three artworks and escape through the window."},
```

Giữ nguyên các entry cũ. F5, chọn Museum Escape, thử pause/restart/main menu rồi vào lại. Thêm entry mới có thể cần cập nhật kiểm thử catalog/menu của nhóm; chạy các kiểm tra trong `docs/architecture/MAP_LAYOUT.md` trước khi gộp nhánh.

### 9.3. Export

1. Dùng **Editor → Manage Export Templates**, cài templates trùng phiên bản engine.
2. Mở **Project → Export**, chọn preset **Windows Desktop** đã có.
3. Chọn Export Project và lưu dưới thư mục build riêng, ví dụ `build/museum-demo/CampusEscape3D.exe`. Tạo thư mục trước nếu cần.
4. Với preset hiện tại, cần mang cả `.exe` và `.pck` cùng thư mục. Mở bản xuất, từ menu chọn bảo tàng và chơi hết một lượt. F6 chỉ là cách chạy scene trong editor, không quyết định scene khởi động của file export.
5. Nếu cần bản Windows chỉ mở bảo tàng, nhóm có thể chuẩn bị launcher/preset riêng sau. Cách đơn giản hiện tại là thêm map vào catalog và giữ menu chung.
6. Nén cả thư mục build để đưa bạn bè chạy thử; khi đổi model/resource, export lại rồi kiểm tra bản xuất, không chỉ chạy source trong editor.

Chi tiết preset và các bước kiểm tra dự án nằm trong `docs/BUILD.md`.

## 10. Lỗi thường gặp

| Hiện tượng | Kiểm tra đầu tiên |
|---|---|
| F5 không thấy map | Map chưa đăng ký catalog; dùng F6 trên scene bảo tàng |
| Rơi xuyên sàn | Use Collision chưa bật; collider không ở lớp world; Player spawn dưới mặt sàn |
| Chỉ thấy màu nền / đen | Camera của Player, vị trí spawn, đèn và Environment; kiểm tra có đang nhìn ngoài map |
| Chuột không xoay | Cửa sổ game chưa focus hoặc đang pause; Resume/click vào game |
| Guard không đi | Patrol Route chưa gán, điểm không trên navmesh, geometry chưa nằm dưới region, chưa bake |
| Guard kẹt ở cửa | Cửa quá hẹp, collision cửa còn nguyên, navmesh không nối hoặc chưa bake lại |
| Kẹt ở cầu thang | Collision bậc thẳng đứng, dốc quá lớn, lỗ sàn/chiếu nghỉ thiếu khoảng trống |
| Không có prompt E | Chưa có ObjectiveHud; Area thiếu CollisionShape; quá 2.2 m; shape nằm sau tường/bệ |
| T2 không cập nhật | Objective Id sai, trùng T1 hoặc manager đang dùng nhiệm vụ thư viện |
| Chữ nhiệm vụ vẫn là thư viện | Chưa gọi setup dữ liệu nhiệm vụ riêng; GameMenus chưa đổi Win Message |
| Cúi sau kính vẫn bị thấy | Kính thực sự trong suốt; cần chân đế/vách đặc đủ lớn, kiểm tra các điểm lấy mẫu thị giác |
| Bị bắt rồi trạng thái đồ sai | Trộn reset mặc định với đồ tùy biến; dùng full-scene restart trong demo hoặc làm checkpoint đồng bộ |
| Đổi một bệ làm tất cả bệ đổi | Đang dùng chung resource; Make Unique khi cần khác nhau |
| Source chạy nhưng export thiếu ảnh/model | Runtime asset đặt nhầm trong docs/tools/tests hoặc đường dẫn sai chữ hoa/thường |

## 11. Lưu công việc bằng Git

Sau mỗi mốc chạy được, kiểm tra `git diff`, stage đúng tệp và commit. Ví dụ:

```powershell
git status
git add maps/museum
git commit -m "Add museum walkable blockout"
```

Nếu bước đó có sửa catalog chung, stage riêng tệp catalog sau khi xem diff. Giữ `.uid` đi cùng script. Không đưa `.godot`, thư mục build hay tài nguyên tạm vào commit. Chỉ push khi muốn đồng bộ lên nhánh của mình. Trước khi merge vào nhánh nhóm, chạy kiểm tra theo hướng dẫn kiến trúc và thử lại các map cũ khi có sửa phần dùng chung.

**Buổi làm đầu tiên chỉ cần hoàn thành mốc A.** Có một căn phòng tự tay dựng và đi lại được sẽ giúp các bước còn lại dễ hiểu hơn nhiều.
