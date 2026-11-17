# Tài liệu ISG Museum

[Mở và chỉnh map](../README.md) · [Kiến trúc nhóm](../../../docs/architecture/MAP_LAYOUT.md)

## 1. Thiết kế

- **Bộ concept mỹ thuật dùng để đối chiếu:** [asset-design-preview-v2](design/asset-design-preview-v2/README.md). Đây là ảnh AI duyệt thiết kế; bằng chứng triển khai nằm trong các báo cáo Godot.
- **Mặt bằng tổng thể:** [concept-v2](design/concept-v2/README.md); **phòng nhân viên/kho phụ hiện hành:** [concept-v3](design/concept-v3/README.md).
- Lịch sử: [concept-v1](design/concept-v1/README.md), [asset-design-preview-v1](design/asset-design-preview-v1/README.md).
- Scene và tọa độ gameplay hiện hành được ưu tiên khi tỷ lệ concept khác sản phẩm.

## 2. Hướng dẫn

Các step là **lịch sử phát triển**, không thay thế hướng dẫn authoring hiện hành tại README map.

- [Bước 4 — Phòng thử có bảo vệ đi tuần](guides/steps/step-04-patrol.md)
- [Bước 5 — Vòng chơi có nhiệm vụ, thắng và thua](guides/steps/step-05-demo.md)
- [Bước 6 — Bảo tàng hai tầng chạy được](guides/steps/step-06-blockout.md)
- [Cập nhật sau sơ đồ 9 bảo vệ](guides/steps/step-07-empty-frame.md)
- [Bước 8 — Mang tranh lớn T2 tới kho](guides/steps/step-08-carry-t2.md)
- [Bước 9 — Chín bảo vệ theo sơ đồ mới](guides/steps/step-09-nine-guards.md)
- [Bước 10 — Sân trong có bốn lối, đường dấu cộng](guides/steps/step-10-courtyard-cross.md)
- [Bước 11 — Đài phun nước giữa sân, cửa đóng/mở](guides/steps/step-11-ring-and-doors.md)
- [Bước 12 — Một lối phòng nhân viên và cửa kho phục chế](guides/steps/step-12-staff-restoration-doors.md)
- [Bước 13 — Phòng nhân viên ca đêm và G3 ngủ/thức](guides/steps/step-13-staff-room.md)
- [Bước 14 — Áp dụng phòng nhân viên A–H](guides/steps/step-14-staff-ah.md)
- [Bước 15 — Giấy ghi chú và lịch thời gian thực](guides/steps/step-15-paper-calendar.md)
- [Bước 16 — Kho phụ khóa mã và dây tầng 1](guides/steps/step-16-aux-storage.md)
- [Bước 17 — Hợp đồng, vé tầng 2 và hiện vật theo phòng](guides/steps/step-17-contract-gameplay.md)
- [Bước 18 — Hợp đồng ngẫu nhiên, bảng tên và vé](guides/steps/step-18-contract-revision.md)
- [Bước 19 — Phòng nhân viên, kho phụ và tranh tầng 2](guides/steps/step-19-room-feedback.md)

## 3. Báo cáo

**Hiện hành:** Gardner B, guard art, NPC art và Post-B ở các liên kết dưới đây. Mỗi đợt có `REPORT.md`, `VALIDATION.json`; chỉ tạo nhóm `images/videos/logs/data/snapshots/reproduce/revisions` khi có nội dung.

- **[post-b-fixes-v1](reports/post-b-fixes-v1/REPORT.md)** — Sửa phần xây trên vòm, ngưỡng A/B/C và cửa.
- **[courtyard-palette-stage-b](reports/courtyard-palette-stage-b/REPORT.md)** — Gardner B — bảng vật liệu đã lưu trong sản phẩm.
- **[courtyard-palette-v1](reports/courtyard-palette-v1/REPORT.md)** — Gardner A1/A2 — góc thử và đối chiếu.
- **[guard-art-v1](reports/guard-art-v1/REPORT.md)** — Rig/animation của chín bảo vệ.
- **[npc-art-v1](reports/npc-art-v1/REPORT.md)** — Model/animation N0 và tiếp đón.
- **[environment-art-v1_1](reports/environment-art-v1_1/REPORT.md)** — Cây LOD, vật liệu, ánh sáng và benchmark.
- **[environment-art-v1](reports/environment-art-v1/REPORT.md)** — Art môi trường đầu tiên và attribution.
- **[visual-feedback-2026-11-15](reports/visual-feedback-2026-11-15/REPORT.md)** — Cột–vòm, foliage, cầu thang, chân tường và hướng nội thất.
- **[editing-mode](reports/editing-mode/REPORT.md)** — Scene chỉnh map không có guard.
- [Gardner A2](reports/courtyard-palette-v1/revisions/revision-a2/REPORT.md) — giữ riêng kết quả A1/A2.
- [Các iteration môi trường v1.1](reports/environment-art-v1_1/revisions/iterations/REPORT.md) — các lượt thử, không thay kết quả nghiệm thu.
- [Docs cleanup v1](reports/docs-cleanup-v1/REPORT.md) — migration, kiểm tra và điều tra teardown Post-B.

Ảnh/video, raw log, số đo và kết quả lịch sử giữ nguyên byte; một số raw log/JSON/argv vẫn ghi đường dẫn cũ. Đây là dữ liệu tại thời điểm chạy, không phải đường dẫn thực thi hiện hành.
Tra cứu đường cũ → mới và hash tại [path-migration.json](reports/docs-cleanup-v1/data/path-migration.json).
Snapshot giữ nguyên từng cụm nguồn và dependency; chỉ các resource path cần thiết được sửa, không rebuild baseline.

Kiểm tra lại an toàn từ repository root:

```text
python maps/isg_museum/tools/organize_docs.py --verify
python maps/isg_museum/tools/organize_docs.py --plan
```

Plan sau migration không đề xuất chuyển tiếp. Manifest giữ byte gốc của các file văn bản đã chỉnh để hoàn tác cùng mapping; không xóa hoặc nén bằng chứng.
