# K17 V6 — Kế hoạch hoàn thiện tầng hầm B1

Ngày lập: 28/10/2026. Mốc mã nguồn đối chiếu: `73e59e4`, nhánh `feature/twp`.

**Trạng thái: đã triển khai M0–M4 trên `feature/twp`.** Kết quả, thông số cuối, ảnh và log nằm trong [báo cáo B1](../b1-refinement/VALIDATION.md). Tài liệu này giữ các yêu cầu và mốc thử ban đầu để đối chiếu; [báo cáo V6 cũ](VALIDATION.md) chỉ phản ánh bản trước đợt B1.

Điều chỉnh mới nhất của người dùng: **đẩy màn vượt qua vị trí cửa hồ sơ rồi dừng trên hành lang, người chơi đi vào phòng từ phía sau màn; khi quay ra, cửa nằm ở phía đường rút.** Khoảng cách tới chốt phải tính từ vị trí màn dừng sau cửa. Không cần xây một khoang đỗ cuối riêng trong phòng.

## 1. Trải nghiệm và phạm vi

Đặc trưng B1 là quan sát, điều khiển màn chiếu và chủ động chuyển hướng chú ý của chốt. Khó ở quyết định tiến/dừng và phối hợp hai hướng quan sát; không bắt người chơi dò một ngưỡng hình học không nhìn thấy.

Phần phải làm trong đợt này:

- Chặn đường vòng qua cảm biến, cả bằng mặt bằng lẫn thể tích phát hiện.
- Màn vừa bề ngang hành lang; dẫn hướng giảm việc căn hai vạch sàn, vẫn có va chạm thật.
- Hai hốc chữ L đối ứng hai ô quan sát W1/W2 của tuần tra.
- Chốt có nhịp kiểm tra tự nhiên và có thể nhận một yêu cầu kiểm tra giả do người chơi gửi.
- Camera C1 trên chốt, kênh hình đã hack, camera trước trên thiết bị và phản hồi rõ khi tín hiệu không dùng được.
- Khóa điện tử phòng hồ sơ; đẩy màn qua cửa; lấy hồ sơ rồi rút ngược đường vào.
- Bản thường và bản không lính dùng cùng mặt bằng, khóa cửa, cảm biến và nhiệm vụ.

Giữ nhiệm vụ trên mặt đất, 120 giây tính từ lúc lấy tài liệu, hai điểm tập kết trên mặt đất, tiếp viện và phá hoại V5. Không tạo một tuyến thoát B1 riêng phía sau hồ sơ. Camera trần C2 là phần bổ sung có điều kiện, chưa nằm trong công việc bắt buộc.

## 2. Luồng chơi cần hoàn thành

```text
Vào K17 → lấy thẻ và chỉ dẫn → mở cửa kho B1
  → sảnh chung trước S1 → S1 → S2 → khu chuẩn bị/checkpoint
  → chiếm kênh CCTV và thử điều khiển màn
  → quan sát chốt + W1/W2 → tiến, chờ ở hốc khi cần
  → canh nhịp kiểm tra tự nhiên hoặc gửi yêu cầu kiểm tra giả
  → vượt khu W2 → đẩy màn qua toàn bộ vị trí cửa hồ sơ
  → thả tay đẩy → dùng thẻ và giải mã cửa → vào phòng
  → lấy tài liệu: bắt đầu 120 giây
  → ra chính cửa đó → chạy ngược hành lang → S2 → S1 → sảnh
  → lên mặt đất → chọn hướng tập kết / phá hoại V5 tùy chọn
```

Hai hốc là các lựa chọn che chắn. Một lượt đi đúng thời điểm có thể bỏ qua một hoặc cả hai hốc; không đặt trigger bắt buộc người chơi phải ghé đủ. Hành động mở khóa không tự lấy tài liệu hoặc khởi động báo động 120 giây.

## 3. Mặt bằng và cảm biến

### 3.1. Mọi lối vào đều ở phía trước cảm biến 1

