extends StealthHud


func _process(delta: float) -> void:
	super(delta)
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var director := StealthDirector.find(self)
	var alarm := SecurityAlarm.find(self)
	if mission and alarm and alarm.is_active() and director and director.status < StealthDirector.Status.SPOTTED:
		_banner.text = "" if mission.has_file else "BÁO ĐỘNG AN NINH"
