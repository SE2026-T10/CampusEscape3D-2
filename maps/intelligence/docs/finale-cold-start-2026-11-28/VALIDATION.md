# Khung đầu cảnh kết qua B trên Windows

Gói Windows từ `ec69243` ghi nhận 1.088,80 ms ở khung cắt sang góc xưởng trong lượt đầu 1080p. Khi tái hiện trên cùng máy bằng một tiến trình mới với thư mục cache ứng dụng trống, bản gốc có khung vào cảnh 726,614 ms. Lệnh xác nhận thoát chiếm 0,440 ms, còn khoảng từ `frame_pre_draw` tới `frame_post_draw` chiếm 724,320 ms. Chạy lại cùng thư mục cache cho khung đầu 12,031 ms. Ở 720p, cặp thăm dò cho 82,072 ms với cache trống và 12,567 ms khi dùng lại.

Các số đo đặt phần chậm trong lần dựng khung đầu ở renderer Compatibility. Bản gốc chuẩn bị góc xưởng qua viewport 32 × 32 rồi giải phóng viewport này. Hai phương án thử dựng trước ở kích thước đầy đủ vẫn có khung đầu chậm khi vào cảnh. Bản cuối giữ lại viewport đã chuẩn bị, dùng lại đúng bộ đệm và camera khi vào cảnh B, rồi giữ khung xưởng cuối phía sau bảng kết quả. Một lớp đen che quá trình chuẩn bị trong một khung lúc tải K17. Tài liệu Godot mô tả việc dựng trước shader trong tầm nhìn khi dùng Compatibility. [Godot về giảm khựng do biên dịch shader](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)

Góc máy B giữ bóng trăng ở phạm vi 24 m và bỏ lượt đổ bóng của đèn cục bộ trong viewport này. Đèn vẫn chiếu sáng cảnh. Nền 3D có chiều cao tối đa 900 pixel, nên bản xuất 1920 × 1080 dựng nền ở 1600 × 900. Ở 1280 × 720, nền chạy ở kích thước gốc. Giao diện kết quả dùng độ phân giải cửa sổ.

## Phương pháp đối chứng

Đo hai bản Windows release từ `ec69243` và nhánh PR trên Core i7-8850H, Quadro P1000, driver NVIDIA 581.15 và Godot 4.7.2 Compatibility. Mỗi lượt mở một tiến trình mới, dùng thư mục `APPDATA` riêng để Godot tạo cache shader ứng dụng mới, tắt VSync, xác nhận kích thước bộ đệm ảnh của cửa sổ và làm nóng hai giây sau khi dựng trạng thái. Cache trình điều khiển trên đĩa được giữ lại và có thể được dùng lại giữa các lượt. Hai bản dùng chung kịch bản thoát qua B khi có 10 NPC và đổi thứ tự trong ba cặp ở mỗi độ phân giải. [Thiết lập cache Compatibility trong mã nguồn Godot](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/rasterizer_gles3.cpp#L311-L338)

Khoảng đo bắt đầu khi xác nhận đường rút và kết thúc sau khung đầu trạng thái `WIN`. Ngưỡng p95 tính theo từng lượt. Đỉnh lúc tải map và đỉnh trong 750 ms sau `WIN` được ghi riêng. Thời gian render ở đây là khoảng giữa hai tín hiệu của engine.

## Kết quả trước và sau

| Độ phân giải đầu ra | Khung vào cảnh, trung vị (ms) | p95, trung vị (ms) | Khung chậm nhất (ms) | Khung đầu `WIN`, trung vị (ms) | Khung đầu `WIN` chậm nhất (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1080p | 55,305 → 53,116 | 17,286 → 18,312 | 57,965 → 74,305 | 13,994 → 17,235 | 16,831 → 19,744 |
| 720p | 88,248 → 43,150 | 13,735 → 15,798 | 114,377 → 62,755 | 12,872 → 9,944 | 13,322 → 10,812 |

Ở 720p, cả ba cặp đều giảm khung vào cảnh và khung đầu `WIN`. Khung chậm nhất giảm 45,1% trong khi p95 trung vị tăng 2,063 ms. Ở 1080p, khung vào cảnh trung vị giảm 2,189 ms, đồng thời khung chậm nhất và p95 tăng. P95 1080p của bản sửa nằm trên mốc 16,7 ms ở cả ba lượt.

Đỉnh trong 750 ms sau `WIN` lần lượt là 26,438 → 34,558 ms ở 1080p và 24,526 → 20,610 ms ở 720p. Trung vị của đỉnh lúc tải map là 1.496,296 → 1.402,827 ms ở 1080p và 1.613,724 → 1.352,546 ms ở 720p.

Trong cả 12 lượt đối chứng, khung chậm nhất trùng với khung vào cảnh. Lượt thăm dò có cú khựng 726,614 ms trước khi chạy đợt đối chứng. Số đo lớn nhất trong đợt đối chứng là 114,377 ms, nên kết quả hiện tại chỉ xác nhận hiệu quả với các cú khựng cỡ này. Đánh giá biên dịch shader vẫn dựa trên dấu hiệu cache và thời gian dựng khung trên một cấu hình GPU.

| Độ phân giải | Lượt | Khung vào cảnh và khung chậm nhất trước → sau (ms) | p95 trước → sau (ms) | Khung đầu `WIN` trước → sau (ms) |
| --- | ---: | ---: | ---: | ---: |
| 1080p | 1 | 53,136 → 53,116 | 17,286 → 18,167 | 16,831 → 19,744 |
| 1080p | 2 | 55,305 → 52,912 | 17,750 → 18,312 | 13,002 → 14,580 |
| 1080p | 3 | 57,965 → 74,305 | 17,010 → 19,233 | 13,994 → 17,235 |
| 720p | 1 | 88,017 → 43,150 | 12,651 → 14,885 | 13,322 → 10,812 |
| 720p | 2 | 88,248 → 62,755 | 13,735 → 15,846 | 12,081 → 9,944 |
| 720p | 3 | 114,377 → 42,173 | 16,472 → 15,798 | 12,872 → 8,167 |

## Đo lại từ mã nguồn

Dùng Godot 4.7.2 và renderer thật. Khi cần đo lần đầu, đặt `APPDATA` của tiến trình Godot vào một thư mục trống riêng cho mỗi lượt. Chạy các lệnh sau từ thư mục dự án.

```text
godot --path . --script res://maps/intelligence/tools/benchmark_sabotage.gd -- --1080p --repeats=1 --out=user://finale-1080p.json
godot --path . --script res://maps/intelligence/tools/benchmark_sabotage.gd -- --repeats=1 --out=user://finale-720p.json
```
