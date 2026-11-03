# Lệnh nghiệm thu V6

Chạy từ gốc repo bằng Godot 4.7.2. Trong các dòng dưới, `godot` đại diện cho binary console tương ứng.

```text
godot --headless --fixed-fps 60 --path . --script tools/ci/check_scripts.gd
godot --headless --fixed-fps 60 --path . --script tools/ci/check_map_contract.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_k17.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_projection.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_art.gd
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/check_attachments.gd
```

## Đi bộ với AI

```text
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/playthrough_k17.gd -- --route=maintenance --live-guards --prepare --camera-off --utilities-north --radio --wait-radio --watch-patrol --crouch --sprint-exfil --background --projection-delay=0
```

Lặp lại với `--projection-delay=4` và `--projection-delay=9`. Trì hoãn nằm tại hốc B1, không phải lúc chờ tuần tra tầng trệt. Log có vị trí lính lúc bắt đầu từng pha để kiểm tra sự khác nhau.

- Hướng sân: thay `--route=maintenance` bằng `--route=courtyard` và thêm `--yard-flank`.
- Phá hoại: giữ hướng bảo trì, thêm `--sabotage`.
- `--background` chỉ dùng cho driver QA: cửa sổ không giành focus và bus âm thanh được tắt trong tiến trình test; không đổi thiết lập lưu của người dùng.

## Bản không lính, hai đường rút, không chuẩn bị chốt

```text
godot --headless --fixed-fps 60 --path . --script maps/intelligence/tools/playthrough_k17.gd -- --sabotage --camera-off --sprint-exfil --background
```

## Renderer và gói runtime

```text
godot --path . --script maps/intelligence/tools/preview_projection.gd
godot --path . --script maps/intelligence/tools/benchmark_projection.gd
godot --headless --path . --export-pack "Windows Desktop" ci-logs/k17-v6/game.pck
```

`check_pack.gd` được sao chép ra ngoài checkout, rồi chạy với `--main-pack` từ thư mục riêng. Driver đi bộ PCK cũng nằm ngoài gói, dùng helper QA ngoài gói thay cho `res://tests/test_utils.gd`; phần game chỉ đọc tài nguyên đã xuất. Lượt cuối dùng Compatibility, fixed-fps 60, VSync tắt, cùng các cờ AI/bảo trì/phá hoại ở trên và `--out` trỏ tới `walking-packed/` để lưu ảnh.

Các fixture hình học và ảnh dàn cảnh không được tính vào kết quả E2E đi bộ. Log có tiền tố `walking-` ghi các lượt bằng input thật.
