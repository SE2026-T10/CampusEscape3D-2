# K17 V5 — Kế hoạch nhiệm vụ phá hoại tùy chọn

Ngày lập: 27/10/2026. Mốc đối chiếu: `2b4c84b` trên nhánh `feature/twp`.

**Trạng thái: đã triển khai Sabotage V1 trên `feature/twp`.** Xem [nghiệm thu và giới hạn thực tế](VALIDATION.md). Phần dưới giữ kế hoạch thiết kế ban đầu cho phần mở rộng phá hoại, nối tiếp K17 V4; các ngân sách thời gian/vị trí dự kiến không thay thế số đo trong báo cáo nghiệm thu.

## 1. Mục tiêu và phạm vi

Sau khi lấy **Mật lệnh 04**, người chơi có thể nhận thêm rủi ro: ghé cụm thiết bị tình báo dự phòng, đặt thiết bị phá hủy rồi rút về điểm tập kết trước khi hết 120 giây. Khi đã thoát an toàn, thiết bị kích hoạt và xuất hiện đoạn kết phá hoại.

Nhiệm vụ bắt buộc vẫn là **lấy hồ sơ và thoát khỏi K17**. Người bỏ qua mục tiêu phụ vẫn hoàn thành nhiệm vụ bình thường. Đây là lựa chọn trong cùng lượt chơi; không cần thêm một chế độ khó hoặc một màn chơi riêng.

### Phạm vi chốt cho Sabotage V1

- Một cụm mục tiêu cố định, có công năng rõ ràng và mô hình nguyên vẹn/hư hại.
- Một thiết bị nhiệm vụ được cấp sẵn, không chiếm ba ô hành trang hiện tại.
- Chỉ cho phép đặt sau khi lấy hồ sơ; giữ E liên tục **5 giây** tại vị trí quy định.
- Dùng đồng hồ rút lui **120 giây hiện có**; không cộng giờ khi bắt đầu hoặc đặt xong.
- Đã đặt thiết bị vẫn phải thoát hợp lệ. Bị bắt hoặc hết giờ trước khi thoát là thất bại của lượt đó.
- Thiết bị chỉ kích hoạt sau khi game xác nhận người chơi đã tới tập kết an toàn.
- Hai kết thúc thành công: thu hồi hồ sơ; thu hồi hồ sơ kèm phá hủy cụm thiết bị.
- Giữ cả hai đường rút hiện hành, chế độ không lính và cơ chế checkpoint.

### Để các đợt sau

Chưa đưa vào V1: nhiều điểm đặt, nhặt vật liệu/chế tạo, ném bom tự do, sát thương chiến đấu, đặt giờ nổ giữa lượt, phá tường mở đường, sập cả tòa nhà, mô phỏng mảnh vỡ vật lý hoặc xây lại navmesh trong lúc chơi. Nhánh phá hoại V1 tạo đoạn cao trào và phần thưởng kể chuyện; không bổ sung hệ thống chiến đấu mới.

## 2. Cốt truyện và trải nghiệm mong muốn

An đã tìm được Mật lệnh 04, nhưng cơ sở còn một **cụm chuyển tiếp và lưu trữ tình báo dự phòng** trong khu kỹ thuật. Lam thông báo có thể vô hiệu hóa cụm này để cắt khả năng phục hồi dữ liệu và liên lạc của địch. Quyết định thuộc về người chơi: ưu tiên đưa hồ sơ ra ngoài, hoặc đánh đổi thời gian và nguy cơ bị phát hiện để hoàn thành thêm mục tiêu.

Nhịp chơi dự kiến:

1. **Nhận biết trước:** lúc chuẩn bị, người chơi có thể nhìn thấy thiết bị và biển công năng tại khu kỹ thuật. Nhật ký ghi nhớ vị trí, nhưng chưa cho đặt.
2. **Báo động:** lấy hồ sơ, bắt đầu 120 giây và lịch an ninh hiện có.
3. **Ra quyết định:** Lam nhắc ngắn rằng mục tiêu phụ nằm gần tuyến bảo trì. Cảnh báo hết giờ/đóng cổng được ưu tiên cao hơn lời giới thiệu này.
4. **Tiếp cận:** quan sát lính và camera, chọn lúc vượt qua đoạn trống vào hốc thiết bị.
5. **Căng thẳng tại chỗ:** giữ E trong 5 giây. Người chơi vẫn có thể bị phát hiện và bắt trong thời gian đó.
6. **Rút lui:** đèn trạng thái trên thiết bị đổi màu; Lam nhắc tiếp tục tới tập kết. Đồng hồ không dừng và không có thêm đếm ngược nổ.
7. **Giải tỏa:** đến tập kết hợp lệ, chuyển sang một góc nhìn ngắn hướng về khu kỹ thuật; thiết bị phát nổ, khói thoát lên vị trí thông gió/mái đã bố trí, sau đó hiện kết quả.

Không yêu cầu người chơi đứng lại bên thiết bị để chứng kiến vụ nổ hoặc quay trở vào cơ sở. Cảm giác kịch tính đến từ lựa chọn và chặng rút lui dưới áp lực, còn vụ nổ là phần kết xác nhận thành quả.

## 3. Bố trí mục tiêu trên bản đồ

### Vị trí đề xuất

Đặt **một hốc thiết bị ở rìa khu trạm điện/xưởng, gần tuyến dịch vụ dẫn ra cửa hậu phía đông**. Cụm này đại diện cho thiết bị thông tin dự phòng, không phải chính công tắc camera hoặc chốt cửa hậu đang dùng.

