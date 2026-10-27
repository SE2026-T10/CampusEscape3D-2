# Mặt bằng museum concept v1

`floorplans.png` và `floorplans.svg` là bản thiết kế mặt bằng có cùng nội dung, kích thước 3200 × 1840 px. Đây là map hư cấu lấy cảm hứng từ bảo tàng Gardner, không phải mặt bằng khảo sát công trình thật.

## Hệ tọa độ và kích thước

- Gốc `(0, 0)` là góc tây bắc tòa nhà. `x` tăng về đông, `y` tăng về nam. Đơn vị mét; khi blockout Godot có thể ánh xạ thành `(X, Z)`.
- Tòa nhà: `x = 0…36`, `y = 0…30`.
- Sân trong / khoảng thông tầng: `x = 12…24`, `y = 9…21`, tức 12 × 12 m.
- Hành lang vòng rộng 3 m: đường bao ngoài `x = 9…27`, `y = 6…24`, trừ phần sân trong.
- Tầng 1 cao độ `+0,00 m`; tầng 2 `+4,50 m`. Khoảng sân ở tầng 2 là khoảng rỗng, có lan can, không có sàn.
- Sơ đồ cầu thang chỉ biểu diễn hướng và vị trí kết nối. Số nét bậc không phải số bậc thi công; cần dựng và thử chiều cao bậc, chiều rộng, khoảng nghỉ trong blockout.

## Phân khu

| Phạm vi (m) | Tầng 1 | Tầng 2 |
|---|---|---|
| x 0–27, y 0–6 | Trưng bày lịch sử | Phòng tranh C / T3 |
| x 27–36, y 0–6 | Thang B | Thang B |
| x 0–9, y 6–24 | Điêu khắc | Phòng tranh A / T1 |
| x 27–36, y 6–18 | Nhân viên / chìa K | Phòng tranh B / T2 |
| x 27–36, y 18–24 | Kho phụ | Kho phục chế (gộp với vùng phía nam) |
| x 27–36, y 24–30 | Phòng dịch vụ | Kho phục chế / R / E |
| x 0–9, y 24–30 | Thang A | Thang A |
| x 9–27, y 24–30 | Sảnh chính | Phòng đệm phía nam |

## Tâm các ô cửa

Chiều rộng cửa thông thường 1,6 m; cửa phòng bắc rộng 2 m; cửa sảnh–hành lang rộng 2,4 m. Đây là kích thước đặt trước khi tính độ dày tường.

| Tầng | Tâm (x, y) | Kết nối / điều kiện |
|---|---|---|
| Cả hai | (15, 6), (23, 6) | Hai cửa phòng bắc ↔ hành lang |
| Cả hai | (27, 3) | Phòng bắc ↔ thang B; khe cửa rộng 2 m |
| Cả hai | (9, 9), (9, 19) | Hai cửa phòng tây ↔ hành lang |
| Cả hai | (18, 24) | Sảnh/phòng đệm phía nam ↔ hành lang |
| Cả hai | (9, 27) | Sảnh/phòng đệm phía nam ↔ thang A |
| Tầng 1 | (27, 10), (27, 15) | Nhân viên ↔ hành lang |
| Tầng 1 | (27, 21) | Kho phụ ↔ hành lang |
| Tầng 1 | (27, 27) | Phòng dịch vụ ↔ sảnh |
| Tầng 1 | (18, 30) | Lối vào chính, rộng 2 m |
| Tầng 1 | (18, 21) | Vòm vào sân trong, rộng 2 m |
| Tầng 2 | (27, 10) | Phòng B ↔ hành lang; cần chìa K |
| Tầng 2 | (32, 18) | B → kho phục chế; ban đầu chốt, mở từ phía B |
| Tầng 2 | (27, 27) | Phòng đệm phía nam ↔ kho phục chế, luôn tiếp cận được |
| Tầng 2 | (36, 27) | Cửa sổ thoát ở mặt ngoài phía đông, rộng 1,6 m |

Thang A nối hai sảnh/phòng phía nam; thang B nối hai phòng bắc. Hai thang ở góc nhà không có cửa trực tiếp sang hành lang vì hình chữ nhật của thang chỉ tiếp xúc hành lang tại một góc.

## Mục tiêu và luồng chơi

- S: bắt đầu ở cửa chính tầng 1 `(18, 30)`.
- K: chìa trong phòng nhân viên tầng 1, gần `(31,5; 13)`.
- T1: tường tây phòng A tầng 2, gần `(1,5; 12)`.
- T2: tường đông phòng B tầng 2, gần `(35; 10)`.
- T3: tường bắc phòng C tầng 2, gần `(18; 1,1)`.
- R: dây trong kho phục chế tầng 2, gần `(32; 23)`.
- E: cửa sổ tầng 2 `(36; 27)`, dây xuống sân ngoài phía đông.
- L: vị trí đáp sơ đồ tầng 1 `(39; 27)`. Khi dựng 3D cần bố trí độ vươn cửa sổ, đoạn dây và vùng đáp ngoài nhà thực tế; ký hiệu L đặt cách tường để dễ đọc.

Tuyến xanh liền là một cách đi gợi ý, không bắt buộc thu thập theo thứ tự. Người chơi có thể quay lại trên tuyến cũ sau khi lấy K, dùng thang A hoặc B, và vào kho phục chế từ phía nam để chuẩn bị dây trước. Tuyến xanh đứt thể hiện lối phụ hoặc khả năng chuẩn bị đường thoát sớm. Tác phẩm T1/T3 không nằm sau cửa cần K; chỉ T2 cần K. Cửa B → kho không cho phép đi tắt từ kho vào B trước khi mở chốt từ bên trong.

## Tuần tra và vật che

- G1: điêu khắc ↔ hành lang tây/nam ↔ sảnh tầng 1. Có đoạn quay lại cùng tuyến tại sảnh.
- G2: phòng A ↔ hành lang tây/bắc ↔ phòng C tầng 2. Một số đoạn hành lang dùng cả hai chiều.
- G3: vòng quanh bệ trưng bày bên trong phòng B, có thể nhìn về phía cửa. Không đi qua cửa khóa hay đường tắt chưa mở.
- Các tuyến đỏ đều nằm trên sàn, qua đúng ô cửa và tránh bệ đặc.
- Các khối màu xám xanh là bệ đặc/vật che tầm nhìn. Khi phủ tủ kính lên bệ, phần kính phải xử lý tầm nhìn phù hợp; không dùng nguyên hộp kính như tường kín.
- Tuyến màu là sơ đồ đường đi. Chưa biểu diễn góc quay và thời gian dừng ở từng waypoint; cần tinh chỉnh khi thử gameplay.

## Tạo lại bản vẽ

Builder `build-floorplans.ps1` dùng `System.Drawing` trên Windows, không cần cài thêm thư viện. File nguồn UTF-8; chạy bằng cách đọc rõ UTF-8 để hỗ trợ PowerShell 5:

```powershell
& ([scriptblock]::Create((Get-Content -LiteralPath 'maps/museum/docs/concept-v1/build-floorplans.ps1' -Raw -Encoding UTF8)))
```

Ảnh đã kiểm tra trực quan: chữ tiếng Việt, chú giải, thang tỷ lệ, lối vào/thoát, khoảng thông tầng, các cửa khóa và tuyến tuần tra đều hiển thị. SVG đã được kiểm tra cú pháp XML. Đây là tài liệu thiết kế; chưa phải scene Godot chơi được.
