# Bước 4 — Phòng thử có bảo vệ đi tuần

Mở `res://maps/museum/scenes/museum.tscn` và nhấn **F6** để chạy riêng map. Dùng WASD, chuột, Shift để chạy, C/Ctrl để cúi và Esc để pause. Restart trong menu tải lại bảo tàng.

## Cây scene đã bổ sung

```text
Museum
├── NavigationRegion3D
│   └── Geometry
│       ├── Floor
│       ├── Wall_North
│       ├── Wall_South
│       ├── Wall_West
│       ├── Wall_East
│       └── CoverPlinth
├── Player
├── DirectionalLight3D
├── GameFlow
├── GameMenus
├── PatrolRoute_Test
│   ├── P1
│   ├── P2
│   ├── P3
│   └── P4
├── Guard_Test
├── NoiseSystem
├── StealthDirector
└── StealthHud
```

- Bệ `CoverPlinth`: Size `(2, 1.2, 1.2)`, Position `(0, 0.6, 0)`, bật collision.
- Navmesh riêng: `res://maps/museum/resources/museum_navigation.tres`.
- NavigationMesh đọc Static Colliders, chỉ lớp 1 `world`; Agent Radius `0.4`, Agent Height `1.8`.
- Bốn điểm tuần tra lần lượt `(-3, 0.05, -3)`, `(3, 0.05, -3)`, `(3, 0.05, 3)`, `(-3, 0.05, 3)`. Mỗi điểm dừng 1.5 giây, tuyến lặp lại.
- `Guard_Test` instance bảo vệ dùng chung, bắt đầu gần P1; thuộc tính Patrol Route tham chiếu node `PatrolRoute_Test`.
- NoiseSystem, StealthDirector và StealthHud dùng các script có sẵn. Không thay đổi AI hoặc Player dùng chung.

## Chơi thử

1. Quan sát bảo vệ di chuyển quanh bệ. Nếu người chơi bị nhìn thấy hoặc gây tiếng động, guard có thể ngắt tuần tra để điều tra/truy đuổi; đó là hành vi dự kiến.
2. Đứng lộ trước mặt bảo vệ để thấy thanh phát hiện và trạng thái truy đuổi.
3. Đi sang phía đối diện bệ, cúi sát phía sau bệ để cắt các tia nhìn. Bảo vệ vẫn có thể đi vòng để tìm; bệ không tạo trạng thái bất khả phát hiện.
4. Chạy tạo tiếng bước chân lớn hơn đi/cúi. Nghe thấy tiếng động, guard có thể chuyển sang điều tra.
5. Để guard bắt được người chơi, kiểm tra HUD bị bắt rồi nhân vật/bảo vệ trở về điểm đầu.

Nấp bằng hình học ở bước này không nhất thiết hiện chữ **HIDDEN**. Trong HUD chung, chữ đó còn cần thành phần `hiding_spot`; hiện chưa thêm thành phần này. Đánh giá che khuất bằng việc thanh phát hiện ngừng tăng và guard mất tầm nhìn.

## Bake lại khi đổi phòng hoặc bệ

Trong editor: chọn `NavigationRegion3D` → **Bake NavigationMesh**, lưu scene và resource navmesh. Không đặt Geometry trở lại ngoài region, vì nguồn bake đang quét các node con của region.

Hoặc chạy từ PowerShell tại thư mục dự án:

```powershell
& '.local/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file 'D:/IT/SE_GAME_3D/.local/logs/museum-navigation-bake.log' --script res://maps/museum/tools/bake_navigation.gd
```

Công cụ bake chỉ lấy hình học của region, không chạy nhân vật/bảo vệ/HUD; kết quả được lưu vào `museum_navigation.tres`. Không bake lại mỗi lần khởi động game.

Trong bước thử này, navmesh dùng kích thước voxel mặc định của dự án. Godot có thể thông báo làm tròn radius/height theo voxel khi bake. Giữ phần navmesh mặt sàn liên thông quanh bệ; phần nhỏ trên nóc bệ nếu có là một đảo rời, không có đường nối từ sàn.

## Kết quả kiểm tra tự động

Đã chạy kiểm tra vật lý trong Godot 4.7.2, đạt 17 kiểm tra, kết thúc với mã 0:

- Navmesh đã bake, route lặp có đủ bốn điểm.
- Hai vòng đi thực tế đúng chuỗi `0,1,2,3,0,1,2,3,0`, không mắc kẹt hoặc bỏ điểm. Trong phần kiểm tra tuần tra thuần túy, tạm cô lập cảm nhận người chơi để không bị ngắt bởi truy đuổi.
- Truy vấn đường đi từ trái sang phải chọn đường vòng qua bệ.
- Trên cùng một đường nhìn, guard thấy người chơi đứng nhưng không thấy khi cúi sau bệ; thanh phát hiện giảm sau khi bị che.
- Sự kiện NoiseSystem đến GuardHearing và chuyển guard sang điều tra.
- Người chơi lộ diện gây truy đuổi; bắt được người chơi đưa GameFlow sang CAUGHT.
- Sau thời gian bị bắt, người chơi và guard về điểm đầu, guard trở lại PATROL và GameFlow về PLAYING.

Log kiểm tra cục bộ: `.local/logs/museum-guard-verification.log`. Kiểm tra không thay đổi script dùng chung. Máy chạy kiểm tra headless có thông báo kho chứng chỉ hệ thống không đọc được; các kiểm tra gameplay vẫn hoàn tất.
