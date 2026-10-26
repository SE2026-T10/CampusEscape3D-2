# Kiểm tra sau khi tổ chức lại theo map

Ngày chạy: 25/10/2026. Nền tảng: Windows, Godot `4.7.2.stable.official.ed1daf0bf`. Thay đổi dựa trên commit `3e11644`, được lưu trên branch `twp`. Mã runtime được kiểm tra thuộc commit `5b50fa6`.

| Kiểm tra | Kết quả |
|---|---|
| Import project sau khi chuyển đường dẫn | Thành công, không có lỗi script hoặc tài nguyên |
| `tools/ci/check_scripts.gd` | 140 script biên dịch thành công |
| `python tools/ci/check_layout.py` | 197 tham chiếu tài nguyên runtime hợp lệ |
| `python tools/ci/check_layout.py --verify-migration` | Đủ 933 file đã di chuyển; checksum của UID, navmesh, tài nguyên nhị phân và dữ liệu lịch sử được giữ nguyên |
| `tools/ci/check_map_contract.gd` | HUD và thông báo cửa thoát nhận dữ liệu riêng từ provider mẫu; không giữ provider sau khi rời map |
| `tests/test_scene.tscn` | Thoát với mã 0, `All tests passed`; bao gồm AI, tương tác, nhiệm vụ, puzzle, security, checkpoint, HUD, lượt chơi từ đầu đến cuối và baseline |
| `tools/qa_flow.gd` | 15 kiểm tra qua, tải 4 lượt scene |
| `tools/map_flow.gd` | 52 kiểm tra qua, tải 12 lượt map trong 3 chu kỳ; không còn node hệ thống map khi về menu |
| Export PCK bằng preset Windows Desktop | Thành công; 257 mục tài nguyên |
| `tools/ci/check_pack.gd` chạy với PCK từ thư mục trống | Tải được menu, tutorial và thư viện; các file kiểm thử/công cụ được kiểm tra không có trong gói |

Bộ kiểm thử gameplay đầy đủ kết thúc lúc 15:36 (giờ Việt Nam), không có `ERROR` hoặc `SCRIPT ERROR`. Có 8 cảnh báo từ các fixture kiểm tra guard bị kẹt, thiếu patrol route hoặc không có navmesh; đó là các tình huống mà suite chủ động kiểm tra. Ba lượt chơi tự động thoát qua bến hàng, cửa chính và đường hầm đều thắng; tutorial cũng thắng khi chơi lại. Các bước CI chạy lại độc lập trên branch `twp`.

Kiểm tra PCK dùng `--main-pack` trong thư mục trống để tài nguyên thiếu không được lấy bù từ source checkout. Script kiểm tra giải phóng từng scene trước khi thoát. Đây là kiểm tra tải tài nguyên và vòng đời scene; chưa phải đánh giá hình ảnh hoặc FPS khi chơi thực tế.

Chưa xuất executable Windows tại máy local vì chưa cài export template. Workflow GitHub Actions có bước xuất Windows x64 sau khi bộ test qua; kết quả CI được xem riêng trên GitHub. Các map `bank`, `museum`, `intelligence` hiện là khung thư mục, chưa phải map chơi được.

Log local nằm trong `ci-logs/` (đã được Git bỏ qua). Không sử dụng log hay ảnh phase cũ làm bằng chứng cho lần kiểm tra này. Xem [hướng dẫn cấu trúc và lệnh kiểm tra](MAP_LAYOUT.md).
