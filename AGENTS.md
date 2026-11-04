# Hướng dẫn cho AI Agent

Trước khi thực hiện task trong repository này, hãy đọc file này trước, sau đó:

1. Đọc [`docs/ai/PROJECT_CONTEXT.md`](docs/ai/PROJECT_CONTEXT.md) để nắm tổng quan và trạng thái các map.
2. Đọc [`docs/ai/ARCHITECTURE.md`](docs/ai/ARCHITECTURE.md) để hiểu cách các hệ thống phối hợp.
3. Tra [`docs/ai/MODULE_INDEX.md`](docs/ai/MODULE_INDEX.md) để khoanh vùng source liên quan.
4. Tra [`docs/ai/FEATURE_REGISTRY.md`](docs/ai/FEATURE_REGISTRY.md) khi task đụng tới một tính năng.
5. Đọc [`docs/ai/CHANGELOG.md`](docs/ai/CHANGELOG.md) khi cần hiểu thay đổi gần đây.

## Quy tắc kiểm tra và thay đổi

- Chỉ đọc source của module liên quan trực tiếp. Nếu cần hiểu sâu, lần theo các dependency trực tiếp thay vì quét toàn repository.
- Tài liệu AI là bản đồ tra cứu, không phải nguồn sự thật tuyệt đối. Xác minh source hiện tại khi task chạm tới hành vi, dependency, API hoặc nội dung tài liệu có dấu hiệu cũ.
- Không tự ý đổi kiến trúc/API dùng chung; tái sử dụng hệ thống có sẵn và không tạo script, scene hoặc hệ thống trùng lặp.
- Trước khi sửa, đánh giá các map/tính năng phụ thuộc. Không xóa hay ghi đè hành vi hiện có nếu chưa hiểu ảnh hưởng.
- Giữ thay đổi trong phạm vi task; không đổi gameplay hoặc phiên bản game chỉ để cập nhật tài liệu.
- Không commit hoặc push trừ khi người dùng yêu cầu.

## Quy trình bắt buộc cho mỗi task

1. **Đọc ngữ cảnh:** đọc các tài liệu ở trên; xác định module, trạng thái tính năng và thay đổi liên quan trong changelog.
2. **Phân tích phạm vi:** lập danh sách file cần kiểm tra/sửa và dependency trực tiếp; xác minh những điểm có thể ảnh hưởng tới tính năng khác. Không đọc toàn bộ source ngay từ đầu.
3. **Thực hiện:** ưu tiên hệ thống/API đã có; giữ kiến trúc hiện tại nếu không có lý do rõ ràng để đổi; kiểm soát ảnh hưởng giữa các map.
4. **Kiểm thử:** chạy test phù hợp theo [`docs/ai/TESTING_GUIDE.md`](docs/ai/TESTING_GUIDE.md). Khi sửa shared/features, đánh giá tất cả map dùng chúng; khi sửa map riêng, kiểm tra map đó và luồng chuyển map. Báo rõ kết quả, lỗi và test chưa chạy.
5. **Cập nhật tài liệu sau mọi thay đổi source code:** cập nhật `MODULE_INDEX.md`, `ARCHITECTURE.md`, `DATA_FLOW.md`, `FEATURE_REGISTRY.md` và/hoặc `TESTING_GUIDE.md` khi nội dung tương ứng thay đổi; ghi thay đổi, test và giới hạn còn lại trong `CHANGELOG.md`. Tạo ADR trong `docs/ai/decisions/` khi có quyết định kiến trúc đáng lưu giữ. Không ghi thông tin chưa xác minh.

## Ưu tiên phạm vi đọc

- Bắt đầu từ `MODULE_INDEX.md` và `FEATURE_REGISTRY.md`, rồi mở các file source được nêu cho đúng task.
- Nếu tài liệu mâu thuẫn với source hoặc một tài liệu khác, dùng source hiện tại và kiểm thử đang đăng ký để xác minh; cập nhật tài liệu liên quan, đồng thời ghi nhận độ lệch quan trọng.
- Không đọc lại module không liên quan nếu tài liệu vẫn khớp source và task không phụ thuộc vào nó.
