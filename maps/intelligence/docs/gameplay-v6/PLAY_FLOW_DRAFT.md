# K17 — Luồng chơi để thảo luận: màn che và chốt gác

Ngày: 28/10/2026. **Bản nháp thảo luận, chưa triển khai vào game.**

**Bản phát triển tiếp:** xem [kế hoạch đầy đủ V6](PLAN.md) để đọc quyết định mặc định, điều khiển, luật AI, mặt bằng, các mốc triển khai và tiêu chí nghiệm thu. Tài liệu này giữ lại luồng trao đổi ban đầu; các câu hỏi cuối đã được chuyển thành phương án đề xuất trong kế hoạch, chưa phải tính năng đã thực hiện.

Hướng đã thống nhất: chiến tranh hiện đại hư cấu, một lính đứng chốt kết hợp lính tuần tra, thâm nhập bằng thủ thuật đánh lừa tầm nhìn. Luồng dưới tạm dùng **màn che cơ động, do An đẩy từng đoạn** để hình dung thao tác; cách vận hành thiết bị vẫn cần trao đổi.

Đây là hướng thảo luận mới sau bản [SCENARIO.md](SCENARIO.md). Khu điều phối với hai lệnh lựa chọn và phòng đầu quét trong bản trước vẫn là ý tưởng tham khảo, chưa được chốt để đưa đồng thời vào lượt chơi này.

## 1. Luồng tổng quát

```text
Vành đai
  → thâm nhập, lấy thẻ và thông tin truy cập
  → chuẩn bị đường rút tùy chọn
  → mở cửa B1, tới vị trí quan sát cuối
  → quan sát lính đứng chốt và tuyến tuần tra bên hông
  → triển khai màn che, tiến từng đoạn tới cửa phòng hồ sơ
  → thu hồi Mật lệnh 04
  → báo động, rút trong 120 giây
  → tùy chọn đặt thiết bị phá hoại
  → tập kết, kết thúc.
```

## 2. Bắt đầu — biết mục tiêu và hậu quả

An xuất hiện ngoài vành đai K17. Lam nói ngắn qua vô tuyến trong lúc người chơi được tự quan sát và di chuyển.

**Lam:** “Mật lệnh 04 ở khu lưu trữ B1. Niêm phong có báo động độc lập. Chuẩn bị đường ra trước khi lấy tài liệu. Bộ màn che chỉ giúp cậu qua mắt người đứng chốt; chú ý người đi tuần.”

Người chơi được cấp bộ thiết bị nhiệm vụ từ đầu. Việc triển khai diễn ra ở khu cuối; không thêm một vòng đi tìm nhiều linh kiện vào luồng cơ bản.

Mục tiêu trước mắt: vào cơ sở. Chưa có đồng hồ 120 giây.

## 3. Thâm nhập — tự tìm cách tiếp cận

Hai hướng vào hiện tại vẫn dùng được: sân/nhà xe phía tây và hậu cần phía đông. An quan sát lính tuần tra, chọn vật che và thời điểm đi qua các đoạn hở.

Người chơi lấy giấy thông hành ở phòng trực và đọc chỉ dẫn tại khu vô tuyến. Hai việc có thể đổi thứ tự. Kiến thức thu được giải thích cách vào B1 và vị trí khu hồ sơ.

Mã cửa được xử lý trước đoạn màn che. Khi đã tới sát phòng hồ sơ, người chơi có đủ thông tin truy cập để tập trung vào việc giữ kín hành tung.

Trong giai đoạn này, người chơi có thể ghé trạm điện để ngắt camera chính, chuẩn bị chốt cửa hậu và nhận biết tủ phá hoại trên tuyến rút. Các việc đó giữ vai trò chuẩn bị của V5.

## 4. Vị trí quan sát — nhìn rõ bài toán trước khi làm

Sau khi mở cửa kho B1, An tới hốc chuẩn bị có vật che thật. Tại đây có checkpoint trước đoạn đặc trưng, chỉ kích hoạt hợp lệ trước khi có hồ sơ và khi chưa bị truy đuổi.

Người chơi quan sát được ba thành phần:

- **Lính đứng chốt:** ở cuối hành lang, quan sát dọc theo hướng người chơi cần đi. Vẫn xoay nhìn và có thể rời chốt khi nhận thấy bất thường.
- **Cửa phòng hồ sơ:** nằm bên hông hành lang, trước vị trí lính đứng chốt; An có thể tới cửa mà không phải đi xuyên qua hoặc áp sát người lính.
- **Lính tuần tra:** đi qua một nhánh bên, có khả năng nhìn vào cạnh/sau màn che nếu người chơi để lộ.