Chưa chốt tọa độ khi chưa dựng thử. Vị trí cụ thể phải vượt qua kiểm tra hình học và lượt đi bộ; không lấy một tọa độ thuận tiện trong mã làm bằng chứng rằng vị trí đã hợp lý.

### Yêu cầu bố cục

- Từ tuyến bảo trì có thể nhận ra biển và mặt tủ khi tiếp cận; tránh đặt sâu vào một phòng mới khiến người chơi phải đi vòng xa.
- Tủ có bệ/chân chạm sàn; bảng và đèn có gá gắn vào tủ hoặc tường. Dây/máng nối có đầu kết thúc hợp lý. Không thêm biển, ống hoặc thiết bị treo giữa không trung.
- Có khe tiếp cận mặt tủ trong tầm tương tác 2,2 m hiện tại, không bị collider của chính tủ chặn tia tương tác.
- Không đặt vùng E chồng lên chốt cửa hậu, bảng điện, radio hoặc cửa. Hai mục tiêu ở gần nhau vẫn phải chọn được riêng bằng hướng nhìn.
- Không chắn cửa bắc/nam, ngưỡng cổng, đường tuần tra, đường chạy hoặc điểm xuất hiện tiếp viện.
- Có vật che thật khi tiếp cận, nhưng mặt thao tác vẫn có một hướng bị quan sát. Không tạo một vùng đứng được gắn nhãn “an toàn” giữa lối đi.
- Không đổi tuyến chuẩn bị cửa hậu: người chơi vẫn có thể tới chốt trước khi lấy hồ sơ.
- Có điểm bố trí khói và góc máy kết thúc phù hợp với kiến trúc thật. Nếu từ tập kết không thấy mặt tủ, góc máy nhìn mái/khu kỹ thuật; không cho hiệu ứng xuyên tường để người chơi thấy vụ nổ.

### Mẫu trang trí

Cụm mục tiêu gồm tủ thiết bị liên lạc/lưu trữ, bảng công năng, đèn hoạt động, dây dẫn và một giá đặt thiết bị nhiệm vụ. Tái sử dụng vật liệu quân sự/công nghiệp và tài nguyên miễn phí đã có trước. Tài nguyên bổ sung phải có nguồn và giấy phép ghi trong `assets/CREDITS.md` của map.

Chỉ trang trí phần phục vụ công năng của hốc này. Không mở rộng diện tích bản đồ trong cùng đợt V5, để tách việc cân bằng cơ chế mới khỏi việc thay đổi toàn bộ đường đi.

## 4. Luật nhiệm vụ và tương tác

### 4.1. Mục tiêu trong ObjectiveManager

Thêm **một** mục tiêu phụ `sabotage_k17`, yêu cầu `take_intelligence` đã hoàn thành. Mục tiêu này chỉ được đánh dấu hoàn thành khi sự kiện phá hủy đã được xử lý sau khi thoát, **không phải khi đặt xong**.

Sau thay đổi, đồ thị có **7 mục tiêu bắt buộc và 3 mục tiêu tùy chọn**. Hai mục tiêu phụ cũ vẫn giữ nguyên. `extract_k17` chỉ phụ thuộc việc lấy hồ sơ; không được thêm phụ thuộc vào `sabotage_k17`.

Có thể cho biết mục tiêu phụ từ phần giới thiệu/nhật ký trước khi lấy hồ sơ, nhưng phải hiển thị điều kiện “Sau khi thu hồi hồ sơ”. Không thêm trạng thái `SKIPPED` vào ObjectiveManager chung; nếu người chơi bỏ qua, mục tiêu phụ giữ trạng thái chưa hoàn thành và màn kết quả giải thích rõ.

### 4.2. Thiết bị nhiệm vụ

- Người chơi có một thiết bị nhiệm vụ từ đầu, quản lý bằng trạng thái riêng K17.
- Không cần tìm thêm, chọn ô đồ hoặc đổi phím F đang dùng ném chai.
- Không làm mất thẻ thông hành hoặc chai trong hành trang.
- Chỉ tiêu hao khi hoàn tất lần giữ E hợp lệ. Bắt đầu rồi hủy không tiêu hao thiết bị.
- Không đặt lại lần hai, không nhặt lại thiết bị đã đặt trong V1.
- Không cho đặt trước khi lấy hồ sơ, khi hết giờ, đang pause, bị bắt, đang rời scene hoặc đã xác nhận thoát.

### 4.3. Thao tác giữ E

Dùng lại `Interactable.hold_duration` và PlayerInteractor hiện tại, không viết một thanh giữ phím riêng.

| Tình huống | Kết quả cần có |
|---|---|
| Nhìn đúng mặt tủ, đủ điều kiện, giữ E đủ 5 giây | Đặt thành công một lần, hiện thiết bị trên giá, chuyển sang đã đặt |
| Nhả E, nhìn sang vật khác, bị vật cản che hoặc rời tầm | Hủy tiến trình; lần sau giữ lại từ đầu |
| Pause/mất focus khi đang đặt | Hủy thao tác như tương tác hiện tại; resume không tự hoàn tất |
| Bị bắt/hết giờ trong lúc đặt | Không đặt thành công; đi theo luồng thất bại/checkpoint |
| Giữ E sau khi đã đặt hoặc nhấn liên tục | Chỉ hiện trạng thái đã đặt; không tạo thêm thiết bị hoặc sự kiện |
| Còn thời gian rất ít | Vẫn theo điều kiện thật; không miễn kiểm tra thời hạn hoặc miễn bị bắt |

