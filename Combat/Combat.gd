extends Node

const FLEECHANCE = 70
const YTEAMPOS = 180

signal targets_selected
signal turn_completed

onready var EnemyAI = preload("res://Combat/EnemyAI.gd")

var active_unit = null
var active_pos = Vector2(0, 0)
var active_targets = []
var active_targets_pos = []
var current_target_index = 0
var selected_targets = []
var target_num = 1
var active_group = "Allies"


func _ready():
	randomize()
	set_process_input(false)
	get_node("BackGround").set_size(OS.get_window_size())
	get_node("CanvasLayer/End/Black").set_size(OS.get_window_size())
	get_node("CanvasLayer/End/Label").set_position(OS.get_window_size()/2)
	get_node("AttackHandler/ScreenShake/Camera2D").set_position(OS.get_window_size()/2)
	get_node("Allies").set_position(Vector2(0, YTEAMPOS))
	get_node("Enemies").set_position(Vector2(OS.get_window_size().x, YTEAMPOS))
	
	var allies = []
	allies.append("Bunny")
	allies.append("Mole")
	
	get_node("Allies").populate(allies, true)
	
	var enemies = []
	enemies.append("Bunny")
	get_node("Enemies").populate(enemies, false)
	
	player_turn()


func _input(event):
	var Pointer = get_node("CanvasLayer/Pointer")
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_right"):
		current_target_index = (current_target_index + 1) % active_targets.size()
		Pointer.set_position(active_targets_pos[current_target_index] - Vector2(0, 200))
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left"):
		current_target_index -= 1
		if current_target_index < 0:
			current_target_index = active_targets.size() - 1
		Pointer.set_position(active_targets_pos[current_target_index]- Vector2(0, 200))
	
	if event.is_action_pressed("ui_accept"):
		target_num -= 1
		selected_targets.append(active_targets[current_target_index])
	elif event.is_action_pressed("ui_cancel"):
		get_node("ActionSelector").enable()
		get_node("CanvasLayer/SkillDescription").show()
		get_node("CanvasLayer/Pointer").hide()
		set_process_input(false)
	
	if target_num == 0:
		emit_signal("targets_selected")
		get_node("CanvasLayer/Pointer").hide()
		set_process_input(false)


func player_turn():
	active_unit = get_node("Allies").get_next_actor()
	active_pos = active_unit.get_global_position()
	
	if active_unit.HP > 0:
		var ActSel = get_node("ActionSelector")
		var action_list = []
		
		ActSel.set_position(active_pos)
		action_list.append(active_unit.Signature1)
		action_list.append(active_unit.Signature2)
		action_list = action_list + ["Flee", "Swap", "Wait", "Item"]
		ActSel.update_actions(action_list)
		ActSel.enable()
		get_node("CanvasLayer/SkillDescription").show()
		yield(self, "turn_completed")
	end_turn()


func enemy_turn():
	var Unit = get_node("Enemies").get_next_actor()
	var act = EnemyAI.choose_action(Unit, $Allies, $Enemies)
	get_node("AttackHandler").attack(Unit, act[1], act[0])
	yield(get_node("AttackHandler"), "attack_finished")
	end_turn()


func end_turn():
	var result = battle_ended()
	if  result == 1:
		victory()
		return
	elif result == 2:
		defeat()
		return
	
	# Go to next turn
	if active_group == "Allies":
		player_turn()
	else:
		enemy_turn()


func battle_ended():
	var dead_allies = get_node("Allies").get_dead_units()
	var dead_enemies = get_node("Enemies").get_dead_units()
	
	if dead_enemies.size() == get_node("Enemies").get_all_units().size():
		# Enemies lost
		return 1
	if dead_allies.size() == get_node("Allies").get_all_units().size():
		# Player lost
		return 2
	return 0


func victory():
	var End = get_node("CanvasLayer/End")
	
	End.get_node("Label").set_text("You Won")
	End.get_node("AnimationPlayer").play("end")
	yield(End.get_node("AnimationPlayer"), "animation_finished")
	get_parent().restart()


func defeat():
	var End = get_node("CanvasLayer/End")
	
	End.get_node("Label").set_text("IS THIS LOSS?")
	End.get_node("AnimationPlayer").play("end")
	yield(End.get_node("AnimationPlayer"), "animation_finished")
	get_parent().restart()


func get_targets(group, exclude_active = false, subgroup = null):
	var team = get_node(group)
	
	active_targets = []
	active_targets_pos = []
	current_target_index = 0
	selected_targets = []
	target_num = 1
	
	if not subgroup:
		active_targets = team.get_all_units()
	elif subgroup == "targetable":
		active_targets = team.get_front_unit()
	
	for target in active_targets:
		active_targets_pos.append(target.get_global_position())
	
	if exclude_active and active_unit in active_targets:
		var i = active_targets.find(active_unit)
		active_targets.remove(i)
		active_targets_pos.remove(i)
	
	get_node("CanvasLayer/Pointer").set_position(active_targets_pos[0] - Vector2(0, 200))
	get_node("CanvasLayer/Pointer").show()
	set_process_input(true)


func flee_succeeded():
	var r = randi() % 100
	
	if r < FLEECHANCE:
		return true
	return false

####################### EXTERNAL SIGNAL HANDLING #######################
# Player selected an action
func _on_ActionSelector_selected( action ):
	get_node("ActionSelector").disable()
	get_node("CanvasLayer/SkillDescription").hide()
	
	if action == "Swap":
		get_targets("Allies", true)
		yield(self, "targets_selected")
		get_node("Allies").swap(active_unit, selected_targets[0])
		yield(get_node("Allies/Tween"), "tween_completed")
	elif action == "Flee":
		if flee_succeeded():
			get_node("Allies").flee(active_unit)
			yield(get_node("Allies/Tween"), "tween_completed")
		else:
			print("Flee failed")
	elif action == "Wait":
		pass
	else:
		get_targets("Enemies", false, "targetable")
		yield(self, "targets_selected")
		get_node("AttackHandler").attack(active_unit, selected_targets[0], action)
		yield(get_node("AttackHandler"), "attack_finished")
	emit_signal("turn_completed")

# Player is scrolling
func _on_ActionSelector_changed_to(name):
	var id = SkillDatabase.get_skill_id(name)
	if id == -1:
		$CanvasLayer/SkillDescription/Description.set_text("Not present in database")
		return
	var description = SkillDatabase.get_skill_description(id)
	$CanvasLayer/SkillDescription/Description.set_text(description)

func _on_Allies_all_acted():
	active_group = "Enemies"

func _on_Enemies_all_acted():
	active_group = "Allies"

########################################################################
