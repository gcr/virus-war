extends Control

## Whose turn.
enum Turn {A, B}
@export var turn: Turn = Turn.A:
	set(value):
		turn=value
		%A_turn_button.button_pressed = (turn == Turn.A)
		%B_turn_button.button_pressed = (turn == Turn.B)
		%B_turn_button.release_focus()
		%A_turn_button.release_focus()
		for button in %GridContainer.get_children():
			button.whose_turn = "A" if turn == Turn.A else "B"
			button.queue_redraw()

## Number of grid cells.
var width:
	get:
		return %GridContainer.columns
## Number of grid cells.
var height:
	get:
		return %GridContainer.get_child_count() / width

## Returns the cell at (r,c) on the grid, or null
func get_cell(r: int, c: int) -> VirusButton:
	if r >= 0 and r < height:
		if c >= 0 and c < width:
			return %GridContainer.get_child(r*width + c)
	return null

func _ready() -> void:
	turn=turn
	for i in %GridContainer.get_child_count():
		# connect up all the grid cells
		var node: VirusButton = %GridContainer.get_child(i)
		var r = i / width
		var c = i % width
		node.above = get_cell(r-1, c)
		node.below = get_cell(r+1, c)
		node.left = get_cell(r, c-1)
		node.right = get_cell(r, c+1)
		node.row = r
		node.col = c
		node.pressed.connect(advance_state.bind(node))

## Advance the state shown on a button
func advance_state(node: VirusButton) -> void:
	match [turn, node.state]:
		[Turn.A, node.State.BLANK]:  node.state = node.State.A
		[Turn.A, node.State.A]:      node.state = node.State.BLANK
		[Turn.A, node.State.B]:      node.state = node.State.DEAD_B
		[Turn.A, node.State.DEAD_A]: node.state = node.State.DEAD_A
		[Turn.A, node.State.DEAD_B]: node.state = node.State.B

		[Turn.B, node.State.BLANK]:  node.state = node.State.B
		[Turn.B, node.State.A]:      node.state = node.State.DEAD_A
		[Turn.B, node.State.B]:      node.state = node.State.BLANK
		[Turn.B, node.State.DEAD_A]: node.state = node.State.A
		[Turn.B, node.State.DEAD_B]: node.state = node.State.DEAD_B

	# Redraw the nodes
	for b in %GridContainer.get_children():
		b.queue_redraw()


func swap_turn_button_pressed() -> void:
	turn = 1-turn
