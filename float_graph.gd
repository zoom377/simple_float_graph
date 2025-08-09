class_name FloatGraph extends Control

@export var timespan: float 	= 5 		## Graph duration (X axis) in seconds
@export var shrink: bool		= true 		## Should graph shrink to fit Y data?
@export var grow: bool 		= true 		## Should graph grow to fit Y data?
@export var min: float 		= 0 		## Default min Y axis
@export var max: float 		= 0 		## Default max Y axis
@export var smooth_shrink_grow: bool = true ## Applies smoothing when shrinking or growing Y axis.
@export var smooth: float 		= 5 		## Smooth lerp speed for smooth_shrink_grow.
## A higher value improves drawing performance but reduces line quality.
## A value of 0 gives perfect line quality.
@export_range(0, 100, 1) var line_threshold: float = 10

## Graph color
var _color: Color = Color.RED
var color: Color:
	set(value): 
		_color = value
		_title_label.modulate = value
		_min_label.modulate = value
		_max_label.modulate = value
	get:
		return _color

var title: String:
	set(value):
		_title_label.text = value
	get:
		return ""


@onready var _max_label: RichTextLabel = $Control/Max
@onready var _min_label: RichTextLabel = $Control/Min
@onready var _title_label: RichTextLabel = $Control/Title
@onready var graph_curve: Control = $MarginContainer/GraphCurve


var _float_data: PackedVector2Array = []
var _last_draw: float = 0
var _start_time: float
var _current_time: float
var _datum_to_normalised: Transform2D
var _normalised_to_viewport: Transform2D
var _datum_to_viewport: Transform2D


## For distinct float variables, and Vector2/3s ONLY if double precision enabled.
const FLOAT64_MAX: float = 1.79769e308
## For distinct float variables, and Vector2/3s ONLY if double precision enabled.
const FLOAT64_MIN: float = -1.7976931348623157e308
const DASH_INTERVAL: float = 16
const BORDER_THICKNESS: float = 2
const CURVE_THICKNESS: float = -1

#func _enter_tree() -> void:

func _ready() -> void:
	graph_curve.draw.connect(_graph_draw)


func _process(delta: float) -> void:
	graph_curve.queue_redraw()


func add(value: float) -> void:
	# TODO This method gets real time since engine started.
	# Perhaps this should be the time at the start of tick.
	var timestamp := float(Time.get_ticks_usec()) / 1_000_000.0
	var new_datum := Vector2(timestamp, value)
	if not is_finite(new_datum.y):
		new_datum.y = 0.0
	
	if _float_data.size() >= 3:
		var p :=  _datum_to_viewport * new_datum
		var l1 := _datum_to_viewport * _float_data[-3]
		var l2 := _datum_to_viewport * _float_data[-2]
		var line_dist_sqr := _point_distance_to_line_squared(p, l1, l2)
		if line_dist_sqr < line_threshold:
			_float_data[-1] = new_datum
			return
	
	_float_data.append(new_datum)


func _graph_draw() -> void:
	_current_time = float(Time.get_ticks_usec()) / 1_000_000.0
	_start_time = _current_time - timespan
	var _draw_delta := float(Time.get_ticks_usec()) / 1_000_000.0 - _last_draw
	shrinkgrow(_draw_delta)
	_update_utility_transforms()
	_trim_old_data()
	_draw_borders()
	_draw_curve()
	_draw_labels()
	_last_draw = float(Time.get_ticks_usec()) / 1_000_000.0


## Update utility transforms used to convert between data and viewport space
func _update_utility_transforms() -> void:
	var screen_rect := graph_curve.get_rect()
	var range = max - min
	
	var datum_tl := Vector2(_start_time, max)
	var datum_bl := Vector2(_start_time, min)
	var datum_br := Vector2(_current_time, min)
	
	var norm_tl := Vector2(0, 1)
	var norm_bl := Vector2(0, 0)
	var norm_br := Vector2(1, 0)
	
	var width_ratio := (datum_br.x - datum_bl.x) / (norm_br.x - norm_bl.x)
	var height_ratio := (datum_tl.y - datum_bl.y) / (norm_tl.y - norm_bl.y)
	
	var basis_x := Vector2(width_ratio if width_ratio != 0 else 0.000001, 0)
	var basis_y := Vector2(0, -height_ratio if height_ratio != 0 else -0.000001)
	#var basis_x := Vector2(width_ratio, 0)
	#var basis_y := Vector2(0, -height_ratio)
	var origin := Vector2(_start_time, max)
	
	_datum_to_normalised = Transform2D(basis_x, basis_y, origin).affine_inverse()
	_normalised_to_viewport = Transform2D(Vector2(screen_rect.size.x, 0), Vector2(0, screen_rect.size.y), Vector2(0, 0))
	_datum_to_viewport = _normalised_to_viewport * _datum_to_normalised


