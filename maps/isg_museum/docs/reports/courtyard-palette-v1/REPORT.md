# Courtyard palette v1 — đợt A

> Hồ sơ lịch sử đã tổ chức lại; kết luận, số đo và kết quả gốc được giữ nguyên. [Mục lục](../../README.md) · [images](images/) · [videos](videos/) · [logs](logs/) · [data](data/) · [revisions](revisions/) . Raw log/JSON có thể ghi đường dẫn cũ; tra manifest migration từ mục lục.


**Đã dựng góc thử. Chưa áp bảng màu mới vào scene sản phẩm.** Preview sử dụng nguyên `museum_editing.tscn` làm scene instance, cùng geometry, module cột–vòm, lan can, cây, tượng, collision và navmesh hiện có. Không sao chép thành một map độc lập. Góc duyệt nhìn chéo từ hành lang đông nam về sân; có thêm góc mắt người chơi, cận tường/cột, sàn/viền và lan can tầng trên.

## Mở và kiểm tra

Mở [courtyard_palette_preview.tscn](../../../scenes/previews/courtyard_palette_preview.tscn), nhấn **F6**.

- WASD/chuột: đi lại và nhìn như map hiện tại.
- **F7**: đổi qua lại giữa vật liệu sản phẩm hiện tại và phương án Venice ấm.
- **F8**: lần lượt tới hành lang đông nam, hành lang tây tầng 1, hành lang tây tầng 2.
- Esc: pause theo hệ thống hiện có.

Vật liệu đề xuất được áp vào instance khi chạy F6. Viewport editor trước khi chạy vẫn tham chiếu scene nguồn. Chế độ chỉnh map giữ nguyên: không có guard, hai NPC vẫn tồn tại. F8 chỉ là di chuyển QA trong preview, giúp xem tầng trên mà không cần làm nhiệm vụ lấy vé.

## Bộ vật liệu thử

Các preset nằm riêng tại `assets/materials/presets/gardner_palette_v1/`, albedo dẫn xuất tại `assets/materials/textures/derived/gardner_palette_v1/`. Không sửa preset/texture nguồn. Các giá trị màu là thông số thiết kế ban đầu, không phải màu đo từ bảo tàng thật.

| Vai trò | Nguồn | Hướng xử lý | Một lần lặp |
|---|---|---|---:|
| courtyard_plaster | Plaster002 | Đất hồng pha nâu, loang rộng seed cố định, normal rất nhẹ | 8 m |
| corridor_floor | PavingStones001 | Xám nâu, giữ mạch và biến thiên viên lát | 2,4 m |
| corridor_border | PavingStones001 | Nâu xám tối, giảm hoa văn/normal | 2,4 m |
| architectural_stone | Marble012 | Ngà be, giảm vân, chi tiết khoáng nhẹ | 1,5 m |
| balustrade_stone | Concrete025 dẫn xuất | Be xám, mịn hơn tường vườn | 1,4 m |
| balustrade_cap | Concrete025 dẫn xuất | Trầm hơn thân lan can | 1,4 m |
| garden_wall_stone | Concrete025 | Nâu xám, nhám hơn kiến trúc đá | 1,6 m |
| sculpture_stone | Marble012 | Đá sáng cũ, giữ khả năng đọc hình tượng/đài phun | 1,4 m |
| walnut_wood | Wood051 | Óc chó đậm cho cánh cửa trong phạm vi | 2 m |
| dark_metal | Metal032 | Đồng/xám sẫm, độ bóng tiết chế | 1 m |

Albedo 512×512 được sinh offline từ nguồn bằng seed ổn định, normal/roughness tiếp tục dùng texture nguồn đã có. Các preset đều nhận sáng. Plaster không dùng vân marble; lan can/tường vườn có nguồn và mức nhám khác đá cột. UV world triplanar giữ tỷ lệ theo mét và tránh reset cùng mảng loang trên từng ô tường. [Cấu hình](../../../resources/courtyard_palette.json) ghi toàn bộ đường dẫn, tint, contrast, normal strength, roughness, tile size và seed. [ASSETS.json](data/ASSETS.json) ghi hash tài nguyên. Giữ giấy phép vật liệu ambientCG hiện có tại `assets/materials/LICENSE.txt` và `sources.json`.