Nhánh bảo trì hiện có cửa nối vào làn quét trong khoảng giữa hai cảm biến. Hai dải quét cũng có kích thước riêng với bề ngang hành lang. Cần sửa đồng thời hai lớp:

1. Chuyển chỗ nhập của nhánh bảo trì và làn quan sát về sảnh phía trước S1. Sau S1, vách hai bên liền mạch tới khu chuẩn bị; không có cửa bên dẫn vòng qua S1 hoặc S2.
2. Cho vùng phát hiện, các tia quét, cột phát và phần chèn tường dùng chung thông số bề ngang. Vùng gameplay phủ toàn bộ tiết diện người chơi có thể đi qua; không chỉ kéo dài hình vẽ tia.
3. Các ô W1/W2 cho nhìn nhưng chặn người, lính và navigation. Không có đường đi xuyên kính để vào kho.
4. Cả hai mặt cảm biến đều có đèn và chữ xanh/vàng/đỏ để đọc được lúc đi vào lẫn lúc quay ra. Giữ chu kỳ ban đầu 8 giây, xanh 4 giây, vàng 1 giây, đỏ 3 giây; chỉ đổi sau khi đo lượt chơi.

Kiểm tra sát hai tường khi đứng/cúi, đi theo cả hai chiều và từ cả hai cầu thang. Tia kiểm tra không được tự đập vào cột phát hoặc vỏ cảm biến rồi khiến toàn bộ cảm biến mất tác dụng.

### 3.2. Hành lang và thiết bị

- Bề ngang thông thủy mục tiêu: 2,60 m. Phần cứng màn khoảng 2,50 m, có mép mềm khoảng 0,05 m mỗi bên; mép mềm không tạo collider kẹt bánh xe.
- Hạ trần cục bộ và hoàn thiện mép trên/dưới để không lộ chân, bánh hoặc khung. Thử từ mắt chốt trước khi chốt chiều cao; camera C1 phải nằm dưới phần trần chắn tầm nhìn.
- Giữ hướng màn độc lập với hướng nhìn. Đẩy dọc có trợ lực giữ tâm; A/D vẫn dùng được để vào hốc tại miệng hốc và để sửa vị trí khi có khoảng trống.
- Trợ lực chỉ chỉnh chuyển động qua kiểm tra va chạm, không teleport, kéo xe xuyên tường hoặc tự vượt người đứng chắn.
- Màn, ray/dẫn hướng và vách hồi không được cắt đường xe đi thẳng tới điểm dừng sau cửa hồ sơ. Đặt phần che lối vào phòng về phía trong phòng khi cần.
- Thông số mặt màn, collider, điểm kiểm tra thân người/khung và phép chiếu lấy từ cùng cấu hình; bỏ các số cứng theo mặt màn 2,20 × 2,24 m cũ ở những chỗ bị ảnh hưởng.

### 3.3. Phòng hồ sơ, chốt và điểm dừng sau cửa

Sơ đồ đã trao đổi lấy kho khoảng 37 × 18,8 m làm tham chiếu. Tọa độ và kích thước cuối phải được dựng thử theo vị trí dừng mới; có thể dịch chốt/vách biên trong phạm vi khuôn viên. Không coi số đo phác thảo là dữ liệu đã nghiệm thu.

