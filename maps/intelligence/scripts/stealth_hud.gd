extends StealthHud


func _process(delta: float) -> void:
	super(delta)
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var director := StealthDirector.find(self)
	var alarm := SecurityAlarm.find(self)
	if mission and alarm and alarm.is_active() and director and director.status < StealthDirector.Status.SPOTTED:
		_banner.text = "" if mission.has_file else "BÁO ĐỘNG AN NINH"
	if director == null: return
	match director.status:
		StealthDirector.Status.SPOTTED:
			var source: String = director.get("sight_source")
			_banner.text = "%s đang quan sát" % source if not source.is_empty() else "Đang bị quan sát"
		StealthDirector.Status.CHASE:
			_banner.text = "Đang bị đuổi · cắt tầm nhìn"
