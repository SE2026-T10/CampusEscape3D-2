# K17 V6 — Kế hoạch kịch bản và triển khai màn che đánh lừa thị giác

Ngày lập: 28/10/2026. Bản nền đã đối chiếu: `98db7ed`, nhánh `feature/twp`.

**Trạng thái: đã triển khai V6 trên `feature/twp`; xem [kết quả và số đo thực tế](VALIDATION.md).** Bản dưới giữ kế hoạch trước khi dựng từ [luồng chơi đã thảo luận](PLAY_FLOW_DRAFT.md). Các thông số đề xuất ban đầu được giữ để đối chiếu; thông số sau cân chỉnh, phần bổ sung ô kính quan sát và kết quả nghiệm thu nằm trong báo cáo.

Đợt hoàn thiện B1 sau phản hồi chơi thử đã triển khai theo [B1_REFINEMENT_PLAN.md](B1_REFINEMENT_PLAN.md): cảm biến kín tuyến, hốc/W1/W2, camera và chuyển hướng chú ý, khóa hồ sơ, đẩy màn qua cửa rồi rút ngược. Xem [kết quả B1 mới](../b1-refinement/VALIDATION.md); báo cáo V6 tại thư mục này giữ kết quả của bản trước.

Đây là tài liệu chính cho hướng V6 hiện tại. [SCENARIO.md](SCENARIO.md) giữ bản ý tưởng trước; phòng đầu quét và khu điều phối với hai lệnh lựa chọn trong bản đó chưa thuộc phạm vi triển khai này.

## 1. Trải nghiệm cần đạt

**Thâm nhập bằng quan sát và đánh lừa thị giác; thoát thân bằng chuẩn bị và ứng biến.**

An là người lính thực hiện nhiệm vụ tại cơ sở tình báo K17 trong một cuộc chiến hiện đại hư cấu. Mục tiêu bắt buộc là lấy Mật lệnh 04 và đưa tài liệu ra ngoài. Lam hỗ trợ qua vô tuyến. Phá hoại cụm tình báo dự phòng là nhiệm vụ bổ sung dành cho người muốn nhận thêm rủi ro.

Đoạn đặc trưng nằm ở hành lang B1: An đẩy một màn chiếu ngụy trang, tái hiện hành lang trống theo góc quan sát của người đứng chốt. Người chơi phải giữ thiết bị đúng hướng, đưa cả người và thiết bị vào các hốc che trước khi tuần tra bên hông nhìn tới. Cảm giác cần đạt là hồi hộp khi tự quyết định tiến hay dừng, sau đó chuyển sang khẩn cấp khi lấy hồ sơ.

Lấy cảm hứng từ thủ thuật hình ảnh trong điện ảnh, xây dựng tình huống và mặt bằng riêng của K17. Không cần chuyển sang game bắn súng hoặc thêm nhiều câu đố để tạo độ khó.

| Mục tiêu | Cách thể hiện | Dấu hiệu chưa đạt |
| --- | --- | --- |
| Đặc trưng rõ | Một chặng dùng màn che có quan sát, thao tác và xử lý tuần tra | Có thiết bị nhưng chạy thẳng vẫn dễ dàng vượt qua |
| Khó nhưng hiểu được | Có tiếng bước chân, hình ảnh lệch và vật che có thể đọc bằng mắt | Bị bắt do một ngưỡng ẩn hoặc lính xuất hiện sau lưng |
| Thế giới đáng tin | Lính phát hiện phần người, khung màn hoặc tiếng động thực sự quan sát được | Lính bỏ qua mặt sau thiết bị ngay trước mắt |
| Chơi lại tốt | Tuyến tuần tra có quy luật; điều tra và lựa chọn tạo biến động | Lần nào cũng có sự cố bắt buộc tại cùng một bước |
| Kế thừa V5 | Giữ hai đường rút, 120 giây và phá hoại tùy chọn | Lượt chơi mới làm một đường rút không còn khả thi |

Mục tiêu thời lượng: lần đầu khoảng **12–18 phút**, đã biết đường khoảng **7–10 phút**. Đoạn màn che dự kiến 2–4 phút ở lần đầu, 45–90 giây khi đã thành thạo. Đây là mục tiêu thiết kế cần đo lại, không dùng để ép người chơi chờ đủ thời lượng.

## 2. Phạm vi và quyết định mặc định

### Giữ lại từ bản hiện tại

- Khuôn viên 96 × 108 m, các khu chức năng trên mặt đất, hai cầu thang và hai điểm tập kết.
- Thẻ thông hành, chỉ dẫn và mã cửa B1; camera, nguồn chính/dự phòng, nhật ký và chai gây tiếng động.
- Hai dải cảm biến trước khu hồ sơ, bố trí lại khi cần nhưng giữ tín hiệu xanh/vàng/đỏ dễ hiểu.
- Mở niêm phong hồ sơ bằng giữ E 3,5 giây; chỉ hoàn tất thao tác mới bắt đầu 120 giây.
- Chuẩn bị cửa hậu, hai đợt tiếp viện và nhiệm vụ phá hoại V5.
- Minimap vị trí thật, bản test không lính và các sửa chữa gá đỡ/hình học đã có.

### Bổ sung cho V6

- Một hành lang an ninh có hốc chuẩn bị, hai vị trí dừng che thật và phòng hồ sơ bên hông.
- Một bộ màn che cơ động, cấp sẵn như trang bị nhiệm vụ; không chiếm ba ô hành trang.
- Một lính giữ chốt và một tuyến tuần tra bên hông, dùng nền AI chung của nhóm.
- Trạng thái hiệu chỉnh thiết bị, dấu hiệu lộ thiết bị và phản ứng điều tra tương ứng.
- Checkpoint trước đoạn màn che và đường rút từ phòng hồ sơ được kiểm tra lại.

### Giới hạn đợt đầu

