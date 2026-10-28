# K17 — Kế hoạch sửa cụm nhập mã và bổ sung minimap

Ngày lập: 28/10/2026. Mốc kiểm tra: `db3818548f48e415d3c8cf5b9dcb9e7b64ef17ef`, nhánh `feature/twp`, map V5.

**Trạng thái: đã triển khai trên `feature/twp`.** Xem [kết quả nghiệm thu và ảnh](VALIDATION.md). Các phần dưới giữ kế hoạch ban đầu; số đo sau sửa nằm trong báo cáo nghiệm thu.

Yêu cầu: sửa hiện tượng mở cửa kho thì bảng nhập mã còn treo giữa khoảng trống; thêm minimap thể hiện đúng vị trí hiện tại của người chơi. Phần này tiếp nối V5, dùng cho cả bản có lính và bản không lính.

## 1. Kết quả kiểm tra

Đã đọc mã dựng map, logic khóa/cửa, HUD và công cụ kiểm tra gá đỡ. Đã chạy một bản sao headless của scene `intelligence_k17_test.tscn`, đo hình học sau khi các nút được tạo lúc chạy, rồi mở cửa bằng công cụ kiểm tra. Không thao tác vào cửa sổ game của người dùng. Số đo lưu trong [INSPECTION.json](INSPECTION.json).

| Hạng mục | Hiện trạng đã xác nhận | Hệ quả |
| --- | --- | --- |
| Cụm nhập mã | `Gameplay/VaultKeypad` và bảng trang trí `Gameplay/EquipmentPresentation` là hai cụm riêng; không nằm dưới bản lề cửa. | Nhìn chính diện lúc cửa đóng có cảm giác bảng gắn trên cửa, nhưng khi cửa mở cả bảng và phím giữ tọa độ cũ. |
| Mở cửa kho | Bản lề chuyển từ 0° đến 90°, nhưng `Panel.visible` thành `false`; `DoorHinge` nằm dưới Panel nên cũng bị ẩn. | Cánh cửa biến mất trong khi cụm nhập mã vẫn còn ở khoảng cửa. Đây là lỗi hiển thị cần kiểm tra cùng lỗi gá bảng. |
| Mặt phím | Cả bốn phím số và nút xác nhận có mặt sau cách mặt bảng **0,0485 m**, tức **4,85 cm**. | Ngoài lỗi khi cửa mở, ngay khi cửa đóng các phím cũng chưa nằm sát vỏ đỡ. |
| Vị trí gá | Tia tại X=5,35 chạm `VaultDoor/Panel`; tia tại X=6,7 chạm tường cố định `NavigationRegion3D/North1`, mặt trước Z≈−23,825. | Muốn gá cố định phải chuyển cả cụm sang cạnh cửa; chỉ lùi Z ở vị trí cũ vẫn dựa vào cánh cửa. |
| Kiểm tra gá đỡ cũ | `check_attachments.gd` dựng hình học kiến trúc/trang trí; không dựng Gameplay và các phím sinh trong `_ready()`. | Chưa bắt được lỗi gá của keypad trong game thực tế. |
| Minimap | Chưa có minimap cho K17. Player có tọa độ và hướng thực; map có tầng trệt và B1. | Có thể dùng một sơ đồ 2D cập nhật trực tiếp từ Player. |
| Chỗ trống trên HUD | Nhiệm vụ ở góc phải trên, trạng thái bên trái, hành trang phía dưới. Thông báo giữa màn rộng 900 đơn vị canvas. | Nếu thêm minimap ở bên phải mà không chỉnh bố cục, thông báo có thể chồng lên minimap, nhất là khi tăng cỡ HUD. |

Nguồn chính: [dựng keypad](../../tools/k17_v4_builder.gd), [logic keypad K17](../../scripts/vault_keypad.gd), [bảng trang trí](../../scripts/equipment_presentation.gd), [dựng cửa](../../tools/build_k17.gd), [CodeLock dùng chung](../../../../features/puzzles/code_lock.gd), [AccessDoor dùng chung](../../../../features/objectives/access_door.gd).

