# Gardner — đợt B trong scene sản phẩm

> Hồ sơ lịch sử đã tổ chức lại; kết luận, số đo và kết quả gốc được giữ nguyên. [Mục lục](../../README.md) · [images](images/) · [videos](videos/) · [logs](logs/) · [data](data/) . Raw log/JSON có thể ghi đường dẫn cũ; tra manifest migration từ mục lục.


Ngày triển khai: **2026-11-17**. Engine **Godot 4.7.2 stable / GL Compatibility**, nhánh `hgmanh-work`.

**Bảng vật liệu đã được bake vào scene/resource sản phẩm**, stage `B_production`. Mở `scenes/museum.tscn` hoặc `scenes/museum_editing.tscn`, nhấn **F6** để sử dụng. Không cần preview, F7 hoặc script gán màu khi bắt đầu lượt. Geometry/module lưu trên đĩa cũng hiển thị vật liệu trong editor. Chế độ editing tiếp tục loại guard và giữ hai NPC.

## Hai tinh chỉnh cuối

**Tay vịn:** tint cuối `[0.56, 0.535, 0.465]`, cùng họ be xám với thân; giữ contrast 0.13, normal 0.08, roughness 0.82. Cap và thân có resource/role riêng, kể cả sau batching. Không dùng emission/unshaded, không sửa đèn. Vùng bóng vẫn có chuyển sắc tự nhiên; vùng nắng không bị ép sáng bằng shader.

**Tường vườn:** ba ảnh cùng camera/ánh sáng trước khi chỉnh: [hiện tại A2](images/diagnostics/diagnostic-current.png), [tắt normal](images/diagnostics/diagnostic-no-normal.png), [albedo phẳng + normal hiện tại](images/diagnostics/diagnostic-flat-albedo.png). Tắt normal vẫn còn hạt rõ; albedo phẳng làm hạt gần như biến mất. Qua phép so sánh này, nguyên nhân chính là chi tiết màu albedo, không phải normal hoặc batching.

Giữ tint `[0.47, 0.43, 0.36]`, normal_strength **0.20**, roughness **0.98**; giảm contrast **0.45 → 0.28**. Thêm `albedo_lowpass_size = 128`: lọc offline albedo từ 512 xuống 128 rồi nội suy bilinear về 512, giữ biến thiên khoáng lớn và mottle seed ổn định. [Ảnh cuối](images/after-garden-wall-closeup.png) còn biến thiên đá nhẹ, không thành màu phẳng. NormalGL và toàn bộ texture nguồn giữ nguyên.

[Snapshot A2](data/palette-a2.json), [cấu hình cuối](data/palette-final.json). Các giá trị tường hồng, sàn, viền 0.22 m, chu kỳ texture sàn 2.4 m, đá cột và tượng giữ theo A2. Không chỉnh ánh sáng, sky, exposure, shadow hoặc renderer.

## Những vùng đã áp dụng

- Vữa hồng ở mặt quay ra hành lang của tường Z6 (+Z), Z24 (-Z), X9 (+X), X27 (-X), cả hai tầng, gồm lintel và đúng các khoảng cửa hiện có.
- Paving và viền ở hành lang vòng tầng 1/tầng 2, **sảnh tầng 1 và phòng đệm nam tầng 2 X9..27/Z24..30**. Mỗi tầng có 288 m² lớp hoàn thiện thuộc phạm vi. Khoảng sân thông tầng, lỗ thang, sàn gỗ phòng và bê tông kho giữ nguyên.
- Cột/vòm/bệ dùng `architectural_stone`; thân lan can `balustrade_stone`; cap `balustrade_cap`; tường vườn `garden_wall_stone`; tượng/bồn phun `sculpture_stone`; sáu cửa dùng hai scene cửa map-local nhận `walnut_wood`/`dark_metal`; kim loại kiến trúc phù hợp nhận `dark_metal`.
- Giữ vật liệu lá, kính, nước, tác phẩm, skin và trang phục nhân vật. Không sửa rig, clip, AI hoặc luật tương tác.

## Authoring và rebuild

`courtyard_palette.gd` có entry point offline `apply_geometry_palette`, `assign_architecture_roles`, `apply_door_palette`, `validate_palette`. Tính transform theo đầy đủ chuỗi cha; không cần SceneTree hoặc khởi tạo gameplay.