func _trim_old_data() -> void:
	if _float_data.size() <= 3 or _float_data[0].x >= _start_time:
		return
		
	for i in range(_float_data.size()):
		if _float_data[i].x >= _start_time: # Found first visible point
			_float_data = _float_data.slice(i-1, _float_data.size())
			return


func shrinkgrow(draw_delta: float):
	if _float_data.size() < 1:
		return
	
	var largest := _float_data[0].y
	var smallest := _float_data[0].y
	
	for datum in _float_data:
		largest = maxf(largest, datum.y)
		smallest = minf(smallest, datum.y)
	
	var new_max := max
	var new_min := min
	
	if shrink:
		new_max = minf(new_max, largest)
		new_min = maxf(new_min, smallest)
	
	if grow:
		new_max = maxf(new_max, largest)
		new_min = minf(new_min, smallest)
	
	if smooth_shrink_grow:
		var weight := clampf(smooth * draw_delta, 0, 1)
		max = lerpf(max, new_max, weight)
		min = lerpf(min, new_min, weight)
	else:
		max = new_max
		min = new_min


func _draw_borders() -> void:
	var top_left := _normalised_to_viewport * Vector2(0, 0)
	var bottom_left := _normalised_to_viewport * Vector2(0, 1)
	var top_right := _normalised_to_viewport * Vector2(1, 0)
	var bottom_right := _normalised_to_viewport * Vector2(1, 1)
	graph_curve.draw_line(top_left, bottom_left, Color.BLACK, BORDER_THICKNESS)
	graph_curve.draw_line(top_right, bottom_right, Color.BLACK, BORDER_THICKNESS)
	
	
	var _zero_height_normalised := (_datum_to_normalised * Vector2(0,0)).y
	_zero_height_normalised = clampf(_zero_height_normalised, 0, 1)
	var zero_left := _normalised_to_viewport * Vector2(0, _zero_height_normalised)
	var zero_right := _normalised_to_viewport * Vector2(1, _zero_height_normalised)
	
	if not zero_left.is_finite() or not zero_right.is_finite():
		return
	
	
	if max <= 0:
		graph_curve.draw_dashed_line(top_left, top_right, Color.BLACK, BORDER_THICKNESS, DASH_INTERVAL)
		graph_curve.draw_line(bottom_left, bottom_right, Color.BLACK, BORDER_THICKNESS)
		pass
	elif min > 0:
		graph_curve.draw_dashed_line(bottom_left, bottom_right, Color.BLACK, BORDER_THICKNESS, DASH_INTERVAL)
		graph_curve.draw_line(top_left, top_right, Color.BLACK, BORDER_THICKNESS)
	else:
		graph_curve.draw_line(zero_left, zero_right, Color.BLACK, BORDER_THICKNESS)
		graph_curve.draw_line(top_left, top_right, Color.BLACK, BORDER_THICKNESS)
		graph_curve.draw_line(bottom_left, bottom_right, Color.BLACK, BORDER_THICKNESS)


func _draw_curve() -> void:
	graph_curve.draw_set_transform_matrix(_datum_to_viewport)
	if _float_data.size() >= 2:
		graph_curve.draw_polyline(_float_data, _color, CURVE_THICKNESS)


func _draw_labels():
	var max_text := _humanize(max, 2)
	var min_text := _humanize(min, 2)
	var largest := maxi(min_text.length(), max_text.length())
	
	_max_label.text = str(max).substr(0, largest)
	_min_label.text = str(min).substr(0, largest)


## Returns point distance to nearest point on a line that passes through l1 -> l2
static func _point_distance_to_line_squared(p: Vector2, l1: Vector2, l2: Vector2) -> float:
	return pow((l2.x - l1.x) * (l1.y - p.y) - (l1.x - p.x) * (l2.y - l1.y), 2.0)\
	 / (pow((l2.x - l1.x), 2.0) + pow((l2.y - l1.y), 2.0))


static func _humanize(value: float, digits: int) -> String:
	var str := str(value)
	var point_idx := str.find(".")
	
	for i in range(point_idx + 1, str.length()):
		if str[i] != "0":
			var end := mini(i + 2, str.length())
			return str.substr(0, end)
	
	
	return str