Registry chỉ chọn các bề mặt kiến trúc cụ thể. Những mesh đá được đổi là adaptation đá nhận sáng đã có, không phủ lại material nguồn GLB. Lá, kính, nước, tác phẩm, character/NPC và các finish trong phòng ngoài phạm vi không bị gán màu hàng loạt. Metadata giữ material nguồn vẫn còn.

## Hình học và cách ly

Đá cột/vòm dùng mesh/module/batch đã sửa hiện tại. Chỉ thay override của instance preview, không sinh lại module sản phẩm. Thân/cap lan can được chọn theo phần render thực; batch spindle hiện có giữ một vai trò thân lan can. Lỗi batch key chưa xét material trong builder sản phẩm chưa được sửa ở đợt A; sẽ xử lý trước khi tích hợp nhiều vai trò vào batching ở đợt B.

Tường hồng chỉ nằm ở các mặt quay ra hành lang: Z6 hướng +Z, Z24 hướng -Z, X9 hướng +X, X27 hướng -X, cắt theo bounds thực của từng đoạn tường/lintel và cả hai tầng. Mặt phòng A/B/C và mặt ngoài nhà giữ nguyên.

Sàn và tường được tách surface/triangle trên đúng mặt có sẵn trong bộ nhớ preview. Viền 0,22 m chiếm vùng riêng trong cùng mặt sàn, không chồng thêm plane đồng phẳng. Silhouette, vị trí, bounds, tổng diện tích mặt và toàn bộ collision giữ nguyên; số triangle render tăng do chia vùng vật liệu. Không bổ sung khối kiến trúc, bậc, vật che hoặc collider. Lớp gỗ chân tường và các offset sửa trước đây giữ nguyên. Sàn phòng, đường sân/vòng đài phun và khoảng thông tầng không đổi.

Environment/Sky của preview được duplicate riêng với cùng giá trị. So sánh đầu tiên **chỉ thay vật liệu**, dùng bối cảnh ngày giả lập của map hiện tại. Không chỉnh nắng, ambient, sky, exposure hoặc shadow. [Camera metadata](data/camera-metadata.json) ghi pose, FOV 75°, 1280×720, renderer, Environment/sky/attributes và từng nguồn đèn. Các thông số trước/sau được so tự động.

## Ảnh và video trực tiếp từ Godot

| Góc | Trước | Sau |
|---|---|---|
| Góc chéo sân–hành lang | [before-overview](images/before-overview.png) | [after-overview](images/after-overview.png) |
| Mắt người chơi | — | [ảnh](images/after-player-eye.png) |
| Tường/cột gần | — | [ảnh](images/after-wall-column-closeup.png) |
| Sàn/viền | — | [ảnh](images/after-floor-border.png) |
| Lan can tầng 2 | — | [ảnh](images/after-upper-balustrade.png) |

[Video Player đi lại](videos/preview-walk.avi): từ hành lang vào sân, men theo đường sân và cột/tường vườn, sau đó nhìn xuống từ tầng 2. Các đoạn đi dùng input và collision Player thật; chuyển giữa khu quay/tầng dùng anchor QA. [Log đạt đích](data/walk.json), [log quay](logs/capture-final.log). Camera dùng chính Player.camera. Ảnh/video không dùng AI; không dùng tốc độ quay phim để kết luận FPS gameplay.

## Kiểm tra

[VALIDATION.json](VALIDATION.json) ghi lệnh, exit code và hash. Các lệnh được chạy:

```text
godot --headless --path . --script res://maps/isg_museum/tools/prepare_courtyard_palette.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/isg_museum/tools/build_courtyard_palette_preview.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_courtyard_palette.gd -- --check
godot --headless --path . --script res://tools/ci/check_scripts.gd
godot --headless --path . --script res://maps/isg_museum/tools/verify_courtyard_palette.gd
python -B tools/ci/check_layout.py
```