- Vẽ rõ cạnh gần/cạnh xa của cửa hồ sơ theo chiều đẩy màn. Điểm dừng nằm vượt toàn bộ miệng cửa, đủ để người sau tay đẩy bước vào cửa mà không phải đi vòng sang mặt trước màn.
- Khoảng cách mục tiêu từ mắt chốt tới mặt màn tại điểm dừng: khoảng 10 m; không thấp hơn 8 m trên tuyến chuẩn. Ngưỡng mất hiệu chỉnh gần 4,5 m của bản hiện tại vẫn là giới hạn cơ chế, không dùng làm khoảng đỗ bình thường.
- Phòng chỉ có một cửa vào/ra. Bít cửa thoát sau cũ bằng tường; xóa cả tương tác, objective, link navigation và chỉ dẫn tương ứng. Không biến cửa đó thành một cửa luôn mở.
- Bảng mở khóa gắn lên tường hoặc cánh cửa thật; nếu gắn cánh cửa thì đi cùng cánh khi mở.
- Người chơi giữ được vật che khi thả xe, mở khóa và đi vào phòng. Cánh cửa mở không hất xe, kẹp người hoặc làm bảng điều khiển treo tại chỗ cũ.
- Khi quay ra, màn nằm ở phía chốt, người chơi đi về phía sảnh. Không yêu cầu mang màn về để thắng.

## 4. Hai hốc và tuyến tuần tra

Lính không cần đứng trong hành lang chính mới phát hiện được người chơi: đường nhìn qua ô bên hông có thể thấy mặt sau màn và người đẩy. Màn hiệu chỉnh cho chốt không bảo vệ khỏi góc này.

Tuyến đề xuất: làn quan sát → W1 → quay về làn → W2 → quay về. Mỗi điểm có một nhịp dừng, nhìn ngang bằng chuyển động đầu/thân thật và tiếng bước chân. Dùng cùng một lính tuần tra được phân công lại, chưa tăng số lính thường trực.

- Hốc 1 dành cho lúc W1 đang bị quan sát; hốc 2 dành cho W2 và việc chuẩn bị tiếp cận cửa hồ sơ.
- Tường chữ L che cả khung màn và các điểm cơ thể, kể cả sau tay đẩy. Bóng tối hoặc một cờ `hidden` không thay thế tường che.
- Miệng hốc đủ cho xe và người cùng di chuyển, có điểm dừng/chặn bánh đọc được bằng mắt.
- Dời mép vách để phần chuyển ngang bị lộ ngắn nhất. Phải đo cả chiều vào và chiều ra: ra khỏi hốc cũng có thể làm lệch hình.
- Chỉ được coi một chuyển tiếp là an toàn khi: hình còn khớp, hoặc tường đã che thật, hoặc chốt thực sự đang nhìn hướng khác. Không tắt kiểm tra thị giác trong trigger hốc.

Khi tuần tra thấy người thật, phản ứng vẫn là AI chung. Khi chỉ thấy thiết bị bất thường, điều tra vị trí thiết bị; không nhận tọa độ người đang khuất.

## 5. Làm chốt chuyển hướng chú ý

### 5.1. Nhịp tự nhiên

Chốt định kỳ kiểm tra máy trực bên cạnh rồi nhìn lại hành lang. Giá trị thử ban đầu: một lượt mỗi khoảng 25–35 giây, nhìn máy khoảng 6–8 giây. Đây là mốc cân chỉnh; nhịp phải đủ đọc và đủ cho một chuyển tiếp hốc sau khi đã sửa hình học, không tạo thời gian chờ bắt buộc cho cả màn chơi.

Ưu tiên quay thân tại chỗ hoặc bước ngắn tới bàn, giảm sai lệch vị trí mắt khi trở lại. Có âm báo, cử động và khoảng quay đầu liên tục. Người chơi nhìn thấy/nghe được hành động, không cần đoán một timer ẩn.

### 5.2. Yêu cầu kiểm tra giả

Sau khi chiếm kênh nội bộ, người chơi có thể gửi một yêu cầu xác nhận lỗi đường truyền tới đúng máy trực tại chốt, kể cả khi đang nắm tay đẩy.

1. Thiết bị báo đã gửi; chờ phản hồi khoảng 1–2 giây. Trong thời gian này chốt chưa được coi là quay đi.
2. Máy trực phát tín hiệu tại vị trí thật. Lính nhận yêu cầu nếu đang giữ chốt và chưa bận điều tra/đuổi bắt.
3. Lính quay về máy, xác nhận trong khoảng 8–10 giây, rồi quay lại. Khoảng an toàn được tính sau khi hướng nhìn thực sự rời hành lang, kết thúc trước khi quay về.
4. Người chơi kiểm tra C1 và W1/W2, chọn vào hoặc ra hốc. Cuộc gọi chỉ tác động chốt; không làm lính tuần tra cùng mất chú ý.

