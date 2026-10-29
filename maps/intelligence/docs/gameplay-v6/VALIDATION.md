# K17 V6 — Kết quả triển khai và kiểm thử

Ngày: 28/10/2026. Nhánh: `feature/twp`. Mốc nền: `98db7ed`.

**Đã triển khai và hoàn tất kiểm tra V6, gồm lượt renderer trên gói cuối.** Báo cáo đi cùng mã nguồn V6, phân biệt kiểm tra tình huống riêng, ảnh dàn cảnh và lượt chơi bằng điều khiển thật. Thiết kế ban đầu nằm trong [PLAN.md](PLAN.md).

## 1. Những phần đã có trong game

- B1 mở rộng trong khuôn viên 96 × 108 m: hành lang kiểm soát, hai hốc đỗ chữ L, phòng hồ sơ, ô kính quan sát và lối thoát nối lại hai cầu thang.
- Màn chiếu gấp có vỏ, khung, bánh xe, tay cầm và bộ điều khiển. Giữ E hai giây để dựng; E nắm/thả; WASD đẩy theo hướng xe, chuột nhìn tự do. Xe và người cùng được kiểm tra va chạm trước khi di chuyển.
- Một góc chiếu từ mắt người giữ chốt, dựng bằng SubViewport 512 × 512 ở khoảng 12,5 lần/giây. Ảnh không chứa người chơi, lính hoặc chính thiết bị.
- Một lính giữ chốt và một lính tuần tra bên hông; tổng sáu lính thường trực, tối đa bốn tiếp viện. Bốn lính còn lại giữ các khu trên mặt đất.
- Bằng chứng thiết bị tách khỏi việc nhìn thấy An. Khung/mặt sau/hình lệch khiến lính điều tra vật thể; chỉ đường nhìn thật tới cơ thể mới cập nhật vị trí An cho hệ phát hiện.
- Checkpoint B1 trước đoạn màn che. Thử lại trả thiết bị về vị trí chuẩn bị, thả tay đẩy, xóa trí nhớ bổ sung và phục hồi nhiệm vụ trước hồ sơ.
- Giữ mã kho, cảm biến, nguồn dự phòng, hai hướng tập kết, đồng hồ 120 giây và phá hoại V5. Đồng hồ bắt đầu khi giữ E lấy hồ sơ hoàn tất.
- Bản không lính dùng cùng scene/nhiệm vụ/thiết bị; hiệu chỉnh theo một mốc mắt tham chiếu, không có NPC ẩn.
- Trạng thái thiết bị đặt dưới minimap, có chữ khớp/gần lệch/lệch. Thu màn ẩn cả các vùng tương tác không còn hình ảnh; lấy hồ sơ xong nhắc bỏ thiết bị lại.
- Tiếng xe và va khung dùng Foley cơ khí sẵn có của dự án, phát ở vị trí thiết bị; tiếng xác nhận/lệch hình là tín hiệu tai nghe. Sự kiện tiếng động cho AI vẫn độc lập với âm thanh phát cho người chơi.

Ô kính cạnh cửa thoát là kính hai chiều: chặn người/lính đi qua nhưng cho cả hai bên nhìn. Người chơi có thể quan sát nhịp tuần tra trước khi phá niêm phong.

## 2. Thông số thực tế sau dựng thử

| Hạng mục | Giá trị |
| --- | --- |
| Sàn B1 phía kho/hành lang mới | 29 × 18,8 m; giữ hành lang/cầu thang bảo trì hiện có |
| Mặt chiếu | 2,2 × 2,24 m |
| Đẩy / lùi / chỉnh ngang | 0,72 / 0,50 / 0,64 m/s |
| Dựng / thu | Giữ E hai giây; nắm/thả là thao tác tức thời riêng |
| Giới hạn góc hiệu chỉnh | ±18°; báo gần lệch khi vượt khoảng 13,5° |
| Người quan sát rời vị trí tham chiếu | Quá 0,65 m thì mất hiệu chỉnh |
| Khoảng cách quá gần | Dưới 4,5 m thì mất hiệu chỉnh |
| Nhận ra thiết bị lộ | Khoảng 0,7 giây nhìn thấy liên tục trước phản ứng điều tra |
| Lấy hồ sơ / đặt thiết bị V5 | 3,5 / 5 giây |
| Rút lui | 120 giây; không cộng giờ cho phá hoại |

