# K17 V6 — Kịch bản chơi đề xuất: 120 giây cuối

Ngày lập: 28/10/2026. Đối chiếu bản hiện tại: `98db7ed` trên `feature/twp`.

**Trạng thái: bản nháp để đọc và trao đổi; chưa triển khai V6 vào game.** Tài liệu này chốt trải nghiệm một lượt chơi trước khi lập kế hoạch dựng cảnh, chia việc và viết mã. Các thời lượng mới là thông số thiết kế ban đầu, cần chơi thử để điều chỉnh.

**Cập nhật thảo luận:** sau bản nháp này, đã chọn bối cảnh hiện đại và hướng màn che với một lính đứng chốt kết hợp lính tuần tra. Xem [luồng chơi đang trao đổi](PLAY_FLOW_DRAFT.md). Phòng đầu quét và khu điều phối với hai lệnh ở dưới vẫn là ý tưởng tham khảo, chưa được chốt triển khai đồng thời.

**Tài liệu chính hiện tại:** [kế hoạch đầy đủ V6 — màn che đánh lừa thị giác](PLAN.md). Giữ bản dưới làm lịch sử ý tưởng; không lấy phạm vi phòng đầu quét/khu điều phối trong bản này làm danh sách triển khai V6 hiện tại.

## 1. Ý tưởng chủ đạo

**Vào trong im lặng, thoát giữa cuộc truy lùng.**

An đột nhập cơ sở tình báo K17 để thu hồi Mật lệnh 04. Lam hỗ trợ qua vô tuyến. Hồ sơ có niêm phong báo động độc lập; lấy được hồ sơ đồng nghĩa bắt đầu cuộc rút lui. Người chơi biết trước nguy cơ này và có cơ hội chuẩn bị.

Trải nghiệm đặc trưng là **quan sát an ninh, chủ động chuẩn bị, chọn thời điểm và ứng biến khi cơ sở phong tỏa**. Mã cửa vẫn phục vụ việc tìm và sử dụng thông tin truy cập; đoạn căng thẳng chính nằm ở cách vượt qua hệ thống bảo vệ và đưa hồ sơ ra ngoài.

Nhịp cảm xúc của lượt chơi:

```text
Quan sát → thâm nhập → tự chọn lợi thế → tập trung cao độ khi lấy hồ sơ
→ báo động → chọn đường rút → quyết định có phá hoại → thoát hoặc thử lại.
```

Mục tiêu thời lượng tham khảo: lần đầu 12–18 phút, đã biết đường 7–10 phút; trong đó chặng rút luôn có tối đa 120 giây. Điều chỉnh các khoảng này bằng playtest, dựa trên thao tác và lựa chọn thực của người chơi.

## 2. Phạm vi của đợt này

| Thành phần | Có sẵn trong bản hiện tại | Đề xuất V6 |
| --- | --- | --- |
| Thâm nhập | Hai hướng vào, giấy thông hành, chỉ dẫn kho và mã cửa | Giữ, thêm chỉ dẫn dẫn tới khu điều phối |
| Chuẩn bị | Ngắt camera chính, chuẩn bị chốt cửa hậu | Giữ; thêm một lựa chọn can thiệp lệnh an ninh |
| Khu mới | Khuôn viên 96×108 m và tám khu chức năng | Một khu điều phối nhỏ, có hai cửa nối vào tuyến hiện hữu |
| Kho B1 | Hai dải cảm biến, lính và thao tác lấy hồ sơ 3,5 giây | Tổ chức lại đoạn cuối thành phòng thu hồi có đầu quét, vị trí quan sát và vật che thật |
| Rút lui | 120 giây, nguồn dự phòng, hai đợt tiếp viện, hai đường ra | Giữ; phản ánh đúng lựa chọn can thiệp trước đó |
| Phá hoại | Đặt thiết bị 5 giây tại tủ tình báo, kích hoạt sau khi thoát | Giữ nhiệm vụ tùy chọn V5 |
| Định hướng | Nhật ký và minimap vị trí thật, tầng trệt/B1 | Bổ sung mặt bằng mới và thông tin về lệnh người chơi đã chọn |

