# Tree Small 02

Mở `tree_small_02_2k.gltf` trong Godot để xem nguồn cây gốc. Giữ `.bin` và `textures/` cùng thư mục.

**Model này cần giảm lưới trước khi dùng trong gameplay.** Gói glTF công khai chỉ chứa `tree_small_02_LOD0`, gồm 2.062.487 tam giác. Metadata nguồn ghi có LOD trong bộ gốc, nhưng gói glTF đang tải không kèm các mức thấp hơn. Texture 2K không làm giảm số tam giác.

Cây cao xấp xỉ 4,6 m, dùng tham khảo cho các góc sân. Khi tích hợp cần tạo phiên bản nhẹ, kiểm tra vật liệu lá và khoảng cách tới cột, lan can, mái kính. Chưa có collider hoặc logic che tầm nhìn.

Nguồn gốc và mã kiểm tra nằm trong `source.json`; giấy phép CC0 trong `LICENSE.txt`. Hình học tải xuống giữ nguyên, chưa đặt vào scene chơi.
