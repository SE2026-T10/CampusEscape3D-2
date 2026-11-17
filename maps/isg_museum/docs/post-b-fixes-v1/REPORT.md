# Post-B fixes v1 — ISG Museum

Ngày kiểm tra: 2026-11-17. Nhánh `hgmanh-work`. Godot **4.7.2 stable**, GL Compatibility, 1280×720; NVIDIA GeForce RTX 3050 6GB Laptop GPU. Kết quả đã lưu trong scene sản phẩm, mở `museum.tscn` hoặc `museum_editing.tscn` bằng F6; không cần chạy preview.

## 1. Kết quả ba mục

| Mục | Kết quả |
|---|---|
| Phần xây trên vòm | Đã thêm 40 phần xây trên bốn cạnh, cả hai tầng. Dùng đúng outer profile của viền đá; trát Gardner hồng, kín tới Y=4.5 / 9.12. Khoảng dưới vòm và các cửa sân giữ mở. |
| Ngưỡng A/B/C | Đã chia vùng hiển thị gỗ/đá/ngưỡng đủ chiều dày năm ô cửa. Mỗi điểm kiểm tra có một mặt sàn hiển thị, cùng Y=4.5; không tạo gờ collision. |
| Cửa | Đã tách gỗ ấm, phào và đồng vàng cũ; bổ sung lock plate và tay gạt hai mặt. Đọc được chi tiết trong bóng và ngoài sáng hiện hành. |

Đã duyệt ảnh Godot và các frame chuyển động thật: đi/cúi/xoay qua cửa, nhìn dọc vòm, mở/đóng cửa. Không thấy sọc chồng mặt tại các ngưỡng đã kiểm tra. [Video kiểm tra 39.53 giây](inspection/inspection.avi), [video gameplay 30.47 giây](gameplay/gameplay.avi). Đây là video Movie Maker trực tiếp từ Godot, không có ảnh AI.

## 2. Nguyên nhân và cách sửa

**Vòm:** nguồn chỉ có ribbon cong, chưa có phần xây bên trên. `arch_profile()` được dùng chung cho ribbon và spandrel; mặt trước/sau nối tới sàn/dầm thực. Góc sân cắt miter theo cùng tọa độ, không dịch cột. Tiếp xúc đá–vữa và nắp trong giữa các nhịp chỉ giữ trong collision, tránh mặt render trùng. Đã cô lập các vệt sáng ở đầu nhịp bằng [ảnh tắt normal](diagnostics/joint-no-normal.png) và [albedo phẳng/unlit tạm](diagnostics/joint-flat-unlit-diagnostic.png): làm cứng normal tại tiếp giáp nắp đã loại vệt sáng trong [ảnh cuối](after-east-lower.png). Tọa độ X/Z của batch mới cũng được chuẩn hóa ở bước cuối để hai nhịp không lệch vài phần triệu mét sau transform/save. Không thay normal/tangent của model Gothic nguồn.

**Ngưỡng:** không quy kết riêng khoảng 4 mm là nguyên nhân duy nhất. Cô lập stone/wood ở cùng camera được lưu trong [video chẩn đoán](threshold-isolation.avi), [metadata](diagnostics/threshold-isolation.json) và [frame đối chiếu](diagnostics/isolation-frames/). Probe trên **scene baseline** xác nhận mặt sàn gỗ và mặt trên lintel tầng dưới đều tại Y=4.5 ngay nửa ngưỡng phía phòng; phía hành lang còn lớp Gardner Y=4.504. Xem [baseline-floor-render-probe.log](baseline-floor-render-probe.log).

Sửa bằng cách giữ BoxMesh gốc phục vụ authoring và toàn bộ collider; ẩn render primitive rồi dựng shell giữ nguyên cạnh/mặt dưới, cắt phần top bị thay thế. Bỏ mặt tiếp xúc trên lintel ở nơi sàn tầng 2 đã phủ. Tách dải ngưỡng từ bounds lintel tầng 2 thực tế, trừ nó khỏi ô lát và cắt top gỗ tương ứng. Gỗ/đá/ngưỡng hiển thị phẳng Y=4.5; không đổi depth test, priority hay clipping camera.

