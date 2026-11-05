extends VBoxContainer

signal skip_requested

const Progress = preload("res://games/puppy_kraft/sim/first_steps.gd")
const TITLES: Array[String] = ["Wobble", "Dig", "Sniff", "Bark", "Home"]

var _title: Label
var _prompt: Label
var _skip: Button


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	add_child(row)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color("fff0cc"))
	row.add_child(_title)
	_skip = Button.new()
	_skip.text = "Skip First Steps"
	_skip.add_theme_font_size_override("font_size", 24)
	_skip.tooltip_text = "Hide these prompts for this world. No abilities or rewards are locked behind them."
	_skip.pressed.connect(skip_requested.emit)
	row.add_child(_skip)
	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 28)
	add_child(_prompt)
	hide()


func present(progress: Progress, prompt: String) -> void:
	visible = progress.step < Progress.Step.DONE
	if not visible:
		return
	_title.text = "First Steps %d/5 / %s" % [progress.step + 1, TITLES[progress.step]]
	_prompt.text = prompt
