
extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0
const FLOOR_Y := 500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var posicao_inicial: Vector2
var travado := false


func _enter_tree() -> void:
	if name == "player2" and not multiplayer.is_server():
		set_multiplayer_authority(multiplayer.get_unique_id(), true)


func _ready() -> void:
	posicao_inicial = global_position


func reiniciar_jogador(nova_posicao: Vector2) -> void:
	travado = true
	velocity = Vector2.ZERO
	posicao_inicial = nova_posicao
	global_position = nova_posicao
	reset_physics_interpolation()


func liberar_jogador() -> void:
	velocity = Vector2.ZERO
	travado = false
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var fase = get_tree().current_scene

	if fase == null:
		return

	if not fase.get("rede_ativa"):
		return

	if not is_multiplayer_authority():
		return

	if travado:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("player2_pular") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animated_sprite.play("pulando")

	var direction := Input.get_axis(
		"player2_esquerda",
		"player2_direita"
	)

	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.play("correndo")
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

		if is_on_floor():
			animated_sprite.play("parado")

	move_and_slide()

	if global_position.y > FLOOR_Y:
		reiniciar_jogador(posicao_inicial)
		travado = false
