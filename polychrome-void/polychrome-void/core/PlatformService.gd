## PlatformService — platform abstraction for achievements and leaderboard APIs.
## Uses local fallback persistence until a native SDK bridge is configured.
extends Node

const LEADERBOARD_KEY: String = "platform_leaderboard_scores"
const ACHIEVEMENTS_KEY: String = "platform_achievements"


func submit_score(score: int) -> void:
	var scores: Array = SaveService.get_save(LEADERBOARD_KEY, [])
	scores.append(score)
	scores.sort_custom(func(a: int, b: int) -> bool: return a > b)
	if scores.size() > 20:
		scores.resize(20)
	SaveService.set_save(LEADERBOARD_KEY, scores)


func unlock_achievement(achievement_id: StringName) -> void:
	var unlocked: Array = SaveService.get_save(ACHIEVEMENTS_KEY, [])
	if not unlocked.has(str(achievement_id)):
		unlocked.append(str(achievement_id))
		SaveService.set_save(ACHIEVEMENTS_KEY, unlocked)


func has_achievement(achievement_id: StringName) -> bool:
	var unlocked: Array = SaveService.get_save(ACHIEVEMENTS_KEY, [])
	return unlocked.has(str(achievement_id))


func get_platform_leaderboard() -> Array[int]:
	var scores: Array = SaveService.get_save(LEADERBOARD_KEY, [])
	var out: Array[int] = []
	for score: Variant in scores:
		out.append(int(score))
	return out
