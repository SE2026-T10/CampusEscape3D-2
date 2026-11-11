# ISG Museum — environment art v1

Triển khai ngày 11–12/11/2026, Godot **4.7.2.stable.official.ed1daf0bf**, **GL Compatibility**. Baseline scene lấy từ `99c43b3`; các sửa đổi asset có sẵn và ba GLB người dùng cung cấp được bảo tồn. Không sửa `shared/`, controller, AI, rig hoặc luật hợp đồng.

## Nội dung đã lưu

- Sân hai tầng dùng mesh cột chùm/vòm nhọn Gothic đã tách và căn gốc; cột góc dùng chung giữa hai cạnh. Đá kem, lan can con tiện, hai mặt mái kính riêng với khung/xà chia ô; mép mái 9 m, đỉnh 11,2 m. Trần phòng/hành lang là phần visual, không sinh navigation.
- Vách có phần đá nhìn thấy cao 0,9 m, lõi bụi và cây cao thêm 0,3 m; giữ collider che tới 1,2 m. Bốn lối sân giữ đủ 2 m, không có cột giữa cửa.
- Bốn tượng Terpsichore tại tọa độ đã giao, trên bệ 1,3 × 1,3 × 1,2 m. Tổng cao 2,47 m; vật liệu tượng nhận sáng. Không giữ chậu lớn hoặc collider khác footprint.
- Đài phun chỉ giữ mesh bồn từ nguồn, bỏ cột/tầng nước trên; thêm mặt nước và tia nhỏ. Tâm, đường vòng 2,2–4 m và bốn nhánh giữ nguyên.
- Bụi, dương xỉ, hai cây tán cao đã giảm lưới; cây chậu trong nhà và cây trong bồn sân trước. Không instance cây nguồn hơn hai triệu tam giác trong scene chơi.
- Bàn A và mặt kín che người cúi, ghế G3, đèn, cassette, ảnh bàn; giữ lịch, giấy, locker/chìa, chai/lon F và vòng H. Kho dùng kệ thép, tủ gỗ, dây thật; thêm bàn/kệ/tủ phục chế ở phía bắc phòng kho tầng 2, giữ depot trống.
- Kệ và tủ Lịch sử, đế tủ trưng bày đã tách kính; S1 thêm lông cánh, S2 dùng abstract bust, H2 dùng đồng hồ nguồn. H1 vẫn có huy chương và ruy băng xanh. `Glass`, `Shards`, `Artifact`, `Lid` vẫn độc lập.
- T1/T2/T3 dùng phần khung Fancy đã tách canvas; A2/C2 và bản đồ dùng riêng surface khung Hanging, bỏ artwork/glass nguồn. Mặt tranh dùng ảnh Turner; T1 đặt visual khung dưới `Frame`, T2 giữ toàn bộ dưới `Visual`. Giữ mặt sau/envelope của T2, không thêm world collider khi đặt xuống.
- Tường A xanh rêu, B xanh xám, C đỏ trầm; ốp gỗ chân tường, sàn gỗ phòng và marble hành lang. Cánh cửa thêm inset/tay nắm dưới `Panel`, không đổi vùng `Passage` hoặc collider.
- Không tạo vách tại Z=24 trong kho tầng 2, không mở lại lối B→kho; cửa kho `(27,27)`, cửa sổ đông và hai thang giữ nguyên.

## Authoring và rebuild

`environment_art_builder.gd` đọc `resources/environment_art_layout.json`, tính bounds có đủ transform cha, tách node/surface cần dùng, chuẩn hóa trong `VisualPivot`, và chỉ thay node mang metadata `environment_art`. Mesh nhập dùng metadata `preserve_source_material`; không gắn gameplay script lên GLB.

Geometry/exhibits/service builder và `apply_materials.gd` gọi art helper trước khi lưu. Chạy lại không tăng đồ/collider. Palette không phủ đệ quy lên nguồn nhập; các override đá chỉ chỉnh mesh/material đã tách, không chỉnh GLB nguồn. Các nhịp đá lặp được gộp thành **ArrayMesh tĩnh**, giữ collision riêng. MultiMesh đã được loại khỏi art vì dummy renderer headless không giữ buffer transform khi serialize; kiểm tra mới bắt được trường hợp geometry batch biến mất sau khi tải lại.

```text
godot --headless --path . --script res://maps/isg_museum/tools/prepare_tree_lod.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_art_assets.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_display_base.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_environment_modules.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_geometry.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_exhibits.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_service.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd -- --check
godot --headless --path . --script res://maps/isg_museum/tools/apply_materials.gd
godot --headless --path . --script res://maps/isg_museum/tools/bake_navigation.gd
```

