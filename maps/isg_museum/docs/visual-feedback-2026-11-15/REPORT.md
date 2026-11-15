# ISG Museum — sửa đồ họa 15/11/2026

Baseline `c9bf5d6`, workspace sạch trước khi sửa. Godot 4.7.2 stable, GL Compatibility. Giữ bằng chứng v1/v1.1, nguồn GLB/glTF và giấy phép. Scene editing vẫn kế thừa scene chính và tắt bảo vệ; gameplay giữ chín guard.

## Kết quả năm mục

1. **Sân ngoài:** bỏ bốn body `FrontYard/Planter7..10` và đoạn sinh FrontFern. Giữ cỏ, đường vào, N0, cửa và hai đèn. Tên LampPost/EntranceLight được giữ ổn định dù số child giảm. Kiểm tra ray tại X6/11/25/30, Z34 trả về mặt cỏ Y≈0; bốn bệ tượng Courtyard vẫn giữ.
2. **Cột–vòm:** kiểm tra mesh có tính transform cha, ghi trong [source-bounds.log](source-bounds.log). Object_4 chạm Object_5 tại Y≈20,94698 của nguồn; Object_5 là đầu phân nhánh, không phải nhịp hoàn chỉnh. Giữ cột chùm nguồn chuẩn hóa 0,55×3,05×0,55 m, thêm anchor Foot/Capital vào module. Thay cách đặt Object_5 bằng ribbon vòm nhọn tham số hoàn chỉnh giữa hai capital, với spring Y3,05, rise 1,25, thickness 0,14 và depth 0,39 m. Các nhịp 2,5/2,22/2,56/2,22/2,5 m dùng cùng helper; góc dùng chung cột, cả hai tầng. Marker hai đầu sau transform được kiểm tra nối capital trong 5 mm; saved scene khớp cấu trúc dựng lại cả mesh/transform, không suy đoán lỗi normal/batching. Đã sửa ownership của mesh dẫn xuất để ribbon và joint được pack/save đầy đủ.
3. **Cây thấp:** envelope 0,36 m thay 0,62 m, shell/lá có chặn giới hạn cạnh và chiều cao từ JSON. Chia mỗi hàng quanh AABB cột đã transform, chừa 4 cm; các cụm Shrub04 cũ được thay bằng lá gấp lấy UV lá Shrub04 và lõi lùi, vừa từng đoạn nhỏ. Cây tán cao v1.1 giữ nguyên. Kiểm tra AABB mọi đoạn không giao exclusion cột và đỉnh không quá 1,2 m. Không thay collider che chắn.
4. **Cầu thang:** mỗi vế có một ArrayMesh gồm 15 bậc đá, tổng 30 bậc/thang. Mặt bậc ngang, cổ bậc đứng; các mũi bậc nối theo đường dốc. Ẩn mesh LowerRamp/UpperRamp, giữ nguyên body/shape, MidLanding, lỗ sàn, vách và lan can. Mesh bậc không có collider; palette gán marble sau lớp plaster. Traversal player/guard cả hai chiều và mang T2 lên/xuống cả A/B đều có test.
5. **Chân tường A/B/C:** `_room_wall_faces` có offset mặc định 2 mm giữ caller cũ; lớp gỗ dùng offset 20 mm, tách sơn 18 mm. Cắt mặt theo cùng bounds tường và cửa, áp dụng cả tầng dưới. Kiểm tra từng mặt gỗ tầng trên có mặt sơn tương ứng cách 15–21 mm. Giữ ốp gỗ và depth test; không đổi render priority hoặc camera clipping. Ảnh/video dọc cả ba phòng cho thấy phần gỗ ổn định tại các góc đã kiểm tra.

## Bằng chứng Godot

Ảnh của năm mục trên dùng **Player.camera thật**, 1280×720. Camera được đặt tại các điểm QA, không lưu pose vào scene. Các góc tầng trên nhìn arcade từ khoảng thông tầng là góc QA bằng camera Player; không coi đó là vị trí đứng trên sàn. `before-source/` giữ scene trước sửa để dựng lại ảnh đối chiếu. Không dùng ảnh AI. Ảnh bổ sung tủ/ghế ở cuối báo cáo dùng camera QA riêng.