- Chọn một người chơi; Lam hỗ trợ bằng lời thoại và hiệu chỉnh, không điều khiển nhân vật thứ hai.
- Chỉ hiệu chỉnh cho **một vị trí quan sát chính**. Không tạo khả năng ngụy trang từ mọi hướng.
- Chưa thêm pin cạn, đạn, chiến đấu, nhảy, leo trần, phá cửa bằng bom hoặc tài nguyên phải nhặt thêm.
- Tuyến tuần tra có quy luật; chưa thêm ngẫu nhiên vào lịch đi và thời điểm quay đầu.
- Chưa thêm phòng đầu quét hoặc khu điều phối A/B. Sau khi đoạn màn che đạt yêu cầu mới cân nhắc mở rộng.
- Giữ tổng sáu lính thường trực và tối đa bốn tiếp viện làm ngân sách ban đầu. Ưu tiên phân công lại lính hiện có; chỉ thay đổi số lượng sau khi đo ảnh hưởng đến toàn map.

## 3. Luồng chơi hoàn chỉnh

```text
Vành đai → thâm nhập → thẻ + thông tin truy cập
                     ↘ chuẩn bị cửa hậu / ngắt camera, tùy chọn
        → checkpoint khu mật → giải mã cửa B1 → qua cảm biến
        → hốc quan sát + checkpoint trước màn che
        → triển khai → tiến/dừng qua hai vị trí che → phòng hồ sơ
        → lấy Mật lệnh 04 → báo động 120 giây
        → chọn đường sân hoặc bảo trì → phá hoại tùy chọn → tập kết
```

### Chặng 1 — Nhận nhiệm vụ và thâm nhập

An bắt đầu ngoài vành đai. Lam giới thiệu ba điều trong khi người chơi vẫn được di chuyển: hồ sơ ở B1, tháo niêm phong gây báo động độc lập, màn che chỉ đánh lừa người quan sát ở hướng phù hợp.

Người chơi chọn lối sân/nhà xe phía tây hoặc hậu cần phía đông. Quan sát camera và tuần tra, tận dụng vật che có sẵn. Chưa có đồng hồ tổng cho giai đoạn này.

Lời thoại mẫu: “Mật lệnh ở kho B1. Chuẩn bị đường ra trước khi lấy. Bộ màn che chỉ giữ được hình ảnh từ một hướng; người đi tuần vẫn là nguy cơ.”

### Chặng 2 — Lấy quyền truy cập và tự chuẩn bị lợi thế

Lấy thẻ ở phòng trực và đọc chỉ dẫn tại bàn vô tuyến theo bất kỳ thứ tự nào. Sau đó đến checkpoint khu mật, đối chiếu bảng ca trực với nhật ký và nhập mã B1. Giữ cơ chế sai mã/khóa tạm hiện có; chưa mở đồng hồ 120 giây tại đây.

Trước khi xuống B1, có thể ngắt camera chính, chuẩn bị chốt cửa hậu và nhận biết tủ mục tiêu phá hoại. Ghi rõ camera sẽ có nguồn dự phòng sau khi lấy hồ sơ. Không yêu cầu hoàn thành các việc tùy chọn để được triển khai màn che.

### Chặng 3 — Quan sát bài toán B1

Sau cửa B1, vượt hai dải cảm biến đến hốc chuẩn bị có tường che thật. Đây là checkpoint mới trước đoạn đặc trưng; checkpoint cũ trước keypad vẫn tồn tại để bảo toàn chuỗi nhiệm vụ.

Từ hốc, người chơi nhận biết được hướng đứng chốt, cửa nhánh tuần tra, hai vị trí dừng và cửa phòng hồ sơ. Có thể quan sát một vòng tuần tra trước khi bắt đầu. Bảng hướng dẫn và giá thiết bị gắn lên cấu kiện thật, không treo giữa khoảng trống.

Lam nhắc một lần: “Đừng chỉ nhìn người cuối hành lang. Khi tuần tra tới cửa bên, cả cậu lẫn khung màn phải khuất.”

### Chặng 4 — Triển khai và vượt hành lang

Giữ E tại vị trí chuẩn bị để dựng thiết bị và hoàn tất hiệu chỉnh ban đầu. Người chơi được kiểm tra một đoạn ngắn trong vùng có che trước khi đẩy ra hành lang. Nhấn E ở tay đẩy để nắm; sau đó di chuyển bằng WASD và quan sát bằng chuột.

Chặng tiến gồm hai lần chuyển vị trí chính: hốc chuẩn bị → hốc dừng thứ nhất → vị trí sát cửa hồ sơ. Người chơi tự chọn thời điểm, có thể dừng hoặc lùi. Thiết bị giữ hướng chiếu bằng cơ cấu ổn định; nhìn sang bên không tự xoay màn theo đầu nhân vật.

Trong lúc tiến, tuần tra bên hông đi theo tuyến thật. Nếu nghe bước chân khi còn ở hốc, có thể chờ. Nếu đã ra đoạn hở, cần chọn tới vị trí che kế tiếp hoặc lùi, dựa trên thời gian và khoảng cách còn lại. Màn chiếu không triệt tiêu tiếng va bánh xe hoặc tiếng người chạy.

Lính đứng chốt vẫn quan sát, nghe và điều tra. Người chơi làm lộ chân/tay, đẩy lệch khỏi góc hiệu chỉnh hoặc để khung màn bị nhìn từ bên sẽ tạo nguy cơ có nguyên nhân cụ thể. Không cài một lần hỏng thiết bị bắt buộc trong mọi lượt.

### Chặng 5 — Vào phòng hồ sơ, chuẩn bị khoảnh khắc lấy tài liệu

Cửa hồ sơ nằm bên hông, trước vị trí lính giữ chốt. Tại vị trí cuối có góc tường và khoang đỗ đủ để An rời tay đẩy, mở cửa rồi vào phòng mà không lộ người. Cánh cửa nằm sau góc khuất; tiếng mở cửa vẫn theo luật âm thanh.

Bên trong, người chơi nhìn thấy tủ hồ sơ, cảnh báo niêm phong và sơ đồ hai hướng thoát. Cửa kỹ thuật dùng để rút chỉ mở sau khi có hồ sơ, tránh đường tắt bỏ qua đoạn thâm nhập. Không thêm lần nhập mã thứ hai.

Lam: “Tháo niêm phong là bắt đầu hai phút. Nhìn đường ra lần cuối. Không cần mang bộ màn về.”