Giới hạn góc 12° trong kế hoạch ban đầu đã tăng thành 18°. Kiểm tra chuyển tiếp phát hiện một góc khung có thể ra khỏi vách hốc trước khi hiệu chỉnh hợp lệ trở lại. Điều chỉnh này bảo đảm lối đi chuẩn không tạo một lần bị lộ bắt buộc. Bộ kiểm tra hiện lấy mẫu cả đoạn ra khỏi hai hốc, không chỉ kiểm tra vị trí đỗ.

Khi người giữ chốt rời vùng hiệu chỉnh, ảnh giữ góc hợp lệ cuối thay vì tiếp tục bám theo người quan sát. Sau hồ sơ, khi xa thiết bị hơn 24 m hoặc khi pause, viewport không tiếp tục dựng ảnh.

## 3. Tổ chức mã nguồn

| Phần | Mã chính |
| --- | --- |
| Cấu hình dùng chung cho dựng/runtime/test | [k17_projection.gd](../../resources/layout/k17_projection.gd) |
| Dựng B1, hốc, kính và trang trí | [k17_projection_builder.gd](../../tools/k17_projection_builder.gd) |
| Thiết bị, hình chiếu, va chạm và âm thanh | [projection_rig.gd](../../scripts/projection_rig.gd), [shader](../../resources/projection_screen.gdshader) |
| Điều khiển khi đang nắm | [projection_player.gd](../../scripts/projection_player.gd), [projection_interactor.gd](../../scripts/projection_interactor.gd) |
| Điều khiển trên thiết bị | [projection_control.gd](../../scripts/projection_control.gd) |
| Vai trò giữ chốt và bằng chứng thiết bị | [projection_guard.gd](../../scripts/projection_guard.gd) |
| Checkpoint và hướng dẫn trong phòng hồ sơ | [projection_checkpoint.gd](../../scripts/projection_checkpoint.gd), [projection_room.gd](../../scripts/projection_room.gd) |

Không sửa mã điều khiển, AI hoặc HUD chung của các map khác. Các lớp K17 kế thừa nền dùng chung; AI vẫn dùng ba trạng thái PATROL/INVESTIGATE/CHASE. Phản ứng điều tra thiết bị nhận vị trí bằng chứng từ raycast, không nhận tọa độ người chơi xuyên vật che.

Thay đổi hình học nằm trong builder và cấu hình nguồn. Navigation, sơ đồ minimap và lightmap V6 đã sinh lại. Các sector không thay đổi được giữ dữ liệu cũ để giảm nhiễu khi xem diff.

## 4. Kiểm tra chức năng và hình học

| Bộ kiểm tra | Kết quả |
| --- | --- |
| Hồi quy K17: nhiệm vụ, hold, an ninh, hai chế độ, V3/V4/V5, keypad/minimap | 608 kiểm tra, không lỗi |
| V6: tương tác, đẩy, che người/thiết bị, nhìn bên, chuyển tiếp hốc, kính, pause và retry | 117 kiểm tra, không lỗi |
| Biên dịch GDScript | 239 script nạp được |
| Art/collision của map | 66 kiểm tra, không lỗi |
| Gá đỡ và điểm nối | 65 biển, 26 cụm ống, 23 tuyến dây; 237 kiểm tra, không lỗi |
| Hợp đồng HUD/map và dọn scene | Qua |
| Gói runtime, scene thường và không lính | Qua; có cả shader, Foley, kính quan sát và các điều khiển V6 |

Các fixture V6 chủ động đặt người/thiết bị ở vị trí cần kiểm tra để đo đường nhìn và trạng thái. Chúng không được tính là lượt đi bộ từ đầu map. Các kiểm tra nấp dùng tia nhìn tới người và khung thật; dấu vẽ dưới sàn không tạo khả năng tàng hình.

## 5. Lượt chơi từ đầu đến kết quả

Các lượt dưới dùng input di chuyển, tương tác/giữ E, keypad và va chạm thật. Không teleport, gán hoàn tất mục tiêu hoặc tắt AI trong lượt có lính. Driver đọc vị trí để chọn đường/thời điểm chờ; dữ liệu đó không được truyền cho AI.

