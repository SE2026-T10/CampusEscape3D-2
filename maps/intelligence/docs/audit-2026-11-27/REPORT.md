# Kiểm thử và kế hoạch cải tiến K17

Ngày 27/11/2026 · Nhánh `feature/twp` · Mốc `2b582eb` · Godot `4.7.2.stable.official.ed1daf0bf`.

Vòng nhiệm vụ K17 hoạt động từ lúc vào cơ sở đến khi bàn giao hồ sơ. B1 có bản sắc rõ nhờ xe che, hai góc camera, nhịp quay của chốt và tuần tra độc lập. Ưu tiên gameplay là giúp người mới đọc đúng cửa sổ an toàn và nhận ra vị trí có thể đổi tuyến. Các ca đã chạy cho thấy lượt bảo trì có thể thắng khi camera mặt đất vẫn bật hoặc cửa hậu chưa được chuẩn bị. Lượt sân thắng khi vòng tránh chốt phản ứng, còn lượt đi thẳng qua khu đó bị tiếp viện bắt.

## 1. Kỹ thuật đồ họa từ các game 3D

| Game và thể loại | Kỹ thuật được công bố | Áp dụng cho K17 |
| --- | --- | --- |
| **Horizon Zero Dawn**, nhập vai hành động thế giới mở | Guerrilla dùng truy vấn khả kiến trên GPU để quản lý môi trường lớn, dày hơn các màn Killzone. Nhóm mỹ thuật cũng thiết kế thảm thực vật trong ngân sách console. [Guerrilla Games](https://www.guerrilla-games.com/read/decima-engine-visibility-in-horizon-zero-dawn) · [GDC, Gilbert Sanders](https://www.gdcvault.com/play/1025530/) | Đo vật thể bị khuất ở B1 trước khi thay đổi mesh. Trong Godot, occlusion có chi phí CPU, nên đo frame time cùng số lượt vẽ. |
| **Fortnite**, battle royale | Epic có Performance Mode và các mức dựng hình. Hướng dẫn UEFN gộp các vật thể ở xa thành mesh/vật liệu đại diện bằng HLOD để giảm lượt vẽ. [Epic, chế độ dựng hình](https://www.epicgames.com/help/c-45487929/c-35761596/a20197720?lang=en-US) · [Epic, giảm draw calls](https://dev.epicgames.com/documentation/fortnite/reducing-draw-calls-in-fortnite) | Gộp vật trang trí tĩnh theo phòng hoặc ô sân. Chỉ thử LOD với asset xa có chi phí đo được. Biển chỉ hướng, vật che, cửa và cảm biến cần giữ dấu hiệu nhận biết ở mọi cấu hình. |
| **Destiny**, bắn súng góc nhìn thứ nhất trong thế giới chia sẻ | Bungie cache dữ liệu render và tập hợp dữ liệu động theo từng frame cho các khâu render đa luồng. [Natalya Tatarchuk và nhóm Bungie, GDC 2015](https://advances.realtimerendering.com/destiny/gdc_2015/Tatarchuk_GDC_2015__Destiny_Renderer_web.pdf) | Profile để xác định điểm nghẽn. Với K17, kiểm tra chi phí từng camera phụ và tìm việc lặp mỗi frame trước khi chỉnh shader hoặc kiến trúc. |

K17 chạy Compatibility, dùng LightmapGI đã bake và gom mesh tĩnh theo không gian, vật liệu, lớp render và trạng thái đổ bóng. Hình chiếu B1 dùng viewport 512 × 512, tối đa khoảng 12,5 lần cập nhật/giây. Camera trước hoặc C1 dùng chung một viewport 480 × 270, tối đa khoảng 10 lần/giây. Cả hai đã có điều kiện dừng khi không cần cập nhật. Vì vậy các ứng viên tiếp theo là đo frame time lúc hai viewport cùng hoạt động, thử occluder trên tường đặc và đo hiệu quả LOD theo khoảng cách. Mesh/collider/minimap có chung nguồn hình học khi dựng lại, nên mọi phương án thay mesh tĩnh đều cần kiểm tra lightmap và mặt bằng. [Builder gom mesh](../../tools/k17_static_merge.gd) · [Godot 4.7, occlusion culling](https://docs.godotengine.org/en/4.7/tutorials/3d/occlusion_culling.html) · [Godot, Mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) · [Godot, LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html)

## 2. Sự kiện lịch sử và chất liệu cho K17

| Sự kiện | Chi tiết được kiểm chứng | Chất liệu có thể dùng trong kịch bản K17 |
| --- | --- | --- |
| **Điện số 157-HĐKTK, 07/04/1975** | Bảo tàng Lịch sử Quốc gia ghi Đại tướng Võ Nguyên Giáp gửi điện cho các đơn vị lúc 9 giờ 30. Triển lãm Hoàng Thành Thăng Long đặt mệnh lệnh trong diễn biến mùa xuân 1975. [Bảo tàng Lịch sử Quốc gia](https://baotanglichsu.vn/VI/Articles/3097/71432/45-nam-ngay-giai-phong-mien-nam-menh-lenh-lich-su-cho-ngay-toan-thang.html) · [Hoàng Thành Thăng Long](https://trungbayonline.hoangthanhthanglong.vn/Home/Index) | Dùng số hiệu, giờ hiệu lực và nơi nhận để người chơi hiểu vì sao 04-B quan trọng với đoàn sơ tán. Viết điện văn, đơn vị và nhân vật của K17 theo thế giới hư cấu của dự án. |
| **Operation Mincemeat, tháng 4/1943** | Bảo tàng Thế chiến II Hoa Kỳ ghi chiến dịch nghi binh của Anh dùng thư giả để đánh lạc hướng về mục tiêu Đồng Minh, trước cuộc đổ bộ Sicily. [The National WWII Museum](https://www.nationalww2museum.org/war/articles/secret-agents-secret-armies-operation-mincemeat) | Cho người chơi đọc dấu hiệu về nguồn gốc và độ mới của hai văn bản. Tài liệu chính đủ để hoàn thành, còn bản đính chính cung cấp thông tin thời hạn mà đoạn kết phản ánh. |
| **Berlin Tunnel, 1955–1956** | CIA ghi việc thu thập bắt đầu ngày 11/05/1955. Bundesarchiv ghi phía Liên Xô biết kế hoạch qua George Blake và công khai việc phát hiện hầm tháng 4/1956. [CIA](https://www.cia.gov/stories/story/berlin-tunnel-americas-ear-behind-the-iron-curtain) · [Bundesarchiv](https://www.bundesarchiv.de/themen-entdecken/online-entdecken/themenbeitraege/kabelkrimi-im-kalten-krieg/) | Viết sổ bàn giao và máy trực với thông tin khác nhau về cùng một sự cố. Dùng độ trễ xác minh của chốt để tạo lựa chọn rút ngay hoặc lấy 04-B. |

Về bối cảnh hư cấu, 04-B báo giờ phong tỏa trong điện văn sớm hơn 20 phút. Đồng hồ 120 giây trên HUD đo quãng rút khỏi cơ sở sau khi tháo niêm phong. Tách hai mốc trong lời thoại và màn kết để người chơi hiểu phần thưởng của 04-B. [Nội dung V8](../../README.md) · [Bộ điều khiển nhiệm vụ](../../scripts/mission_controller.gd)

## 3. Ma trận kiểm thử đã chạy

Các ca đi nhiệm vụ điều khiển nhân vật, keypad, giữ E và va chạm qua driver. Driver có thể chờ dựa trên pha của lính. Các ca chức năng, tác chiến cô lập và dựng trạng thái để chụp ảnh có phạm vi riêng. Log, gói PCK, ảnh và JSON lưu tại `D:/CNPM/output/k17-audit-2026-11-27/`.

| Nhóm | Kịch bản và điều kiện đạt | Kết quả |
| --- | --- | --- |
| Luồng chính, an ninh và hồi phục | Kiểm tra chuỗi nhiệm vụ, mã sai/khóa tạm, giữ E, cảm biến, tắt và khôi phục nguồn, lịch điều động, tạm dừng, bị bắt/hết giờ và khôi phục checkpoint | `check_k17` đạt 610 phép kiểm. Bộ `check_navigation` chạy riêng đạt 133 phép kiểm về hai tầng, collider, navmesh, tương tác và minimap. |
| B1 và 04-B | Hốc che tại W1/W2, phản ứng khi khung lộ, camera trước/C1, V/R, chốt xác minh báo động, khóa hồ sơ, quyền B1 sau retry, phụ lục/nhật ký/kết quả ở hai chế độ | Projection 118, B1 56, B1 feed 36, V7 51, V8 55 phép kiểm đều đạt. Phá hoại chạy riêng đạt 78 phép kiểm. |
| Cảnh và giá đỡ | Giá camera, biển, ống và vật che kiểm theo hình học hoặc nguồn dựng | Art 66 và attachments 239 phép kiểm đạt. |
| Truy đuổi và phong tỏa | Bốn ca gặp lính cô lập, đổi tuyến ở T+70/T+90, chạy 90 giây mô phỏng có 6 và 10 NPC | Hai ca đổi sang bảo trì với camera bật và cửa hậu đã chuẩn bị đều thắng, còn 37,3 giây ở T+70 và 17,3 giây ở T+90. Ba trình kiểm thử được cập nhật theo map hiện hành và chạy lại. |
| Luồng dùng chung và bản xuất | Biên dịch script, hợp đồng map, chọn/chơi lại/về menu, nạp PCK từ thư mục ngoài dự án | `check_scripts`, `check_map_contract`, `map_flow` đều đạt. `map_flow` ghi 100 phép kiểm, nạp 24 lượt trong 3 vòng. Cả PCK mốc ban đầu và `game-k17-reviewed.pck` sau sửa HUD đều nạp được hai chế độ và qua bài kiểm tra runtime của gói. |

### Lượt đi nhiệm vụ bằng input

| Lượt | Lựa chọn | Kết quả | Bị bắt / chạm cảm biến / tiếp viện |
| --- | --- | --- | --- |
| Không lính · sân | 04-B và phá hoại | Thắng, còn 49,5 giây | 0 / 0 / 0 |
| Không lính · bảo trì | 04-B và phá hoại, cửa hậu mở cơ | Thắng, còn 52,2 giây | 0 / 0 / 0 |
| Không lính · vào từ đông | Rút bảo trì, camera vẫn cấp nguồn | Thắng, còn 58,4 giây sau sửa tọa độ driver | 0 / 0 / 0 |
| Có lính · sân, qua chốt phản ứng | Nhịp chốt tự nhiên, rút theo tuyến thẳng | Bị bắt ở khoảng T+31,4, gần `(-12, 0, 8)` | 1 / 0 / 2 |
| Có lính · vòng sân | Nhịp chốt tự nhiên, vòng phía nam chốt phản ứng | Thắng, còn 72,0 giây | 0 / 0 / 3 |
| Có lính · bảo trì | R, tắt camera mặt đất trước, chuẩn bị cửa hậu | Thắng, còn 68,6 giây | 0 / 0 / 4 |
| Có lính · bảo trì | R, pha B1 +4 giây, cửa hậu mở cơ | Thắng, còn 58,3 giây | 0 / 0 / 4 |
| Có lính · bảo trì | R, pha B1 +9 giây, 04-B và phá hoại | Thắng, còn 59,4 giây. Tương tác 04-B dùng 3,48 giây theo đồng hồ lượt. | 0 / 0 / 4 |
| Có lính · bảo trì | Camera mặt đất bật, chuẩn bị cửa hậu | Thắng, còn 72,1 giây | 0 / 0 / 4 |
| PCK mốc ban đầu · có render và có lính | R, bảo trì, pha B1 +9 giây, 04-B và phá hoại | Thắng, còn 59,2 giây, 130 waypoint. Ảnh từ lượt lưu trong `pack-walking/`. | 0 / 0 / 4 |

Chênh lệch thời gian còn lại giữa hai lượt có/không chuẩn bị cửa hậu gồm chênh pha B1 và phản ứng NPC. So sánh riêng tác dụng của chuẩn bị bằng bài chức năng dùng cùng chốt mở cơ. Đợt hai có thể hoãn một NPC theo tầm nhìn, nên lượt vòng sân ghi nhận ba tiếp viện.

- **Kiểm thử `vault_wall_cover`.** Điểm cũ nằm trên bố cục trước V6, khiến người và lính không thiết lập được truy đuổi. Bài sửa bắt đầu ở làn xe B1, chạy vào hốc chữ L hiện hành và lấy mẫu tia từ mắt lính đến các điểm cơ thể. Cả bốn ca đạt. Trong ca B1, tường cắt các tia trong lúc rút, AI chuyển từ truy đuổi sang điều tra, không kích hoạt `HIDDEN` và không bắt người chơi trong khoảng kiểm tra. Lính có thể vòng lại thấy người chơi. [Fixture](../../tools/encounters_v4.gd)
- **Kiểm thử chạy dài.** Chốt B1 đứng gác, nên ngưỡng bốn waypoint chỉ áp dụng cho lính tuần tra. Bài sửa xác nhận chốt có vào nhịp máy trực và chỉ rời vị trí trong biến thể đã lấy hồ sơ. Hai chế độ chạy 90 giây đều đạt, không báo kẹt hoặc bỏ sai waypoint. Ca 10 NPC tạm dừng nhận thức thị giác để cô lập điều hướng. [Soak](../../tools/guard_soak_k17.gd)
- **Lối vào phía đông.** Driver cũ yêu cầu đi thẳng qua cụm kiện hàng. Đổi điểm dẫn hướng để vòng cụm kiện theo làn đang dùng ở đường rút. Lần chạy lại đi và thắng qua 83 waypoint, minimap khớp cả 83 lần. [Driver](../../tools/playthrough_k17.gd)

## 4. Đánh giá gameplay theo tiêu chí chuyên gia

Đây là đánh giá thiết kế của đợt rà soát. Thang 1–5 chấm mức tính năng hiện tại đáp ứng từng mục, dựa trên phân tích luật và kết quả kiểm thử.

| Tiêu chí | Điểm sơ bộ | Nhận định |
| --- | --- | --- |
| Bản sắc thử thách | 4/5 | Màn che làm thay đổi vị trí và góc nhìn thật. Hốc chữ L và W1/W2 cho người chơi quyết định lúc rẽ. Bước rút bằng chính cửa đi vào tạo cao trào từ không gian đã học. |
| Đọc nguyên nhân bị phát hiện | 3/5 | Vạch phát hiện, camera và âm thanh cho biết có nguy cơ. Người mới còn phải phân biệt độ khớp của màn đối với chốt, C1 bị chiếm quyền và tầm nhìn độc lập của lính bên hông. Ánh sáng tối dễ gợi nhầm về luật phát hiện. Dựa trên cách Martin Walsh mô tả việc khiến AI có quy luật và phản hồi nhất quán. [Ubisoft, GDC](https://www.youtube.com/watch?v=RFWrKHM0vAg) · [Game AI Pro 2](https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy%27s_Splinter_Cell_Blacklist.pdf) |
| Tự học và thao tác | 3/5 | Có checkpoint trước B1 và chế độ không lính. Khâu từ nắm xe đến quan sát C1, nhìn W1/W2 và dùng R dồn nhiều kiến thức vào một đoạn. Dựa trên playtest lặp và hướng dẫn qua nhiều kênh của *Blacklist*, cùng thiết kế lựa chọn stealth của Nels Anderson. [Ubisoft, Super Spy Crash Course](https://www.gdcvault.com/play/1020450/Super-Spy-Crash-Course-Teaching) · [Klei, GDC](https://gdcvault.com/play/1018948/Of-Choice-and-Breaking-New) |
| Chọn đường và phục hồi | 4/5 | Cửa hậu đã chuẩn bị tạo lợi thế cụ thể, lối bảo trì vận hành sau T+90 và đường vòng sân thắng với AI thật. Mục cần đánh giá thêm là người mới có nhận ra nhánh vòng trước khi vào vùng tiếp viện. Dựa trên phương pháp đặt cơ hội và ràng buộc cho nhiều cách đi của Arkane. [Harvey Smith, Yoann Saquet và Dana Nightingale](https://bethesda.net/en-US/news/designing-an-arkane-game-level) |
| Nhịp căng thẳng | 3/5 | Các mốc T+10, T+15, T+45, T+70, T+90 rõ về luật. Bốn lần chờ nhịp tự nhiên của driver mất khoảng 30–64 giây mỗi lần. Các lượt dùng R vẫn có lần chờ hơn 75 giây do kết hợp điều kiện chốt và tuần tra. Đây là thời gian chờ theo quy tắc chọn nhịp của driver. Dựa trên nhịp tăng áp lực và có khoảng giảm áp lực của Valve. [Michael Booth, Left 4 Dead, GDC](https://cdn.akamai.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf) |
| Giá trị của mục tiêu phụ | 4/5 | Giấy 04-B gắn rủi ro trong B1 với hệ quả của đoàn sơ tán, còn phá hoại đòi đổi đường hoặc dành thời gian ở xưởng. Cần thử đọc hiểu giá trị trước khi người chơi tiêu thời gian ở bàn hoặc tủ. |

### Kịch bản thử nghiệm với người chơi

Chạy với 6 người mới chơi K17, chia ngẫu nhiên 3 người bản hiện hành và 3 người bản thử, mỗi người có một lần tiếp xúc đầu tiên. Mời thêm 2 người đã biết đường để kiểm tra cả hai tuyến và lặp các pha chốt. Sau lượt đầu, dùng checkpoint B1 và ca T+70 để thu thêm dữ liệu theo cùng kịch bản. Áp dụng bản sửa HUD cho cả hai nhóm để đánh giá dấu hiệu gameplay trên cùng bố cục. Nhóm nhỏ cho phản hồi định tính và kiểm tra hướng thay đổi. Các ngưỡng dưới đây là mục tiêu thử vòng đầu.

| Cảnh | Kịch bản cho bản thử | Điều phối và đo |
| --- | --- | --- |
| **Cảnh 1. Nhận nhiệm vụ ở vành đai** | Lam nhắc trước khi vào. “Lấy Mật lệnh 04 sẽ kích hoạt báo động niêm phong. Nhớ lối rút trước khi xuống B1.” Sổ bàn giao đánh dấu có bản đính chính. Bảng khu vực cho thấy hướng sân và hướng bảo trì với chữ A/B nhất quán. | Giao mục tiêu chung là đưa hồ sơ ra ngoài. Đo thời gian tìm thẻ/chỉ dẫn, số lần đi ngược hướng và người có thể chỉ hai hướng rút trên bản đồ. |
| **C2. Lần đầu dùng màn che** | Ở bảng hack, hướng dẫn ngắn theo thứ tự nắm xe, nhìn feed trước, chuyển C1. Chỉ nhắc R khi đã vào hốc và máy trực sẵn sàng. Khi chốt quay, hiển thị “Chốt đang nhìn máy · kiểm tra W1/W2” cùng âm báo có phụ đề. | Bắt đầu từ checkpoint chung. Ghi thời gian từ hack tới hốc đầu, số lần nhấn V/R, lần chờ dài nhất, lần bị lộ và lý do người chơi tự kể. Mục tiêu 2/3 người mới bản thử tự vào được hốc đầu, giải thích đúng tuần tra vẫn nhìn độc lập. |
| **C3. Mở hồ sơ và cân nhắc 04-B** | Trước khi mở ngăn, thấy “04-B · Giữ E 3 giây · giờ phong tỏa đã sửa”. Vị trí và dấu nhận của bản chính/bản đính chính khác nhau. Khi báo động, lời của Lam ưu tiên hướng cửa, thông tin phụ lục ở prompt tại chỗ và nhật ký. | Ghi lựa chọn bỏ/lấy phụ lục, lý do và thời gian bỏ ra. Mục tiêu 2/3 người mới bản thử nói được lợi ích của 04-B và nhận ra mốc 120 giây bắt đầu khi lấy bản chính. |
| **C4. Thoát hoặc đổi tuyến** | Ở ngã rẽ sau cảm biến, bảng A và B nói rõ lối nào lên sân, lối nào qua chốt cơ. Khi cổng A chuẩn bị đóng, HUD giữ trạng thái và biển tại điểm rẽ ghi hướng B. Dấu hiệu từ chốt phản ứng nhìn thấy từ vật che trước khi đi vào đoạn hở. | Để người chơi tự chọn tuyến trước. Sau đó dựng T+70/T+90 để kiểm tra đổi tuyến, có và không chuẩn bị cửa hậu. Đo số lần rẽ nhầm, thời gian quay đầu, vị trí bị bắt, thời gian còn lại và lý do chọn đường. Mục tiêu 2/3 người mới bản thử đổi được sang B mà không cần gợi đường. |
| **C5. Kết quả và thử lại** | Bản chính xác nhận đã thu hồi. Có 04-B thì thông báo đoàn sơ tán đã đổi tuyến. Phá hoại là một dòng kết quả riêng sau tập kết. Khi bị bắt, thử lại tại checkpoint B1 và hỏi người chơi hành động nào muốn đổi. | Ghi số lần retry, thời gian quay lại điểm mắc, lý do thua theo lời người chơi và phân biệt tín hiệu nhìn/nghe/cảm biến. Đạt khi retry phục hồi đúng và người chơi tự nêu được lựa chọn hoặc nhịp đi muốn thử tiếp. |

Sau pha thử, điều phối viên hỏi người chơi về dấu hiệu họ quan sát, nguyên nhân lính phản ứng và cách đi nếu lối đó đóng. Ghi lại câu trả lời, đồng hồ và sự kiện trong lượt, rồi chấm theo cùng tiêu chí. Thử với âm thanh tắt/phụ đề bật và HUD 100%/125% trong lượt bổ sung. Ghi nguyên nhân của từng lần thất bại, kể cả lỗi nhiệm vụ, tín hiệu không rõ, lựa chọn tuyến và thời điểm di chuyển.

## 5. Đo đồ họa và thử tối ưu

### Chi phí dựng hình theo cảnh

Máy đo dùng i7-8850H, Quadro P1000, OpenGL Compatibility 3.3, driver NVIDIA 581.15. Đo khoảng cách giữa frame bằng đồng hồ thực, VSync tắt. p95 là ngưỡng mà 95% frame của mẫu nằm dưới hoặc bằng. CPU và renderer đều góp vào số đo. Các mốc dưới đây dùng pixel đầu ra xác minh từ ảnh readback. Giá trị `get_texture().get_size()` trong JSON ở cửa sổ 1080p báo 2880 × 1620, trong khi `Window.size` và ảnh đều là 1920 × 1080.

Ba góc cố định ở mặt đất chạy với camera bật và AI hoạt động. Mỗi cấu hình có hai lượt, mỗi lượt làm nóng hai giây và lấy mẫu bốn giây. Số lượt vẽ là chỉ số tổng của engine tại cuối mẫu.

| Góc nhìn | NPC | Đầu ra | p95 qua hai lượt | p99 qua hai lượt | Lượt vẽ tại cuối mẫu |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Sân | 10 | 1280 × 720 | 20,70–24,54 ms | 27,57–28,98 ms | 4.079 |
| Khối chỉ huy | 10 | 1280 × 720 | 14,35–16,72 ms | 16,92–18,53 ms | 2.646 |
| Dịch vụ | 10 | 1280 × 720 | 13,63–14,09 ms | 15,89–19,30 ms | 2.169–2.183 |
| Sân | 6 | 1920 × 1080 | 19,34–21,20 ms | 23,53–32,40 ms | 3.714 |
| Sân | 10 | 1920 × 1080 | 21,88–23,04 ms | 26,90–29,17 ms | 4.068 |
| Khối chỉ huy | 10 | 1920 × 1080 | 15,12–15,62 ms | 17,88–18,70 ms | 2.635 |
| Dịch vụ | 10 | 1920 × 1080 | 14,90–17,27 ms | 17,36–27,79 ms | 2.169 |

Góc sân vượt ngân sách thử 16,7 ms ở cả hai lượt 1080p, đồng thời có nhiều lượt vẽ nhất. Đây là nơi ưu tiên phân tích draw calls theo vật liệu, mesh và bóng. Với cảnh kết phá hoại 720p, ba mẫu dàn trạng thái có p95 **14,22–17,91 ms**, p99 **17,58–22,88 ms**. Đỉnh của lượt khởi động đầu là **43,37 ms** ở khoảng 0,1 giây đầu cảnh. Nên ghi lại riêng frame đầu khi profile cảnh kết. Dữ liệu ở `render-v4-720p.json`, `render-v4-1080p.json` và `render-finale.json`.

### Thử occluder cho B1

Thử tám mặt phẳng nằm trong các đoạn tường đặc ở B1, có chừa mép quanh cửa và cửa quan sát. So sánh tắt/bật/bật/tắt cho cả camera chính, viewport hình chiếu và viewport quan sát. Sáu lính dừng tại vị trí cố định, hình chiếu vẫn cập nhật. Mỗi mẫu làm nóng một giây và đo 3,5 giây. Cột dưới dùng trung bình hai giá trị p95 của mỗi biến thể.

| Đầu ra | Feed quan sát | p95 tắt occlusion | p95 bật occlusion |
| --- | --- | ---: | ---: |
| 720p | Ẩn feed | 7,61 ms | 7,38 ms |
| 720p | Camera trước | 6,32 ms | 7,51 ms |
| 720p | C1 | 8,22 ms | 9,07 ms |
| 1080p | Ẩn feed | 8,42 ms | 8,30 ms |
| 1080p | Camera trước | 9,52 ms | 10,48 ms |
| 1080p | C1 | 10,90 ms | 11,11 ms |

Sáu cặp ảnh ở cùng vị trí trùng RGB. Số lượt vẽ trung bình dao động theo mẫu và không giảm nhất quán. Với camera trước, p95 tăng ở cả hai kích thước cửa sổ. Giữ thử nghiệm ngoài scene K17 và dành lần đo tiếp theo cho góc sân. Các ảnh dàn một vị trí người vận hành và không đại diện cho cả tuyến đi trong B1. Dữ liệu ở `render-occlusion.json` và các cặp `b1_*_occlusion*.png`.

### Bố cục HUD tại 125%

Lần đầu, cả hai feed chạm vùng phụ đề ở mức 125% tại ba kích thước cửa sổ 1280 × 720, 1920 × 1080 và 1024 × 768. Cả sáu ca 100% qua. Bản sửa giới hạn chiều cao theo khoảng trống đến vùng phụ đề, giữ tỷ lệ hình 16:9 khi cần thu khung. Lần chạy lại đạt **12/12** ca với bốn dòng phụ đề, khung giữ 288 × 184 ở mức 100% và thu còn 244 × 159 đơn vị HUD ở mức 125%. Game dùng nội dung 16:9 ở cửa sổ 1024 × 768. Bài B1 feed, V7, V8, kiểm tra script và luồng menu đều qua sau sửa. Ảnh và kết quả nằm trong `hud-final/`. [Bố cục HUD K17](../../scripts/objective_hud.gd) · [Khung feed](../../scripts/projection_surveillance.gd)

## 6. Kế hoạch cải tiến tổng thể

| Ưu tiên | Hạng mục | Tiêu chí nghiệm thu |
| --- | --- | --- |
| **P0** | Tổ chức lại đúng lúc hiển thị ở bảng B1, phân biệt độ khớp màn, hướng nhìn của chốt và tuần tra bên hông. Bổ sung dấu hiệu chữ/hình cho ba pha cảm biến và nguyên nhân cảnh báo. Đưa bản thử vào các ca C2/C5. | Người mới đạt ngưỡng C2 và mô tả được tín hiệu gây phát hiện. Bộ B1/feed/V7/V8, retry và HUD tại 720p/1080p qua. |
| **P0** | Làm rõ lối vòng A trước chốt phản ứng, và đường B ở ngã rẽ trước S1 và trên HUD khi cảnh báo T+70. Dùng lối sân thẳng từng thất bại làm ca kiểm thử khả năng đọc tín hiệu khi rút. | Hai tuyến thắng ở các pha đã xác định, ca đổi tuyến đạt C4. Khoanh được trường hợp người chơi hiểu hướng và chấp nhận mạo hiểm. |
| **P1** | Nếu người mới chờ lâu ở B1, kiểm tra bằng cặp A/B giữa cấu hình hiện tại và một phương án giảm thời gian không có quyết định, chẳng hạn điều chỉnh pha tương đối của chốt và tuần tra. Thử cùng các pha 0/+4/+9 giây, có/không R. | Mục tiêu thử giảm tối thiểu 25% trung vị thời gian đứng chờ ở B1, HUD vẫn mô tả đúng luật và cửa sổ hợp lệ có cả hai cách dùng R hoặc nhịp tự nhiên. |
| **P1** | Viết lại sổ bàn giao, con dấu và thông điệp tập kết để làm rõ 04-B thay đổi giờ sơ tán. Kiểm tra C3/C5 với nhánh bản chính, 04-B, phá hoại và cả hai. | Người chơi giải thích được ý nghĩa canh giờ trước khi chọn, các nhánh cập nhật đúng kết quả và tài liệu giữ đúng thuần hư cấu của K17. |
| **P1** | Profile góc sân với 6 và 10 NPC. Thử từng nhóm mesh và shadow caster để biết phần nào giảm lượt vẽ. Sau đó thử gom prop trùng vật liệu theo ô sân, LOD cho đồ xa hoặc giảm số mesh đổ bóng. | Mục tiêu ban đầu 1080p p95 ≤ 16,7 ms trên máy chuẩn, 720p p95 ≤ 33,3 ms trên máy thấp. Dùng ba lượt 30 giây mỗi biến thể, báo p50/p95/p99, lượt vẽ và đỉnh ở báo động, mở camera và cảnh kết. Kiểm ảnh cho biển, camera, vệt cảm biến, vật che và đèn tập kết. |
| **P2** | Chốt bản thử phát hành sau vòng người chơi mới. Chạy lại ma trận K17, xuất gói, kiểm hai chế độ từ menu và thử trên máy mục tiêu thứ hai. | Bản thử giữ đủ ca B1/chốt/camera, hồ sơ/04-B/phá hoại, hồi phục checkpoint và hai tuyến rút. Ghi nhận ca còn rủi ro từ playtest và phân tích p95/p99 theo từng cảnh. |

Sửa gameplay theo từng thay đổi nhỏ trong `maps/intelligence/`. Bản thử đầu gom chỉ dẫn B1 và tín hiệu đổi đường. Dùng kết quả người mới để chọn có cần cân chỉnh nhịp chốt. Nhánh đồ họa đo và thử riêng ở góc sân, sau đó đo lại khi ghép với bản gameplay. Với thay đổi hình học, dùng builder nguồn, bake lại ánh sáng, rồi chạy kiểm tra collider/navmesh/minimap và cả lượt có lính lẫn không lính. [Luồng dựng và kiểm thử](../../README.md)

### Công cụ

- **Hiện có.** Godot 4.7.2, công cụ benchmark/preview của repo, Git và Blender 4.5.9 trên máy. Godot Profiler và Debugger Monitors có thể dùng ngay để xem script, vật lý và lượt vẽ. [Godot Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html)
- **Chỉ cài khi cần phân tích sâu.** RenderDoc để chụp khung OpenGL và tìm tập draw call, vật liệu hoặc pass tốn kém. PresentMon để đo nhịp trình bày frame trên Windows hoặc máy thứ hai. Cột thời gian CPU và latency của OpenGL có giới hạn theo tài liệu PresentMon. [RenderDoc](https://github.com/baldurk/renderdoc) · [PresentMon](https://github.com/GameTechDev/PresentMon#analyzing-opengl-and-vulkan-applications)
- **Khi xuất bản chơi độc lập.** Dùng export template đúng bản Godot cùng preset Windows Desktop. PCK trong đợt này đã chạy với máy Godot có sẵn. [Hướng dẫn đóng gói K17](../b1-refinement/COMMANDS.md)

### Chạy lại các bài chính

Gọi `godot` bằng binary 4.7.2 từ thư mục gốc repo. Lệnh cho nhóm B1, V8, soak, đổi tuyến và cả hai chế độ nằm ở README K17. Giữ log của lần thất bại khi sửa hoặc đổi đường.

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/encounters_v4.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/guard_soak_k17.gd -- --reinforced
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --route=maintenance --entry=maintenance --crouch --sprint-exfil
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --live-guards --crouch --camera-off --radio --wait-radio --sprint-exfil --watch-patrol --utilities-north --prepare --route=courtyard --natural-post --yard-flank
godot --headless --path . --export-pack "Windows Desktop" <đường-dẫn-tuyệt-đối>/game.pck
```

Đợt này đã kiểm tra build `2b582eb` bằng công cụ, sửa bố cục HUD K17 và thử occlusion trong phiên đo riêng. Kịch bản A/B gameplay đang chờ bản thử và nhóm người chơi. Chưa có mẫu trải nghiệm lần đầu hoặc số đo trên GPU thứ hai.
