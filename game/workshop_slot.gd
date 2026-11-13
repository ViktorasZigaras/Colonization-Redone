extends Button
signal assigned(worker: int, job: String)
var job := ""

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("worker") and job != ""

func _drop_data(_at: Vector2, data: Variant) -> void:
	assigned.emit(data.worker,job)