**Cửa:** phép áp cũ gộp mọi phần thành `walnut_wood`/`dark_metal`, làm ô gỗ và đồng mất tương phản. Đã thêm ba preset độc lập:

| Role | Tint | Roughness / metallic |
|---|---|---|
| door_wood | [0.43, 0.285, 0.155] | 0.78 / 0 |
| door_trim | [0.35, 0.22, 0.11] | 0.78 / 0 |
| door_brass | [0.64, 0.46, 0.19] | 0.42 / 0.75 |

Vân Wood051 và bề mặt Metal032 dùng lại nguồn hiện có, không ghi đè nguồn. Gỗ/kim loại đều nhận sáng, không emission. Body + ba batch chi tiết = bốn mesh nhìn thấy/cửa; source chi tiết có tên ổn định dưới Panel. Hai template dùng chung cũng cập nhật cửa B/kho phục chế tầng 2. Không đổi màu nội thất dùng `walnut_wood` hoặc các role Gardner B khác.

## 3. Collision, navigation và phần được bảo vệ

- Giữ nguyên **832 hàng collision** cũ theo path/transform/layer/shape; chỉ thêm **48 body + 56 shape** cho phần xây/các góc. Có 40 concave skin được dựng từ chính profile, tám khối đầu góc và tám core nhỏ nằm trong phần xây để kín ray tại đường miter. Không collider trang trí cửa/ngưỡng.
- Ray thực chặn phần xây ở đủ 40 nhịp, thông phần dưới cả 40 nhịp, kín 16 tia góc thấp/cao; cover và đường đi cũ tiếp tục đạt suite.
- Đã bake navigation sau bổ sung collision: **402 polygon**. SHA-256 navmesh trước/sau **giống hệt**; không sinh đường trên mái hoặc vùng thông tầng. [Chi tiết](collision-navigation.json).
- Player đứng/cúi và guard navigate thật qua đủ năm cửa hai chiều; cửa B vẫn dùng K, từ chối đóng khi bị chiếm và giữ đúng body/link đóng/mở.
- **364 tệp được bảo vệ** giữ nguyên SHA-256, gồm script gameplay, rig/animation/material nhân vật và preset Gardner cũ. **254 tệp bằng chứng A1/A2/B** giữ nguyên. [Hash](protected-hashes.json).

## 4. Authoring và kiểm tra

Nguồn chính sửa: `environment_art_builder.gd`, `courtyard_palette.gd`, `prepare_environment_modules.gd`, `apply_environment_art.gd`; JSON layout/palette và ba preset cửa. Cập nhật verify art để chỉ loại đúng collision mới khỏi phép so baseline cũ; suite mới kiểm riêng từng bổ sung. Tạo `post_b_fixes_tests.gd`, `verify_post_b_fixes.gd`, `capture_post_b_fixes.gd`; đăng ký suite ở `tests/test_scene.gd`. `build_geometry.gd` / `material_palette.gd` dùng entry point đã có nên không cần sửa thêm ở đợt này.

Đã sinh module → geometry → materials → art, sau đó lặp materials/art và reload. Chín scene có cùng semantic signature và số node/mesh/shape ở cả ba snapshot; [đối chiếu](rebuild-comparison.json). `--check` và các lượt verify không đổi **63 scene/manifest/preset/tài nguyên** trong danh sách [trước](readonly-before.json) / [sau](readonly-after.json). Scene sinh lại ngoài phạm vi trực tiếp có thể đổi resource ID do pack/save; gameplay và tài nguyên nhân vật không đổi.

**785 kiểm tra museum** ở các runner riêng đều đạt. Runner chung có `All tests passed`. Các suite chạy `--fixed-fps 60`; runner chung cũng dùng cờ này để tăng tốc thời gian mô phỏng. APPDATA chỉ đổi trong môi trường tiến trình con sang `.local/post-b-fixes-userdata`; shell/user settings được giữ nguyên.

