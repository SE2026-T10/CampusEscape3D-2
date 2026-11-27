# Bước 12 — Một lối phòng nhân viên và cửa kho phục chế

Đã cập nhật scene chính `res://maps/isg_museum/scenes/museum.tscn`.

| Node dưới NavigationRegion3D/Doors | Vị trí | Chức năng |
|---|---|---|
| Staff | (27, 0, 10) | Cửa duy nhất của phòng nhân viên tầng 1 |
| RestorationEntrance | (27, 4.5, 27) | Cửa từ phòng đệm phía nam vào kho phục chế tầng 2 |

Giữ lối phòng nhân viên phía bắc, cạnh biển “Nhân viên”. Lối cũ tại `(27, 0, 15)`
đã được bịt bằng tường đầy đủ cả hình ảnh và collision. Không chỉ đặt cửa chắn
một trong hai lối. G3 vẫn tuần bên trong phòng và chìa K vẫn nằm ở vị trí cũ.

Hai cửa mới ban đầu đóng, mở tự do từ cả hai phía bằng **E**, nhấn E lần nữa
để đóng. Cửa chặn di chuyển và tầm nhìn khi đóng; chỉ bật link navigation khi mở.
Không cho đóng đè người chơi hoặc bảo vệ đứng ngay cánh cửa.
Không cần chìa K hoặc mật mã cho hai cửa này.

Cửa `RestorationShortcut` tại `(32, 4.5, 18)` vẫn là chốt riêng từ phòng B.
Người chơi được mở cửa phía nam để lấy dây trước khi có chìa K.
Khi mang T2 theo đường vòng, phải E mở cửa mới trước khi đi vào kho;
tranh đang cầm không chặn tương tác với cửa.

## Chạy thử

1. Mở scene chính, nhấn **F6**, vào sảnh và lên hành lang phía đông tầng 1.
2. Kiểm tra lối phòng nhân viên phía nam đã thành tường.
3. Đi tới cửa phía bắc, E mở, vào lấy chìa; thử đóng/mở từ phía trong.
4. Lên tầng 2, tới phòng đệm phía nam, E mở cửa kho ở phía đông.
5. Thử đóng lại để ngăn tầm nhìn; đứng lùi khỏi mặt cửa khi đóng.
6. Mang T2 qua đường vòng, mở cửa rồi giao tranh tại thảm xanh như trước.

Navmesh đã bake lại: 439 polygon, gồm cả hai cửa đóng và tường bịt lối cũ.
Đã chạy 308 kiểm tra hành vi: 105 blockout, 72 demo, 83 vận chuyển T2, 48 T1.
Kiểm tra gồm đi qua hai cửa thật bằng Player, E mở/đóng từ hai phía,
collision/tia nhìn/navigation, đường mang T2, chín tuyến tuần tra và tải lại scene.

Builder đã cập nhật để lần dựng lại sau vẫn giữ một lối phòng nhân viên.
Có chế độ `--update-staff` chỉ dựng lại vách StaffPartition, không ghi đè sân,
các phòng khác hoặc cầu thang. Sau khi thay collision phải bake navigation lại.