Điều kiện vận hành:

- Chỉ có một yêu cầu đang chờ/xử lý; không xếp hàng. Hồi chiêu thử ban đầu 25 giây sau lượt phản hồi, hiển thị được trên thiết bị.
- Chốt đang điều tra, thấy người, nghe tiếng nguy hiểm, bị va chạm hoặc nhận báo động hồ sơ có thể từ chối/ngắt việc kiểm tra. Tác nhân nguy hiểm ưu tiên cao hơn máy trực.
- Khi chốt đã xác nhận thấy An, yêu cầu giả không xóa trí nhớ và không ép trở lại giữ chốt.
- Không phạt thao tác bấm khi nút đang hồi chiêu. Với các yêu cầu đã được chấp nhận lặp dày, đề xuất cảnh báo đối chiếu từ lượt thứ hai trong 60 giây; lượt thứ ba tạm từ chối kênh 45 giây. Không tự gây bắt chỉ vì bộ đếm. Sau đó kênh dùng lại được; nhịp kiểm tra tự nhiên vẫn tồn tại, tránh khóa nhiệm vụ.
- Các giá trị chống lặp nằm trong cấu hình và cần thử; không nhân bản radio loa mặt đất để kéo toàn bộ lính tới một điểm.
- Pause đóng băng thời gian, thất bại/menu/reset hủy yêu cầu chờ. Không phát lại cuộc gọi của lượt chơi trước.

### 5.3. Quan hệ với hình chiếu

Cuộc gọi thay đổi hành động/hướng nhìn của lính; không giảm FOV, tắt thính giác hoặc bật bất tử. Nếu mắt chốt ra ngoài vùng tham chiếu, hình chiếu giữ ảnh hợp lệ cuối và báo mất hiệu chỉnh như bình thường. Không tự bám vị trí mới để tiếp tục che mọi góc.

Chỉ tiến khi đã xác nhận chốt quay đi. Khi chốt nhìn lại, người/xe phải ở sau tường hoặc màn đã khớp trở lại. Mục tiêu dựng thử: phần chuyển tiếp bị lộ không quá khoảng 5–6 giây và còn ít nhất khoảng 2 giây dự phòng trong cửa sổ đánh lạc hướng. Nếu không đạt, sửa miệng hốc trước khi kéo dài thời gian quay lưng.

## 6. Camera, hack và nguồn điện

### 6.1. Ba luồng hình tách biệt

| Luồng | Nội dung | Công dụng |
| --- | --- | --- |
| Ảnh chiếu ngụy trang | Hành lang trống, dựng theo mắt chốt, loại người/thiết bị | Mặt trước màn |
| Camera trước của màn | Cảnh thật phía trước, có người và vật cản | Nhìn đường khi đang đẩy |
| CCTV C1 trên chốt | Cảnh thật từ camera gắn cố định trên chốt | Xem vị trí màn, sai lệch từ góc camera và động tác chốt |

C1 không nhìn xuyên tấm màn. Nếu An bị che kín, hình C1 chỉ thấy mặt màn và phần không gian có đường nhìn. Góc C1 khác góc mắt lính; không lấy việc hình trông khớp trên C1 làm bằng chứng tuyệt đối rằng chốt đang bị đánh lừa. Trạng thái hiệu chỉnh vẫn tính theo mắt lính.

Camera trần C2 chỉ bổ sung nếu cần quan sát rõ toàn thân từ bên/trên, có phạm vi quan sát thực và vật che thật. Chưa làm góc nhìn tự do hoặc một camera toàn cảnh nhìn xuyên trần.

### 6.2. Chiếm kênh tại điểm chuẩn bị

