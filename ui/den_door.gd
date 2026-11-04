extends Control

## Three explicit slots; occupied or unreadable worlds are never silently replaced.

signal create_requested(slot: int, pup_name: String, seed_text: String)
signal load_requested(slot: int)
signal delete_requested(slot: int)

const Saves = preload("res://games/puppy_kraft/sim/world_save.gd")

@onready var _slots: VBoxContainer = %Slots
@onready var _form: VBoxContainer = %NewWorldForm
@onready var _form_title: Label = %FormTitle
@onready var _pup_name: LineEdit = %PupName
@onready var _seed_text: LineEdit = %SeedText
@onready var _create: Button = %CreateWorld
@onready var _status: Label = %DoorStatus
@onready var _delete_dialog: ConfirmationDialog = %DeleteWorldDialog

var _selected_slot := 0
var _delete_slot := 0


func _ready() -> void:
	_form.hide()
	_create.pressed.connect(_create_world)
	_delete_dialog.confirmed.connect(func() -> void: delete_requested.emit(_delete_slot))
	_seed_text.text_submitted.connect(func(_text: String) -> void: _create_world())


func refresh(saves: Saves) -> void:
	_selected_slot = 0
	_form.hide()
	_status.text = "Worlds save locally. Seed words recreate terrain, not another pup's edits."
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for slot in range(1, Saves.SLOT_COUNT + 1):
		var summary := saves.summary(slot)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		_slots.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var primary := Button.new()
		primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		primary.custom_minimum_size.y = 52
		row.add_child(primary)
		var exists := bool(summary["exists"])
		if not exists:
			primary.text = "Slot %d / New world" % slot
		elif bool(summary["valid"]):
			primary.text = "Slot %d / Continue with %s / Day %d" % [
				slot, str(summary["pup_name"]), int(summary["day"]),
			]
		else:
			primary.text = "Slot %d / Cannot load this world" % slot
			primary.disabled = true
		primary.pressed.connect(_choose_slot.bind(slot, exists))
		if exists:
			var remove := Button.new()
			remove.text = "Delete..."
			remove.tooltip_text = "Delete Slot %d after confirmation." % slot
			remove.pressed.connect(_confirm_delete.bind(slot))
			row.add_child(remove)
			var detail := Label.new()
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_theme_font_size_override("font_size", 18)
			detail.text = "%s / %s" % [str(summary["seed_words"]), str(summary["generator"])] \
				if bool(summary["valid"]) else str(summary["message"])
			card.add_child(detail)
	_focus_first_slot.call_deferred()


func show_error(message: String) -> void:
	_status.text = "Could not complete that action: " + message


func _focus_first_slot() -> void:
	if not is_visible_in_tree() or _form.visible:
		return
	for node: Node in _slots.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.disabled:
			button.grab_focus()
			return


func _choose_slot(slot: int, occupied: bool) -> void:
	if occupied:
		load_requested.emit(slot)
		return
	_selected_slot = slot
	_form_title.text = "NEW WORLD / SLOT %d" % slot
	_form.show()
	_pup_name.text = ""
	_seed_text.text = ""
	_pup_name.grab_focus()


func _create_world() -> void:
	if _selected_slot == 0:
		show_error("Choose an empty world slot first.")
		return
	create_requested.emit(_selected_slot, _pup_name.text, _seed_text.text)


func _confirm_delete(slot: int) -> void:
	_delete_slot = slot
	_delete_dialog.title = "Delete world %d?" % slot
	_delete_dialog.dialog_text = (
		"This permanently deletes this world's terrain edits and pup progress. "
		+ "It does not delete another slot, Settings or existing shared backups."
	)
	_delete_dialog.popup_centered(Vector2i(580, 200))