Giữ E 3,5 giây để lấy. Nhả E, mất tiêu điểm, rời tầm hoặc tạm dừng thì hủy tiến trình theo cơ chế hiện tại. Chỉ khi hoàn tất mới có tài liệu và chạy lịch báo động.

### Chặng 6 — Báo động và rút lui

Tại T+0, người chơi giữ toàn quyền điều khiển. Lính nhận thông tin báo động và tìm tới nơi xảy ra sự kiện theo luật AI; không tự biết tọa độ hiện tại của An. Người giữ chốt có thể rời vị trí khiến hiệu chỉnh màn không còn phù hợp. Thiết bị có thể bỏ lại trong khoang đỗ, không trở thành điều kiện thắng.

Từ phòng hồ sơ có lối thoát nối tới ngã rẽ cho hai hướng: quay về tuyến cầu thang chính hoặc đi hành lang bảo trì/cầu thang thứ hai. Không buộc người chơi chen qua người giữ chốt hoặc đẩy lại màn trên toàn đoạn vừa đi. Đường sân vẫn phải vượt các nguy cơ trên mặt đất và lịch đóng cổng.

Phá hoại giữ vai trò tùy chọn: tại xưởng phía đông, giữ E 5 giây để đặt thiết bị rồi tiếp tục rút. Không cộng thời gian. Nếu thông báo khẩn đang phát, lời nhắc phá hoại chờ hoặc bỏ qua; tránh che cảnh báo cổng và đồng hồ.

### Chặng 7 — Kết quả và thử lại

- Đến vùng tập kết với hồ sơ trước thời hạn: hoàn thành mục tiêu chính.
- Đã đặt thiết bị và thoát hợp lệ: chạy đoạn kết phá hoại V5, sau đó ghi thành tích bổ sung.
- Bỏ qua phá hoại vẫn hoàn thành nhiệm vụ chính bình thường.
- Bị bắt hoặc hết giờ: về checkpoint hợp lệ trước khi lấy hồ sơ; giữ kiến thức nhật ký, khôi phục thế giới và trang bị theo snapshot.

Không mở phần chơi tiếp theo hoặc bắt làm map khác để hoàn tất K17.

## 4. Mặt bằng B1 và tính hợp lý của không gian

### Quan hệ giữa các khu

```text
Cầu thang chính → cảm biến → hốc chuẩn bị / checkpoint
                                     │
                         hành lang do lính đứng chốt quan sát
                                     │
                            hốc dừng 1 ├── cửa nhánh tuần tra / vòng đi thật
                                     │
                            hốc dừng 2 ├── cửa phòng hồ sơ, nằm sau góc tường
                                     │          │
                                người giữ chốt  └── cửa thoát sau khi có hồ sơ
                                                     │
                                    ngã rẽ → cầu thang chính / bảo trì
```

Sơ đồ thể hiện quan hệ, chưa phải bản vẽ theo tỉ lệ. Phải khảo sát bằng bản dựng hình khối trước khi chốt tọa độ.

B1 hiện có phòng kho khoảng 20 × 16 m và một hành lang phía đông. Chưa có đủ cấu trúc cho toàn bộ tình huống mới. Cho phép **mở rộng có giới hạn một nhánh B1**, ưu tiên trong khuôn viên hiện tại, thay vì kéo dài toàn bộ khu quân sự. Cần kiểm tra chồng lấn cầu thang, sàn tầng trệt, vách và tuyến rút trước khi chọn hướng mở rộng.

Thông số khảo sát: hành lang rộng khoảng 2,6–3,2 m; phần cần vượt nằm trong tầm quan sát thực của người giữ chốt, khoảng 8–12 m. Hốc dừng khởi điểm khoảng 2,4 × 2,5 m nhưng kích thước cuối phải đủ cho toàn bộ thiết bị, người và khoảng thao tác. Không tạo hành lang quá xa khiến lính có tầm nhìn 14 m không thể phát hiện từ đầu.

### Điều kiện bắt buộc khi bố trí

1. Cả An và khung/bánh/mặt sau màn phải khuất khỏi tuyến bên khi đỗ đúng hốc. Đo bằng tia nhìn nhiều điểm và kiểm tra ảnh từ mắt lính.
2. Người giữ chốt nhìn được đoạn vượt quan trọng. Quét đầu ngắn không được tạo cửa sổ đủ chạy qua toàn chặng một cách dễ dàng. Lối giải sáng tạo bằng phân tâm có rủi ro vẫn được chấp nhận, không đặt cờ nhiệm vụ ép phải nhấn nút thiết bị.
3. Cửa phòng hồ sơ mở sau một góc tường, có đủ chỗ đứng ngoài cung quét của cửa. Tường thật che chuyển động cánh cửa và người đi qua.
4. Lối bảo trì trước hồ sơ không được trở thành cửa sau đi thẳng tới tài liệu. Khóa theo trạng thái hồ sơ bằng cơ chế hiện có, có biển giải thích.
5. Khi báo động, ít nhất một lối rời phòng hồ sơ luôn có khoảng đi hợp lệ; cả hai hướng tập kết phải được chứng minh bằng lượt chơi đầy đủ.
6. Màn đỗ ngoài cung cửa và đường chạy. Collider của người, xe đẩy và lính không khóa cứng nhau ở ngã rẽ.
7. Sàn/trần/ống/dây/bảng/camera có cấu kiện đỡ và mối nối thật. Mở rộng B1 phải cập nhật ánh sáng, navigation và sơ đồ minimap cùng một đợt.

## 5. Thiết bị và điều khiển

Thiết bị là một màn chiếu gấp có khung, bánh xe và cụm cảm biến, lấy ra từ trang bị nhiệm vụ tại hốc chuẩn bị. Không bắt người chơi kéo xe từ ngoài vành đai xuống cầu thang. Chỉ triển khai tại khu có mốc hiệu chỉnh B1; không biến thành tấm khiên mang đi toàn map.

### Thao tác đề xuất

