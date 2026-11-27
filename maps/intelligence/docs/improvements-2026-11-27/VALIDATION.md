# Kết quả cải tiến K17

Ngày 27/11/2026 · `feature/twp` · mốc `2b582eb` cùng thay đổi tại workspace · Godot `4.7.2.stable.official.ed1daf0bf`. [Báo cáo gốc và kịch bản người chơi](../audit-2026-11-27/REPORT.md)

## Gameplay đã triển khai

- **B1.** HUD ghi phạm vi tác dụng của hình chiếu với chốt, camera hiện tại, thao tác V tiếp theo và hướng nhìn thật của chốt. Gợi ý R hiện tại hốc khi có thể yêu cầu. Dòng W1/W2 nhắc người chơi kiểm tra tuần tra bên hông trước khi rẽ. Âm báo máy trực có phụ đề. Bảng cảm biến hai mặt ghi S1/S2, ký hiệu **✓ QUA**, **△ CHỜ**, **× DỪNG** và thời gian đến pha kế tiếp. HUD hiện pha của dải gần người chơi khi họ đứng sát tia và có thể nhìn xuyên tới biển của dải kế tiếp. Cảnh báo chỉ rõ dải cảm biến hoặc C1 đã báo động. [HUD K17](../../scripts/objective_hud.gd) · [Điều khiển CCTV B1](../../scripts/projection_surveillance.gd) · [Cảm biến](../../scripts/sensor_lane.gd)
- **Đường rút.** Bảng B1 chỉ A lên sân và B sang bảo trì. Bảng tầng trệt dẫn tới lối vòng A. Bảng mới gắn vào xà cổng ở rìa sân phân biệt lối A qua mép nam và lối B sang đông. Minimap vẽ lối vòng A từ cùng tọa độ với driver đi bộ và gỡ vạch khi cổng nhận lệnh đóng. Bảng, HUD và minimap đọc cùng trạng thái cửa. [Bảng đường rút](../../scenes/props/k17_v7_presentation.tscn) · [Tọa độ lối vòng](../../resources/layout/k17_layout.gd)
- **Hồ sơ.** Sổ bàn giao giải thích giờ phong tỏa trong 04-B sớm hơn 20 phút và giúp đoàn sơ tán đổi tuyến. Bản chính và ngăn 04-B có nhãn riêng. Tương tác tại ngăn nói rõ giá trị của 04-B. Lời thoại sau khi lấy bản chính ưu tiên hướng cửa ra và hai tuyến, đồng thời xác nhận thời gian rút. Văn bản tập kết ghi hậu quả của việc giao 04-B. [Cảnh tài liệu](../../scenes/props/k17_v8_documents.tscn) · [Kết quả nhiệm vụ](../../scripts/mission_controller.gd)
- **Nhãn gỡ lỗi.** Lính tiếp viện nhận trạng thái F3 lúc xuất hiện. Điều này khắc phục việc nhãn thử nghiệm hiện xuyên tường trong lượt chơi khi F3 tắt. Kiểm tra bổ sung sinh đợt đầu khi F3 tắt và đợt hai khi F3 bật. [Mã tiếp viện](../../scripts/reinforcements.gd)

## Kiểm thử hồi quy

| Phạm vi | Bằng chứng |
| --- | --- |
| Nhiệm vụ, nấp, an ninh và hình học | `check_k17` đạt 617 phép kiểm. `check_navigation`, `check_art`, `check_attachments`, `check_sabotage` đạt khi chạy riêng. Kiểm tra an ninh xác nhận ký hiệu ở cả hai mặt biển, trạng thái của dải gần nhất trên HUD và sự kiện báo động đến từ S1 thật. |
| B1, HUD và 04-B | Projection 118, B1 56 và B1 feed 36 phép kiểm đều đạt. Lần có render cuối đạt 65 phép kiểm V7 và 57 phép kiểm V8. Ca pause, hủy giữ E, thử lại, phụ lục, cửa chờ vật cản, cổng đóng và khóa cơ đều được thử. |
| Layout | `preview_b1` đạt 12/12 ca, gồm hai feed ở ba kích thước cửa sổ, HUD 100%/125% và bốn dòng phụ đề. Ảnh camera, biển B1, biển sân và bàn hồ sơ lưu trong thư mục kết quả. |
| Lính và menu | Bốn ca truy đuổi, soak 90 giây với 6/10 NPC, kiểm tra script, hợp đồng map và `map_flow` đạt. Chốt B1 được kiểm theo vai trò đứng gác và phản ứng báo động. |
| Gói chơi thử | `K17-playtest.pck` xuất từ preset Windows Desktop, nạp từ thư mục ngoài repo và qua kiểm tra cả hai chế độ. Lượt đi từ PCK qua 130 waypoint, lấy 04-B, hoàn thành phá hoại và rút bảo trì với 59,4 giây còn lại. |

