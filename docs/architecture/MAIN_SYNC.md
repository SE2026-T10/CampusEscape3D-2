# Đồng bộ main với cấu trúc phát triển theo bản đồ

Ngày thực hiện: 26/10/2026. Nhánh nhận kết quả: `twp`.

## Mã nguồn dùng để đối chiếu

- `main`: `504ce2ea14ae1b13b627cc3b108dfa3856cf0fae`, đã hợp nhất PR #3 và phần hoàn thiện thư viện tại `619d639`.
- `twp` trước đồng bộ: `10355a130831dfe53d5baed4d6e26be73557fb03`.
- Godot: `4.7.2.stable.official.ed1daf0bf`, kiểm tra tại máy Windows.

Các thay đổi mới của `main` được tích hợp vào `twp`, giữ lịch sử Git của cả hai nhánh. Bản cập nhật dành cho nhóm đánh giá cấu trúc trước khi quyết định hợp nhất vào các nhánh chính.

Nguồn `main` được chọn đang dùng phiên bản trò chơi `1.1.0`. Tại thời điểm đối chiếu, `Development` có thêm commit `f94adfd` chuẩn bị phát hành `1.2.0`. Khi nhóm thống nhất hợp nhất với `Development`, cần đồng bộ số phiên bản trong cấu hình, preset xuất bản và README theo kế hoạch phát hành của nhóm.

## Nội dung đã tích hợp

- Giữ cấu trúc `shared/`, `features/`, `maps/<map_id>/` và `templates/map/`; từng bản đồ độc lập, dùng chung nhân vật, AI, tương tác và HUD.
- Giữ toàn bộ phần hoàn thiện mới của thư viện: phòng điện, khóa số và tủ, máy bơm/cống, cửa cuốn, kho, khu xử lý sách, sảnh, khu kệ, văn phòng, phòng học và tầng hầm.
- Giữ mô hình và hoạt ảnh tương tác, đèn trạng thái, dấu tài liệu chưa đọc, vị trí vật phẩm, vật thể va chạm và navmesh 1.244 đa giác của `main`.
- Chuyển 12 script `fixes_x8.gd` đến `fixes_x19.gd`, cùng 12 tệp UID, vào `maps/library/tools/expansion/`. Các lệnh trong script sử dụng đường dẫn mới.
- Giữ giao diện `MapHudProvider`, menu chọn bản đồ độc lập và README tiếng Việt đã có trên `twp`.
- Giải quyết xung đột của bộ kiểm thử baseline bằng cách giữ đường dẫn mới cùng số đa giác mới. Công cụ dựng phần mở rộng giữ dữ liệu và `MainLayout` của `main`, dùng đường dẫn theo thư mục map.

## Đối chiếu dữ liệu nguồn

Đã so sánh toàn bộ tệp trong ảnh nguồn `main` với vị trí tương ứng sau tổ chức lại:

| Hạng mục | Kết quả |
|---|---|
| Tệp nguồn của `main` có mặt tại vị trí tương ứng | 1.374/1.374 |
| Tệp được chuyển sang đường dẫn mới | 957 |
| Cảnh `.tscn` khớp nguồn sau đổi đường dẫn tài nguyên và mô tả trong trình biên tập | 11/11 |
| Tệp dữ liệu được so sánh trực tiếp và giữ nguyên từng byte | 1.052 |

Nhóm dữ liệu so sánh trực tiếp gồm UID, âm thanh, ảnh, navmesh, JSON, CSV, log và văn bản dữ liệu. Mã nguồn có các thay đổi cần thiết cho đường dẫn, giao diện HUD chung, menu, bộ chạy kiểm thử và quy trình đóng gói. README tiếng Việt cùng tài liệu kiến trúc được giữ; các log, ảnh và báo cáo lịch sử không bị viết lại để làm bằng chứng mới.

Danh sách đường dẫn và checksum nguồn nằm trong [path-migration-main.json](path-migration-main.json). Snapshot ban đầu [path-migration.json](path-migration.json) được giữ để tra cứu lịch sử.

## Kiểm tra sau đồng bộ

| Kiểm tra | Kết quả |
|---|---|
| Nhập dự án vào Godot | Thành công, không có lỗi script hoặc tài nguyên |
| `tools/ci/check_scripts.gd` | 152 script biên dịch thành công |
| `tools/ci/check_layout.py` | 200 tham chiếu tài nguyên hợp lệ |
| Đối chiếu snapshot `path-migration-main.json` | Đủ 957 tệp di chuyển; dữ liệu nhị phân, UID và navmesh giữ nguyên |
| `tools/ci/check_map_contract.gd` | HUD và cửa thoát nhận dữ liệu riêng, không để sót provider khi rời bản đồ |
| `tests/test_scene.tscn` | `All tests passed`, mã thoát 0; gồm các cơ chế chung, toàn bộ phần mở rộng, lượt chơi từ đầu đến cuối và baseline |
| `tools/qa_flow.gd` | 15 kiểm tra qua, tải 4 lượt cảnh |
| `tools/map_flow.gd` | 52 kiểm tra qua, tải 12 lượt bản đồ trong 3 chu kỳ; không tăng số nút hoặc để sót hệ thống |
| Xuất gói PCK bằng preset Windows Desktop | Thành công, không có lỗi tài nguyên |
| `tools/ci/check_pack.gd` với PCK từ thư mục trống | Menu, bản đồ hướng dẫn và thư viện đều tải được; không chứa các tệp kiểm thử/công cụ được kiểm tra |

Bộ kiểm thử gameplay đầy đủ chạy từ 09:39 đến 10:05 ngày 26/10/2026, giờ Việt Nam. Không có `ERROR` hoặc `SCRIPT ERROR`. Có 8 cảnh báo từ các ca cố ý tạo guard bị kẹt, thiếu tuyến tuần tra hoặc thiếu navmesh. Ba lượt chơi thoát qua bến hàng, cửa chính và lối bí mật đều thắng; bản đồ hướng dẫn cũng thắng khi chơi lại. Kiểm tra baseline xác nhận đúng navmesh 1.244 đa giác.

Gói PCK được kiểm tra trong thư mục trống, không thể lấy bù tài nguyên từ source checkout. Lần kiểm tra này chưa xuất tệp thực thi Windows tại máy local; workflow CI có bước xuất Windows x64 sau khi kiểm thử thành công.

Các lệnh đối chiếu chính:

```text
python tools/ci/check_layout.py --verify-migration --migration-manifest docs/architecture/path-migration-main.json
godot --headless --path . --script res://tools/ci/check_scripts.gd
godot --headless --path . --script res://tools/ci/check_map_contract.gd
godot --headless --path . res://tests/test_scene.tscn
godot --headless --path . --script res://tools/qa_flow.gd
godot --headless --path . --script res://tools/map_flow.gd
```

Log lần chạy mới nằm trong `ci-logs/main-sync-*.log`, được Git bỏ qua. Kiểm tra tự động không thay thế đánh giá hình ảnh, độ khó hoặc FPS bằng người chơi trên phần cứng mục tiêu.