Đề xuất giữ E 3 giây tại đầu nối/bảng thật. Hoàn tất đồng thời cấp quyền xem hình thật, gửi yêu cầu kiểm tra và chuyển luồng phòng trực sang đoạn ghi hành lang trống. Không dùng ảnh trống làm feed người chơi. Trước khi chiếm kênh, CCTV vẫn là thiết bị giám sát địch khi có đường nhìn hợp lệ.

Mạch CCTV/máy trực B1 dùng nguồn nội bộ có dự phòng, tách rõ khỏi công tắc `surveillance` mặt đất hiện có. Đây là cơ chế mới phải thể hiện trên bảng điện, HUD/nhật ký và lời nhắc; không để nhiệm vụ “camera đã tắt” khiến người chơi hiểu toàn bộ B1 đã mất giám sát. Giữ sự kiện nguồn dự phòng mặt đất hiện tại và kiểm tra tương tác với nó.

Sau khi tháo niêm phong: báo động nội bộ ưu tiên hơn quyền chiếm kênh, hủy yêu cầu giả, không cho gửi thêm. Máy trực/đèn cho biết kênh bị thu hồi; luồng giả cho địch kết thúc. Luồng xem cá nhân báo mất kết nối thay vì giữ ảnh cũ như thể đang trực tiếp. Không thêm một timer hack cạn pin trước hồ sơ trong đợt này.

### 6.3. Điều khiển và hiệu năng

- E giữ chức năng tương tác/nắm/thả; không buộc nhìn lại bảng điều khiển để gọi chốt khi đang đẩy.
- Phím đề xuất tại K17: V đổi/ẩn feed quan sát, R gửi yêu cầu giả. Kiểm tra lại keybind thực tế trước triển khai; có nút E trên thiết bị làm lựa chọn thao tác trực tiếp. Không ghi thay đổi input toàn cục của map khác khi không cần.
- Xem feed không dừng thời gian hoặc miễn phát hiện. J, pause, menu, mất focus và retry phải xử lý grip/chuột đúng, không để xe tiếp tục chạy.
- Chỉ thêm một viewport quan sát đang được chọn ở khoảng 480 × 270, 10 lần/giây; không render camera trước và C1 cùng lúc khi chỉ một feed đang hiển thị. Viewport ảnh ngụy trang vận hành riêng theo nhu cầu.
- Feed thật giữ các lớp lính, người và màn; không dùng nhầm culling của ảnh ngụy trang. Có chữ báo không tín hiệu khi mất nguồn/quyền truy cập.
- Đo bằng renderer Compatibility trên máy hiện tại. Mục tiêu chi phí tăng thêm khoảng dưới 10% frame time trong cảnh tương đương, không cam kết trước số đo. Giảm tần số/độ phân giải trước khi thêm camera nữa.

## 7. Khóa hồ sơ và đường rút

### 7.1. Mở khóa

Đẩy màn vượt cửa và dừng ở vị trí đã đánh dấu; thả tay đẩy. Dùng thẻ đã có, giữ E giải mã khóa khoảng 6 giây tại bảng cạnh cửa. Không bắt tìm một mã số mới trong đợt này.

- Thiếu thẻ, ngoài tầm hoặc không nhìn đúng bảng: lời nhắc nêu đúng nguyên nhân.
- Nhả E, rời tầm/tiêu điểm, pause hoặc bị bắt: hủy tiến trình chưa hoàn tất, không mở cửa ngầm.
- Hoàn tất chỉ mở khóa; cửa tiếp tục dùng được cả hai chiều và không tự khóa khi có hồ sơ/báo động.
- Nhận tài liệu vẫn là thao tác giữ E 3,5 giây riêng. Chỉ hoàn tất thao tác này mới bật 120 giây và lịch tiếp viện.

### 7.2. Quay ra bằng đường vào

Ra cửa hồ sơ rồi chạy về phía sảnh, không đi sang phía trước màn/chốt. Hai hướng tập kết mặt đất và V5 vẫn giữ. B1 không tự sinh thêm cảnh vệ đúng sau lưng; lính tìm tới nguồn báo động theo đường đi thật.

