@tool
extends EditorPlugin

const singleton_script_name := "SFG"


func _enter_tree() -> void:
	add_autoload_singleton(singleton_script_name, "res://addons/simple_float_graph/sfg.gd")
	pass


func _exit_tree() -> void:
	remove_autoload_singleton(singleton_script_name)
	pass
