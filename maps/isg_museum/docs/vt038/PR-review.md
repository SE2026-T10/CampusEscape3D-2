# Xuất bản nhánh cá nhân và nội dung PR tham khảo VT-038

## Nhánh và baseline

| Mục | Giá trị đã kiểm tra ngày 13/11/2026 |
| --- | --- |
| Remote `origin` | `https://github.com/SE2026-T10/CampusEscape3D-2.git` |
| Baseline và HEAD cục bộ khi soạn nháp | `c9bf5d63080c86b67f9581b4bc15bb515b180816` |
| Nhánh nguồn | [bt3/23001903-vt038-idempotency](https://github.com/SE2026-T10/CampusEscape3D-2/tree/bt3/23001903-vt038-idempotency) |
| Nhánh đích đề xuất | `hgmanh-work`, tại đúng baseline nêu trên trên `origin` |
| `main` trên `origin` | `5f54f65ff65784b74d1742ff7aa41180592f1e22` |
| Quyết định xuất bản | Sinh viên cho phép commit/push đúng 105 file lên nhánh cá nhân. Không tạo PR hoặc merge trong bước này. |

Lệnh đọc ref đã trả về mã thoát `0`:

```powershell
git ls-remote --symref origin HEAD refs/heads/hgmanh-work refs/heads/bt3/23001903-vt038-idempotency refs/heads/main
```

`HEAD` mặc định của remote trỏ đến `main`. Lịch sử từ `main` đến baseline có 26 commit sẵn có (`git rev-list --left-right --count refs/remotes/origin/main...HEAD` trả về `0 26`). Dùng `hgmanh-work` làm base để phạm vi PR bắt đầu tại baseline của bài.

## Các commit đóng gói

1. `feat(isg_museum): deduplicate storage door keypad submissions`
   - Commit: [a61014093896bb78da42941d04c50e0ed0525479](https://github.com/SE2026-T10/CampusEscape3D-2/commit/a61014093896bb78da42941d04c50e0ed0525479).
   - `maps/isg_museum/scripts/storage_door.gd`
   - `maps/isg_museum/scripts/storage_keypad.gd`
   - `tests/test_scene.gd`
   - `maps/isg_museum/tests/storage_submission_tests.gd`
   - `maps/isg_museum/tests/storage_submission_tests.gd.uid`
   - `maps/isg_museum/tools/benchmark_storage_submission.gd`
   - `maps/isg_museum/tools/benchmark_storage_submission.gd.uid`
   - `maps/isg_museum/tools/run_storage_submission_tests.gd`
   - `maps/isg_museum/tools/run_storage_submission_tests.gd.uid`
2. `docs(isg_museum): record VT-038 verification and report source`
   - Tài liệu, evidence và source báo cáo theo [danh sách từng đường dẫn](COMMIT-MANIFEST.md).
3. `fix(docs): keep published branch link readable in PDF`
   - Dùng tên nhánh làm nhãn link ở trang đầu; đích HTTPS vẫn trỏ tới nhánh thật. Không đổi code, test, raw evidence hoặc số trang báo cáo.

Trình tự test-first được ghi bằng baseline, snapshot/hash test và log [RED](RED.md), sau đó là diff và log [GREEN](GREEN.md). Các commit đóng gói trạng thái sau kiểm chứng theo phạm vi đã duyệt; không dựng lại lịch sử. SHA chứa đầy đủ evidence được lấy từ nhánh trên remote khi xuất PDF cuối, tránh ghi SHA tự tham chiếu của commit tài liệu vào chính nó.

## Nội dung PR dự kiến

**Tiêu đề**

`[VT-038] Chống xử lý lặp lượt nhập mã cửa kho phụ ISG Museum`

**Thay đổi**

- Bổ sung yêu cầu nhập mã có khóa tại `StorageDoor`, lưu kết quả theo instance cửa và cho `StorageKeypad` gửi yêu cầu qua API mới. Retry cùng khóa và payload nhận lại kết quả đã lưu, giữ nguyên số lần xử lý side effect.
- Đăng ký suite VT-038 vào runner hiện có, thêm runner riêng và harness tải. [Traceability](traceability.md) liên kết tiêu chí, test và kết quả.

**Kiểm chứng**

- RED ghi nhận xử lý lặp qua API legacy trên baseline. GREEN kiểm tra contract qua API keyed và regression ở cửa kho phụ.
- Mutant `wrong_attempts_after ← alarm_count` bị assertion receipt đầu tiên bắt trong T02, T03 và T04. Mapping về `wrong_attempts` đã được khôi phục. [Diff mutation](evidence/mutation.diff), [log mutant](evidence/mutation-field.stderr.log), [hash sau khôi phục](evidence/restored-sha256.txt).
- Chưa quan sát lỗi flaky trong 15 lượt dùng ngày giả, thay thứ tự scenario độc lập và dùng fixture mới. [Flaky evidence](evidence/FLAKY.md).
- Harness nội bộ có peak 100 in-flight, dispatch 10/frame, 50 yêu cầu mới và 50 retry mỗi lô. p95 gồm thời gian chờ là 0,150024 giây trên 1.000 mẫu. [Load evidence](evidence/LOAD.md).
- Full integrated suite Windows với `APPDATA` riêng exit `0`, runner in `All tests passed`. `stderr` có chẩn đoán kho chứng chỉ Windows và cảnh báo guard/navigation. CI Linux/WSL chưa chạy. [Lệnh và log](README.md).

**Phạm vi**

Một người chơi local, ledger theo instance cửa/lượt chơi, xử lý trên main thread. Thử nghiệm tải chỉ đo harness in-process. Bảo đảm qua crash, restart và network nằm ngoài phạm vi triển khai.

## Ghi chú duyệt báo cáo

- **Đã duyệt phạm vi.** Sinh viên yêu cầu sửa cỡ mục 6 rồi chốt nội dung và đồng ý commit/push nhánh cá nhân. Tiêu đề mục 5 và 6 cùng font đậm 21 pt; reflection 322 từ. Không ghi nhận sinh viên đã tự chạy lại test hoặc tự giải thích code nếu chưa được xác nhận.
- **Giữ nguyên evidence.** Raw log và snapshot RED không thay đổi. Một số log giữ đường dẫn và tên tài khoản Windows như đã thông báo trước khi xuất bản.
- **PDF cuối.** Trang đầu dùng link nhánh thật. Cột Commit/PR và evidence dùng SHA đã xác minh trên remote. [Cách dựng PDF](README.md#dựng-pdf-bản-nháp). Đề chấp nhận link branch hoặc PR nên chưa cần mở PR; không merge.