Giới hạn kiểm tra: đây là đo runtime và đối chiếu mã nguồn. Chưa có ảnh nghiệm thu mới, chưa chơi E2E cho thay đổi đề xuất. Các số đo cửa sổ headless trong JSON không thay thế kiểm tra giao diện có hình ảnh ở nhiều độ phân giải.

## 2. Phương án sửa keypad

### 2.1. Gắn cố định vào tường cạnh cửa

Chuyển **toàn bộ cụm bảng, phím, màn hình, đèn và biển tên** sang tường cố định bên phải cửa kho, phía người chơi tiếp cận. Cánh cửa mở độc lập; keypad vẫn có bề mặt đỡ thật ở cả trạng thái đóng và mở.

- Điểm khảo sát ban đầu: tâm ngang X≈6,7; cao độ thao tác quanh Y≈1,3. Tọa độ Z tính từ mặt tường và chiều dày vỏ, không chép tọa độ cũ rồi dịch bằng mắt.
- Chốt vị trí sau khi kiểm tra trực tiếp phần tường, khoảng đứng, lối đi và tia tương tác. Điểm đứng thử khoảng X≈6,8, Z≈−22,2 chỉ là ứng viên, chưa phải tọa độ nghiệm thu.
- Không để vỏ lấn vào khoảng mở cửa hoặc chắn đường đến cầu thang. Đứng và ngồi đều nhìn, chọn được từng phím trong tầm tương tác 2,2 m.
- Gộp gá đỡ và mặt điều khiển vào cùng hệ tọa độ local của `VaultKeypad`; xóa bảng/chân đế/biển tên cũ ở tọa độ thế giới để tránh hai bảng chồng nhau.

### 2.2. Tạo vỏ và bố trí các chi tiết

- Dùng một vỏ hộp có mặt lưng chạm tường, mặt trước, khung màn hình, vít/gá và điểm kết thúc dây dẫn hợp lý.
- Mặt sau phím phải ngồi trên mặt vỏ; sai số gá mục tiêu tối đa 1–2 mm. Khi nhấn, phím lún vào vỏ theo hành trình hiện có, rồi trở về vị trí nghỉ.
- Đưa các chữ số, nhãn xác nhận và đèn vào vùng đỡ tương ứng. Dùng khoảng lệch bề mặt nhỏ để tránh nhấp nháy, không tạo khoảng hở vài centimet.
- Tọa độ gá, kích thước vỏ và điểm đứng kiểm thử dùng chung một cấu hình map để builder, runtime và E2E không lệch nhau.
- Giữ các đường dẫn `Gameplay/VaultKeypad/Dial1`…`Dial4` và `Gameplay/VaultKeypad/Enter`, hoặc cập nhật mọi nơi sử dụng nếu buộc phải thay đổi. Ưu tiên giữ nguyên để giảm ảnh hưởng tới công cụ chơi thử.

### 2.3. Sửa hiển thị cửa kho và giữ logic hiện hành

- Tách phần hình ảnh cánh cửa khỏi Panel đang bị ẩn khi mở; để bản lề và mô hình cánh cửa còn hiển thị suốt chuyển động, mở xong và khi khôi phục checkpoint.
- Ưu tiên sửa cấu trúc/biểu diễn cửa riêng của K17. Nếu cần sửa `AccessDoor` dùng chung, phải kiểm tra lại các map đang dùng lớp này.
- Kiểm tra collider và khả năng đi qua theo cơ chế cửa hiện có; không để sửa hình ảnh khiến cửa mở mà vẫn chặn người chơi.
- Giữ luật nhập mã: bốn chữ số, tương tác E, xác nhận, điều kiện thẻ/checkpoint, sai ba lần khóa tạm 20 giây và trạng thái đã mở.
- Chạy kiểm tra gá trên scene runtime đã sinh đủ phím. Kiểm tra từng mặt phím và mặt lưng vỏ với hình học đỡ thật; loại chính chi tiết đang đo khỏi phép thử. Tường cố định mới là giá đỡ hợp lệ cho mặt lưng vỏ.

