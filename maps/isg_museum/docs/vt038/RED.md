# VT-038 — Giai đoạn 4, bản ghi RED tại thời điểm chạy

Ngày 13/11/2026. Baseline `c9bf5d63080c86b67f9581b4bc15bb515b180816`, nhánh cá nhân `bt3/23001903-vt038-idempotency`, worktree `D:/IT/SE_GAME_3D/.local/vt038/worktree`. Nhánh gốc `hgmanh-work` giữ nguyên. Chưa commit/push, chưa sửa production. Sinh viên duyệt kế hoạch để bắt đầu giai đoạn 4, chưa xác nhận RED.

## Chạy lại T02/T03

Để tái hiện, dùng checkout baseline và hai file test/runner RED theo [README](README.md), sau khi import bằng Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
& 'D:/IT/SE_GAME_3D/.local/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file 'D:/IT/SE_GAME_3D/.local/vt038/red-evidence/red-review.engine.log' --script res://maps/isg_museum/tools/run_storage_submission_tests.gd
$LASTEXITCODE
```

Lệnh thực tế và exit code: [JSON](evidence/red.json). [stdout](evidence/red.stdout.log) ghi từng lần giao; [stderr](evidence/red.stderr.log) ghi assertion fail. Exit **1**, đúng một failure. Lần chạy đầu (trong hồ sơ `.local`) cũng cho cùng assertion; lần xác nhận dùng `--log-file` trong workspace để loại lỗi ghi log mặc định. Cả hai vẫn ghi lỗi đọc kho chứng chỉ Windows; test không gọi mạng.

## Expected / actual

Thứ tự: `[wrong_attempts, door_alarms, contract_alarms, rejected, keypad_noise]`.

| Kiểm tra | Expected | Actual | Kết quả |
|---|---|---|---|
| T02 — ba ID khác nhau | `[0, 1, 1, 3, 3]` | `[0, 1, 1, 3, 3]` | PASS đối chứng |
| T03 — lần gửi đầu | `accepted=false`, `[1, 0, 0, 1, 1]` | `accepted=false`, `[1, 0, 0, 1, 1]` | Điều kiện kiểm chứng đạt |
| T03 — sau ba lượt giao cùng ID/payload | `[1, 0, 0, 1, 1]` | `[0, 1, 1, 3, 3]` | RED |

`maps/isg_museum/tests/storage_submission_tests.gd:13` đặt dữ liệu/kỳ vọng, `:81–82` so sánh và báo sai khác. Fixture tạo scene bảo tàng thật cho từng ca, vô hiệu guards bằng chế độ authoring sẵn có, cố định lịch qua `time_provider`, đặt người chơi gần cửa và đếm `rejected` cùng `NoiseSystem.noise_emitted` của keypad. Kiểm tra lần đầu dùng cả `false` lẫn bộ đếm để phân biệt mã sai **đã được xử lý** với từ chối trước tác động.

Adapter test tại `:90–93` chuyển cả ba lần giao một envelope tới `submit_code()` thật. Chữ ký legacy chỉ nhận mã và actor, không có request ID. Adapter không tạo báo động, không giả lập kết quả và không sửa trạng thái. Chính mã production tại `maps/isg_museum/scripts/storage_door.gd:48–63` tăng số lần sai trên mỗi lời gọi, rồi reset bộ đếm và phát báo động ở ngưỡng ba. Evidence xác nhận hành vi khi giả lập gửi lại **ở ranh giới test**; chưa chứng minh UI hiện tại có thể tự gửi lại cùng một yêu cầu. Receipt có cấu trúc chưa tồn tại, nên RED này kiểm tra tác động nghiệp vụ chứ không tuyên bố đã test contract receipt.

## Baseline và phạm vi kiểm tra

- Baseline sạch khi tạo worktree; import lần đầu `Godot --headless --path . --editor --quit` exit `0`, xem `baseline-import.*`. Log có cảnh báo chuyển đổi vật liệu, lỗi kho chứng chỉ và lỗi lưu editor settings ngoài workspace. Không diễn giải thành CI sạch.
- Verifier kho phụ nguyên bản, trên production chưa thay đổi: `verify_storage.gd` exit `0`, **34 checks, 0 failures** ([stdout](evidence/red-storage.stdout.log), [stderr](evidence/red-storage.stderr.log), [lệnh](evidence/red-storage.json)). Tệp verifier và production khớp baseline; lệnh chạy sau khi tạo test mới nhưng verifier không gọi suite mới. Lỗi kho chứng chỉ và đường dẫn log `user://` vẫn được lưu.
- Import sau thêm test exit `0`, sinh hai `.gd.uid`; layout exit `0` (794 tham chiếu); compile check exit `0` (342 scripts). Log: `test-import.*`, `test-layout.*`, `test-scripts.*`. Compile check cũng ghi lỗi kho chứng chỉ.
- Tại lúc dừng giai đoạn 4, chưa có GREEN hay xác nhận RED. Sinh viên xác nhận test ở tin nhắn tiếp theo; xem [AI Usage Log](AI-Usage-Log.md) và [kết quả giai đoạn 6](README.md).
