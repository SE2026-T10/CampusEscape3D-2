# K17 — 120 giây cuối

Người phụ trách: Nguyễn Đình Phiên. Một người lính thâm nhập cơ sở tình báo trong chiến tranh hư cấu, thu hồi Mật lệnh 04 rồi mang hồ sơ về điểm tập kết.

[Cốt truyện gốc](https://docs.google.com/document/d/1JnYON8pKSkMLtzYODPYOhB-96hSxaVUOpCYgm020JS8/edit). Vòng nhiệm vụ V1 đã có đợt nâng cấp mỹ thuật: kiến trúc bê tông/olive, hàng rào lưới thép, hành lang kiểm soát, trần, đồ nội thất, hình ảnh lính và ánh sáng bake. Xem [nguồn asset](assets/CREDITS.md), [kiểm tra mỹ thuật](docs/art-v2/VALIDATION.md) và [bằng chứng V1 trước nâng cấp](docs/v1/VALIDATION.md).

## Chơi bản mở rộng

Dùng Godot **4.7.2 official**, mở `project.godot`, chạy project và chọn **K17 — 120 giây cuối** trong menu. Có thể mở trực tiếp `scenes/intelligence_k17.tscn` và nhấn F6.

```text
godot --path . res://maps/intelligence/scenes/intelligence_k17.tscn
```

WASD di chuyển, chuột nhìn, Shift chạy, C/Ctrl cúi, E tương tác, Esc/P tạm dừng. F3 bật/tắt thông tin gỡ lỗi trong bản phát triển.

1. Vào cơ sở qua sân phía tây hoặc lối kỹ thuật phía đông.
2. Đến bàn trong phòng trực phía tây và lấy giấy thông hành bằng E.
3. Mở cửa gia cường khu hồ sơ bằng E. Vòng qua tủ che bên phải, tìm vạch sơn và biển checkpoint.
4. Vượt hai dải cảm biến ở hành lang hồ sơ: **xanh được qua, vàng sắp quét, đỏ dừng lại**. Dừng giữa hai dải để quan sát nhịp tiếp theo.
5. Nhìn vào Mật lệnh 04, **giữ E 3,5 giây** để mở niêm phong. Thanh tiến trình xuất hiện dưới lời nhắc; nhả E, nhìn lệch, rời tầm, pause hoặc bị bắt sẽ hủy thao tác. Đồng hồ 120 giây bắt đầu khi lấy xong.
6. Rút qua sân phía tây trước khi cổng đóng, hoặc tới cửa hậu phía đông và giữ E 8 giây mở khóa cơ. Nếu đã chuẩn bị chốt trước đó, cửa hậu mở ngay bằng E.
7. Mang hồ sơ đến vùng đèn xanh bên ngoài hàng rào để hoàn thành.

Bàn radio ở khu thông tin có bộ hẹn bốn giây; hai loa gắn trong hành lang và ngoài sân phát tiếng rè tại vị trí thật, thu hút lính nghe được. Radio hồi sau 20 giây từ lúc hẹn. Lính đang truy đuổi vẫn theo luật AI chung.

Trước khi lấy hồ sơ, có thể tới bảng **CHỐT CỬA HẬU** trên vách phía đông khu kỹ thuật và giữ E 2,5 giây để chuẩn bị mở nhanh. Nên làm trước khi lưu checkpoint; việc chuẩn bị tham gia cùng snapshot nhiệm vụ.

Lịch phong tỏa tính từ lúc nhấc hồ sơ: cửa hậu khóa cơ ngay; giây **50** loa cảnh báo; giây **65** cổng sân nhận lệnh đóng; giây **85** loa chốt phía đông gọi kiểm soát. Cổng có vùng kiểm tra người đứng ở ngưỡng: chờ tối đa ba giây rồi hủy lần đóng nếu còn bị cản. Các mốc khác vẫn tiếp tục. Nếu đã qua cổng trước khi đóng, vẫn có thể vào vùng tập kết bên ngoài.

Bị bắt sẽ quay về checkpoint đã kích hoạt; trước checkpoint sẽ trở về điểm đầu. Hết giờ hiện màn thất bại với nút thử lại checkpoint, chơi lại từ đầu và về menu. Khôi phục trước phòng hồ sơ giữ giấy thông hành/cửa đã mở, trả hồ sơ về giá và đưa đồng hồ về trạng thái chưa chạy. Đi qua checkpoint trong lúc rút lui không ghi đè lần lưu này.

## Phạm vi đã có

- Một tầng, sân tiếp vận, phòng trực, khu thông tin, khu hồ sơ và lối kỹ thuật/bảo trì.
- Hai tuyến tiếp cận, hai điểm tập kết, bốn NPC với tuyến tuần tra riêng và navmesh đã bake.
- Player, tương tác E, AI nhìn/nghe và HUD đều dùng phần chung; `features/` cung cấp nhiệm vụ, giấy thông hành, cửa và checkpoint.
- Trạng thái hồ sơ và đồng hồ thuộc `mission_controller.gd`; HUD nhận dữ liệu qua `MapHudProvider`.
- Pause dừng đồng hồ; hết giờ không tăng số lần bị lính bắt; thắng ghi nhận đường rút và số giây còn lại.

Đã bổ sung giữ E/thanh tiến trình dùng chung theo tùy chọn, cảm biến, radio, chốt chuẩn bị cửa hậu, lịch phong tỏa, lời radio theo ưu tiên và ba âm thanh tự tổng hợp. Các đồ vật cũ giữ thời gian tương tác bằng 0. Cổng dùng collider và walking link đồng bộ trên navmesh đã cắt tại ngưỡng, không để NPC lên đường đi xuyên cổng đã khóa. Xem [báo cáo bản mở rộng](docs/security-v2/VALIDATION.md).

Đồng hồ 120 giây và lịch cửa là thông số thử nghiệm; chưa được cân bằng thành độ khó cuối hoặc xác nhận thời lượng 10–15 phút bằng người chơi. Độ tối của hình ảnh chưa làm thay đổi luật nhìn/nghe NPC. Thoại hiện thể hiện bằng chữ; chưa có giọng lồng tiếng hoặc bộ chiến đấu.

## Dựng lại và kiểm tra

`build_k17.gd` tạo scene gameplay và navmesh từ bố cục collision. Lần dựng bình thường **giữ nguyên** scene môi trường và lightmap đã bake. Có thể chỉnh mỹ thuật trực tiếp trong `scenes/environment/k17_environment.tscn`.

Chỉ khi muốn sinh lại môi trường từ bộ module, dùng `-- --rebuild-art`; thao tác này ghi đè scene môi trường và cần bake lại ánh sáng. Các tool không chạy khi chơi game.

`scenes/k17_security.tscn` là lớp gameplay được builder sinh riêng, chứa cảm biến, loa, chốt và hai cổng động. Chỉnh thông số hoặc vị trí trong script/builder tương ứng khi muốn giữ chúng qua lần dựng lại. Các mesh và đèn bake trong `environment/` được giữ nguyên.

```text
godot --headless --path . --script res://maps/intelligence/tools/build_k17.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/intelligence/tools/check_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/check_art.gd
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd
```

Tái tạo model: Python chạy `tools/fetch_art_assets.py --cache <thư_mục_ngoài_project>` để lấy bản gốc và xác minh MD5; Blender 4.5+ chạy `--background --python tools/build_art_models.py -- --cache <thư_mục_đó>`. Các đường dẫn trong ví dụ là tương đối với thư mục map; nếu chạy từ root project hãy thêm `maps/intelligence/`.

Import model tĩnh với **Meshes → Light Baking → Static Lightmaps** (giá trị 2), texel size 0.2; giữ tắt mesh compression theo các tệp `.glb.import` đã lưu. Hình ảnh lính chuyển động dùng thiết lập riêng, không bake vào môi trường.

Bake ánh sáng: mở editor với `--rendering-method mobile` trên GPU có RenderingDevice, mở `scenes/environment/k17_environment.tscn`, chọn `LightmapGI`, nhấn **Bake Lightmaps**, lưu `resources/k17_lightmap.lmbake` và lưu scene. Có thể chạy EditorScript `tools/bake_lightmaps.gd` bằng Ctrl+Shift+X trong editor Godot 4.7. Project phát hành vẫn dùng Compatibility; không cần đổi renderer trong `project.godot`.

`preview_art.gd` chụp các góc cố định, tắt quyết định NPC chỉ trong lượt chụp; `benchmark_art.gd` đo frame time theo thời gian thực với cả bốn NPC hoạt động, tắt bắt và giữ camera đứng yên để so sánh. Không dùng số đo headless/fixed-fps làm FPS đồ họa.

`playthrough_k17.gd` dùng bộ điều khiển và tương tác thật để kiểm tra va chạm của cả hai tuyến, chủ động tắt NPC chỉ trong lượt QA này. `guard_soak_k17.gd` kiểm tra riêng bốn NPC đang hoạt động trong scene thật. Scene phát hành luôn giữ NPC hoạt động.

Tool đi bộ có các tùy chọn `--live-guards`, `--crouch`, `--radio`, `--wait-radio`, `--prepare`, `--sprint-yard`, `--settle-before-file`, `--yard-flank`, `--route=courtyard|maintenance` và `--entry=courtyard|maintenance`. Nó biết dừng trước dải cảm biến để đợi xanh; vẫn dùng di chuyển, tương tác và thời gian giữ thật. `--wait-radio` đợi tám giây sau khi hẹn để lính có thời gian phản ứng; `--settle-before-file` đợi trạng thái yên ba giây ở checkpoint có vật che; `--yard-flank` dùng hành lang kỹ thuật rồi đi dọc sân tới cổng phía tây. Các tùy chọn này chỉ dành cho QA, không sửa AI hoặc điều kiện thắng. Một tuyến cố định bị bắt không tự chứng minh lỗi gameplay; log ghi trạng thái, số lần bị bắt và các công cụ đã dùng.

```text
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --radio --wait-radio --prepare --sprint-yard --settle-before-file --yard-flank --entry=courtyard
```

`capture_security.gd` chụp các trạng thái được dàn sẵn của cảm biến, giữ E, radio và cửa phong tỏa bằng renderer thật. Không dùng lượt chụp thay bằng chứng hoàn thành E2E. Suite giữ E kiểm tra hủy và tương thích mặc định; suite an ninh kiểm tra ray cảm biến, lịch hẹn, snapshot và khả năng đi qua từng trạng thái cổng.

Suite nhiệm vụ được đăng ký trong `tests/test_scene.gd`; `tools/map_flow.gd` kiểm tra việc chọn, restart và rời cả ba map. Build/export dùng quy trình chung. Không có phụ thuộc runtime vào scene hay script của thư viện.
