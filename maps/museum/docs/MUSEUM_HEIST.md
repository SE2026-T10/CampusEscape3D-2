# Museum Heist

## Giới thiệu

- **Tên hiển thị:** Museum Heist
- **Map ID:** `museum`
- **Thể loại:** lén lút góc nhìn thứ nhất, graybox thử nghiệm
- **Ý tưởng:** xâm nhập một bảo tàng ban đêm, lấy thẻ nhân viên trong khu vực hạn chế rồi tìm tới lối thoát chính.

Bản Museum Heist hiện dùng các prop low-poly ghép từ nhiều mesh thay cho các khối màu đơn: tủ trưng bày có đế gỗ, khung đồng, kính và cổ vật; bệ đá có bust; tranh có khung và hình abstract/landscape; quầy lễ tân, ghế, kệ hồ sơ, bàn an ninh, chậu cây, cột và dây phân cách. Map vẫn là graybox gameplay, chưa có camera, vault, puzzle, artifact hay nhiều exit riêng.

## Cốt truyện

Người chơi xuất hiện trong bảo tàng sau giờ đóng cửa. Nhiệm vụ hiện tại là đi vào sảnh, tới vùng hạn chế, lấy thẻ nhân viên, tới khu vực cửa ra rồi dùng phím **E** để thoát. Thắng chỉ khi hoàn thành chuỗi nhiệm vụ và tương tác với cửa thoát; chỉ đi tới khu vực thoát không kết thúc màn chơi.

Map hiện không có artifact mục tiêu, vault, clue, câu đố hay nhánh nhiệm vụ bảo tàng. Các nội dung này là hướng phát triển, không phải phần chơi hiện có.

## Thiết kế bản đồ

Scene có sàn chính khoảng 40 × 30 m, bốn tường biên và các cụm prop theo từng khu vực. Chúng tạo tuyến vòng quanh vật trưng bày và điểm che khuất, nhưng không đóng kín thành các phòng riêng:

| Khu vực gameplay | Vị trí gần đúng (X, Z) | Nội dung hiện có |
|---|---:|---|
| Lobby / điểm bắt đầu | (-15, 0) | Quầy lễ tân hướng về spawn, ghế nhân viên, bench, hai chậu cây, cột và đèn |
| Exhibition Hall | (-4, 2) | Ba tủ kính, bệ đá có bust, tượng bust độc lập, hai tranh khác nhau và dây phân cách |
| Restricted Archive | (12, -8) | Hai kệ hồ sơ có thùng/hồ sơ, dây phân cách, trigger thẻ, thẻ và cửa nhân viên |
| Security Area | (13, 13) | Bàn điều khiển có hai màn hình, phím/đèn báo và ghế bảo vệ |
| Main Exit | (-15, 11) | Trigger tiếp cận, tuần tra ExitGuard và cửa thoát chính |

Các tủ, quầy, bệ, kệ, bench, cột và chậu có collision tương ứng; tranh gắn tường không có collision, còn cả trụ lẫn dây barrier có collision để chặn đường đi. StaticBody prop dùng physics layer mặc định `1`, nằm trong `GuardVision.sight_mask = 3`, nên mesh kính vẫn chặn raycast tầm nhìn dù vật liệu nhìn xuyên được.

Các prop lớn có `NavigationObstacle3D` bật avoidance để hỗ trợ steering cục bộ của guard. Tuy nhiên, `museum_navmesh.tres` vẫn là một polygon thủ công phủ gần hết sàn, không được bake lại quanh từng prop; avoidance không thay thế navmesh obstacle carving/path reroute. Patrol marker hiện tại được giữ ngoài footprint chính của prop, nhưng đường INVESTIGATE/CHASE quanh props cần xác nhận bằng playtest trong Godot.

## Mục tiêu

Map dùng chuỗi tuyến tính gồm năm mục tiêu bắt buộc, hiển thị trên HUD:

1. Vào bảo tàng.
2. Tới vùng hạn chế.
3. Lấy thẻ nhân viên.
4. Tới lối ra chính.
5. Thoát qua cửa chính.