Thao tác đặt không cho bất tử, không tự tắt camera, không làm lính quên người chơi và không gọi thêm một đợt lính ngoài lịch hiện có. Âm thanh thao tác nhỏ phục vụ phản hồi; V1 không thêm một nguồn NoiseSystem mới làm thay đổi cân bằng nghe của AI. Sau khi đặt, lịch nguồn dự phòng và cổng vẫn tiếp tục như cũ.

## 5. Đồng hồ, độ khó và đường rút

Giữ đồng hồ duy nhất: **120 giây tính từ lúc lấy xong hồ sơ**. Thiết bị không có đồng hồ nổ độc lập; việc kích hoạt sau xác nhận tập kết cần được nói rõ để tránh hiểu rằng người chơi có thêm thời gian.

| Mốc từ lúc lấy hồ sơ | Sự kiện được giữ |
|---|---|
| T+0 | Bắt đầu đồng hồ, còi/đèn báo động và khóa cơ cửa hậu |
| T+10 | Đợt một, hai cảnh vệ |
| T+15 | Nguồn dự phòng cấp lại camera |
| T+45 | Đợt hai, hai cảnh vệ; tối đa mười NPC |
| T+70 | Cảnh báo sắp đóng cổng sân |
| T+90 | Cổng sân nhận lệnh đóng |
| T+100 | Thông báo tăng kiểm soát chốt đông, không phải một đợt spawn mới |
| T+120 | Thất bại nếu chưa xác nhận thoát hợp lệ |

### Ngân sách thời gian đề xuất

Lượt có lính qua bảo trì trong [nghiệm thu gần nhất](../attachments-v4/VALIDATION.md) còn **41,9 giây**, tương đương khoảng **78,1 giây** rút lui. Đây là một lượt đi đã biết đường, mô phỏng headless 60 Hz; không đại diện cho người chơi lần đầu và không phải số đo FPS.

Mục tiêu thiết kế cho nhánh phá hoại, tính phần tăng thêm so với cùng đường rút không phá hoại:

| Thành phần | Ngân sách dự kiến |
|---|---|
| Rẽ vào mục tiêu rồi quay lại tuyến | 5–10 giây |
| Giữ E | 5 giây |
| Quan sát/chờ một nhịp an toàn | 5–10 giây |
| Tổng tăng thêm | **15–25 giây** |

Với mốc hiện tại, tổng dự kiến khoảng **93–103 giây**; dùng khoảng **90–110 giây** làm mục tiêu cân bằng cho lượt thành công đã biết đường. Không coi phép cộng này là kết quả E2E. Chờ lính, bị truy đuổi hoặc chưa chuẩn bị cửa hậu có thể làm tăng thời gian đáng kể.

Các quyết định cân bằng:

- Tuyến bảo trì là tuyến được ưu tiên khi làm mục tiêu phụ. Chuẩn bị chốt trước đem lại lợi thế thật: mở ngay thay vì giữ E tám giây.
- Chưa chuẩn bị vẫn được thử đặt, có thể bỏ thao tác và tiếp tục rút. Phải đo riêng trường hợp này; không cam kết mọi chiến thuật đều kịp.
- Cả hai điểm tập kết đều nhận kết thúc phá hoại nếu đã đặt và còn thời gian. Không cam kết phá hoại rồi quay ra sân luôn là đường khả thi dưới T+90.
- Không ép người chơi chọn đường sân đã đóng. Hướng dẫn/radio phải cho biết đường bảo trì còn dùng được.
- Nếu nhánh phụ quá khó vì đường vòng, sửa vị trí và góc tiếp cận trước; không âm thầm giảm AI, kéo dài 120 giây hoặc cho bỏ qua collider.
- Đo ít nhất ba lượt thành công qua bảo trì với đầy đủ AI, báo cáo cả lượt thất bại. Chơi thử với 3–5 người chưa biết đường là bước đánh giá độ dễ hiểu/độ khó, không thay bằng tool thuộc waypoint.

## 6. Trạng thái và xử lý kết thúc

### 6.1. Trạng thái phá hoại

| Trạng thái | Điều kiện và biểu hiện |
|---|---|
| `LOCKED` | Chưa lấy hồ sơ; chỉ xem thông tin mục tiêu |
| `AVAILABLE` | Đã lấy hồ sơ, còn thời gian, chưa đặt |
| `PLANTING` | Tiến trình giữ E do PlayerInteractor quản lý; không lưu checkpoint |
| `ARMED` | Giữ E hoàn tất; thiết bị đã đặt, chờ thoát hợp lệ |
| `DETONATED` | Sự kiện phá hủy sau xác nhận thoát đã được xử lý một lần |

`PLANTING` là trạng thái biểu diễn lấy từ thao tác đang giữ, không phải bộ đếm thứ hai chạy song song. Hủy quay về `AVAILABLE`. Bị bắt/hết giờ trước tập kết không chuyển sang `DETONATED`.

Điều phối nhiệm vụ riêng K17 đi theo các pha:

```text
INFILTRATION -> ESCAPE -> EXTRACTION_COMMITTED -> FINALE -> COMPLETE
                   |               |
                   |               +-- không đặt: hoàn tất kết quả thường
                   +-- bị bắt/hết giờ: thử lại checkpoint hoặc rời màn
```