| Lượt | Chế độ / đường rút | Phá hoại | Còn lại | Bị bắt | Cảm biến |
| --- | --- | --- | --- | --- | --- |
| Pha B1 0 giây | Có AI / bảo trì | Bỏ qua | 82,6 s | 0 | 0 |
| Pha B1 +4 giây | Có AI / bảo trì | Bỏ qua | 82,6 s | 0 | 0 |
| Pha B1 +9 giây | Có AI / bảo trì | Bỏ qua | 82,6 s | 0 | 0 |
| Sân | Có AI / sân | Bỏ qua | 81,9 s | 0 | 0 |
| Phá hoại | Có AI / bảo trì | Hoàn thành | 76,3 s | 0 | 0 |
| Test sân | Không lính / sân | Hoàn thành | 65,6 s | 0 | 0 |
| Test bảo trì | Không lính / bảo trì, chưa chuẩn bị chốt | Hoàn thành | 68,3 s | 0 | 0 |
| PCK + renderer | Có AI / bảo trì | Hoàn thành | 75,7 s | 0 | 1 |

Ba pha B1 bắt đầu ở vị trí tuần tra khác nhau, được trì hoãn ngay tại hốc chuẩn bị để tránh việc chờ lính ở tầng trệt vô tình đồng bộ lại pha. Cả ba vượt đủ hai hốc với **không va xe**. Trước khi lấy hồ sơ, driver quan sát lính thật qua ô kính rồi chọn lúc quay lại bàn hồ sơ.

Các lượt có AI dùng phương án ngắt camera, chuẩn bị cửa hậu và quan sát tuần tra trước khi lấy hồ sơ. Đây là những lộ trình có thể thắng đã kiểm chứng, không phải khẳng định mọi thời điểm lao qua đường trống đều an toàn. Các lượt không lính vẫn giữ cảm biến, camera, lịch báo động và thao tác mở cơ tám giây khi chưa chuẩn bị cửa hậu.

Lượt PCK chạy từ thư mục riêng với nguồn game chỉ có gói `.pck`. Driver QA và helper dọn audio nằm ngoài gói. Có renderer Compatibility, input thật, AI thật và ảnh tại các mốc. Lượt cuối dùng fixed-fps 60, VSync tắt. Có một lần chạm cảm biến rồi tiếp tục xử lý, không bị bắt và hoàn thành cả phá hoại. Bài integration PCK kiểm tra riêng việc tài liệu phát triển không được xuất vào game.

Tổng tám lượt hoàn thành trong bảng, với 1.019 waypoint và mẫu vị trí minimap tại waypoint. Không tính thêm lượt PCK trung gian đã chạy trước đợt hoàn thiện Foley vào tổng này.

## 6. Hình chiếu và hiệu năng

So sánh ở cùng vị trí mắt lính, giữ nguyên camera và cảnh, loại người/thiết bị khỏi ảnh tham chiếu hành lang trống. Vùng mặt chiếu bên trong mép có 6.240 pixel: sai lệch màu tuyệt đối trung bình **0,01050 trên thang 0–1**, khoảng **1,05%**. Bật/tắt ảnh tạo thay đổi trung bình khoảng 22,4%, nên kết quả không phải một tấm màn đã bị ẩn khỏi cả hai ảnh. Xem [số đo](projection-comparison.json).

Lỗi ảnh chiếu sáng hơn cảnh đã sửa bằng cách giữ ảnh trung gian ở tone mapping tuyến tính và áp dụng màu/filmic đúng một lần ở camera chính. Mặt chiếu cũng không nhận thêm fog lần thứ hai.

Máy đo: **Quadro P1000**, Compatibility, viewport 1280 × 720, VSync tắt. Mỗi điểm nhìn chạy OFF/ON/ON/OFF, một giây làm nóng và 2,5 giây lấy mẫu mỗi lượt. Sáu lính được giữ đứng yên giống nhau ở cả hai điều kiện.

| Điểm nhìn | Trung vị OFF | Trung vị ON | Chênh lệch |
| --- | --- | --- | --- |
| Mắt lính | 6,755 ms | 6,926 ms | +2,54% |
| Người đẩy | 4,048 ms | 4,089 ms | +1,00% |

