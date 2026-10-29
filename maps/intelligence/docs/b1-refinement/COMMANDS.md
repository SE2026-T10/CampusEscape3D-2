# Lặp kiểm tra K17 V6 B1

Chạy từ thư mục gốc repo, `godot` trỏ tới Godot 4.7.2 official. Những lệnh dựng/bake thay scene nên thực hiện tuần tự, không chạy builder trong lúc editor đang bake/lưu.

## Chức năng và hình học

```text
godot --headless --path . --script res://tools/ci/check_scripts.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_k17.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_projection.gd
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/check_b1.gd
godot --headless --path . --script res://maps/intelligence/tools/check_art.gd
godot --headless --path . --script res://maps/intelligence/tools/check_attachments.gd
godot --headless --path . --script res://tools/ci/check_map_contract.gd
```

## Đi nhiệm vụ bằng input thật

Không lính, cả hai đường rút, phá hoại, cửa hậu chưa chuẩn bị:

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --crouch --camera-off --sprint-exfil --sabotage
```

AI bảo trì, mặc định dùng cuộc gọi giả ở B1:

```text
godot --headless --path . --fixed-fps 60 --max-fps 600 --script res://maps/intelligence/tools/playthrough_k17.gd -- --route=maintenance --live-guards --prepare --camera-off --utilities-north --radio --wait-radio --watch-patrol --crouch --sprint-exfil
```

Các lượt trong báo cáo dùng cùng lệnh AI với các thay đổi sau:

| Lượt | Thay đổi cờ |
| --- | --- |
| Sân, nhịp chốt tự nhiên | `--route=courtyard --natural-post`, bỏ `--route=maintenance` |
| B1 pha +9 giây, phá hoại | Thêm `--projection-delay=9 --sabotage` |
| B1 pha +4 giây, chưa chuẩn bị cửa hậu | Bỏ `--prepare`, thêm `--projection-delay=4` |

Driver chọn chờ dựa vào vị trí thật của lính, không đổi AI. `--sprint-exfil` đi bộ nhẹ dưới B1 rồi chạy trên mặt đất. Với renderer, có thể thêm `--out=res://maps/intelligence/docs/b1-refinement/walking-local` để lưu mốc ảnh và `--background` để trình QA tiếp tục sau mất focus. Thao tác bị hủy do pause được làm lại bằng input; không sửa cơ chế pause của game thường.

## Renderer, dựng và ánh sáng

```text
godot --path . --fixed-fps 60 --max-fps 240 --script res://maps/intelligence/tools/preview_b1.gd
godot --path . --script res://maps/intelligence/tools/benchmark_b1.gd
```

Preview dùng vị trí dàn sẵn để chụp và đo HUD. Benchmark không dùng `--headless` hoặc `--fixed-fps`; tránh chạy cùng QA khác. Hai alias `preview_projection.gd`/`benchmark_projection.gd` gọi bản B1 mới. Các file JSON/ảnh được ghi trong thư mục báo cáo này.

Khi thay hình học, sửa nguồn builder/cấu hình rồi chạy:

```text
godot --headless --path . --script res://maps/intelligence/tools/build_k17.gd
```

Kiểm tra exit code trước khi tiếp tục. Builder cập nhật scene, navigation, minimap; còn ánh sáng cần bake bằng editor Mobile/Forward+. Chạy `maps/intelligence/tools/bake_v6_lightmaps.gd` dưới dạng EditorScript, xác nhận `K17 V6 BAKE SAVED`, rồi chơi bằng Compatibility theo cấu hình dự án. Không để việc kích hoạt helper bake thay đổi cấu hình chạy đã lưu của nhóm.

## Bản đóng gói

```text
godot --headless --path . --export-pack "Windows Desktop" ci-logs/k17-b1/game.pck
```

Tạo thư mục đầu ra trước; cần export template đúng phiên bản. Copy `maps/intelligence/tools/check_pack.gd` ra ngoài repo, chạy Godot từ một thư mục rỗng với `--main-pack <đường dẫn tuyệt đối game.pck> --script <bản copy checker>`. Checker chỉ dùng tài nguyên runtime, xác nhận cả hai chế độ và loại tài liệu/tools/tests khỏi gói.

Lượt PCK đi bộ trong báo cáo dùng bản copy ngoài repo của `playthrough_k17.gd`, đổi preload `tests/test_utils.gd` thành đường dẫn helper ngoài gói và tắt VSync ở driver. Game vẫn chỉ nạp nguồn từ PCK. Cờ giống lượt AI +9 giây/phá hoại, thêm `--background` và đường dẫn tuyệt đối `--out=...`; fixed-fps 60, max-fps 240. Log và ảnh được lưu trong báo cáo, không cần đưa PCK vào Git.