`EXTRACTION_COMMITTED` nghĩa là điểm thoát đã được chấp nhận và chặng chơi có rủi ro đã kết thúc. Cảnh phá hủy không phải khoảng thời gian người chơi còn phải chạy hoặc còn có thể bị bắt.

### 6.2. Vì sao phải sửa luồng thoát hiện tại

Hiện tại [mission_controller.gd](../../scripts/mission_controller.gd) gọi `finish_level()` và hoàn thành `extract_k17` ngay trong `try_extract()`. ObjectiveManager phát `level_completed`, GameFlow mở WIN ngay. Nếu chỉ ghép hiệu ứng vào sau, bảng kết quả sẽ che vụ nổ và một số bộ điều khiển vẫn có thể chạy sai thời điểm.

Kế hoạch là điều phối bằng trạng thái cục bộ K17, dùng GameFlow chung cho pause/menu/WIN như hiện tại; không thêm trạng thái cinematic vào hệ thống dùng chung chỉ để phục vụ map này.

### 6.3. Thứ tự xác nhận thoát

1. Kiểm tra GameFlow đang PLAYING, chưa rời scene, có hồ sơ, còn thời gian, chưa bị bắt và chưa xác nhận thoát. Mục tiêu bắt buộc hiện hành phải là `extract_k17`.
2. Giữ quy tắc hiện có: cập nhật thời hạn trước Area3D tập kết trong cùng physics tick. Nếu thời gian đã về 0 thì thất bại; không đổi thành thắng nhờ callback tới sau.
3. Chốt một lần `extraction_committed`, tuyến rút, thời gian còn lại, thời gian chơi và các số liệu dùng cho kết quả. Hủy thao tác E còn dở.
4. Dừng đồng hồ/radio lịch nhiệm vụ, tắt tương tác và gọi `finish_level()` để đóng băng người chơi/lính, ngăn bị bắt tiếp.
5. Chặn riêng các bộ điều phối K17: không spawn tiếp viện, không chuyển nguồn/cổng và không phát thông báo gameplay mới sau khi chốt thoát. Chỉ đóng băng actor chưa đủ vì Reinforcements/PowerNetwork vẫn là node riêng.
6. Nếu chưa đặt: hoàn thành `extract_k17` và mở kết quả thường như hiện tại.
7. Nếu đã đặt: chạy finale; xử lý sự kiện phá hủy một lần, cập nhật mô hình hư hại, hoàn thành `sabotage_k17`, rồi mới hoàn thành `extract_k17` để mở WIN.

[extraction_zone.gd](../../scripts/extraction_zone.gd) đang thử thoát mỗi physics tick khi người chơi ở trong vùng. Cờ chốt thoát phải ngăn việc ghi tuyến nhiều lần, tạo nhiều finale hoặc hoàn thành mục tiêu lặp.

### 6.4. Tính nhất quán khi pause, bỏ qua hoặc lỗi hiệu ứng

- GameFlow vẫn hỗ trợ Esc/P và mất focus để pause. Finale, tween, âm thanh và thời gian chờ của finale phải cùng dừng; resume tiếp tục đúng chỗ.
- Sau ít nhất 0,5 giây, cho **nhấn Enter mới để bỏ qua** cảnh. Nhận và tiêu thụ sự kiện phím để nó không kích hoạt nút Chơi lại trên bảng kết quả vừa xuất hiện.
- Bỏ qua vẫn đi qua cùng hàm chốt phá hủy và kết quả, không tạo một nhánh đánh dấu thắng riêng.
- Sự kiện phá hủy do logic nhiệm vụ quyết định; hạt khói/animation/âm thanh là phần trình bày. Không đợi tín hiệu kết thúc particle mới ghi thành tích.
- Nếu scene VFX/âm thanh/góc máy thiếu, thực hiện sự kiện phá hủy hợp lệ, áp dụng trạng thái hư hại nếu có, hiện thông báo ngắn và chốt kết quả. Không treo lượt chơi vì hiệu ứng lỗi.
- Có giới hạn chờ finale theo thời gian chơi không pause, dự kiến tối đa **6 giây**, và một đường hoàn tất dùng chung. Không có callback nào được chốt kết quả lần hai.
- Restart/về menu hủy finale, âm thanh, tween và callback đang chờ bằng mã lượt; callback từ scene/lượt cũ không được sửa lượt mới.
- Không dùng `GameFlow.play_time` đang tiếp tục tăng trong finale làm số liệu chặng chơi. Chụp thời gian tại tập kết; phần menu kết quả riêng K17 đọc số đã chụp. Không ghi lùi đồng hồ chung để che thời lượng cinematic.

## 7. HUD, lời thoại và hai đoạn kết

### Trong lượt chơi