P95 tại mắt lính dao động từ trung bình 9,691 lên 10,714 ms; tại người đẩy từ 6,286 xuống 5,946 ms. Các số là khoảng thời gian giữa frame, gồm CPU và renderer, không phải số đo GPU riêng hoặc cam kết FPS khi chơi. Kết quả trung vị đạt ngân sách tăng dưới 10% cho hiệu ứng trong các cảnh đo.

Đã kiểm tra bộ đếm cập nhật viewport không tăng khi đã lấy hồ sơ, ra xa thiết bị hoặc pause. Dữ liệu đầy đủ trong [performance.json](performance.json).

## 7. Giao diện và ảnh

Đã chụp sáu tổ hợp kích thước cửa sổ yêu cầu 1920 × 1080, 1280 × 720, 1024 × 768 ở scale 100%/125%, đồng thời bật bốn dòng phụ đề và thông báo checkpoint dài. Dự án dùng viewport logic cố định theo chế độ stretch; kích thước viewport thực và các hình chữ nhật được lưu trong [layouts.json](screens/layouts.json).

Không có giao nhau giữa khối trạng thái thiết bị với minimap/hành trang/phụ đề, hoặc giữa thông báo với minimap/trạng thái/phụ đề trong sáu cấu hình. Trạng thái thiết bị dành chỗ trong cột phải; thông báo tự giảm cỡ chữ khi vùng giữa hai cột hẹp.

- [Mặt sau thiết bị và tay đẩy](screens/02_equipment_back.png).
- [Từ mắt lính: bật hình](screens/03_guard_projection_on.png), [tắt hình](screens/04_guard_projection_off.png).
- [Ô kính quan sát và lính thật bên ngoài](screens/07b_observation_window.png).
- [HUD 125% với bốn phụ đề](screens/hud_1024x768_125.png).
- [Ảnh kết quả lượt chơi PCK](walking-packed/maintenance_03_victory.png).

Ảnh trong `screens/` là cảnh dàn kiểm tra có chủ động đặt camera. Ảnh trong `walking-packed/` được chụp trong lượt chơi bằng input thật.

## 8. Tự kiểm tra lại

Mở `project.godot` bằng Godot 4.7.2, F5 rồi chọn K17 thường hoặc K17 không lính. Dấu nhận biết là tiêu đề **K17 V6** trên HUD, hốc màn chiếu sau hai cảm biến và ô kính trong phòng hồ sơ.

Tại hốc B1: giữ E dựng, E nắm, WASD đẩy/lùi/chỉnh ngang, chuột quan sát, E thả. J hoặc pause thả xe an toàn. Shift/F chưa dùng trong khi đang nắm; thả tay trước nếu muốn ném chai. Vào hốc theo lối bên rồi đỗ sâu sau vách, không đứng ngay miệng hốc.

Các lệnh từ thư mục gốc repo, với `godot` trỏ tới binary 4.7.2:

```text
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_k17.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_projection.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_attachments.gd
godot --path . --script maps/intelligence/tools/preview_projection.gd
godot --path . --script maps/intelligence/tools/benchmark_projection.gd
```

Lượt chuẩn có AI có thể lặp bằng `playthrough_k17.gd` với các cờ trong log. Toàn bộ log nghiệm thu nằm trong `logs/`; helper dựng scene vẫn là `build_k17.gd`. Khi sửa hình học, cần sinh lại navigation/minimap và bake lại bằng [bake_v6_lightmaps.gd](../../tools/bake_v6_lightmaps.gd) trong editor Mobile/Forward+, sau đó chơi bằng Compatibility như cấu hình dự án.

## 9. Giới hạn và phần để sau

Đã kiểm chứng các tình huống và lộ trình liệt kê; chưa có nghiên cứu playtest với người mới để xác nhận mục tiêu thời lượng hoặc mức khó phù hợp mọi người. Đồ họa và âm thanh tiếp tục dùng phong cách/asset miễn phí sẵn có của dự án.

Pin, nhiều người quan sát được hiệu chỉnh đồng thời, chiến đấu, ngẫu nhiên hóa tuần tra, phòng đầu quét và khu điều phối A/B không nằm trong V6 này. Không thay đổi nội dung các map thành viên khác.
