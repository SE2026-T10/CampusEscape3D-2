# Vật liệu bảo tàng

Thư mục này chứa 8 bộ ảnh bề mặt ambientCG và các vật liệu đã thiết lập sẵn cho map. Mở `res://maps/isg_museum/scenes/museum.tscn` trong Godot rồi nhấn **F6** để xem trong game.

```text
materials/
├── textures/
│   ├── wood_floor_051/
│   ├── plaster_002/
│   ├── marble_012/
│   ├── wood_051/
│   ├── paving_stones_001/
│   ├── grass_001/
│   ├── metal_032/
│   └── concrete_025/
└── presets/
    ├── wood_floor.tres
    ├── plaster_cream.tres
    ├── plaster_sage.tres
    ├── plaster_burgundy.tres
    ├── marble.tres
    ├── dark_wood.tres
    ├── paving_stones.tres
    ├── grass.tres
    ├── steel.tres
    ├── painted_steel.tres
    └── concrete.tres
```

Trong mỗi thư mục `textures`, ảnh JPG giữ tên gốc của ambientCG. `Color` là màu bề mặt, `NormalGL` tạo cảm giác gồ ghề khi có ánh sáng, `Roughness` điều khiển độ nhám. Một số bộ có thêm `AmbientOcclusion` để làm rõ khe nhỏ và `Metalness` để xác định phần kim loại.

| Bộ ảnh gốc | Preset dùng trong map | Nguồn tải |
|---|---|---|
| WoodFloor051 | `wood_floor.tres` cho sàn gỗ | [Wood Floor 051](https://ambientcg.com/view?id=WoodFloor051) |
| Plaster002 | `plaster_cream.tres`, `plaster_sage.tres`, `plaster_burgundy.tres` cho tường | [Plaster 002](https://ambientcg.com/view?id=Plaster002) |
| Marble012 | `marble.tres` cho sảnh và bệ trưng bày | [Marble 012](https://ambientcg.com/view?id=Marble012) |
| Wood051 | `dark_wood.tres` cho cửa, bàn và quầy | [Wood 051](https://ambientcg.com/view?id=Wood051) |
| PavingStones001 | `paving_stones.tres` cho đường đi ngoài trời | [Paving Stones 001](https://ambientcg.com/view?id=PavingStones001) |
| Grass001 | `grass.tres` cho thảm cỏ | [Grass 001](https://ambientcg.com/view?id=Grass001) |
| Metal032 | `steel.tres`, `painted_steel.tres` cho kệ và tủ kim loại | [Metal 032](https://ambientcg.com/view?id=Metal032) |
| Concrete025 | `concrete.tres` cho sàn kho | [Concrete 025](https://ambientcg.com/view?id=Concrete025) |

Các ảnh được phát hành theo CC0, cho phép dùng, chỉnh sửa và phân phối cùng game. [Giấy phép ambientCG](https://docs.ambientcg.com/license/)

Để dùng vật liệu cho một đồ vật mới, chọn node **MeshInstance3D**, tìm **Geometry → Material Override** trong Inspector rồi kéo tệp `.tres` tương ứng từ `presets` vào ô đó. Với đồ vật có node con `Mesh` hoặc `Visual`, chọn node con chứa hình trước khi kéo vật liệu.

Các preset dùng triplanar theo tọa độ thế giới để vân giữ kích thước đồng đều trên những khối lớn nhỏ khác nhau. Trong preset, **UV1 → Scale** điều khiển mật độ vân. Tăng Scale làm vân nhỏ và lặp nhiều hơn, giảm Scale làm vân lớn hơn. Giá trị khởi đầu được tính theo số mét cho mỗi lần lặp ảnh.

| Preset | Kích thước một lần lặp ảnh |
|---|---|
| `wood_floor.tres` | 4 m |
| `steel.tres`, `painted_steel.tres` | 1 m |
| Các preset còn lại | 2 m |

Muốn đổi màu tường hoặc màu sơn tủ, mở preset và chỉnh **Albedo → Color**. Ba preset plaster dùng chung bộ ảnh gốc với màu kem, xanh rêu và đỏ trầm khác nhau. Chọn **Make Unique** trước khi chỉnh nếu chỉ muốn đổi một đồ vật đang dùng chung preset.

Các công cụ dựng map tự áp lại quy tắc gán vật liệu khi tạo lại scene. Nếu cần áp lại thủ công sau khi chỉnh scene, chạy từ thư mục gốc project trong PowerShell.

```powershell
& '.\.local\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://maps/isg_museum/tools/apply_materials.gd
```

Lệnh này gán lại vật liệu của các mesh đã có trong quy tắc map, bao gồm những ô Material Override bạn đã đổi thủ công trên các mesh đó.

Đợt art v1.1 bổ sung `courtyard_stone_cream.tres` và `courtyard_statue_stone.tres`.
Hai preset nhận ánh sáng, dùng chung albedo Marble012 đã giảm tương phản và pha kem,
giữ normal/roughness nguồn với normal strength 0,12 và 0,07. Albedo dẫn xuất được
tạo offline bằng `tools/prepare_courtyard_materials.gd`; không sửa texture gốc.
Module cột được sinh lại bằng `prepare_environment_modules.gd`, sau đó art pass
gán đúng preset cho kiến trúc sân và tượng. Metadata của art giữ chúng qua palette.
Xem [bằng chứng v1.1](../../docs/environment-art-v1_1/REPORT.md).
