# Chỉnh nhịp chốt B1

Mốc trước là `343fd3d` trên `feature/twp`. Bản đề xuất đặt 26 giây cho lần quan sát đầu tiên và 18 giây cho các lần quan sát tiếp theo. Mốc cũ là 30 giây cho cả hai. Nếu chốt giữ vị trí, lần quay sang máy đầu tiên đến sớm hơn 4 giây. Sau một lượt kiểm tra tự nhiên dài 9,5 giây, chu kỳ từ lần quay này đến lần quay kế tiếp giảm từ 39,5 xuống 27,5 giây. Nhịp mới thay đổi lúc chốt quay máy so với vòng tuần tra W1/W2. Tuần tra vẫn đánh giá tầm nhìn theo vị trí thật. Bản thử chỉ giảm cả hai mốc xuống 18 giây từng làm lần chờ đầu trên tuyến tự nhiên tăng lên 88,9 giây, nên chọn mốc đầu riêng.

## So sánh cùng ca

Godot 4.7.2, vật lý 60 tick/giây, `playthrough_k17.gd` giữ nguyên. Cột chờ chuyển hốc cộng bốn dòng `[B1 timing]` của mỗi lượt. Cột chờ lấy hồ sơ ghi riêng dòng `[B1 pickup timing]`, trước khi bắt đầu đồng hồ rút lui. `+4` và `+9` là số giây chờ thêm ở điểm chuẩn bị B1 ngay trước khi chiếm kênh.

| Ca có lính | Chờ chuyển hốc trước → sau (giây) | Chờ lấy hồ sơ trước → sau (giây) | Thời gian còn khi thoát trước → sau (giây) |
| --- | ---: | ---: | ---: |
| A vòng sân, chốt theo nhịp tự nhiên | 171,92 → 66,65 | 0,43 → 2,90 | 72,0 → 73,0 |
| B, dùng R, pha gốc | 135,15 → 74,63 | 2,95 → 29,18 | 68,6 → 66,3 |
| B, dùng R, +4, cửa hậu chưa chuẩn bị | 136,83 → 76,30 | 2,98 → 29,23 | 58,3 → 64,0 |
| B, dùng R, +9, lấy 04-B và phá hoại | 126,15 → 65,63 | 0,00 → 25,78 | 59,4 → 56,7 |

- Trung vị tổng chờ chuyển hốc mỗi lượt giảm **135,99 → 70,64 giây (48%)**. Trung vị của 16 lần chuyển hốc giảm **25,67 → 16,67 giây (35%)**. Lần chờ chuyển hốc dài nhất giảm **75,27 → 32,73 giây**.
- Thời gian chờ ngay trước khi lấy hồ sơ tăng trong ba ca dùng R, vì driver tới nơi ở pha khác và chờ chân tuần tra ở W2. Khi cộng đoạn này, trung vị tổng chờ mỗi lượt vẫn giảm **138,96 → 97,62 giây (30%)**.
- Bốn lượt mới hoàn thành cả nhiệm vụ với 509 waypoint, 0 lần bị bắt và 0 lần kích hoạt cảm biến S1/S2. Bản không lính lấy 04-B và phá hoại, thoát qua B với 52,2 giây ở cả hai bản.
- Ca đối chứng bật camera vẫn bị Guard5 bắt trước B1. Ca đổi sang B ở T+70/T+90 vẫn hoàn thành khi cửa hậu đã chuẩn bị và vẫn bị Guard3 bắt ở khóa cơ khi chưa chuẩn bị.

## Kiểm tra hồi quy

- K17 621 phép kiểm, B1 60, projection 118, camera B1 36, V7 61, V8 55 và luồng map 100. Bổ sung bốn phép kiểm cho thời điểm chốt bắt đầu, thời lượng kiểm tra và mốc được dùng lại sau đó. Các ca R bị ngắt do điều tra, hồi yêu cầu, đối chiếu kênh, pause và thử lại vẫn đạt.
- Kiểm tra tải 269 script, hợp đồng map và 12 ca bố cục B1 có render. Cả hai chế độ tải được từ gói Windows Desktop PCK. Lượt có lính lấy 04-B và phá hoại trong bản PCK cũng hoàn thành 130 waypoint và thoát qua B với 56,7 giây còn lại.
- Các số đo phản ánh điều kiện quan sát của driver. Còn thiếu dữ liệu về thời gian chờ và cách đọc tín hiệu của người chơi lần đầu.

## Chạy lại các lượt chính

Chạy từ thư mục dự án với binary Godot 4.7.2 đặt trong `$godot`.

```powershell
$driver = @('--headless', '--path', '.', '--fixed-fps', '60', '--max-fps', '600',
    '--script', 'res://maps/intelligence/tools/playthrough_k17.gd', '--')
$guarded = @('--live-guards', '--crouch', '--camera-off', '--radio', '--wait-radio',
    '--sprint-exfil', '--watch-patrol', '--utilities-north')

& $godot @driver @guarded --prepare --route=courtyard --natural-post --yard-flank
& $godot @driver @guarded --prepare --route=maintenance
& $godot @driver @guarded --route=maintenance --projection-delay=4
& $godot @driver @guarded --prepare --route=maintenance --projection-delay=9 --annex --handover --sabotage
& $godot @driver --route=maintenance --crouch --camera-off --sprint-exfil --annex --sabotage
```
