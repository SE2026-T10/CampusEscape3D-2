# ISG Museum — NPC art v1, 16/11/2026

> Hồ sơ lịch sử đã tổ chức lại; kết luận, số đo và kết quả gốc được giữ nguyên. [Mục lục](../../README.md) · [images](images/) · [videos](videos/) · [logs](logs/) · [data](data/) . Raw log/JSON có thể ghi đường dẫn cũ; tra manifest migration từ mục lục.


Đã thay hình khối N0 và tiếp đón bằng visual có skin, dùng lại rig bảo vệ 65 xương. Hai actor vẫn là Area3D/Interactable, giữ vùng tương tác, nhiệm vụ và UI hiện có. Không instance actor Guard, không thêm AI, cảm biến, navigation, collider world hoặc âm thanh bảo vệ.

Working tree guard-art chưa commit được giữ nguyên. Rig, guard_animations.res, guard manifest và các scene guard đã được đối chiếu hash với bàn giao guard-art: không thay đổi. `museum.tscn` không cần chỉnh thêm trong lượt NPC; các thay đổi guard-art có sẵn trong file vẫn được giữ.

## Asset và animation

Tái sử dụng `guard_rig.tscn`, mesh/skin và local-rest retarget của `prepare_guard_assets.gd`. Công cụ mới kế thừa hàm converter, đặt target là skeleton đã lưu; không gọi phần rigging hay ghi resource guard. Đầu ra riêng: `museum_npc_visual.tscn`, `npc_animations.res`, `npc_animation_manifest.json`.

| Runtime | Nguồn | Thời lượng / xử lý |
|---|---|---|
| standing_idle | guard idle dẫn xuất | 8,333 s, loop |
| standing_talk | npc_talking.fbx, mixamo_com | 3,933 s, loop |
| seated_idle | guard sitting_idle dẫn xuất | 6,4 s, loop |
| seated_talk | receptionist_talking.fbx, mixamo_com | 44,067 s, loop |
| seated_watch | seated_idle + modifier | 6,4 s, loop và nhìn người chơi |

Talking giữ cử chỉ tay/thân và vị trí hông dọc, loại dịch chuyển XZ. Clip receptionist nguồn thực sự là ngồi; mean hip height được căn về seated_idle. Tail 0,35 s hòa về pose đầu để tránh nhảy ở key cuối. Một AnimationPlayer/visual thực hiện crossfade 0,2 s; không restart khi cờ talking không đổi. Không có animation event cấp hợp đồng/vé.

Trang phục N0 xanh rêu, tiếp đón nâu/xám ấm. Chỉ duplicate material áo/vest/quần; mesh/skin, da và khuôn mặt vẫn dùng resource nguồn. Hai mesh vũ khí cầm tay tách riêng được ẩn cho vai dân sự, không ẩn đầu hoặc sửa rig. Material bảo vệ giữ nguyên. Jose Manuel **CC BY 4.0** và Adobe Mixamo terms được ghi trong [NPC_README](../../../assets/animations/mixamo/derived/NPC_README.md), `npc_source.json`, catalog và manifest. FBX/GLB gốc không đổi.

## Anchor, hướng và quan sát

| Actor | Area giữ nguyên | Visual local | Hướng |
|---|---|---|---|
| N0 | (20.5, 1, 31.5), transform actor cũ | (0, -1, 0), yaw 180° | Hướng ra khu tiếp cận sân trước |
| Tiếp đón | (32.7, 1.15, 27) | (+0.35, -1.15, 0), yaw 90° | -X về quầy |

VisualPivot bên trong vẫn chuyển nguồn +Z sang -Z theo chuẩn rig. Root/actor không kéo giãn. Tiếp đón có floor anchor `(33.05,0,27)`; đo ở pose nói: hips khoảng `(33.035,0.485,27)`, chân khoảng Y0,114. Ghế dịch vụ bị ngược như ghế G3 trước đây: đã đổi riêng instance trong `apply_to_service()` từ yaw +90° sang -90°. Collider ghế/quầy và vùng ray tương tác không đổi.