`--check` không lưu scene/manifest. So sánh cây node đã sort theo path, transform, mesh arrays, vật liệu/texture, collision, LOD, đèn, environment và metadata; bỏ qua ID resource sinh ngẫu nhiên. Không so văn bản `.tscn`. [Kiểm tra hash](readonly-check.log) xác nhận cả chín scene và manifest giữ nguyên sau lệnh này.

## Kiểm thử

Đã chạy baseline trước khi sửa: **590 checks, 0 failures**. Sau triển khai: **652 checks museum, 0 failures** trong mười lệnh riêng bên dưới. Các lỗi phát hiện trong quá trình triển khai đã được sửa: buffer MultiMesh headless, ownership của module nhập và khung T1 xuyên tường 5 mm. Không hạ/xóa test gameplay cũ.

Lệnh cho từng dòng: `godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_<tên>.gd`.

| Tên | Baseline | Sau art | Log |
|---|---:|---:|---|
| blockout | 106/0 | 106/0 | [log](after-blockout.log) |
| contract_variants | 71/0 | 71/0 | [log](after-contract_variants.log) |
| empty_frame | 48/0 | 48/0 | [log](after-empty_frame.log) |
| carry | 83/0 | 83/0 | [log](after-carry.log) |
| staff_room | 55/0 | 55/0 | [log](after-staff_room.log) |
| storage | 34/0 | 34/0 | [log](after-storage.log) |
| service | 31/0 | 31/0 | [log](after-service.log) |
| exhibits | 32/0 | 32/0 | [log](after-exhibits.log) |
| room_feedback | 30/0 | 30/0 | [log](after-room_feedback.log) |
| environment_art | — | 62/0 | [log](after-environment_art.log) |

`environment_art` kiểm tra bounds batch sau tải scene, hai lần art pass, đủ bốn lối sân bằng input thật, đi trọn vòng đài phun, collision/layer, tia qua khe lan can và bị phần đá chặn, T2 envelope, node trạng thái và phụ thuộc runtime. Với từng bệ, guard G4 thật nhìn về player: cúi bị che, đứng được thấy; ray ra mép bệ thông. `blockout` kiểm tra hai vòng tuần tra của cả chín guard, nối hai tầng qua cả hai thang, cửa mở/đóng và sàn/lan can. Các suite chuyên biệt kiểm tra G3 nghỉ/tìm/về ghế, giữ-thả E, kính vỡ/lấy món, T1/G6, mang/đặt/nhặt/giao T2, vé, K, DDMM, dây/thoát, Pause, Restart và Play Again.

| Lệnh khác | Kết quả / bằng chứng |
|---|---|
| `godot --version` | Đúng 4.7.2 stable official |
| `godot --headless --path . --editor --quit` | Import cuối exit 0; [log](final-import.log). Dùng APPDATA tạm trong Temp để không ghi editor settings bên ngoài sandbox. |
| `godot --headless --path . --script res://tools/ci/check_scripts.gd` | **335 scripts đạt**; [log](check-scripts.log) |
| Art pass mặc định, `--check`, palette, ba builder | Exit 0; xem `apply_environment_art.log`, `check-art.log`, `apply_materials.log`, `build_*.log` |
| Bake navigation | [log](bake_navigation.log); Static Colliders world=1, agent 1,8 m, radius 0,4 m, climb 0,25 m, slope 40° |
| `godot --headless --path . res://tests/test_scene.tscn` | Lần đầu có hai lỗi lưu/đọc settings HUD do `user://` không ghi được: [log](integrated.log). Chạy lại với APPDATA tạm có quyền ghi và `--fixed-fps 60`: **exit 0, All tests passed**, không sửa shared; [log cuối](integrated-writable.log). |
| `python3 tools/ci/check_layout.py` | **Chưa chạy được**: chỉ có alias WindowsApps 0 byte, không có Python interpreter khả dụng; [ghi nhận](check-layout.log). |
| `git diff --check` | Đạt; chỉ có thông báo chuẩn hóa CRLF ở một số asset metadata có sẵn |

Baseline Windows có lỗi truy cập root certificate store và ghi log/editor settings trong sandbox; staff suite có cảnh báo resource khi thoát. Root-certificate diagnostic còn xuất hiện sau art và không làm test hành vi thất bại. Không coi đây là test pass của CI Linux/WSL; chưa chạy export Windows hoặc toàn bộ shell pipeline CI.