Sơ đồ chỉ thể hiện quan hệ, chưa phải mặt bằng thi công:

```text
Hốc chuẩn bị → đoạn tiến màn → cửa nhánh tuần tra → cửa phòng hồ sơ → chốt gác
                   ↕                                  ↕
             vị trí dừng có che                 vào phòng thu hồi
```

Các vị trí dừng phải che được cả An lẫn phần thiết bị dễ bị thấy từ nhánh tuần tra. Nếu lính nhìn được mặt sau, khung màn hoặc An thì phải có phản ứng phù hợp. Chỉ gắn nhãn “chỗ nấp” là chưa đủ.

**Lam:** “Người cuối hành lang giữ hướng chính diện. Đợi đội tuần tra rời cửa bên rồi hãy đưa màn ra.”

## 5. Triển khai — bắt đầu duy trì sự đánh lừa

An triển khai màn che ở vị trí chuẩn bị. Thiết bị dựng lại hình ảnh hành lang trống theo hướng người đứng chốt đang quan sát. Lam hỗ trợ hiệu chỉnh qua liên lạc; một người chơi điều khiển An và thao tác với thiết bị.

Trước khi tiến, người chơi nhận biết được:

- Hướng mà thiết bị đang che giấu.
- Trạng thái hình ảnh còn khớp hay đang có nguy cơ lệch.
- Đường đi tiếp và vị trí có thể dừng/lùi.

Thiết bị chỉ che giấu hình ảnh trong điều kiện phù hợp. Tiếng bước chân, va chạm và người quan sát từ hướng khác vẫn là nguy cơ. Giai đoạn này chưa chốt nút điều khiển, tốc độ đẩy hoặc thời lượng pin.

Người chơi đưa màn tiến từng đoạn. Mỗi đoạn gồm: quan sát → tiến → dừng đúng vị trí → kiểm tra chốt và nhánh bên.

## 6. Biến động — lính tuần tra khiến kế hoạch không đứng yên

Khi An đang giữa chặng, tiếng bước chân hoặc trao đổi vô tuyến báo một lính tuần tra đang tới cửa nhánh. Nhịp đến phải do tuyến di chuyển thật; tín hiệu cảnh báo xuất hiện đủ sớm để có thể xử lý.

Người chơi cần tự quyết định theo tình hình:

- Nếu chưa rời vị trí có che, giữ nguyên và đợi lính đi qua.
- Nếu đang trên đoạn hở, tiến tới điểm che gần nhất khi còn đủ khoảng trống, hoặc lùi về điểm trước.
- Nếu màn hoặc An đã bị nhìn thấy, chuyển sang xử lý nghi vấn/truy đuổi theo luật AI. Thiết bị không làm người lính bỏ qua thứ đang thấy.

Cùng lúc, người đứng chốt vẫn quan sát hướng chính. Nếu góc nhìn vượt giới hạn thiết bị hoặc có tiếng động đáng ngờ, trạng thái an toàn bị đe dọa. Người chơi có cơ hội nhận biết, dừng và điều chỉnh; không mặc định bắt thiết bị hỏng ở một mốc cố định trong mọi lượt.

**Tình huống mẫu:** An vừa đưa màn qua đoạn đầu thì nghe bước chân. Người chơi dừng tại hốc kỹ thuật, giữ cả mình và thiết bị ngoài tầm nhìn từ cửa bên. Sau khi tuần tra đi khỏi, An kiểm tra lại hướng chốt rồi tiếp tục tới cửa hồ sơ.

Thiết kế mặt bằng phải chứng minh tình huống này có thể diễn ra hợp lý. Nếu chỉ cần chờ lính quay đi để qua toàn bộ hành lang, hoặc lính đi ngang khung màn lộ rõ mà không phản ứng, đoạn chơi chưa đạt mục tiêu.

## 7. Vào phòng hồ sơ — khoảng yên trước báo động

An tới cửa bên và vào phòng hồ sơ trong lúc chốt vẫn bị đánh lừa. Cửa và lớp tường tạo khoảng che để người chơi rời thiết bị và tiếp cận tài liệu. Mở cửa phải được tính vào hình ảnh che giấu và tiếng động; không để lính đứng chốt thấy rõ cửa tự mở rồi bỏ qua.

