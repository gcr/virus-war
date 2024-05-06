@tool
extends Button
class_name VirusButton

enum State {BLANK, A, B, DEAD_A, DEAD_B}
@export var state: State = State.BLANK:
	set(value):
		state=value
		_ready()


@export var whose_turn: String

## Reference to button above this one. (Set by Game)
var above: VirusButton
## Reference to button below this one. (Set by Game)
var below: VirusButton
## Reference to button left of this one. (Set by Game)
var left: VirusButton
## Reference to button right of this one. (Set by Game)
var right: VirusButton
## Row in grid
var row: int
## Col in grid
var col: int

var owned_by:
	get:
		if state == State.A or state == State.DEAD_A:
			return "A"
		elif state == State.B or state == State.DEAD_B:
			return "B"
		else:
			return ""
"""
var owned_by_accounting_for_liveness:
	get:
		if not is_dead: return owned_by
		if state == State.A or state == State.DEAD_B:
			return "A"
		elif state == State.B or state == State.DEAD_A:
			return "B"
		else:
			return ""
"""
var is_alive:
	get:
		return state == State.A or state == State.B
var is_dead:
	get:
		return state == State.DEAD_A or state == State.DEAD_B
var is_blank:
	get:
		return state == State.BLANK

func connected_to(other) -> bool:
	if other != null:
		# blank pieces are not connected
		#if is_blank or other.is_blank:
		#	return false
		# alive/alive and dead/dead are connected if they share owners
		return owned_by == other.owned_by and not other.is_blank and not is_blank
		#if is_dead == other.is_dead:
		#	return owned_by == other.owned_by
		#else:
		#	# pieces with different liveness are
		#	# connected to opposite teams
		#	return owned_by != other.owned_by and not other.is_blank and not is_blank
	return false

## Update text and label.
func _ready() -> void:
		button_pressed = is_dead

		release_focus()

func _draw() -> void:
	var w = get_rect().size.x
	var h = get_rect().size.y
	const r = 0.4
	var label_size = 0.2*w  / 2
	var label_thickness = 1.0
	var center = get_rect().size / 2
	var label_color = Color(0,0,0)

	# Draw label
	if owned_by == "A":
		draw_line(center + Vector2(-label_size, -label_size), center + Vector2(label_size, label_size), label_color, label_thickness, true)
		draw_line(center + Vector2(label_size,-label_size), center + Vector2(-label_size, label_size), label_color, label_thickness, true)
	elif owned_by == "B":
		draw_arc(center, label_size, 0, TAU, 64, label_color, label_thickness, true)

	# Draw T/B/R/L lines between regions
	var maybe_line = func(v1, v2, offset_v1, offset_v2, other_node):
		var orig_v1 = v1
		var orig_v2 = v2
		match [offset_v1, offset_v2]:
			# maybe bump the start or end point by the
			# rounded corner radius?
			[true, true]:
				v1 += (v2-v1) * r
				v2 += (v1-v2) * r/(1-r)
			[true, _]:
				v1 += (v2-v1) * r
			[_, true]:
				v2 += (v1-v2) * r
		if is_blank and other_node and other_node.is_blank:
			draw_line(orig_v1, orig_v2, Color.GRAY, 1.0)
			#draw_line(v2, orig_v2, Color.GRAY, 1.0)
		else:
			if not is_blank and not connected_to(other_node):
				draw_line(v1, v2, Color.BLACK, 2.0)
		if not other_node:
			draw_line(v1, v2, Color.BLACK, 2.0)

	# Corners influence the horizontal and vertical lines.
	# Suppose B and C should be connected:
	#  A  |    B
	#-----' ,-----
	#  C   |   D
	# A and D should draw circles, but
	# B and C should also offset their borders by the
	# radius of the circle to prevent overdraw.

	#var ul_connected = (above and above.left and (connected_to(above.left) or above.connected_to(left) or not connected_to(above) or not connected_to(left)))
	#var ur_connected = (above and above.right and (connected_to(above.right) or above.connected_to(right)))
	#var bl_connected = (below and below.left and (connected_to(below.left) or below.connected_to(left)))
	#var br_connected = (below and below.right and (connected_to(below.right) or below.connected_to(right)))

	# Draw our inner circles.
	var maybe_draw_circle = func(side1, side2, side_corner, xy, r, start, end):
		# do they exist and are they connected?
		var should_draw = false
		if side1 and side2:
			# if we're blank, we only want to draw a circle if
			# they aren't blank and are connected
			if is_blank:
				should_draw = side1.connected_to(side2) and not side1.is_blank
			else:
				# if we're NOT blank, we only want to draw a circle
				# if we're NOT connected to them
				should_draw = not connected_to(side1) and not connected_to(side2) and not connected_to(side_corner)
				# special case: if connections happen crisscross, draw
				if connected_to(side_corner) and not side1.is_blank and side1.connected_to(side2) and not connected_to(side1): # and whose_turn == side1.owned_by:
					should_draw = true
		if should_draw:
			draw_arc(xy, r, start, end, 16, Color.BLACK, 1.0, true)
		return should_draw or connected_to(side_corner)


	var ul_circ = false
	var ur_circ = false
	var bl_circ = false
	var br_circ = false
	if above:
		ul_circ = maybe_draw_circle.call(above, left, above.left, Vector2(w*r, h*r), w*r, -PI, -PI/2)
		ur_circ = maybe_draw_circle.call(above, right, above.right, Vector2(w*(1-r), h*r), w*r, -PI/2, 0)
	if below:
		bl_circ = maybe_draw_circle.call(below, left, below.left, Vector2(w*r, h*(1-r)), w*r, PI/2, PI)
		br_circ = maybe_draw_circle.call(below, right, below.right, Vector2(w*(1-r), h*(1-r)), w*r, 0, PI/2)

	maybe_line.call(Vector2(0, 0), Vector2(w, 0), ul_circ, ur_circ, above)
	maybe_line.call(Vector2(0, h), Vector2(w, h), bl_circ, br_circ, below)
	maybe_line.call(Vector2(0, 0), Vector2(0, h), ul_circ, bl_circ, left)
	maybe_line.call(Vector2(w, 0), Vector2(w, h), ur_circ, br_circ, right)