Khối lượng cốt lõi: **một khu mới, một nhiệm vụ chuẩn bị tùy chọn và một đoạn thu hồi hồ sơ đặc trưng**. Ưu tiên bố trí khu điều phối trong phần diện tích còn phù hợp của khuôn viên; ranh giới và tọa độ chỉ chốt sau khi dựng thử đường đi.

## 3. Kịch bản một lượt chơi

### Cảnh 1 — Vành đai, nhận nhiệm vụ

An xuất hiện ngoài hàng rào. Nhìn thấy ánh đèn cơ sở, xe tiếp vận, biển chỉ khu và các hướng tiếp cận. Người chơi điều khiển ngay; lời giao nhiệm vụ xuất hiện trong lúc quan sát.

**Lam:** “Mật lệnh 04 nằm trong kho B1. Niêm phong có báo động riêng. Cậu có thể vào kín đáo, nhưng khi lấy tài liệu thì phải rút ngay. Nhớ đường ra trước khi xuống kho.”

Mục tiêu đầu: **Vào cơ sở K17.** Chưa có đồng hồ 120 giây.

Hai hướng tiếp cận:

- **Phía tây, qua sân/nhà xe:** gần phòng trực và giấy thông hành; phải quan sát các đoạn sân hở.
- **Phía đông, qua hậu cần:** cho phép xem trước trạm điện, cửa hậu và nhánh điều phối; người chơi vẫn cần tới phòng trực lấy thẻ.

Hai hướng có lợi thế về thứ tự chuẩn bị. Khi bố trí lại cảnh cần làm rõ lợi thế này bằng tầm nhìn, biển chỉ và đường nối.

### Cảnh 2 — Giấy thông hành và thông tin kho

An tới phòng trực, chờ lính rời hướng nhìn hoặc dùng vật che để tiếp cận bàn. Lấy giấy thông hành rồi tìm chỉ dẫn ở khu vô tuyến. Hai việc có thể thực hiện theo thứ tự người chơi chọn.

Tại bàn vô tuyến, người chơi biết:

1. Cách đối chiếu mã cửa tại checkpoint khu hồ sơ.
2. Niêm phong tài liệu chắc chắn kích hoạt phong tỏa khi bị tháo.
3. Khu điều phối có thể sửa **một lệnh ứng phó** trước khi hệ thống chuyển sang báo động.

**Lam:** “Cậu đã có thông tin vào kho. Muốn thuận đường rút hơn thì tìm bàn điều phối. Hoặc đi thẳng tới khu hồ sơ; quyết định là của cậu.”

Checkpoint khu thông tin tiếp tục phục vụ lượt chơi như hiện tại. Nhật ký lưu những điều đã đọc; minimap chỉ vị trí thật, không hiện vị trí lính hoặc đường giải.

### Cảnh 3 — Chuẩn bị theo cách của người chơi

Người chơi có thể đi thẳng tới kho hoặc ghé các mục tiêu chuẩn bị. Tắt camera chính và chuẩn bị cửa hậu vẫn hoạt động theo V5. Nguồn dự phòng sau khi lấy hồ sơ vẫn là giới hạn của việc ngắt camera chính.

**Khu điều phối mới** nối khối chỉ huy với hành lang kỹ thuật, tạo một vòng di chuyển có hai đầu ra. Bên trong có bàn trực, sơ đồ phong tỏa, thiết bị vô tuyến, bảng lệnh và một vị trí quan sát có vật che thật. Mỗi đồ vật phải giải thích được chức năng của khu này.

Một lính hiện có được bố trí tuyến kiểm tra đi qua khu điều phối; phân bổ lại tuần tra trong bước thiết kế chi tiết. Chưa tăng trần sáu lính thường trực và bốn tiếp viện chỉ để lấp khu mới.

Người chơi dùng thẻ ở bảng điều khiển. Bảng giải thích tác dụng trước khi xác nhận, sau đó cần giữ E tại chỗ; thời lượng thử ban đầu **5 giây**. Có thể bỏ dở và rút về vật che. Nhiệm vụ mới là **Can thiệp lệnh phong tỏa**, thuộc nhóm tùy chọn.

Chọn một trong hai lệnh:

| Lựa chọn | Thay đổi sau khi lấy hồ sơ | Cách sử dụng |
| --- | --- | --- |
| **A — Gia hạn kiểm tra cổng sân** | Cổng sân đóng ở T+110 thay vì T+90; cảnh báo chuyển sang T+90. Tổng thời gian rút vẫn 120 giây. | Hỗ trợ người chọn tuyến sân, có thêm cửa sổ đi qua cổng |
| **B — Điều một cảnh vệ đi kiểm tra** | Một cảnh vệ phía đông thuộc đợt T+45 nhận tuyến kiểm tra cố định qua khu điều phối trước khi trở về tuyến gốc. | Tạo khoảng giảm áp lực có giới hạn trên một phần tuyến bảo trì |

Với B, mục tiêu thử ban đầu là tạo khoảng lệch nhịp khoảng 10–15 giây; thời lượng thật phải đến từ quãng đường và tốc độ đi. Cảnh vệ vẫn tồn tại, các lính khác làm nhiệm vụ bình thường, và người đã phát hiện An vẫn truy đuổi. Điểm kiểm tra được xác định trước, không đi theo vị trí bí mật của người chơi. Nếu cảnh vệ đó không thể xuất hiện hợp lệ, áp dụng quy tắc hoãn/hủy tiếp viện hiện có và không điều lính khác thay thế từ giữa bản đồ.

Chỉ một lệnh có hiệu lực. Trước khi lấy hồ sơ, quay lại bảng có thể đổi lựa chọn; lệnh mới thay lệnh cũ. Khi báo động niêm phong bắt đầu, bảng khóa quyền sửa. Bỏ qua khu này thì dùng lịch an ninh V5 bình thường.

Thông tin người chơi cần nhớ luôn được ghi trong J và trạng thái nhiệm vụ: lệnh đã chọn, điều gì thay đổi và điều gì vẫn giữ nguyên. Việc chọn A/B không tự cấp thẻ, mở kho, tắt nguồn dự phòng hoặc hoàn thành chốt cửa hậu.

### Cảnh 4 — Qua cửa kho và tới vị trí quan sát

An tới checkpoint khu hồ sơ, đọc bảng ca trực và nhập mã ở keypad gắn tường. Cửa mở, nhìn thấy cầu thang dẫn xuống B1. Lời nhắc cuối nhấn mạnh hậu quả lấy tài liệu.

**Lam:** “Xuống dưới cẩn thận. Camera chính và thiết bị quét trong kho dùng nguồn khác nhau. Giữ được im lặng đến sát tài liệu sẽ cho cậu cơ hội quan sát.”

Giữ đoạn cảm biến hiện tại trên đường vào, nhưng sắp lại vị trí và nhịp để đoạn quan sát cuối không trở thành nhiều lượt chờ giống nhau nối tiếp. Biển và bố trí thiết bị phải phân biệt rõ từng loại nguy hiểm.

Tại cửa phòng thu hồi có hốc chờ được tường/tủ chắn đường nhìn. Từ đó người chơi thấy đầu quét, mặt bàn hồ sơ và đường lùi. Vị trí này phải thực sự có vật che theo luật nấp hiện hành.

Đề xuất một **checkpoint cuối trước thu hồi**, đặt tại hốc chuẩn bị sau khi đã mở kho. Đây là điểm lưu bổ sung sau các điều kiện truy cập; checkpoint khu hồ sơ trước keypad vẫn giữ để tránh tạo vòng phụ thuộc. Checkpoint mới chỉ lưu khi không bị truy đuổi và chưa có tài liệu. Từ đây người chơi có thể quay lại chuẩn bị, rồi trở về cập nhật checkpoint trước khi lấy hồ sơ.

### Cảnh 5 — Phòng thu hồi, đoạn đặc trưng

Tài liệu nằm trên bàn trong vùng đầu quét kiểm soát. Người chơi cần quan sát hướng quét và khoảng khuất do kiến trúc tạo ra, chọn lúc tiến vào rồi giữ E mở niêm phong.

**Cách đọc tình huống:**

- Vệt quét và đèn trên thiết bị cho biết phía đang bị kiểm tra.
- Âm thanh mô-tơ và đèn chuyển trạng thái báo thiết bị sắp quay lại; có cả tín hiệu hình ảnh để chơi không cần dựa hoàn toàn vào âm thanh.
- Hốc chờ và đường lùi được nhìn thấy trước khi tiến vào.

**Chuỗi thao tác dự kiến:**