Không có mục tiêu tùy chọn. Thẻ chỉ có thể nhặt khi mục tiêu lấy thẻ đang hoạt động. Cửa thoát chỉ thắng khi mục tiêu thoát đã hoạt động và mục tiêu thẻ đã hoàn thành. Cửa nhân viên từ chối người chơi chưa lấy thẻ; prompt dùng chung của cửa nêu lý do cần thẻ. Thẻ là mục tiêu/pickup trong `AccessCard`; map hiện không bật inventory cho player.

## NPC và AI

Có **năm guard**, tất cả là instance của `shared/scenes/npc/guard.tscn`:

| Guard | Vị trí xuất phát | Hai điểm tuần tra (X, Z) |
|---|---:|---|
| LobbyGuard | (-12, 8) | (-12, 8) → (8, 8) |
| ArchiveGuard | (10, -4) | (10, -4) → (14, -10) |
| ControlGuard | (8, 10) | (8, 10) → (14, 10) |
| VaultGuard | (-8, -10) | (-8, -10) → (-3, -11) |
| ExitGuard | (-14, 11) | (-14, 11) → (-6, 12) |

Các tuyến lặp qua hai marker của từng guard. Chúng hiện là tuyến đặt trong không gian mở, không đại diện cho phòng archive/control/vault thực tế.

Guard dùng AI chung với các trạng thái **PATROL**, **INVESTIGATE** và **CHASE**. Vision kiểm tra tầm nhìn, góc nhìn và vật cản; hearing nhận noise event như bước chân. Guard có thể điều tra vị trí tiếng động ước lượng và truy đuổi khi phát hiện người chơi. Bản Museum không có AI riêng.

## Cơ chế gameplay

| Cơ chế | Trạng thái triển khai |
|---|---|
| Thẻ nhân viên | Có; nhặt bằng E khi mục tiêu thẻ đang hoạt động, hoàn tất mục tiêu đó |
| Cửa nhân viên | Có; `AccessDoor`, cần hoàn thành mục tiêu lấy thẻ; mở bằng E |
| Cửa thoát chính | Có; `ExitDoor`, cần tới đúng bước cuối của chuỗi mục tiêu và dùng E |
| Guard tuần tra, thị giác, thính giác | Dùng hệ thống dùng chung |
| Museum props | Có; các scene riêng cho tủ kính, bust, pedestal, hai tranh, quầy lễ tân, bench, planter, bàn an ninh, kệ hồ sơ, cột và barrier |
| Collision / tầm nhìn | Có collision cho vật cản chính; static body layer 1 chặn raycast guard vision, kể cả kính trong |
| Navigation avoidance | Có `NavigationObstacle3D` trên prop cản đường; navmesh thủ công chưa carve quanh prop và chưa được xác nhận runtime |
| Camera an ninh | Chưa triển khai |
| Puzzle / bảng điện / mã vault | Chưa triển khai |
| Artifact, vault, clue, vật phẩm đánh lạc hướng | Chưa triển khai |
| Inventory, checkpoint trong lượt chơi | Các node dùng chung có trong project; map này chưa bật inventory và chưa đặt checkpoint |
| Escape qua service exit hoặc lối khác | Chưa triển khai |

## Tài nguyên và cấu trúc file

- `scenes/museum_heist.tscn` — scene chính; đặt prop, lighting, player/guard/patrol, objective và game-flow nodes.
- `scenes/props/display_case.tscn` — đế gỗ, viền kim loại, kính có collision, cổ vật và đèn trong tủ.
- `scenes/props/statue_bust.tscn`, `art_pedestal.tscn`, `decorative_column.tscn` — bust nhiều mesh, bệ nhiều tầng và cột có chân/thân/đầu cột.
- `scenes/props/painting.tscn`, `painting_landscape.tscn` — tranh abstract và landscape có khung, canvas và hình khối nghệ thuật.
- `scenes/props/reception_desk.tscn`, `security_station.tscn` — quầy/bàn nhiều thành phần, màn hình, chi tiết điều khiển và ghế dùng chung.
- `scenes/props/museum_bench.tscn`, `plant_pot.tscn`, `archive_shelf.tscn`, `rope_barrier.tscn` — nội thất lobby, kệ có hàng, và trụ dây phân cách.
- `resources/museum_navmesh.tres` — navigation mesh polygon thủ công cho mặt sàn rộng; không tự carve theo prop.
- **Model/material:** Không có model/texture art phù hợp trong Museum, shared hoặc tutorial; ghế nhân viên tái sử dụng `shared/scenes/props/chair.tscn`. Các prop khác dùng primitive mesh và material `StandardMaterial3D` riêng (gỗ, đồng, đá, kính, lá, màn hình); không thêm asset ngoài hoặc phụ thuộc asset map khác.
- `docs/MUSEUM_HEIST.md` — tài liệu trạng thái map này.
- `scripts/`, `assets/`, `tests/`, `tools/` — hiện chưa có script, asset, test hay tool riêng cho Museum.
- `shared/` và `features/` — mã nguồn các hệ thống được scene tham chiếu; map không sao chép player hoặc guard AI.

