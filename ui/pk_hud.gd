extends PanelContainer

## Building, mouth state, the bark budget, and a separate persistent save status.

signal save_requested
signal nap_requested
signal skip_first_steps_requested

const World = preload("res://games/puppy_kraft/sim/world_state.gd")
const Blocks = preload("res://games/puppy_kraft/sim/blocks.gd")
const Chunk = preload("res://games/puppy_kraft/sim/chunk.gd")
const FirstSteps = preload("res://games/puppy_kraft/ui/first_steps.gd")

var _first_steps: FirstSteps
var _material: Label
var _target: Label
var _ability: Label
var _mouth: Label
var _status: Label
var _nap: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margins := MarginContainer.new()
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 10)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margins.add_child(layout)
	_first_steps = FirstSteps.new()
	_first_steps.skip_requested.connect(skip_first_steps_requested.emit)
	layout.add_child(_first_steps)
	var row := HBoxContainer.new()
	layout.add_child(row)
	_material = Label.new()
	_material.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material.add_theme_font_size_override("font_size", 24)
	row.add_child(_material)
	var save := Button.new()
	save.text = "Save world"
	save.pressed.connect(save_requested.emit)
	row.add_child(save)
	_nap = Button.new()
	_nap.text = "Call it a day"
	_nap.tooltip_text = "Return to the starting straw bed first."
	_nap.pressed.connect(nap_requested.emit)
	row.add_child(_nap)
	_ability = Label.new()
	_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability.add_theme_font_size_override("font_size", 20)
	_ability.tooltip_text = (
		"Yip is free; Woof costs 3 energy; Ruff costs 8 and has a 1s cooldown. "
		+ "After 1s grounded and inactive, recover 2 energy per second, up to 100."
	)
	layout.add_child(_ability)
	_mouth = Label.new()
	_mouth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mouth.add_theme_font_size_override("font_size", 20)
	layout.add_child(_mouth)
	_target = Label.new()
	_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target.add_theme_font_size_override("font_size", 20)
	layout.add_child(_target)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	layout.add_child(_status)


func present(world: World, first_steps_prompt: String) -> void:
	_first_steps.present(world.first_steps, first_steps_prompt)
	_material.text = "%s x%d  |  %d dug / %d placed" % [
		Blocks.title(world.selected_block), world.inventory[world.selected_block],
		world.blocks_dug, world.blocks_placed,
	]
	_ability.text = "Energy %d/100  |  Bark: %s" % [
		floori(world.needs.energy + 0.00000001), world.abilities.charge_caption(),
	]
	var guidance := world.stick.caption
	if guidance.is_empty():
		guidance = "Drop to dig or build; run + Carry to throw." if world.stick.carried \
			else "Sniff for your stick, then Carry nearby."
	_mouth.text = "Mouth: %s  |  %s" % ["stick" if world.stick.carried else "empty", guidance]
	var target := Blocks.title(world.grid.get_block(world.target_cell, world.target_layer))
	if world.sniffing:
		_target.text = world.scent.caption(world.body.position) + " End sniffing to dig."
	else:
		_target.text = "Target: %s / %s / %s%s" % [
			target, "back wall" if world.target_layer == Chunk.BACK else "front",
			"in reach" if world.target_in_reach else "out of reach",
			"  |  " + world.hint if not world.hint.is_empty() else "",
		]
	_nap.disabled = not world.near_bed()


func show_message(message: String, failed: bool = false) -> void:
	_status.text = ("SAVE FAILED: " if failed else "") + message
	_status.add_theme_color_override("font_color",
		Color("f1aea3") if failed else Color("d3dfcb"))
