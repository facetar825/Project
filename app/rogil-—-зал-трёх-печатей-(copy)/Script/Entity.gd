extends CharacterBody3D
class_name Entity

@export var max_hp: int = 100
@export var base_damage: int = 25
@export var base_crit_chance: int = 10
@export var base_crit_damage: int = 110
@export var regen_hp: int = 5
@export var speed: int = 10
@export var speed_attack: float = 0.3

@export var bonuse_hp: int = 0
@export var bonuse_damage: int = 0
@export var bonuse_crit_chance: int = 0
@export var bonuse_crit_damage: int = 0
@export var bonuse_regen_hp: int = 0
@export var bonuse_speed: int = 0
@export var bonuse_speed_attack: float = 0

var point : int
var current_hp: int
var level: int = 1
var exp: int = 0
var next_level: int = 10

var can_attack: bool = true
var regen_timer: float = 0.0
const REGEN_INTERVAL = 1.0  # реген каждую секунду

func _ready() -> void:
	current_hp = get_max_hp()

func _process(delta: float) -> void:
	_handle_regen(delta)

func _handle_regen(delta: float) -> void:
	if current_hp >= get_max_hp():
		return
	regen_timer += delta
	if regen_timer >= REGEN_INTERVAL:
		regen_timer = 0.0
		current_hp = min(current_hp + get_regen_hp(), get_max_hp())

func  get_speed_attack() -> float:
	return speed_attack + (level - 1) + bonuse_speed_attack
func get_speed() -> int:
	return speed + (level - 1) + bonuse_speed
func get_regen_hp() -> int:
	return regen_hp + (level - 1) + bonuse_regen_hp
func get_max_hp() -> int:
	return max_hp + (level - 1) * bonuse_hp
func get_damage() -> int:
	return base_damage + (level - 1) * bonuse_damage
func get_crit_chance() -> int:
	return base_crit_chance + (level - 1) + bonuse_crit_chance
func get_crit_damage() -> int:
	return base_crit_damage + (level - 1) * bonuse_crit_damage
func add_exp(amount: int) -> void:
	exp += amount
	while exp >= next_level:
		level_up()

func level_up() -> void:
	exp -= next_level
	level += 1
	point +=1
	next_level = int(next_level * 1.2)
	current_hp = get_max_hp()
	print("%s повысил уровень до %d!" % [name, level])

func take_damage(amount: int) -> void:
	current_hp -= amount
	print("%s получил %d урона. HP: %d/%d" % [name, amount, current_hp, get_max_hp()])
	if current_hp <= 0:
		die()

func die() -> void:
	print("%s умер!" % name)
	queue_free()

# Вычисляет итоговый урон с учётом крита
func calculate_attack_damage() -> Dictionary:
	var dmg := get_damage()
	var is_crit := randi() % 100 < get_crit_chance()
	if is_crit:
		dmg = int(dmg * (get_crit_damage() / 100.0))
	return {"damage": dmg, "is_crit": is_crit}

# Атака с кулдауном
func try_attack(target: Entity) -> bool:
	if not can_attack:
		return false
	can_attack = false
	_play_aura()
	
	var result := calculate_attack_damage()
	target.take_damage(result["damage"])
	if result["is_crit"]:
		print("%s нанёс КРИТИЧЕСКИЙ удар: %d" % [name, result["damage"]])
	else:
		print("%s нанёс урон: %d" % [name, result["damage"]])
	# Таймер через SceneTree — не блокирует
	get_tree().create_timer(speed_attack).timeout.connect(
		func(): can_attack = true
	)
	
	return true	
func _play_aura() -> void:
	pass
