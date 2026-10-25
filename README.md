# Campus Escape 3D

[![Kiểm thử và đóng gói](https://github.com/SE2026-T10/CampusEscape3D-2/actions/workflows/build.yml/badge.svg?branch=Development)](https://github.com/SE2026-T10/CampusEscape3D-2/actions/workflows/build.yml)

## Giới thiệu dự án

Dự án được tổ chức theo các bản đồ độc lập. Mã dùng chung cho nhân vật, NPC và giao diện nằm trong `shared/`; các cơ chế tùy chọn nằm trong `features/`. Mỗi bản đồ quản lý cảnh, mã xử lý, tài nguyên, kiểm thử và công cụ của mình trong `maps/<map_id>/`. Xem [Hướng dẫn làm việc theo bản đồ](docs/architecture/MAP_LAYOUT.md) để biết cấu trúc, giao diện mở rộng HUD và lệnh kiểm tra. Các thư mục ngân hàng, bảo tàng và tình báo hiện là khung làm việc; menu vẫn chỉ có hai bản đồ chơi được.

Campus Escape 3D là trò chơi hành động lén lút 3D góc nhìn thứ nhất, sử dụng phong cách đồ họa ít đa giác. Hai bản đồ hiện có lấy bối cảnh thư viện đại học vào ban đêm. Người chơi thâm nhập, lấy vật phẩm mục tiêu rồi trốn thoát, tránh các bảo vệ có khả năng tuần tra, nhìn, nghe, điều tra và truy đuổi.

Người chơi chọn một trong hai bản đồ từ menu chính:

- **Library Tutorial** — thư viện hướng dẫn, thuộc phiên bản sản phẩm tối thiểu (MVP): một tầng, ba bảo vệ; lấy thẻ ra vào trong khu Restricted Stacks rồi trốn thoát.
- **Expanded Library** — thư viện mở rộng: hai tầng và một tầng hầm, bảy bảo vệ, tám nhiệm vụ bắt buộc, ba nhiệm vụ tùy chọn và ba đường thoát. Mục tiêu về thời gian hoàn thành vẫn cần được xác nhận bằng người chơi thử.

Trò chơi được phát triển bằng Godot và GDScript, dành cho máy tính Windows. Phiên bản hiện tại là **1.1.0**, khai báo tại `application/config/version` trong `project.godot`. Tên bản đồ, nhãn giao diện và định danh kỹ thuật được giữ nguyên để đối chiếu với trò chơi và mã nguồn.

## Cấu trúc thư mục và cách tổ chức tệp

Dự án được tổ chức để 5 thành viên có thể phát triển 5 bản đồ (map) độc lập trong cùng một trò chơi. Người chơi chọn bản đồ từ menu; mỗi bản đồ có thể mang bối cảnh khác nhau như thư viện, ngân hàng, bảo tàng hoặc cơ sở tình báo. Trí tuệ nhân tạo (AI) của NPC, điều khiển nhân vật, tương tác và giao diện trong lúc chơi (HUD) dùng chung; bố cục, nhiệm vụ và cơ chế đặc trưng nằm trong thư mục của từng bản đồ.

### Cây thư mục chính

```text
CampusEscape3D-2/
├── shared/                         # Thành phần dùng chung giữa các bản đồ
│   ├── scenes/                     # Cảnh nhân vật, NPC, đồ vật và giao diện
│   ├── scripts/                    # Điều khiển, AI, tương tác, HUD, luồng trò chơi
│   └── assets/                     # Âm thanh, mô hình, ảnh bề mặt, vật liệu chung
├── features/                       # Các cơ chế có thể lựa chọn sử dụng
│   ├── inventory/                  # Vật phẩm, nhặt và sử dụng đồ
│   ├── stamina/                    # Thể lực khi chạy
│   ├── objectives/                 # Nhiệm vụ, điều kiện mở cửa và thoát
│   ├── checkpoints/                # Điểm hồi sinh và khôi phục trạng thái
│   ├── puzzles/                    # Mật mã, nguồn điện và cơ chế giải đố
│   └── security/                   # Camera và các thiết bị an ninh
├── maps/                           # Nội dung riêng của từng bản đồ
│   ├── tutorial/                   # Bản đồ hướng dẫn, dùng để tham khảo và kiểm thử
│   ├── library/                    # Bản đồ thư viện mở rộng hiện có
│   ├── bank/                       # Khung ví dụ cho bản đồ ngân hàng
│   ├── museum/                     # Khung ví dụ cho bản đồ bảo tàng
│   └── intelligence/               # Khung cho bản đồ cơ sở tình báo
├── templates/map/                  # Khung thư mục để bắt đầu bản đồ mới
├── tests/                          # Kiểm thử chung và bộ chạy kiểm thử các bản đồ
├── tools/                          # Công cụ CI, đo hiệu năng, kiểm tra chuyển bản đồ
├── docs/                           # Kiến trúc, hướng dẫn đóng gói, báo cáo chung
├── .github/workflows/              # Quy trình kiểm thử và đóng gói tự động
├── project.godot                   # Cấu hình dự án Godot
└── export_presets.cfg              # Cấu hình xuất bản trò chơi
```

Hiện chỉ có **Library Tutorial** và **Expanded Library** là hai bản đồ chơi được trong menu. `bank/` và `museum/` là khung ví dụ, chưa phải phân công chính thức; `intelligence/` mới chuẩn bị cấu trúc và ý tưởng. Các bản đồ còn lại được thêm khi nhóm chốt bối cảnh. Bản đồ hướng dẫn được giữ làm mẫu và kiểm thử, không mặc định tính là một trong năm bản đồ của nhóm.

### Phân chia nội dung dùng chung và nội dung riêng

| Vị trí | Nội dung đặt tại đây | Ví dụ |
|---|---|---|
| `shared/` | Thành phần được nhiều bản đồ sử dụng | Nhân vật, AI bảo vệ, tương tác bằng phím E, HUD, menu, âm thanh chung |
| `features/` | Cơ chế tái sử dụng mà bản đồ lựa chọn và cấu hình | Túi đồ, thể lực, nhiệm vụ, điểm hồi sinh, giải đố, camera |
| `maps/<map_id>/` | Tài nguyên và mã xử lý đặc trưng của một bản đồ | Bố cục phòng, tuyến tuần tra, lưới điều hướng, nhiệm vụ, vật phẩm và cơ chế riêng |
| `tests/`, `tools/`, `docs/` ở gốc | Kiểm thử, công cụ và tài liệu áp dụng cho toàn dự án | Bộ chạy kiểm thử, kiểm tra chuyển bản đồ, CI, hướng dẫn đóng gói |

Ví dụ: mã xử lý đường thoát, đầu đọc thẻ và bến hàng của thư viện nằm trong `maps/library/scripts/`; dữ liệu tuần tra được bố trí trong cảnh (scene) của bản đồ, còn AI xử lý tuần tra nằm trong `shared/scripts/npc/`. Bản đồ mới sử dụng cảnh nhân vật/NPC chung thay vì sao chép thành một bộ điều khiển và AI khác.

`features/` hiện là các cơ chế bật/tắt hoặc cấu hình theo bản đồ, chưa phải các phần mở rộng có thể xóa tùy ý khỏi dự án. Các dữ liệu nhiệm vụ, vật phẩm và thông báo mặc định cần được cấu hình phù hợp với bản đồ mới.

### Cấu trúc bên trong một bản đồ

Mỗi bản đồ có cùng khung thư mục `maps/<map_id>/`:

| Thư mục | Tệp và nội dung |
|---|---|
| `scenes/` | Cảnh chính của bản đồ và các cảnh con riêng (`.tscn`) |
| `scripts/` | Mã xử lý nhiệm vụ, cơ chế và điều phối riêng (`.gd` cùng `.gd.uid`) |
| `assets/` | Mô hình, ảnh, vật liệu, âm thanh chỉ dùng trong bản đồ |
| `resources/` | Lưới điều hướng và dữ liệu cấu hình của bản đồ (`.tres`...) |
| `tests/` | Kiểm thử hành vi và điều kiện hoàn thành của bản đồ |
| `tools/` | Công cụ dựng bản đồ, tạo lưới điều hướng, chụp ảnh hoặc đo đạc riêng |
| `docs/` | Cốt truyện, thiết kế, ảnh và kết quả kiểm thử; có `.gdignore` để Godot bỏ qua |

Mỗi bản đồ có một cảnh chính làm điểm vào. `expanded_library_expansion.tscn` là cảnh con của bản đồ thư viện, không phải một bản đồ độc lập. Khi rời bản đồ, các nút (node) hệ thống thuộc cảnh đó được giải phóng để lần chọn bản đồ tiếp theo bắt đầu riêng biệt.

### Bắt đầu làm một bản đồ mới

1. Sao chép nội dung `templates/map/` sang `maps/<map_id>/`, bổ sung README mô tả bối cảnh, nhiệm vụ và phạm vi. Không sao chép `templates/.gdignore` vào gốc bản đồ mới; giữ `.gdignore` trong `docs/`.
2. Tạo cảnh chính trong `scenes/`, bố trí môi trường, va chạm, lưới điều hướng và tuyến tuần tra. Sử dụng `shared/scenes/player/player.tscn` và `shared/scenes/npc/guard.tscn` cho nhân vật và NPC.
3. Thêm các hệ thống cần dùng từ `features/`, cấu hình mục tiêu và điều kiện thắng/thua của bản đồ. Mã xử lý đặc trưng đặt trong `scripts/`. Nếu cần trạng thái HUD riêng, triển khai `MapHudProvider` để cung cấp dữ liệu cho HUD chung.
4. Khi cảnh chơi được, đăng ký `{id, title, scene, description}` trong [`shared/scripts/game/level_catalog.gd`](shared/scripts/game/level_catalog.gd) để menu hiển thị bản đồ.
5. Viết kiểm thử trong `maps/<map_id>/tests/` và đăng ký bộ kiểm thử vào [`tests/test_scene.gd`](tests/test_scene.gd). Chỉ đặt tệp trong thư mục chưa làm kiểm thử hành vi tự chạy. Kiểm tra thêm việc chơi lại, thoát về menu và chuyển sang bản đồ khác.

Chi tiết về cấu hình nhiệm vụ, giao diện HUD và lệnh kiểm tra: [Hướng dẫn làm việc theo bản đồ](docs/architecture/MAP_LAYOUT.md). Kết quả kiểm tra lần tổ chức lại: [VALIDATION.md](docs/architecture/VALIDATION.md).

## Phiên bản Godot

- **Bộ máy phát triển:** Godot **4.7.2 Stable**, bản chính thức (`4.7.2.stable.official.ed1daf0bf`). Các phiên bản khác chưa được hỗ trợ. Bộ kiểm thử và quy trình đóng gói đều kiểm tra đúng phiên bản này.
- **Ngôn ngữ lập trình:** GDScript.
- **Bộ kết xuất:** Compatibility (OpenGL).
- **Nền tảng đích:** máy tính Windows (x86_64).

## Cài đặt

**Để chơi:** tải `CampusEscape3D-<version>-windows-x64.zip` từ mục GitHub Releases hoặc tệp kết quả của một lần chạy GitHub Actions, xem phần Đóng gói tự động. Giải nén và chạy `CampusEscape3D.exe`; giữ `CampusEscape3D.pck` cùng thư mục. Không cần cài thêm thành phần khác. Tệp thực thi chưa được ký số nên Windows SmartScreen có thể yêu cầu xác nhận trong lần chạy đầu.

**Để phát triển:**

1. Cài [Godot 4.7.2 Stable](https://godotengine.org/download/archive/4.7.2-stable/).
2. Sao chép kho mã nguồn về máy bằng `git clone`.
3. Nhập `project.godot` trong trình quản lý dự án của Godot.

## Chạy trò chơi

- **Từ trình biên tập:** mở dự án và nhấn **F5**. Trò chơi bắt đầu tại menu chính để chọn bản đồ.
- **Library Tutorial:** bản đồ hướng dẫn ban đầu, có đầy đủ chuỗi nhiệm vụ lấy thẻ và trốn thoát.
- **Expanded Library:** thư viện hai tầng, thêm mạng lưới bảo trì ở tầng hầm trong bản mở rộng năm 2026, gồm bảy khu vực và bảy bảo vệ. Người chơi tự do khám phá theo các điều kiện nhiệm vụ: tìm thẻ nhân viên và bộ dụng cụ; mở bảng điện, cấp điện cho kho, suy luận mã khóa từ manh mối; lấy bản thảo quý rồi thoát theo một trong ba đường:
  - **Cửa chính:** khóa lại sau khi đi vào; cần thẻ an ninh tổng và thao tác ghi đè tại đầu đọc ở sảnh.
  - **Bến hàng:** cửa cuốn cần nguồn điện `SERVICE EXIT`, cơ cấu nhả được gỡ kẹt bằng bộ dụng cụ và lệnh `OPEN`.
  - **Lối bảo trì bí mật:** nằm ở tầng hầm và dẫn ra cống thoát nước.

  Người chơi đi qua lối thoát để thắng; màn hình kết quả ghi lại đường đã dùng. Các câu đố tùy chọn gồm máy bơm, tủ an ninh và đường tắt qua cổng sau khu lưu trữ. Bốn camera trên mạch `SURVEILLANCE` phát báo động khi phát hiện người chơi, khiến bảo vệ đến kiểm tra. Báo động không kết thúc lượt chơi ngay. Công tắc trong phòng điện điều khiển camera và nguồn điện bến hàng; bật nguồn bến hàng sẽ khởi động lại camera. Bảo vệ kiểm tra các chỗ ẩn gần nơi tìm kiếm; chỗ ẩn chỉ có tác dụng nếu không ai thấy người chơi đi vào. Chạy nhanh tiêu hao thể lực. Người chơi mang tối đa ba vật phẩm và có nhật ký lưu tài liệu, manh mối. HUD hiển thị `WAYS OUT` cho các đường thoát và điều kiện đã khám phá, trạng thái điện sau khi xem bảng công tắc và điểm hồi sinh gần nhất.
- **Cài đặt (`Settings`):** có trong menu chính và menu tạm dừng của cả hai bản đồ. Hỗ trợ cỡ giao diện 90/100/110/125 %, âm lượng tổng và phụ đề âm thanh. Phụ đề bật mặc định, hiển thị tiếng báo động, bước chân, bộ đàm, kính vỡ và công tắc kèm mũi tên chỉ hướng ở góc dưới trái. Cấu hình lưu tại `user://settings.cfg`.
- **Chạy thẳng một cảnh khi phát triển:** mở `maps/tutorial/scenes/library_graybox.tscn` hoặc `maps/library/scenes/expanded_library.tscn`, nhấn **F6**.
- **Bản đã đóng gói:** chạy `CampusEscape3D.exe`.

## Điều khiển

| Thao tác | Phím |
|---|---|
| Di chuyển | **W A S D** |
| Chạy nhanh | Giữ **Shift**; trong Expanded Library tiêu hao thể lực, chạy liên tục được 5 giây khi đầy và bắt đầu hồi sau khi dừng 1 giây |
| Ngồi thấp: yên tĩnh hơn, khó bị thấy hơn, di chuyển chậm hơn | Giữ **C** hoặc **Ctrl** |
| Tương tác: lấy thẻ, dùng cửa và đồ vật | **E** |
| Chọn vật phẩm đang mang trong Expanded Library | **1**, **2**, **3** |
| Dùng vật phẩm đã chọn, ném đồ gây xao nhãng trong Expanded Library | **F** |
| Mở nhật ký tài liệu và manh mối trong Expanded Library | **J** |
| Nhìn xung quanh | Chuột |
| Tạm dừng/tiếp tục, hiển thị con trỏ và menu tạm dừng | **Escape** hoặc **P** |
| Hiển thị gỡ lỗi: điều hướng, đường đi, tầm nhìn, phát hiện, trạng thái AI, vùng tiếng động và ước lượng thính giác | **F3**, trong bản có hỗ trợ gỡ lỗi |

Trò chơi không có thao tác nhảy. Các đường lên xuống sử dụng cầu thang; nhảy lên kệ có thể khiến người chơi bỏ qua khu vực hoặc ra ngoài bản đồ. Toàn bộ phím được khai báo tại **Project Settings → Input Map**.

## Đóng gói trò chơi

Hướng dẫn đầy đủ về đóng gói và phát hành nằm trong **[`docs/BUILD.md`](docs/BUILD.md)**.

**Từ trình biên tập trên Windows:**

1. Cài bộ mẫu xuất bản 4.7.2 tại **Editor → Manage Export Templates**.
2. Chọn **Project → Export → Windows Desktop → Export Project**, lưu tại `build/CampusEscape3D.exe` và bỏ chọn chế độ gỡ lỗi.
3. Phân phối `CampusEscape3D.exe` cùng `CampusEscape3D.pck`.

**Từ dòng lệnh trên Linux hoặc WSL, sử dụng đúng các lệnh mà CI chạy:**

```
export GODOT="$(bash tools/ci/setup_godot.sh | tail -n 1)"   # Tải Godot 4.7.2 và mẫu Windows, kiểm tra mã băm
bash tools/ci/validate.sh        # Kiểm tra phiên bản, nhập tài nguyên, biên dịch mã và cấu hình
bash tools/ci/run_tests.sh       # Toàn bộ kiểm thử, luồng trò chơi và chọn bản đồ
bash tools/ci/export_windows.sh  # → dist/CampusEscape3D-<version>-windows-x64.zip
```

## Đóng gói tự động

GitHub Actions, khai báo tại `.github/workflows/build.yml`, chạy khi:

- Đẩy mã lên nhánh `Development`, `main` hoặc `twp`.
- Tạo yêu cầu hợp nhất mã (PR) vào `Development` hoặc `main`.
- Đẩy thẻ phiên bản dạng `vX.Y.Z`.
- Chạy thủ công bằng nút **Run workflow**.

| Công việc | Các bước | Kết quả |
|---|---|---|
| Kiểm tra cấu hình và kiểm thử | Cài Godot 4.7.2, xác minh SHA-512 → `validate.sh` → `run_tests.sh` | Dừng quy trình nếu lỗi cấu hình, biên dịch, kiểm thử hoặc luồng trò chơi |
| Xuất bản Windows x64 | Chỉ chạy khi kiểm thử thành công: cài đặt → kiểm tra → `export_windows.sh` | Tải lên gói `CampusEscape3D-<version>-windows-x64`, giữ trong 30 ngày |
| Phát hành trên GitHub | Chỉ chạy với thẻ phiên bản và sau khi xuất bản thành công | Tạo bản phát hành kèm gói nén và nội dung `docs/release-notes/<tag>.md` |

**Thông tin xác thực:** quy trình không dùng hay lưu thông tin bí mật riêng; bước phát hành sử dụng `GITHUB_TOKEN` do GitHub cấp cho lần chạy.

**Quy trình phát hành:** tăng phiên bản → viết ghi chú phát hành → đẩy lên `Development` → chờ kiểm thử thành công → tạo thẻ `vX.Y.Z` → đẩy thẻ lên GitHub. Chi tiết trong `docs/BUILD.md`. Tài liệu phát hành được chuẩn bị cho **`v1.0.0`** (MVP, bản đồ hướng dẫn) và **`v1.1.0`** (cả hai bản đồ); việc có tài liệu chưa đồng nghĩa bản phát hành đã được công bố.

## Kiến trúc hệ thống

Mỗi bản đồ có một cảnh chính, chứa các hệ thống trò chơi dưới dạng nút. Menu chọn bản đồ theo `LevelCatalog`. Khi rời bản đồ, cảnh cùng các hệ thống của nó được giải phóng; dự án không dùng hệ thống tự nạp toàn cục (autoload). Các hệ thống tìm nhau qua nhóm, chẳng hạn `StealthDirector.find(node)`, và trao đổi qua tín hiệu. Phần trình bày như âm thanh, hoạt ảnh và giao diện lắng nghe sự kiện từ logic trò chơi.

```
shared/scenes/ui/main_menu.tscn                 Cảnh menu: một nút cho mỗi bản đồ trong LevelCatalog và nút thoát
maps/library/scenes/expanded_library.tscn       Thư viện mở rộng; công cụ dựng và trang trí nằm trong maps/library/tools/
└── Expansion (expanded_library_expansion.tscn) Phần mở rộng năm 2026: tầng hầm, mạng bảo trì khu G, phòng điện
                                               Công cụ tại maps/library/tools/expansion/; bộ dựng v4 được giữ làm mốc
maps/tutorial/scenes/library_graybox.tscn       Bản đồ hướng dẫn
├── NavigationRegion3D (+ library_navmesh.tres) Phòng, tường, kệ, bàn ghế và chỗ ẩn HidingSpot
├── Player (shared/scenes/player/player.tscn)   FirstPersonPlayer, PlayerNoise, PlayerInteractor, PlayerFeedback
│                                              PlayerStamina/PlayerInventory bật qua use_stamina/use_inventory
├── Guards                                     Các điểm PatrolRoute/PatrolPoint và cảnh shared/scenes/npc/guard.tscn
├── Gameplay                                   ObjectiveManager, vùng kích hoạt, AccessCard, ExitDoor, CheckpointManager
│                                              Thư viện mở rộng có thêm cửa thẻ và cửa một chiều AccessDoor
├── StealthDirector                            Trạng thái lén lút, bắt người chơi và đặt lại bản đồ
├── NoiseSystem                                Sự kiện tiếng động gửi tới thính giác bảo vệ
├── GameFlow                                   PLAYING / CAUGHT / PAUSED / WIN; tạm dừng, chơi lại, chuyển cảnh
├── StealthHud, ObjectiveHud, GameMenus          Giao diện cho người chơi
├── AudioDirector, Ambience                     Nhạc, âm hiệu, âm thanh giao diện và không gian
├── Dressing                                   Trang trí không va chạm: biển, sách, đèn, đồ vật
└── NavigationDebug, DetectionDebugHud          Lớp hiển thị gỡ lỗi F3, loại khỏi bản phát hành
```

| Thư mục | Nội dung |
|---|---|
| `shared/scripts/player/` | `FirstPersonPlayer`: di chuyển, ngồi thấp, nhìn, hồi sinh; `PlayerNoise`: tiếng bước chân; `PlayerInteractor`: dò tương tác bằng phím E |
| `shared/scripts/npc/` | `Guard`: điều hướng, di chuyển, dữ liệu cảm nhận; `GuardVision`, `GuardHearing`, `PatrolRoute`, `PatrolPoint` |
| `shared/scripts/npc/ai/` | Máy trạng thái `GuardStateMachine` với `PatrolState`, `InvestigateState`, `ChaseState`; dữ liệu cảm nhận `GuardPerception` |
| `shared/scripts/stealth/` | `StealthDirector`, `HidingSpot` |
| `shared/scripts/interaction/`, `shared/scripts/noise/`, `shared/scripts/debug/` | Tương tác chung, sự kiện tiếng động và hiển thị gỡ lỗi |
| `features/` | Các hệ thống tùy chọn: túi đồ, thể lực, nhiệm vụ, điểm hồi sinh, giải đố, an ninh |
| `shared/scripts/game/` | `GameFlow`, `GameStateMachine`, `LevelCatalog`: danh sách bản đồ trong menu |
| `shared/scripts/ui/` | `MainMenu`, `StealthHud`, `ObjectiveHud`, `GameMenus`, `MenuStyle` |
| `shared/scripts/presentation/` | `AudioDirector`, `SoundBank`, `PlayerFeedback`, `GuardPresentation`: hoạt ảnh mô hình; `AmbientEmitter`: âm thanh môi trường |
| `shared/scripts/level/` | `ShelfBooks`: tạo sách bằng `MultiMesh` |
| `maps/<map_id>/` | Cảnh, mã xử lý, tài nguyên, kiểm thử, công cụ và tài liệu riêng của bản đồ |
| `tests/` | Kiểm thử chung và bộ chạy đăng ký kiểm thử riêng của từng bản đồ |
| `tools/` | Công cụ đo hiệu năng, QA, chuyển bản đồ và CI; công cụ riêng nằm trong `maps/<map_id>/tools/`, đều được loại khỏi bản xuất |

**Các lớp vật lý:**

1. `world`: môi trường.
2. `player`: nhân vật người chơi.
3. `npc`: nhân vật máy.
4. `interactable`: đối tượng tương tác.

## Trạng thái AI của bảo vệ

Mỗi bảo vệ sử dụng máy trạng thái tại `shared/scripts/npc/ai/guard_state_machine.gd`, gồm ba trạng thái. Bản đồ hướng dẫn có ba bảo vệ; thư viện mở rộng hiện có bảy bảo vệ, sử dụng chung cảnh và nền tảng AI.

| Trạng thái | Hành vi |
|---|---|
| **PATROL** — tuần tra | Đi theo tuyến bằng `NavigationAgent3D`, dừng chờ tại từng điểm |
| **INVESTIGATE** — điều tra | Đi tới vị trí đã thấy dấu hiệu khả nghi hoặc vị trí ước lượng của tiếng động, tìm kiếm và nhìn quanh trong 6 giây rồi quay lại tuần tra |
| **CHASE** — truy đuổi | Chạy theo khi còn nhìn thấy người chơi; mất dấu thì điều tra vị trí cuối cùng đã biết |

**Chuyển trạng thái:** được kiểm tra trong mỗi nhịp vật lý theo thứ tự ưu tiên dưới đây. Điều kiện hợp lệ đầu tiên được áp dụng.

| Ưu tiên | Điều kiện | Chuyển trạng thái |
|---|---|---|
| 1 | Xác nhận nhìn thấy: mức phát hiện đạt 100 và người chơi còn trong tầm nhìn | PATROL / INVESTIGATE → CHASE |
| 2 | Thấy dấu hiệu khả nghi: mức phát hiện ≥ 30 | PATROL → INVESTIGATE tại vị trí nhìn thấy |
| 3 | Nghe tiếng động | PATROL → INVESTIGATE tại vị trí ước lượng |
| 4 | Hết thời gian tìm kiếm | INVESTIGATE → PATROL |
| 4 | Mất dấu người chơi | CHASE → INVESTIGATE |

Các chuyển trạng thái khác, chẳng hạn CHASE → PATROL trực tiếp, đều bị từ chối.

**Cảm nhận cơ bản:**

- **Thị giác:** góc nhìn 90°, tầm xa 14 m; bị tường và kệ cao che khuất.
- **Mức phát hiện:** từ 0 đến 100, tăng nhanh khi ở gần và giảm khi người chơi khuất tầm nhìn. Mức 30 là khả nghi (`SUSPICIOUS`), mức 100 là báo động (`ALERTED`).
- **Thính giác:** nghe bước đi trong khoảng 5 m, chạy nhanh trong khoảng 12 m; tường làm khoảng cách này giảm một nửa. Vị trí ước lượng luôn có sai số, tăng theo khoảng cách.
- **Ngồi thấp:** giảm một nửa tốc độ tăng mức phát hiện và làm bước chân nhỏ hơn.
- **Ô bàn học có vách:** khi ngồi thấp bên trong, vách che tầm nhìn từ hai bên và phía sau.

## Nội dung và cơ chế trò chơi

Bản đồ hướng dẫn tại `maps/tutorial/scenes/library_graybox.tscn` là một thư viện đại học nhỏ theo phong cách ít đa giác. Tên tệp được giữ từ giai đoạn dựng khối thô để ổn định các tham chiếu. Bản đồ gồm:

- **Entrance:** lối vào và điểm xuất hiện, có thảm đỏ, cây và bảng thông báo.
- **Main Library Room:** phòng chính, bốn kệ cao ở phía tây; phía đông là khu đọc sách **Reading Area** với bàn, đèn xanh, kệ thấp 1,2 m để ngồi ẩn và quầy thủ thư có quả địa cầu. Đồng hồ trên tường bắc hướng về lối vào.
- **Hallway West:** hành lang phía tây dẫn tới **Restricted Stacks**, khu mục tiêu có thảm đỏ, biển `RESTRICTED` đỏ trên hai cửa và thẻ ra vào được chiếu sáng trên bàn lưu trữ.
- **Back Corridor:** hành lang sau có xe đẩy sách và điểm hồi sinh **Staff Nook**.
- **Hallway East:** hành lang phía đông có ô bàn học để ẩn.
- **Exit Area:** khu thoát có bảo vệ, thùng, giá và cửa ra.

Có hai đường đến thẻ: phía tây qua Hallway West, hoặc phía đông qua Hallway East và hành lang sau. Từ thẻ cũng có hai đường tới cửa thoát, được đánh dấu bằng biển `EXIT` màu xanh. Lịch sử thiết kế, số đo và ảnh trước/sau của từng phiên bản nằm trong `maps/tutorial/docs/level/LEVEL_LOG.md`.

Ba **bảo vệ** màu xanh đậm tuần tra phòng chính, khu hạn chế và khu thoát; `GuardEast` canh lối ra. Mỗi người đi theo một tuyến lặp bằng `NavigationAgent3D`, dừng tại từng điểm. Tầm nhìn có góc 90°, xa 14 m, bị tường và kệ chắn. Khi thấy người chơi, mức phát hiện tăng nhanh ở gần và chậm ở xa; khi khuất tầm nhìn thì giảm. Mức 30 chuyển sang khả nghi, mức 100 chuyển sang báo động. Khi mất dấu, bảo vệ chỉ biết vị trí cuối cùng đã nhìn thấy người chơi.

- **PATROL:** đi theo tuyến tuần tra.
- **INVESTIGATE:** tới nơi thấy khả nghi hoặc nghe tiếng động, tìm kiếm trong 6 giây rồi quay lại tuần tra.
- **CHASE:** truy đuổi khi mức phát hiện đầy và còn nhìn thấy người chơi; khi mất dấu thì tới vị trí cuối cùng để điều tra.

Bảo vệ cũng **nghe tiếng động**:

- Đi bộ tạo bước chân nhỏ, nghe được trong khoảng 5 m.
- Chạy nhanh tạo tiếng lớn hơn, nghe được trong khoảng 12 m.
- Tường làm khoảng cách nghe giảm một nửa.
- Khi nghe thấy, bảo vệ điều tra vị trí ước lượng của tiếng động. Ước lượng luôn có sai số và càng xa càng kém chính xác.

Nhìn thấy người chơi luôn được ưu tiên hơn nghe tiếng động; bảo vệ đang truy đuổi bỏ qua tiếng động.

Ngồi thấp làm giảm một nửa tốc độ tăng mức phát hiện, thu nhỏ mục tiêu và giảm khoảng cách nghe bước chân xuống khoảng 2 m, đổi lại di chuyển chậm hơn. Năm **ô bàn học** có vách cao 1,4 m là chỗ ẩn: khi ngồi bên trong, vách che hai bên và phía sau; đứng lên sẽ để lộ đầu.

**Giao diện phát hiện:** dải thông báo phía trên hiển thị tình huống khẩn cấp nhất: đang bị đuổi, cần cắt tầm nhìn (`CHASED — break line of sight!`, đỏ); đang bị nhìn thấy (`YOU ARE BEING SEEN`, cam); bảo vệ đang điều tra (`A guard is investigating`, vàng); hoặc đang ẩn (`HIDDEN`, xanh). Các tam giác quanh tâm ngắm chỉ hướng từng bảo vệ đang chú ý, điều tra hoặc truy đuổi, kể cả phía sau. Biểu tượng `?` hoặc `!` xuất hiện trên đầu bảo vệ. Dòng dưới trái cho biết tư thế và mức tiếng động.

**Mục tiêu bản đồ hướng dẫn:** bảng nhiệm vụ ở góc trên phải hướng dẫn theo thứ tự:

1. Đi vào thư viện.
2. Đến khu Restricted Stacks.
3. Lấy thẻ trên bàn lưu trữ phía sau các kệ: nhìn vào thẻ và nhấn **E**.
4. Đến lối thoát.
5. Dùng cửa thoát bằng phím **E**.

Nhiệm vụ hoàn thành tuần tự. Cửa thoát vẫn khóa, có màu đỏ, cho tới khi có thẻ. Thử mở khi chưa đủ điều kiện làm cửa rung và tạo tiếng động mà bảo vệ gần đó có thể nghe.

**Chuỗi nhiệm vụ gốc của Expanded Library, trước bản mở rộng năm 2026:** gồm năm bước dưới đây, được giữ để đối chiếu các báo cáo và kiểm thử cũ. Nhiệm vụ hiện tại có tám mục bắt buộc, ba mục tùy chọn và ba đường thoát như phần Chạy trò chơi.

1. Đi vào thư viện.
2. Lấy thẻ nhân viên trong Office 2 ở tầng trên, khu nhân viên.
3. Lấy bản thảo quý trong kho lưu trữ. Dùng thẻ và phím **E** để mở Archive Front Gate hoặc Lobby Staff Door dẫn tới hành lang dịch vụ.
4. Mở cổng sau kho lưu trữ. Cổng chỉ mở từ phía trong, dẫn tới cầu thang nhân viên và bến hàng; có thể mở trước khi lấy bản thảo.
5. Thoát qua bến hàng bằng phím **E** trong phiên bản gốc; cửa còn khóa cho tới khi cổng sau mở.

Các điểm hồi sinh của thiết kế gốc gồm Study Rooms, Staff Offices và Storage. Bị bắt sẽ khôi phục trạng thái tại điểm gần nhất, gồm cả trạng thái cửa. Vạch sẫm trên sàn đánh dấu chỗ ẩn; ngồi thấp tại đó để nhận trạng thái `HIDDEN`. Biển đỏ đánh dấu cửa hạn chế. Bảo vệ thư viện mở rộng phát hiện và chạy nhanh hơn bản đồ hướng dẫn, nên cần tận dụng vật cản để cắt tầm nhìn.

**Điểm hồi sinh:** trong bản đồ hướng dẫn, bước lên đệm tại Hallway West hoặc Staff Nook cạnh hành lang sau để đặt điểm hồi sinh. Đệm chuyển sang màu xanh.

**Bị bắt:** bảo vệ đang truy đuổi sẽ bắt người chơi khi tới đủ gần. Sau 2,5 giây:

- Người chơi trở lại điểm hồi sinh gần nhất; nếu chưa kích hoạt điểm nào thì trở lại lối vào.
- Các bảo vệ trở về tuần tra và xóa ký ức về người chơi.
- Tiến độ nhiệm vụ được khôi phục về thời điểm kích hoạt điểm hồi sinh. Nếu lấy thẻ sau thời điểm đó, thẻ sẽ trở lại bàn.

Điểm hồi sinh không kích hoạt trong lúc bị truy đuổi.

**Luồng trò chơi:** có bốn trạng thái cấp trò chơi, tách biệt với AI của bảo vệ:

- **PLAYING:** đang chơi.
- **CAUGHT:** hiển thị màn hình bị bắt trong thời gian ngắn.
- **PAUSED:** tạm dừng.
- **WIN:** đã trốn thoát.

Hành vi tương ứng:

- **Tạm dừng:** nhấn Esc/P hoặc chuyển sang cửa sổ khác sẽ dừng bảo vệ, điều hướng, vật lý, tiếng động và bộ đếm thời gian. Con trỏ hiện ra cùng các nút tiếp tục (`Resume`), chơi lại (`Restart level`), cài đặt (`Settings`) và menu chính (`Main menu`).
- **Bị bắt:** sau màn hình thông báo, người chơi hồi sinh và trở về `PLAYING`. Không thể tạm dừng trong màn hình bị bắt.
- **Thắng:** màn hình hiển thị thời gian và số lần bị bắt, kèm nút chơi lại (`Play again`) và menu chính (`Main menu`).

Chuột chỉ được giữ trong cửa sổ khi đang chơi.

Nhấn **F3** để hiển thị lưới điều hướng màu lam, đường đi hiện tại màu vàng, tuyến tuần tra bằng các đường màu, vùng tầm nhìn xanh/vàng/đỏ theo mức nhận biết, đường nối tới người chơi khi bị thấy, dấu vị trí cuối cùng và nhãn trạng thái/mức phát hiện. Bảng góc trên trái liệt kê mức phát hiện của từng bảo vệ.

### Âm thanh và trình bày

- **Nhân vật:** tiếng chân theo từng bước, nhỏ khi ngồi thấp và nặng hơn khi chạy; đầu dao động nhẹ; góc nhìn rộng hơn một chút lúc chạy; âm báo nhỏ khi xuất hiện gợi ý tương tác.
- **Bảo vệ:** mô hình ít đa giác có các khớp, hoạt ảnh đứng yên, đi bộ, chạy và tìm kiếm; tiếng chân 3D, chìa khóa, hội thoại bộ đàm khi tuần tra và cuộc gọi khi bắt đầu điều tra. Biểu tượng `?`/`!` bật lên khi trạng thái đổi.
- **Thư viện:** âm nền trong phòng, tiếng đồng hồ, lật trang, đặt sách và ghế kêu theo từng lúc. Đây là âm trang trí, bảo vệ không nghe chúng.
- **Âm thanh lén lút:** âm hiệu ngắn khi bị chú ý, bị điều tra, bắt đầu truy đuổi hoặc mất dấu; nhạc căng thẳng khi bị nhìn thấy/điều tra và nhạc truy đuổi khi bị đuổi.
- **Giao diện:** thanh phát hiện dưới dải trạng thái; gợi ý phím tương tác; tiến độ như `OBJECTIVE 2/5` với hiệu ứng nháy khi đổi; menu tạm dừng và âm nút bấm; màn hình bị bắt có viền tối, đếm ngược hồi sinh; màn hình thắng có thống kê.
- Âm lượng được chia thành bốn kênh trong `default_bus_layout.tres`: `Music` (nhạc), `SFX` (hiệu ứng), `Ambience` (môi trường), `UI` (giao diện).
- Tất cả âm thanh được tạo bởi `tools/generate_audio.gd`, không dùng tài nguyên âm thanh bên ngoài. Tạo lại bằng `godot --headless --path . --script res://tools/generate_audio.gd`; bốn âm lặp được cấu hình trong tệp `.import` tương ứng.
- `maps/tutorial/tools/capture_presentation.gd` kết xuất tư thế bảo vệ và ảnh HUD vào `docs/presentation/`.

## Kiểm thử

**Chạy kiểm thử:** trong trình biên tập, mở `res://tests/test_scene.tscn` và nhấn **F6**. Khi thành công, chương trình in thông báo bắt đầu bằng `All tests passed`, kèm danh sách các giai đoạn đã kiểm tra: thiết lập, nhân vật, điều hướng, AI, thính giác, lén lút, nhiệm vụ, luồng trò chơi, trình bày, hiệu năng, QA và các phần mở rộng của thư viện. Từ dòng lệnh:

```bash
godot --headless --path . --editor --quit          # Lần đầu: nhập tài nguyên của dự án
godot --headless --path . res://tests/test_scene.tscn
godot --headless --path . --script res://tools/qa_flow.gd   # Luồng trò chơi với chuyển cảnh thật
godot --headless --path . --script res://tools/map_flow.gd  # Chọn, chơi lại và rời cả hai bản đồ, lặp 3 lần
```

- **Mã thoát:** `0` khi tất cả kiểm tra thành công, `1` khi có lỗi và liệt kê từng lỗi. Các kiểm thử di chuyển, điều hướng và cảm nhận chạy qua các nhịp vật lý thật nên có thể kéo dài hàng chục phút; lần kiểm tra trên Windows ngày 25/10/2026 mất khoảng 25 phút.
- **Cảnh báo dự kiến:** 8 cảnh báo từ các ca chủ động tạo cấu hình thiếu hoặc bị chặn để kiểm tra hành vi xử lý lỗi.
- **Trong CI:** `tools/ci/run_tests.sh` chạy toàn bộ bộ kiểm thử, kiểm tra luồng trò chơi và kiểm tra chọn bản đồ.
- **Cấu trúc và tài nguyên:** `python tools/ci/check_layout.py` kiểm tra đường dẫn; `tools/ci/check_map_contract.gd` kiểm tra giao tiếp giữa bản đồ, HUD và cửa thoát. Kết quả lần tổ chức lại nằm trong [VALIDATION.md](docs/architecture/VALIDATION.md).

### Kiểm thử dùng chung

- `tests/test_scene.gd` — bộ chạy kiểm thử và kiểm tra thiết lập giai đoạn 1: phiên bản Godot, cấu hình dự án, cấu hình xuất bản Windows, thư mục, cảnh khối thô và khả năng biên dịch mã.
- `tests/player_tests.gd` — giai đoạn 2: ánh xạ phím, tính toán chuyển động, giới hạn góc nhìn bằng chuột; trong cảnh kiểm tra tiếp đất, tốc độ đi/chạy, dừng, va chạm thùng/tường và hồi sinh khi rơi.
- `tests/navigation_tests.gd` — giai đoạn 3: đủ phòng; lưới điều hướng phủ sàn trống, không phủ tường/đồ đạc hoặc ra ngoài phòng; các mép sàn có tường; đường tới mọi phòng không xuyên tường; một đối tượng thử `NavigationAgent3D` đi từ lối vào tới lối ra; lớp gỡ lỗi vẽ được lưới; lưới đã lưu khớp với kết quả tạo lại.
- `tests/guard_tests.gd` — giai đoạn 4: logic tuyến tuần tra, cảnh bảo vệ, khả năng đi tới từng điểm; hoàn thành vòng đúng thứ tự và thời gian chờ, không dịch chuyển tức thời hoặc rời lưới; không chồng lên nhau, đi ngược chiều qua nhau; bỏ qua điểm bị chặn, đứng yên khi không có tuyến, dừng ở cuối tuyến không lặp.
- `tests/vision_tests.gd` — giai đoạn 5 trong khu thử riêng: góc/tầm nhìn; thời gian tăng mức phát hiện; giữ rồi giảm mức sau khi mất dấu; vị trí cuối cùng không cập nhật khi người chơi ẩn; tường và kệ cao chắn nhìn, bàn thấp không chắn; ngoài góc hoặc tầm nhìn không bị thấy; ở xa tăng mức chậm hơn; ngưỡng cấu hình được và vùng gỡ lỗi dừng ở tường. Trong thư viện, kiểm tra mọi bảo vệ có thị giác và không ai nhìn thấy điểm xuất hiện suốt một vòng tuần tra.
- `tests/ai_state_tests.gd` — kiểm thử đơn vị giai đoạn 6 với bảo vệ giả, không dùng vật lý: trạng thái đầu, mọi chuyển trạng thái hợp lệ, thứ tự ưu tiên nhìn thấy trước tiếng động, từ chối chuyển không hợp lệ, thứ tự vào/ra, yêu cầu lặp, 2.000 bước ngẫu nhiên và không chia sẻ trạng thái giữa các bảo vệ.
- `tests/ai_behavior_tests.gd` — giai đoạn 6 trong thư viện: bảo vệ đi qua chuỗi `PATROL → INVESTIGATE → CHASE → INVESTIGATE → PATROL` với nhân vật thật; chỉ theo vị trí cuối cùng khi mất dấu và điều tra tiếng động.
- `tests/hearing_tests.gd` — giai đoạn 7:
  - Cấu hình tiếng động, phạm vi nghe và tác dụng giảm âm của tường.
  - Vị trí ước lượng không chính xác tuyệt đối, có tính xác định, sai số tăng theo khoảng cách và khác nhau giữa các bảo vệ.
  - Bỏ qua sự kiện cũ/hết hạn; sự kiện trùng chỉ xử lý một lần; gộp bước chân lặp.
  - Nhiều bảo vệ hoạt động đồng thời và bỏ qua tiếng từ bảo vệ khác.
  - Bước đi tạo `WALK`, chạy tạo `RUN`; đứng yên và dịch chuyển tức thời không phát tiếng.
  - `NoiseMaker` tạo tiếng tương tác.
  - Trong thư viện, đi bộ sau bảo vệ không bị nghe nhưng chạy bị nghe; bảo vệ điều tra gần vị trí ước lượng, không đi đúng tọa độ thật; đang đuổi thì bỏ qua tiếng động.
- `tests/loop_tests.gd` — giai đoạn 8:
  - Ưu tiên trạng thái, ngồi thấp và không đứng dậy dưới dầm thấp.
  - Ô bàn học che người ngồi nhưng không che người đứng; nhìn từ phía mở làm tốc độ phát hiện giảm một nửa.
  - Mất dấu người chơi đang ẩn khiến bảo vệ điều tra rồi quay về tuần tra: `SPOTTED → INVESTIGATING → HIDDEN`.
  - Đi khi ngồi thấp ít gây tiếng; chỉ báo hướng và tư thế trên HUD đúng.
  - Người chạy có thể cắt đuôi; bị bắt làm đóng băng rồi đặt lại bản đồ.
- `tests/objective_tests.gd` — giai đoạn 9:
  - Trạng thái, thứ tự nhiệm vụ và ảnh chụp tiến độ.
  - Đến được các mục tiêu, thẻ, cửa và điểm hồi sinh theo thứ tự.
  - Tầm tương tác và tác dụng ngăn của tường.
  - Cửa từ chối khi thiếu thẻ; hoàn thành đầy đủ tới trạng thái `ESCAPED`.
  - Điểm hồi sinh giữ tiến độ trước đó, hoàn tác tiến độ về sau và đặt lại bảo vệ; không kích hoạt khi bị truy đuổi.
  - Không bảo vệ nào nhìn thấy vị trí hồi sinh trong vòng tuần tra.
- `tests/game_flow_tests.gd` — giai đoạn 10:
  - Máy trạng thái chỉ nhận chuyển hợp lệ, không lặp và chịu được 3.000 yêu cầu ngẫu nhiên.
  - Nút bắt đầu/thoát ở menu và phím Esc/P.
  - Tạm dừng/tiếp tục bằng phím, nút và khi cửa sổ mất tiêu điểm; con trỏ đúng trạng thái.
  - Khi tạm dừng, bảo vệ, điều hướng, mức phát hiện, nhân vật, đồng hồ tiếng động và bộ đếm đều dừng.
  - Bị bắt rồi hồi sinh, thắng, chơi lại và về menu; mỗi lần chỉ có một chuyển cảnh.
- `tests/level_design_tests.gd` — giai đoạn 11:
  - Đủ các không gian bắt buộc, hai đường độc lập tới thẻ và hai đường tới lối ra.
  - Đến được các chỗ ẩn, gồm ô bàn học trên đường phía đông.
  - Có biển `RESTRICTED`, tên phòng, `EXIT`, đèn chiếu thẻ và đồng hồ làm mốc.
  - Sách, biển, đèn và trần trang trí không va chạm; trần dùng lớp kết xuất 2.
  - Sách được tạo nhất quán và nằm trong kệ.
- `tests/presentation_tests.gd` — giai đoạn 12:
  - Tải được mọi âm thanh; âm lặp và âm phát một lần đúng cấu hình; đủ bốn kênh âm.
  - Dao động đầu, loại chuyển động, chọn hoạt ảnh bảo vệ và tách phím trong gợi ý tương tác.
  - Mô hình đủ khớp hoạt ảnh, không thêm va chạm, giữ nguyên khối va chạm và tốc độ bảo vệ.
  - Mỗi bước phát một tiếng; camera ổn định khi đứng yên.
  - Bảo vệ đi khi tuần tra, tìm kiếm khi điều tra, có tiếng chân và bộ đàm.
  - `AudioDirector` phản ứng với sự kiện lén lút, nhiệm vụ, tạm dừng và cửa, không lặp âm hiệu.
  - Âm giao diện hoạt động lúc tạm dừng; thanh phát hiện theo bảo vệ có mức nhận biết cao nhất.
- `tests/performance_tests.gd` — giai đoạn 13: giữ cấu hình bóng đã đo, gồm bóng mặt trời, 2 tầng bóng và bộ nhớ bản đồ bóng 2048; kiểm tra kịch bản và thống kê của công cụ đo hiệu năng.
- `tests/qa_playthrough_tests.gd` — giai đoạn 14: đi hết nhiệm vụ bằng thao tác thật, kích hoạt điểm hồi sinh, nhấn E lấy thẻ/dùng cửa, thắng và phát âm thanh; tạo truy đuổi, bị bắt rồi hồi sinh với hoạt ảnh, nhạc và màn hình tương ứng.
- `tests/qa_regression_tests.gd` — mỗi lỗi đã sửa trong đợt QA có một kiểm tra hồi quy, gồm hiệu ứng tiêu đề thắng và bố trí bảo vệ của công cụ đo hiệu năng.
- `tests/map_selection_tests.gd` — danh sách bản đồ, một nút cho mỗi bản đồ và điều hướng bàn phím; mỗi nút tải đúng một lần; mỗi bản đồ được tải hai lần, có đúng một bản của từng hệ thống, chơi lại đúng bản đồ, về đúng menu, không nhân đôi kết nối tín hiệu và giải phóng hết khi rời.
- `tests/map_hud_provider_tests.gd` — dữ liệu trạng thái và thông báo cửa thoát riêng được đưa vào HUD chung qua `MapHudProvider`; xóa dữ liệu khi gỡ nút cung cấp hoặc rời bản đồ. Bộ này được chạy riêng bởi `tools/ci/check_map_contract.gd`.

### Kiểm thử riêng của thư viện mở rộng

Các tệp dưới đây nằm trong `maps/library/tests/`. Nhiều bộ kiểm thử gốc được giữ để so sánh với thiết kế trước bản mở rộng năm 2026.

- `maps/library/tests/expanded_graybox_tests.gd` — cấu trúc cảnh, kích thước cửa/cầu thang, lưới hai tầng, phần trang trí không va chạm; mỗi phần rắn có một khối va chạm, không có chi tiết trang trí trong phạm vi 0,15 m của vùng đi; đến được mọi vị trí, từng cầu thang, cổng và hai hướng tiếp cận; nhân vật thật đi tuyến chính/phụ.
- `maps/library/tests/expanded_ai_tests.gd` — điều hướng và bảo vệ của bố cục gốc: hai tầng được tạo lưới và bịt kín; điểm tuần tra tránh cửa/cầu thang; sáu bảo vệ gốc đi hết vòng đồng thời không kẹt; tường, kệ, sàn và lan can ảnh hưởng thị giác; nghe ở chỗ mở, qua tường và qua sàn; truy đuổi, mất dấu, lên/xuống cầu thang; đi ngược chiều qua cửa và cầu thang; một bảo vệ đi qua mọi cổng và cầu thang.
- `maps/library/tests/expanded_layout_expansion_tests.gd` — bố cục mở rộng, giai đoạn 2: bảy khu, mọi khu mới đi tới được; bịt kín bên ngoài, cống sau song chắn và dưới sàn; năm tuyến qua khu kệ; cửa mới rộng 2 m, cao 2,6 m và hai cầu thang bảo trì đủ rộng, độ dốc, khoảng trống đầu; nhân vật đi xuống phía tây, qua hầm và lên phía đông; bảo vệ tới mọi khu mới; khu D vẫn cần thẻ dù đi từ tầng hầm.
- `maps/library/tests/expanded_mechanics_tests.gd` — thể lực và túi đồ, giai đoạn 3: quy tắc thể lực ở 7–144 Hz và thời gian khung hình không đều; chạy thật tại 30/60/120 nhịp vật lý cho cùng 5 giây và quãng đường; không mất thể lực khi đi, đứng, ngồi, ẩn, tương tác hoặc bị nhìn thấy; hồi sinh nạp đầy. Kiểm tra ba ô đồ, từ chối món thứ tư/thẻ khi đầy, dụng cụ và thẻ không tiêu hao; mỗi lần ném thành công mất một vật phẩm và tạo một tiếng khiến bảo vệ điều tra, ném thất bại không tiêu hao; tài liệu chỉ ghi nhật ký một lần; chỉ gửi/lấy/đổi ở kệ lưu đồ, tổng đồ không đổi; cửa kiểm tra thẻ đang mang; ba lần bị bắt khôi phục ô, kệ và vật nhặt không trùng; bản đồ hướng dẫn không có các cơ chế này.
- `maps/library/tests/expanded_puzzle_tests.gd` — giải đố, nhật ký và nhiệm vụ, giai đoạn 4: đồ thị nhiệm vụ đủ điều kiện tiên quyết, không có chu trình hoặc phụ thuộc từ mục bắt buộc vào mục tùy chọn; kho/bản thảo được bảo vệ và không tiết lộ mã. `ObjectiveManager` hỗ trợ mục song song, tùy chọn, ẩn và khôi phục nhất quán, giữ nguyên chế độ tuyến tính. Chơi hai tuyến hợp lệ bằng thao tác thật: bến hàng không làm tùy chọn và cống qua máy bơm. Thử các thứ tự sai: thiếu thẻ, mở kho bằng tay, lấy bản thảo sớm, khóa thiếu điện, cầu dao sau nắp, mã/cầu dao sai gây báo động, khóa tạm thời và thử lại, thoát sớm, máy bơm đình trệ; kiểm tra tủ tùy chọn. Khôi phục điểm hồi sinh vẫn giữ nhật ký/khám phá và giải tiếp được.
- `maps/library/tests/expanded_security_tests.gd` — an ninh, giai đoạn 5: quy tắc mở rộng chỉ áp dụng cho bảy bảo vệ của thư viện; giữ bản đồ hướng dẫn và cảnh bảo vệ gốc. Kiểm tra nghe, nhìn, truy đuổi, mất dấu, tìm kiếm và tuần tra; đồ ném kéo bảo vệ tới chỗ rơi; đi vào chỗ ẩn khi không bị thấy thì ẩn được, khi bị thấy thì không, bảo vệ tìm kiếm có thể kiểm tra và phát hiện. Báo động nhân tốc độ phát hiện 1,6 và thời gian tìm kiếm 1,5 nhưng không tự bắt người chơi. Camera phát hiện chậm hơn khi ngồi/ở xa, báo đúng vị trí, cập nhật HUD và gọi bảo vệ; tắt thì tối, không ảnh hưởng AI bảo vệ. Tám tổ hợp mạch điện chỉ cấp đúng thiết bị; khởi động lại và khóa công tắc 30 giây; bến hàng cần bản thảo/điện, cống không cần điện và không gây bế tắc; khôi phục mạch theo điểm hồi sinh; truy đuổi lên cầu thang đông rồi quay lại; vòng tuần tra bảo vệ tầng hầm.
- `maps/library/tests/expanded_escape_tests.gd` — đường thoát và điểm hồi sinh, giai đoạn 6: chơi từng đường trong lượt mới, dùng thao tác thật ở phần cần thiết. Cửa chính khóa lại, đầu đọc từ chối thiếu thẻ, thao tác ghi đè bị ngắt/hoàn tất và báo động camera sảnh; cửa cuốn thiếu điện, cơ cấu kẹt, dụng cụ, lệnh `OPEN`, tắt/bật điện; vách bí mật chỉ có gợi ý sau khi đọc sơ đồ, chốt, song chắn kẹt và máy bơm. Mọi đường đều từ chối khi thiếu bản thảo, các đường khác giữ đóng, màn hình thắng ghi đúng đường. Kiểm tra bị bắt trước điểm đầu, màn hình, vị trí/hướng hồi sinh, thể lực, mức phát hiện, đồ, nhiệm vụ, câu đố, điện, cửa, vách, nhật ký, HUD; năm lần bị bắt không nhân đồ; mở đường trước/sau điểm hồi sinh vẫn hoàn thành được; bảo vệ trở lại vị trí lưu ở `PATROL` và đủ khoảng trống hồi sinh.
- `maps/library/tests/expanded_hud_tests.gd` — HUD và khả năng tiếp cận, giai đoạn 7: giá trị cài đặt mặc định/sai, lưu/đọc, áp dụng cỡ giao diện và kênh `Master`, menu chính/tạm dừng. HUD phản ánh thể lực, `EXHAUSTED`, ô đồ, nhiệm vụ và nhật ký chỉ chứa tài liệu/manh mối. `WAYS OUT` và thông báo chỉ nêu đường/điều kiện đã biết; lối bí mật chỉ hiện sau sơ đồ. Kiểm tra nhật ký, đường thoát, điện sau khi bị bắt; phụ đề báo động, vật gây xao nhãng, công tắc, âm hiệu, tiếng chân, hướng/tầng, ngoài tầm nghe và khi tắt. Kiểm tra bố cục 1280×720, 1920×1080, 1024×768, 2560×1440 ở mọi cỡ giao diện: nằm trong màn hình, không chồng, nhấn J xem hết nhật ký. Kiểm tra màn hình kết quả và HUD hướng dẫn có phụ đề/cài đặt.
- `maps/library/tests/expanded_e2e_tests.gd`, cùng `tests/e2e_walker.gd` — chơi từ đầu đến cuối, giai đoạn 8: đi từ hiên tới lối thoát bằng phím di chuyển, E, F và phím ô đồ, không dịch chuyển tức thời. Lượt bắt buộc thoát bến hàng: thử sai cầu dao/mã rồi sửa, bị từ chối khi thiếu bản thảo, không mở cổng sau từ phía cầu thang, đi khắp khu và cầu thang khi mang bản thảo. Lượt làm đủ tùy chọn thoát cửa chính, bị bắt giữa chừng và khôi phục đồ/nhiệm vụ/câu đố, giữ nhật ký. Lượt thoát lối bí mật đổi mạch theo thứ tự khác. Ném đồ vào bảo vệ ở `PATROL`, `INVESTIGATE`, `CHASE`; chơi lại bản đồ hướng dẫn. Người bị cửa từ chối vẫn đứng an toàn ở ngưỡng cửa.
- `maps/library/tests/expanded_polish_tests.gd` — hoàn thiện và hiệu năng, giai đoạn 9: âm xoay số, sai mã, giải đúng, nhặt đồ, nắp bảng/công tắc, đồ ném và đầu đọc; âm phát tại đúng cơ cấu, không phát âm nhặt khi bị từ chối. Hộp trang trí không va chạm, nằm trên sàn như hình trang trí, trên đầu hoặc ngoài lưới, cách đồ tương tác/chỗ ẩn ít nhất 0,6 m; đủ biển mới; nhãn trạng thái cống dưới biển tường; bản đồ hướng dẫn không có âm cơ cấu riêng. Các sửa lỗi bổ sung: máy bơm đình trệ không phát âm sai mã; đi được vào chỗ ẩn hầm/ban công; điểm Maintenance Bay lưu/hồi sinh hướng về cửa; Staff Offices hồi sinh trong Office 1; mỗi mô hình chịu tối đa 8 đèn.
- `maps/library/tests/expanded_baseline_tests.gd` — mốc đối chiếu: cảnh con mở rộng được tạo đúng một lần sau `Gameplay`, đúng vị trí và chỉ trong thư viện mở rộng. Phần ngoài cảnh con giữ dấu vân tay hình học va chạm, trang trí gộp, khung cửa, bảo vệ, tuyến và nút nhiệm vụ so với commit `7d73492`. Tải luân phiên hai bản đồ không để sót hệ thống, bảo vệ hay mục tiêu.
- `maps/library/tests/expanded_mission_tests.gd` — chuỗi năm nhiệm vụ gốc: thao tác thật từ lúc bắt đầu tới màn hình thắng; từ chối thiếu thẻ, mở sai phía, lấy bản thảo sớm, thoát trước đường tắt; cửa đóng chặn nhân vật và tầm nhìn. Mở cổng sau trước khi lấy bản thảo; bị bắt trước/sau lấy thẻ, sau bản thảo, sau đường tắt và lặp năm lần; đặt lại bảo vệ, không kích hoạt điểm hồi sinh khi bị đuổi; sau mỗi hồi sinh, đồ/cửa/nhiệm vụ/lối ra/HUD khớp ảnh trạng thái đã lưu.

**Công cụ cân bằng, chỉ dùng khi phát triển:** `maps/library/tools/coverage_map.gd` đo tầm nhìn, bản đồ nhiệt và độ lộ của tuyến; `maps/library/tools/playtest_bot.gd` là người chơi thử tự động, đã cập nhật ở giai đoạn mở rộng 8 để đi bốn phương án bến hàng, cửa chính, lối bí mật và đầy đủ; `maps/library/tools/summarize_playtests.py` tổng hợp kết quả. Xem `maps/library/docs/phase-5-balance.md`; quy trình người chơi thử trong `maps/library/docs/PLAYTEST_PROTOCOL.md`.

**Công cụ hình ảnh, chỉ dùng khi phát triển:** `maps/library/tools/capture_views.gd` chụp cùng góc nhìn qua các bản; `maps/library/tools/light_report.gd` đối chiếu đèn với giới hạn bộ kết xuất Compatibility và độ sáng tuyến tuần tra; `maps/library/tools/profile_expanded.gd` đo kết xuất kèm chẩn đoán; `maps/library/tools/collision_fingerprint.gd` ghi các khối va chạm, bảo vệ và điểm tuần tra để so sánh hai bản. Xem `maps/library/docs/phase-6-visual-polish.md`.

**Trước khi phát hành:** thực hiện `docs/qa/REGRESSION_CHECKLIST.md`, gồm kiểm thử tự động và kiểm tra thủ công trên Windows.

### Công cụ kiểm tra chất lượng

- `tools/qa_flow.gd` chạy luồng trò chơi và chuyển cảnh thật, kiểm tra 15 bước: từ menu bắt đầu, tạm dừng, tiếp tục, chơi lại; bị bắt rồi hồi sinh, về menu và bắt đầu lại; thắng, chơi lại và thoát. Chạy bằng `godot --path . --script res://tools/qa_flow.gd -- --out=docs/qa/flow_check`; thành công in `QA FLOW PASSED`, thoát với mã `0`.
- `tools/map_flow.gd` chọn từng bản đồ từ menu thật, chơi lại và về menu, lặp ba lần. Sau mỗi chuyển cảnh, kiểm tra đúng cảnh, giải phóng cảnh cũ, mỗi hệ thống chỉ có một bản, số kết nối tín hiệu không đổi và số nút không tăng. Thành công in `MAP FLOW PASSED`, thoát với mã `0`.
- `docs/qa/REGRESSION_CHECKLIST.md` liệt kê các bước tự động và thủ công cần thực hiện trước phát hành.

## Kết quả đo hiệu năng

Các số liệu dưới đây là kết quả lịch sử tại từng giai đoạn, không phải kết quả đo lại sau khi đổi cấu trúc thư mục. Kiểm tra cấu trúc mới ngày 25/10/2026 được ghi riêng trong [VALIDATION.md](docs/architecture/VALIDATION.md).

**Phiên bản 1.1.0, cả hai bản đồ:** xem [`docs/performance/release_1_1/README.md`](docs/performance/release_1_1/README.md). Trên máy ảo phát triển dùng kết xuất phần mềm, FPS tuyệt đối không phản ánh máy chơi thật. Thư viện mở rộng đạt khoảng 93% tốc độ khung hình của bản đồ hướng dẫn, với số lệnh vẽ tương đương; 24 bảo vệ tiêu tốn khoảng 2,5 ms CPU mỗi khung hình ở cả hai bản đồ. **Các mục tiêu 60/45 FPS chưa được đo trên Windows cho phiên bản này trong báo cáo đó**; lệnh đo nằm trong tài liệu liên kết.

**Giai đoạn 13, bản đồ hướng dẫn:** phương pháp và dữ liệu đầy đủ trong **[`docs/phase-13-performance.md`](docs/phase-13-performance.md)**. Bằng chứng nằm tại `docs/performance/`, gồm CSV từng khung hình, bản tổng hợp, biểu đồ và ảnh kết xuất trước/sau.

**Công cụ đo:**

- `tools/benchmark.gd` chạy lại kịch bản cố định trong bản đồ thật: camera đi theo đường định sẵn, tiếng động xuất hiện theo lịch cố định.
- Các kịch bản gồm thông thường `normal` với 3 bảo vệ, nhiều bảo vệ `several` với 8 và tải nặng `stress` với 24.
- Ghi thời gian khung hình, mã xử lý, AI, hoạt ảnh, kết xuất, số lệnh vẽ, bộ nhớ và bảo vệ bị kẹt.

**Đo trên máy ảo Linux không có GPU:** 2 CPU ảo, Mesa llvmpipe kết xuất bằng phần mềm, độ phân giải 1280×720, bản có gỡ lỗi. Đây là môi trường dùng để tìm và đo tác dụng của tối ưu bóng.

| Chỉ số | Thông thường, 3 bảo vệ | Tải nặng, 24 bảo vệ |
|---|---|---|
| FPS trung bình trước → sau tối ưu bóng | 8,37 → 11,61 | 7,85 → 10,57 |
| Thời gian khung hình trung bình trước → sau | 119,6 → 86,2 ms | 127,3 → 94,6 ms |
| CPU mỗi khung hình khi không kết xuất, gồm logic, vật lý và điều hướng | 0,7 ms | 2,1 ms |

**Đo trên phần cứng Windows:** kiểm tra phát hành ngày 09/10/2026, Windows 10, Intel i5-8265U, NVIDIA GeForce MX130, 1280×720, bản có gỡ lỗi. Bằng chứng trong `docs/performance/windows/`, chi tiết trong `docs/FINAL_REPORT.md`.

| Chỉ số | Thông thường, 3 bảo vệ | Tải nặng, 24 bảo vệ |
|---|---|---|
| FPS trung bình, trong ngoặc là nhóm 1% khung hình chậm nhất | 202,8 (62,1) | 153,2 (57,5) |
| Thời gian khung hình trung bình / phân vị 95 | 4,94 / 6,81 ms | 6,54 / 10,7 ms |
| CPU mỗi khung hình khi không kết xuất | 0,85 ms | 2,93 ms |

**Kết quả phân tích:**

- Kết xuất chiếm khoảng 90% thời gian khung hình; bóng mặt trời với 4 tầng là chi phí đơn lẻ lớn nhất.
- Giảm còn 2 tầng và kích thước bộ nhớ bản đồ bóng 2048; phép so sánh điểm ảnh không thấy thay đổi hình ảnh.
- Logic trò chơi có chi phí thấp: 48 bảo vệ dùng 3,8 ms CPU mỗi khung hình trong phép đo này.
- Bộ nhớ ổn định trong lượt chạy 5 phút.
- Đợt QA giai đoạn 14 đã sửa số liệu tải nặng sau khi khắc phục lỗi của công cụ đo.

### Chạy đo hiệu năng

`tools/benchmark.gd` chạy bản đồ thật với kịch bản cố định, lặp lại được; ghi thời gian khung hình, mã xử lý, AI bảo vệ, hoạt ảnh, kết xuất, số lệnh vẽ, bộ nhớ và số NPC:

```bash
godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --scenario=normal --out=docs/performance/my_run
godot --headless --fixed-fps 60 --path . --script res://tools/benchmark.gd -- --scenario=stress --out=docs/performance/my_run
godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=stress --out=docs/performance/my_run
```

- Chọn `--level=tutorial` mặc định hoặc `--level=expanded`. Mỗi bản đồ có vòng camera và các điểm tiếng động riêng.
- Cấu hình kịch bản của công cụ: bản đồ hướng dẫn `normal` 3 bảo vệ, `several` 8, `stress` 24; thư viện mở rộng `normal` 6, `several` 12, `stress` 24; hoặc đặt `--npcs=N`. Đây là số NPC của kịch bản đo, không phải tổng bảo vệ trong bản đồ hiện tại.
- Chế độ `--headless` chỉ đo CPU, một nhịp vật lý mỗi khung hình và không kết xuất.
- `python3 docs/performance/analyse.py` tạo lại bảng và biểu đồ, cần thư viện matplotlib.
- Phương pháp và kết quả nằm trong `docs/phase-13-performance.md`.

## Lịch sử các phiên bản thiết kế bản đồ

Thư viện mở rộng có nhật ký riêng tại **[`maps/library/docs/LEVEL_LOG.md`](maps/library/docs/LEVEL_LOG.md)**, thiết kế tại [`maps/library/docs/LAYOUT.md`](maps/library/docs/LAYOUT.md). Các commit trên nhánh `Development` ghi nhận: v0 `cce1e9a`, v1 `3896e7c`, v2 `8dd2d63`, v3 và v4 cùng nằm trong `484761d`.

Bản đồ hướng dẫn trải qua năm phiên bản có số đo, mỗi phiên bản có thư mục bằng chứng. Cả năm được đưa vào Git trong commit `3320e45`. Nhật ký đầy đủ về thay đổi, lý do, số đo và ảnh trước/sau nằm tại **[`maps/tutorial/docs/level/LEVEL_LOG.md`](maps/tutorial/docs/level/LEVEL_LOG.md)**.

| Phiên bản | Thay đổi | Bằng chứng |
|---|---|---|
| v0 | Mốc ban đầu: đo bản khối thô giai đoạn 10 bằng bộ công cụ bản đồ mới | `maps/tutorial/docs/level/v0/` |
| v1 | Bổ sung vật che và điều chỉnh tầm nhìn: kệ thấp, tủ mục lục, ô bàn học hành lang đông, xe sách, thùng và giá ở khu thoát | `maps/tutorial/docs/level/v1/` cùng `compare.md` |
| v2 | Chuyển GuardEast sang canh khu thoát; đo 6 tuyến đề xuất, chọn B2 | `maps/tutorial/docs/level/v2/` cùng `experiments/` |
| v3 | Tăng khả năng nhận biết: cửa, biển tên phòng, `RESTRICTED`, `EXIT`, mốc định hướng và đèn chiếu thẻ; chỉ đổi hình ảnh, số đo giữ nguyên | `maps/tutorial/docs/level/v3/` |
| v4 | Hoàn thiện đồ họa ít đa giác: bảng màu, ánh sáng, sách, trần, ghế, cây, cửa sổ, áp phích và thảm | `maps/tutorial/docs/level/v4/`, `maps/tutorial/docs/level/before_after/` |

**Đo từ v0 đến v4:**

- Tỷ lệ sàn cách vật che không quá 1,5 m tăng từ 33% lên 42%.
- Tuyến phía đông an toàn nhất đến thẻ ngắn hơn, từ 115–117 m còn 103 m; mức lộ cao nhất giảm từ 38% xuống 31%.
- Điểm xuất hiện và hai điểm hồi sinh giữ mức lộ 0%.

## Giới hạn và những việc cần kiểm chứng

**Phạm vi:**

- Hiện có hai bản đồ chơi được: bản hướng dẫn và thư viện mở rộng. Các bản đồ khác mới có khung thư mục.
- Chưa có lưu tiến trình lượt chơi ra đĩa.
- Menu đã có cỡ giao diện, âm lượng và phụ đề âm thanh; chưa có đầy đủ tùy chỉnh độ nhạy chuột hoặc độ phân giải.
- Thoát ứng dụng từ menu chính.

**Kiểm thử:**

- Báo cáo phát hành ngày 09/10/2026 ghi nhận bộ kiểm thử và luồng trò chơi qua trên Linux, máy ảo phát triển và Windows 10.
- Trong đợt đó, bản thực thi Windows do CI tạo đã được mở và đi từ menu vào bản đồ; chưa có bản ghi chơi thủ công đầy đủ phần 2 của danh sách kiểm tra.
- Âm thanh chưa có đánh giá nghe trực tiếp được ghi nhận trong báo cáo.
- Các lượt chơi bằng chương trình không đánh giá được độ khó lén lút; cần người chơi thật.
- **Báo cáo phát hành 1.1.0:** bộ kiểm thử, luồng và xuất bản qua trên Linux, gồm máy ảo và CI lần #5 tại `484761d`. Báo cáo đó chưa ghi nhận việc mở bản xuất Windows, chọn cả hai bản đồ, chơi hết thư viện mở rộng và đo FPS cho phiên bản này. Mục tiêu hoàn thành 20–30 phút chưa được xác nhận bằng người chơi; kết quả của chương trình chơi thử nằm tại `maps/library/docs/v3/` và `v4/playtests/`.
- **Kiểm tra sau tổ chức thư mục ngày 25/10/2026:** bộ kiểm thử cơ chế chơi đầy đủ, kiểm tra chuyển bản đồ và tải gói PCK đã qua trên Windows; xem [biên bản kiểm tra](docs/architecture/VALIDATION.md). Kết quả này không thay thế việc chơi thủ công hoặc đo FPS.

**Bản đồ:**

- Cảnh hướng dẫn vẫn mang tên `library_graybox.tscn` để giữ ổn định tham chiếu.
- Vật trang trí như ghế, biển và sách không có va chạm; cây có va chạm. Phần trang trí không phải đồ tương tác.
- Cửa sổ sử dụng các mặt phẳng phát sáng.
- Bản hướng dẫn có hai điểm hồi sinh, chưa có điểm trên tuyến đông sau khi lấy thẻ.
- Thư viện mở rộng từng sửa hiện tượng nhấp nháy do hai bề mặt chồng nhau ở khung cửa trực tiếp trong cảnh. Dựng lại bằng `maps/library/tools/build_expanded_graybox.gd` có thể đưa khung cửa cũ trở lại.

**AI:**

- Các bảo vệ dùng chung một tuyến có thể chặn nhau ở lối hẹp khoảng 5 giây trước khi bỏ qua điểm. Hai bản đồ chính dùng một bảo vệ cho mỗi tuyến; kịch bản tải nặng chủ động thêm nhiều bảo vệ trên cùng tuyến, xem `docs/performance/release_1_1/`.
- Âm thanh môi trường chỉ phục vụ trang trí: bảo vệ không nghe và tường không làm giảm âm này.

**Trình bày:**

- Mô hình bảo vệ gồm các khối cứng, hoạt ảnh bằng mã; khoảng 20 lệnh vẽ cho mỗi bảo vệ theo báo cáo hiện có.
- Âm thanh là các hiệu ứng tổng hợp đơn giản.

**Đóng gói:**

- Chỉ xuất bản cho Windows x64.
- Tệp thực thi chưa được ký số.
- Các gói không giống nhau hoàn toàn ở mức từng byte vì lưu thời gian của tệp.
- Báo cáo CI cũ ghi nhận cảnh báo về Node.js 20 của các tác vụ `checkout`, `cache`, `upload-artifact` phiên bản `@v4`; cần đọc nhật ký của lần chạy cụ thể để biết trạng thái hiện tại.

**Lịch sử CI:** [lần đóng gói #5](https://github.com/SE2026-T10/CampusEscape3D-2/actions/runs/38188815204) tại `484761d`, thuộc giai đoạn 5–6 của thư viện mở rộng, qua kiểm tra/kiểm thử trong 11 phút 59 giây và xuất Windows trong 42 giây; tải lên `CampusEscape3D-1.0.0-windows-x64`, 37,6 MB. Các lần #1–#5 được báo cáo thành công. [Lần đóng gói #1](https://github.com/SE2026-T10/CampusEscape3D-2/actions/runs/37272574230) tại `15b3ebf` qua kiểm tra/kiểm thử trong 4 phút 16 giây, xuất Windows trong 39 giây và tải gói 37,5 MB. Đây là kết quả lịch sử, không đại diện cho CI của nhánh hiện tại.

## Hướng dẫn phát triển

### Thêm hoặc chỉnh tuyến tuần tra

1. Thêm nút `PatrolRoute`, gắn mã `shared/scripts/npc/patrol_route.gd`, dưới `Guards`. Bỏ chọn **Loop** nếu muốn bảo vệ dừng ở điểm cuối.
2. Thêm các nút con `Marker3D`, gắn `shared/scripts/npc/patrol_point.gd`, theo thứ tự đi và đặt trên sàn có thể đi. Cấu hình **Wait Time** cho từng điểm; `-1` dùng thời gian mặc định của bảo vệ.
3. Thêm một thể hiện của `shared/scenes/npc/guard.tscn` dưới `Guards`, đặt **Patrol Route** trỏ tới tuyến mới. Nhiều bảo vệ có thể dùng chung tuyến.

Kiểm thử xác nhận từng điểm tuần tra trong thư viện nằm trên lưới điều hướng và có đường tới.

### Công cụ thiết kế bản đồ

Đo bản đồ và ghi lại một phiên bản; chạy trên đúng commit cần lưu bằng chứng:

```bash
godot --path . --script res://maps/tutorial/tools/level_report.gd -- --out=maps/tutorial/docs/level/v5 --version=v5
godot --path . --resolution 1280x720 --script res://maps/tutorial/tools/capture_views.gd -- --out=maps/tutorial/docs/level/v5/views
godot --headless --path . --script res://maps/tutorial/tools/level_compare.gd -- --before=maps/tutorial/docs/level/v4 --after=maps/tutorial/docs/level/v5
```

Kết quả của từng công cụ:

- `level_report.gd` tạo `report.md`, `metrics.json` và `map.png` khi chạy có hiển thị. Các chỉ số gồm:
  - Mức lộ: tỷ lệ thời gian một vị trí nằm trong tầm nhìn của bảo vệ trong vòng tuần tra.
  - Vùng che chắn.
  - Vòng tuần tra.
  - Đường ngắn nhất và an toàn nhất của người chơi.
  - Mức lộ của chỗ ẩn và vị trí hồi sinh.
- `--scene=res://other.tscn` chuyển sang đo một cảnh thử nghiệm khác.
- `capture_views.gd` chụp 8 góc nhìn cố định và một góc từ trên xuống để so sánh các phiên bản cùng vị trí.
- `level_compare.gd` tạo bảng trước/sau trong `compare.md`.

### Tạo lại lưới điều hướng sau khi đổi bản đồ

Lưới điều hướng được tạo từ các khối va chạm tĩnh, lưu tại `maps/tutorial/resources/library_navmesh.tres`. Sau khi di chuyển tường, kệ hoặc đồ đạc, tạo lại bằng một trong hai cách:

- **Trong trình biên tập:** chọn `NavigationRegion3D` trong cảnh thư viện, nhấn **Bake NavigationMesh** trên thanh công cụ rồi lưu bằng Ctrl+S.
- **Từ dòng lệnh:** `godot --headless --path . --script res://maps/tutorial/tools/bake_navigation.gd`.

Nếu quên tạo lại, kiểm thử báo `The saved navigation mesh is out of date`, nghĩa là lưới đã lưu không còn khớp với bản đồ.

## Tài liệu tham khảo

- [Tổ chức và làm việc theo bản đồ](docs/architecture/MAP_LAYOUT.md).
- [Kết quả kiểm tra sau khi tổ chức lại](docs/architecture/VALIDATION.md).
- `docs/phase-1-setup.md` — thiết lập dự án.
- `docs/phase-2-first-person-player.md` — nhân vật góc nhìn thứ nhất.
- `docs/phase-3-library-navigation.md` — điều hướng trong thư viện.
- `docs/phase-4-npc-patrol.md` — tuần tra của NPC.
- `docs/phase-5-npc-vision.md` — thị giác NPC.
- `docs/phase-6-npc-ai-state-machine.md` — máy trạng thái AI.
- `docs/phase-7-hearing-and-noise.md` — thính giác và tiếng động.
- `docs/phase-8-stealth-loop.md` — vòng lặp lén lút.
- `docs/phase-9-objectives-and-checkpoints.md` — nhiệm vụ và điểm hồi sinh.
- `docs/phase-10-game-flow.md` — luồng trò chơi.
- `docs/phase-11-final-level.md` — bản đồ hoàn thiện.
- `maps/tutorial/docs/level/LEVEL_LOG.md` — thiết kế v0–v4 cùng bằng chứng.
- `docs/phase-12-presentation.md` — âm thanh và trình bày.
- `docs/phase-13-performance.md` — đo, phân tích, tối ưu hiệu năng; bằng chứng trong `docs/performance/`.
- `docs/phase-14-qa.md` — kiểm tra chất lượng cuối kỳ; danh sách và bằng chứng trong `docs/qa/`.
- `docs/BUILD.md` — đóng gói, CI và quy trình phát hành.
- `docs/phase-15-build-pipeline.md` — quy trình đóng gói tự động.
- `docs/release-notes/v1.0.0.md` — ghi chú phát hành 1.0.0.
- `docs/release-notes/v1.1.0.md` — ghi chú phát hành 1.1.0.
- `maps/library/docs/expansion/` — phần mở rộng thư viện, mốc ban đầu và điểm tích hợp.
- `maps/library/docs/phase-7-release.md` — QA, hiệu năng, đóng gói và nghiệm thu phiên bản 1.1.0.
- `docs/performance/release_1_1/README.md` — đo hiệu năng cả hai bản đồ.
- **[`docs/FINAL_REPORT.md`](docs/FINAL_REPORT.md)** — báo cáo MVP cuối cùng và kiểm chứng phát hành.
- Thiết kế thư viện mở rộng: `maps/library/docs/phase-0-audit.md`, `maps/library/docs/LAYOUT.md`, `maps/library/docs/phase-1-graybox.md`, `maps/library/docs/phase-2-map-selection.md`, `maps/library/docs/phase-3-navigation-and-guards.md`, `maps/library/docs/phase-4-mission.md`, `maps/library/docs/phase-5-balance.md`, `maps/library/docs/phase-6-visual-polish.md`, `maps/library/docs/PLAYTEST_PROTOCOL.md`, `maps/library/docs/LEVEL_LOG.md`.
