# Đề xuất tổng thể bảo tàng — 11/11/2026

Ba ảnh concept để thảo luận thiết kế trước khi bàn giao Coding Agent. Tạo bằng image_gen tích hợp từ ảnh phong cách và hai sơ đồ hiện tại do người dùng gửi, bảng model thật và preview bộ Gothic đã tải. Các scene và mã nguồn game không thay đổi.

| Ảnh | Nội dung duyệt |
|---|---|
| [01-courtyard-style.png](01-courtyard-style.png) | Cột vòm, lan can đá, mái kính hai dốc, bốn tượng trên bệ, cây và vách che |
| [02-floor-1-overview.png](02-floor-1-overview.png) | Các phòng tầng 1, nội thất, sân trước, đồng đội và năm vị trí bảo vệ minh họa |
| [03-floor-2-overview.png](03-floor-2-overview.png) | Phòng A/B/C, khoảng thông tầng, hai thang, kho phục chế và tập kết T2 |

Giữ khung nhà 36 × 30 m, sân 12 × 12 m, hành lang vòng 3 m, bốn lối sân rộng 2 m và vòng đi quanh đài phun nước. Vách giữa cột dự kiến tường đặc 0,9 m cộng bụi dày 0,3 m. Bốn bệ tượng cao khoảng 1,2 m thay cho bốn khối/chậu cây che chắn. Mẫu tượng Terpsichore được dùng lặp lại với hướng quay khác nhau để phù hợp thư viện hiện có.

Tầng 1 có một cửa phòng nhân viên, tủ kho sát tường, dây ở kho phụ và N0 bên phải cửa chính. H1 là huy chương bạc ruy băng xanh; H2 là đồng hồ bỏ túi. Tầng 2 không có sàn trong vùng sân; phòng B ngăn kho bằng tường đặc. Kho phục chế và tập kết T2 là một phòng liên tục, chỉ vào từ phòng đệm phía nam; cửa sổ thoát ở tường đông. Hình mặt bằng bỏ mái để thấy nội thất.

Đây là ảnh concept AI, không phải ảnh chụp game hay bản vẽ thi công có tỷ lệ bảo đảm. Hình dáng, chi tiết nội thất, đèn, bề mặt, tư thế người và khoảng cách có thể được giản lược. Đối chiếu scene hiện hành và tọa độ khi bàn giao triển khai. Các vị trí người trên ảnh minh họa hoạt động, không thay thế waypoint tuần tra.

Mái kính, bệ, vách, màu đá, hàng cây cắt gọn và các chi tiết kiến trúc là phần đề xuất cần dựng hoặc điều chỉnh. Đài phun thấp một tia trong bộ ảnh là phương án chỉnh theo ý tưởng đã thảo luận; model đài phun nguồn còn có cột/tầng nước, cần chỉnh nếu chọn giữ đúng hình concept. Những ảnh này không xác minh collision, navmesh hay việc AI bị che sau bụi cây.

Nguồn và giấy phép từng model nằm trong [hướng dẫn asset sân vườn](../../assets/COURTYARD_GUIDE.md), [danh mục](../../assets/catalog.json) và `source.json` của các asset. [PROMPTS.md](PROMPTS.md) lưu đầy đủ các prompt và lượt sửa H1/H2. Các mẫu Gothic/Balustrade dùng CC BY 4.0; Terpsichore bản Glenn Gunhouse dùng CC BY-SA 4.0. Các bản ảnh trước giữ trong `asset-design-preview-v1/`.
