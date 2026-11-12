# ISG Museum — environment art v1.1

Ngày triển khai: **12/11/2026**. Baseline **35fe3f8** (art v1), Godot **4.7.2.stable.official.ed1daf0bf**, GL Compatibility. Báo cáo, log và ảnh v1 được giữ nguyên; phần Python “chưa chạy” ở v1 là lịch sử, không bị sửa lại.

## Thay đổi

- Vegetation dùng scale đồng đều theo chiều cao và giới hạn tán, thay cho kéo XYZ riêng. Hai cây giữ vị trí cũ; các LOD có cùng source bounds và anchor ở tâm chân. Ngân sách đọc từ JSON: near **48.000**, mid **12.000**, far **3.200**; thực tế **42.820 / 11.384 / 3.189** tam giác. Khoảng chuyển **18/26 m**.
- LOD lá nguồn nhảy từ 177.711 xuống 16.075 tam giác, làm mất tán. Bản v1.1 bake 39 cụm không gian × ba góc trực giao thành atlas CC0, đặt trên các card cong; thân/cành có ngân sách và native LOD riêng. Mọi mức giữ đủ cụm lá, giảm độ cong và mesh gỗ theo khoảng cách. Không đưa cây nguồn 2.062.487 tam giác vào runtime. [Manifest](../../assets/models/derived/tree_lod_manifest.json), [thống kê LOD nguồn](source-lods.log).
- Bụi có lớp lá Shrub 04 gấp nhẹ, phủ mặt trên và hai mặt bên, lõi lùi vào phía trong. Giữ 64 shrub đã giảm lưới; không tăng cành trên toàn map. Viền lá có sai lệch nhỏ và tổng cao vẫn 1,2 m. Collider world và bốn cửa 2 m giữ nguyên.
- Thêm `courtyard_stone_cream.tres` và `courtyard_statue_stone.tres`: albedo Marble012 giảm tương phản còn 12%, pha kem, giữ normal/roughness nhẹ, nhận sáng. Cột được sinh lại từ công cụ tạo module; dùng chung preset cho vòm, bệ, lan can và bồn. Palette và rebuild giữ vật liệu.
- JSON điều khiển ambient, sun, hướng nắng, màu trời, bốn đèn sân và chính sách shadow. Cấu hình cuối: ambient **0,32**, sun **0,85**, đèn sân **0,75 / 5,5 m**; directional shadow bật, local shadow tắt. Đèn sân có mô hình đèn nhìn thấy được. Không sửa renderer hoặc nhận thức AI.

## Bằng chứng hình ảnh

Ảnh lấy trực tiếp từ viewport Godot, không dùng ảnh AI. `before-source/` là bản sao scene của baseline, chỉ đổi đường dẫn scene con sang bản sao để giữ visual cột/mesh v1. Không tải cảnh baseline từ working tree đã sửa.

| Góc cố định | V1 | V1.1 |
|---|---|---|
| Sân, kiến trúc và mái | [trước](before-01-courtyard.png) | [sau](after-01-courtyard.png) |
| Ngang mắt: đài phun và cây | [trước](before-02-fountain-trees.png) | [sau](after-02-fountain-trees.png) |
| Tán nhìn từ mép hành lang tầng 2, camera QA | [trước](before-03-upper-canopy.png) | [sau](after-03-upper-canopy.png) |
| Mặt trên và bên hàng bụi | [trước](before-04-hedge.png) | [sau](after-04-hedge.png) |
| Player.camera thật, đứng | [trước](before-05-player-standing.png) | [sau](after-05-player-standing.png) |
| Player.camera thật, cúi | [trước](before-06-player-crouching.png) | [sau](after-06-player-crouching.png) |
| QA ngoài: player–bệ–guard | [trước](before-07-cover-qa.png) | [sau](after-07-cover-qa.png) |
| Mái, kính bật | [trước](before-08-roof-glass-on.png) | [sau](after-08-roof-glass-on.png) |
| Cùng góc, kính tắt | [trước](before-09-roof-glass-off.png) | [sau](after-09-roof-glass-off.png) |

Player chưa có avatar góc thứ ba. Ảnh QA ghi rõ capsule xanh mô phỏng đúng capsule cúi thật; không thay rig/presentation nhân vật. Hai ảnh đứng/cúi dùng chính `Player/Head/Camera3D`, cùng tọa độ chân; metadata camera nằm trong `before-capture.json` và `after-capture.json`.