| Góc | Trước | Sau |
|---|---|---|
| Cửa chính, N0 và nền | [ảnh](before-yard.png) | [ảnh](after-yard.png) |
| Hai bồn phía tây đã bỏ | [ảnh](before-yard-west.png) | [ảnh](after-yard-west.png) |
| Hai bồn phía đông đã bỏ | [ảnh](before-yard-east.png) | [ảnh](after-yard-east.png) |
| Cạnh bắc, tầng dưới | [ảnh](before-north.png) | [ảnh](after-north.png) |
| Cạnh nam, tầng dưới | [ảnh](before-south.png) | [ảnh](after-south.png) |
| Cạnh tây, tầng dưới | [ảnh](before-west.png) | [ảnh](after-west.png) |
| Cạnh đông, tầng dưới | [ảnh](before-east.png) | [ảnh](after-east.png) |
| Cạnh bắc, tầng trên | [ảnh](before-upper-north.png) | [ảnh](after-upper-north.png) |
| Cạnh nam, tầng trên | [ảnh](before-upper-south.png) | [ảnh](after-upper-south.png) |
| Cạnh tây, tầng trên | [ảnh](before-upper-west.png) | [ảnh](after-upper-west.png) |
| Cạnh đông, tầng trên | [ảnh](before-upper-east.png) | [ảnh](after-upper-east.png) |
| Đầu cột và spring | [ảnh](before-joint.png) | [ảnh](after-joint.png) |
| Góc sân | [ảnh](before-corner.png) | [ảnh](after-corner.png) |
| Lá/cột và mép cửa | [ảnh](before-hedge.png) | [ảnh](after-hedge.png) |
| Thang A vế dưới | [ảnh](before-stair-a-lower.png) | [ảnh](after-stair-a-lower.png) |
| Thang A vế trên | [ảnh](before-stair-a-upper.png) | [ảnh](after-stair-a-upper.png) |
| Thang B vế dưới | [ảnh](before-stair-b-lower.png) | [ảnh](after-stair-b-lower.png) |
| Thang B vế trên | [ảnh](before-stair-b-upper.png) | [ảnh](after-stair-b-upper.png) |
| Chân tường A | [ảnh](before-room-a.png) | [ảnh](after-room-a.png) |
| Chân tường B | [ảnh](before-room-b.png) | [ảnh](after-room-b.png) |
| Chân tường C | [ảnh](before-room-c.png) | [ảnh](after-room-c.png) |

[Video Player đi/lia camera](player-walk.avi): 1.775 frame, 60 fps, 29,58 giây. Đi dọc chân tường A/B/C, sát hàng cây từ hành lang, lên và xuống cả hai vế của cả hai thang. Dùng input và collision player thật; fixture chuyển vị trí giữa các khu độc lập. [Log tọa độ thực đạt](movie.log). Đã sửa đoạn đi sát cây ban đầu bị bệ tượng cản, quay lại video cuối trên hành lang thông. Các frame JPEG `movie-*.jpg` trích trực tiếp từ AVI để kiểm tra.

## Collision, navigation và gameplay

Chỉ xóa bốn body sân ngoài kích thước 1,4×0,8×1,4 tại `(6/11/25/30,0.4,34)`. Test collision signature so với v1 bỏ qua đúng bốn đường dẫn đó và các shape con; phần còn lại phải bằng nhau. Không bỏ kiểm tra toàn bộ collision. Vách cover 1,2 m, bệ tượng, chân cột, dốc, cửa và lan can giữ nguyên.

Bake lại Static Colliders world=1, agent height 1,8, radius 0,4, climb 0,25, slope 40°: **402 polygons**. Xem [bake log](bake_navigation.log). Bậc/lá/vòm không thêm collision hoặc navigation surface.

Lượt gameplay QA native **110 giây**, đủ chín guard đang xử lý, có chase, đi cả hai thang, mở cửa và giao T2: [JSON](after-gameplay.json), [log](gameplay.log). Đây là fixture điều khiển input/né vật tự động, cấp V/K và vô hiệu hóa kết thúc do bắt trong instance QA để đi hết tuyến; vision/hearing, chase, body collision và nav của guard vẫn chạy. Scene sản phẩm không thay luật. Các suite tương tác riêng kiểm tra quyền lấy đồ bình thường. Số FPS của lượt QA chạy cùng kiểm thử khác không được dùng làm benchmark hiệu năng.

## Pipeline và kiểm thử

Sinh lại module → geometry → palette/art → navigation. Chạy art pass hai lần; test so node, transform, resource, collider và saved scene; `--check` giữ nguyên hash scene/manifest: [readonly-check.json](readonly-check.json). Giá trị cấu hình nằm trong `environment_art_layout.json` và được generator đọc.

