# ISG Museum v1.1 — benchmark

Ngày đo: 12/11/2026. CPU **Intel Core 5 210H**, GPU **NVIDIA GeForce RTX 3050 6GB Laptop GPU**, driver **621.14**, Windows, Godot **4.7.2-stable (official)**, **GL Compatibility**.

V1 lấy từ snapshot scene baseline `35fe3f8`; v1.1 lấy scene hiện hành. Cùng GPU/máy, viewport **1280×720**, FOV **78°**, bốn camera benchmark v1 giữ nguyên. Chạy từng process nối tiếp, không chạy import, test hay chụp ảnh đồng thời. Mỗi góc warmup **3 giây**, lấy mẫu **6 giây** theo đồng hồ thật. Benchmark đặt **VSync disabled (0)**, **Engine.max_fps=0**, low-processor mode tắt; dùng exclusive fullscreen và khôi phục thiết lập khi xong. JSON ghi mode/viewport thực tế.

**Frame interval** đo giữa hai process frame bằng `Time.get_ticks_usec()`, gồm CPU, scheduling và presentation. **GPU render time** do RenderingServer viewport timer cung cấp, ghi riêng; không gọi frame interval là GPU time. Không đo tổng RAM tiến trình. Render memory là monitor bộ nhớ render của Godot.

## Render tĩnh: AI đóng băng

| Góc | Bản | FPS TB | Interval p50 / p95 / p99 (ms) | GPU p95 (ms) | Draw p50 / p95 | Primitives p50 / p95 | Render memory peak (MiB) |
|---|---|---:|---|---:|---|---|---:|
| courtyard | v1 | 364.0 | 2.515 / 4.155 / 5.169 | 1.457 | 1,197 / 1,197 | 1,480,677 / 1,480,677 | 438.8 |
| courtyard | v1.1 | 339.8 | 2.764 / 4.200 / 4.785 | 2.144 | 1,400 / 1,400 | 2,070,593 / 2,070,593 | 468.1 |
| cover | v1 | 542.8 | 1.675 / 2.906 / 3.734 | 0.926 | 642 / 642 | 1,040,003 / 1,040,003 | 438.8 |
| cover | v1.1 | 504.9 | 1.829 / 3.040 / 3.932 | 1.297 | 832 / 832 | 1,242,773 / 1,242,773 | 468.1 |
| staff | v1 | 567.7 | 1.609 / 2.751 / 3.564 | 1.053 | 599 / 599 | 478,858 / 478,858 | 438.8 |
| staff | v1.1 | 463.1 | 1.927 / 3.497 / 4.726 | 1.199 | 952 / 952 | 1,014,240 / 1,014,240 | 468.1 |
| sculpture | v1 | 581.1 | 1.555 / 2.896 / 3.877 | 1.301 | 297 / 297 | 45,948 / 45,948 | 455.1 |
| sculpture | v1.1 | 659.2 | 1.434 / 2.313 / 3.027 | 1.318 | 299 / 299 | 45,962 / 45,962 | 472.2 |

## Gameplay thực thời gian, chín guard

Lấy mẫu **240 giây** sau warmup 3 giây, **61,365 frame**. Không dùng fixed-fps hoặc movie writer. Player chạy bằng input/physics thật theo waypoint cố định, dùng thử capsule để chọn hướng tránh vật và NPC; tự mở cửa qua tương tác. NavigationAgent của guard giữ nguyên. V và K được cấp trong fixture, chỉ kết thúc do bắt giữ được vô hiệu hóa ở instance benchmark để giữ thời lượng. Guard vẫn chạy vision, hearing, tìm kiếm, chase và body collision; G3 vẫn có state ngủ/nghỉ như production. Không sửa gameplay source.

- FPS trung bình: **255.7**.
- Frame interval p50/p95/p99: **3.562 / 6.942 / 9.075 ms**.
- GPU render p95: **2.041 ms**.
- Draw calls p50/p95: **707 / 1,665**.
- Primitives p50/p95: **824,329 / 2,192,218**.
- Render memory peak: **453.1 MiB**.
- Frame đang mang T2: **7,096**; frame có chase: **25,595**; T2 giao bằng production interaction: **True**.
- Tuyến hợp lệ: **True**. Waypoint thực đạt: `lobby → stair_a_entry → stair_a_door → stair_a_bottom → stair_a_landing_s → stair_a_landing_n → stair_a_top → stair_a_exit → upper_south_entry → south_buffer → south_portal → upper_southeast → gallery_b_approach → gallery_b → pickup_t2 → carry_wall_north → carry_room_west → carry_room_exit → carry_corridor → carry_southeast → carry_south → carry_buffer → depot_approach → warehouse_entry → depot → warehouse_exit → return_buffer → return_south → return_southeast → upper_north_ring → gallery_c_approach → gallery_c → north_room_east → stair_b_approach → stair_b_entry → stair_b_top → stair_b_landing_n → stair_b_landing_s → stair_b_bottom → history_approach → history_entry → history_east → history_south → history → history_south_portal → courtyard_approach → courtyard → ring_east → ring_south → ring_west → ring_north → yard_exit → ground_northeast → staff_approach → staff_entry → staff → staff_exit → ground_east → south_ring → lobby_approach`.

