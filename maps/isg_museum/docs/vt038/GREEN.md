# VT-038 — Giai đoạn 5, GREEN và diff chờ review

- Baseline: `c9bf5d63080c86b67f9581b4bc15bb515b180816`. Nhánh `bt3/23001903-vt038-idempotency`; worktree `D:/IT/SE_GAME_3D/.local/vt038/worktree`.
- Sinh viên xác nhận test RED trước giai đoạn 5. Tại thời điểm thu log GREEN, diff còn chờ review và mutation, flaky, tải chưa chạy. Trạng thái các bước sau nằm trong [README](README.md).
- [Diff production](evidence/production.diff); diff đầy đủ ở lần review giai đoạn 5 được giữ trong `.local/vt038/green-evidence/review.diff`. Đã kiểm tra `git diff --check` và `git apply --reverse --check` cho diff đầy đủ (kiểm tra, không áp dụng). Bản [test RED gốc](evidence/storage_submission_tests.red.gd) khớp SHA-256 `98c3ff7a6ca82d165b68bb27dd834eabde9fa46c121b329d74710c2c234475cf`.

## Diff cần review

- `maps/isg_museum/scripts/storage_door.gd`: điểm vào `submit_code_request(scope, request_id, code, by)` kiểm tra kiểu/schema, cửa hiện tại và player của lượt. Ledger nằm trên node cửa: ID đã nhận gắn với mã nguyên vẹn, gồm số 0 đầu. Cùng ID/mã và đã xử lý thì trả bản sao receipt trước khi xét ngày/vị trí/khóa. Khác mã là `CONFLICT`. Không log mã người chơi. Mỗi lần restart tạo node/ledger mới; không lưu qua lần khởi động. ID không bị eviction ngầm trong lượt.
- Cùng một hàm nghiệp vụ giữ ngưỡng ba lần sai, reset bộ đếm, tiếng động, báo động, mở khóa và cập nhật hợp đồng. API bool cũ vẫn dùng hàm đó. Cả mã đúng và sai **đã xử lý** đều có receipt; `alarm_triggered` lấy từ kết quả nghiệp vụ lần gốc, không suy từ lần replay. `RETRYABLE` trước tác động không có receipt terminal và vẫn giữ ràng buộc ID/mã. `IN_PROGRESS`/`BUSY` chặn gọi lồng; `BUSY` cho ID mới chưa nhận ID đó.
- `maps/isg_museum/scripts/storage_keypad.gd`: mỗi lần xác nhận hợp lệ lấy ID mới từ cửa, hiển thị sai/thông báo báo động theo receipt, thành công vẫn đóng panel. Không có tự gửi lại trong UI. Dùng chính API nội bộ để test retry. Guard main-thread là cho tương tác đồng bộ của một scene, không phải giao thức đa luồng, durable storage hay exactly-once xuyên crash/network.
- `maps/isg_museum/tests/storage_submission_tests.gd`: T02/T03 giữ oracle side effect từ RED; chỉ chuyển từ adapter pass-through sang API thật và thêm oracle receipt. Thêm kiểm chứng replay khi trạng thái đổi, conflict/validation, từ chối tạm rồi retry, reentry qua signal, qua ngày và caller sửa bản sao. T11 dùng hai instance cửa thật và đóng/mở keypad; verifier kho phụ riêng kiểm tra restart thật và trạng thái reset. Suite vẫn được đăng ký ở `tests/test_scene.gd`, dùng runner tập trung đã thêm ở RED.

## Chạy lại GREEN tập trung

Từ worktree đã import, chạy:

```powershell
& 'D:/IT/SE_GAME_3D/.local/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file 'D:/IT/SE_GAME_3D/.local/vt038/green-evidence/review-run.engine.log' --script res://maps/isg_museum/tools/run_storage_submission_tests.gd
$LASTEXITCODE
```

Lệnh thực tế, cwd, giờ bắt đầu/kết thúc và exit code: [JSON](evidence/green.json). Log: [stdout](evidence/green.stdout.log), [stderr](evidence/green.stderr.log).

| Kiểm tra | Kết quả đã quan sát |
|---|---|
| Focused GREEN | Exit `0`, `0 failures`. T03: `[wrong_attempts, door_alarms, contract_alarms, rejected, keypad_noise] = [1, 0, 0, 1, 1]`; T02: `[0, 1, 1, 3, 3]`. |
| Storage regression | Exit `0`, 34 checks, 0 failures, gồm keypad thật, báo động, mã đúng và restart. |
| Room feedback regression | Exit `0`, 30 checks, 0 failures, gồm lịch và tương thích `submit_code()` cũ. |
| Script, layout, map contract | Exit `0`: 342 scripts, 794 tham chiếu và `MAP CONTRACT PASSED`. |
| Import | Exit `0`; log có lỗi môi trường lưu editor settings ngoài workspace và đọc kho chứng chỉ. |
| Game flow, map flow | Exit `0`: 15 và 100 checks tương ứng. Map flow kiểm tra catalog hiện có, không dùng thay cho verifier riêng của bảo tàng. |

Mỗi lần chạy trên có `<tên>.json`, `.stdout.log`, `.stderr.log`; Godot `4.7.2.stable.official.ed1daf0bf`. Root certificate store báo lỗi như trước patch, kể cả ở các lệnh exit `0`. WSL trả `Wsl/EnumerateDistros/Service/E_ACCESSDENIED`; các lệnh Windows trên không được ghi thành CI Linux/WSL pass. Chưa ghi kết luận cho integrated suite đang chạy; file `green-integrated.json` chỉ được tạo khi lệnh kết thúc. Chưa chạy kiểm tra rebuild map thư viện (ngoài diff, builder ghi lại scene/navmesh tạm thời).

## Hai giả định AI đã kiểm chứng

1. **“Cùng main thread thì không thể gọi lồng.”** T09 gọi lại từ signal `rejected` thật trước khi thao tác gốc trả về. Đã quan sát `IN_PROGRESS`, `CONFLICT`, `BUSY`, legacy trả `false` và bộ đếm chỉ tăng một lần. Sau khi thoát callback, ID mới dùng được, chứng minh guard được dọn và `BUSY` không chiếm ID.
2. **“`false` không có side effect, hoặc có thể suy kết quả replay từ trạng thái hiện tại.”** T02/T03 kiểm tra receipt với giá trị cụ thể và đếm hiệu ứng độc lập. T04 phát lại lần sai thứ ba sau một yêu cầu khác: receipt vẫn có `alarm_triggered=true`, counters `0/1`, trong khi counters sống `1/1` và không có báo động/tiếng động mới. T10/T12 thay ngày qua `time_provider` và sửa response ở caller; replay giữ kết quả gốc, ID mới dùng mã ngày mới. Không lấy sự bằng nhau của hai response làm bằng chứng duy nhất.

Sinh viên sau đó chấp nhận diff trong phạm vi local đã công bố. Xem [kết quả giai đoạn 6](README.md) để biết kết quả suite tích hợp, mutation, flaky và tải.
