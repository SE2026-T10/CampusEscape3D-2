# Courtyard palette — A2

Ngày kiểm tra: **2026-11-17**. Stage giữ **`A_preview_only`**. Chỉ cập nhật preview và tài nguyên `gardner_palette_v1`; chưa triển khai đợt B. Không thay ánh sáng, hình học, collision, navigation, nhân vật hoặc gameplay. Không bake navmesh.

## Thông số A1 → A2

| Role | Thông số | A1 | A2 |
|---|---|---|---|
| courtyard_plaster | tint | [0.59, 0.335, 0.275] | [0.67, 0.43, 0.36] |
| corridor_floor | tint | [0.43, 0.405, 0.365] | [0.50, 0.46, 0.39] |
| corridor_floor | contrast | 1.45 | 1.0 |
| balustrade_cap | tint | [0.46, 0.435, 0.375] | [0.52, 0.495, 0.43] |
| garden_wall_stone | tint | [0.36, 0.335, 0.285] | [0.47, 0.43, 0.36] |
| garden_wall_stone | normal_strength | 0.32 | 0.20 |

Giữ nguyên mọi trường cấu hình khác, gồm thân lan can `[0.56, 0.535, 0.465]`, border, seed/mottle, tỷ lệ texture, camera và anchor. `tile_m = 2.4` là chu kỳ lặp texture sàn; viền vẫn rộng `0.22 m`. [Cấu hình A1](palette-a1.json), [cấu hình A2](palette-a2.json), [sáu thay đổi máy đọc được](parameter-changes.json).

## Mở preview

Mở [courtyard_palette_preview.tscn](../../../scenes/previews/courtyard_palette_preview.tscn), nhấn **F6**. WASD/chuột đi và nhìn; **F7** chuyển vật liệu sản phẩm gốc ↔ đề xuất A2; **F8** đổi điểm đứng/tầng. F7 không chuyển A1 ↔ A2: dùng các ảnh cùng góc dưới đây để so hai phương án. Scene sản phẩm tiếp tục dùng bảng màu cũ.

## Đối chiếu trực tiếp từ Godot

Cả hai lượt dùng **Player.camera**, Godot **4.7.2 stable**, **GL Compatibility**, **1280×720**, **FOV 75°**. Giữ nguyên sky, ambient, nắng, đèn, shadow, exposure và các hiệu ứng hiện hành. Cảnh được đóng băng khi chụp; video bật lại di chuyển. Bộ A1 cũ được giữ nguyên. Đã chụp bổ sung A1 trước khi sửa JSON để có góc tường vườn trùng khớp và một bộ tham chiếu A1 đầy đủ tại đây.

| Góc | A1 | A2 |
|---|---|---|
| Tổng thể | [ảnh](a1-reference/a1-overview.png) | [ảnh](a2-overview.png) |
| Mắt Player | [ảnh](a1-reference/a1-player-eye.png) | [ảnh](a2-player-eye.png) |
| Tường/cột | [ảnh](a1-reference/a1-wall-column-closeup.png) | [ảnh](a2-wall-column-closeup.png) |
| Sàn/viền | [ảnh](a1-reference/a1-floor-border.png) | [ảnh](a2-floor-border.png) |
| Lan can tầng 2 | [ảnh](a1-reference/a1-upper-balustrade.png) | [ảnh](a2-upper-balustrade.png) |
| Tường vườn mới | [ảnh](a1-reference/a1-garden-wall-closeup.png) | [ảnh](a2-garden-wall-closeup.png) |

[Metadata A1 gốc](camera-metadata-a1-original.json), [A1 chụp bổ sung](a1-reference/camera-metadata.json), [A2](camera-metadata.json), [so sánh](camera-comparison.json). Cả **6 cặp** khớp camera/ánh sáng; 5 góc A1 chụp lại cũng khớp điều kiện của bộ A1 gốc. Metadata còn ghi draw calls/primitives theo góc; tổng thể A1/A2 đều **1.215 draw calls / 1.646.967 primitives**. Đây là số đếm render, không phải benchmark frame time mới.

[Video A2](a2-preview-walk.avi): **16,47 giây, 494 frame, 30 fps**, quay bằng Godot Movie Maker. Đi từ hành lang vào sân, đi dọc hành lang/sát tường vườn, nhìn xuống sàn từ điểm đứng Player, nhìn lan can từ tầng 1 rồi tầng 2. Bốn đoạn đi dùng input và collision Player thật, đều đạt đích: [walk.json](walk.json). Có chuyển anchor QA giữa các đoạn/tầng; video không phải một lượt đi liên tục qua cầu thang. [Metadata video](movie-metadata.json), [log quay](capture-a2.log). Ảnh/video không dùng AI.

### Nhận xét sau khi xem ảnh và các frame video