Giữ nguyên BoxMesh của tường/sàn làm dữ liệu kích thước cho finish A/B/C và wainscot. Nhóm có quản lý **`Geometry/GardnerPalette`** gồm một mesh tường và hai mesh sàn, dùng các surface theo role. Lớp tường cách mặt gốc 4 mm. Sàn ở Y0.004/Y4.504; các plane Marble cũ trên hành lang tầng trên được thay bằng lớp này. Các cell floor/border có miền riêng, không chồng hai lớp đồng phẳng. Không sửa collider hoặc bề mặt navigation.

Material palette và art builder đều gọi helper. Art gán role trước batching; batch key phân biệt material/role, gồm special-case spindle và các BoxMesh giống nhau. Mesh nhiều surface không bị gộp vào một override. Nhánh chia surface của preview cũ cũng được sửa để giữ đúng material từng surface, hỗ trợ indexed/non-indexed và transform cha.

Module Gothic được sinh với role đá kiến trúc mới. Hai template cửa được bake trực tiếp; tất cả instance của hai template trong map đều là sáu cửa thuộc phạm vi. Không lưu override sâu theo từng instance cửa. Scene sản phẩm không có F7/F8 hay teleport QA. Preview cũ ghi rõ baseline hiện tại là B, F7 không dùng; công cụ capture A từ chối chạy ở stage B để tránh ghi đè bằng chứng A1/A2.

Đã chạy lại prepare → import → module → geometry → materials → art, rồi lặp materials/art. **Cả 9 scene đầu ra có cùng semantic signature, số node/mesh/collider trước và sau rebuild:** [so sánh](data/rebuild-comparison.json), [trước](data/rebuild-before.json), [sau](data/rebuild-after.json). `--check` tiếp tục chỉ đọc.

## Ảnh sản phẩm và video

Ảnh dưới đây lấy trực tiếp từ **museum.tscn**, qua Player.camera; không qua script preview và không dùng AI. [Metadata trước](data/before-camera-metadata.json), [sau](data/after-camera-metadata.json), [so sánh 11 cặp](data/camera-comparison.json) khóa pose, FOV 75°, 1280×720 và toàn bộ ánh sáng.

| Góc | Trước | Sau |
|---|---|---|
| Tổng thể | [ảnh](images/before-overview.png) | [ảnh](images/after-overview.png) |
| Tầm mắt sân | [ảnh](images/before-player-eye.png) | [ảnh](images/after-player-eye.png) |
| Tường/cột | [ảnh](images/before-wall-column-closeup.png) | [ảnh](images/after-wall-column-closeup.png) |
| Sàn/viền | [ảnh](images/before-floor-border.png) | [ảnh](images/after-floor-border.png) |
| Lan can trong bóng | [ảnh](images/before-upper-balustrade.png) | [ảnh](images/after-upper-balustrade.png) |
| Tường vườn | [ảnh](images/before-garden-wall-closeup.png) | [ảnh](images/after-garden-wall-closeup.png) |
| Sảnh | [ảnh](images/before-lobby.png) | [ảnh](images/after-lobby.png) |
| Phòng đệm nam | [ảnh](images/before-south-buffer.png) | [ảnh](images/after-south-buffer.png) |
| G3 | [ảnh](images/before-staff.png) | [ảnh](images/after-staff.png) |
| N0 | [ảnh](images/before-teammate.png) | [ảnh](images/after-teammate.png) |
| Tiếp đón | [ảnh](images/before-receptionist.png) | [ảnh](images/after-receptionist.png) |

Ảnh kiểm tra thêm: [bốn cạnh/hai tầng và nội thất A/B/C](data/details/detail-camera-metadata.json), [A](images/details/detail-gallery-a.png), [B](images/details/detail-gallery-b.png), [C](images/details/detail-gallery-c.png). [Scene editing chạy trực tiếp](images/editing/editing-overview.png) dùng cùng bảng màu đã lưu, không có guard.

[Video gameplay](videos/gameplay.avi), [kết quả từng bước](data/gameplay/gameplay.json). Fixture quay chỉ tắt terminal capture của StealthDirector để không ngắt video; chín AI tiếp tục hoạt động, giữ quy tắc cảm biến theo phase (G3 ngủ có thị giác tắt). Có chuyển anchor giữa các đoạn, không phải lượt chơi liên tục. Thực hiện API tương tác thật và input di chuyển Player thật: N0, nhận hợp đồng, cửa chính, ba câu đúng để nhận vé, đi lên thang A/xuống thang B, lấy K và mang T2 qua cửa ra hành lang. Các hỗ trợ này chỉ nằm trong tool QA, không lưu vào scene sản phẩm.

## Kiểm tra và tính toàn vẹn

