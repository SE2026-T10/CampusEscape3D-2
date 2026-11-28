# Khung đầu cảnh kết qua B trên Windows

Gói Windows từ `ec69243` ghi nhận 1.088,80 ms ở khung cắt sang góc xưởng trong lượt đầu 1080p. Khi tái hiện trên cùng máy bằng một tiến trình mới với thư mục cache ứng dụng trống, bản gốc có khung vào cảnh 726,614 ms. Lệnh xác nhận thoát chiếm 0,440 ms, còn khoảng từ `frame_pre_draw` tới `frame_post_draw` chiếm 724,320 ms. Chạy lại cùng thư mục cache cho khung đầu 12,031 ms. Ở 720p, cặp thăm dò cho 82,072 ms với cache trống và 12,567 ms khi dùng lại.

Các số đo đặt phần chậm trong lần dựng khung đầu ở renderer Compatibility. Bản gốc chuẩn bị góc xưởng qua viewport 32 × 32 rồi giải phóng viewport này. Hai phương án thử dựng trước ở kích thước đầy đủ vẫn có khung đầu chậm khi vào cảnh. Bản cuối giữ lại viewport đã chuẩn bị, dùng lại đúng bộ đệm và camera khi vào cảnh B, rồi giữ khung xưởng cuối phía sau bảng kết quả. Viewport này còn ẩn trong lúc chuẩn bị. Ảnh kiểm tra khi tải K17 ghi nhận góc nhìn người chơi. Tài liệu Godot mô tả việc dựng trước shader trong tầm nhìn khi dùng Compatibility. [Godot về giảm khựng do biên dịch shader](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)

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

## Lần chỉnh tiếp PR #54

Góc máy B đứng yên và các NPC đã bị đóng băng khi xác nhận thoát. Cảnh dùng một ảnh nền ngoại cảnh chuẩn bị lúc tải map, với lượt dựng dự phòng nếu kích thước bộ đệm thay đổi. Nền được giữ trong lúc nổ và khi hiện bảng kết quả. Viewport trong suốt chỉ vẽ lửa, khói và tia lửa ở cùng góc máy. Ánh chớp qua B dùng quầng sáng cục bộ tại điểm nổ. Nền giữ giới hạn 900 px chiều cao từ bản PR trước, còn lớp hiệu ứng có giới hạn 720 px. Bảng kết quả được vẽ ở độ phân giải cửa sổ.

Đối chứng trên ba bản Windows release với cùng công cụ đo và cùng nội dung nhiệm vụ. `feature/twp` ở `ec69243` là mốc tích hợp, `7d1a7fb` là mốc PR #54 trước lần chỉnh này. Hai mốc được đo xen kẽ với một bản thử, sau đó đo bản cuối trong cùng phiên. Mỗi bản có ba lượt ở mỗi độ phân giải. Từng tiến trình dùng thư mục cache ứng dụng trống riêng. Kích thước bộ đệm cửa sổ được xác nhận bằng ảnh render, VSync tắt và có 10 NPC trước khi cắt cảnh. Cache trình điều khiển trên đĩa được giữ lại.

| Độ phân giải | Bản | Khung vào cảnh, trung vị | p95, trung vị | Khung chậm nhất | Khung đầu `WIN`, trung vị | Khung đầu `WIN` chậm nhất |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1080p | `feature/twp` | 54,865 | 15,895 | 63,057 | 16,593 | 17,594 |
| 1080p | PR #54 cũ | 51,469 | 15,896 | 52,114 | 16,541 | 17,910 |
| 1080p | PR #54 mới | 4,725 | 6,524 | 42,804 | 26,521 | 42,804 |
| 720p | `feature/twp` | 86,124 | 13,988 | 91,976 | 13,421 | 14,048 |
| 720p | PR #54 cũ | 42,152 | 13,390 | 55,951 | 7,922 | 8,288 |
| 720p | PR #54 mới | 3,965 | 5,418 | 14,939 | 8,043 | 8,260 |

Tất cả số trong bảng dùng mili giây. P95 1080p cao nhất của bản mới là 10,009 ms, nên cả ba lượt đạt mốc 16,7 ms. P95 720p giảm khoảng 60% và khung vào cảnh giảm khoảng 91% ở cả hai độ phân giải so với PR #54 cũ. Khung chậm nhất trong khoảng đo giảm, còn khung đầu `WIN` 1080p tăng. Hai đỉnh 1080p của bản mới xảy ra ngay khung đầu `WIN`. Ở 720p, ba đỉnh xảy ra khoảng 0,68–0,88 giây sau khi vào cảnh, gần lúc nổ.

Trong 750 ms sau khung `WIN`, đỉnh tăng từ 31,369 lên 85,684 ms ở 1080p và giảm từ 21,382 còn 19,331 ms ở 720p. Khoảng 750 ms này nằm ngoài p95 và khung chậm nhất trong bảng.

| Độ phân giải | Bản | Lượt | Khung vào cảnh (ms) | p95 (ms) | Khung chậm nhất (ms) | Khung đầu `WIN` (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1080p | `feature/twp` | 1 | 54,865 | 16,653 | 54,865 | 17,594 |
| 1080p | `feature/twp` | 2 | 53,717 | 15,687 | 53,717 | 16,593 |
| 1080p | `feature/twp` | 3 | 63,057 | 15,895 | 63,057 | 13,576 |
| 1080p | PR #54 cũ | 1 | 50,891 | 14,990 | 50,891 | 16,541 |
| 1080p | PR #54 cũ | 2 | 51,469 | 15,896 | 51,469 | 15,120 |
| 1080p | PR #54 cũ | 3 | 52,114 | 16,261 | 52,114 | 17,910 |
| 1080p | PR #54 mới | 1 | 4,644 | 6,440 | 26,521 | 26,521 |
| 1080p | PR #54 mới | 2 | 4,725 | 6,524 | 42,804 | 42,804 |
| 1080p | PR #54 mới | 3 | 6,620 | 10,009 | 18,583 | 11,671 |
| 720p | `feature/twp` | 1 | 64,284 | 13,988 | 64,284 | 13,421 |
| 720p | `feature/twp` | 2 | 86,124 | 13,969 | 86,124 | 12,280 |
| 720p | `feature/twp` | 3 | 91,976 | 15,009 | 91,976 | 14,048 |
| 720p | PR #54 cũ | 1 | 55,951 | 13,390 | 55,951 | 7,464 |
| 720p | PR #54 cũ | 2 | 41,643 | 14,619 | 41,643 | 8,288 |
| 720p | PR #54 cũ | 3 | 42,152 | 12,980 | 42,152 | 7,922 |
| 720p | PR #54 mới | 1 | 3,965 | 5,418 | 14,939 | 8,260 |
| 720p | PR #54 mới | 2 | 3,936 | 5,490 | 10,061 | 8,043 |
| 720p | PR #54 mới | 3 | 4,813 | 5,395 | 10,002 | 7,247 |
