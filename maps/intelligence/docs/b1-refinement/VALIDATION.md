# K17 V6 B1 — Triển khai và kiểm thử

Ngày: 28/10/2026. Nhánh: `feature/twp`. Mốc nền: `73e59e4`.

Đã triển khai [kế hoạch hoàn thiện B1](../gameplay-v6/B1_REFINEMENT_PLAN.md), cập nhật đồng thời bản thường và bản không lính. Các kết quả dưới đây được chạy lại cho B1 mới; số của [V6 trước đó](../gameplay-v6/VALIDATION.md) chỉ giữ làm lịch sử. Chỉ thay đổi trong `maps/intelligence/`.

## 1. Luồng chơi hiện hành

1. Lấy thẻ/chỉ dẫn, mở kho bằng keypad như trước. Cả cầu thang chính, cầu thang bảo trì và làn tuần tra đều nhập vào sảnh **trước S1**. Hai dải cảm biến phủ kín lối đi.
2. Giữ E **3 giây** ở bảng B1 để chiếm kênh. Dựng màn bằng giữ E **2 giây**, E nắm/thả, WASD đẩy theo hướng xe; chuột nhìn tự do. Xe có hỗ trợ giữ tâm khi đã đi thẳng giữa hành lang, vẫn kiểm tra va chạm của cả xe và người.
3. **V** chuyển camera trước → C1 trên chốt → ẩn. Đây là cảnh thật có người/lính/thiết bị, tách khỏi ảnh hành lang trống dùng chiếu ngụy trang. **R** gửi yêu cầu kiểm tra giả; chỉ chuyển ngang khi chốt thực sự quay sang máy và tuần tra bên hông đã đi khỏi ô cần qua.
4. Hai hốc chữ L che thật cả người và xe. Chốt có nhịp kiểm tra tự nhiên; cuộc gọi không làm tuần tra mất cảnh giác, xóa truy đuổi hoặc giảm thị giác/thính giác AI.
5. **Đẩy màn vượt toàn bộ cửa hồ sơ**, tới dấu dừng cách chốt 10 m. Thả tay, giữ E **6 giây** ở đầu đọc trụ trái để mở cửa. Cửa trượt lên, đầu đọc giữ trên tường; người chơi vào từ phía sau màn. Mở khóa chưa chạy đồng hồ.
6. Giữ E **3,5 giây** lấy hồ sơ mới bắt đầu 120 giây. Quyền CCTV/cuộc gọi bị thu hồi. Quay ra **chính cửa vừa vào**, trở về sảnh cảm biến rồi chọn sân hoặc bảo trì. Cửa sau hồ sơ và các lối tắt theo FILE cũ đã bỏ, bịt bằng tường thật.
7. Có thể bỏ màn lại. Chốt tới gần mới thu và gạt khung chắn đường bằng chuyển động có va chạm; thiết bị không biến mất hoặc mất collider. Người chơi vẫn được thao tác thu/dựng/nắm sau FILE khi đủ khoảng trống. Phá hoại V5 vẫn tùy chọn và dùng chung 120 giây.

Mạch B1 dùng nguồn nội bộ riêng. Tắt ba camera mặt đất không tắt C1; trước hack và sau thu hồi, C1 phát hiện người theo đường nhìn thật và phản ánh lên HUD. C1 không nhìn xuyên màn. Góc C1 khác mắt chốt nên không dùng hình C1 làm chứng cứ tuyệt đối về độ khớp.

## 2. Thông số sau dựng thử

| Hạng mục | Giá trị cuối |
| --- | --- |
| Sàn B1 mới | 38 × 18,8 m, giữ khuôn viên 96 × 108 m |
| Hành lang / mặt màn | 2,60 m / 2,60 × 2,50 m; mép mềm che khe bên |
| Khối va chạm màn | Rộng 2,50 m, cao 2,46 m |
| Đẩy / lùi / chỉnh ngang | 0,85 / 0,85 / 0,90 m/s |
| Điểm dừng / chốt | `(-16.5, -4, -47)` / `(-26.5, -4, -47)` |
| Cửa hồ sơ | Tâm x = −14; miệng cửa từ x = −15,5 tới −12,5 |
| Đỗ hốc 1 / hốc 2 | `(-2.3, -4, -50.05)` / `(-11.8, -4, -50.05)` |
| W1 / W2 | x = −3 / −10,2; kính chặn di chuyển, cho nhìn hai chiều |
| Chốt kiểm tra tự nhiên | 9,5 giây sau mỗi 30 giây quan sát bình thường |
| Yêu cầu giả | Trễ 1,5 giây; kiểm tra 10 giây; hồi 25 giây |
| Chống lặp | Hai lượt được nhận trong 60 giây; yêu cầu tiếp theo bị đối chiếu 45 giây, rồi dùng lại |
| Feed quan sát | Một viewport 480 × 270, 10 lần/giây; chỉ render góc đang chọn |
| Ảnh ngụy trang | Viewport riêng 512 × 512, khoảng 12,5 lần/giây |
| Lính | Sáu thường trực; tối đa bốn tiếp viện; không tăng so với V6 |

