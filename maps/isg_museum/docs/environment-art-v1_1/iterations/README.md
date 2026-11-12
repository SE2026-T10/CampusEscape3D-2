# Lượt chuẩn bị và đo chưa đạt tuyến

Thư mục này giữ log/JSON trung gian, không dùng làm kết quả nghiệm thu v1.1.

- `gameplay-smoke.log` và các file `after-gameplay.*` đầu tiên: smoke 65 giây, chưa đủ tuyến.
- `incomplete-course-after-gameplay.*`: lượt native 240 giây dùng autopilot đặt đích sau cửa kho đang đóng; player đi vòng về thang A, chưa giao tranh/chưa qua thang B. Lượt này bị đánh dấu `course_valid=false` và exit 1.
- `incomplete-course-benchmark-run.json` giữ bản ghi nguyên thủy của lượt trên, gồm cấu trúc JSON PowerShell chưa chuẩn hóa.
- Các log compile/apply/capture còn lại thuộc giai đoạn sửa lỗi công cụ, trước lần validation cuối.

Tuyến cuối dùng waypoint trước/sau cửa và hai nhịp thang, thêm kiểm tra capsule tránh world/NPC; giữ input, controller, collider, perception và NavigationAgent của guard. `../course-check.json` xác nhận tuyến ở headless fixed-fps; `../after-gameplay.json` là lượt native 240 giây hợp lệ dùng cho benchmark cuối. Toàn bộ suite cuối và exit code nằm trong `../VALIDATION.json`.