1. Dừng tại hốc, quan sát một chu kỳ.
2. Khi đầu quét chuyển khỏi bàn hồ sơ, cúi qua đoạn trống ngắn.
3. Nhìn tài liệu và giữ E **3,5 giây** theo thao tác hiện có.
4. Nhả E hoặc rời tầm trước khi hoàn tất sẽ hủy; người chơi có thể lùi về hốc và chờ lần tiếp theo.
5. Hoàn tất thao tác thì lấy được hồ sơ và chuyển ngay sang báo động 120 giây.

Thông số thử: cơ hội thao tác khoảng **8 giây**, đoạn từ hốc tới bàn khoảng **2–3 m**, tín hiệu báo đầu quét trở lại bắt đầu trước khoảng **3 giây**. Những con số này chỉ hợp lệ nếu dựng thử cho thấy đủ thời gian tiến vào, nhìn đúng mục tiêu và thao tác; đặc biệt phải kiểm tra đường lùi khi bỏ dở.

Đầu quét quay lại không đồng nghĩa thất bại tức thì: chỉ khi thực sự phát hiện người chơi qua đường nhìn hợp lệ mới kích hoạt báo động cục bộ. Lính tới kiểm tra điểm sự kiện theo thông tin chúng nhận được. Người chơi có thể lùi, cắt tầm nhìn hoặc bị bắt theo luật hiện hành. Đồng hồ rút chưa chạy khi chưa lấy được hồ sơ.

Thiết bị quét và niêm phong có nguồn độc lập, được giải thích bằng nhãn tại kho và lời nhắc. Tắt ba camera chính vẫn giúp tiếp cận, nhưng không loại bỏ đoạn thu hồi này. Ngay trước thao tác lấy, hiển thị rõ: **“Thu hồi Mật lệnh 04 — hoàn tất sẽ bắt đầu 120 giây rút lui.”**

### Cảnh 6 — Niêm phong bị phá

Ngay khi hồ sơ được thu hồi:

- Đèn khu kho chuyển sang trạng thái báo động, còi và loa hoạt động.
- Đồng hồ 120 giây xuất hiện; hai lối rút đã có vẫn được nhận biết qua biển và minimap.
- Cửa hậu chuyển sang khóa cơ như V5. Lịch tiếp viện và nguồn dự phòng bắt đầu.
- Bàn điều phối khóa sửa; lệnh A/B đã chọn được áp dụng đúng phạm vi.

**Lam:** “Có tài liệu rồi! Cơ sở đang phong tỏa. Đi theo đường đã chuẩn bị; còn hai phút.”

Người chơi giữ điều khiển trong khoảnh khắc chuyển trạng thái. Hiệu ứng báo động không được lấy mất thời gian bằng một đoạn cắt cảnh bắt buộc. Nếu còn trong vùng quét, hệ thống chuyển sang trạng thái báo động thống nhất thay vì bắt thao tác lấy tài liệu thành công rồi phạt thêm một lần vì chu kỳ cũ.

### Cảnh 7 — Rút lui, đọc tình hình và quyết định phá hoại

Hai hướng rút giữ vai trò hiện tại:

- **Sân:** quay cầu thang chính và khối giữa, vượt sân tới tập kết phía tây. Đường này chịu áp lực cổng đóng và các đoạn hở.
- **Bảo trì:** cửa phía đông kho B1, hành lang ngầm, cầu thang thứ hai, qua khu kỹ thuật tới cửa hậu. Chốt chuẩn bị trước giúp tránh thao tác mở khóa tám giây trong lúc bị truy lùng.

Lệnh A giúp cửa sổ qua cổng sân rộng hơn nhưng không giảm số lính hay mở vật che. Lệnh B chỉ làm lệch tuyến của một cảnh vệ trong một khoảng; người chơi vẫn cần quan sát những người còn lại. Trong mỗi lượt, cơ sở hoạt động theo cùng bộ quy tắc và phản ánh lựa chọn trước đó.

Khi tới gần xưởng, An nhìn thấy cụm tình báo dự phòng. Lam nhắc ngắn nếu còn phù hợp với các cảnh báo ưu tiên cao hơn:

**Lam:** “Tủ dự phòng ở xưởng. Cậu có thể đặt thiết bị trước khi rút. Ưu tiên đưa tài liệu ra ngoài nếu không còn đủ thời gian.”