| Lệnh / tool | Exit | Checks | Log |
|---|---:|---:|---|
| `import` | 0 | — | [import.log](import.log) |
| `scripts` | 0 | — | [scripts.log](scripts.log) |
| `materials_check` | 0 | — | [materials_check.log](materials_check.log) |
| `art_check` | 0 | — | [art_check.log](art_check.log) |
| `verify_courtyard_palette` | 0 | 43 | [verify_courtyard_palette.log](verify_courtyard_palette.log) |
| `verify_post_b_fixes` | 0 | 31 | [verify_post_b_fixes.log](verify_post_b_fixes.log) |
| `verify_environment_art` | 0 | 97 | [verify_environment_art.log](verify_environment_art.log) |
| `verify_blockout` | 0 | 114 | [verify_blockout.log](verify_blockout.log) |
| `verify_service` | 0 | 31 | [verify_service.log](verify_service.log) |
| `verify_staff_room` | 0 | 55 | [verify_staff_room.log](verify_staff_room.log) |
| `verify_empty_frame` | 0 | 48 | [verify_empty_frame.log](verify_empty_frame.log) |
| `verify_carry` | 0 | 83 | [verify_carry.log](verify_carry.log) |
| `verify_guard_visuals` | 0 | 42 | [verify_guard_visuals.log](verify_guard_visuals.log) |
| `verify_npc_visuals` | 0 | 65 | [verify_npc_visuals.log](verify_npc_visuals.log) |
| `verify_editing_mode` | 0 | 75 | [verify_editing_mode.log](verify_editing_mode.log) |
| `verify_room_feedback` | 0 | 30 | [verify_room_feedback.log](verify_room_feedback.log) |
| `verify_contract_variants` | 0 | 71 | [verify_contract_variants.log](verify_contract_variants.log) |
| `runner` | 0 | 31 | [runner.log](runner.log) |
| Python thật `-B tools/ci/check_layout.py` | 0 | 883 references | [check-layout.log](check-layout.log) |

Executable: `.local/godot/Godot_v4.7.2-stable_win64_console.exe`. Python: `C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe`. Lệnh đầy đủ, thời lượng, exit code, capture và mọi attempt trước đó nằm trong [VALIDATION.json](VALIDATION.json) / [results.json](results.json). Các log attempt không bị xóa hay coi là lượt đạt cuối. [Danh sách file](CHANGED_FILES.txt), [palette cuối](final-courtyard-palette.json), [layout cuối](final-environment-art-layout.json).

## 5. Ảnh, video và điều kiện so sánh

**23 cặp trước/sau** khớp position/rotation/FOV/near/far/viewport/renderer và toàn bộ lighting metadata: [đối chiếu](camera-comparison.json), [trước](before-camera-metadata.json), [sau](after-camera-metadata.json). Ánh sáng, sky, ambient, nắng và exposure giữ nguyên.

| Góc vòm | Trước | Sau |
|---|---|---|
| Tầng 1 | [Ảnh](before-arcade-lower.png) | [Ảnh](after-arcade-lower.png) |
| Tầng 2 | [Ảnh](before-arcade-upper.png) | [Ảnh](after-arcade-upper.png) |
| Góc dưới | [Ảnh](before-corner-lower.png) | [Ảnh](after-corner-lower.png) |
| Góc trên | [Ảnh](before-corner-upper.png) | [Ảnh](after-corner-upper.png) |

| Cạnh | Dưới | Trên |
|---|---|---|
| north | [Tầng 1](after-north-lower.png) | [Tầng 2](after-north-upper.png) |
| south | [Tầng 1](after-south-lower.png) | [Tầng 2](after-south-upper.png) |
| west | [Tầng 1](after-west-lower.png) | [Tầng 2](after-west-upper.png) |
| east | [Tầng 1](after-east-lower.png) | [Tầng 2](after-east-upper.png) |