| Tình huống | Điều khiển | Quy tắc |
| --- | --- | --- |
| Dựng/thu tại điểm có khoảng trống | Giữ E khoảng 2 giây | Hủy đúng luật giữ tương tác; không thu xuyên người hoặc tường |
| Nắm hoặc thả tay đẩy | Nhấn E tại tay đẩy | Nắm là một chế độ riêng, không phải giữ E và nhìn cố định liên tục |
| Tiến/lùi/chỉnh ngang khi đang nắm | WASD | Theo trục xe và giới hạn vật lý, không đổi hướng theo góc nhìn chuột |
| Quan sát chốt/tuần tra | Chuột | Nhìn tự do; thân người vẫn phải nằm trong vùng che thật |
| Cúi | C/Ctrl | Giữ hành vi quen thuộc nếu khoảng tay cầm cho phép; kiểm tra chiều cao cơ thể và camera |
| Chạy hoặc ném chai khi đang nắm | Shift/F | Chưa cho thực hiện khi hai tay bận; nhắc thả tay đẩy trước |
| Nhật ký/minimap/tạm dừng | J/M/Esc/P | Giữ phím hiện tại; mở giao diện làm xe dừng an toàn |

Vận tốc đẩy khởi điểm **0,6–0,8 m/s**, lùi khoảng 0,5 m/s; giới hạn chỉnh ngang nhỏ để giữ hình ảnh khớp. Không thêm nút phải giữ theo nhịp, thanh cân bằng liên tục hoặc thao tác phối hợp nhiều phím ở đợt đầu.

Xe và người di chuyển bằng kiểm tra va chạm thực. Không kéo người bằng teleport/tween xuyên cửa; không vô hiệu collider để giải quyết kẹt. Khi một trong hai vướng vật cản, cả thao tác phải dừng có kiểm soát, không đẩy lính ra khỏi đường.

Thả tay không tự thu màn. Màn đứng ở vị trí đã dừng; người chơi bước ra ngoài phạm vi che thì có thể bị thấy. Khi vào phòng hồ sơ, khoang đỗ cuối đủ chỗ bỏ lại thiết bị. Nếu thiết bị nằm sai vị trí, cho lùi/thu khi đủ khoảng trống; không tự dịch chuyển qua lính để mở đường rút.

### Hiệu chỉnh hình ảnh

- Dùng một vùng góc hẹp quanh vị trí người giữ chốt; khởi điểm khoảng ±10–12°, khoảng cách làm việc khảo sát 5–14 m.
- Góc đầu lính, vị trí mắt, mặt màn và các phần cơ thể phải cùng được tính. Chỉ xoay mô hình đầu mà tầm nhìn vẫn hướng khác là lỗi.
- Từ mắt người giữ chốt, mặt chiếu phải phủ được hình dáng phần thiết bị cần giấu, gồm chân đế/bánh khi chúng nằm trong đường nhìn. Bộ phận nhô khỏi mép chiếu vẫn là bằng chứng thật, không được gán ẩn chỉ vì thiết bị đang bật.
- Trạng thái xanh: khớp trong điều kiện hiệu chỉnh; vàng: gần giới hạn hoặc đang dịch chuyển làm lệch; đỏ: mất hiệu chỉnh.
- Cảnh báo đo từ điều kiện thật. Không thêm thời gian miễn phát hiện sau khi cơ thể đã lộ; tốc độ tích phát hiện của AI tạo cơ hội phản ứng như hiện tại.
- Không có pin cạn ở đợt đầu. Áp lực đến từ vị trí, thời điểm, tiếng động và người quan sát.

## 6. Luật AI và bị lộ

### Tách ba điều lính có thể nhận thấy

**Thấy An:** dùng FOV, tầm nhìn, raycast tới các điểm cơ thể và thanh phát hiện hiện có. Màn là một vật thể có bề mặt che thật; lính vẫn thấy được phần người nhô khỏi mép hoặc khi đi vòng qua. Không cho lính nhìn xuyên tấm màn đặc để trừng phạt người chơi.

**Thấy thiết bị đáng ngờ:** bổ sung quan sát nhiều điểm trên khung, bánh và mặt sau. Hình chiếu hợp lệ chỉ che giấu dấu hiệu thiết bị đối với người quan sát đã hiệu chỉnh. Nhìn từ bên, phía sau, khi tắt hoặc khi hình lệch phải tạo nghi vấn tại **vị trí thiết bị được thấy**, dù An vẫn đang khuất sau nó.

**Nghe tiếng động:** giữ hệ âm thanh có khoảng cách và vật cản. Va chạm xe hoặc hành vi của An có thể khiến lính điều tra. Thiết bị không xóa trí nhớ hoặc hủy truy đuổi đã có.

Việc màn chắn tia nhìn chưa đủ tạo cơ chế ngụy trang: nếu chỉ có collider, nó sẽ thành vật che mà lính luôn bỏ qua. Điều kiện nghiệm thu là lính nhận biết và tiếp cận một tấm màn đáng ngờ, sau đó có thể vòng qua nhìn thấy An. Ngược lại, chỉ thấy thiết bị không được gán thành “đã nhìn thấy An” và truyền tọa độ người chơi cho cả đội.

### Vai trò và ưu tiên

| Đối tượng | Trạng thái bình thường | Khi có bất thường | Sau khi lấy hồ sơ |
| --- | --- | --- | --- |
| Người giữ chốt | Giữ vị trí, quét nhìn ngắn, kiểm soát hành lang | Xác minh dấu hiệu; có thể rời chốt điều tra | Phản ứng với nguồn báo động, tham gia tìm kiếm |
| Tuần tra bên hông | Đi vòng có quy luật, nhìn vào hành lang tại cửa bên | Thấy khung/mặt sau thì điều tra vị trí đó; thấy An thì theo AI chung | Tiếp tục theo luật truy lùng và thông tin đã nhận |
| Lính khác/tiếp viện | Giữ phạm vi hiện tại | Nghe/thấy/báo động hợp lệ mới phản ứng | Giữ lịch xuất hiện và cơ chế an toàn hiện có |

Ưu tiên: xác nhận thấy An → truy đuổi; mất dấu → tìm theo vị trí biết lần cuối; chưa thấy người nhưng có bằng chứng thiết bị/tiếng động → điều tra; hết nghi vấn → trở lại nhiệm vụ giữ chốt hoặc tuần tra. Người giữ chốt không bị đóng băng perception để đứng yên.

