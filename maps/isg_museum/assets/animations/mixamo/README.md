# Hoạt ảnh Mixamo

Đã nhận **9 clip hoạt ảnh và 1 nhân vật tham chiếu** do bạn tải từ Mixamo ngày 10/11/2026. Các tệp FBX gốc được sắp xếp theo hai thư mục sau.

```text
mixamo/
├── reference/
│   └── reference_tpose.fbx
├── clips/
│   ├── guard_idle.fbx
│   ├── guard_walk.fbx
│   ├── guard_run.fbx
│   ├── guard_look_around.fbx
│   ├── guard_sitting_idle.fbx
│   ├── guard_sit_down.fbx
│   ├── guard_stand_up.fbx
│   ├── npc_talking.fbx
│   └── receptionist_talking.fbx
├── source.json
└── LICENSE.txt
```

Godot 4.7.2 đã đọc thành công cả 10 tệp. Chúng dùng FBX Binary 7.7, xuất ở 30 FPS. Tên và quan hệ cha–con của 65 xương trong các clip khớp với nhân vật tham chiếu.

| Tệp | Vai trò dự kiến | Thời lượng |
|---|---|---|
| [reference_tpose.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/reference/reference_tpose.fbx) | Nhân vật X Bot tham chiếu, hai mesh và bộ xương | T-pose 0,033 giây |
| [guard_idle.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_idle.fbx) | Bảo vệ đứng chờ | 8,333 giây |
| [guard_walk.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_walk.fbx) | Bảo vệ đi tuần | 1,033 giây |
| [guard_run.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_run.fbx) | Bảo vệ chạy đuổi | 0,633 giây |
| [guard_look_around.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_look_around.fbx) | Quan sát và tìm kiếm | 6,333 giây |
| [guard_sitting_idle.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_sitting_idle.fbx) | G3 ngồi thức | 6,400 giây |
| [guard_sit_down.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_sit_down.fbx) | G3 ngồi xuống ghế | 2,233 giây |
| [guard_stand_up.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/guard_stand_up.fbx) | G3 đứng dậy | 2,267 giây |
| [npc_talking.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/npc_talking.fbx) | Đồng đội nói chuyện | 3,933 giây |
| [receptionist_talking.fbx](D:/IT/SE_GAME_3D/maps/isg_museum/assets/animations/mixamo/clips/receptionist_talking.fbx) | Nhân viên tiếp đón nói chuyện | 44,067 giây |

Chín clip chỉ chứa bộ xương và chuyển động. Nhân vật tham chiếu có take `mixamo_com` giữ T-pose trong khoảng 0,033 giây. Tệp tham chiếu còn có `Take 001` dài 3,333 giây với 0 track, vì vậy cần chọn đúng take khi dùng làm tư thế chuẩn.

Hai clip di chuyển còn chứa dịch chuyển ngang của xương Hips. `guard_walk.fbx` đi khoảng **1,845 m** mỗi clip, `guard_run.fbx` đi khoảng **3,749 m**. Khi ghép với điều khiển tuần tra của map, cần tạo bản hoạt ảnh **In Place** hoặc xử lý dịch chuyển gốc để vị trí nhân vật do bộ điều khiển quản lý. Các bản gốc trong thư mục này được giữ để đối chiếu.

Model [bảo vệ Sketchfab](D:/IT/SE_GAME_3D/maps/isg_museum/assets/models/characters/low_poly_security_guard/README.md) đã tải về và cần gắn xương trước khi ghép hoạt ảnh. Khi triển khai G3, cần căn động tác ngồi và đứng với vị trí ghế. Ngủ gật và trao giấy/vé cần chuẩn bị thêm từ `Sitting Idle` hoặc `Talking` khi phát triển phần tương ứng.

Thông tin nguồn, mã kiểm tra tệp và kết quả đọc hoạt ảnh được ghi trong `source.json`. Các tệp dùng điều kiện sử dụng Adobe Mixamo. Adobe cho phép dùng nhân vật và hoạt ảnh trong game theo điều kiện của họ. [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) · [Mixamo](https://www.mixamo.com/)
