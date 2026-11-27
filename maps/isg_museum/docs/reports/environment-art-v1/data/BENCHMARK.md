# Benchmark đồ họa museum v1

GPU: **NVIDIA GeForce RTX 3050 6GB Laptop GPU**. Renderer: **gl_compatibility**. Godot 4.7.2 Stable.

Hai lượt dùng cùng máy, camera và kích thước viewport; baseline từ snapshot scene tại 99c43b3. Mỗi view làm nóng 90 frame, đo 180 frame bằng thời gian thực giữa các process frame. Scene/AI được đóng băng để so sánh render. FPS bị giới hạn quanh 144 Hz; không suy ra GPU headroom từ kết quả này.

| View | Viewport | FPS trước/sau | ms trước/sau | p95 ms sau | Draw calls trước/sau | Primitives trước/sau | MiB render trước/sau |
|---|---|---:|---:|---:|---:|---:|---:|
| 01-courtyard | 1280×720 | 144.1 / 144.0 | 6.94 / 6.94 | 7.19 | 698 / 1,192 | 40,528 / 1,480,617 | 142.0 / 437.4 |
| 02-cover | 1280×720 | 144.0 / 144.0 | 6.94 / 6.94 | 7.17 | 395 / 641 | 13,422 / 1,039,991 | 142.0 / 437.4 |
| 04-floor-2 | 1280×1280 | 144.1 / 144.0 | 6.94 / 6.94 | 7.62 | 1,116 / 1,647 | 87,470 / 1,285,880 | 147.4 / 442.8 |
| 03-floor-1 | 1280×1280 | 144.0 / 144.0 | 6.94 / 6.94 | 7.38 | 708 / 1,173 | 62,810 / 752,584 | 147.4 / 442.8 |
| 05-staff | 1280×720 | 144.0 / 144.0 | 6.94 / 6.94 | 7.28 | 437 / 593 | 12,586 / 478,786 | 142.0 / 437.4 |
| 06-broken-glass | 1280×720 | 144.0 / 144.0 | 6.94 / 6.94 | 7.20 | 224 / 269 | 53,890 / 45,728 | 168.4 / 463.8 |
| 07-map-ui | 1280×720 | 144.0 / 144.0 | 6.94 / 6.94 | 7.31 | 1,097 / 1,713 | 61,878 / 1,951,268 | 168.8 / 464.2 |
| 08-calendar-ui | 1280×720 | 144.0 / 144.0 | 6.94 / 6.94 | 7.20 | 714 / 1,168 | 69,081 / 1,525,597 | 168.8 / 464.2 |

Các view sau art giữ khoảng 144 FPS / 6,94 ms trên máy này. Chi phí hình học và bộ nhớ tăng rõ so với blockout: cột/vòm hai tầng, 16 nhịp con tiện, bốn tượng, lá và đồ nội thất có texture. Primitives bao gồm các pass của renderer, gồm bóng đổ; số tam giác mỗi model/LOD xem manifest. Bộ nhớ trên là monitor RENDER_VIDEO_MEM_USED của Godot, không phải RAM toàn tiến trình hoặc tổng VRAM driver.

Bụi 27.327→2.287 tam giác; cây chậu 176.226→10.636; tượng 114.430→28.605; cây cao 2.062.487→18.589 gần / 577 xa. Các nhịp đá được gộp tĩnh để giảm số draw so với từng module riêng; không còn MultiMesh bị mất transform khi lưu headless.

Không thấy giảm FPS trong các sample VSync-capped này, nhưng chưa có benchmark dài với AI hoạt động, GPU timing, heatmap overdraw hoặc máy yếu. Khác biệt bộ nhớ/draw/primitives là chi phí thực cần cân nhắc; không tuyên bố không có regression trên mọi phần cứng.

Dữ liệu gốc: [baseline-render-metrics.json](baseline-render-metrics.json), [render-metrics.json](render-metrics.json).