## Tích hợp với hệ thống chung

- **Player:** instance `shared/scenes/player/player.tscn`, gồm điều khiển góc nhìn thứ nhất, di chuyển, ngồi thấp, noise, tương tác E và phản hồi người chơi. Cấu hình mặc định không bật inventory hoặc stamina.
- **Guards:** instance scene guard và dùng `Guard`, `GuardVision`, `GuardHearing`, `PatrolRoute`/`PatrolPoint` dùng chung.
- **HUD:** `StealthHud` hiển thị trạng thái lén lút; `ObjectiveHud` hiển thị năm mục tiêu được cấu hình riêng cho Museum.
- **Objectives:** `ObjectiveManager` cấu hình chuỗi tuyến tính; trigger dùng `ObjectiveTrigger`, pickup dùng `AccessCard`, cửa dùng `AccessDoor` và `ExitDoor`.
- **Luồng trò chơi:** `GameFlow`, `GameMenus`, `StealthDirector`, `NoiseSystem` và `AudioDirector` là các hệ thống chung được đặt trong scene map.
- **Catalog/menu:** entry `museum` trong `LevelCatalog` tạo nút Museum Heist trong main menu. Restart tải lại scene Museum và menu chính dùng flow chung.

## Cách mở và chơi map

1. Chạy project bằng Godot 4.7.2.
2. Chọn **Museum Heist** tại main menu.
3. Điều khiển bằng **WASD**, nhìn bằng chuột, **Shift** chạy, **C/Ctrl** ngồi thấp, **E** tương tác và **Esc** tạm dừng.
4. Đi qua lần lượt các vùng mục tiêu trên HUD, nhặt thẻ khi được yêu cầu, rồi tương tác với cửa chính.

## Kiểm thử

| Kiểm tra trong phiên thay props | Kết quả |
|---|---|
| `python tools/ci/check_layout.py` | Qua; xác nhận 527 tham chiếu runtime `res://` |

Godot editor/headless, `tools/ci/validate.sh`, `tools/ci/run_tests.sh`, `tools/map_flow.gd` và screenshot/playtest không chạy được trong phiên này vì executable Godot không có trong PATH. Bố cục props, collision raycast thực tế, navigation avoidance, guard/player bị kẹt và hình ảnh trong góc nhìn thứ nhất vẫn cần xác minh trong Godot. Các kết quả kiểm thử cũ ở tài liệu trước không được coi là kiểm chứng phiên thay props này.

## Hướng phát triển

- Thay không gian mở bằng lobby, exhibition hall, restricted archive, security control room, vault và maintenance area có kết nối, vật cản và collision rõ ràng.
- Thêm artifact/vault, clue, puzzle bảo mật, camera có thể vô hiệu hóa và điều kiện mở cửa nhất quán.
- Tạo ít nhất hai tuyến thoát độc lập với prerequisites và tác động gameplay riêng.
- Bổ sung vật phẩm distraction, các mục tiêu tùy chọn, checkpoint/hiding spots nếu cần.
- Thêm camera, vault, puzzle, artifact và các exit phụ mà không làm hỏng objective chain hiện tại.
- Thêm test gameplay riêng cho mục tiêu, tương tác bị khóa, guard navigation, reset và các đường thoát.