- Nhật ký/giới thiệu: “Mục tiêu phụ: vô hiệu hóa cụm tình báo dự phòng. Chỉ thực hiện sau khi thu hồi hồ sơ; hồ sơ phải được đưa ra ngoài trước khi hết giờ.”
- Nhìn tủ trước khi có hồ sơ: “Thiết bị tình báo dự phòng — thu hồi hồ sơ trước.” Nếu tia tương tác vẫn nhận mục tiêu khóa, lời nhắc phải giải thích điều kiện, tránh tạo cảm giác nhấn E bị lỗi.
- Đủ điều kiện: dùng prompt có sẵn, dạng “[E] Giữ 5,0 giây · Đặt thiết bị phá hủy”. Thanh giữ E hiện trong HUD chung.
- Đã đặt: “Đã đặt thiết bị — rút tới điểm tập kết”. Không hiện dấu hoàn thành phá hoại ở bước này.
- Thêm tối đa một dòng trạng thái ngắn: “Phá hoại: tùy chọn / đã đặt / hoàn tất”. Không mở popup hoặc bắt xác nhận khi đồng hồ đang chạy.
- Không thêm bản đồ chỉ đường toàn màn hình, đồng hồ nổ thứ hai hoặc biểu tượng nhìn xuyên tường trong đợt đầu.
- Hàng đợi radio dùng ưu tiên và chống lặp hiện có. Giới thiệu mục tiêu phụ không che cảnh báo T+70, T+90 và nguồn dự phòng.

### Kết thúc thường

“Đã thu hồi Mật lệnh 04.” Hiện tuyến rút và thời gian còn lại tại lúc tập kết. Dòng phụ: “Phá hoại: chưa thực hiện.” Người chơi vẫn thắng; không gọi đây là một nhiệm vụ thất bại hoặc tự giảm hạng khi chưa có hệ thống xếp hạng.

### Kết thúc phá hoại

“Đã thu hồi Mật lệnh 04 và phá hủy cụm tình báo dự phòng.” Thêm xác nhận mục tiêu phụ hoàn tất; giữ số liệu tuyến rút, thời gian, số lần bị bắt/hết giờ và hai mục tiêu chuẩn bị cũ.

Nếu đã đặt nhưng bị bắt/hết giờ trước tập kết: không chiếu đoạn thắng, không ghi phá hoại hoàn tất. Khi thử lại, thiết bị và thế giới trở về checkpoint trước khi lấy hồ sơ.

## 8. Mỹ thuật, âm thanh và hiệu năng

### Đoạn kết khoảng 4 giây

| Thời gian trình bày dự kiến | Nội dung |
|---|---|
| 0–0,7 giây | Cắt sang một góc máy tĩnh an toàn, hướng về khu kỹ thuật; xác nhận đã rút |
| 0,7–1,5 giây | Kích hoạt sự kiện phá hủy, một xung sáng cục bộ và âm thanh chính |
| 1,5–3,5 giây | Khói/bụi thoát ở vị trí đã bố trí, đổi cụm thiết bị sang hư hại |
| 3,5–4 giây | Lời xác nhận ngắn, chuyển sang kết quả |

Mỗi tuyến rút có góc máy được dàn trước, kiểm tra không nằm trong tường/trần. Góc máy là thành phần riêng của finale, không gắn dưới actor đã bị `finish_level()` tắt xử lý. Giữ chuyển cảnh ngắn, không quay lượn dài hoặc rung máy mặc định.

### Cách thực hiện phần hình ảnh

- Dùng mô hình nguyên vẹn/hư hại được chuẩn bị sẵn; thay trạng thái hiển thị có kiểm soát.
- Giữ collider kiến trúc trong V1; không phá hình học tác động đường đi và không bake navmesh lúc nổ.
- Phần mesh cần thay trạng thái không gom vào mesh tĩnh của cả sector. Không bake bóng cố định của mô hình nguyên vẹn lên nền rồi để bóng còn sau khi đổi sang hư hại.
- Khói/bụi hữu hạn, có giới hạn hạt và thời gian sống; ưu tiên hiệu ứng hỗ trợ Compatibility. Không phụ thuộc shader chỉ chạy ở renderer khác.
- Dự kiến tối đa một đèn động không shadow cho xung sáng; không dùng nhiều đèn và mảnh vỡ vật lý cùng lúc.
- Không chớp lặp hoặc phủ trắng toàn màn hình. Bỏ qua cảnh luôn khả dụng; không cần thêm bảng cài đặt chung mới trong V1.
- Âm thanh qua hệ thống âm lượng và captions hiện có; không phát ngoài Master bus hoặc bỏ qua trạng thái mute/pause. Bổ sung âm thanh miễn phí nếu bộ hiện tại thiếu và ghi nguồn.

### Cách đánh giá hiệu năng

Máy đối chiếu hiện tại: Quadro P1000 4 GB, 1280×720, Compatibility. Chụp baseline ngay trước đợt V5 rồi đo lại cùng góc, số NPC và cấu hình.

Mục tiêu thiết kế là phần hốc mục tiêu chưa kích hoạt không làm thời gian khung hình trung vị tăng quá **10%** ở cùng cảnh thử. Với finale, ghi cả frame time trung vị và các khung hình chậm; nếu có giật rõ lúc dùng lần đầu thì phải preload/giảm tài nguyên. Đây là ngưỡng mục tiêu để đo, chưa phải kết quả đã đạt.

Không dùng thời gian headless/fixed-fps để kết luận hiệu năng đồ họa. Không báo một mức FPS của bản cũ như bằng chứng cho bản có vụ nổ.

## 9. Tổ chức mã nguồn dự kiến

Ưu tiên giới hạn thay đổi trong `maps/intelligence/`, tái sử dụng điều khiển, AI, tương tác và ObjectiveManager chung.

