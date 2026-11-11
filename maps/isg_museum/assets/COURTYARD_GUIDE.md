# Asset sân vườn cột vòm

Đã tích hợp art v1 vào scene chơi ngày 11–12/11/2026. Builder, LOD, kiểm thử và ảnh Godot nằm trong [báo cáo triển khai](../docs/environment-art-v1/REPORT.md). Các ghi chú chuẩn bị dưới đây mô tả tình trạng nguồn trước khi tích hợp; GLB/glTF nguồn vẫn giữ nguyên.

Đợt chuẩn bị ngày 10/11/2026 cho phương án `docs/asset-design-preview-v1/06-courtyard-garden.png` và bốn tượng thay chậu cây. Ngày 11/11/2026 bổ sung ba GLB người dùng tải — cột–vòm, lan can và tượng Terpsichore. Thư mục này chuẩn bị model và dữ liệu nguồn; chưa đặt các model mới vào scene chơi.

## Model đã tải

| Asset | Tệp mở trong Godot | Cách dùng dự kiến |
|---|---|---|
| [Shrub 04](https://polyhaven.com/a/shrub_04) | [shrub_04_2k.gltf](models/vegetation/shrub_04/shrub_04_2k.gltf) | Ghép và chỉnh hình thành dải bụi trên chân tường. Đây là cành bụi tự nhiên, chưa phải hàng rào cắt phẳng. |
| [Fern 02](https://polyhaven.com/a/fern_02) | [fern_02_2k.gltf](models/vegetation/fern_02/fern_02_2k.gltf) | Dương xỉ trong các ô cây, quanh bệ tượng; tránh lấn đường vòng và bốn nhánh đi. |
| [Tree Small 02](https://polyhaven.com/a/tree_small_02) | [tree_small_02_2k.gltf](models/vegetation/tree_small_02/tree_small_02_2k.gltf) | Cây tán cao tại góc sân. Tệp glTF tải được chỉ chứa LOD0, hơn 2 triệu tam giác. Cần giảm lưới trước khi dùng nhiều cây trong game. |
| [Gothic Architectural Structures](https://sketchfab.com/3d-models/gothic-architectural-structures-affc5b590531447788aafc23a011154c) | [gothic_architectural_structures.glb](models/architecture/gothic_architectural_structures/gothic_architectural_structures.glb) | Bộ cột và vòm để ghép các nhịp quanh sân; cần căn tỷ lệ và chỉnh màu đá. |
| [Balustrade Balcony](https://sketchfab.com/3d-models/balustrade-balcony-83bf8e57aba441de9f2a9ef7442db59d) | [balustrade_balcony.glb](models/architecture/balustrade_balcony/balustrade_balcony.glb) | Lan can tầng 2, cần ghép theo từng cạnh khoảng thông tầng và giữ collision bảo vệ lối đi. |
| [Terpsichore Lyran by Canova](https://sketchfab.com/3d-models/terpsichore-lyran-by-canova-aef74272b36a48a5a4e35189b048034c) | [terpsichore_lyran_by_canova.glb](models/exhibits/terpsichore_lyran/terpsichore_lyran_by_canova.glb) | Tượng nữ cổ điển đặt trên bệ đặc riêng. Cần căn kích thước và giảm lưới nếu nhân bản nhiều tượng. |

Ba model cây dùng giấy phép CC0-1.0, có `.gltf`, `.bin` và texture 2K. File nguồn và phụ thuộc có mã kiểm tra để đối chiếu với Poly Haven. Texture 2K giảm dung lượng ảnh; không giảm số tam giác của model.

Ba GLB bổ sung giữ hình học và vật liệu của gói tải. Cột–vòm do Samuel F. Angrick-Johanns (Oneironauticus) tạo, lan can do Esther3D tạo, đều dùng CC BY 4.0. Tượng Terpsichore là bản Glenn Gunhouse chỉnh từ bản quét Cleveland Museum of Art, dùng CC BY-SA 4.0. Mỗi thư mục có `source.json` và `LICENSE.txt`; giữ đúng tác giả và giấy phép của từng phiên bản.

Mở tệp `.gltf` hoặc `.glb` từ FileSystem của Godot để xem. Giữ `.bin` và `textures/` cùng thư mục với `.gltf`. Hình học, đơn vị và vật liệu đang giữ theo nguồn; cần căn tỷ lệ, chỉnh màu và thiết lập collision khi triển khai vào map.

Godot 4.7.2 đã đọc thành công hình học của ba GLB bổ sung. Bộ Gothic gồm các module đang xếp lệch nhau, cần tách và căn lại gốc trước khi ghép nhịp. Khi tách lan can cần giữ đúng tỷ lệ các node con; Godot cũng báo normal map dùng UV khác ảnh màu, nên cần đối chiếu và chỉnh vật liệu khi tích hợp. Tượng Terpsichore dùng vật liệu unlit từ nguồn, cần đổi sang vật liệu nhận ánh sáng nếu muốn tượng hòa với đèn sân vườn. Các tệp GLB nguồn được giữ nguyên.

## Một model còn chờ tải qua trình duyệt

Goddess Isis đã có dữ liệu nguồn và giấy phép, chưa có tệp model. API metadata chính thức xác nhận model có thể tải, nhưng API tải trả HTTP 401 vì cần xác thực. Phiên đăng nhập Chrome không tự được dùng bởi chương trình tải API.

| Asset | Thư mục chuẩn bị | Giấy phép / tác giả |
|---|---|---|
| [Goddess Isis](https://sketchfab.com/3d-models/goddess-isis-1st-century-ce-fef83e3711e248689702f953e02809a0) | `models/exhibits/goddess_isis/` | CC0-1.0 — Minneapolis Institute of Art |

Để tải bổ sung, mở đúng link trong Chrome đang đăng nhập, chọn **Download 3D Model**, ưu tiên GLB hoặc glTF có texture và lưu nguyên gói vào `D:/IT/SE_GAME_3D/.local/downloads/museum_models/sketchfab/`. Giữ nguyên gói nguồn để kiểm tra khi đưa vào thư viện. Chỉ cập nhật trạng thái sang `downloaded` sau khi model đã được giải nén và kiểm tra.

## Các phần dựng theo kích thước map

Đài phun nước và vật liệu `Marble012`, `PavingStones001`, `Plaster002`, `Grass001`, `Metal032` đã có trong thư viện. Mái kính hai dốc theo ô sân 12 × 12 m, khung kim loại, vách thấp và bệ tượng sẽ dựng riêng ở bước triển khai.

Giữ vách tổng cao 1,2 m, bốn lối vào rộng 2 m và đường vòng quanh đài phun nước. Lá cây trang trí không tự chặn AI; vách và bệ cần có khối collision chặn tia nhìn phù hợp. Bệ tượng dự kiến cao 1,2 m, phần tượng đặt phía trên. Chưa có collision hoặc navigation mới trong đợt chuẩn bị asset này.