Ngưỡng khảo sát cho dấu hiệu thiết bị: lộ rõ liên tục khoảng 0,5–1 giây thì biểu lộ nghi vấn, tiếp tục thấy thì tiến kiểm tra. Mức nghi vấn giảm khi khuất nhưng không xóa ngay ký ức vừa quan sát. Thời gian này cần thử ở tốc độ tuần tra thật; không tự biến thành khoảng miễn trừ cho việc An lộ người.

Tuyến bên dự kiến khoảng 25–40 giây một vòng, có bước chân không gian báo trước cửa nguy hiểm. Bố trí âm thanh/đường đi để có khoảng phản ứng ít nhất 3 giây trước lần nhìn bên quan trọng, trong điều kiện bình thường. Không phát câu “lính đang đến” nếu người lính thực tế đã rời tuyến để điều tra nơi khác.

Ở lần dựng đầu, đặt camera hiện có ngoài khu màn che. Nếu góc camera có thể nhìn thấy thiết bị trong mặt bằng cuối, phải bổ sung quy tắc nhận diện tương ứng hoặc điều chỉnh vị trí có lý do; không để collider vô tình vô hiệu camera.

## 7. HUD, âm thanh và chất lượng hình ảnh

### Thông tin cần thấy

- Mục tiêu ở hốc chuẩn bị: “Quan sát chốt gác, triển khai màn che và tiếp cận phòng hồ sơ”.
- Một chỉ báo nhỏ khi gần/đang dùng thiết bị: **khớp hình / gần lệch / lệch hình**, kèm câu ngắn chỉ nguyên nhân.
- Ghi rõ “Che hướng chính” để người chơi hiểu phạm vi; trạng thái đó không thay thế thanh bị phát hiện của AI.
- Chỉ hiện nhắc E ở tay đẩy hoặc điểm dựng; không để cả dãy nút lơ lửng quanh màn.
- Minimap vẫn theo Player thật, phân tầng đúng; không dùng tâm xe làm vị trí An và không thêm dấu lính xuyên tường.
- Mở nhật ký, pause, bị bắt, thắng hoặc cảnh kết: dừng thao tác đẩy, ẩn thành phần không phù hợp và trả chuột đúng trạng thái.

Âm thanh ưu tiên bước chân có vị trí, tiếng bánh/va chạm vừa đủ nghe, một tiếng báo hiệu chỉnh mất và lời Lam ngắn theo sự kiện. Có phụ đề; trạng thái thiết bị dùng chữ/biểu tượng bên cạnh màu. Lời thoại không được trở thành máy báo tọa độ tuần tra mà An không thể biết.

### Cách dựng hiệu ứng

Ưu tiên một `SubViewport` và camera dựng góc hành lang trống, ánh xạ lên mặt màn theo góc hiệu chỉnh. Dùng culling layer riêng để bản chiếu không chứa An, lính hoặc chính màn, tránh tự lặp hình. Không tắt/bật hiển thị cả nhân vật trong thế giới chính mỗi lần chụp.

Khởi điểm 512 × 512 hoặc kích thước tương đương theo tỉ lệ mặt màn, cập nhật khoảng 10–15 lần/giây khi đang hoạt động; tắt cập nhật khi thu, ngoài khu, pause hoặc kết thúc. Chỉ một góc chiếu, không thêm camera minimap 3D hoặc nhiều pass hiệu ứng.

Thử trước khả năng khớp sàn, đường tường và độ sáng từ mắt người giữ chốt. Nếu hiệu ứng bị “tấm ảnh dán” rõ rệt hoặc tốn tài nguyên, sửa camera/UV, giảm vùng góc cho phép, giảm độ phân giải và cache phần nền tĩnh. Không tiếp tục làm cảnh lớn khi phần cốt lõi chưa thuyết phục.

Khung có chân/bánh tiếp đất, màn có mặt sau và tay cầm, dây đi tới vỏ thiết bị. Tường B1 có công năng: ống, tủ kỹ thuật, giá hồ sơ và đèn gắn thật. Giữ chi tiết chính có thể đọc trong bóng tối; ánh sáng cảnh báo không được che mất vật cản hoặc tín hiệu cảm biến.

## 8. Báo động, đường rút và checkpoint

### Giữ lịch báo động V5 làm mốc ban đầu

| Tính từ lúc lấy hồ sơ | Sự kiện |
| --- | --- |
| T+0 | Đèn/còi, cửa hậu khóa cơ, bắt đầu 120 giây |
| T+10 | Đợt tiếp viện thứ nhất: hai lính |
| T+15 | Nguồn dự phòng cấp lại camera |
| T+45 | Đợt tiếp viện thứ hai: hai lính |
| T+70 | Cảnh báo cổng sân sắp đóng |
| T+90 | Cổng sân đóng theo cơ chế an toàn hiện có |
| T+100 | Tín hiệu loa/chốt phía đông, nhắc thời gian còn lại |
| T+120 | Thất bại nếu chưa tập kết hợp lệ |

Tiếp viện giữ grace xuất hiện 8 giây và kiểm tra vị trí an toàn. Không sinh lính ngay trong tầm nhìn hoặc trên đầu người chơi để tăng kịch tính. Cổng giữ quy tắc tránh kẹp người ở ngưỡng; mở rộng B1 không làm thay đổi ngầm các điều kiện này.

Đo lại toàn tuyến bằng đi bộ thật ở bản có AI: hướng sân phải kịp cổng T+90 khi đi đúng nhịp; hướng bảo trì phải còn dư địa xử lý chốt và một lần né tuần tra trước T+120. Nếu có phá hoại, tính đủ 5 giây đặt thiết bị và hành trình tới tủ. Mục tiêu khảo sát là còn 15–25 giây ở một lượt rút cơ bản đã biết đường, thay vì chỉ vừa đủ thắng khi chạy tối ưu từng bước.

Không khẳng định mọi tổ hợp phá hoại/đường rút/chuẩn bị đều dễ thắng. Tuy nhiên, mỗi hướng tập kết cần có ít nhất một phương án hợp lệ và có thể lặp lại; hướng bảo trì kèm phá hoại cần có một lộ trình đã kiểm chứng. Nếu tuyến sân không hợp lý để ghé xưởng, mô tả rõ rủi ro thay vì ép cân bằng hai lựa chọn giống nhau.

