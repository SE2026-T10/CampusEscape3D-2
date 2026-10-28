# Map bảo tàng — hgmanh

Người phụ trách: **hgmanh**. Nhánh phát triển: **`hgmanh-work`**.

Map ID: **`museum`**. Thư mục làm việc: `maps/museum/`.
Nhánh được tạo từ `main` tại commit `13807bd` ngày 27/10/2026.
Hiện có phòng demo chơi được tại `res://maps/museum/scenes/museum.tscn`:
ba tác phẩm, dây, điểm thoát, một bảo vệ tuần tra và HUD nhiệm vụ.
Mở scene rồi nhấn **F6** để thử riêng; map chưa đăng ký trong menu chung.

Chi tiết: [Bước 4 — bảo vệ tuần tra](docs/step-04-patrol.md),
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
2. Mở scene chính `res://maps/museum/scenes/museum.tscn` với node gốc `Museum`.
3. Mở rộng môi trường, collision và NavigationRegion3D/NavMesh riêng của bảo tàng.
4. Sử dụng player/NPC từ `shared/scenes/player/player.tscn` và
   `shared/scenes/npc/guard.tscn`; lựa chọn các cơ chế phù hợp trong `features/`.
5. Cấu hình các hệ thống scene-local cần dùng (GameFlow, nhiệm vụ, checkpoint,
   stealth, âm thanh, HUD). Dùng mục tiêu riêng của bảo tàng.
6. Mở scene chính rồi nhấn **F6** để chạy thử riêng map.
7. Khi map chơi được, đăng ký vào `shared/scripts/game/level_catalog.gd` và thêm
   suite kiểm thử vào `tests/test_scene.gd` theo hướng dẫn kiến trúc.

Ưu tiên đặt nội dung riêng trong `maps/museum/`. Phối hợp với nhóm khi cần sửa
`shared/`, `features/`, catalog hoặc bộ chạy kiểm thử chung.

## Git

```powershell
git switch hgmanh-work
git status
git add maps/museum
git commit -m "Set up museum map workspace"
git push -u origin hgmanh-work
```

Gửi Pull Request vào nhánh tích hợp nhóm thống nhất (ví dụ `Development`).
Khi cần cập nhật từ `main`, commit công việc đang làm trước, rồi chạy
`git fetch origin` và `git merge origin/main` trên nhánh `hgmanh-work`.

Hướng dẫn: [Làm việc theo từng map](../../docs/architecture/MAP_LAYOUT.md).
