# Nguồn tài nguyên mỹ thuật K17

Chi phí mua asset: **0 đồng**. Không sử dụng gói thương mại, model Mixamo hoặc model nhân vật tải từ Quaternius trong bản này.

## Tài nguyên bên ngoài: Poly Haven, CC0

Giấy phép của thư viện: <https://polyhaven.com/license>. Bản văn CC0 nằm tại `CC0-1.0.txt`.

| Nguồn | Tệp sử dụng trong project | Chỉnh sửa |
|---|---|---|
| [Modular Chainlink Fence](https://polyhaven.com/a/modular_chainlink_fence) | `models/fence_panel.glb` | Chọn panel đôi, chuẩn hóa gốc/tỷ lệ, xuất GLB với texture 1K |
| [Industrial Caged Sconce](https://polyhaven.com/a/industrial_caged_sconce) | `models/caged_lamp.glb` | Chọn biến thể A, chuẩn hóa gốc, giảm lưới và xuất GLB 1K |
| [Modular Industrial Pipes 01](https://polyhaven.com/a/modular_industrial_pipes_01) | `models/pipe_straight.glb`, `models/pipe_valve.glb` | Chọn hai module, chuẩn hóa gốc và xuất GLB 1K |
| [Concrete Wall 001](https://polyhaven.com/a/concrete_wall_001) | `textures/concrete_wall_001/` | Diffuse, normal OpenGL và roughness 1K |
| [Concrete Floor 02](https://polyhaven.com/a/concrete_floor_02) | `textures/concrete_floor_02/` | Ảnh 1K; vật liệu trong game dùng roughness cố định để giảm bóng ướt |
| [Asphalt 02](https://polyhaven.com/a/asphalt_02) | `textures/asphalt_02/` | Ảnh 1K, UV theo tỷ lệ thế giới |
| [Corrugated Iron](https://polyhaven.com/a/corrugated_iron) | `textures/corrugated_iron/` | Ảnh 1K cho mái che cổng |
| [Rusty Metal 04](https://polyhaven.com/a/rusty_metal_04) | `textures/rusty_metal_04/` | Ảnh 1K dùng có chọn lọc ở lưới thoát nước |

Tác giả từng tài nguyên được ghi trên trang nguồn. Manifest `SOURCE_MANIFEST.json` lưu URL và MD5 bản tải gốc cùng SHA-256 của các tệp đã đưa vào project. Ảnh preview của nhà cung cấp không được dùng làm ảnh chứng minh gameplay.

## Nội dung tự dựng cho project

Các model còn lại do công cụ `tools/build_art_models.py` dựng bằng Blender: bàn trực, tủ quân dụng, tủ hồ sơ, bàn lưu trữ, bàn radio, thùng tiếp tế, bao cát, thùng nhiên liệu, cửa gia cường, đèn pha, bảng sơ đồ và các phần hình ảnh lính.

Lính K17 dùng model phân khớp tự dựng, gắn vào các khớp animation của Guard dùng chung. Đây là nhân vật phong cách đơn giản có quân phục/mũ/trang bị, không phải model người quét ảnh hoặc nhân vật AAA có skeleton/retarget mới. AI và bộ điều khiển vẫn là phần dùng chung.

Kiến trúc, biển cố định, khung cửa, mái, vạch sơn và bố trí ánh sáng được dựng trong `tools/k17_art_builder.gd`. Lightmap được bake bằng Godot; các ảnh báo cáo được chụp từ scene thực tế.

## Âm thanh và lớp an ninh tự tạo

`audio/relay.wav`, `audio/radio.wav`, `audio/gate_motor.wav` được tổng hợp bằng `tools/build_security_audio.py`: sóng sin, noise có seed cố định và envelope, mono PCM 16-bit 22050 Hz. Không chứa sample tải ngoài hoặc giọng nói của người thật. Có thể tái tạo bằng Python chuẩn, không cần thư viện bổ sung.

Khung cảm biến, bảng điều khiển, loa PA, chỉ báo và các cổng động được lắp bởi `tools/k17_security_builder.gd`, tái sử dụng model cửa tự dựng. Không thêm nguồn asset thương mại trong đợt cơ chế an ninh.
