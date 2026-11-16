# ISG Museum — Guard art v1, 16/11/2026

Đã tích hợp model bảo vệ Jose Manuel vào G1–G9 bằng skin thực, một Skeleton3D 65 xương/actor, bảy clip Mixamo và clip ngủ dẫn xuất. Model khối cũ đã được bỏ khỏi actor museum, không giữ ẩn. Shared guard, AI, navigation, perception, collider, nhiệm vụ, N0 và tiếp đón giữ nguyên. `museum_editing.tscn` vẫn loại toàn bộ actor cùng visual trước khi vào cây.

## Rig, skin và tái tạo

Nguồn GLB không có skeleton/skin. Đã kiểm tra trực tiếp mesh và transform cha: [log](source-inspection.log), [ảnh nguồn](source-model.png). Nguồn nhìn +Z, A-pose. Công cụ Godot offline `prepare_guard_assets.gd` chuẩn hóa đồng đều theo chiều cao 1,78 m, căn chân, đo landmark vai/khuỷu/cổ tay/hông/gối/cổ chân, dựng skeleton có cùng hierarchy/global axes với Mixamo. A-pose được chuyển sang T-rest bằng biến đổi bind tương ứng; mỗi vertex nhận tối đa ba influence chuẩn hóa, padding thành bốn. Skin lưu inverse global-rest bind và mesh lưu ARRAY_BONES/ARRAY_WEIGHTS. Vật liệu, topology và phụ kiện gốc được giữ. Runtime không có X Bot hoặc skeleton riêng cho từng clip.

Đã kiểm tra biến dạng qua idle/walk/run/look/sit/stand và G3 thật. Phát hiện áo/quần có thể bị cẳng tay gần eo hút trọng số trong A-pose; đã giới hạn influence theo garment, thêm assertion chống tái phát. Surface Object_2 là hai đoạn đường nhỏ, không phải triangle mesh: giữ đúng primitive nguồn. Kết quả **4.776 tam giác + 2 line segments, 9 mesh, 8 vật liệu**, không cộng nhầm line indices thành tam giác.