`npc_watch_modifier.gd` là SkeletonModifier3D chạy sau animation, theo [cơ chế modifier của Godot](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html). Tính hướng trong không gian skeleton, chuyển rotation qua basis của parent bone, giới hạn yaw ±0,65 rad/pitch ±0,18 rad và nội suy với hệ số 5/s. Chia chỉnh nhìn cho đầu và phần ngực trên; không xoay hông, ghế hoặc Area. Native modifier rollback tránh tích lũy pose qua các frame.

Giữ nguyên điều kiện cooldown > 0 và player cách NPC dưới 5 m, cùng WatchNotice. Khi cooldown kết thúc, controller chọn lại talk/idle theo phiên hội thoại còn tồn tại. Không dùng góc quay của Head hình khối cũ.

## Vòng đời hội thoại

`open_contract()` trả bool; chỉ mở thành công mới gắn source và bật N0 nói. Nhận hợp đồng/đóng UI đưa N0 về idle. J có source=null; màn tổng kết không phải hội thoại. Các nhánh nút, E/Esc/J, khoảng cách, GameFlow và hủy UI đều kết thúc phiên trước khi xóa source.

ServiceUI chỉ kích hoạt NPC cho quiz/ticket có source trực tiếp. Map và M/V từ xa không bật nói. Khi đủ ba câu đúng, `_open()` nhận diện cùng source/actor và đổi mode sang ticket trong phiên đang mở: không close/reopen, không phát lại clip, giữ modal và mouse restore state. Câu hỏi/đáp án, random bốn hợp đồng, lịch hẹn, cooldown 10 s và thời điểm cấp vé giữ nguyên. Không có callback animation can thiệp các luật này.

Hai UI phát `conversation_started`/`conversation_ended`, gọi API presentation trung tính của source và kiểm tra instance còn tồn tại. Source giống nhau không tạo phiên mới; teardown UI dừng talking. Không thêm kết nối signal lặp trong `_process`.

## Rebuild và kiểm thử

Hai builder đã sinh lại scene và chạy lại lần thứ hai. Snapshot so theo node/type/transform/mesh data/skin/collision thay vì resource ID: **97 node tương đương**, không nhân đôi visual. [Kết quả](data/authoring-check.json), [snapshot đầu](data/authoring-first.json), [snapshot sau](data/authoring-second.json), [exit codes](data/rebuild-exits.json). `build_service.gd` gọi palette và art helper như pipeline hiện có; root visual có metadata giữ material nguồn, màu vai trò áp bằng override riêng khi vào scene.

`prepare_npc_assets.gd -- --check` kiểm tra manifest/hash nguồn, rig, skin weights, library/loop và track đích. Hash resource/manifest trước và sau không đổi. Art `--check` cũng đạt sau reload: [log](logs/check-art.log). Không bake navmesh: topology/collision không đổi, hash nav giữ nguyên.

Kết quả cuối **381 kiểm tra museum, 0 failures**, tất cả exit 0:

| Suite | Checks |
|---|---:|
| npc_visuals | 65 |
| contract | 42 |
| contract_variants | 71 |
| service | 31 |
| editing_mode | 75 |
| guard_visuals | 42 |
| staff_room | 55 |

Import Godot 4.7.2 đạt; **355 scripts** hợp lệ; layout **816 runtime references**. Runner chung có suite NPC mới và báo **All tests passed**, exit 0: [log](logs/integrated.log). [VALIDATION.json](VALIDATION.json) lưu lệnh/exit code/log/hash cụ thể.