Màn đỗ phía chốt không được trở thành bức tường miễn nhiễm khiến lính đứng kẹt vô hạn. Cần một phản ứng tại chỗ đối với vật cản: đề xuất lính tiếp cận được mặt trước, xác minh và thu/gạt khung trong khoảng 2–3 giây khi đường tới sự kiện hồ sơ bị màn chặn. Chỉ thực hiện sau khi phát hiện thiết bị hoặc có đường cần đi bị chắn, ở tầm tương tác thật; không biến mất/teleport màn. Động tác có tiếng và hình. Luật thấy người/nghe tiếng vẫn ưu tiên.

Phía người chơi, cho phép thu/dịch màn sau FILE khi cần giải phóng đường; không bắt mang màn đi, không vô hiệu hóa tương tác khiến thiết bị trở thành chướng ngại không thể xử lý. Nếu xử lý vật cản của AI chưa đạt, chưa nghiệm thu hành lang kín ngang.

Giữ 120 giây làm mốc đầu. Đo lại tuyến sân, bảo trì, cửa hậu chưa chuẩn bị và phá hoại sau khi thay đường B1. Mục tiêu chính phải có dư địa cho ít nhất một lần chờ cảm biến ngắn; không dựa vào một lượt chạy hoàn hảo mới thắng. Ưu tiên rút ngắn quãng vô nghĩa/sửa bố trí trước khi đề nghị đổi đồng hồ.

## 8. HUD, phản hồi và checkpoint

- Minimap giữ vị trí người chơi thật, bổ sung S1/S2, W1/W2, hốc, cửa hồ sơ và đường quay về. Không hiện lính xuyên tường chỉ vì bật CCTV.
- Máy trực/chốt có âm xác nhận, quay đầu và tín hiệu sắp kết thúc. HUD phân biệt “đã gửi”, “đang chờ”, “đang kiểm tra”, “từ chối/hồi chiêu”; không ghi “an toàn” nếu chỉ vừa gửi yêu cầu.
- Trạng thái hình khớp/gần lệch/lệch và nguyên nhân mất tín hiệu đọc được, không che minimap, đồng hồ, phụ đề hoặc thanh giữ E.
- Hướng dẫn theo lúc cần: thử camera/đẩy ở điểm chuẩn bị, giải thích cửa sổ W1/W2, chỉ cách gọi chốt, nhắc đẩy qua cửa và rút ngược. Chưa cần một màn hình hướng dẫn dài trước khi chơi.
- Lưu checkpoint an toàn tại khu chuẩn bị; không ghi snapshot trong lúc quay đầu, chuyển hốc, giữ mở khóa hoặc sau FILE. Retry trả màn về HOME, cửa hồ sơ khóa lại, quyền camera/counter theo baseline checkpoint và không còn cuộc gọi chờ, nghi vấn cũ hoặc tiếp viện cũ.
- Không lính: vẫn có CCTV thật, điều khiển màn, cảm biến, khóa và đồng hồ; hiệu chỉnh dùng mốc tham chiếu công khai. Yêu cầu giả báo không có chốt, không tạo NPC vô hình. Không bắt người chơi giả lập một lượt gọi để mở hồ sơ.

## 9. Nơi triển khai trong mã nguồn

Chỉ sửa `maps/intelligence/`. Bảng dưới giữ định hướng ban đầu; triển khai thực tế gộp quyền kênh, feed và cuộc gọi trong `projection_surveillance.gd`, nút tương tác dùng `b1_console.gd`, không tạo riêng `projection_distraction.gd`.