Miệng hốc và dấu đỗ đã dời sau đo chuyển tiếp. Một lượt vào/ra hốc mất khoảng **6,3–7 giây** bằng input thật; lúc thân chốt đã quay đi, cửa sổ còn khoảng **9,25 giây**, đủ trên hai giây dự phòng cho chuyển tiếp chuẩn. Các lượt đi bộ trong báo cáo có **0 lần va xe**. Chưa khẳng định mọi góc rẽ hoặc thời điểm bắt đầu đều an toàn.

## 3. Kiểm tra tự động

| Bộ kiểm tra | Kết quả mới |
| --- | --- |
| Nhiệm vụ / giữ E / an ninh / không lính / mở rộng / V4 / V5 / navigation | 129 + 19 + 45 + 36 + 42 + 128 + 78 + 133 = **610**, không lỗi |
| Nền màn chiếu V6, cập nhật theo B1 mới | **118**, không lỗi |
| B1: đường vòng, hốc, cuộc gọi, C1, khóa, vật cản và reset | **54**, không lỗi |
| Mỹ thuật và collision | **66**, không lỗi |
| Gá đỡ / điểm nối | **239**, không lỗi; 64 biển, 26 cụm ống, 25 tuyến dây |
| Biên dịch | **245 script** nạp được |
| Hợp đồng map/HUD, dọn scene | Qua |
| Giao diện hai feed | **12** tổ hợp feed/kích thước/scale, không chồng khối được kiểm tra |
| PCK thường và không lính | Qua: tài nguyên, điều khiển, ánh sáng, minimap, tiếp viện, reset và kết thúc |

Tổng **1.087 phép kiểm tra chức năng/hình học** trong năm nhóm đầu. Không cộng số script, kiểm tra bố cục hoặc waypoint vào tổng này. [Log](logs/) lưu riêng từng nhóm.

Fixture đặt actor ở vị trí cần đo, không tính là lượt chơi. Kiểm tra hốc dùng tia nhìn thật tới khung và các điểm cơ thể, gồm sai lệch 0,31 m của vị trí sau tay đẩy. Kiểm tra chuyển hướng chốt không tắt mắt lính. Khóa được thử bằng giữ E thật, nhả sớm và ray tương tác từ hành lang; mở khóa không cộng FILE hoặc chạy timer. C1 được thử cả bị màn chắn, người bước ra trước màn, quyền đã hack và thu hồi.

Navigation và minimap đã sinh lại từ builder. Ánh sáng V6 được bake lại với renderer Mobile rồi chạy bằng Compatibility. Bảng/ống/máng dây được chuyển theo tường mới; nguồn dựng giữ trong builder để không mất khi tái tạo map.

## 4. Lượt chơi từ đầu tới kết quả

Driver dùng điều khiển, keypad, giữ E và va chạm thật. Lượt có lính giữ nhận thức/AI và lịch tiếp viện; không teleport, gán mục tiêu hoàn thành hay tắt cảm biến. Driver đọc vị trí/nhịp tuần tra để chọn thời điểm chờ, không truyền tọa độ người chơi cho AI.

| Lượt | Cách qua chốt / đường rút | Phá hoại | Còn lại | Bị bắt | Cảm biến | Tiếp viện |
| --- | --- | --- | --- | --- | --- | --- |
| AI, pha B1 0 s | Cuộc gọi / bảo trì đã chuẩn bị | Bỏ qua | 68,6 s | 0 | 1 | 4 |
| AI, nhịp tự nhiên | Không gọi chốt / sân | Bỏ qua | 72,0 s | 0 | 1 | 3 |
| AI, pha B1 +9 s | Cuộc gọi / bảo trì đã chuẩn bị | Hoàn thành | 62,3 s | 0 | 1 | 4 |
| AI, pha B1 +4 s | Cuộc gọi / bảo trì **chưa chuẩn bị**, mở cơ 8 s | Bỏ qua | 58,3 s | 0 | 1 | 4 |
| Không lính | Sân, cửa hậu chưa chuẩn bị | Hoàn thành | 52,3 s | 0 | 0 | 0 |
| Không lính | Bảo trì, cửa hậu chưa chuẩn bị | Hoàn thành | 55,0 s | 0 | 0 | 0 |
| PCK + renderer | Cuộc gọi / bảo trì đã chuẩn bị, pha B1 +9 s | Hoàn thành | 59,8 s | 0 | 1 | 4 |

Tổng **bảy lượt thắng**, **887 waypoint và mẫu vị trí minimap**. Các pha 0/4/9 giây trì hoãn ngay tại điểm chuẩn bị B1. Lượt nhịp tự nhiên xác nhận không bắt buộc sử dụng cuộc gọi. Những lượt có AI đều chọn ngắt camera mặt đất trước và đi nhẹ trong B1, chạy khi lên mặt đất. Kết quả không có nghĩa người chơi mới sẽ hoàn thành với cùng thời gian.

