# Thư viện asset bảo tàng

Thư viện ngày 10/11/2026 đã lưu **24 model, 1 ảnh tác phẩm, 9 clip hoạt ảnh và 1 nhân vật tham chiếu Mixamo**. Có thêm **4 bản ghi model sân vườn chờ tải qua Sketchfab**. Trạng thái từng mục nằm trong `catalog.json` và `source.json` của thư mục tương ứng.

Ba model sân vườn mới gồm **Shrub 04, Fern 02 và Tree Small 02**, có texture 2K và dữ liệu nguồn. Xem [hướng dẫn sân vườn](COURTYARD_GUIDE.md) để mở đúng tệp và tải bổ sung bốn mẫu còn thiếu. Tree Small 02 hiện là nguồn LOD0 cần giảm lưới trước khi dùng trong game.

Ba model mới đã được Godot 4.7.2 đọc thành công; 21 tệp model và phụ thuộc đã khớp kích thước, MD5 từ nguồn và SHA-256 lưu trong metadata. Đợt sân vườn thêm khoảng 117,4 MiB vào thư viện.

```text
assets/
├── materials/                  8 bộ vật liệu ambientCG đã thiết lập trước
├── models/
│   ├── frames/                 Khung tranh treo và ảnh để bàn
│   ├── exhibits/               Đồng hồ, tượng và tủ kính
│   ├── furniture/              Bàn, ghế, tủ ngăn kéo và kệ gỗ
│   ├── electronics/            Máy cassette
│   ├── lighting/               Đèn bàn, đèn kho và đèn trần
│   ├── storage/                Kệ thép, tủ gỗ và cuộn dây
│   ├── security/               Hộp điều khiển
│   ├── vegetation/             Cây trong chậu, bụi xanh, dương xỉ và cây tán cao
│   ├── architecture/           Đài phun nước; bản ghi cột–vòm và lan can chờ tải
│   └── characters/             Model bảo vệ cần gắn xương
├── images/artworks/            Ảnh tranh gốc của The Met
├── animations/mixamo/          9 clip FBX và nhân vật tham chiếu có bộ xương
└── catalog.json                Danh mục và trạng thái tải
```

Mỗi model được tải xong có tệp `.gltf` hoặc `.glb`, `source.json` và `LICENSE.txt`. Model Poly Haven đi cùng tệp `.bin` và thư mục `textures/` chứa ảnh 2K. Các model giữ hình học và kích thước gốc từ nguồn.

Đã kiểm tra 21 model bằng `GLTFDocument` của Godot 4.7.2 trong thư mục kiểm tra riêng. Các tệp phụ thuộc đều có sẵn ở máy, 97 tệp Poly Haven khớp mã MD5 từ nguồn và ảnh Turner đọc được ở kích thước 1959 × 1461 px. Godot chuyển vật liệu specular/glossiness của đài phun nước sang roughness/metallic khi đọc, nên màu và độ bóng cần đối chiếu thêm khi tích hợp.

Godot 4.7.2 cũng đã đọc thành công 10 tệp FBX Mixamo. Các clip có cùng hệ 65 xương với nhân vật tham chiếu và khai báo 30 FPS. Bộ đã nhận được trình bày trong [hướng dẫn hoạt ảnh](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/README.md).