Các ca đi bộ bật điều khiển và AI giống chế độ chơi đã chọn. Driver dùng waypoint và vị trí lính để chọn thời điểm chờ. Ảnh layout dùng các tình huống dàn sẵn. Log và JSON ở `D:/CNPM/output/k17-improvements/`.

| Lượt đi bộ | Kết quả | Tiếp viện |
| --- | --- | ---: |
| Không lính, 04-B và phá hoại | Sân còn 49,5 giây. Bảo trì còn 52,2 giây. | 0 |
| Không lính, vào từ đông, rút bảo trì | Thắng, còn 58,4 giây | 0 |
| Có lính, lối vòng A theo nhịp chốt tự nhiên | Thắng, còn 72,0 giây | 3 |
| Có lính, đi thẳng qua chốt phản ứng | Bị bắt tại `(-12, 0, 8)` khoảng T+31,4 | 2 |
| Có lính, bảo trì, camera mặt đất bật | Thắng, còn 72,1 giây | 4 |
| Có lính, bảo trì, pha B1 +4 giây, chưa chuẩn bị cửa hậu | Thắng, còn 58,3 giây | 4 |
| Có lính, bảo trì, pha B1 +9 giây, 04-B và phá hoại | Thắng, còn 59,4 giây | 4 |

Ca đổi tuyến dàn trạng thái tại khối giữa với camera bật và cửa hậu đã chuẩn bị. Cả T+70 lẫn T+90 đều thoát, lần lượt còn **37,3** và **17,3 giây**. Trong hai lượt chạy riêng chưa chuẩn bị, Guard3 bắt người chơi ở điểm giữ E cửa hậu. Rủi ro này đưa vào playtest đổi tuyến và thử cách chuẩn bị trước khi xuống B1.

## Phương án tối ưu đồ họa

