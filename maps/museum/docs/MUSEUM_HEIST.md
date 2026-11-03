# Museum Heist

## Giới thiệu

- **Tên hiển thị:** Museum Heist
- **Map ID:** `museum`
- **Thể loại:** lén lút góc nhìn thứ nhất, graybox thử nghiệm
- **Ý tưởng:** xâm nhập một bảo tàng ban đêm, lấy thẻ nhân viên trong khu vực hạn chế rồi tìm tới lối thoát chính.

Đây là bản graybox nhỏ để kiểm tra tích hợp map với catalog, player, guard, nhiệm vụ và luồng chơi chung. Nó chưa hiện thực đầy đủ thiết kế Museum Heist nhiều phòng như ý tưởng ban đầu.

## Cốt truyện

Người chơi xuất hiện trong bảo tàng sau giờ đóng cửa. Nhiệm vụ hiện tại là đi vào sảnh, tới vùng hạn chế, lấy thẻ nhân viên, tới khu vực cửa ra rồi dùng phím **E** để thoát. Thắng chỉ khi hoàn thành chuỗi nhiệm vụ và tương tác với cửa thoát; chỉ đi tới khu vực thoát không kết thúc màn chơi.

Map hiện không có artifact mục tiêu, vault, clue, câu đố hay nhánh nhiệm vụ bảo tàng. Các nội dung này là hướng phát triển, không phải phần chơi hiện có.

## Thiết kế bản đồ

Scene hiện có một mặt sàn graybox khoảng 40 × 30 m, bốn tường biên, một lưới điều hướng thủ công và một số node đánh dấu vị trí. Đây là không gian mở duy nhất; tên gọi dưới đây mô tả vị trí gameplay, không phải các phòng được ngăn bằng tường:

| Khu vực gameplay | Vị trí gần đúng (X, Z) | Nội dung hiện có |
|---|---:|---|
| Điểm bắt đầu / sảnh | (-15, 0) | Player spawn và vùng kích hoạt mục tiêu vào map |
| Vùng hạn chế | (14, -7) | Trigger mở mục tiêu lấy thẻ |
| Vị trí thẻ | (14, -3) | Thẻ nhân viên có thể nhặt |
| Cửa nhân viên | (8, -6) | Cửa khóa bằng mục tiêu thẻ; mở bằng E sau khi lấy thẻ |
| Vùng tới lối ra | (-15, 11) | Trigger mục tiêu tiếp cận cửa thoát |
| Cửa thoát chính | (-15, 15) | Interactable hoàn tất màn sau khi đủ điều kiện |

Người chơi đi qua sàn mở giữa các vị trí này; hiện không có hành lang, phòng trưng bày, kho lưu trữ, phòng điều khiển, vault, maintenance hay đường service exit riêng. Chỉ có một lối thoát được triển khai, không có hai tuyến thoát khác nhau.

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
| Camera an ninh | Chưa triển khai |
| Puzzle / bảng điện / mã vault | Chưa triển khai |
| Artifact, vault, clue, vật phẩm đánh lạc hướng | Chưa triển khai |
| Inventory, checkpoint trong lượt chơi | Các node dùng chung có trong project; map này chưa bật inventory và chưa đặt checkpoint |
| Escape qua service exit hoặc lối khác | Chưa triển khai |

## Tài nguyên và cấu trúc file

- `scenes/museum_heist.tscn` — scene chính; khai báo geometry graybox, player/guard instances, patrol routes, trigger, card, door và các hệ thống gameplay.
- `resources/museum_navmesh.tres` — navigation mesh dạng polygon thủ công cho mặt sàn mở.
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

Các kiểm tra dưới đây xác minh việc biên dịch/tải scene và luồng chọn map; chúng không phải đánh giá chơi thử thủ công, cân bằng độ khó hay kiểm thử mọi đường đi gameplay:

| Kiểm tra | Kết quả |
|---|---|
| `tools/ci/check_scripts.gd` bằng Godot 4.7.2 | Qua; 152 script biên dịch |
| `tools/map_flow.gd` | Qua 76/76 kiểm tra; tải 18 map qua 3 chu kỳ, gồm chọn/restart/rời Museum, nhiệm vụ reset sạch và 5 guard có route 2 điểm |
| `python tools/ci/check_layout.py` | Qua; 219 tham chiếu tài nguyên runtime hợp lệ |
| `tests/test_scene.tscn` bằng Godot 4.7.2 | Qua toàn bộ suite; xác nhận menu có 3 map và Museum tải, restart, quay lại menu cùng các hệ thống dùng chung |

Kiểm thử không xác nhận map đạt thiết kế hoàn chỉnh, có camera/puzzle/vault, hay có nhiều lối thoát. Việc chơi thủ công và kiểm tra chất lượng trải nghiệm vẫn cần thực hiện.

## Hướng phát triển

- Thay không gian mở bằng lobby, exhibition hall, restricted archive, security control room, vault và maintenance area có kết nối, vật cản và collision rõ ràng.
- Thêm artifact/vault, clue, puzzle bảo mật, camera có thể vô hiệu hóa và điều kiện mở cửa nhất quán.
- Tạo ít nhất hai tuyến thoát độc lập với prerequisites và tác động gameplay riêng.
- Bổ sung vật phẩm distraction, các mục tiêu tùy chọn, checkpoint/hiding spots nếu cần.
- Cải thiện hình ảnh bảo tàng bằng props, biển hướng dẫn, display cases, tượng và ánh sáng riêng.
- Thêm test gameplay riêng cho mục tiêu, tương tác bị khóa, guard navigation, reset và các đường thoát.
