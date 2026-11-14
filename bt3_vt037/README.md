# VT-037 – Undo cho hành động có rủi ro mất dữ liệu (Campus Escape 3D)
Harness độc lập (Python 3.12, stdlib) mô phỏng hành động drop inventory; không phải code Godot của game.
Branch: bt3/23001879-vt037-undo

## Chạy test
    PYTHONPATH=src python3 -m unittest discover -s tests -v
## Mutation (nuốt exception, trả dữ liệu mặc định) — chạy trên bản sao tạm
    python3 tools/mutate.py                              # v1+v2
    python3 tools/mutate.py test_undo_contract_v1.py     # chỉ v1
## Coverage dòng (stdlib trace; không có branch coverage)
    PYTHONPATH=src python3 tools/line_cov.py
## Flaky probe / Tải 200 tác vụ (độ trễ giả lập)
    python3 tools/flaky_check.py
    PYTHONPATH=src python3 tools/load_test.py
Evidence trong evidence/. Lịch sử commit thể hiện: baseline -> test v1 (fail) -> patch (pass) -> mutation -> test v2.
