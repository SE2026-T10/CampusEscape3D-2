# Hiệu năng góc sân K17 với 10 NPC

| Độ phân giải | p95 trước | p95 sau | Mức giảm | Draw call trung vị trước → sau |
| --- | ---: | ---: | ---: | ---: |
| 1920 × 1080 | 21,60 ms | **15,43 ms** | 28,6% | 2.850 → 1.837 |
| 1280 × 720 | 18,99 ms | **13,48 ms** | 29,0% | 2.857 → 1.844 |

Cả ba lượt 1080p sau tối ưu đạt ngân sách 16,7 ms. Các lượt lần lượt là 15,53, 15,43 và 15,40 ms. Số đo thuộc một máy và một góc camera cố định.

K17 dùng hộp che khuất đặt lùi 4 cm bên trong mỗi mặt của các mảng tường và mái đặc. Các hộp bám từng mảng riêng để chừa nguyên lỗ cửa. Hàng rào lưới, kính quan sát và cánh cửa di động nằm ngoài tập hộp che. Cài đặt áp dụng cho viewport chính trong thời gian mở K17 và được khôi phục khi rời map. [Tài liệu Godot về occlusion culling](https://docs.godotengine.org/en/4.7/tutorials/3d/occlusion_culling.html)

## Cách đo lại

Chạy từ thư mục dự án. Cờ `--1080p` bật 1920 × 1080. Lệnh còn lại dùng 1280 × 720.

```text
godot --path . --script res://maps/intelligence/tools/benchmark_v4.gd -- --1080p --views=yard --counts=10 --power=on --occlusion=compare --seconds=20 --repeats=3 --out=res://ci-logs/k17-yard-1080p.json
godot --path . --script res://maps/intelligence/tools/benchmark_v4.gd -- --views=yard --counts=10 --power=on --occlusion=compare --seconds=20 --repeats=3 --out=res://ci-logs/k17-yard-720p.json
```

Máy đo chạy Windows, Godot 4.7.2, Quadro P1000 và renderer Compatibility. Công cụ xác nhận kích thước framebuffer, tắt VSync, làm nóng 2 giây và lấy mẫu thời gian thực trong 20 giây mỗi lượt. Camera đứng ở góc sân, hệ thống giám sát có điện và cả 10 NPC đều hoạt động sau hai đợt tiếp viện. Kịch bản giữ đồng hồ tại T+45 và vô hiệu hóa việc bị bắt để duy trì cùng tình huống trong suốt phép đo.

Mốc nguồn là `29d2db4` (`feature/twp`). Phép đo xen kẽ tắt/bật occlusion trên cùng scene. Lượt “trước” tắt occlusion theo cấu hình render của mốc nguồn. Kết quả đại diện là trung vị của ba p95, mỗi p95 tính từ thời gian giữa hai khung liên tiếp trong một lượt.

| Độ phân giải | p95 từng lượt trước (ms) | p95 từng lượt sau (ms) |
| --- | --- | --- |
| 1080p | 34,422 / 21,604 / 21,405 | 15,534 / 15,428 / 15,398 |
| 720p | 21,495 / 18,860 / 18,985 | 13,491 / 13,475 / 13,400 |

Đợt đo độc lập trên checkout `29d2db4` trước khi sửa cho trung vị p95 22,18 ms ở 1080p và 19,88 ms ở 720p. Bảng trên dùng đợt đo xen kẽ với cùng công cụ cho cả hai trạng thái.

## Kiểm tra hình ảnh

Scene tạo 78 hộp che. Đối chiếu 12 cặp ảnh 1080p, mỗi cặp giữ nguyên trạng thái cảnh và vị trí camera. Có 11 cặp giống từng pixel, gồm góc đo sân, dưới mái, ngã rẽ, cổng, mặt kính quan sát và hành lang B1. Ở góc hậu cần, 0,083% pixel lệch hơn hai mức màu, tập trung trên phần vỏ camera chốt đông. Đèn trạng thái và biển dưới camera vẫn đọc được.

## Kiểm thử hồi quy

- 621 phép kiểm K17, 72 phép kiểm mỹ thuật, 239 phép kiểm gắn vật thể và 65 phép kiểm B1 đạt. Kiểm tra mỹ thuật xác nhận các hộp nằm trong kết cấu đặc và viewport khôi phục cài đặt khi rời map.
- Hai bộ kiểm có render V7 và camera B1 cùng đạt 77 phép kiểm. Luồng mở, chơi lại và rời map đạt 100 phép kiểm; hợp đồng map và kiểm tra 270 script đạt.
- Chạy toàn nhiệm vụ có lính qua A còn 73,2 giây và qua B còn 67,1 giây. Cả hai lượt có 0 lần bị bắt và 0 lần chạm cảm biến. Bản thử không lính đạt cả hai tuyến.
- Gói Windows Desktop PCK xuất thành công và vượt qua kiểm tra nạp từ ngoài dự án ở cả chế độ thường và chế độ không lính.
