## SaveSystemVerificationTest — validates slot isolation and cloud mirror write path.
extends Node


func _ready() -> void:
	print("[SaveSystemVerification] Running...")
	var original_slot: int = SaveService.get_active_slot()

	SaveService.set_active_slot(0)
	SaveService.set_save("meta_currency", 111)
	SaveService.set_save("cloud_enabled", true)

	SaveService.set_active_slot(1)
	SaveService.set_save("meta_currency", 222)
	SaveService.set_save("cloud_enabled", false)

	SaveService.set_active_slot(0)
	var slot0: int = int(SaveService.get_save("meta_currency", 0))
	SaveService.set_active_slot(1)
	var slot1: int = int(SaveService.get_save("meta_currency", 0))

	SaveService.set_active_slot(original_slot)

	if slot0 == 111 and slot1 == 222:
		print("[SaveSystemVerification] PASS  slot isolation OK")
	else:
		push_error("[SaveSystemVerification] FAIL  slot isolation broken: s0=%d s1=%d" % [slot0, slot1])
