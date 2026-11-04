extends "res://maps/museum/scripts/staff_document.gd"

## Local computer time is presentation only. Puzzle maintenance dates stay fixed.
var time_provider := Callable(Time,"get_datetime_dict_from_system")
var _refresh_left := 0.0


func _ready() -> void:
	super()
	refresh_clock()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 1.0
		refresh_clock()


func refresh_clock() -> void:
	var now: Dictionary = time_provider.call()
	$Text.font_size = 34
	$Text.text = "C · LỊCH BẢO TRÌ\nHôm nay: %02d/%02d/%04d\n%02d:%02d:%02d\nKiểm tra dây: 14/03" % [
		now.day,now.month,now.year,now.hour,now.minute,now.second]


func get_content() -> String:
	var now: Dictionary = time_provider.call()
	var weekdays := ["Chủ nhật","Thứ hai","Thứ ba","Thứ tư","Thứ năm","Thứ sáu","Thứ bảy"]
	return "Hôm nay: %s, %02d/%02d/%04d\nGiờ máy tính: %02d:%02d:%02d\n\nLỊCH BẢO TRÌ\nKiểm tra đèn: 08/03\nKiểm tra dây bảo hộ: 14/03\nBảo dưỡng đài phun nước: 16/03\n\nNgày bảo trì được ghi cố định.\nGhi chú G nằm trên bàn A." % [
		weekdays[int(now.get("weekday",0))],now.day,now.month,now.year,now.hour,now.minute,now.second]