### Lưu và khôi phục

- Giữ checkpoint khu mật trước keypad. Checkpoint mới ở hốc chuẩn bị chỉ kích hoạt sau khi mở B1, trước hồ sơ và ngoài tình trạng truy đuổi/bị bắt.
- Sau khi có hồ sơ, không ghi đè checkpoint trước nhiệm vụ bằng trạng thái báo động.
- Snapshot mới khôi phục màn về vị trí chuẩn bị an toàn, chưa nắm tay đẩy; Player có lại điều khiển. Không lưu hồi sinh vào giữa một lần đẩy đang bị nhìn.
- Lưu trạng thái có ý nghĩa: thiết bị được cấp, vị trí chuẩn, mốc nhiệm vụ và thiết lập thế giới. Không đưa bộ đếm cập nhật liên tục vào so sánh snapshot khiến checkpoint lưu mỗi frame.
- Khôi phục/reset phải xóa nghi vấn thiết bị, hiệu chỉnh cũ, người đang nắm, âm thanh hẹn, lời thoại và sự kiện của lượt trước bằng `run_id` hoặc cơ chế tương đương.
- Cửa, điện, cảm biến, khoang đỗ, vai trò lính và tiếp viện trở lại trạng thái nhất quán. Nhật ký giữ kiến thức như hiện tại.

### Chế độ không lính

Cùng hình học, thiết bị, HUD, cảm biến, keypad, nhiệm vụ, hai đường rút và phá hoại. Tắt cả lính thường trực lẫn tiếp viện. Màn vẫn thao tác và xem hiệu ứng được; không có mục tiêu phụ thuộc vào một lính không tồn tại làm khóa hồ sơ. Có thể đi thẳng để kiểm tra map.

Hiệu chỉnh ở bản không lính dùng mốc mắt tham chiếu cố định tại chốt, chỉ phục vụ dựng ảnh và hướng dẫn thử thiết bị. Không sinh một NPC ẩn hoặc để một tham chiếu guard rỗng làm hỏng thiết bị. Trong bản thường, trạng thái hợp lệ phải theo mắt người quan sát thật.

Bài thử có lính mới dùng để kết luận độ khó và khả năng đánh lừa; bản không lính phục vụ kiểm tra mặt bằng, thao tác và đường đi.

## 9. Tổ chức kỹ thuật dự kiến

Mọi tên file mới dưới đây là đề xuất để triển khai, chưa phải file đã có. Các phần gameplay riêng của K17 đặt trong `maps/intelligence/`; tái sử dụng điều khiển, tương tác, HUD và AI nền của nhóm.

| Nhóm | Vị trí dự kiến | Trách nhiệm |
| --- | --- | --- |
| Thông số và mặt bằng | `resources/layout/k17_projection.gd` mới, `k17_layout.gd` hiện có | Mốc chuẩn, vùng góc, kích thước, pose đỗ, hốc và tuyến đi; dùng chung cho builder/runtime/test |
| Dựng khu B1 | `tools/k17_projection_builder.gd` mới, nối vào `tools/build_k17.gd` | Cảnh hình khối, tường/cửa/vật che, nội thất, đường rút và bố trí vai trò |
| Thiết bị | `scenes/equipment/projection_rig.tscn`, `scripts/projection_rig.gd` mới | Hình ảnh, collider, triển khai/thu, trạng thái và checkpoint |
| Đẩy thiết bị | `scripts/projection_player.gd` mới | Chế độ nắm, input tương đối với xe, nhìn tự do và di chuyển có va chạm |
| Tái tạo hình ảnh | `scripts/projection_view.gd`, shader/resource riêng mới | Camera chiếu, UV, hiệu chỉnh, culling và ngân sách render |
| Nhận diện bằng chứng | `scripts/projection_observer.gd` mới | Từng người quan sát kiểm tra thiết bị, FOV/raycast, góc hợp lệ và nghi vấn |
| Vai trò giữ chốt | `scripts/projection_guard.gd` mới | Giữ/quay về chốt, điều tra bằng chứng, chuyển tiếp AI nền |
| Tích hợp nhiệm vụ | `scripts/mission_controller.gd`, `mission_checkpoint.gd` hiện có | Mục tiêu, lời Lam, cổng thoát, snapshot, không đổi điều kiện bắt đầu 120 giây |
| Giao diện và sơ đồ | HUD K17, `scripts/stealth_director.gd`, minimap builder hiện có | Hiển thị trạng thái thật, không ghi đè việc AI khác nhìn thấy, cập nhật B1 |
| Kiểm tra và bằng chứng | `tools/check_projection.gd`, bài walking E2E và `docs/gameplay-v6/VALIDATION.md` mới | Kiểm tra điều kiện, ảnh, số đo thời gian/hiệu năng và kết quả chơi |

### Điểm tích hợp cần xử lý có chủ đích

**Điều khiển:** `FirstPersonPlayer` hiện tự tính vận tốc từ góc nhìn ở mỗi physics frame. Không gắn thêm script kéo transform song song với nó. Dựng một lớp K17 kế thừa hoặc một điểm mở rộng opt-in để thay phần tính vận tốc/nhìn khi đang nắm xe; giữ một nơi quyết định di chuyển cuối cùng. Cách chọn cuối phải qua thử va chạm và không làm thay đổi điều khiển các map khác.

**Tương tác:** `PlayerInteractor` hiện hủy hold khi nhìn khỏi vật. Vì người chơi phải nhìn sang tuần tra, chỉ dùng hold để dựng/thu; nắm tay đẩy là chế độ riêng. Tạm dừng, mở giao diện, mất trạng thái PLAYING hoặc đổi scene phải dừng và giải phóng chế độ này an toàn.

