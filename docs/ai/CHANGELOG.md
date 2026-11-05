# Changelog cho AI Agent

Ghi các thay đổi đã xác minh, không dùng file này thay cho release notes. Dùng ngày ISO `YYYY-MM-DD`; liệt kê file/module bị ảnh hưởng, test đã chạy và test chưa chạy. Với thay đổi source, cập nhật registry/architecture/flow/testing trước hoặc cùng entry changelog.

## 2026-11-04 — Khởi tạo bộ tài liệu ngữ cảnh AI

- **Nội dung:** Tạo chỉ dẫn agent và tài liệu project context, architecture, module index, data flow, feature registry, testing guide và ADR index dựa trên cấu trúc/source/catalog/test hiện tại.
- **File thêm:** `AGENTS.md`, `docs/ai/PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `MODULE_INDEX.md`, `DATA_FLOW.md`, `FEATURE_REGISTRY.md`, `TESTING_GUIDE.md`, `CHANGELOG.md`, `decisions/README.md`.
- **Module liên quan:** Không đổi source runtime; chỉ ghi nhận shared/features/maps/tests/tools.
- **Kiến/API:** Gameplay, architecture, API không đổi.
- **Kiểm tra:** `git status`/tree/source review. Godot import, test runner, QA flow, map flow và CI scripts **chưa chạy**; Godot executable không có trong PATH.
- **Kết quả/giới hạn:** README gốc chưa liệt kê K17; `maps/museum/README.md` vẫn ghi Museum chưa có scene/catalog, trái với scene/catalog/flow tool hiện tại. Mô tả Museum graybox trong README gốc phù hợp với source. Changelog này ghi nhận độ lệch; source/catalog/flow tools được dùng làm căn cứ. Các chi tiết chưa xác minh runtime không được tuyên bố là đã test trong phiên này.