Người chơi tự chọn:

- Tiếp tục tới tập kết, hoàn thành nhiệm vụ chính.
- Dừng ở tủ, giữ E năm giây đặt thiết bị rồi rút tiếp trong cùng đồng hồ.

Thiết bị chỉ kích hoạt sau khi game xác nhận đã thoát an toàn. Giữ E có thể hủy, lính vẫn phát hiện/bắt bình thường, và đặt xong không cộng thời gian. Lựa chọn bỏ qua phá hoại vẫn là một kết thúc thành công.

### Cảnh 8 — Tập kết và kết quả

Đến vùng tập kết hợp lệ trước khi hết giờ sẽ chốt kết quả lượt chơi.

- **Thu hồi hồ sơ:** An thoát, Lam xác nhận Mật lệnh 04 đã an toàn, hiển thị kết quả.
- **Thu hồi và phá hoại:** sau khi đã thoát, đoạn kết V5 cho thấy cụm tình báo bị vô hiệu hóa, rồi hiển thị thành tích bổ sung.

Kết quả có thể ghi lệnh chuẩn bị đã chọn, đường thoát và phá hoại có hoàn thành hay không, để người chơi muốn thử một kế hoạch khác. Không cần thêm xếp hạng phức tạp trong bản đầu.

## 4. Lịch rút lui để người chơi có thể hiểu và dự đoán

T là số giây sau khi thực sự lấy được tài liệu. Toàn bộ thời gian trước đó dùng cho thâm nhập và chuẩn bị.

| Thời điểm | Mặc định hoặc chọn B | Chọn A |
| --- | --- | --- |
| T+0 | Báo động, cửa hậu khóa cơ, bắt đầu 120 giây | Như mặc định |
| T+10 | Đợt tiếp viện thứ nhất, tối đa hai người | Như mặc định |
| T+15 | Camera được nguồn dự phòng cấp lại | Như mặc định |
| T+45 | Đợt hai, tối đa hai người; nếu chọn B, một cảnh vệ phía đông đi theo lệnh kiểm tra cố định trước | Đợt hai theo lịch/tuyến gốc |
| T+70 | Loa báo cổng sân sẽ đóng sau 20 giây | Cổng đã gia hạn; không phát cảnh báo cũ gây hiểu sai |
| T+90 | Cổng sân nhận lệnh đóng | Loa báo cổng sẽ đóng sau 20 giây |
| T+100 | Cảnh báo kiểm soát chốt đông như V5 | Như mặc định |
| T+110 | Cổng sân tiếp tục đóng; cửa hậu vẫn có chốt cơ | Cổng sân nhận lệnh đóng |
| T+120 | Hết giờ nếu chưa tập kết hợp lệ | Như mặc định |

Quy tắc hoãn tiếp viện khi điểm vào bị chiếm/nhìn trực tiếp, xử lý người đứng ở ngưỡng cổng và pause tiếp tục theo luật hiện có. Minimap chỉ hiện thông tin hệ thống mà người chơi biết; không bổ sung chấm vị trí lính.

## 5. Một lượt chơi mẫu

Đây là ví dụ kể trải nghiệm, chưa phải lượt E2E hoặc số đo đã đạt:

1. Người chơi chọn vào phía tây, nhìn lượt tuần tra rồi lấy thẻ ở phòng trực.
2. Đọc chỉ dẫn kho tại bàn vô tuyến; biết chắc lấy hồ sơ sẽ báo động nên quyết định chuẩn bị đường bảo trì.
3. Vào khu điều phối, quan sát lính đi qua rồi chọn **B**. Sau đó ghé trạm điện chuẩn bị cửa hậu, nhận biết tủ phá hoại nằm cạnh đường rút.
4. Mở cửa hồ sơ, đối chiếu mã rồi mở kho B1. Đi tới hốc chuẩn bị và lưu checkpoint cuối.
5. Đợi đầu quét chuyển hướng. Lần đầu tiến vào hơi muộn, người chơi chủ động hủy thao tác và lùi ra trước khi bị nhìn thấy.
6. Ở chu kỳ tiếp theo, tiến vào sớm hơn và giữ E đủ thời gian. Còi báo động vang lên, 120 giây bắt đầu.
7. Rút theo hành lang ngầm. Nguồn dự phòng khởi động; sau đó loa xác nhận lệnh kiểm tra phía đông. Người chơi tận dụng khoảng lệch nhịp, vẫn nhìn và nghe để tránh các lính khác.
8. Tới xưởng, kiểm tra đồng hồ và tình hình. Nếu còn cơ hội thì đặt thiết bị; nếu nguy hiểm thì đi thẳng.
9. Dùng chốt cửa hậu đã chuẩn bị và chạy tới tập kết. Nếu đã đặt thiết bị, chứng kiến đoạn kết phá hoại sau khi an toàn.