**AI:** `GuardVision` hiện kiểm tra các điểm cơ thể của Player; chưa có nhận diện thiết bị. Giữ nền này, thêm bằng chứng riêng cho K17. `GuardPerception` hiện có dữ liệu thấy người và nghe âm thanh, chưa có bằng chứng thị giác về vật thể. Nếu lớp K17 không thể chuyển tiếp điều tra bằng một giao diện sạch, thêm một trường bằng chứng tùy chọn vào perception/state machine, mặc định tắt và kiểm tra lại map thư viện. Không giả làm tiếng động hoặc xác nhận thấy Player chỉ để ép AI tới thiết bị.

**Vật lý/navigation:** vật thể đẩy có collider che thật; vision cần thấy vật che khi raycast. Phần nhận diện thiết bị kiểm tra điểm trên bề mặt, loại chính collider của thiết bị khỏi tia xác minh khi cần, vẫn tôn trọng tường che. Lính điều tra tới điểm tiếp cận bên ngoài xe, có khả năng đi vòng; không chọn đích ở bên trong collider. Chỉ dùng avoidance không đủ thay thế kiểm tra đường đi khi xe chặn tuyến.

**Sinh cảnh:** map có builder sinh nhiều phần. Thay đổi cấu trúc phải vào builder và dữ liệu nguồn, tránh chỉnh scene sinh ra rồi lần dựng kế tiếp mất sửa. Sau thay B1 cần sinh lại navigation, lightmap và minimap, kiểm tra scene thường/test kế thừa cùng nội dung.

## 10. Các mốc triển khai và điều kiện chuyển bước

Chia theo kết quả có thể chơi thử; chưa ấn định ngày hoàn thành khi chưa vượt rủi ro hình ảnh và AI. Mỗi mốc cần có phiên bản chạy được, ghi rõ điều gì chưa hoàn tất.

| Mốc | Công việc | Kết quả để người dùng thử | Điều kiện chuyển bước |
| --- | --- | --- | --- |
| M0 — Chốt mặt bằng | Đo B1, dựng khối hành lang/hốc/phòng và hai đường rút; đặt vai trò lính | Đi bộ cả tuyến, nhìn từ mắt người giữ chốt/tuần tra | Cửa, khoảng che, cung quay và hai hướng thoát có chỗ thật; không có đường tắt vô ý |
| M1 — Màn che tối thiểu | Dựng/thu/nắm/đẩy, va chạm, một người giữ chốt, hiệu ứng chiếu và nhận biết thiết bị | Thử tiến/lùi, lộ mép người, tắt màn, lệch góc | Thủ thuật nhìn thuyết phục ở vùng cho phép; màn đáng ngờ bị kiểm tra; hiệu năng chấp nhận được |
| M2 — Tuần tra và lựa chọn | Tuyến bên, hai hốc, âm thanh báo trước, quay về chốt và điều tra | Vượt hành lang hoàn chỉnh trước hồ sơ | Có thể tiến/dừng/lùi theo dấu hiệu thật; cả thiết bị lẫn người được che ở hốc; không cần may rủi |
| M3 — Một lượt nhiệm vụ | Tích hợp hồ sơ, checkpoint, báo động, hai đường rút và V5 | Chơi từ menu tới kết quả ở cả bản thường/test | Không khóa nhiệm vụ, reset sạch; chứng minh hướng sân và bảo trì có thể thắng |
| M4 — Hoàn thiện cảnh/HUD | Nội thất, gá đỡ, ánh sáng, animation, phụ đề, minimap và chất lượng ảnh | Bản gần hoàn thiện ở nhiều độ phân giải | Không nổi đồ, không hở sàn/ống, đọc được nguy cơ và lời nhắc; không tụt hiệu năng quá mục tiêu |
| M5 — Nghiệm thu | Regression, E2E đi bộ thật, thử thủ công, profile và gói bàn giao | Bản V6 cùng hướng dẫn tự test và báo cáo | Đạt ma trận dưới, ghi rõ giới hạn còn lại và bằng chứng |

**Ưu tiên đầu tiên là M0–M1.** Nếu màn không thuyết phục hoặc AI bỏ qua khung lộ, sửa nguyên mẫu trước khi làm thêm phòng, hội thoại và trang trí. Nếu cơ động quá khó vận hành, trình một phương án điều khiển đơn giản hơn để trao đổi; không âm thầm thay thành thiết bị tàng hình toàn hướng.

## 11. Ma trận kiểm thử và tiêu chí nghiệm thu

### Cơ chế cốt lõi

| Nhóm | Trường hợp tối thiểu | Kết quả đúng |
| --- | --- | --- |
| Góc hợp lệ | Đứng sau màn, khớp hình, người giữ chốt nhìn thẳng | Không tích phát hiện An nếu mọi điểm cơ thể khuất; không điều tra thiết bị khi hình hợp lệ |
| Mất hiệu chỉnh | Tắt thiết bị, xoay lệch, người giữ chốt rời vùng | Nhận thấy thiết bị bất thường khi có đường nhìn; báo nguyên nhân đúng |
| Cơ thể lộ | Bước ngang, đứng/cúi, ló chân/tay qua mép | Điểm nhìn lộ làm thanh phát hiện tăng theo luật AI |
| Mặt sau/khung | Tuần tra đi tới cửa bên khi xe còn hở | Phát sinh nghi vấn và tới kiểm tra; không lập tức biết vị trí An sau vật che |
| Che thật | Đỗ cả xe và người trong mỗi hốc | Tường che thực tế khỏi tuyến bên; một phần xe thò ra phải có nguy cơ bị thấy |
| Âm thanh | Va xe, ném chai sau khi thả tay, tiếng cửa | Chỉ người nghe được mới phản ứng; đang chase không tự bỏ mục tiêu vì màn |
| Nhiều quan sát | Chốt bị đánh lừa nhưng người khác thấy An | HUD báo bị thấy đúng; trạng thái màn không ghi đè quan sát khác |
| Vật lý | Tiến/lùi vào cửa, góc tường, lính và xe; thả tay giữa đường | Không xuyên, teleport, kẹp vĩnh viễn hoặc đẩy lính sang vị trí khác |
| Giao diện | Đang đẩy mở J/pause, bị bắt, restart, về menu | Không còn vận tốc/input bị giữ; chuột và HUD trở lại đúng trạng thái |

### E2E nhiệm vụ