Godot là 4.7.2 stable trong `.local/godot/`. Python dùng interpreter uv hiện có. APPDATA của tiến trình kiểm tra nằm riêng tại `.local/courtyard-palette-userdata`.

Kết quả: **39 checks, 0 failures; 362 scripts hợp lệ; layout 854 runtime references; mọi lệnh cuối exit 0**. Đã kiểm tra: đủ 10 vai trò/texture và thực sự được gán; đúng mặt tường; vùng viền độc lập; bounds/diện tích mặt; khôi phục nguyên resource gốc khi F7; collision bất biến; vùng không liên quan giữ material/mesh; input Player qua cửa sân và đứng trên sàn tầng 2. Prepare/apply lặp không tăng binding/node; texture/preset sinh lại cho hash giống nhau. Suite được đăng ký vào runner chung theo convention repository, nhưng chưa chạy full runner/regression sản phẩm ở đợt A.

**199 tệp sản phẩm đã kiểm hash trước/sau và không đổi**, gồm scene, module, preset hiện có, script/builder, navigation và tài nguyên nhân vật/animation được bảo vệ. Chỉ tạo các file preview/preset/texture/config/tool/test/tài liệu mới và thêm đăng ký test. Không gọi pipeline ghi lại scene sản phẩm, không bake navigation. [product-before.json](data/product-before.json), [product-after.json](data/product-after.json), [rebuild-check.json](data/rebuild-check.json).

## Chi phí tại cùng góc

[BENCHMARK.md](data/BENCHMARK.md) và [raw JSON](data/benchmark.json): cùng camera/đèn/renderer, map editing đóng băng, VSync/frame cap tắt chỉ trong tool rồi khôi phục, 120 display frame warmup và 8 giây/mẫu. CPU Intel Core 5 210H, GPU RTX 3050 6GB Laptop, 1280×720.

- Draw calls p50: **1.113 → 1.215** (+102, khoảng 9,2%).
- Process-frame interval p50: **2,724 → 3,189 ms**.
- p95: **4,582 → 7,581 ms**; p99: **6,512 → 12,129 ms**.
- Primitives: **1.645.615 → 1.646.967**.

Đây là frame interval của process, không phải GPU timing. Mẫu ngắn và AI đóng băng; không suy ra FPS gameplay/dư địa toàn map. Preview giữ cả hai bảng màu để chuyển F7 nên số memory bao gồm cả hai. Chi phí tách surface/vai trò là có thật; cần giữ material-aware batching và đo dài hơn trong đợt B.

Log GL khi thoát capture/benchmark có diagnostic hai texture chưa giải phóng, mỗi texture 349.524 byte, process vẫn exit 0; chưa xác định nguồn cache/teardown. Giữ nguyên log, không diễn giải thành không có lỗi hoặc đã tối ưu xong. Không có ghi đè tệp sản phẩm. Diagnostic certificate store Windows đã xuất hiện ở các lượt trước. Các lỗi type inference của công cụ thử ban đầu đã sửa và chạy lại; chỉ log cuối trong VALIDATION là kết quả nghiệm thu kỹ thuật.

## Cần người dùng góp ý trước đợt B

1. Độ đậm của hồng đất trong bóng: giữ trầm như ảnh hay sáng/phấn hơn.
2. Sắc xám nâu, tỷ lệ lát và viền 0,22 m: độ tối/độ rộng đã hợp lý chưa.
3. Lan can be xám và cap tối: mức tách khỏi cột/nền đã đủ rõ chưa.
4. Tường vườn: giữ nhám/trầm để tôn cây hay làm sáng/mịn hơn.
5. Tông ngà của cột/tượng ở vùng nắng và vùng bóng.

Trần gỗ cam và cấu trúc mái là hiện trạng được giữ để khóa điều kiện; chưa phối lại hay chỉnh đèn trong ảnh này. Sau khi bảng vật liệu được duyệt mới xem ánh sáng bằng lượt trước/sau riêng. Khác biệt kiến trúc và tích hợp pipeline sản phẩm thuộc bước sau.

[CHANGED_FILES.txt](data/CHANGED_FILES.txt) liệt kê tệp bàn giao. Đợt B chưa triển khai.
