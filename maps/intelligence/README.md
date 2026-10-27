# K17 — 120 giây cuối

Map độc lập của Nguyễn Đình Phiên: An đột nhập cơ sở tình báo trong chiến tranh hư cấu, thu hồi **Mật lệnh 04** rồi thoát trước khi cơ sở phong tỏa. [Cốt truyện gốc](https://docs.google.com/document/d/1JnYON8pKSkMLtzYODPYOhB-96hSxaVUOpCYgm020JS8/edit).

Bản V3 mở khuôn viên từ 48 × 60 m lên **96 × 108 m**, gồm tám khu chức năng, kho mật **B1**, hai cầu thang, hai đường vào và hai điểm tập kết ngoài hàng rào. Có **sáu lính thường trực**, tối đa **bốn cảnh vệ tiếp viện** khi lấy hồ sơ. Dùng AI, điều khiển, tương tác và HUD chung của nhóm.

## Mở và tự chơi

Mở `project.godot` bằng **Godot 4.7.2 official**, nhấn F5 rồi chọn **K17 — 120 giây cuối**. Hoặc mở `scenes/intelligence_k17.tscn`, nhấn F6.

```text
godot --path . res://maps/intelligence/scenes/intelligence_k17.tscn
```

WASD di chuyển, chuột nhìn, Shift chạy, C/Ctrl cúi, E/giữ E tương tác, Esc/P tạm dừng, F3 bật thông tin gỡ lỗi. Không cần nhảy hoặc leo dây.

**Test không lính:** chọn **K17 — Test map không lính gác** trong menu hoặc chạy `scenes/intelligence_k17_test.tscn`. Đây là cùng bản đồ và nhiệm vụ; cảm biến, cửa, checkpoint và đồng hồ vẫn chạy. Cả lính thường trực lẫn tiếp viện đều được tắt. HUD và kết quả ghi rõ lượt test. Restart/thử lại giữ đúng chế độ; về menu chọn bản thường để chơi có lính.

## Đi nhiệm vụ

1. Từ vành đai, vào qua sân/nhà xe phía tây hoặc đường hậu cần phía đông. Quan sát biển khu vực và các tuyến tuần tra.
2. Lấy **giấy thông hành** trên bàn phòng trực phía tây, qua nhà xe. Phòng trực có cửa trước và cửa phía khối nhà trung tâm.
3. Vào **khối chỉ huy/vô tuyến**, lấy **sơ đồ và mã kho** trên bàn liên lạc. Phía sau vách che trong phòng vô tuyến có checkpoint đầu tiên.
4. Có thể ghé **trạm điện phía đông**, giữ E **2,5 giây** ở bảng **CHỐT CỬA HẬU**. Khi rút lui, cửa hậu đã chuẩn bị mở ngay; nếu chưa chuẩn bị phải giữ E tám giây.
5. Dùng thẻ mở cửa khu phân loại hồ sơ. Đi hành lang bên phải đến **checkpoint trước kho mật**, rồi mở cửa xuống **B1** bằng mã kho đã lấy.
6. Qua hai dải cảm biến: **xanh được qua, vàng sắp quét, đỏ dừng lại**. Có vùng chờ giữa các dải. Đến bàn hồ sơ và giữ E **3,5 giây** để mở niêm phong. Thanh tiến trình hủy khi nhả E, nhìn lệch, rời tầm hoặc pause.
7. Khi lấy xong hồ sơ, đồng hồ **120 giây** bắt đầu. Chọn đường rút và mang tài liệu vào vùng đèn xanh ngoài hàng rào để thắng.

**Rút qua sân:** quay lại cầu thang chính, qua khối giữa và ra sân. Có thể dùng lối kỹ thuật ra sân để tránh phòng trực; dùng xe, kiện hàng và mép sân để tránh chốt tiếp viện. Cổng chính sẽ đóng theo lịch.

**Rút bảo trì:** từ kho B1, mở cửa phía đông bằng hồ sơ, đi hành lang ngầm rồi lên cầu thang thứ hai. Qua các vách kiểm soát của tuyến dịch vụ/xưởng để đến cửa hậu phía đông. Tuyến này có chỗ che và vẫn dùng được sau khi cổng chính khóa.

Radio ở phòng vô tuyến hẹn tiếng rè sau **bốn giây**, phát từ hai loa có vị trí thật và hồi sau 20 giây. Chỉ lính nghe được mới điều tra. Lính đã truy đuổi tiếp tục theo luật AI chung, không tự quên người chơi vì radio.

## Báo động và tiếp viện

| Sau khi lấy hồ sơ | Sự kiện |
|---|---|
| T+0 | Đèn đỏ/còi báo động, cửa hậu khóa cơ, bắt đầu 120 giây |
| T+10 | Hai cảnh vệ từ chốt phản ứng/khu bắc; tổng tối đa tám lính |
| T+45 | Hai cảnh vệ từ chốt vận tải/hậu cần; tổng tối đa mười lính |
| T+70 | Cảnh báo sắp đóng cổng chính |
| T+90 | Cổng chính nhận lệnh đóng; cửa hậu vẫn mở được bằng chốt cơ |
| T+100 | Loa nhắc tăng kiểm soát chốt đông |
| T+120 | Thất bại nếu chưa đưa hồ sơ tới tập kết |

Tiếp viện dùng Guard và hình ảnh quân sự chung với lính hiện có. Cảnh vệ nhận tuyến kiểm tra từ chốt; nhìn/nghe mới cung cấp thông tin về người chơi. Điểm vào đang bị người chơi chiếm hoặc nhìn trực tiếp sẽ được hoãn có giới hạn. Không sinh lính vô hạn. Báo động cảm biến trước khi lấy hồ sơ không tự gọi hai đợt tiếp viện.

Cửa chờ người đứng ở ngưỡng tối đa ba giây rồi hủy lần đóng nếu vẫn bị cản. Người đã qua cổng có thể tiếp tục tới tập kết. Pause dừng lịch. Bắt/hết giờ rồi thử lại sẽ khôi phục checkpoint, xóa tiếp viện của lượt cũ, hủy thao tác/sự kiện đang chờ và cho phép hai đợt chạy lại sau lần lấy hồ sơ tiếp theo. Không ghi đè checkpoint trong chặng rút lui.

## Cấu trúc và dựng lại

- `scenes/intelligence_k17.tscn`: map chính; `intelligence_k17_test.tscn` kế thừa để test không lính.
- `scenes/sectors/`: tám scene được instance vào map: vành đai, nhà xe, phòng trực, chỉ huy, trạm điện, phân loại, kho mật và tuyến dịch vụ.
- `scenes/environment/k17_environment.tscn`: mỹ thuật lõi giữa; `k17_security.tscn`: cảm biến, radio, chốt và cổng động.
- `resources/layout/k17_layout.gd`: vị trí nhiệm vụ, điểm tập kết, tuần tra và các tuyến điều động.
- `tools/k17_expansion_builder.gd`: kiến trúc/va chạm/mỹ thuật các khu mở rộng; `build_k17.gd`: ghép map, nhiệm vụ và bake navmesh.
- `scripts/reinforcements.gd`: điều phối hai đợt tiếp viện, kiểm tra điểm vào, ngoại hình và dọn actor khi thử lại.
- `resources/k17_v3_lightmap.*`: ánh sáng bake cho toàn bộ map, do `LightmapGI` ở root quản lý.

Builder sinh lại các sector và gameplay từ mã nguồn; sửa builder/dữ liệu bố cục trước khi chạy để giữ thay đổi qua lần dựng tiếp theo. Lần dựng thường giữ scene mỹ thuật lõi và lightmap đã có. Dùng `-- --rebuild-art` khi chủ động muốn sinh lại mỹ thuật lõi. Thay vị trí, hình học hoặc mesh tĩnh cần **bake lại ánh sáng**, đồng thời kiểm tra collider/navmesh/link.

Bake: khởi động editor với `--rendering-method mobile`, mở **map chính**, chọn `LightmapGI` ở root, Bake Lightmaps và lưu `resources/k17_v3_lightmap.lmbake`, rồi lưu scene. Có thể dùng EditorScript `tools/bake_lightmaps.gd`. Khi chơi vẫn dùng Compatibility như các map khác; không cần cài plugin.

```text
godot --headless --path . --script res://maps/intelligence/tools/build_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/check_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/check_art.gd
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd -- --crouch --prepare --sprint-yard
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --prepare --radio --wait-radio --sprint-yard --settle-before-file --yard-flank
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd -- --reinforced
```

Tool đi bộ dùng điều khiển và giữ E thật, không dịch chuyển giữa waypoint. Mặc định chạy scene không lính để kiểm tra hình học; `--live-guards` giữ nhận thức/AI và tiếp viện thật. `--entry=maintenance` kiểm tra hướng vào hậu cần; `--route=courtyard|maintenance` chọn đường rút; bỏ `--prepare` để kiểm tra mở cửa hậu tám giây. `--yard-flank` chọn đường vòng sân và dùng radio trước lúc lấy hồ sơ. Soak tiếp viện kiểm tra riêng tuyến đường với nhận thức nhìn tạm dừng; E2E có lính kiểm tra đầy đủ nhìn/nghe/truy đuổi.

Khi chạy QA có render trong nền, thêm `--background` để tool tự tiếp tục nếu cửa sổ mất focus. Thao tác giữ E bị hủy do pause được thử lại bằng một lần giữ mới. Tùy chọn này chỉ thuộc tool QA; bản chơi thường vẫn pause khi mất focus.

`preview_expansion.gd` chụp các góc dàn sẵn để xem mỹ thuật, không thay bằng chứng thắng. `benchmark_expansion.gd` đo renderer theo đồng hồ thực tại các góc cố định với sáu/mười NPC; không dùng `--headless` hoặc `--fixed-fps` cho benchmark.

Xem [kiểm tra V3](docs/expansion-v3/VALIDATION.md), [nguồn tài nguyên miễn phí](assets/CREDITS.md), [bản an ninh V2](docs/security-v2/VALIDATION.md). Bản mở rộng vẫn dùng nhân vật/đạo cụ phong cách đơn giản. Mục tiêu 10–15 phút lần đầu và độ khó cuối cần chơi thử với người chưa biết map; chưa có chiến đấu, bắn súng, leo dây hoặc xe lái được. Độ sáng render chưa làm thay đổi luật nhìn/nghe NPC.