## 3. Thiết kế minimap

### 3.1. Hành vi người chơi nhìn thấy

- Sơ đồ 2D ở bên phải, bên dưới bảng nhiệm vụ; nền tối, tường rõ, mũi tên người chơi nổi bật và nhãn tầng `TRỆT`/`B1`.
- Phía trên bản đồ luôn là hướng −Z của map. Mũi tên xoay theo hướng nhìn ngang của người chơi; nhìn lên hoặc xuống không làm lệch hướng trên sơ đồ.
- Cập nhật vị trí từ transform thật của Player mỗi khung hình. Đi bộ, chạy, ngồi, quay đầu và hồi sinh đều được phản ánh ngay, không nội suy theo tiến độ nhiệm vụ hoặc điểm đường định sẵn.
- Tự chuyển sơ đồ tầng khi đi cầu thang; khu chuyển tầng có nhãn rõ để người chơi hiểu đang đi lên hay xuống.
- Hiện mặc định khi chơi; có thể bật/tắt bằng phím M qua action riêng của K17 sau khi kiểm tra trùng phím.
- Ẩn khi mở nhật ký, tạm dừng, bị bắt, thất bại, màn kết quả và đoạn kết phá hoại V5. Khi trở lại chơi, tôn trọng lựa chọn bật/tắt trước đó.
- Bản đầu chỉ hiển thị cấu trúc, vị trí và hướng người chơi; không bổ sung vị trí lính, mật mã, đường giải tự động hoặc mục tiêu bí mật.

### 3.2. Dữ liệu sơ đồ theo đúng kiến trúc

Lấy dữ liệu sàn/tường/cửa/cầu thang từ cùng nguồn dựng hình học K17, trước bước gộp mesh tĩnh. Gắn thông tin tầng và vai trò cho các hình học cần vẽ, rồi xuất một resource `.tres` để game đọc khi chạy.

- Tầng trệt: phạm vi hiện tại X=[−48;48], Z=[−53;55], tức 96×108 m. Tâm theo mặt phẳng XZ là (0;1), không mặc định (0;0).
- B1: kho, hành lang và hai lối cầu thang; dùng khung riêng vừa nội dung để vị trí dưới hầm không thành một chấm nhỏ trên nền trống. Khung dự kiến X=[−12;36], Z=[−52;−22], sẽ chốt từ dữ liệu dựng.
- Vẽ tường, lối cửa, sàn, vật cản lớn ảnh hưởng định hướng và ký hiệu cầu thang. Không lấy mái/trần, biển, đường ống hoặc collider tạm dùng để bake nav làm đường đi trên sơ đồ.
- Không lấy toàn bộ navmesh chiếu xuống làm mặt bằng: dữ liệu điều hướng có thể chứa mặt trên mái/trần và không biểu diễn đầy đủ tường/cửa.
- Dữ liệu do builder tạo; thay đổi kiến trúc rồi dựng lại map phải tạo lại sơ đồ tương ứng. Resource phải được đóng gói trong bản export.

### 3.3. Quy đổi vị trí thật

Đưa `player.global_position` về tọa độ local của map, sau đó chiếu X/Z lên khung vẽ. Với khung thế giới `[xmin, xmax] × [zmin, zmax]` và vùng vẽ W×H:

```text
local_position = map_root.to_local(player.global_position)
scale = min(W / (xmax - xmin), H / (zmax - zmin))
padding = (Vector2(W, H) - Vector2(xmax - xmin, zmax - zmin) * scale) / 2
pixel = padding + Vector2(local_position.x - xmin, local_position.z - zmin) * scale
```

Giữ tỷ lệ đồng nhất theo hai trục; phần thừa để trống cân hai bên. X tăng đi sang phải, Z tăng đi xuống. Điểm xuất phát (−36;51) phải nằm gần góc trái dưới sơ đồ tầng trệt.

Lấy hướng ngang từ trục nhìn của thân Player, chuyển về hệ trục map rồi tính góc mũi tên. Không cộng quãng đường từ vận tốc và không sửa transform Player để phục vụ minimap. Khi scene/Player được tạo lại, liên kết lại đối tượng trước khi cập nhật marker.

