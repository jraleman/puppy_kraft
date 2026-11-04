extends SceneTree

## The basic bark budget restores only through simulated grounded rest, not menus.

const Needs = preload("res://games/puppy_kraft/sim/needs.gd")
const Body = preload("res://games/puppy_kraft/sim/puppy_body.gd")
const Frame = preload("res://games/puppy_kraft/sim/input_frame.gd")
const Fixture = preload("res://games/puppy_kraft/tests/world_fixture.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_budget()
	_test_world_rest()
	_test_fixed_step()
	if _failures.is_empty():
		print("Puppy Kraft basic-energy tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_budget() -> void:
	var needs := Needs.new()
	needs.energy = 0.0
	for tick in 60:
		needs.step(true)
	_expect(needs.energy == 0.0, "Rest recovery must wait one full idle second.")
	for tick in 90:
		needs.step(true)
	_expect(needs.spend(3) and is_zero_approx(needs.energy),
		"Exactly 1.5 seconds of recovery must fund a Woof despite floating-point accumulation.")
	_expect(not needs.spend(8) and is_zero_approx(needs.energy),
		"Failed spending must not make energy negative or consume a partial cost.")
	needs.energy = 99.99
	for tick in 120:
		needs.step(true)
	_expect(needs.energy == 100.0, "Long rest must cap the basic energy budget at 100.")


func _test_world_rest() -> void:
	var world := Fixture.world()
	world.needs.energy = 50.0
	world.advance(Body.STEP * 120.0, Frame.new())
	_expect(is_equal_approx(world.needs.energy, 52.0),
		"A grounded idle world must restore two energy per second after the delay.")
	var frame := Frame.new()
	frame.move = 1.0
	var before := world.needs.energy
	world.advance(Body.STEP * 30.0, frame)
	_expect(world.needs.energy == before and world.needs.rest_ticks == 0,
		"Movement must interrupt rest without inventing the deferred running-energy drain.")
	frame.move = 0.0
	frame.sniff = true
	world.advance(Body.STEP * 90.0, frame)
	_expect(world.needs.energy == before and world.needs.rest_ticks == 0,
		"Active sniffing must neither spend energy nor count as resting.")


func _test_fixed_step() -> void:
	var a := Fixture.world()
	var b := Fixture.world()
	a.needs.energy = 10.0
	b.needs.energy = 10.0
	a.advance(Body.STEP * 123.5, Frame.new())
	for frame in 247:
		b.advance(Body.STEP * 0.5, Frame.new())
	_expect(is_equal_approx(a.needs.energy, b.needs.energy)
		and a.needs.rest_ticks == b.needs.rest_ticks,
		"Energy recovery must depend on fixed simulation ticks, not render-frame partitioning.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