| Hạng mục | Mã nguồn/chỗ cập nhật |
| --- | --- |
| Tọa độ, kích thước, nhịp chốt, khoảng an toàn | `resources/layout/k17_projection.gd`; thêm cấu hình có tên, không rải số cứng |
| Mặt bằng, vách, kính, bảng, C1 và máy trực | `tools/k17_projection_builder.gd`, `tools/k17_expansion_builder.gd` |
| Dải quét kín, chỉ báo hai chiều | `tools/k17_security_builder.gd`, `scripts/sensor_lane.gd` |
| Màn/dẫn hướng/vật cản/thu sau báo động | `scripts/projection_rig.gd`, `scripts/projection_player.gd`, `scripts/projection_interactor.gd` |
| Nhịp tự nhiên và nhận yêu cầu của chốt | `scripts/projection_guard.gd`; giữ ưu tiên AI chung |
| Quyền camera, feed thật, yêu cầu/hồi chiêu | Đề xuất `scripts/projection_surveillance.gd`, `scripts/projection_distraction.gd` |
| Khóa hồ sơ và cửa hai chiều | Đề xuất `scripts/archive_lock.gd`; sửa scene/builder và `scripts/projection_room.gd` |
| Mục tiêu, nguồn điện, phát hiện từ CCTV | `scripts/mission_controller.gd`, `scripts/power_network.gd`, `scripts/security_camera.gd`, `scripts/stealth_director.gd` |
| HUD, minimap, snapshot và không lính | `scripts/objective_hud.gd`, `scripts/minimap.gd`, `scripts/projection_checkpoint.gd`, `scripts/test_mode.gd` |
| Navigation/lightmap, tái dựng và đóng gói | Builder, `tools/bake_v6_lightmaps.gd`, các bộ kiểm tra hiện có |

Geometry phải sửa vào nguồn builder/cấu hình rồi sinh lại scene, minimap, navigation và lightmap. Không chỉnh riêng scene thường khiến scene không lính bị lệch. Không sửa phần thư viện hay điều khiển/AI chung nếu lớp K17 kế thừa đã đủ.

## 10. Thứ tự thực hiện và điều kiện chuyển mốc

| Mốc | Công việc | Được chuyển tiếp khi |
| --- | --- | --- |
| M0 — Dựng lại đường đi | Sảnh trước S1, quét kín, W1/W2, hốc, cửa duy nhất, đẩy màn qua cửa | Không còn đường vòng; đủ chỗ cho cả xe/người; khoảng cách chốt đạt; vào/ra phòng không cần xuyên màn |
| M1 — Cơ động và che thật | Màn vừa hành lang, trợ lực, sửa miệng hốc, kiểm tra từ các mắt nhìn | Cả chiều vào/ra mỗi hốc có cửa sổ an toàn; xe không kẹt; luật hiệu chỉnh không bị nới tùy tiện |
| M2 — Camera và chuyển chú ý | C1, camera trước, quyền kênh, máy trực, nhịp tự nhiên và cuộc gọi giả | Nhìn được tình huống thật; phản hồi đúng; cuộc gọi không xóa chase; người chơi có thể chọn tiến/dừng theo dấu hiệu |
| M3 — Nhiệm vụ trọn vẹn | Khóa hồ sơ, giữ E, 120 giây, rút ngược, xử lý màn chắn, reset, V5 | Đi từ menu tới thắng ở cả hai hướng mặt đất; không khóa nhiệm vụ sau khi bỏ màn |
| M4 — Hoàn thiện và nghiệm thu | Gá đỡ, ánh sáng, âm thanh, HUD, renderer, gói chạy và tài liệu | Đạt ma trận kiểm tra; có ảnh và lượt chơi thật; nêu rõ phần hoãn |

M0–M1 là điều kiện nền. Chưa đạt thì sửa mặt bằng trước, không bù bằng việc làm lính nhìn kém hơn hoặc cho hiệu ứng hoạt động mọi góc.

## 11. Ma trận nghiệm thu tối thiểu