- Tường trong bóng chuyển từ đỏ gạch tối sang hồng đất phai dịu hơn; ở mảng nắng vẫn có sắc ấm, cột ngà tiếp tục nổi rõ. Loang rộng và chất trát được giữ nguyên.
- Sàn sáng/ấm hơn, mạch lát bớt tương phản đen; cách lát vẫn dễ đọc. Viền vẫn tối rõ vì role này giữ nguyên theo yêu cầu.
- Cap lan can sáng hơn A1, chênh với thân nhỏ hơn. Ở hành lang tầng 2 trong bóng, tay vịn vẫn đọc thành một dải xám tương đối tối dưới ánh sáng cũ; cần người dùng duyệt mức này.
- Tường vườn sáng hơn, tách khỏi cây và bóng tốt hơn; normal giảm nên cảm giác ráp nhẹ hơn. Hạt màu từ Concrete025 vẫn thấy khi nhìn gần, vì contrast/texture không đổi trong lượt này.
- Cột, vòm, tượng, đài phun, kính, cây và trần gỗ giữ nguyên. Chưa thay đèn để làm sáng thêm vùng bóng.

## Công cụ và tài nguyên

- `resources/courtyard_palette.json`: đúng sáu trường thay đổi trong bảng trên.
- `tools/prepare_courtyard_palette.gd`: `--check` đối chiếu normal/roughness/metallic, texture path, triplanar/scale và pixel albedo tái tính từ JSON; chỉ đọc, không ghi tài nguyên. Chặn stage ngoài `A_preview_only`. Logic sinh albedo được dùng chung, kết quả sinh không đổi với những role giữ nguyên.
- `tools/capture_courtyard_palette.gd`: thêm `--output=...`, `--prefix=...`, `--garden-wall`, `--review-walk`; mặc định vẫn ghi theo hành vi A1. Thêm snapshot cấu hình/tham số chạy cho lượt capture. Không sửa camera A1 có sẵn.
- Đã sinh lại preset/texture và preview bằng công cụ hiện có. Chỉ **5/20 file tài nguyên dẫn xuất** đổi hash: bốn PNG của plaster/floor/cap/garden wall và `garden_wall_stone.tres` (normal). 15 file còn lại giữ nguyên, gồm vật liệu cột/tượng/thân lan can.
- Giữ nguyên test/capture/nhân vật đã có; không sửa pipeline hay preset sản phẩm. [Danh sách file A2](CHANGED_FILES.txt).

## Kiểm tra thực tế

[VALIDATION.json](VALIDATION.json) và [results.json](results.json) ghi đầy đủ argv, exit code, log. Godot dùng executable 4.7.2 trong `.local/godot/`; Python dùng interpreter uv đã có. APPDATA chỉ đặt trong bản sao môi trường của tiến trình kiểm tra tại `.local/courtyard-palette-userdata`, không đổi thiết lập người dùng.

| Lệnh/công việc | Exit | Kết quả |
|---|---:|---|
| Capture A1 trước chỉnh sửa | 0 | Đủ bộ tham chiếu và cận tường vườn |
| Prepare `--check` trước sinh lại | **1 (mong đợi)** | Phát hiện 4 albedo A1 không khớp JSON A2 và normal tường vườn cũ |
| `prepare_courtyard_palette.gd` | 0 | 10 role, 0 failures |
| `--headless --editor --quit` | 0 | Import xong |
| `build_courtyard_palette_preview.gd` | 0 | Preview build OK |
| `prepare_courtyard_palette.gd -- --check` | 0 | JSON/preset/albedo khớp |
| `tools/ci/check_scripts.gd` | 0 | 362 scripts hợp lệ |
| `verify_courtyard_palette.gd` | 0 | **39 checks, 0 failures** |
| Python `-B tools/ci/check_layout.py` | 0 | **854 runtime references** |
| Prepare lần hai + check lần hai | 0 / 0 | Cả 20 file giữ cùng hash; check chỉ đọc |
| Capture/video A2 | 0 | Đủ 6 ảnh, video và metadata |

Suite hiện có tiếp tục kiểm tra đúng mặt/vùng vật liệu, bảo toàn bounds/diện tích bề mặt, collision, các mesh/material ngoài phạm vi, khôi phục F7, anchor F8 tầng 2 và di chuyển Player thật. Prepare/apply lặp không tăng binding/hình học. Không bỏ hoặc làm yếu assertion cách ly preview. Chưa chạy full runner hoặc regression sản phẩm cho đợt B.

**199/199 file sản phẩm được bảo vệ giữ nguyên hash**: [trước](product-before.json), [sau](product-after.json). **42/42 file bằng chứng A1 cũ giữ nguyên hash**: [danh sách](a1-evidence-before.json). [Rebuild/check chỉ đọc](rebuild-check.json). Không có thay đổi collision/navigation.

Các log vẫn có diagnostic đọc certificate store Windows và, khi thoát capture GL, hai texture chưa giải phóng (349.524 byte/texture), giống A1; process exit 0, ảnh/video tạo đủ. Chưa xác định nguồn diagnostic texture, không ghi nhận là đã sửa. Thời gian Movie Maker gồm encoding và bị khóa 30 fps, không dùng để kết luận hiệu năng gameplay.

**Kết thúc ở preview A2 để duyệt. Chưa triển khai đợt B.**