Đường trở ra và cửa kỹ thuật dẫn tới tuyến bảo trì phải được nhìn thấy trước khi lấy tài liệu. Người chơi có một nhịp ngắn để nhìn đồng hồ hệ thống, ghi nhớ đường chạy và tự quyết định thời điểm thu hồi.

**Lam:** “Đến được rồi. Từ lúc tháo niêm phong, cậu có hai phút. Kiểm tra đường ra lần cuối.”

Hiển thị rõ hậu quả trước thao tác. An giữ E mở niêm phong theo cơ chế hiện có; hoàn tất mới có hồ sơ và bắt đầu 120 giây. Bỏ dở thì chưa kích hoạt đồng hồ rút.

## 8. Lấy tài liệu — cơ sở chuyển sang truy lùng

Ngay khi thu hồi thành công, đèn/còi chuyển trạng thái và lịch phong tỏa bắt đầu. Người chơi vẫn điều khiển được, không phải chờ một đoạn cắt cảnh làm mất thời gian.

Lính đứng chốt chuyển sang phản ứng với sự kiện; các lính tuần tra và tiếp viện hoạt động theo thông tin chúng nhận được. Khi bị nhìn thấy thì có truy đuổi; báo động không tự cung cấp vị trí liên tục của An cho toàn bộ AI.

Thủ thuật đã hoàn thành vai trò đưa An tới hồ sơ. Không bắt buộc mang thiết bị về tập kết. Thiết kế phải bảo đảm màn có thể thu/gạt nhanh hoặc có khoảng đi qua phù hợp, để nó không khóa cứng cửa phòng hay đường rút.

## 9. Rút lui — dùng những gì đã chuẩn bị

Giữ hai hướng hiện có:

- **Sân:** về cầu thang chính và khối giữa, qua sân tới tập kết; phải tính tới lịch đóng cổng và các đoạn trống.
- **Bảo trì:** cửa kỹ thuật phía đông, hành lang ngầm và cầu thang thứ hai, qua xưởng tới cửa hậu; chuẩn bị chốt trước giúp mở nhanh.

Đồng hồ 120 giây, nguồn dự phòng và hai đợt tiếp viện tiếp tục là khung rút lui của V5. Mặt bằng và tuần tra mới phải được đo lại để cả hai hướng có cách thoát khả thi.

Tới gần xưởng, Lam nhắc mục tiêu phá hoại tùy chọn nếu không có cảnh báo khẩn cấp hơn. Người chơi nhìn thời gian còn lại và tình hình thực tế để chọn đặt thiết bị năm giây hoặc đi thẳng. Thiết bị chỉ kích hoạt sau khi đã thoát an toàn.

## 10. Kết thúc và thử lại

- Tới tập kết có hồ sơ trước khi hết giờ: hoàn thành nhiệm vụ.
- Có đặt thiết bị và đã thoát: chạy đoạn kết phá hoại V5, ghi thành tích bổ sung.
- Bị bắt trước hoặc sau khi lấy: dùng checkpoint hợp lệ, giữ kiến thức trong nhật ký, khôi phục thiết bị và trạng thái cần thiết để chơi lại.
- Lượt thử lại không được thừa tiếp viện/sự kiện của lượt cũ, mất vĩnh viễn màn che, hoặc hồi sinh giữa tầm nhìn mở.

## 11. Những điểm cần trao đổi tiếp

1. **Cách vận hành màn:** bản này tạm chọn cơ động, đẩy từng đoạn; phương án đặt cố định sẽ dẫn tới luồng thao tác khác.
2. **Cách đọc giới hạn:** người chơi nhận ra góc che sắp mất và tuần tra tới qua dấu hiệu nào, ở khoảng cách nào?
3. **Vai trò người đứng chốt:** mức xoay quan sát và điều kiện rời chốt phải tạo áp lực nhưng vẫn đọc được.
4. **Lối dừng an toàn:** mặt bằng có che thật cho cả người và thiết bị, đường lùi rõ, không có màn che lơ lửng hay đồ vật bị AI bỏ qua vô lý.
5. **Mức biến động:** tuyến tuần tra có quy luật để học; khả năng điều tra khiến người chơi cần ứng biến. Chưa chốt thêm ngẫu nhiên hoặc thêm số lính.

Đầu quét riêng và khu điều phối của bản nháp trước sẽ chỉ được xét lại sau khi thống nhất luồng màn che. Bước hiện tại là trao đổi trải nghiệm; chưa phải danh sách công việc triển khai hoặc thông số cân bằng cuối cùng.