Lần chơi sau có thể chọn A và tuyến sân, hoặc bỏ hẳn khu điều phối để thử rút với lịch chuẩn. Các lựa chọn này tạo khác biệt về đường đi và rủi ro trong cùng mục tiêu thu hồi tài liệu.

## 6. Thất bại và thử lại

| Tình huống | Kết quả mong muốn |
| --- | --- |
| Bị thấy trước khi lấy tài liệu | Báo động cục bộ và phản ứng nhìn/nghe bình thường; còn cơ hội cắt tầm nhìn |
| Bị bắt trước khi lấy | Trở về checkpoint đã lưu, giữ kiến thức trong J, khôi phục trạng thái nhiệm vụ/đồ theo snapshot |
| Bỏ dở thao tác niêm phong | Chưa lấy tài liệu, chưa bắt đầu 120 giây; có thể lùi ra và thử lại |
| Bị bắt/hết giờ sau khi lấy | Trở về trạng thái trước thu hồi ở checkpoint cuối đã kích hoạt; cảnh vệ tiếp viện, đồng hồ và sự kiện của lượt cũ được dọn |
| Đã đặt thiết bị nhưng chưa thoát | Chưa tính thành công phá hoại; thử lại trả thiết bị và trạng thái tủ theo checkpoint |
| Trở lại checkpoint sau khi đổi A/B | Lưu lựa chọn mới khi cập nhật checkpoint hợp lệ; không cộng dồn hai lệnh |

Checkpoint cuối không lưu sau khi có hồ sơ. Nếu người chơi chưa kích hoạt nó thì dùng checkpoint hợp lệ gần nhất. Những sự kiện đang chờ của lượt cũ không được chạy sang lượt thử lại. Điểm hồi sinh phải có vật che và cho phép quan sát chu kỳ mới trước khi tiến ra.

## 7. Thứ tự dựng thử sau khi thống nhất kịch bản

1. **Thử phòng thu hồi trước:** hốc quan sát, đầu quét, đường lùi và thao tác 3,5 giây. Chứng minh đoạn này vừa căng thẳng vừa đọc được trước khi làm đồ họa chi tiết.
2. **Dựng khu điều phối và lệnh A:** bố trí đường vòng hai đầu, thao tác chọn, báo trước tác dụng và mốc đóng cổng mới.
3. **Thêm lệnh B:** kiểm tra đường đi thật và mức lợi thế so với A, giữ luật phát hiện/truy đuổi chung.
4. **Nối toàn lượt:** cập nhật chỉ dẫn, lời thoại, checkpoint, mặt bằng minimap và hai kết thúc V5.
5. **Chơi thử:** bỏ chuẩn bị/A/B × có hoặc bỏ phá hoại; xác minh hai tuyến rút, bị bắt/thử lại và bản không lính. Cân bằng lính và lệnh B phải kiểm tra trên bản có AI.

Mốc nghiệm thu trải nghiệm: người chơi hiểu vì sao phải quan sát, biết trước thời điểm bắt đầu 120 giây, nhận ra tác dụng lựa chọn A/B và giải thích được nguyên nhân thất bại. Mỗi tuyến rút cần có lượt chơi thật chứng minh khả thi dưới luật an ninh của nó; thời gian bố trí trên giấy chưa đủ làm bằng chứng.

Chưa đưa vào đợt này: chiến đấu/bắn súng, thêm một vòng thu thập nhiều chìa khóa, nhiều tầng mới, lính xuất hiện vô hạn, hoặc thay hệ thống AI chung. Các mở rộng như camera mất điện kéo lính tới kiểm tra có thể bàn riêng sau khi vòng chơi trên hoạt động tốt.
