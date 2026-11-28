# Hiệu năng cảnh kết phá hoại qua B

Đợt đo 27–28/11/2026 chạy trên Windows với Core i7-8850H, NVIDIA Quadro P1000 và Godot 4.7.2 Compatibility. Bản trước là `85b50e9` trên `feature/twp`. Hai bản Windows release dùng cùng kịch bản dựng trạng thái, tắt VSync, làm nóng hai giây và xác nhận kích thước bộ đệm hình ảnh thực tế. Mỗi bản chạy bốn lượt ở mỗi độ phân giải, mỗi lượt một tiến trình, đổi thứ tự chạy giữa các cặp. Cả mười NPC có mặt trước khi kích hoạt thoát qua B. Trò chơi đóng băng NPC sau khi xác nhận thoát như trong lượt chơi thường.

Đo khoảng thời gian giữa các tín hiệu `frame_post_draw`, từ lúc kích hoạt qua B đến hết khung đầu tiên ở trạng thái `WIN`. Khoảng đo gồm cả thời điểm vào góc máy và kích hoạt hiệu ứng. Tính p95 theo từng lượt, dùng trung vị của bốn p95 để đối chiếu với mốc 16,7 ms, đồng thời ghi khung chậm nhất quan sát được. Kiểm tra thêm 750 ms sau khung `WIN`. Phiên chụp ảnh riêng được dùng để so sánh hình ảnh, vì thao tác đọc và lưu ảnh làm tăng thời gian khung hình.

Góc máy xưởng qua B dùng phạm vi bóng trăng tối đa 24 m và cho bóng của hai đèn sân phía đông bắt đầu mờ từ 16 m. Máy quay giữ góc xưởng sau vụ nổ trong khi bảng kết quả hiện lên. Bảng kết quả K17 chuẩn bị sẵn ký tự khi tải map, bỏ viền chữ trên nền tối và dùng hiệu ứng mờ dần cho tiêu đề ở kích thước cố định. Khi khôi phục checkpoint, camera, HUD và khoảng đổ bóng trở về cấu hình chơi.

## So sánh trước và sau

| Độ phân giải | Trung vị p95 toàn cảnh | Khung chậm nhất toàn cảnh | Trung vị khung đầu `WIN` | Khung đầu `WIN` chậm nhất |
| --- | ---: | ---: | ---: | ---: |
| 1080p | 18,569 → 15,717 ms | 52,806 → 30,808 ms | 40,666 → 25,709 ms | 52,806 → 30,515 ms |
| 720p | 17,228 → 19,451 ms | 61,286 → 42,246 ms | 25,843 → 16,102 ms | 26,445 → 20,703 ms |

Ở 1080p, trung vị p95 giảm 15,4% và đạt mốc 16,7 ms. Ba trong bốn lượt của bản tối ưu đạt mốc. Lượt thứ tư có p95 17,338 ms. Bốn khung đầu `WIN` vẫn trên 16,7 ms, dù nhanh hơn bản trước ở từng cặp. Ở 720p, khung đầu `WIN` nhanh hơn trong cả bốn cặp và khung chậm nhất toàn cảnh giảm, đồng thời p95 trung vị tăng 2,223 ms. Khung chậm nhất trong 750 ms sau `WIN` tăng từ 19,294 lên 24,116 ms ở 1080p và từ 14,864 lên 19,768 ms ở 720p. Kết quả hiệu năng hiện có trên một cấu hình máy.

| Độ phân giải | Lượt | p95 trước → sau (ms) | Khung chậm nhất trước → sau (ms) | Khung đầu `WIN` trước → sau (ms) |
| --- | ---: | ---: | ---: | ---: |
| 1080p | 1 | 20,611 → 14,602 | 41,679 → 24,279 | 41,679 → 20,435 |
| 1080p | 2 | 17,460 → 16,398 | 39,652 → 30,808 | 39,652 → 30,515 |
| 1080p | 3 | 19,678 → 15,036 | 33,820 → 22,447 | 33,820 → 22,447 |
| 1080p | 4 | 15,943 → 17,338 | 52,806 → 28,972 | 52,806 → 28,972 |
| 720p | 1 | 26,304 → 22,758 | 61,286 → 42,246 | 26,304 → 16,842 |
| 720p | 2 | 18,409 → 20,418 | 32,504 → 28,989 | 24,690 → 15,362 |
| 720p | 3 | 14,987 → 18,484 | 25,381 → 27,601 | 25,381 → 20,703 |
| 720p | 4 | 16,047 → 13,716 | 26,445 → 21,143 | 26,445 → 13,192 |

Ảnh 1080p xác nhận hiệu ứng lửa, phụ đề và hình khối xưởng vẫn đọc được trong cảnh kết. Bảng kết quả giữ nội dung bàn giao, đường bảo trì, trạng thái phá hoại và hai nút điều hướng. Nền phía sau bảng chuyển sang góc xưởng và không hiện HUD đang chơi.

## Chạy lại từ mã nguồn

Các lệnh dùng renderer thật, có cửa sổ. Lặp lại mỗi lệnh trong tiến trình mới nếu cần kiểm tra riêng lần đầu mở bảng kết quả.

```text
godot --path . --script res://maps/intelligence/tools/benchmark_sabotage.gd -- --1080p --repeats=1 --out=user://finale-1080p.json
godot --path . --script res://maps/intelligence/tools/benchmark_sabotage.gd -- --repeats=1 --out=user://finale-720p.json
```