[VALIDATION.json](VALIDATION.json) ghi lệnh/argv, exit code, kết quả cuối và hash. [CHANGED_FILES.txt](data/CHANGED_FILES.txt) liệt kê file. Các suite museum giữ kiểm tra khớp nối, foliage exclusions, cover, ray nhìn, chống rơi, thang, tuần tra, G3/G6, animation, hội thoại, vé và T2; assertion vật liệu cũ được thay bằng đúng role tương ứng.

Collision geometry trước/sau có cùng **832 dòng signature**, SHA-256 `e2874a406a25e34477fa03a8eb260f4bc3125ee80d2eae2fc33132f9253ee354`: [trước](data/before-collision.json), [sau](data/after-collision.json). Không bake navigation; hash navigation giữ nguyên. Hash rig/animation/material nhân vật và script gameplay ngoài phạm vi giữ nguyên. Bằng chứng A1/A2 được giữ nguyên; khác đợt A, các scene/module/manifest sản phẩm thuộc danh sách được phép thay đổi ở B.

Godot dùng executable 4.7.2 trong `.local/godot/`. Python dùng interpreter uv đã có. APPDATA riêng chỉ đặt trong môi trường con của tiến trình kiểm tra; không đổi ProjectSettings hoặc thiết lập người dùng.

Kết quả cuối: **747 kiểm tra museum, 0 failures**, tất cả suite dưới đây exit **0**:

| Suite | Checks |
|---|---:|
| courtyard_palette | 40 |
| environment_art | 93 |
| blockout | 114 |
| room_feedback | 30 |
| guard_visuals | 42 |
| staff_room | 55 |
| npc_visuals | 65 |
| service | 31 |
| contract_variants | 71 |
| empty_frame | 48 |
| carry | 83 |
| editing_mode | 75 |

Runner chung cuối: `godot --headless --path . --fixed-fps 60 res://tests/test_scene.tscn`, **All tests passed**, exit **0**, khoảng **166 giây**: [log](logs/runner.log). Lượt không fixed-fps ban đầu đã dừng và thay bằng lượt mô phỏng cố định này; không tính log dở dang là kết quả đạt.

`check_scripts.gd`: **363 scripts**, exit 0. Python layout: **867 runtime references**, exit 0. Prepare/import/module/geometry/material/art và các lượt lặp đều exit 0. Hai stage A/B hợp lệ được chấp nhận; stage lạ bị từ chối, exit **1 đúng mong đợi**. Fixture stage tạm thời được khôi phục byte-for-byte về B. Hai kiểm tra indexed/non-indexed/material và transform lồng nhau đã đưa vào suite courtyard chính.

**33/33 file giữ nguyên hash qua hai lệnh `--check`**, gồm scene, module, manifest, navmesh, config và tài nguyên palette. Prepare lặp sinh lại **20/20 file resource giống byte**. **258 file ngoài phạm vi**, **18 texture nguồn** và **95 file bằng chứng A1/A2** giữ nguyên hash: [protected](data/protected-hashes.json), [nguồn texture](data/source-texture-hashes.json), [read-only](data/read-only-check.json). Danh sách scene/builder/manifest được phép thay đổi ghi riêng trong protected-hashes, không áp yêu cầu bất biến của đợt A lên scene sản phẩm B.

## Hiệu năng và giới hạn

[BENCHMARK.md](data/BENCHMARK.md): cùng máy, viewport/camera/ánh sáng, product scene đóng băng; VSync/frame cap tắt chỉ trong tool rồi khôi phục. Draw calls **1.278 → 1.224**, process-frame interval p50 **2.875 → 2.840 ms**; chi phí tách lớp vật liệu được bù một phần bởi batching BoxMesh theo material. Không diễn giải thành dư địa toàn map hoặc GPU frame time. Video có chín AI là kiểm tra gameplay/hình ảnh, không dùng FPS Movie Maker bị khóa để kết luận hiệu năng.

Các diagnostic certificate store Windows, một số tài nguyên/orphan lúc thoát headless và cảnh báo navigation đồng bộ của runner được giữ trong log. Nhánh override sâu từng instance cửa thử nghiệm từng gây semantic mismatch và một lượt chẩn đoán crash; nhánh này đã bỏ, thay bằng bake template cửa. Không kết luận chắc nguyên nhân nội bộ của crash. Đường `--check` bắt buộc và các kiểm tra cuối đạt. Không tuyên bố mọi log hoàn toàn sạch. Chưa đo GPU timing hoặc lượt gameplay uncapped dài; không có công việc triển khai sản phẩm nào đang chờ duyệt preview.
