# Phương án 9 bảo an

Ảnh tham chiếu: `floorplans-exterior-start.png`.
Ảnh mới: `floorplans-patrol-9-guards.png`.
Đã triển khai vào museum.tscn: xem [Bước 9](../step-09-nine-guards.md).
Số G1–G9 dưới đây cũng là số hiệu node hiện tại trong Godot.

| Tầng | Bảo an | Khu vực phụ trách |
|---|---|---|
| 1 | G1 | Phòng điêu khắc, vòng quanh các bệ |
| 1 | G2 | Phòng trưng bày lịch sử |
| 1 | G3 | Phòng nhân viên |
| 1 | G4 | Hành lang vòng ngoài sân trong |
| 1 | G5 | Sảnh chính và phòng dịch vụ, qua cửa nối hai phòng |
| 2 | G6 | Phòng A, có điểm dừng kiểm tra T1 |
| 2 | G7 | Phòng C |
| 2 | G8 | Phòng B, không qua cửa khóa/chốt |
| 2 | G9 | Hành lang quanh khoảng thông tầng và phòng đệm phía nam |

Tuyến đi qua cửa hiện có, vòng quanh bệ, không cắt qua tường hay khoảng thông tầng.
Với khu chỉ có một cửa nối, đi vào rồi quay lại qua chính cửa đó.
G4 đi quanh sân ở hành lang, không đi ra sân trước. G9 không vào kho phục chế.

Vị trí dây R trong ảnh vẫn theo sơ đồ tham chiếu ở tầng 2. Phương án chuyển dây
xuống kho phụ tầng 1 và thêm mật mã là nội dung riêng chưa áp dụng vào bản này.

Cơ chế kiểm tra khung T1 đã chuyển từ Guard_G2 cũ sang Guard_G6.
Đã kiểm tra tuyến qua cửa, collision và navmesh bằng AI thực tế.