Vật chuẩn trắng/đỏ/xanh nằm phía trên mái trong cặp kính bật/tắt. Cả ba vẫn nhìn thấy qua kính; màu trời là phần lớn nền xanh. Không thay kính từ suy đoán màu ảnh.

LOD được chụp riêng dưới **cùng rig ánh sáng v1.1**, để tách khác biệt mesh/tỷ lệ khỏi ánh sáng map:

- Cùng camera 12 m: [v1 near](before-lod-near-same-camera.png), [v1 far](before-lod-far-same-camera.png); [v1.1 near](after-lod-near-same-camera.png), [mid](after-lod-mid-same-camera.png), [far](after-lod-far-same-camera.png).
- Native LOD ở khoảng cách tới gốc [12 m](after-lod-auto-12m.png), [18 m](after-lod-auto-18m.png), [22 m](after-lod-auto-22m.png), [30 m](after-lod-auto-30m.png). Godot đánh giá khoảng nhìn theo mesh; khoảng cách ghi trên ảnh là camera tới gốc cây.
- [Video chuyển LOD 10 giây, 600 frame](tree-lod-transition.avi): camera đi 12 → 30 → 12 m, đổi góc nhẹ, dùng native visibility ranges. Đây là ghi hình fixed-fps, không phải benchmark thời gian thực.

So sánh cột [chưa batch](after-10-column-unbatched.png) và [batch rồi save/reload](after-11-column-batched-reloaded.png) dùng cùng camera/material/light. [Sai khác pixel](column-batch-comparison.json) được ghi tự động. Không sửa normal/tangent vì phép so sánh không xác nhận lỗi batching.

Ảnh tổng thể hai tầng, nhân viên, kính S2 sau tương tác, bản đồ và lịch ở [báo cáo v1](../environment-art-v1/REPORT.md) vẫn là bằng chứng của các khu không đổi trong đợt này.

## Authoring và kiểm thử

`environment_art_layout.json` là nguồn cấu hình. `prepare_tree_lod.gd` đọc ngân sách/range, `prepare_art_assets.gd` đọc ngân sách prop; manifest ghi phương pháp, yêu cầu và số thực tế. Công cụ mới chỉ chạy offline.

Quy trình dựng lại:

```text
godot --headless --path . --script res://maps/isg_museum/tools/prepare_courtyard_materials.gd
godot --path . --rendering-method gl_compatibility --script res://maps/isg_museum/tools/bake_tree_leaf_clusters.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/isg_museum/tools/prepare_tree_lod.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_art_assets.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_environment_modules.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_geometry.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_exhibits.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_service.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_materials.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd -- --check
```

[VALIDATION.json](VALIDATION.json) ghi lệnh, exit code, ngày kiểm tra và số check; mỗi suite có log riêng. `run-validation.ps1` chạy import, scripts, layout, art check, mười suite museum và runner chung. `--fixed-fps 60` chỉ dùng cho test/ghi hình, không dùng benchmark. APPDATA tạm nằm trong `.local/godot-art-userdata-v11` để các test settings có quyền ghi; không sửa cấu hình người dùng.

Kết quả cuối: **577 checks museum, 0 failures**; runner chung **exit 0, All tests passed**.

| Kiểm tra | Kết quả | Log |
|---|---:|---|
| environment_art | 87/0 | [log](verify-environment_art.log) |
| blockout | 106/0 | [log](verify-blockout.log) |
| contract_variants | 71/0 | [log](verify-contract_variants.log) |
| empty_frame | 48/0 | [log](verify-empty_frame.log) |
| carry | 83/0 | [log](verify-carry.log) |
| staff_room | 55/0 | [log](verify-staff_room.log) |
| storage | 34/0 | [log](verify-storage.log) |
| service | 31/0 | [log](verify-service.log) |
| exhibits | 32/0 | [log](verify-exhibits.log) |
| room_feedback | 30/0 | [log](verify-room_feedback.log) |
| Import, scripts | exit 0; 339 scripts | [import](final-import.log), [scripts](final-check-scripts.log) |
| Layout Python | exit 0; 791 runtime references | [log](check-layout.log) |
| Art `--check` | exit 0; scene/manifest hash giữ nguyên | [log](check-art.log), [hash](readonly-check.json) |
| Runner chung | exit 0; All tests passed | [log](integrated.log) |