```text
maps/intelligence/
├── docs/sabotage-v5/
│   ├── PLAN.md                         # tài liệu hiện tại
│   └── VALIDATION.md                   # tạo khi có kết quả thật
├── resources/layout/
│   └── k17_sabotage.gd                 # cấu hình vị trí, 5 giây, góc máy, giới hạn VFX
├── scenes/
│   ├── props/k17_sabotage_target.tscn   # tủ nguyên vẹn/đã đặt/hư hại, vùng tương tác
│   └── effects/k17_sabotage_finale.tscn # góc máy, hình ảnh, âm thanh hữu hạn
├── scripts/
│   ├── sabotage_controller.gd          # trạng thái thiết bị, reset, chốt phá hủy một lần
│   ├── sabotage_target.gd              # Interactable; điều kiện/prompt và yêu cầu đặt
│   ├── extraction_finale.gd            # trình bày, pause/skip/fallback/cleanup
│   └── game_menus.gd                   # lớp riêng K17 để trình bày kết quả/thời gian chốt
└── tools/
    ├── k17_sabotage_builder.gd         # ghép mục tiêu/góc máy vào map
    └── check_sabotage.gd               # kiểm tra trạng thái và các trường hợp biên
```

Đây là **cây file dự kiến**, không phải các file runtime đã được tạo. Tên có thể điều chỉnh khi viết mã, nhưng trách nhiệm phải tách rõ:

| Thành phần | Trách nhiệm |
|---|---|
| `mission_controller.gd` hiện có | Sở hữu pha nhiệm vụ, thời hạn, xác nhận thoát, snapshot kết quả và thời điểm hoàn thành mục tiêu |
| `sabotage_controller.gd` mới | Sở hữu duy nhất trạng thái thiết bị; kiểm tra đặt hợp lệ, tiêu hao, xử lý phá hủy một lần và restore |
| `sabotage_target.gd` mới | Nhận tương tác E và chuyển yêu cầu sang controller; không tự điều khiển đồng hồ/WIN |
| `extraction_finale.gd` mới | Biểu diễn kết quả logic; không tự cấp hồ sơ, cộng giờ hoặc quyết định thành tích |
| `reinforcements.gd`, `power_network.gd` hiện có | Kiểm tra pha rút lui, ngừng sự kiện gameplay sau khi xác nhận thoát |
| `objective_hud.gd` và menu riêng K17 | Hiển thị trạng thái và kết quả bằng tiếng Việt, dùng số liệu đã chốt |
| `build_k17.gd` và builder mới | Nguồn sinh scene; ghép mục tiêu đúng vị trí, giữ các node động ngoài static merge |
| `playthrough_k17.gd` hiện có | Thêm lựa chọn thử nhánh phá hoại bằng đi bộ/giữ E thật |

Không sửa scene sinh sẵn bằng tay rồi để builder ghi mất thay đổi. Cập nhật builder/cấu hình trước, dựng lại scene, kiểm tra navmesh/collider và bake ánh sáng khi có thay đổi hình học tĩnh. Scene test không lính tiếp tục kế thừa map chính, không copy riêng cả map.

Không thay đổi hợp đồng dùng chung để phục vụ một tính năng riêng nếu chưa cần. Nếu lúc triển khai phát hiện điểm buộc sửa phần chung, phải ghi rõ ảnh hưởng và chạy hồi quy các map sử dụng phần đó.

## 10. Checkpoint, reset và vòng đời

K17 hiện không lưu checkpoint sau khi lấy hồ sơ. V5 giữ quy tắc này, tránh tình huống được lưu giữa lượt phá hoại hoặc nhận lại 120 giây sau mỗi lần thử.

Khi bắt/hết giờ và thử lại checkpoint:

1. Vô hiệu mã lượt cũ và hủy mọi hold/tween/sự kiện finale đang chờ.
2. Khôi phục hồ sơ và đồ thị nhiệm vụ theo checkpoint; mục tiêu phụ phá hoại chưa hoàn thành.
3. Trả cụm thiết bị về nguyên vẹn, ẩn thiết bị đã đặt và hiệu ứng khói/hư hại.
4. Hoàn lại trạng thái một thiết bị nhiệm vụ; chưa có hồ sơ thì `LOCKED`.
5. Xóa snapshot thoát, cờ đã chốt/kết quả và các cờ sự kiện một lần.
6. Giữ luồng reset lính/tiếp viện, camera, cửa và nguồn điện hiện có; không tạo thêm actor từ lượt cũ.

Nhật ký có thể giữ kiến thức đã đọc như hiện tại. Biết vị trí mục tiêu không đồng nghĩa đã lấy hồ sơ hoặc được phép đặt ở lượt mới.

Kiểm tra cả thứ tự restore giữa các node: không được hiện trạng thái `ARMED` trong một frame hoặc phát nổ do tín hiệu cũ sau respawn. Rời map/restart phải dọn sạch mọi node/sound được tạo động.

## 11. Kế hoạch kiểm thử và bằng chứng

Chỉ ghi `VALIDATION.md` là đạt khi có log/ảnh/lượt chạy tương ứng. Tách ba loại bằng chứng: kiểm tra logic cô lập, lượt đi nhiệm vụ bằng input thật và đánh giá hình ảnh/hiệu năng có renderer.

### 11.1. Logic và trường hợp biên

