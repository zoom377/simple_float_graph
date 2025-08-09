extends Node

const GRAPH_CONTAINER = preload("res://addons/simplefloatgraph/UI/GraphContainer.tscn")
const FLOAT_GRAPH := preload("res://addons/simplefloatgraph/UI/FloatGraph.tscn")

var _tracked_floats: Array[FloatContext] = []

var _vbox: Container

func _enter_tree() -> void:
	var cont := GRAPH_CONTAINER.instantiate()
	add_child(cont)
	_vbox = cont.get_child(0)
	for child in _vbox.get_children():
		_vbox.remove_child(child)


## Begins to automatically record the float value every frame and display on graph.
## selector should be a function that returns the current float value.
func start_tracking(selector: Callable, title: String = "", color: Color = Color.RED, sample_mode: SampleMode = SampleMode.PROCESS) -> FloatGraph:
	var new_graph := create_graph()
	new_graph.color = color
	new_graph.title = title
	
	var context := FloatContext.new()
	context.graph_control = new_graph
	context.selector = selector
	context.sample_mode = sample_mode
	
	_tracked_floats.append(context)
	return new_graph
	
	return null


## Create a graph to which data can be manually added using FloatGraph.add(value)
func create_graph() -> FloatGraph:
	var new_graph := FLOAT_GRAPH.instantiate() as FloatGraph
	_vbox.add_child(new_graph)
	return new_graph


## Destroys a graph. Additionally stops auto tracking if it was registered with start_tracking()
func destroy_graph(graph: FloatGraph) -> void:
	for i in range(_tracked_floats.size()):
		var ctx := _tracked_floats[i]
		if ctx.graph_control == graph:
			ctx.graph_control.queue_free()
		_tracked_floats.remove_at(i)
		break


func _physics_process(delta: float) -> void:
	for context in _tracked_floats:
		if context.sample_mode != SampleMode.PHYSICS_PROCESS:
			break
		
		var value_this_tick := context.selector.call()
		assert(value_this_tick is float, "Selector function must return a float value.")
		context.graph_control.add(value_this_tick)


func _process(delta: float) -> void:
	for context in _tracked_floats:
		if context.sample_mode != SampleMode.PROCESS:
			break
		
		var value_this_tick := context.selector.call()
		assert(value_this_tick is float, "Selector function must return a float value.")
		context.graph_control.add(value_this_tick)


class FloatContext:
	var selector: Callable
	var graph_control: FloatGraph
	var sample_mode: SampleMode


enum SampleMode {PROCESS, PHYSICS_PROCESS}