Lượt AI có một lần chạm cảm biến vẫn hoàn thành; không trình bày là lượt tàng hình tuyệt đối. Trước khi lấy hồ sơ, driver chờ tiếng bước chân tuần tra rời W2. Lịch tiếp viện giữ nguyên; lượt sân tới tập kết khi actor cuối đợt hai chưa được điều động, nên ghi nhận ba thay vì bốn tiếp viện.

PCK chạy từ thư mục riêng, nguồn game chỉ có gói; driver QA/helper nằm ngoài gói. Compatibility, fixed-fps 60, VSync tắt, cửa sổ 1280 × 720. Công cụ QA có thể tiếp tục sau mất focus và nhấn E nắm lại tay đẩy; bản chơi thường vẫn pause/thả tay như trước. [Ảnh thắng từ lượt PCK](walking-packed/maintenance_03_victory.png), [ảnh lấy hồ sơ](walking-packed/maintenance_02_file.png), [ảnh đặt thiết bị](walking-packed/maintenance_02b_armed.png).

Thông tin gói kiểm tra: [pack.json](pack.json). Gói lớn không đưa vào Git; tạo lại bằng lệnh trong [COMMANDS.md](COMMANDS.md). Bộ kiểm tra xác nhận tài liệu/tools/tests không nằm trong bản xuất.

## 5. Hình ảnh và hiệu năng

Ảnh dàn cảnh từ renderer thật: [mặt bằng bỏ trần](screens/09_floor_plan.png), [camera trước](screens/03_front_feed.png), [C1 trên HUD](screens/04_c1_feed.png), [mắt chốt](screens/05_post_projection.png), [W1 nhìn về hốc](screens/10_w1_hidden_bay.png), [W2 nhìn về hốc](screens/10_w2_hidden_bay.png), [góc C1 thực](screens/11_c1_actual_view.png), [khóa trên trụ cửa](screens/07_archive_lock.png), [cửa mở](screens/08_archive_open.png). Các ảnh này minh họa bố trí, không thay bằng chứng đi bộ.

Hai feed được kiểm tra tại kích thước cửa sổ yêu cầu 1920 × 1080, 1280 × 720 và 1024 × 768, scale 100%/125%. Dự án dùng stretch; viewport logic thực ghi trong [layouts.json](screens/layouts.json). Không có giao nhau với các khối HUD được đo hoặc tràn viewport. Chưa thay bằng thử nghiệm khả năng đọc chữ với người chơi mới.

Đo renderer trên **Quadro P1000**, Compatibility, 1280 × 720, VSync tắt. Sáu actor giữ đứng yên; mỗi mẫu một giây làm nóng và 2,5 giây lấy số. Đây là khoảng thời gian giữa frame gồm CPU/renderer, không phải GPU timing riêng hoặc cam kết FPS. Dữ liệu lần cuối lưu trong [performance.json](performance.json); phần hình chiếu có dao động lớn giữa hai lượt ON, nên chưa coi đây là số đo ổn định để xác nhận ngân sách dưới 10% cho toàn bộ hiệu ứng.

Viewport quan sát mới chạy riêng theo thứ tự OFF/trước/C1/OFF: trung vị OFF **4,895 / 4,666 ms**, camera trước **4,760 ms**, C1 **4,835 ms**. So với trung bình hai OFF, chênh lệch lần lượt khoảng **−0,4% / +1,1%**. Đã xác nhận viewport ảnh ngụy trang ngừng cập nhật sau FILE, khi ở xa và khi pause. Khi ẩn/mất quyền, feed quan sát tắt và không giữ ảnh cũ giả là trực tiếp.

So sánh ảnh cùng mắt chốt, loại actor, trên 2.254 pixel trong mặt màn: sai lệch màu tuyệt đối trung bình khoảng **0,0142/1**, tức 1,42%; khác biệt ON/OFF khoảng 14,1%. [Số đo](projection-comparison.json), [ảnh tham chiếu](screens/projection_reference.png), [ảnh có màn chiếu](screens/projection_matched.png). Không chuyển con số này thành “độ chính xác” thị giác hoặc áp dụng cho mọi góc C1/W1/W2.

## 6. Tự chơi và phần để sau

Đóng lượt game cũ rồi mở lại dự án, F5 → **K17 — 120 giây cuối**, hoặc chọn **Test map không lính gác**. Khối trạng thái phải có chữ **K17 V6 B1**. Không cần plugin khi chơi. [README](../../README.md) có luồng chơi và phím điều khiển; [COMMANDS.md](COMMANDS.md) có lệnh lặp kiểm thử.

C2 trần, pin, chiến đấu, ngẫu nhiên hóa tuần tra và mở rộng khu mặt đất chưa làm trong B1. Cần playtest với người mới để đánh giá độ khó, khả năng nhận ra nhịp chốt/W1/W2 và thời lượng chờ. Cần lượt đo hiệu năng dài hơn trong điều kiện ổn định trước khi cam kết ngân sách của toàn bộ hình chiếu. Các nhiệm vụ, AI/điều khiển chung và map của thành viên khác giữ nguyên.