### 3.4. Chuyển tầng và hiệu năng

- Mặt sàn tầng trệt quanh Y=0, B1 quanh Y=−4; dùng vùng cầu thang và ngưỡng có độ trễ để tránh đổi tầng liên tục giữa dốc.
- Ngưỡng thử: đi xuống chuyển sang B1 khi Y<−2,4; đi lên về tầng trệt khi Y>−1,6. Kiểm tra cả hai cầu thang và hồi sinh trước khi chốt.
- Sơ đồ nền dùng Control vẽ 2D, chỉ dựng lại khi đổi tầng, kích thước hoặc dữ liệu. Marker là phần tử riêng, cập nhật vị trí/hướng mỗi khung hình.
- Không thêm lượt render 3D từ camera trên cao. Đo chi phí trên cùng góc nhìn/cùng cấu hình; mục tiêu chi phí khung hình tăng không quá 5%, đây là mục tiêu nghiệm thu chưa phải số đo đạt được.

## 4. Tích hợp HUD

Đặt minimap dưới `ObjectiveHud` riêng của K17 để đi theo việc ẩn HUD trong đoạn kết V5. Hạn chế chỉnh HUD dùng chung của các map khác.

- Vùng sơ đồ ban đầu khoảng 200×200 đơn vị canvas, cộng tiêu đề và lề; vị trí lấy từ đáy thực tế của bảng nhiệm vụ, không đặt một Y cố định.
- Khi nội dung nhiệm vụ dài hoặc tăng cỡ HUD, bố trí lại khoảng trống và kích thước sơ đồ. Không che thông báo, đồng hồ báo động, tâm ngắm, lời nhắc E, phụ đề hay hành trang.
- Thu hẹp/xuống dòng thông báo giữa màn trong HUD K17 nếu cần; thông báo rộng 900 hiện tại phải được đưa vào kiểm tra va chạm bố cục.
- Kiểm tra các độ phân giải 1280×720, 1024×768 và 1920×1080, với cỡ HUD 100% và 125%, cả lúc xuất hiện nhiệm vụ phụ V5 và cảnh báo 120 giây.
- Minimap không nhận chuột hoặc giữ focus; điều khiển nhân vật và nhập mã tiếp tục hoạt động bình thường.

## 5. Tệp dự kiến tác động

Đây là danh sách trách nhiệm dự kiến, chưa phải các tệp đã được tạo hoặc sửa:

| Tệp/nhóm tệp | Công việc |
| --- | --- |
| `scripts/vault_keypad.gd`, cấu hình trong `resources/layout/` | Quản lý gá, vỏ, bố trí phím và thông số dùng chung cho công cụ kiểm thử. |
| `scripts/equipment_presentation.gd` | Bỏ bảng, chân đế và biển keypad cũ ở tọa độ thế giới. |
| `tools/k17_v4_builder.gd`, `tools/build_k17.gd` | Gá keypad mới, sửa cấu trúc hình ảnh cửa và xuất dữ liệu sơ đồ. |
| `tools/k17_expansion_builder.gd` và helper hình học cần thiết | Cung cấp sàn/tường/cầu thang có phân tầng trước khi gộp mesh. |
| `resources/layout/minimap_layout.gd` và resource `.tres` sinh ra | Định nghĩa dữ liệu 2D, giới hạn từng tầng và vùng cầu thang. |
| `scripts/minimap.gd`, `scripts/objective_hud.gd` | Vẽ sơ đồ, marker thật, đổi tầng, bật/tắt và bố cục HUD K17. |
| `tools/check_attachments.gd` hoặc công cụ kiểm tra runtime bổ sung | Kiểm tra giá đỡ của keypad đã sinh đủ phím, cả khi cửa mở. |
| `tools/playthrough_k17.gd`, bài kiểm thử K17 | Cập nhật điểm đứng nhập mã; thêm kiểm tra phép chiếu, tầng, HUD và hồi quy V5. |