Vị trí/thời điểm từng waypoint và trạng thái cả chín guard cuối lượt nằm trong [after-gameplay.json](after-gameplay.json); CSV giữ frame interval, draw, primitives, memory, GPU timing, số guard đang chase và cờ mang tranh ở từng frame.

## Cách chạy và giới hạn

```text
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --before --exclusive
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --exclusive
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://maps/isg_museum/tools/benchmark_environment_art.gd -- --gameplay --seconds=240 --exclusive
```

Raw: [v1 render](before-render.json), [v1.1 render](after-render.json), [gameplay](after-gameplay.json), và ba CSV cùng tên. Lượt smoke 65 giây và lượt 240 giây với tuyến autopilot chưa đúng được giữ trong `iterations/`, không dùng làm benchmark nghiệm thu. Sau đó course-check headless fixed-fps xác nhận toàn tuyến trước khi chạy native lại. Video LOD và course-check không dùng để suy ra hiệu năng.

Thiết lập được khôi phục ở cả ba lượt: **True**. Chưa đo máy cấu hình thấp, heatmap overdraw, nhiệt độ/xung GPU hoặc RAM toàn tiến trình. Một cặp đo ngắn không xác định được mức tăng chất lượng còn an toàn trên mọi máy. Nếu FPS vẫn tạo plateau dù tool đã bỏ cap, chỉ dùng các khoảng thời gian và GPU timing trong phạm vi phép đo này; không coi đó là bằng chứng dư địa FPS.

Chi phí tán mới gồm alpha-scissor atlas và ba card cong mỗi cụm; far giữ tán nhưng giảm cành/gốc rõ hơn khi ép xem sát. Hàng bụi thêm lá hình học, stone dùng normal/roughness nguồn dùng chung. Cần đọc mức tăng draw/primitives/memory cùng frame interval; không kết luận tối ưu chỉ từ ngân sách cây hoặc texture 2K.

## Tách nguyên nhân phần tăng chi phí

Đo bổ sung cùng camera, warmup, thời lượng và thiết lập uncapped; chỉ đổi từng thành phần trên instance tạm, không lưu scene. `no-new-foliage` ẩn hai cây và lớp lá hedge mới, giữ các shrub nguồn; `v1-sun` chỉ trả hướng directional về v1, vẫn giữ toàn bộ art/material v1.1; `no-fill` tắt hẳn bốn Omni sân.

| Variant | Góc | Draw p50 | Primitives p50 | GPU p95 (ms) |
|---|---|---:|---:|---:|
| no-new-foliage | courtyard | 1,364 | 1,673,777 | 1.714 |
| no-new-foliage | staff | 950 | 998,696 | 1.187 |
| v1-sun | courtyard | 1,256 | 1,731,049 | 2.033 |
| v1-sun | staff | 599 | 478,858 | 1.052 |
| no-fill | courtyard | 1,400 | 2,070,593 | 2.163 |
| no-fill | staff | 952 | 1,014,240 | 1.195 |

Ở **staff**, chỉ trả hướng nắng về v1 đưa counter từ **952 / 1.014.240** về đúng **599 / 478.858** của baseline. Ẩn cây và hedge mới chỉ giảm còn **950 / 998.696**. Vì camera và mesh không đổi trong phép thử hướng nắng, phần tăng chủ yếu ở góc này là **shadow pass theo hướng directional mới**, không phải do tăng số cây hoặc Omni. GPU p95 ở staff tăng khoảng **0,146 ms** so với v1; frame interval p95 tăng khoảng **0,746 ms** trong cặp chính. Giữ hướng nắng mới để có chuyển sắc đã chụp, công khai chi phí này thay vì tuyên bố tối ưu.

Ở **courtyard**, ẩn cây/hedge mới giảm primitives **2.070.593 → 1.673.777** và GPU p95 **2,144 → 1,714 ms**. Trả riêng hướng nắng v1 giảm còn **1.731.049** primitives. Hai tác động có tương tác shadow/culling, không cộng các mức giảm thành tổng chi phí. Tắt Omni không giảm counter hoặc GPU timing đáng kể trong các lượt này.

So với v1, góc sân tăng draw khoảng **17%**, primitives khoảng **40%**, FPS trung bình giảm khoảng **6,7%**. Đây là chi phí chất lượng thật. Lượt gameplay cuối đạt p95/p99 dưới 10 ms trên máy đo, nhưng không chứng minh mức tăng chất lượng còn an toàn trên mọi GPU.

Các file `after-render-<variant>.json`, CSV và log cùng tên giữ số gốc. Diagnostic `v1-sun` tải thêm snapshot để đọc transform, nên **không dùng memory peak của nó** so sánh bộ nhớ runtime. Lượt diagnostic này có hai cảnh báo texture GLES lúc thoát (349.524 byte mỗi texture); các số hiệu năng chính lấy từ các process render/gameplay riêng, không lấy lượt diagnostic làm gameplay.
