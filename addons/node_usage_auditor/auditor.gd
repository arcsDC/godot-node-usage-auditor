@tool
extends EditorPlugin

var _menu_item: MenuItem
var _dialog: AcceptDialog
var _output: RichTextLabel

func _enter_tree() -> void:
	_menu_item = get_editor_interface().get_base_control().get_node("PopupMenu")
	_menu_item.add_child(_create_menu_item())
	_dialog = _create_dialog()
	add_child(_dialog)

func _exit_tree() -> void:
	if _menu_item:
		_menu_item.queue_free()
	if _dialog:
		_dialog.queue_free()

func _create_menu_item() -> MenuItem:
	var item := MenuItem.new()
	item.text = "Audit Node Usage"
	item.pressed.connect(_on_audit_pressed)
	return item

func _create_dialog() -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "Node Usage Audit"
	dialog.min_size = Vector2(400, 300)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(_output)
	return dialog

func _on_audit_pressed() -> void:
	var results := _scan_project()
	_output.text = results
	_dialog.popup_centered()

func _scan_project() -> String:
	var output := "[b]Node Usage Audit Report[/b]\n\n"
	var scene_paths := _get_scene_paths()
	var node_names := {}
	var unused_nodes := []

	for path in scene_paths:
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		_collect_nodes(root, node_names, unused_nodes)
		root.free()

	if unused_nodes.is_empty():
		output += "[color=green]No unused nodes found.[/color]\n"
	else:
		output += "[b]Unused Nodes:[/b]\n"
		for node in unused_nodes:
			output += "  - %s (%s)\n" % [node.name, node.get_path()]

	if node_names.size() > 0:
		output += "\n[b]Duplicate Names:[/b]\n"
		for name in node_names:
			if node_names[name] > 1:
				output += "  - %s (appears %d times)\n" % [name, node_names[name]]

	return output

func _get_scene_paths() -> Array:
	var paths := []
	var dir := DirAccess.open("res://")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				paths.append("res://" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return paths

func _collect_nodes(node: Node, names: Dictionary, unused: Array) -> void:
	names[node.name] = names.get(node.name, 0) + 1
	if node.get_children().is_empty() and not node.has_meta("used"):
		unused.append(node)
	for child in node.get_children():
		_collect_nodes(child, names, unused)