1. **Cắt đường vòng:** từ từng cầu thang, làn phụ và sát hai tường đều phải qua S1 rồi S2 trước khi tới màn; cùng các trường hợp đó theo chiều ra. Kính/tường không có khe đi lọt. Không dùng tường vô hình để che lỗi thiết kế.
2. **Chuyển hốc:** thử vào/ra hốc 1 và 2, có/không cuộc gọi, chốt đang nhìn/đang quay/đang trở lại, tuần tra ở W1/W2 và lúc di chuyển. Kiểm tra điểm mẫu dọc cả chuyển động của xe lẫn người; không chỉ chụp lúc đã đỗ.
3. **Sai lầm có nguyên nhân:** rẽ quá sớm, rẽ muộn, va khung, ló người, tắt hình, chốt rời mốc hoặc tuần tra thấy mặt sau đều phản ứng hợp lý. Chốt thực sự nhìn đi thì không nhận ra từ một trạng thái AI bị báo sai.
4. **Cuộc gọi:** chậm phản hồi, từ chối khi chase/điều tra, ngắt bởi tiếng nguy hiểm, hết lượt xác nhận, gửi lặp, pause/reset/menu và báo động hồ sơ. Không gửi hàng loạt từ một phím giữ, không lưu timer từ lượt cũ.
5. **Camera:** feed C1 và camera trước có người/lính/xe thật; ảnh chiếu không có các đối tượng đó. C1 không thấy An khi bị màn che. Mất quyền/nguồn không giữ ảnh cũ với nhãn trực tiếp. Camera mặt đất và B1 phản ánh đúng nguồn khác nhau.
6. **Khóa/cửa:** thiếu thẻ, hủy giữ E, bị bắt, cửa mở/đóng, bảng đi theo cánh, người và xe gần cửa. Không chạy đồng hồ khi mới mở khóa; cửa không tự khóa khi lấy hồ sơ. Bỏ hẳn cửa sau cũ và các objective/link không còn đúng.
7. **Vật cản sau FILE:** màn sau cửa không chắn đường người chơi; người chơi còn xử lý được màn nếu cần. Chốt có đường tiếp cận và phản ứng hợp lệ trước màn, không đứng kẹt vô hạn hoặc xuyên qua nó.
8. **Lượt chơi thật:** ít nhất ba lượt AI hoàn thành liên tiếp với pha tuần tra ban đầu khác nhau; có lượt dùng cuộc gọi và lượt tận dụng nhịp tự nhiên. Chạy tuyến sân, bảo trì, bảo trì chưa chuẩn bị và phá hoại V5; bản không lính hoàn thành cả hai hướng tập kết. Ghi thời gian còn lại, số lần lộ và nguyên nhân.
9. **Hồi quy và bàn giao:** chạy bộ nền V6, kiểm tra art/attachments/map contract, navigation, HUD ở các độ phân giải/cỡ chữ đang hỗ trợ, renderer và PCK thực. Số kiểm tra V6 cũ không được trình bày là kết quả của bản mới.

## 12. Kết quả bàn giao khi triển khai

- Bản thường và không lính cùng được cập nhật; hướng dẫn thao tác ngắn và tuyến chơi gợi ý.
- Sơ đồ theo tọa độ đã dựng, ảnh từ mắt chốt/C1/W1/W2, cả lúc chuyển hốc và sau khi mở cửa.
- Báo cáo thử lại riêng cho đợt hoàn thiện B1: lượt chơi, thời gian, hiệu năng, lỗi còn lại và phần chưa làm.

**Thông số sau dựng thử:** B1 38 × 18,8 m; hành lang 2,60 m; màn 2,60 × 2,50 m; khoảng đỗ tới chốt 10 m. Chốt kiểm tra tự nhiên 9,5 giây mỗi 30 giây quan sát; yêu cầu giả có trễ 1,5 giây và lượt kiểm tra 10 giây. Chuyển tiếp hốc mất khoảng 6,3–7 giây; cửa sổ bắt đầu sau khi thân chốt thực sự quay đi còn trên 9 giây. Các số cuối và giới hạn kiểm chứng xem báo cáo B1. C2 giữ là phần để sau.
