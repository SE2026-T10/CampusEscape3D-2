extends RefCounted
## Scene-local configuration, shared by authoring, permanent and late actors.
const CHASE_SPEED := 5.0
const CAMERAS := [
	["Command",Vector3(3,2.8,10),Vector3(6.5,1,10),9.0],
	["Records",Vector3(10.8,2.8,-12),Vector3(10.8,1,-19),7.5],
	["Service",Vector3(27,3,28),Vector3(32,1,37),10.0],
]
const POWER_SWITCH := Vector3(42.9,1.4,3.2)
const KEYPAD := Vector3(5.35,1.3,-23.45)
const VAULT_CODE := "4827"
const NOTES := [
	["VaultCode",Vector3(5.9,1.34,11.5),"Chỉ dẫn kho B1","Kho B1 dùng bốn chữ số. Đọc các ô trong bảng ca trực theo thứ tự A → C → B → D. Bảng đối chiếu ở điểm chuẩn bị khu hồ sơ. Thẻ và checkpoint phải hợp lệ trước khi xác nhận mã.",true],
	["DutyTable",Vector3(8.85,1.4,-18.45),"Bảng ca trực","Đối chiếu ca trực: A = 4; B = 2; C = 8; D = 7. Thứ tự nhập do ban chỉ huy quy định trong chỉ dẫn kho B1. Nhập sai ba lần: khóa tạm 20 giây và báo động cục bộ.",false],
	["PowerMemo",Vector3(42.85,1.4,1.7),"Nguồn dự phòng và đường rút","Công tắc trạm điện cắt nguồn camera chính. Phá niêm phong hồ sơ khởi động nguồn dự phòng sau 15 giây. Cổng sân đóng ở giây 90. Chuẩn bị chốt cửa hậu để mở nhanh; nếu chưa chuẩn bị phải giữ E tám giây. Lấy tài liệu xong mới bắt đầu 120 giây.\n\nTÙY CHỌN / PHÁ HOẠI: tủ tình báo dự phòng nằm cạnh bàn dụng cụ trong xưởng phía nam trạm điện. Sau khi lấy hồ sơ, giữ E 5 giây tại mặt tủ để đặt thiết bị đã được cấp. Không chiếm ô đồ, không cộng giờ. Thiết bị chỉ kích hoạt khi đã rút tới tập kết an toàn; có thể bỏ qua để ưu tiên hồ sơ.",false],
]
const BOTTLES := [Vector3(-35,.86,4),Vector3(5,.05,12.7)]
const HIDING := {
	"MotorPool": Vector3(-41,0,24.9),
	"GuardPost": Vector3(-43,0,-6.3),
	"RadioBay": Vector3(0,0,13),
	"Utilities": Vector3(41.2,0,5),
	"Records": Vector3(8,0,-20),
	"Vault": Vector3(-7.5,-4,-47.2),
	"Service": Vector3(25.8,0,37.3),
}
const HIDING_SIZE := {
	"MotorPool":Vector3(1.3,1.25,.7),"GuardPost":Vector3(.8,1.25,1.2),
	"RadioBay":Vector3(1.3,1.25,1.1),"Utilities":Vector3(.8,1.25,.6),
	"Records":Vector3(1.1,1.25,1.1),"Vault":Vector3(1,1.25,1.1),
	"Service":Vector3(.7,1.25,1.2),
}

static func configure_guard(guard: Guard) -> void:
	guard.expanded_security = true
	guard.chase_speed = CHASE_SPEED
	guard.alarm_detection_multiplier = 1.35
	guard.alarm_search_multiplier = 1.5
