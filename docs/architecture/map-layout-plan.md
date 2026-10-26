# Kế hoạch tổ chức repository theo từng map

Ngày lưu: **25/10/2026**.

Repository: [SE2026-T10/CampusEscape3D-2](https://github.com/SE2026-T10/CampusEscape3D-2).

Trạng thái khi lập: **kế hoạch để nhóm xem xét, chưa triển khai di chuyển hoặc chỉnh sửa mã nguồn**. Bản kế hoạch dựa trên cấu trúc đã kiểm tra tại commit `3e11644`. Việc triển khai sau đó được thực hiện trên branch `twp`; xem `MAP_LAYOUT.md` để biết cấu trúc hiện hành.

## 1. Mục tiêu và quyết định của nhóm

- Nhóm có 5 thành viên, mỗi thành viên phụ trách một map độc lập.
- Các map được chọn từ menu, không phải chuỗi vượt cấp hay hệ thống mở khóa màn.
- Bối cảnh có thể khác nhau: thư viện, ngân hàng, bảo tàng hoặc địa điểm khác.
- Các phần thống nhất dùng chung là AI NPC, điều khiển nhân vật, hệ thống tương tác và HUD.
- Mỗi map tự phụ trách bối cảnh, bố cục, tuần tra, nhiệm vụ, cơ chế riêng, điều kiện thắng/thua và bằng chứng kiểm thử.
- Những cơ chế bổ sung đã có như inventory, stamina, checkpoint, puzzle và camera được tổ chức để lựa chọn sử dụng. Không bắt mọi map phải dùng đầy đủ cơ chế của thư viện.

## 2. Cấu trúc dự kiến

```text
CampusEscape3D-2/
├── shared/                         # Phần dùng chung
│   ├── scenes/
│   │   ├── player/
│   │   ├── npc/
│   │   ├── props/
│   │   └── ui/
│   ├── scripts/
│   │   ├── player/                 # Điều khiển và tương tác
│   │   ├── npc/                    # AI, nhìn, nghe, patrol
│   │   ├── interaction/            # Quy ước đối tượng tương tác
│   │   ├── ui/                     # HUD, menu, settings
│   │   ├── game/                   # Chọn map, pause, restart
│   │   ├── noise/                  # Tiếng động cho NPC
│   │   └── utilities/
│   └── assets/                     # Tài nguyên chung
│
├── features/                       # Cơ chế tùy chọn có thể tái sử dụng
│   ├── inventory/
│   ├── stamina/
│   ├── objectives/
│   ├── checkpoints/
│   ├── puzzles/
│   └── security/
│
├── maps/
│   ├── tutorial/                   # Tutorial hiện có, giữ để tham khảo/test
│   ├── library/                    # Map thư viện hiện có
│   │   ├── scenes/
│   │   ├── scripts/
│   │   ├── assets/
│   │   ├── resources/              # Navmesh, dữ liệu cấu hình
│   │   ├── tests/
│   │   ├── tools/
│   │   └── docs/
│   ├── bank/                       # Cùng cấu trúc như library
│   ├── museum/
│   └── ...                         # Hai map còn lại khi nhóm chốt tên
│
├── templates/
│   └── map/                        # Khung thư mục, hướng dẫn tạo map
│
├── tests/                          # Test lõi chung và tích hợp nhiều map
├── tools/                          # Benchmark, kiểm tra và build chung
├── docs/                           # Kiến trúc, hướng dẫn làm việc nhóm
├── .github/workflows/
├── project.godot
├── export_presets.cfg
└── README.md
```

`bank` và `museum` là ví dụ bối cảnh đã được nhắc đến, chưa phải phân công chính thức cho thành viên. Không tạo sẵn hai tên map còn lại khi nhóm chưa quyết định.

Tutorial hiện có được giữ làm mẫu và phục vụ kiểm thử; việc tính nó vào sản phẩm cuối do nhóm quyết định. File `expanded_library_expansion.tscn` vẫn là phần ghép bên trong map thư viện, không được tính thành map độc lập.

## 3. Phân loại nội dung hiện có

| Nội dung hiện tại | Vị trí dự kiến |
|---|---|
| Scene player, guard; AI và điều khiển | `shared/` |
| Tương tác, HUD, menu, chọn map | `shared/` |
| Inventory, stamina, checkpoint, puzzle dùng lại được | `features/` |
| Scene thư viện mở rộng và expansion | `maps/library/scenes/` |
| Navmesh thư viện | `maps/library/resources/` |
| Logic riêng: đường thoát, dock, badge reader của thư viện | `maps/library/scripts/` |
| Công cụ `tools/expanded/` | `maps/library/tools/` |
| Test `expanded_*` | `maps/library/tests/` |
| Tài liệu thiết kế thư viện | `maps/library/docs/` |

Chỉ chuyển vào `features/` những cơ chế có thể dùng lại thực sự. Nội dung còn chứa giả định riêng về bản thảo, đường thoát hoặc vị trí trong thư viện thuộc map thư viện, trừ khi được tách cấu hình rõ ràng.

## 4. Các bước triển khai

### Bước 1 — Chốt ranh giới dùng chung và riêng

- Lập danh sách đường dẫn cũ → mới trước khi di chuyển.
- Xác định file dùng chung, file thuộc feature tùy chọn và file riêng của từng map.
- Ghi nhận trạng thái Git ban đầu để có thể đối chiếu và hoàn tác.
- Giữ tài liệu, log và số đo lịch sử đúng ngữ cảnh; không biến kết quả cũ thành bằng chứng kiểm tra mới.

### Bước 2 — Gom hai map hiện tại và cập nhật tham chiếu

- Di chuyển file cùng các file `.uid` liên quan.
- Cập nhật đường dẫn tài nguyên và cấu hình import khi cần.
- Sửa tham chiếu trong scene, `load/preload`, catalog, test, công cụ dựng map và export.
- Giữ bố cục, nhiệm vụ và hành vi hiện tại để xác định lỗi phát sinh do di chuyển.
- Cấu trúc node bên trong scene được giữ ổn định khi không cần thay đổi.

### Bước 3 — Tách phụ thuộc của HUD vào thư viện

HUD hiện biết trực tiếp về đường thoát và điện của Expanded Library. Cần có giao diện để từng map cung cấp dữ liệu cho HUD chung:

- Mục tiêu và tiến độ.
- Lời nhắc tương tác.
- Thông báo hoặc trạng thái riêng của map.
- Kết quả hoàn thành.

Thư viện tiếp tục cung cấp dữ liệu đường thoát/điện. Ngân hàng, bảo tàng hoặc map khác cung cấp nội dung riêng qua cùng quy ước. Các chi tiết như tên phòng, vật phẩm mục tiêu và điều kiện thoát không được viết cố định vào HUD chung.

### Bước 4 — Chuẩn bị khung làm việc và kiểm tra tích hợp

- Tạo khung thư mục cho bank, museum và hướng dẫn thêm map.
- Chỉ đăng ký map vào menu khi có scene chạy được; không hiển thị map rỗng như một sản phẩm đã hoàn thành.
- Cập nhật test runner để tìm cả test chung và test trong từng map.
- Loại test, công cụ và bằng chứng của từng map khỏi bản export.
- Cập nhật README và hướng dẫn làm việc theo cấu trúc mới.

## 5. Quy ước phối hợp

- Mỗi người chủ yếu sửa `maps/<map_cua_minh>/`.
- Thay đổi `shared/`, `features/`, menu hoặc cấu hình build cần trao đổi và review vì có thể ảnh hưởng các map khác.
- NPC dùng chung thuật toán; số lượng, vị trí và tuyến tuần tra thuộc cấu hình từng map.
- Map tự quản lý dữ liệu nhiệm vụ và cơ chế riêng, đồng thời kết nối đúng với HUD và tương tác chung.
- Mỗi map phải vào được, chơi được, kết thúc được và rời map không để lại trạng thái ảnh hưởng map khác.
- Thành viên phụ trách map chịu trách nhiệm cả thiết kế, triển khai, kiểm thử và bằng chứng trên GitHub.
- Ghi nhận đúng phần đã được thành viên làm trước; việc tổ chức lại thư mục không thay đổi tác giả của mã nguồn.

## 6. Tiêu chí hoàn thành đợt tổ chức lại

- [ ] Project import và toàn bộ script biên dịch được bằng Godot 4.7.2.
- [ ] Hai map hiện tại vẫn vào chơi, restart và quay về menu đúng.
- [ ] AI, tương tác, HUD và checkpoint vẫn hoạt động.
- [ ] Bộ test hiện có chạy qua; kết quả mới được lưu riêng với log lịch sử.
- [ ] Không còn tham chiếu tài nguyên đang dùng đến đường dẫn cũ đã bị di chuyển.
- [ ] Pipeline export dùng đúng đường dẫn mới và chứa đủ tài nguyên chạy game.
- [ ] Test/tool riêng của map không bị đóng vào bản phát hành.
- [ ] Có hướng dẫn thêm map và quy định phần dùng chung cần review.
- [ ] Thay đổi được trình bày rõ để nhóm xem xét trước khi commit hoặc đẩy lên GitHub.

## 7. Phạm vi của kế hoạch

Đợt này chỉ tổ chức cấu trúc, cập nhật tham chiếu và tách các phụ thuộc cần thiết để hỗ trợ nhiều map. Chưa bao gồm xây nội dung ngân hàng/bảo tàng, sửa lại thiết kế gameplay thư viện hoặc triển khai toàn bộ ý tưởng map mới.

Kế hoạch này được lưu trước theo yêu cầu của người dùng. Chỉ triển khai sắp xếp repo khi có chỉ dẫn tiếp theo.
