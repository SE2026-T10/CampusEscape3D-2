# K17 — 120 giây cuối

Map độc lập của Nguyễn Đình Phiên: An đột nhập cơ sở tình báo trong chiến tranh hư cấu, thu hồi **Mật lệnh 04** rồi thoát trước khi cơ sở phong tỏa. [Cốt truyện gốc](https://docs.google.com/document/d/1JnYON8pKSkMLtzYODPYOhB-96hSxaVUOpCYgm020JS8/edit).

Bản V4 giữ khuôn viên **96 × 108 m**, tám khu chức năng, kho mật **B1**, hai cầu thang và hai đường rút của V3. Bổ sung **bảy chỗ nấp, ba camera, nguồn dự phòng, mã kho thực, nhật ký và vật ném gây tiếng động**. Có sáu lính thường trực, tối đa bốn cảnh vệ tiếp viện. AI, điều khiển, tương tác và HUD vẫn dùng phần chung của nhóm.

Đợt rà soát sau V4 bổ sung nội thất theo công năng, giá đỡ camera và sửa bảy điểm nấp. Camera trong nhà gắn trần, camera ngoài trời có cột/chân đế; phòng tác chiến, phân loại, trạm điện và xưởng có trang thiết bị. Khu phân loại phía đông đã có cửa thông nội bộ. Xem [ảnh và kiểm tra bản rà soát](docs/visual-review-v4/VALIDATION.md).

Đợt [sửa điểm nối và gá đỡ](docs/attachments-v4/VALIDATION.md) nối lại các co ống theo đúng miệng nối, làm liền tuyến máng dây B1 và bổ sung gá, cột hoặc ty treo cho bảng biển. Bảng trên giá hồ sơ có thanh ngang đỡ; bảng điều khiển trạm điện và keypad có tủ/chân đỡ.

**V5 — Phá hoại tùy chọn:** sau khi lấy hồ sơ, có thể đặt thiết bị tại tủ tình báo dự phòng trong xưởng phía đông, cạnh bàn dụng cụ. Giữ E **5 giây** ở mặt tủ rồi rút trong cùng **120 giây**. Khi đã tới tập kết an toàn, cảnh phá hủy chạy khoảng bốn giây rồi hiện kết quả; Enter bỏ qua cảnh, Esc/P tạm dừng. Bỏ qua phá hoại vẫn thắng bình thường. Xem [kế hoạch](docs/sabotage-v5/PLAN.md) và [kết quả kiểm thử V5](docs/sabotage-v5/VALIDATION.md).

## Mở và tự chơi

Mở `project.godot` bằng **Godot 4.7.2 official**, nhấn F5 rồi chọn **K17 — 120 giây cuối**. Hoặc mở `scenes/intelligence_k17.tscn`, nhấn F6.

```text
godot --path . res://maps/intelligence/scenes/intelligence_k17.tscn
```

WASD di chuyển, chuột nhìn, Shift chạy, C/Ctrl cúi, E/giữ E tương tác, **1–3 chọn ô đồ, F ném chai, J xem nhật ký**, Esc/P tạm dừng, F3 bật thông tin gỡ lỗi. V4 chính chưa bật stamina; đây là đợt thử bổ sung sau khi cân bằng đường rút.

**Test không lính:** chọn **K17 — Test map không lính gác** trong menu hoặc chạy `scenes/intelligence_k17_test.tscn`. Cùng bản đồ và nhiệm vụ; camera, cảm biến, mã kho, nguồn điện, checkpoint và đồng hồ vẫn chạy. Cả lính thường trực lẫn tiếp viện đều tắt. Restart/thử lại giữ đúng chế độ; về menu chọn bản thường để chơi có lính.

## Đi nhiệm vụ

1. Từ vành đai, vào qua sân/nhà xe phía tây hoặc đường hậu cần phía đông. Quan sát biển khu vực và các tuyến tuần tra.
2. Lấy **giấy thông hành** trên bàn phòng trực phía tây, qua nhà xe. Phòng trực có cửa trước và cửa phía khối nhà trung tâm.
3. Đọc **chỉ dẫn kho B1** trên bàn vô tuyến ở khối chỉ huy. Có thể đọc trước khi lấy thẻ. Phía sau vách che có checkpoint đầu tiên, được lưu khi đủ thẻ và chỉ dẫn.
4. Có thể ghé **trạm điện phía đông**: tắt công tắc nguồn camera, đọc ghi chú dự phòng và giữ E **2,5 giây** ở **CHỐT CỬA HẬU**. Cửa hậu đã chuẩn bị mở ngay khi rút; nếu chưa chuẩn bị phải giữ E tám giây. Hai bước chuẩn bị là mục tiêu tùy chọn.
5. Mang thẻ để mở cửa khu hồ sơ. Đi hành lang bên phải đến **checkpoint khu mật**, đọc **bảng ca trực** rồi đối chiếu với chỉ dẫn trong J để suy ra bốn chữ số. Đến keypad cạnh cửa B1, E đổi từng số và xác nhận. Sai ba lần khóa tạm 20 giây, sau đó được thử lại; chưa tính 120 giây ở bước này.
6. Qua hai dải cảm biến: **xanh được qua, vàng sắp quét, đỏ dừng lại**. Có vùng chờ giữa các dải. Đến bàn hồ sơ và giữ E **3,5 giây** để mở niêm phong. Thanh tiến trình hủy khi nhả E, nhìn lệch, rời tầm hoặc pause.
7. Khi lấy xong hồ sơ, đồng hồ **120 giây** bắt đầu. Chọn đường rút và mang tài liệu vào vùng đèn xanh ngoài hàng rào để thắng.

Có **bảy mục tiêu bắt buộc** và **ba mục tiêu tùy chọn**: chuẩn bị cửa hậu, ngắt camera chính và phá hoại cụm tình báo. Thiết bị phá hoại được cấp sẵn, không chiếm ô đồ và chỉ tiêu hao khi giữ E hoàn tất; nhả E, nhìn lệch, rời tầm hoặc pause sẽ hủy thao tác. Chỉ đặt sau khi có hồ sơ; đặt xong vẫn chưa được tính phá hoại thành công cho đến khi thoát và kích hoạt. Bị bắt/hết giờ rồi thử lại sẽ trả thiết bị và tủ về trạng thái trước khi lấy hồ sơ.

Túi ba ô đủ cho giấy thông hành và hai chai rỗng có sẵn trong map. Hồ sơ và ghi chú không chiếm ô. Chai chỉ mất khi ném thành công; thẻ không bị tiêu hao. Nhật ký giữ kiến thức sau khi bị bắt; đồ mang theo, nguồn điện, cửa và tiến độ trở về checkpoint. Ghi chú nguồn điện có hướng dẫn vị trí và luật phá hoại để xem lại bằng J.

**Rút qua sân:** quay lại cầu thang chính, qua khối giữa và ra sân. Có thể dùng lối kỹ thuật ra sân để tránh phòng trực; dùng xe, kiện hàng và mép sân để tránh chốt tiếp viện. Cổng chính sẽ đóng theo lịch.

**Rút bảo trì:** từ kho B1, mở cửa phía đông bằng hồ sơ, đi hành lang ngầm rồi lên cầu thang thứ hai. Qua các vách kiểm soát của tuyến dịch vụ/xưởng để đến cửa hậu phía đông. Tuyến này có chỗ che và vẫn dùng được sau khi cổng chính khóa.

Radio ở phòng vô tuyến hẹn tiếng rè sau **bốn giây**, phát từ hai loa có vị trí thật và hồi sau 20 giây. Chỉ lính nghe được mới điều tra. Lính đã truy đuổi tiếp tục theo luật AI chung, không tự quên người chơi vì radio.

Bảy vị trí nấp nằm sau xe, cạnh tủ, sau vách hoặc trong hốc kiện hàng ở nhà xe, phòng trực, vô tuyến, trạm điện, khu hồ sơ, B1 và tuyến dịch vụ. Cúi và vào khi chưa bị thấy là điều kiện để được tính đang nấp; **vật che phải thực sự chắn đường nhìn từ người quan sát đến cơ thể**. Lính hoặc camera nhìn qua mặt hở vẫn phát hiện được; đứng trên vùng đánh dấu không tạo khả năng tàng hình. Bản hiện tại bỏ ô màu dưới sàn và nhãn nấp lơ lửng. Lính vẫn có thể vòng vào kiểm tra; camera có đường nhìn rõ sẽ hủy trạng thái HIDDEN trên HUD.

K17 bật luật an ninh mở rộng cho cả lính thường trực và tiếp viện: đuổi 5 m/s, phát hiện nhanh hơn ×1,35 và tìm kiếm lâu hơn ×1,5 khi báo động. Đứng trong bóng tối chưa làm giảm tầm nhìn của AI.

Ba camera kiểm soát khối chỉ huy, khu hồ sơ và tuyến dịch vụ. Chúng tích thanh phát hiện, bị tường/vật che chặn và chỉ báo động khi đầy; camera không tự bắt người chơi. Tắt nguồn chính tạo lợi thế trước khi lấy hồ sơ. Sau đó nguồn dự phòng bật lại camera ở **T+15**, công tắc nguồn chính không cắt được nguồn dự phòng.

## Báo động và tiếp viện

| Sau khi lấy hồ sơ | Sự kiện |
|---|---|
| T+0 | Đèn đỏ/còi báo động, cửa hậu khóa cơ, bắt đầu 120 giây |
| T+10 | Hai cảnh vệ từ chốt phản ứng/khu bắc; tổng tối đa tám lính |
| T+15 | Nguồn dự phòng cấp lại điện cho ba camera |
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
- `tools/k17_room_dressing.gd`: nội thất theo công năng, hốc vật che và giá camera; được ghép trước khi bake navmesh/gom mesh/bake ánh sáng.
- `tools/k17_attachment_builder.gd`: gá tường, cột và ty treo cho biển; `check_attachments.gd` kiểm tra điểm tựa trên hình học thật trước khi gom mesh và kiểm tra các đầu nối ống/máng dây.
- `scripts/reinforcements.gd`: điều phối hai đợt tiếp viện, kiểm tra điểm vào, ngoại hình và dọn actor khi thử lại.
- `resources/layout/k17_sabotage.gd`, `tools/k17_sabotage_builder.gd`: vị trí tủ/điểm đứng, góc kết thúc và nguồn dựng cụm thiết bị V5; navmesh dùng cùng footprint với collider thật.
- `scenes/props/k17_sabotage_target.tscn`: tủ có điểm tựa, thiết bị đã đặt và mô hình hư hại; các mesh thay trạng thái không gom/bake vào sector.
- `scripts/sabotage_controller.gd`, `sabotage_target.gd`: điều kiện đặt, giữ E dùng chung, tiêu hao một lần, trạng thái hư hại và checkpoint.
- `scripts/extraction_finale.gd`, `scenes/effects/k17_sabotage_finale.tscn`: góc máy, hiệu ứng/âm thanh, pause, bỏ qua và dọn cảnh. `mission_controller.gd` xác nhận thoát trước, dừng gameplay, chốt số liệu rồi hoàn thành nhiệm vụ sau cảnh; có đường hoàn tất dự phòng nếu phần trình bày lỗi.
- `scripts/game_menus.gd`: menu riêng K17, kết quả tiếng Việt và thời gian chụp tại tập kết, không cộng thời lượng cảnh phá hủy.
- `resources/layout/k17_v4.gd`: cấu hình AI, chỗ nấp, camera, tài liệu, keypad và vật ném.
- `scripts/security_alarm.gd`, `power_network.gd`: nối phong tỏa với AI và lịch nguồn dự phòng riêng K17.
- `scripts/hiding_spot.gd`, `security_camera.gd`, `stealth_director.gd`: lớp bổ sung riêng K17 kiểm tra nấp theo vật che/hướng nhìn và phản ánh camera lên HUD; giữ mã dùng chung của các map khác.
- `scripts/mission_note.gd`, `vault_keypad.gd`, `inventory.gd`, `objective_hud.gd`: dùng cơ chế chung với nội dung/điều kiện của map.
- `tools/k17_static_merge.gd`: gom mesh dạng khối theo ô không gian/vật liệu, giữ nguyên collider và tạo lại UV2.
- `resources/k17_v4_lightmap.*`: ánh sáng hiện hành cho toàn map. Dữ liệu V3 còn lưu để tham chiếu lịch sử.

Builder sinh lại các sector và gameplay từ mã nguồn; sửa builder/dữ liệu bố cục trước khi chạy để giữ thay đổi qua lần dựng tiếp theo. Lần dựng thường giữ scene mỹ thuật lõi và lightmap đã có. Dùng `-- --rebuild-art` khi chủ động muốn sinh lại mỹ thuật lõi. Thay vị trí, hình học hoặc mesh tĩnh cần **bake lại ánh sáng**, đồng thời kiểm tra collider/navmesh/link.

Bake: khởi động editor với `--rendering-method mobile`, mở **map chính**, chọn `LightmapGI` ở root, Bake Lightmaps và lưu `resources/k17_v4_lightmap.lmbake`, rồi lưu scene. Có thể dùng EditorScript `tools/bake_lightmaps.gd`. Khi chơi vẫn dùng Compatibility; không cần plugin. Sector được gom mesh mỗi lần dựng. Khi chủ động dựng lại mỹ thuật lõi, dùng `-- --rebuild-art --optimize-art` rồi bake lại; chạy builder thường sẽ giữ mỹ thuật lõi đã tối ưu.

```text
godot --headless --path . --script res://maps/intelligence/tools/build_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/check_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/check_art.gd
godot --headless --path . --script res://maps/intelligence/tools/check_attachments.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_sabotage.gd
godot --headless --path . --script res://maps/intelligence/tools/playthrough_k17.gd -- --crouch --prepare --sprint-yard
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --prepare --camera-off --radio --wait-radio --sprint-exfil --settle-before-file --yard-flank --watch-patrol --stage-delay=6 --route=courtyard --utilities-north
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --prepare --camera-off --radio --wait-radio --sprint-yard --settle-before-file --yard-flank --watch-patrol --stage-delay=6 --route=maintenance --utilities-north
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd
godot --headless --path . --script res://maps/intelligence/tools/guard_soak_k17.gd -- --reinforced
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/encounters_v4.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/redirect_v4.gd
godot --path . --script res://maps/intelligence/tools/benchmark_v4.gd
```

Tool đi bộ dùng điều khiển và giữ E thật, không dịch chuyển giữa waypoint. Mặc định chạy scene không lính để kiểm tra hình học; `--live-guards` giữ nhận thức/AI và tiếp viện thật. `--entry=maintenance` kiểm tra hướng vào hậu cần; `--route=courtyard|maintenance` chọn đường rút; bỏ `--prepare` để kiểm tra mở cửa hậu tám giây. `--yard-flank` chọn đường vòng sân và dùng radio trước lúc lấy hồ sơ. Soak tiếp viện kiểm tra riêng tuyến đường với nhận thức nhìn tạm dừng; E2E có lính kiểm tra đầy đủ nhìn/nghe/truy đuổi.

Thêm `--sabotage` để tool rẽ vào tủ, giữ E thật và chờ kết quả phá hoại. Tuyến bảo trì là tuyến khuyến nghị; đi chậm vòng qua xưởng rồi quay ra sân có thể gặp cổng đã đóng ở T+90. Đường sân vẫn nhận kết thúc phá hoại nếu tới kịp. Tool `--watch-patrol` quan sát thêm từ checkpoint trước khi tới keypad; không đổi tốc độ, tầm nhìn hay lịch lính.

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --sabotage --live-guards --crouch --prepare --camera-off --radio --wait-radio --sprint-yard --settle-before-file --yard-flank --watch-patrol --route=maintenance --utilities-north
```

`preview_sabotage.gd` dựng trạng thái để chụp tủ/hai góc kết thúc, không phải bằng chứng đi nhiệm vụ. `benchmark_sabotage.gd` đo frame time renderer thật của cảnh kết; chạy có cửa sổ, không thêm `--headless` hoặc `--fixed-fps`. Dựng lại map xong cần khởi động lại lượt chơi để tải scene mới.

Khi chạy QA có render trong nền, thêm `--background` để tool tự tiếp tục nếu cửa sổ mất focus. Thao tác giữ E bị hủy do pause được thử lại bằng một lần giữ mới. Tùy chọn này chỉ thuộc tool QA; bản chơi thường vẫn pause khi mất focus.

`--camera-off` chọn đi trạm điện trước; bỏ cờ này để thử camera hoạt động, đọc chỉ dẫn từ cạnh bàn có vật che. `--utilities-north` tiếp cận trạm điện từ cửa bắc, quan sát lính trước khi vào. `--watch-patrol` cho tool quan sát tuần tra trước khi rời vô tuyến và ở cầu thang chính khi cần. `--yard-flank` vòng phía nam chốt phản ứng thay vì đi xuyên phòng. `--sprint-exfil` chạy trong chặng rút qua sân; `--sprint-yard` chỉ chạy đoạn sân trống khi tiếp cận. Chờ trước khi phá niêm phong là một chiến thuật kiểm thử, không thay đổi AI. Thời điểm vào hành lang vẫn phụ thuộc tuần tra; một chuỗi input thắng không bảo đảm mọi cách đi đều an toàn.

`encounters_v4.gd` kiểm tra bốn tình huống với một Guard thật: hai lượt phản ứng sớm khoảng 13 m, vòng vật che rồi nấp ở vô tuyến và cắt tầm nhìn bằng vách ở B1. Fixture tắt các NPC/camera khác để tách truy đuổi; E2E nhiệm vụ giữ đầy đủ AI và lịch tiếp viện. Tuyến sân chạy nhanh có thể thắng trước T+45 nên chỉ gặp đợt một; hai cảnh vệ còn lại xuất hiện nếu người chơi còn trong nhiệm vụ ở T+45. Tuyến bảo trì đã kiểm tra với đủ mười NPC.

`redirect_v4.gd` kiểm tra đoạn đổi sang bảo trì từ khối giữa ở T+70/T+90, với camera bật, mười NPC và cửa hậu đã chuẩn bị. Tool đặt trạng thái đầu của tình huống rồi dùng input/cổng/AI thật để thoát; không thay lượt chơi toàn nhiệm vụ. Cùng tình huống chưa chuẩn bị có thể bị bắt khi giữ khóa cơ.

`preview_expansion.gd` chụp góc dàn sẵn để xem mỹ thuật, không thay bằng chứng thắng. `benchmark_v4.gd` đo thời gian thực 30 giây/góc, bốn góc và 6/8/10 NPC với camera ON/OFF. Có cờ `--seconds`, `--counts`, `--views`, `--power=on|off`, `--repeats`, `--out`; không dùng `--headless`/`--fixed-fps` cho số đo renderer.

Xem [nghiệm thu V4](docs/upgrade-v4/VALIDATION.md), [kiểm tra V3](docs/expansion-v3/VALIDATION.md) và [nguồn tài nguyên miễn phí](assets/CREDITS.md). Thời lượng lần đầu, cân bằng truy đuổi và stamina cần người chơi mới đánh giá thêm. Chưa có chiến đấu, bắn súng, leo dây hoặc xe lái được.