| Nhóm | Tình huống bắt buộc |
|---|---|
| Điều kiện | Trước hồ sơ; có hồ sơ; không PLAYING; đang rời scene; đã thoát; đã hết giờ |
| Hold | Đủ 5 giây; nhả ở gần hoàn tất; đổi mục tiêu; rời tầm; bị vật cản; pause; bị bắt |
| Một lần | Giữ/nhấn lặp không tạo thêm thiết bị; vùng tập kết gọi lặp không tạo thêm finale hoặc WIN |
| Thời hạn | Vừa hết giờ trong lúc đặt; đang ARMED hết giờ; tới tập kết khi còn rất ít thời gian; thời gian về 0 cùng tick với vào vùng |
| Mục tiêu | Bỏ qua vẫn thắng 7/7; đặt chưa được tính hoàn thành; phá hủy rồi mới hoàn tất mục tiêu phụ và WIN |
| Finale | Hai góc máy; pause/focus; bỏ qua; thiếu VFX/âm thanh; quá thời gian chờ; callback lặp; phím bỏ qua không kích nút menu |
| Vòng đời | Bắt/thất bại rồi retry; restart; về menu khi đang cảnh; lượt mới không nhận callback/thiết bị lượt cũ |
| Số liệu | Tuyến rút/thời gian tại tập kết được giữ; cinematic không tăng thời gian ghi trên kết quả |
| Tài nguyên | Chạy bản đóng gói từ thư mục sạch; mọi scene/âm thanh mới đã được export |

### 11.2. Lượt đi nhiệm vụ

1. **Không phá hoại, cả hai tuyến:** kiểm tra hồi quy nhiệm vụ gốc bằng input thật; không cần ghé hốc mới.
2. **Không lính, có phá hoại, cả hai tuyến:** kiểm tra khả năng tương tác, va chạm, cổng, đồng hồ và kết thúc. Nếu tuyến sân sau detour không kịp, ghi rõ giới hạn thay vì dịch chuyển người chơi để tạo lượt thắng.
3. **Có lính, phá hoại qua bảo trì, đã chuẩn bị:** trường hợp cân bằng chính; giữ cả nhận thức AI, ba camera, cảm biến và tối đa bốn tiếp viện.
4. **Có lính, chưa chuẩn bị cửa hậu:** kiểm tra khả năng giữ khóa tám giây, nguy cơ bị bắt và đường bỏ mục tiêu phụ. Báo kết quả thật, không bắt buộc mọi lượt đều thắng.
5. **Bỏ dở thao tác rồi rút:** mục tiêu chính hoàn tất, thiết bị chưa tiêu hao, không có cảnh phá hoại.
6. **Đã đặt rồi bị bắt/hết giờ, thử lại:** không nhận thành tích của lượt cũ; lượt mới có thể đặt và kết thúc lại đúng một lần.
7. **Đã đặt, tới sân quá muộn:** kiểm tra khả năng đổi tuyến bảo trì; không sửa giờ đóng cổng để cứu lượt test.

Tool phải điều khiển đi bộ, camera và E thật trên các đoạn cần đánh giá. Fixture đặt trạng thái để thử race/pause được ghi riêng, không dùng làm bằng chứng đã đi trọn nhiệm vụ.

### 11.3. Hình ảnh và trải nghiệm

- Chụp cận tủ, bệ/gá, dây nối và biển; chụp góc người chơi tiếp cận/đang thao tác.
- Kiểm tra tầm tương tác ở tư thế đứng/cúi, không xuyên tường, không bị tủ che hết vùng E.
- Kiểm tra đường nhìn từ lính/camera tới vị trí đặt: vật che thực sự che phần nào và mặt hở thực sự có nguy cơ.
- Rà lại các điểm gần đó: không tách ống, treo biển/camera hoặc biến chỗ nấp cũ thành một ô đứng lộ thiên.
- Chạy lại kiểm tra gá đỡ, mỹ thuật, chức năng K17 và đường đi sau khi thêm hình học.
- Quay/chụp cả hai đoạn kết, pause/skip, mute/captions và bản không lính.
- Đo hiệu năng renderer trước/sau cùng cấu hình, bao gồm lần kích hoạt hiệu ứng đầu tiên.
- Người chơi mới phải hiểu: phá hoại là tùy chọn; đồng hồ vẫn chạy; đặt xong phải rút; thiết bị kích hoạt khi đã thoát.

## 12. Các mốc thực hiện và điều kiện chuyển bước

| Mốc | Công việc | Kết quả cần xem được trước khi sang bước sau |
|---|---|---|
| M0 — Chốt bố cục | Dựng hốc thử, vị trí tương tác, đường rẽ vào/ra, góc finale | Đi bộ không lính, E nhận đúng; bệ/gá/collider hợp lý; có số đo detour |
| M1 — Logic nhiệm vụ | Mục tiêu phụ, thiết bị riêng, hold/cancel, trạng thái/reset | Bỏ qua và đặt đều đúng luật; không chiếm ô đồ; chưa cần hiệu ứng đẹp |
| M2 — Luồng thoát | Xác nhận thoát một lần, snapshot, chặn lịch gameplay, finale/skip/fallback | Hai kết thúc hoạt động, không WIN sớm, không kẹt do pause/menu/thiếu VFX |
| M3 — Mỹ thuật | Tủ/hư hại, hiệu ứng, âm thanh, captions, góc máy, bake khi cần | Nhìn đúng công năng khu quân sự; không đồ treo/ống rời; không giật rõ lúc nổ |
| M4 — Cân bằng | E2E thật, hai tuyến, đã/chưa chuẩn bị, full AI, chơi thử | Số đo thời gian/rủi ro; nhánh tùy chọn có giá trị và không phá nhiệm vụ gốc |
| M5 — Đóng gói | Kiểm tra export, tài liệu tự test, log/ảnh nghiệm thu | Bản đóng gói chạy độc lập, có bằng chứng và giới hạn được ghi rõ |

