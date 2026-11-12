# Map bảo tàng — hgmanh

Art môi trường v1: sân Gothic hai tầng, mái kính, bốn tượng, đài phun thấp, cây LOD và nội thất đã được lưu vào scene. Công cụ authoring, ảnh Godot, baseline và giới hạn nghiệm thu: [environment-art-v1/REPORT.md](docs/environment-art-v1/REPORT.md).

Sau khi chỉnh layout hoặc dựng lại, chạy `tools/apply_environment_art.gd`, rồi kiểm tra bằng cùng script với `-- --check`. Các builder geometry/exhibits/service và `apply_materials.gd` đều gọi art helper trước khi lưu; không cần tạo môi trường trong runtime.

Người phụ trách: **hgmanh**. Nhánh phát triển: **`hgmanh-work`**.

Map ID: **`isg_museum`**. Thư mục làm việc: `maps/isg_museum/`.
Nhánh được tạo từ `main` tại commit `13807bd` ngày 27/10/2026.
Hiện có bản dựng khối hai tầng 36 × 30 m tại `res://maps/isg_museum/scenes/museum.tscn`:
sân trong thông tầng, hai đường dốc chữ U, chín bảo vệ, chìa K, hai cửa có điều kiện,
mười hiện vật, dây, cửa sổ thoát và HUD hợp đồng.
Theo [sơ đồ concept v2](docs/concept-v2/README.md), Player xuất phát ở sân trước
`(18, 0.1, 35)`, đi tới cửa chính và nhấn **E** để vào sảnh.
Mở scene rồi nhấn **F6** để thử riêng; map chưa đăng ký trong menu chung.

Đã thêm **[Bước 9 — Chín bảo vệ](docs/step-09-nine-guards.md)** theo sơ đồ mới:
G1–G5 tầng 1, G6–G9 tầng 2; có nhãn số trên đầu để nhận biết khi chạy thử.
Cơ chế **[phát hiện khung T1 trống](docs/step-07-empty-frame.md)** nay thuộc G6:
lấy T1 để lại khung, G6 kiểm tra bằng tầm nhìn thực rồi tìm quanh phòng A.
Đã thêm **[Bước 8 — Vận chuyển tranh lớn T2](docs/step-08-carry-t2.md)**:
E nhấc tranh, Q đặt xuống/nhặt lại bằng E; mang tranh đi chậm và không sprint.
Chỉ giao T2 tại thảm xanh trong kho mới hoàn thành nhiệm vụ vận chuyển.
Đã cập nhật **[sân trong và cửa đóng/mở](docs/step-11-ring-and-doors.md)**:
bốn lối nối với đường tròn quanh đài phun nước giữa sân; G5 chỉ tuần sảnh,
phòng dịch vụ có cửa riêng. Nhấn E để mở hoặc đóng cửa, chắn tầm nhìn bảo vệ.
Đã thêm **[cửa phòng nhân viên và cửa kho phục chế](docs/step-12-staff-restoration-doors.md)**:
phòng nhân viên chỉ còn một lối vào, hai cửa mới đều E mở/đóng từ hai phía.
Đã sửa **[phòng nhân viên theo bố cục A–H](docs/step-14-staff-ah.md)**:
cúi nấp sau bàn A, G3 ngồi ở B, chìa treo trên tủ D, đọc C/G để suy mã kho,
chai/lon F gây tiếng. Khi kiểm tra, G3 đi vòng H quanh bàn rồi về ghế.
Đã thêm [giấy ghi chú trên bàn và lịch thời gian thực](docs/step-15-paper-calendar.md):
E đọc giấy giữa màn hình; lịch C cập nhật ngày giờ máy tính.
Đã triển khai [kho phụ khóa mã ở tầng 1](docs/step-16-aux-storage.md):
mã ngày hiện tại DDMM từ C/G, E lấy dây trên giá và cảnh báo khi sai ba lần.
Dây không còn ở tầng 2; tập kết T2 và cửa sổ thoát vẫn ở kho phục chế tầng 2.
Đã triển khai [vòng chơi hợp đồng và cơ chế từng phòng](docs/step-17-contract-gameplay.md):
N0 giao nhiệm vụ S1/H1/T1, dịch vụ cấp vé tầng 2 và bản đồ, tủ kính điêu khắc,
ngăn lịch sử, tranh phụ A/B/C và niêm phong báo động phòng C.
Có dây và cắt đuôi thì được rút lui; kết quả đánh giá riêng theo hiện vật đúng hợp đồng.
Khi bị bắt, màn tổng kết chờ người chơi chọn chơi lại.
Đã cập nhật theo [phản hồi chơi thử — bước 18](docs/step-18-contract-revision.md):
bốn hợp đồng ngẫu nhiên độc lập (25% mỗi mẫu), giấy ngắn gọn, bảng tên trên bàn,
hỏi đáp đổi theo hợp đồng, vé đọc sau khi trả lời đúng (**V** xem lại), N0 bên phải cửa chính.
Đã áp dụng [góp ý về các phòng — bước 19](docs/step-19-room-feedback.md).
Lịch tháng và mã kho cùng cập nhật theo ngày máy tính, G3 có tư thế ngồi mới,
tủ kho sát tường nam, bỏ sổ trực và các đồ được chỉ định, bịt lối B sang kho,
bỏ ghế cạnh N0 và đưa tranh tầng 2 sát tường.
Bản dựng đã qua **602 kiểm tra** riêng của map.