## Ảnh và hiệu năng

Tất cả PNG dưới đây được lấy trực tiếp từ viewport **Godot GL Compatibility**, không dùng ảnh AI làm bằng chứng. Hai ảnh mặt bằng là cutaway phục vụ kiểm tra: ẩn tầng/mái và rút tường ngoài chỉ trong công cụ chụp, không lưu thay đổi này vào scene chơi. Player ở trạng thái crouch cho ảnh cover; kính S2 được phá bằng hàm tương tác sản phẩm; lịch và bản đồ mở qua tương tác thật.

| Ảnh | Nội dung |
|---|---|
| [01-courtyard.png](01-courtyard.png) | Tầm mắt sân, cột/vòm hai tầng và mái kính |
| [02-cover.png](02-cover.png) | Góc nhìn thấp sau bệ, player đã crouch |
| [03-floor-1.png](03-floor-1.png) | Tổng thể tầng 1 và sân trước |
| [04-floor-2.png](04-floor-2.png) | Tổng thể tầng 2, kho liền phòng và khoảng thông tầng |
| [05-staff.png](05-staff.png) | Phòng nhân viên, bàn A và G3 ngồi |
| [06-broken-glass.png](06-broken-glass.png) | S2 sau tương tác phá kính: còn artifact, đế và mảnh kính |
| [07-map-ui.png](07-map-ui.png) | Bản đồ dữ liệu thật tại 1280×720 |
| [08-calendar-ui.png](08-calendar-ui.png) | Lịch cập nhật tại 1280×720 |

[BENCHMARK.md](BENCHMARK.md) so sánh trước/sau trên cùng GPU, view và renderer; JSON gốc lưu FPS trung bình, frame interval trung bình/p95, draw calls, primitives, viewport và bộ nhớ render. Mỗi view làm nóng 90 frame rồi đo 180 frame. AI bị đóng băng để tách chi phí hình ảnh; đây không phải benchmark gameplay dài hoặc GPU-only timing. VSync khoảng 144 Hz có thể che phần headroom còn lại.

Mesh runtime: tree near **18.589**, far **577**; shrub **2.287** thay 27.327; cây chậu **10.636** thay 176.226; Terpsichore **28.605** thay 114.430 tam giác. Chỉ hai cây cao; dùng LOD thấp ở xa. Không suy ra tối ưu từ texture 2K. Manifest ghi source/derived và số tam giác thực tế; vật liệu đá bỏ normal map lan can sai, tượng bỏ unlit.

## Giới hạn nghiệm thu

- Cây near thấp hơn mục tiêu ban đầu 30–60k; canopy và LOD xa còn thưa. Ánh sáng/độ dày cây của bản GL Compatibility này cần Manager duyệt bằng ảnh thực tế; không tuyên bố đạt độ hoàn thiện ảnh concept AI.
- Có số liệu render trên máy RTX 3050, nhưng chưa đo GPU frame time, RAM toàn tiến trình, heatmap overdraw hoặc máy cấu hình thấp. Không lấy FPS VSync-capped để khẳng định không có regression trên mọi máy.
- Chưa chạy layout Python và CI Linux/WSL/export như ghi ở trên. Không thay đổi rig/Mixamo/hoạt ảnh tay/leo dây.

## Tệp và giấy phép

[CHANGED_FILES.txt](CHANGED_FILES.txt) liệt kê file của đợt triển khai; các metadata/license và GLB người dùng đã thêm trước baseline không bị ghi đè. Source hash ba GLB vẫn khớp `source.json`:

- Gothic: `417dc69a55a53ee25560118c2ed380035c10d4064a5949f53b570c24721b9eeb`.
- Balustrade: `208215278d9f15e4d572854c947b1133a4cdd85a0929e1484df2eba8f2278a98`.
- Terpsichore: `dd1669cc8564a79682d7bc199581d7cda700469168ab06e7bfea48aaaf10000a`.

[ATTRIBUTION.md](ATTRIBUTION.md) giữ tác giả/URL/giấy phép và mô tả chỉnh sửa. Terpsichore derived tiếp tục **CC BY-SA 4.0**, có bản license kèm trong `assets/models/derived/`. Các nguồn Gothic, lan can, bồn phun và tủ kính giữ CC BY 4.0 tương ứng. Không có phụ thuộc Goddess Isis, `.local/` hoặc thư mục ảnh concept AI trong scene runtime.