| Asset | Tệp chính để xem | Vị trí dự kiến |
|---|---|---|
| [Fancy Picture Frame 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/fancy_picture_frame_01/) | [fancy_picture_frame_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/fancy_picture_frame_01/fancy_picture_frame_01_2k.gltf) | Khung T1/T2/T3 |
| [Hanging Picture Frame 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/hanging_picture_frame_01/) | [hanging_picture_frame_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/hanging_picture_frame_01/hanging_picture_frame_01_2k.gltf) | Tranh nhỏ A2/C2, bản đồ và áp phích |
| [Standing Picture Frame 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/standing_picture_frame_01/) | [standing_picture_frame_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/frames/standing_picture_frame_01/standing_picture_frame_01_2k.gltf) | Ảnh để bàn nhân viên |
| [Pocket Watch](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/pocket_watch/) | [pocket_watch_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/pocket_watch/pocket_watch_2k.gltf) | Hiện vật H2 |
| [Modern Abstract Bust](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/modern_abstract_bust/) | [modern-abstract-bust.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/modern_abstract_bust/modern-abstract-bust.glb) | Hiện vật S2 |
| [Small Museum Display Case](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/small_museum_display_case/) | [small_museum_display_case.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/exhibits/small_museum_display_case/small_museum_display_case.glb) | Tủ kính, cần tách phần kính khi triển khai |
| [Metal Office Desk](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/metal_office_desk/) | [metal_office_desk_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/metal_office_desk/metal_office_desk_2k.gltf) | Bàn A trong phòng nhân viên |
| [Dining Chair 02](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/dining_chair_02/) | [dining_chair_02_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/dining_chair_02/dining_chair_02_2k.gltf) | Ghế G3 và nhân viên tiếp đón |
| [Vintage Wooden Drawer 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/vintage_wooden_drawer_01/) | [vintage_wooden_drawer_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/vintage_wooden_drawer_01/vintage_wooden_drawer_01_2k.gltf) | Tủ ngăn kéo phòng nhân viên |
| [Wooden Display Shelves 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/wooden_display_shelves_01/) | [wooden_display_shelves_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/furniture/wooden_display_shelves_01/wooden_display_shelves_01_2k.gltf) | Kệ trang trí phòng Lịch sử |
| [Desk Lamp Arm 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/desk_lamp_arm_01/) | [desk_lamp_arm_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/desk_lamp_arm_01/desk_lamp_arm_01_2k.gltf) | Đèn trên bàn A |
| [Industrial Pipe Lamp](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/industrial_pipe_lamp/) | [industrial_pipe_lamp_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/industrial_pipe_lamp/industrial_pipe_lamp_2k.gltf) | Đèn kho |
| [Modern Ceiling Lamp 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/modern_ceiling_lamp_01/) | [modern_ceiling_lamp_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/lighting/modern_ceiling_lamp_01/modern_ceiling_lamp_01_2k.gltf) | Phòng dịch vụ và sảnh phụ |
| [Cassette Player](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/electronics/cassette_player/) | [cassette_player_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/electronics/cassette_player/cassette_player_2k.gltf) | Đồ trang trí bàn trực |
| [Steel Frame Shelves 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/steel_frame_shelves_01/) | [steel_frame_shelves_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/steel_frame_shelves_01/steel_frame_shelves_01_2k.gltf) | Kệ kho phụ |
| [Painted Wooden Cabinet](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/painted_wooden_cabinet/) | [painted_wooden_cabinet_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/painted_wooden_cabinet/painted_wooden_cabinet_2k.gltf) | Tủ kho phục chế |
| [Rope Coil](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/rope_coil/) | [rope-coil.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/storage/rope_coil/rope-coil.glb) | Dây thoát hiểm |
| [Power Box 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/security/power_box_01/) | [power_box_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/security/power_box_01/power_box_01_2k.gltf) | Vỏ hộp điều khiển phòng C |
| [Potted Plant 01](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/vegetation/potted_plant_01/) | [potted_plant_01_2k.gltf](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/vegetation/potted_plant_01/potted_plant_01_2k.gltf) | Phòng dịch vụ và sân trong |
| [Low Poly Security Guard](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/characters/low_poly_security_guard/) | [low_poly_security_guard.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/characters/low_poly_security_guard/low_poly_security_guard.glb) | Bảo vệ, cần gắn xương và hoạt ảnh |
| [Fountain](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/architecture/italian_fountain/) | [fountain.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/architecture/italian_fountain/fountain.glb) | Đài phun nước giữa sân trong |
| [Tranh Venice của Turner](D:/IT/SE_GAME_3D/maps/isg_museum/assets/images/artworks/turner_venice/) | [turner_venice_original.jpg](D:/IT/SE_GAME_3D/maps/isg_museum/assets/images/artworks/turner_venice/turner_venice_original.jpg) | Mặt tranh phong cảnh, ảnh gốc 1959 × 1461 px |

Các hoạt ảnh nằm trong [animations/mixamo](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/README.md). Thư mục `reference/` giữ nhân vật T-pose, `clips/` giữ 9 clip gốc. Hai động tác đi và chạy còn có dịch chuyển gốc, cần xử lý In Place khi ghép với điều khiển tuần tra. Bảo vệ Sketchfab cần gắn xương trước bước ghép này.

Để xem một model trong Godot sau này, mở tệp `.gltf` hoặc `.glb` từ FileSystem. Giữ tệp `.gltf`, `.bin` và thư mục `textures/` cùng vị trí để Godot tìm đủ hình học và vật liệu. Với GLB, hình học và ảnh đã nằm trong một tệp.

Thư viện này đang ở bước chuẩn bị asset. Khi triển khai vào map, cần căn kích thước, đặt vị trí và giữ các vùng tương tác của cơ chế đang dùng. Khung T1 cần tách mặt tranh để giữ khung trống, T2 cần mặt sau và cách cầm/đặt, tủ kính cần phần kính tách riêng. Bàn A cần mặt trước kín, ghế cần khớp tư thế G3, nhân vật cần kiểm tra bộ xương và chuyển hoạt ảnh. Model đèn sẽ cần nguồn sáng trong scene.

Các model Poly Haven, Innerscene và Grab3D đã tải dùng CC0. Tranh Turner được The Met xác nhận Public Domain. Ba model Sketchfab đã tải dùng CC BY 4.0 và cần ghi công tác giả khi đưa vào game. Bốn mẫu Sketchfab sân vườn đang chờ tải có giấy phép riêng trong từng thư mục, gồm CC0, CC BY và CC BY-SA. Thông tin tác giả, URL nguồn và mã kiểm tra SHA-256 của tệp đã tải nằm trong `source.json` của từng asset.

Nhân vật tham chiếu và hoạt ảnh Mixamo dùng điều kiện Adobe Mixamo, được ghi trong `animations/mixamo/LICENSE.txt`. [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)

Tám bộ vật liệu ambientCG có hướng dẫn riêng tại [materials/README.md](D:/IT/SE_GAME_3D/maps/isg_museum/assets/materials/README.md).