Chín suite gameplay cũ vẫn là **490 checks**, cộng 87 kiểm tra art. Đính chính ngày 12/11/2026: tổng các header log v1 là **552** (490 + 62), trong khi REPORT v1 ghi 652; số tổng lịch sử bị cộng dư 100. Báo cáo v1 giữ nguyên theo yêu cầu; v1.1 dùng tổng tự tính từ log trong VALIDATION. Art tăng 62 → 87 checks, các suite cũ giữ nguyên.

Root certificate store diagnostic của Windows và cảnh báo resource lúc thoát staff suite còn như baseline; không làm thất bại test hành vi. Chưa chạy CI shell trên Linux/WSL hoặc export.

Python dùng interpreter đã được Manager xác nhận, không cài mới. Lệnh kiểm tra và kết quả mới có ngày trong [check-layout.log](check-layout.log) và VALIDATION; báo cáo v1 giữ nguyên.

Lượt layout trước khi chỉnh art trong phiên này đã đạt 779 references; lượt cuối tăng lên 791 do thêm resource runtime. Thời điểm chạy và executable cụ thể nằm trong VALIDATION.

Không bake navmesh: collision signature so với snapshot v1 phải bằng nhau. SHA256 navmesh gốc: `0DB27200B0C97F1B8E1E784C95EBECDF3F1C0FA5DAB2BCC3DD3641BA8C0ACF4E`. Test mới giữ nguyên kiểm tra cover/ray/di chuyển, bổ sung ngân sách/anchor, lighting, preset module, palette và idempotence. Không xóa test cũ.

## Hiệu năng, giới hạn và giấy phép

[BENCHMARK.md](BENCHMARK.md) ghi kết quả render v1/v1.1 và lượt gameplay có chín guard; CSV giữ mẫu gốc. Thời gian giữa process frame và GPU render timing là hai số riêng. Không suy ra dư địa hiệu năng từ FPS bị giới hạn hoặc từ số tam giác của riêng cây.

Lượt native cuối lấy mẫu **240 giây / 61.365 frame**, cả chín guard bật physics, có **25.595 frame chase** và **7.096 frame mang T2**; đã giao T2 và đi đủ hai thang/sân. Frame interval p50/p95/p99 **3,562 / 6,942 / 9,075 ms**, GPU p95 **2,041 ms**. Góc sân render v1 → v1.1: **364 → 340 FPS**, draw **1.197 → 1.400**, primitives **1.480.677 → 2.070.593**. Giữ chi phí chất lượng này trong báo cáo.

Phép thử chỉ trả hướng nắng v1 khôi phục chính xác counter staff **599 / 478.858**, thay cho **952 / 1.014.240** của hướng mới. Đây là chi phí shadow theo hướng nắng, đã tách khỏi cây và Omni bằng các lượt diagnostic riêng. Không đổi hướng nắng cuối sau khi đo/chụp; không gọi tăng chất lượng là tối ưu hiệu năng.

Leaf cluster cards giữ tán tốt hơn LOD native nhưng vẫn là xấp xỉ đa góc, có thể thấy mặt phẳng khi nhìn rất gần; texture alpha vẫn gây overdraw. Chưa có heatmap overdraw, đo máy yếu, CI Linux/WSL hoặc export Windows. Benchmark gameplay dùng fixture bỏ kết thúc khi bị bắt để đủ thời lượng; AI, sight/hearing, chase và collision nhân vật vẫn chạy. Không phải một lượt chơi hoàn thành hợp đồng tự nhiên.

Source GLB/glTF không đổi. Tree Small 02 và Shrub 04 theo CC0; atlas và UV lá dẫn xuất từ đúng nguồn đó. Marble012 (ambientCG, CC0) chỉ tạo albedo dẫn xuất; normal/roughness nguồn giữ nguyên. Terpsichore giữ tác giả **Glenn Gunhouse**, **CC BY-SA 4.0**, file license trong derived; các credit v1 không đổi. [Giấy phép và ghi công nguồn](../environment-art-v1/ATTRIBUTION.md), [mô tả derived](../../assets/models/derived/README.md), [danh sách file](CHANGED_FILES.txt).