Lệnh, kết quả thực tế và số checks trong [VALIDATION.json](VALIDATION.json). Các suite bắt buộc lưu `verify-*.log`; riêng art và contracts dùng log `*-final.log` sau khi sửa lỗi trong quá trình triển khai. Chạy thêm `verify_stair_carry.gd` cho T2 trên thang. `check_scripts.gd`, editor import, Python layout dùng interpreter uv có sẵn và runner chung đều được chạy. Dùng APPDATA riêng trong `.local` cho các tiến trình test; không ghi thiết lập vào source hoặc sửa shared.

Kết quả cuối: **672 checks museum, 0 failures** trong 12 suite; **342 scripts** biên dịch, layout **792 runtime references**, tất cả exit 0. Runner chung cuối: **All tests passed, exit 0** trong [integrated-final.log](integrated-final.log).

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/isg_museum/tools/prepare_environment_modules.gd
godot --headless --path . --script res://maps/isg_museum/tools/build_geometry.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_materials.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd
godot --headless --path . --script res://maps/isg_museum/tools/bake_navigation.gd
godot --headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd -- --check
godot --headless --path . --script res://tools/ci/check_scripts.gd
godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_<suite>.gd
godot --headless --path . --fixed-fps 60 res://tests/test_scene.tscn
python -B tools/ci/check_layout.py
```

`<suite>` gồm blockout, environment_art, editing_mode, room_feedback, carry, empty_frame, staff_room, storage, service, exhibits, contract_variants và stair_carry. Mỗi suite có số lượng thực tế trong VALIDATION. Python là `C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe`. Runner dùng fixed-fps cho các bài kiểm tra mô phỏng, không dùng để kết luận FPS gameplay.

Baseline art/blockout/editing lần lượt 87/106/75 checks, đều 0 failures. Lỗi phát hiện khi triển khai: khai báo AABB thiếu type, ownership ribbon không được pack, và một lượt contract đọc file geometry lúc authoring đang ghi. Đã sửa và chạy lại với scene hoàn chỉnh. Root certificate store diagnostic trên Windows và cảnh báo tài nguyên khi thoát staff suite là diagnostic đã có. Log lỗi trung gian được giữ để đối chiếu; chỉ kết quả cuối trong VALIDATION được dùng bàn giao.

## File và giới hạn

[CHANGED_FILES.txt](CHANGED_FILES.txt) liệt kê toàn bộ file. Nguồn chính: `build_geometry.gd`, `environment_art_builder.gd`, `prepare_environment_modules.gd`, `material_palette.gd`, layout JSON; đầu ra geometry/module/manifest/navmesh được sinh lại. Các scene khác qua material/art pass có thay resource serialization; script gameplay, AI, rig, điều khiển và editing flag giữ nguyên.

Các góc chụp và video đã được xem trực tiếp từ output Godot. Vòm mới là hình học tham số theo nhịp hiện hành, không tái tạo toàn bộ hoa văn Object_5. Tán cây cao có thể che một phần kiến trúc ở góc xiên; cây cao và ánh sáng v1.1 giữ nguyên theo phạm vi. Không tuyên bố kiểm tra mọi góc camera hoặc mọi GPU; chưa chạy export Windows/CI Linux và chưa benchmark riêng hiệu năng đợt này.

## Bổ sung mục 6–7: hướng tủ kho và ghế G3

Kiểm tra ngày **15/11/2026**, sau khi hoàn tất năm mục trên. Đã mở nguồn glTF trong Godot qua cùng `prepare_visual()` ở yaw 0, đối chiếu cả hai mặt. Cả hai model có mặt trước hướng **+Z**. Tủ thực sự bị quay ngược: mặt có cánh, ngăn kéo và tay nắm nằm phía +Z, trong khi kho cần mặt trước -Z. Ghế cũng bị ngược: yaw +90 đưa mặt trước về +X, xa bàn.

| Instance | Yaw trước → sau | Kết quả |
|---|---|---|
| `storage_cabinet` | 0° → 180° | Cánh/ngăn kéo hướng -Z vào phòng; lưng +Z sát tường nam |
| `g3_chair` | 90° → -90° | Mặt ghế hướng -X về bàn A; lưng ghế +X |
| `restoration_cabinet` | -90° → -90° | Giữ nguyên bố trí riêng của tủ phục chế |

Chỉ sửa yaw hai entry trong `environment_art_layout.json`, áp art pass để lưu scene/manifest. `prepare_visual()` xoay VisualPivot trước khi tính bounds và căn chân/tâm; root vẫn scale 1. Tủ giữ vị trí `(31.5,0,23.525)`, envelope `3.4×2.2×0.65 m`, đáy Y=0 và mép sau Z=23.85 sát mặt trong tường Z=24. Ghế giữ `(34.1,0,12)`, envelope `0.7×1.2×0.7 m`. G3 giữ vị trí ghế và yaw +90° của controller (nhìn -X); không cần chỉnh `staff_presentation.gd`, `staff_guard.gd` hoặc root guard.

Các mesh tủ cũ, CabinetDoor/CabinetHandle và ChairSeat/ChairBack đều ẩn sau reload; không có mặt/tay nắm cũ chồng lên. [Audit scene đã reload](furniture-after-audit.json) ghi đủ **9 guard**, G3 ngủ tại ghế, pose/pivot/bounds và trạng thái các mesh cũ. Ảnh bên cạnh cho thấy G3 ngồi trên mặt ghế, lưng tựa đúng phía và chân không xuyên bàn. Suite staff kiểm tra thức dậy, tìm quanh bàn, truy đuổi và trở về ghế đạt.

| Bằng chứng Godot | Trước | Sau |
|---|---|---|
| Tủ nhìn từ trong kho | [lưng tủ](furniture-before-cabinet.png) | [cánh và ngăn kéo](furniture-after-cabinet.png) |
| Ghế với G3, nhìn bên cạnh | [ghế ngược](furniture-before-g3-side.png) | [ngồi hướng về bàn](furniture-after-g3-side.png) |
| Ghế/G3 nhìn xiên | [trước](furniture-before-g3-oblique.png) | [sau](furniture-after-g3-oblique.png) |

[Nguồn tủ nhìn từ +Z](furniture-before-source-storage_cabinet-plus-z.png), [nguồn tủ nhìn từ -Z](furniture-before-source-storage_cabinet-minus-z.png), [nguồn ghế nhìn từ +Z](furniture-before-source-g3_chair-plus-z.png). Công cụ `capture_furniture_feedback.gd` chụp scene **museum.tscn**, không dùng editing. Đợi G3 thật khởi tạo tư thế ngủ rồi dừng xử lý riêng instance chụp để giữ camera cố định; ảnh 1280×720 dùng camera QA riêng. Đây là bằng chứng tư thế ban đầu, không thay cho kiểm tra AI động.

Các lệnh chạy bổ sung, tất cả **exit 0**:

| Lệnh/tham số Godot | Kết quả | Log |
|---|---|---|
| `--headless --path . --script res://maps/isg_museum/tools/apply_environment_art.gd` | Lưu art | [log](furniture-apply.log) |
| Cùng lệnh trên, thêm `-- --check` | Saved scene khớp nguồn; hash scene/manifest không đổi | [log](furniture-check-art.log), [hash check](furniture-readonly.json) |
| `--headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_environment_art.gd` | 93 checks, 0 failures | [log](furniture-verify-environment_art.log) |
| `--headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_storage.gd` | 34 checks, 0 failures | [log](furniture-verify-storage.log) |
| `--headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_staff_room.gd` | 55 checks, 0 failures | [log](furniture-verify-staff_room.log) |
| `--headless --path . --editor --quit` | Import công cụ chụp | [log](furniture-import.log) |
| `--headless --path . --script res://tools/ci/check_scripts.gd` | 343 scripts đạt | [log](furniture-check-scripts.log) |
| `--path . --script res://maps/isg_museum/tools/capture_furniture_feedback.gd -- --after` | Ảnh thực và audit sau reload | [log](furniture-after.log) |

Tổng kiểm tra bổ sung: **182 checks, 0 failures**. Không cộng vào 672 checks của lượt năm mục để giả lập một lượt full regression mới. [Kết quả máy đọc](furniture-validation.json) được gắn vào VALIDATION chung. Không đổi collider hoặc bake nav lần nữa: SHA256 trước/sau phần bổ sung đều `9efa7029d1a69b43e70323af30d9119ffb2bd2b3cdbcaaaa8280bacea4cd3bfb`.

File nguồn bổ sung: layout JSON và công cụ chụp mới; geometry/manifest được lưu lại qua art pass, cùng các scene đi qua pipeline. Không sửa model nguồn, hướng tủ phục chế, logic AI, điều kiện lấy dây/mật mã hoặc chế độ editing. Bằng chứng cũ được giữ nguyên; ảnh bổ sung dùng tiền tố `furniture-`.
