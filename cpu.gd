extends CanvasLayer

@export var think_per_frame: int = 10
@export var n_thinks_left: int = 0
@export var n_thinks_total: int = 10000

@export var best_cell: PackedByteArray

signal finished

func start_mcts(game: Game) -> void:
	var arr: PackedByteArray
	for r in game.height:
		for c in game.width:
			arr.append(game.get_cell(r,c).state)
	$CpuPlayer.reset_state(game.turn, 1, game.width, arr)
	n_thinks_left = n_thinks_total
	%ProgressBar.max_value = n_thinks_total
	visible = true
	set_process(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if n_thinks_left > 0:
		n_thinks_left -= think_per_frame
		best_cell = $CpuPlayer.run_mcts(think_per_frame)

		%ProgressBar.value = (n_thinks_total - n_thinks_left)
	else:
		visible = false
		set_process(false)
		if best_cell.size() == 2:
			finished.emit(best_cell)