Guard visual test chỉ được cập nhật assertion editing: cho phép hai skeleton dân sự ở đúng subtree, vẫn cấm guard actor và visual mồ côi. Không bỏ kiểm tra skin/AI guard. Các kiểm tra mới bao gồm arm animation thật của cả hai NPC, modifier thật sau animation, pose độc lập, material guard không đổi, các nhánh đóng UI, remote read, quiz → ticket, vé/cửa, pause/reload và editing còn tương tác.

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/ci/check_scripts.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_npc_assets.gd -- --check
godot --headless --path . --fixed-fps 60 --script res://maps/isg_museum/tools/verify_<suite>.gd
godot --headless --path . --fixed-fps 60 res://tests/test_scene.tscn
python -B tools/ci/check_layout.py
```

`<suite>` là bảy suite trong bảng. Python dùng interpreter uv đã có tại `C:/Users/Gia Manh/AppData/Roaming/uv/python/cpython-3.15-windows-x86_64-none/python.exe`. APPDATA test nằm riêng trong `.local/npc-art-userdata` của tiến trình; không sửa ProjectSettings/user settings toàn cục.

## Bằng chứng Godot

[Video](videos/npc-showcase.avi): **626 frame, 30 FPS, 20,87 s**, GL Compatibility, 1280×720. Đã xem ảnh và các JPEG trích đúng video chunks AVI. [Audit trạng thái/anchor](data/capture.json), [log](logs/capture-final.log). Không dùng ảnh AI, không dùng FPS quay phim làm benchmark.

| Tình huống | Ảnh |
|---|---|
| N0 chờ / nói trực tiếp | [chờ](images/n0-idle.png), [nói](images/n0-talking.png) |
| Giấy hẹn từ xa, N0 không nói | [ảnh](images/remote-contract.png) |
| Ngồi chờ và hông/chân | [góc bên](images/reception-idle-side.png) |
| Hỏi đáp, cử chỉ ngồi | [bên](images/reception-talking-side.png), [trước](images/reception-talking-front.png) |
| Cooldown/WatchNotice | [ảnh](images/reception-watch.png) |
| Quiz chuyển ticket cùng phiên | [ảnh](images/reception-ticket-session.png) |
| Vé từ xa, NPC không nói | [ảnh](images/remote-ticket.png) |
| Ba màu trang phục | [so sánh QA](images/role-colours-qa.png) |

Fixture quay dùng scene gameplay, giữ NPC/UI thật, dừng guard AI/caught overlay để xem hội thoại. Panel/backdrop được ẩn riêng ở các góc pose; UI vẫn mở và giữ source/modal. Ảnh phân biệt trang phục tạm đặt G5/N0/tiếp đón và ghế cạnh nhau ngoài sân trong instance QA; không lưu vị trí này vào scene sản phẩm. Ảnh tương tác/anchor còn lại ở vị trí thật. J/M/V được kiểm tra bằng input trong suite, các ảnh remote dùng cùng API mở từ xa.

## File và giới hạn

[CHANGED_FILES.txt](data/CHANGED_FILES.txt) chỉ liệt kê phần NPC; các file guard-art có sẵn trong working tree được giữ riêng. Nguồn sửa: contract_teammate/UI, service_npc/UI/expansion, hai builder và riêng hướng ghế trong environment_art_builder. Scene teammate/service được sinh lại; catalog thêm entry NPC; runner chung đăng ký suite. Các file visual/controller/modifier/preparer/library/manifest/test/capture và tài liệu NPC được tạo mới.

Rig và hình dáng cơ thể vẫn là model low-poly dùng chung; hai vai phân biệt bằng trang phục và cử chỉ, chưa có gương mặt riêng hoặc diễn xuất ngón tay. Chưa thêm hoạt ảnh trao vật phẩm đồng bộ bàn tay/vé, voice/lip sync, benchmark riêng hoặc export Windows/CI Linux. Không có bước rigging bên ngoài còn bị chặn. Diagnostic certificate store đã có ở baseline; lỗi type inference của bản test thử đã sửa trước các lượt cuối. Chỉ log cuối trong VALIDATION dùng nghiệm thu.