Mỗi mốc tạo một phần có thể kiểm tra riêng trên `feature/twp`. Tên commit theo Conventional Commits với mô tả tiếng Việt, ví dụ:

```text
feat(k17): thêm mục tiêu phá hoại tùy chọn sau khi lấy hồ sơ
feat(k17): bổ sung cảnh phá hủy sau khi thoát an toàn
fix(k17): khôi phục thiết bị phá hoại khi thử lại checkpoint
docs(k17): ghi kết quả kiểm thử nhánh phá hoại
```

Chưa cần tạo thêm nhánh hoặc PR trong bước lập kế hoạch. Việc ghép sang nhánh khác thực hiện khi đã có bản nghiệm thu và người dùng xác định nhánh đích.

## 13. Tiêu chí nghiệm thu bản đầu

- [x] Nhiệm vụ cũ vẫn thắng được qua hai đường rút khi bỏ qua phá hoại.
- [x] Một mục tiêu phụ mới; tổng 7 bắt buộc/3 tùy chọn; không biến mục tiêu phụ thành điều kiện thắng.
- [x] Chỉ đặt sau hồ sơ, giữ E 5 giây; hủy và tương tác lặp không sai trạng thái/tiêu hao.
- [x] Hành trang ba ô, phím điều khiển, lịch AI/nguồn/cổng và 120 giây giữ đúng luật.
- [x] Cụm mục tiêu có công năng, điểm tựa và đường tiếp cận hợp lý; không chắn cửa hoặc tuần tra.
- [x] Một lượt có lính qua bảo trì chứng minh nhánh phụ khả thi; đủ ba lượt để đánh giá ngân sách thời gian, kèm số liệu thất bại nếu có.
- [x] Không báo hoàn thành phá hoại ngay lúc đặt; chỉ ghi sau thoát và sự kiện phá hủy.
- [x] Hết giờ/bị bắt trước tập kết vẫn thất bại; quy tắc thời hạn cùng tick không đổi.
- [x] Không WIN sớm, spawn sau thoát, nổ lặp hoặc callback cũ chạy sang lượt mới.
- [x] Cả hai tuyến có kết thúc đúng; pause, bỏ qua, retry, restart, về menu và thiếu VFX không làm kẹt game.
- [x] Kết quả dùng tuyến/thời gian chụp tại tập kết, không cộng cinematic vào chặng chơi.
- [x] Đạt kiểm tra hình học/mỹ thuật/hồi quy và đo hiệu năng thật; tài nguyên mới có nguồn.
- [x] Bản đóng gói và chế độ không lính chạy được; có hướng dẫn tự test và `VALIDATION.md` ghi bằng chứng thật.

## 14. Rủi ro chính và cách xử lý

| Rủi ro | Cách xử lý ưu tiên |
|---|---|
| Đặt gần đường thoát đến mức không có lựa chọn/rủi ro | Đổi góc tiếp cận và hướng tuần tra quan sát mặt tủ; không tăng thời gian giữ tùy tiện |
| Đường vòng quá dài khiến gần như không kịp | Rút ngắn detour/đổi hốc, đo lại; giữ đồng hồ và AI trước khi bàn đổi luật |
| Không rõ E có hoạt động hay không | Mặt thao tác dễ nhận biết, prompt nêu điều kiện khóa, ray/collider được kiểm chứng |
| Vụ nổ đẹp nhưng game đã hiện WIN hoặc vẫn bị bắt | Chốt thoát và ngừng gameplay trước, hoàn thành mục tiêu bắt buộc sau finale |
| Checkpoint giữ lại bom hoặc vụ nổ lượt cũ | Trạng thái riêng có restore, mã lượt vô hiệu callback và kiểm tra retry nhiều lần |
| Mô hình hư hại vẫn để lại bóng nguyên vẹn | Tách phần thay đổi khỏi static merge/lightmap cố định, kiểm tra hai trạng thái có render |
| Khói dày/hiệu ứng làm giật máy | Preload, giới hạn hạt/đèn, bỏ mảnh vỡ vật lý; đo cảnh thật trên Compatibility |
| Nhiệm vụ mới bị hiểu là bắt buộc | Nhãn “tùy chọn” từ giới thiệu đến HUD/kết quả; kết thúc thường vẫn là thắng |

## 15. Hướng mở rộng sau khi V1 ổn định

1. Nhiều mục tiêu với lựa chọn phá một hoặc nhiều cụm, mỗi cụm có rủi ro/lợi ích riêng.
2. Cảnh phá hủy khác nhau theo tuyến rút hoặc số mục tiêu đã hoàn tất.
3. Một chế độ nâng cao có kích hoạt trước khi rút, thay đổi ánh sáng/cửa/lối đi; phải thiết kế lại thời gian và checkpoint trước khi thêm.
4. Xếp hạng nhiệm vụ dựa trên hồ sơ, phá hoại, phát hiện và thời gian, sau khi nhóm đã thống nhất luật điểm.

Những mục này không nằm trong nghiệm thu Sabotage V1. Điểm bắt đầu triển khai là **M0: chọn và đi thử hốc thiết bị**, sau đó mới nối cơ chế đặt và đoạn kết.
