@tool
extends EditorPlugin

const PLUGIN_NAME = "Arcade Vehicle Framework"

func _enter_tree() -> void:
	print("[%s] Plugin initialized smoothly!" % PLUGIN_NAME)

func _exit_tree() -> void:
	print("[%s] Plugin deactivated smoothly." % PLUGIN_NAME)