1. Bản không lính: đi từ menu tới hồ sơ, thử thiết bị, kết thúc qua từng hướng; không có tiếp viện sinh muộn.
2. Bản có AI: vượt màn theo nhịp tuần tra, lấy hồ sơ và thoát qua sân trước đóng cổng.
3. Bản có AI: rút bảo trì khi đã chuẩn bị cửa hậu và khi chưa chuẩn bị; tính đủ thao tác mở cơ.
4. Bản có AI: hồ sơ → đặt thiết bị V5 → bảo trì → tập kết → cảnh phá hoại.
5. Bỏ phá hoại vẫn thắng; đặt xong nhưng bị bắt/hết giờ không tự cho thành tích phá hoại.
6. Cố tình để lộ xe/người, gây điều tra, bị bắt ở trước và sau hồ sơ; thử lại không mất thiết bị hay giữ tiếp viện cũ.
7. Hủy giữ E trước khi lấy xong không bắt đầu 120; sau FILE mọi checkpoint cũ/mới đều không ghi đè snapshot.
8. Đi qua cảm biến, nhập sai mã, bật lại nguồn dự phòng, gặp cổng đóng và thử các đường tắt từ lối bảo trì.

Các lượt nghiệm thu dùng di chuyển và tương tác thật, có log thời gian/đường đi; không chỉ teleport hoặc set hoàn tất mục tiêu. Chạy lặp một số pha tuần tra khác nhau; ít nhất ba lượt hoàn thành liên tiếp cho lộ trình chuẩn để phát hiện chiến thắng do may mắn. Không yêu cầu mọi lượt đều không bị nghi ngờ, nhưng phải giải thích được nguyên nhân mỗi lần bị lộ.

### Đồ họa, hồi quy và hiệu năng

- Chụp chính diện, cạnh, sau và từ mắt lính ở từng hốc; kiểm tra cả cửa đóng/mở, màn dựng/thu và trạng thái báo động.
- Kiểm tra sàn/ống/biển/đèn/dây/camera có mối nối và vật đỡ; kiểm tra ánh sáng B1 sau khi bake lại.
- HUD ở 1920×1080, 1280×720 và 1024×768, cỡ 100%/125%; không che đồng hồ, minimap hoặc chỉ báo bị phát hiện.
- Regression bộ nền hiện có, script/scene import, art, attachments, navigation, reset và gói chạy. Chỉ sửa số mong đợi khi thay đổi chức năng có lý do; không bỏ assertion cũ để tạo kết quả xanh.
- Nếu chạm mã chung, chạy thêm kiểm tra điều khiển, tương tác và AI của các map khác, đặc biệt thư viện.
- Đo bằng renderer thật trên máy hiện tại, so cảnh tương đương khi hiệu ứng tắt/bật: frame time, FPS thấp, draw calls và bộ nhớ. Mục tiêu ban đầu là chi phí màn khi hoạt động không làm frame time tăng quá khoảng 10%; ưu tiên giữ nhịp chơi ổn định trên máy dùng P1000. Đây là ngưỡng mục tiêu, chưa có số đo V6.
- Giảm cập nhật/độ phân giải/culling trước khi thêm hiệu ứng. Headless test không thay thế kiểm tra chất lượng hình ảnh hoặc GPU.

## 12. Rủi ro và phương án xử lý

| Rủi ro | Cách phát hiện sớm | Hướng xử lý |
| --- | --- | --- |
| Hình chiếu không khớp góc nhìn | Ảnh từ mắt lính ở M1 | Sửa phép chiếu/UV, giới hạn vùng hiệu chỉnh và làm rõ phản hồi; chưa mở rộng cảnh |
| Màn thành vật che vô điều kiện | Tắt màn, đi lộ khung mà AI không phản ứng | Hoàn thiện bằng chứng thiết bị và điểm điều tra; giữ che vật lý đúng nhưng không bỏ qua vật khả nghi |
| Đẩy xe khó chịu hơn thú vị | Thử nhìn quanh, đổi hốc và lùi liên tiếp | Tách nhìn khỏi hướng đẩy, mở rộng khoảng thao tác, giảm số lần phải vi chỉnh |
| Hốc không đủ che hoặc không vừa xe | Raycast nhiều điểm và ảnh từ tuyến tuần tra | Sửa kiến trúc/kích thước trước khi tinh chỉnh thanh phát hiện |
| B1 dài thêm làm 120 giây vô lý | Walking E2E từng đường ở M0/M3 | Rút ngắn phần hành trình không có quyết định, nối đường rút hợp lý; giữ mốc 120 trước khi cân nhắc đổi luật |
| Lính bị kẹt vì thiết bị | Chạy soak điều tra và đi vòng khi xe ở nhiều vị trí | Chọn điểm tiếp cận ngoài collider, giữ hành lang đủ rộng, xử lý trở lại tuyến |
| Reset làm mất đồ hoặc giữ nghi vấn | Bị bắt ở từng trạng thái, thử lại nhiều lần | Snapshot chuẩn, dừng grip/render/timer, xóa bằng chứng theo lượt |
| Bản không lính bị bỏ quên | So sánh cùng seed/cấu hình cảnh và luồng nhiệm vụ | Dùng chung scene/cấu hình, chỉ thay policy sinh AI |

## 13. Bàn giao khi thực hiện xong

- Bản K17 V6 thường và không lính, cùng hướng dẫn mở game và luồng tự test ngắn.
- Kịch bản/hướng dẫn đã cập nhật theo thiết kế thực tế, bảng điều khiển và giới hạn thiết bị.
- Báo cáo `VALIDATION.md` có commit kiểm tra, ảnh, kết quả E2E, thời gian từng đường rút, số đo renderer và lỗi còn lại.
- Danh sách phần hoãn để lần sau bổ sung, tránh lẫn kế hoạch với tính năng đã chạy.

Đã thực hiện theo các mốc M0 → M1 → M2 → M3 → M4 → M5 trên nền `feature/twp`. [Báo cáo nghiệm thu](VALIDATION.md) ghi phạm vi thực tế, các điều chỉnh sau dựng thử và bằng chứng, tách khỏi các mục tiêu thiết kế ban đầu ở trên.