Đầu ra rig là scene Godot có ArrayMesh/Skin: [guard_rig.tscn](../../assets/models/characters/low_poly_security_guard/derived/guard_rig.tscn). Không cần Blender hoặc thao tác rigging ngoài môi trường này. [README rig](../../assets/models/characters/low_poly_security_guard/derived/README.md) ghi cách dựng lại. Model nguồn và source.json không đổi; ghi công **“Low poly security guard” by Jose Manuel — CC BY 4.0** và Adobe Mixamo terms được giữ tại derived README, catalog và manifest.

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/isg_museum/tools/prepare_guard_assets.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_guard_assets.gd -- --check
```

`--check` không ghi lại resource: [hash check](check-readonly.json). Authoring tạo rig, animation library, visual và actor scene map-local. Nó không ghi đè museum scene đã bố trí. Các lần rebuild sử dụng landmark/binding/clip source cố định; resource ID văn bản có thể khác nhưng hierarchy, mesh arrays và clip data tương đương. Không có runtime dependency tới `.local/`.

## Clip và controller

Chọn take `mixamo_com`, không dùng Take 001 làm tham chiếu. Retarget dùng correction quaternion giữa local rest nguồn/đích, kiểm tra parent hierarchy, giữ target rest translations và điều chỉnh positional delta. Bone names cùng nhau không được coi là đủ. Quy tắc Bone Rest/pose được đối chiếu với [tài liệu Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html).

| Clip | Loop | Xử lý |
|---|---|---|
| idle | Có | Đứng, nhịp thở |
| walk / run | Có | XZ hông cố định; giữ Y/khớp; key cuối nối key đầu |
| look_around | Có | Điều tra đứng yên, G6 inspection, chase dừng |
| sitting_idle | Có | Tư thế tỉnh trên ghế |
| sleep | Có | Dẫn xuất sitting_idle, gục đầu 0,30 rad/thân 0,10 rad và nhịp nhẹ |
| sit_down / stand_up | Không | Giữ chiều cao hông, loại translation ngang để giữ anchor ghế |
| RESET | Không | Target local rest đầy đủ |

[Manifest](../../resources/guard_animation_manifest.json) ghi source hash/take, thời lượng, loop, travel và tốc độ tham chiếu. Walk/run được đo lại trên FK skeleton đích ở 120 Hz bằng median vận tốc chân trong pha stance thấp: khoảng **1,464 / 4,598 m/s**. Playback theo vận tốc actor thật, clamp 0,5–1,8. Không khởi động lại cùng clip mỗi frame. AnimationPlayer thực hiện crossfade 0,18–0,20 s; AnimationTree là graph authoring bất hoạt, tránh hai mixer cùng ghi pose.

`museum_guard_presentation.gd` tái sử dụng helper bước chân theo quãng đường, chìa khóa, radio, captions và icon của shared controller; không gọi phần khởi tạo animation procedural Model/Hips. Mỗi actor chỉ có một controller, không có audio event trong clip để phát trùng. Skeleton/playback độc lập, mesh/material/clip resources dùng chung.

G3 dùng `staff_presentation.gd` kế thừa controller mới. Thân ngồi giữ yaw ghế gốc kể cả khi AI quay cảm biến quan sát. Hips lúc ngủ khoảng Y0,485, cổ chân khoảng Y0,076 tương đối actor; ghế vẫn `(34.1,0,12)`, yaw -90° đã sửa trước đó. Model source +Z được sửa bằng VisualPivot 180°, không xoay actor gameplay. Di chuyển/chase ngắt transition ngay, không chờ stand_up 2,27 s. Clip đứng dậy đầy đủ chỉ có ở lượt QA đứng yên; trong gameplay bắt đầu bước là blend sang locomotion. Sit_down chỉ bắt đầu khi phase settling đã đưa actor về ghế và dừng. Không có animation_finished callback ghi AI hoặc kéo actor về ngủ.

## Bằng chứng trực tiếp từ Godot

Ảnh/video GL Compatibility, 1280×720, camera QA riêng; không dùng AI image. Đã xem ảnh và các frame chuyển động trích từ AVI. Video khóa 30 FPS phục vụ duyệt hình, **không** dùng để kết luận hiệu năng.

- [Guard/G3: video cuối](guard-final.avi): chu trình G3 thật và gallery các clip riêng. [G3 phases](g3-phases.json) ghi ngủ → quan sát → tìm kiếm → chase → tìm kiếm → trở về → settling → ngủ. Log phase lấy tại ranh giới frame nên trường animation có thể trễ một frame so với phase. Fixture đặt player để tạo sighting thật, gọi sự kiện nghe, tắt riêng terminal caught overlay; AI/cảm biến/di chuyển vẫn chạy. Không lưu fixture vào scene sản phẩm.
- [Hai thang và G6](routes-accepted.avi), [kết quả](routes.json): G1 đi lên/xuống A và B bằng movement/nav/collision thật. Fixture tạm cung cấp đích navigation và bỏ AI quyết định cho G1, đóng băng các guard khác và bỏ collision riêng của các actor đóng băng để cô lập tuyến; không sửa geometry/navmesh. G6 được đặt tại inspection pose QA, lấy T1 thật rồi `can_see_frame`/`report_missing` kiểm tra bằng ray thật. Suite empty_frame riêng kiểm tra G6 đi tuần/kiểm tra tự nhiên.
- [Chín guard đang hoạt động](nine-guards.avi), [audit](tour.json): camera lần lượt tới từng guard, cả chín actor giữ physics/AI hoạt động. Không phải cả chín guard đồng thời nằm trong một khung hình.

| Góc | Ảnh |
|---|---|
| Đứng / đi / chạy | [idle](clip-idle.png), [walk](clip-walk.png), [run](clip-run.png) |
| Kiểm tra / transition | [look](clip-look_around.png), [sit](clip-sit_down.png), [stand](clip-stand_up.png) |
| G3 ngủ / tỉnh ngồi | [ngủ](g3-sleep.png), [quan sát](g3-observing.png) |
| G3 trở lại ghế | [ngồi đúng ghế](g3-returned.png) |
| G6 thấy khung trống | [ảnh](g6-empty-frame.png) |
| Chín pose runtime | `tour-Guard_G1.png` tới `tour-Guard_G9.png` |

## Kiểm thử và hiệu năng

[VALIDATION.json](VALIDATION.json) ghi lệnh, exit code và log cuối. Museum: **364 checks, 0 failures** trong guard_visuals (42), staff_room (55), room_feedback (30), empty_frame (48), blockout (114), editing_mode (75). Suite visual đã đăng ký vào runner chung; [runner cuối](integrated-accepted.log) báo **All tests passed**. Shared presentation tests tiếp tục chạy với model mặc định. Import, check_scripts, layout và prepare --check được chạy riêng, không suy luận từ runner.

Các test model khối cũ được thay bằng kiểm tra hips/knee/foot skeletal, vẫn giữ toàn bộ AI/noise/chase/capture/return assertions. Skin weights, bind, tác động vertex, paths, resource sharing, pose độc lập, root drift, pause, không reset clip mỗi frame và không phát bước chân khi ngồi đều được kiểm tra. Repeated sit/reset kiểm tra anchor; staff suite và video chứng minh chu trình AI thực. Restart/reload và editing được kiểm tra bằng suite riêng.

Collider, route sản phẩm, lớp world/player/npc/interactable và cảm biến không đổi; **không bake navmesh**. Hash navmesh giữ `9efa7029d1a69b43e70323af30d9119ffb2bd2b3cdbcaaaa8280bacea4cd3bfb` như trước.

[Benchmark](benchmark.json) là lượt riêng, VSync tắt và Engine.max_fps=0 trong tool rồi khôi phục; 180 frame warmup, đo 30 giây, chín AI hoạt động, camera sân cố định, player đứng ngoài. Có p50/p95/p99 process-frame interval, draw calls, primitives, memory và phần cứng. Đây **không phải GPU frame time**, không phải worst case cả chín model đều visible và chưa có phép so sánh trước/sau cùng điều kiện để kết luận chi phí tăng hay dư địa GPU.

## File và giới hạn

[CHANGED_FILES.txt](CHANGED_FILES.txt) là danh sách đầy đủ. Nguồn chính: prepare_guard_assets, museum_guard_presentation, staff_presentation, museum scene, các scene npc, manifest, catalog và tests; tests/test_scene.gd chỉ thêm suite mới. Không sửa shared runtime hoặc scene editing.

Rig dùng trọng số hình học có giới hạn garment, không phải hand-painted cinematic rig. Bàn tay/phụ kiện theo cổ tay, chưa thêm diễn xuất ngón tay hay cơ chế vũ khí. Không thay N0/receptionist, không thêm tay player/leo dây. Chuyển tiếp đứng có thể bị ngắt rất nhanh theo tốc độ AI như yêu cầu. Đã kiểm tra các pose/camera trong bằng chứng, không tuyên bố mọi góc nhìn/GPU. Chưa chạy export Windows hoặc CI Linux.

Log draft được giữ riêng: ban đầu có lỗi type inference của tool, đọc JSON trước khi flush và một fixture chọn waypoint giữa hai vế thang B không phù hợp. Đã sửa flush/primitive type/garment weights/waypoints và chạy lại. Chỉ log `accepted-*`, `*-accepted.log`, `prepare-final.log` cùng kết quả cuối trong VALIDATION được dùng nghiệm thu. Diagnostic Windows certificate store đã có từ baseline; không phải lỗi animation.