Hình học và cách chỉnh sàn/dốc/cửa: [Bước 6 — mặt bằng hai tầng](docs/step-06-blockout.md).

Lịch sử phòng thử: [Bước 4 — bảo vệ tuần tra](docs/step-04-patrol.md),
[Bước 5 — nhiệm vụ, thắng và thua](docs/step-05-demo.md).

## Thư mục làm việc

- `scenes/`: scene chính và các scene con của bảo tàng.
- `scripts/`: logic đặc trưng của map.
- `assets/`: model, ảnh, vật liệu và âm thanh riêng.
- `resources/`: navmesh và cấu hình.
- `tests/`: kiểm thử riêng của map.
- `tools/`: công cụ dựng map và bake navmesh.
- `docs/`: thiết kế, ảnh, ghi chú; giữ `.gdignore` tại đây.

## Bắt đầu phát triển

1. Mở project Godot tại `D:\IT\SE_GAME_3D`.
2. Mở scene chính `res://maps/isg_museum/scenes/museum.tscn` với node gốc `Museum`.
3. Sửa hình học trong scene con `scenes/museum_geometry.tscn`; sau khi đổi collision,
   bake lại navmesh từ NavigationRegion3D trong scene chính. Builder trong `tools/`
   chỉ dùng khi muốn tạo lại hình học, sẽ ghi đè chỉnh sửa trực tiếp trong scene con.
4. Sử dụng player/NPC từ `shared/scenes/player/player.tscn` và
   `shared/scenes/npc/guard.tscn`; lựa chọn các cơ chế phù hợp trong `features/`.
5. Cấu hình các hệ thống scene-local cần dùng (GameFlow, nhiệm vụ, checkpoint,
   stealth, âm thanh, HUD). Dùng mục tiêu riêng của bảo tàng.
6. Mở scene chính rồi nhấn **F6** để chạy thử riêng map.
7. Khi map chơi được, đăng ký vào `shared/scripts/game/level_catalog.gd` và thêm
   suite kiểm thử vào `tests/test_scene.gd` theo hướng dẫn kiến trúc.

Ưu tiên đặt nội dung riêng trong `maps/isg_museum/`. Phối hợp với nhóm khi cần sửa
`shared/`, `features/`, catalog hoặc bộ chạy kiểm thử chung.

## Git

```powershell
git switch hgmanh-work
git status
git add maps/isg_museum
git commit -m "Set up museum map workspace"
git push -u origin hgmanh-work
```

Gửi Pull Request vào nhánh tích hợp nhóm thống nhất (ví dụ `Development`).
Khi cần cập nhật từ `main`, commit công việc đang làm trước, rồi chạy
`git fetch origin` và `git merge origin/main` trên nhánh `hgmanh-work`.

Hướng dẫn: [Làm việc theo từng map](../../docs/architecture/MAP_LAYOUT.md).

Đồ họa sân v1.1: [báo cáo và ảnh Godot](docs/environment-art-v1_1/REPORT.md),
[benchmark](docs/environment-art-v1_1/BENCHMARK.md). Ngân sách cây ba LOD, tỷ lệ tán
và ánh sáng được cấu hình trong `resources/environment_art_layout.json`.
Quy trình dựng lại và giấy phép dẫn xuất: [derived README](assets/models/derived/README.md).
Báo cáo v1 giữ nguyên làm lịch sử kiểm thử.