Bốn đèn sân dùng mờ dần riêng cho bóng động theo khoảng cách. Thông số ở asset và builder cùng đặt ngưỡng bóng 23 m, độ dài vùng chuyển 6 m và ngưỡng mờ ánh sáng 150 m. Ánh sáng trực tiếp có tầm 28 m. Giữ bốn cascade của đèn trăng giúp duy trì cách dựng bóng hiện tại ở các cạnh tường và mái. Dữ liệu LightmapGI tiếp tục dùng cho hình học tĩnh. [Nguồn dựng mỹ thuật](../../tools/k17_art_builder.gd) · [Godot 4.7, mờ dần ánh sáng và bóng](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html#light-shadow-distance-fade)

Pilot 1080p dùng hai mẫu bốn giây cho mỗi cấu hình với 10 NPC. Mờ bóng đèn sân giảm trung vị lượt vẽ từ khoảng 3.955 xuống 3.100 ở góc sân. Tắt hết bóng đèn sân giảm lượt vẽ sâu hơn và làm thay đổi màu vùng nền ở dưới mái trong ảnh thử. Mẫu hai cascade làm rõ ranh giới bóng trên một phần mái. Chọn mờ bóng theo khoảng cách, rồi kiểm bằng scene đóng gói và đo lại trước/sau bằng cùng cảnh.

Lượt đo xác nhận dùng Quadro P1000, OpenGL Compatibility, VSync tắt và kích thước ảnh đầu ra đọc từ renderer. Cảnh nào đo cũng dùng bản cuối với F3 tắt. Biến thể gốc tắt mờ bóng đèn sân trong thời gian đo. Cả hai biến thể dùng cùng điểm nhìn và camera mặt đất bật. AI vẫn chạy, còn lịch nhiệm vụ và số lính được đặt trước để so sánh các lượt. Mỗi lượt làm nóng hai giây. 1080p dùng ba lượt 30 giây mỗi biến thể ở 6 và 10 NPC. 720p dùng ba lượt 10 giây với 10 NPC trên cùng máy. Các số là khoảng cách giữa frame, gồm thời gian phía CPU và renderer.

| Góc sân | p50 gốc → bản thử | p95 gốc → bản thử | p99 gốc → bản thử | Lượt vẽ gốc → bản thử |
| --- | ---: | ---: | ---: | ---: |
| 1080p · 6 NPC | 13,18 → 11,46 ms | 18,95 → 17,01 ms | 22,36 → 20,03 ms | 3.775 → 2.581 |
| 1080p · 10 NPC | 16,78 → 13,95 ms | 23,45 → 20,41 ms | 28,85 → 23,80 ms | 4.269 → 2.834 |
| 720p · 10 NPC | 15,39 → 12,36 ms | 20,60 → 17,51 ms | 26,41 → 21,90 ms | 4.116 → 2.810 |

Bảng lấy trung vị của ba lượt cho từng chỉ số. Với 10 NPC, cả ba lượt bản thử có p95 **20,11–20,86 ms**, giảm khoảng **13%** theo trung vị. Trung vị lượt vẽ giảm khoảng **34%**. Ngân sách 16,7 ms ở góc sân 1080p vẫn chưa đạt ổn định trên máy đo. Xem `shadows-1080p.json` để đối chiếu từng lượt, kể cả đỉnh 37,00 ms ở biến thể gốc và 34,76 ms ở bản thử với 10 NPC.

Bốn cặp ảnh dàn cảnh 1080p cho khu giao sân, đường dịch vụ, cổng A và hành lang B1. Kiểm tra vị trí vật che, mặt biển, tia cảm biến và đèn tập kết bằng ảnh từ renderer. Lượt PresentMon độc lập thu **522 mẫu** tại góc sân với 10 NPC. RenderDoc chụp một frame OpenGL ở cùng góc sau khi đặt camera và sinh đủ lính. Dữ liệu ở `presentmon-yard-shipping.csv`, `renderdoc-capture.json` và `shadows-scenes.json`.

Cảnh kết phá hoại ở 720p với 10 NPC dùng ba lượt ngắn theo thời gian thật. p95 **11,63–18,55 ms**, p99 **16,04–28,01 ms**, đỉnh **45,05 ms** lúc đồng hồ cảnh kết đạt 4,02 giây. Dữ liệu ở `render-finale.json`.

Benchmark B1 mở lại kênh sau ca kiểm tra thu hồi và xác nhận mỗi camera cập nhật 25 lần trong mẫu 2,5 giây, với 0 lần khi ẩn feed. Ở 720p với sáu NPC giữ vị trí, p99 ổn định của camera trước là **8,57 ms** và C1 là **10,03 ms**. Trong giây đầu khi mở hoặc đổi góc, p99 lần lượt **9,05** và **10,57 ms**, đỉnh **9,64** và **12,90 ms**. Trong giây đầu sau báo động niêm phong, p99 **9,07 ms**, đỉnh **17,35 ms**. Hình chiếu ngừng cập nhật sau hồ sơ, khi ở xa và khi pause. Dữ liệu ở `b1-perf-final/performance.json`. [Benchmark B1](../../tools/benchmark_b1.gd)

## Vòng kiểm chứng với người chơi

Dùng bản thử để thực hiện các cảnh C2–C5 trong báo cáo gốc. Driver hiện ghi bốn lần chờ cửa sổ B1 mỗi lượt. Tổng thời gian chờ là 171,9 giây với nhịp tự nhiên và 126,2–138,7 giây qua ba cấu hình có R. Lượt có R vẫn có một lần chờ 75,3 giây. Đây là đường cơ sở theo quy tắc của driver.

Dữ liệu sáu người mới vẫn cần thu để xác nhận họ đọc đúng W1/W2, cách đổi B và giá trị 04-B. Điều chỉnh pha chốt và tuần tra khi người chơi vẫn gặp chờ dài, rồi so sánh trước/sau với mục tiêu giảm tối thiểu 25% thời gian chờ trung vị. Kiểm tra ngưỡng 720p trên máy cấu hình thấp trong vòng chơi thử phát hành.
