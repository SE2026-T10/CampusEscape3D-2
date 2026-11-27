# Fountain

Đã nhận tệp **fountain.glb** do bạn tải từ Sketchfab ngày 10/11/2026. Godot 4.7.2 đọc được model và vật liệu của tệp này.

Mở [fountain.glb](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/architecture/italian_fountain/fountain.glb) để xem model. Tệp chứa 24 mesh, năm vật liệu và năm ảnh texture được nhúng.

Tác giả là **yorre.detavernier**. Giữ `LICENSE.txt` và `source.json` để ghi công khi dùng model theo CC BY 4.0. [Trang model gốc](https://sketchfab.com/3d-models/fountain-8580500134194ba5be3f6df7593049f2) · [Giấy phép](https://creativecommons.org/licenses/by/4.0/)

Model có 2.984 tam giác. Tệp dùng vật liệu `KHR_materials_pbrSpecularGlossiness`, nên Godot chuyển sang cách tính roughness/metallic khi đọc và báo màu hoặc độ bóng có thể khác nguồn. Tệp GLB gốc được giữ nguyên để đối chiếu khi chỉnh vật liệu sau này.

Khi đưa vào sân trong, cần căn kích thước đài theo lối đi vòng hiện có, tạo collision cho bể và chỉnh riêng phần nước cùng ánh sáng.