Nếu thêm collider tĩnh ảnh hưởng lối đi thì dựng lại navmesh. Nếu đổi hình học đang được bake ánh sáng thì bake lại dữ liệu liên quan; kiểm tra bóng cũ và đường dẫn mesh sau khi thay cấu trúc. Không dựng lại toàn bộ art khi không cần.

## 6. Thứ tự thực hiện và tiêu chí hoàn thành

### Bước 1 — Sửa keypad và cửa kho

1. Tạo cụm gá thống nhất, đặt lên tường đã đo; dọn bảng cũ.
2. Đưa mặt phím vào vỏ; chỉnh màn hình/đèn/biển theo cùng tọa độ local.
3. Sửa phần hình ảnh cửa bị ẩn; kiểm tra trạng thái đóng, đang mở và mở hoàn toàn.
4. Kiểm thử tương tác thật và bổ sung phép đo gá runtime trước khi triển khai minimap.

**Đạt khi:** cả bốn phím và nút xác nhận có đỡ thật lúc nghỉ/nhấn, vỏ sát tường, cửa mở không còn cụm nhập mã treo ở lối đi; đứng/ngồi đều nhập được và đi qua cửa được.

### Bước 2 — Sinh sơ đồ và marker vị trí thật

1. Xuất dữ liệu tầng trệt/B1 từ hình học dựng map.
2. Thực hiện phép chiếu, tỷ lệ, hướng mũi tên và liên kết Player.
3. Kiểm tra các điểm chuẩn: xuất phát, khu thông tin, keypad, hai cầu thang, kho B1, hành lang B1 và hai lối thoát.

**Đạt khi:** phép chiếu các điểm chuẩn sai không quá 1 pixel theo công thức; marker runtime bám đúng tọa độ Player trong cùng khung cập nhật, quay đúng hướng và không bị lệch khi thay tỷ lệ/khung vẽ. Kiểm thử thêm map root có dịch chuyển/xoay để bắt lỗi trộn tọa độ local/global.

### Bước 3 — Chuyển tầng và bố cục HUD

1. Hoàn thiện vùng cầu thang, đổi tầng có độ trễ và xử lý hồi sinh/restart.
2. Thêm bật/tắt và các trạng thái ẩn/hiện cùng HUD V5.
3. Kiểm tra bằng ảnh và vùng chữ thực ở các cấu hình màn hình/cỡ HUD đã nêu.

**Đạt khi:** không nhấp nháy tầng giữa dốc; không hiện sơ đồ tầng trệt khi người chơi đã ở kho B1; minimap không che thông báo hoặc lời nhắc tương tác.

### Bước 4 — Nghiệm thu chung

- Chụp keypad chính diện và nhìn nghiêng khi cửa đóng, đang mở, mở xong; kiểm tra cả thao tác nhấn và checkpoint restore.
- Nhập đúng/sai, hết ba lượt, hết khóa tạm, thiếu thẻ/checkpoint và đã giải; xác minh giao diện và cửa cùng đúng trạng thái.
- Đi bộ, chạy, ngồi, quay 360°, đi cả hai cầu thang, hồi sinh và chơi lại; đối chiếu minimap với transform thực ở các điểm chuẩn.
- Kiểm tra nhật ký J, phím M, tạm dừng, bị bắt/thất bại, thắng thường và đoạn kết phá hoại V5.
- Chạy cả scene có lính và không lính; xác minh cùng dùng một phiên bản keypad/minimap.
- Chạy lại tuyến V5 lấy hồ sơ rồi thoát, và tuyến nhận mục tiêu phá hoại rồi thoát; giữ đồng hồ 120 giây và lịch tiếp viện hiện hành.
- Đo hiệu năng, kiểm tra lỗi Godot và chạy bản đóng gói để xác nhận resource minimap không bị thiếu.

Ảnh, số đo, lệnh kiểm tra và giới hạn còn lại được lưu vào báo cáo nghiệm thu sau triển khai. Kế hoạch này không coi phép đo headless hiện tại là bằng chứng đã hoàn thành các bước trên.
