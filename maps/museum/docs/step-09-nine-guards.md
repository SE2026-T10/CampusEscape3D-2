# Bước 9 — Chín bảo vệ theo sơ đồ mới

Đã áp dụng vào `res://maps/museum/scenes/museum.tscn`, dựa trên
`concept-v2/floorplans-patrol-9-guards.png`.
Tọa độ waypoint được căn theo cửa và collision thực tế trong scene.

| Tầng | Node | Tuyến tuần tra | Số điểm |
|---|---|---|---|
| 1 | Guard_G1 | Vòng quanh hai bệ phòng điêu khắc | 4 |
| 1 | Guard_G2 | Phòng trưng bày lịch sử phía bắc | 4 |
| 1 | Guard_G3 | Ngủ ở B; vòng H quanh bàn A khi kiểm tra (bước 14) | 6 |
| 1 | Guard_G4 | Hành lang vòng quanh sân trong | 4 |
| 1 | Guard_G5 | Chỉ tuần sảnh chính; phòng dịch vụ có cửa riêng | 5 |
| 2 | Guard_G6 | Phòng A, có điểm Inspect_T1 trên lối phía tây | 5 |
| 2 | Guard_G7 | Phòng C phía bắc | 4 |
| 2 | Guard_G8 | Phòng B, vòng quanh bệ giữa phòng | 4 |
| 2 | Guard_G9 | Hành lang vòng ↔ cửa phía nam ở (18,24) ↔ phòng đệm | 12 |

Mỗi bảo vệ có tuyến `PatrolRoute_Gn` tương ứng. G1–G5 đi trên sàn Y=0,
G6–G9 trên sàn Y=4.5; marker được đặt cao hơn sàn 0.1 m như trước.
Các điểm thường dừng 0.8 giây, điểm kiểm tra T1 dừng 2 giây.
Nhãn G1–G9 ở trên đầu giúp nhận biết khi chạy thử.

G4 đi ở hành lang bao quanh sân, không vào vườn hay sân trước.
G9 đi xuống phòng đệm rồi quay lại qua chính cửa phía nam, không vào kho.
G8 tuần trong B; tuyến không yêu cầu mở cửa B hoặc chốt kho.
Giới hạn khu vực trên áp dụng khi tuần tra; phản ứng nhìn thấy, điều tra tiếng động
và đuổi người chơi tiếp tục dùng AI chung của nhóm.

## Cơ chế T1 được chuyển sang G6

Trong bản cũ, bảo vệ phòng A mang tên Guard_G2. Nay node đó là Guard_G6,
gắn `museum_inspector.gd`, có `Speech`, `painting_path` trỏ T1 và
`search_points_path` trỏ RoomSearch_T1. Guard_G2 mới chỉ tuần phòng lịch sử tầng 1.

HUD, lời thoại và chỉ dẫn đã đổi sang “G6 đã phát hiện thiếu tác phẩm T1”.
G6 vẫn phải tới điểm kiểm tra và thực sự nhìn thấy khung trống mới phát hiện;
phát hiện tranh mất không tự cung cấp vị trí người chơi.

## Chạy và chỉnh trong Godot

1. Mở `res://maps/museum/scenes/museum.tscn`, nhấn **F6**.
2. Đi từ sân trước vào sảnh, quan sát G5 đi qua sảnh và phòng dịch vụ.
3. Kiểm tra G1/G2/G3 trong ba phòng tầng 1 và G4 quanh sân.
4. Lên tầng 2, quan sát G6/G7/G8 trong A/C/B, G9 ở hành lang và phòng đệm.
5. Lấy T1, nấp và chờ G6 kiểm tra. HUD/lời thoại phải báo đúng G6.
6. Thử mang T2, đặt xuống, lấy lại, giao trong kho và thoát như bước 8.
7. Restart hoặc bị bắt sẽ đặt lại đủ chín bảo vệ và nhiệm vụ.

Muốn sửa tuyến: mở `PatrolRoute_Gn`, chỉnh Position của các Marker3D.
Không đổi tên Inspect_T1 nếu chưa sửa Inspection Point Name trên Guard_G6.
Thay đổi waypoint không cần bake lại navmesh; đổi collision/sàn/tường thì cần bake.
Muốn thay tốc độ: chọn Guard_Gn, chỉnh Patrol Speed trong Inspector.

## Kiểm tra

Đã chạy 266 kiểm tra hành vi: 79 hình học/di chuyển/tuần tra,
57 vòng chơi, 48 khung T1, 82 vận chuyển T2.
Bộ tuần tra chạy cả chín người đồng thời ít nhất hai vòng theo đúng thứ tự,
không kẹt, giữ đúng tầng/khu vực khi cửa B và chốt kho còn đóng.
Perception được tách khỏi kiểm tra tuyến để bảo vệ không bỏ tuần tra đi đuổi
nhân vật thử; các bộ T1 và vòng chơi kiểm tra riêng phát hiện/đuổi/bắt thật.

Chỉ cập nhật map bảo tàng; không sửa AI hoặc scene dùng chung của nhóm.