Ảnh tám góc có tên `after-corner-X-Z-floor-N.png`; [metadata bổ sung](after-details-camera-metadata.json).

| Ngưỡng | Phía hành lang | Phía phòng |
|---|---|---|
| A bắc | [Trước](before-threshold-a-north-hall.png) / [Sau](after-threshold-a-north-hall.png) | [Trước](before-threshold-a-north-room.png) / [Sau](after-threshold-a-north-room.png) |
| A nam | [Trước](before-threshold-a-south-hall.png) / [Sau](after-threshold-a-south-hall.png) | [Trước](before-threshold-a-south-room.png) / [Sau](after-threshold-a-south-room.png) |
| B | [Trước](before-threshold-b-hall.png) / [Sau](after-threshold-b-hall.png) | [Trước](before-threshold-b-room.png) / [Sau](after-threshold-b-room.png) |
| C tây | [Trước](before-threshold-c-west-hall.png) / [Sau](after-threshold-c-west-hall.png) | [Trước](before-threshold-c-west-room.png) / [Sau](after-threshold-c-west-room.png) |
| C đông | [Trước](before-threshold-c-east-hall.png) / [Sau](after-threshold-c-east-hall.png) | [Trước](before-threshold-c-east-room.png) / [Sau](after-threshold-c-east-room.png) |

| Cửa tầng 1 | Mặt 1 | Mặt 2 |
|---|---|---|
| entrance | [Trước](before-door-entrance-front.png) / [Sau](after-door-entrance-front.png) | [Trước](before-door-entrance-back.png) / [Sau](after-door-entrance-back.png) |
| staff | [Trước](before-door-staff-front.png) / [Sau](after-door-staff-front.png) | [Trước](before-door-staff-back.png) / [Sau](after-door-staff-back.png) |
| storage | [Trước](before-door-storage-front.png) / [Sau](after-door-storage-front.png) | [Trước](before-door-storage-back.png) / [Sau](after-door-storage-back.png) |
| service | [Trước](before-door-service-front.png) / [Sau](after-door-service-front.png) | [Trước](before-door-service-back.png) / [Sau](after-door-service-back.png) |

[Tay nắm trước](before-door-handle.png) / [sau](after-door-handle.png). [Mở/đóng thực tế](inspection/inspection-movie.json): 19 hành động/movement đạt. [Gameplay](gameplay/gameplay.json): 23 hành động/movement đạt; đủ chín guard AI hoạt động, cả hai thang, N0, quiz/vé, K và mang T2. [Frame kiểm tra](inspection/frame-index.json), [frame gameplay](gameplay/frame-index.json) là payload MJPEG gốc của Godot, không chỉnh ảnh.

## 6. Giới hạn và lưu ý

- Capture dùng Player.camera thật; các góc cận cố định là QA ở vị trí camera được ghi rõ. Video có cắt anchor giữa các đoạn để rút ngắn; B mở tạm trong video threshold, kho dùng mã lịch hiện tại. Trong video gameplay chỉ tắt terminal capture của StealthDirector tại fixture để hoàn tất quay, chín guard/sensor vẫn theo trạng thái AI. Không lưu fixture, teleport hoặc hotkey QA vào scene sản phẩm.
- Đánh giá chuyển động bằng các frame gốc xuất từ AVI, gồm chuỗi liên tiếp tại ngưỡng, cùng kết quả di chuyển thật; đây không phải một phiên kiểm thử thủ công bằng bàn phím F6 của người dùng.
- Log Windows vẫn có cảnh báo certificate store. Runner Post-B riêng còn cảnh báo dọn tài nguyên lúc thoát (8 ObjectDB / 3 resource) dù exit 0; không sửa shared runtime để xử lý vấn đề teardown của tooling này. Không có lỗi script trong các lượt đạt cuối.
- Movie Maker khóa 30 FPS và có chi phí encode; không dùng thời gian quay để kết luận hiệu năng gameplay. Draw calls/primitives cùng góc được giữ trong camera metadata, không coi đó là benchmark GPU.
