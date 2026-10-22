
extends Area2D

var jogo_terminou := false
var aguardando_saida_dos_jogadores := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if jogo_terminou or aguardando_saida_dos_jogadores:
		return

	var fase = get_tree().current_scene

	if fase == null:
		return

	# Somente o servidor valida quem chegou ao portal.
	if not multiplayer.is_server():
		return

	if not fase.get("rede_ativa"):
		return

	var jogador_id := 0

	if body.name == "player":
		jogador_id = 1
	elif body.name == "player2":
		jogador_id = 2
	else:
		return

	# Impede que outra vitória seja registrada nesta rodada.
	jogo_terminou = true

	if body is CharacterBody2D:
		body.set("travado", true)
		body.velocity = Vector2.ZERO

	print("JOGADOR %d GANHOU!" % jogador_id)

	if fase.has_method("servidor_registrar_vitoria"):
		fase.servidor_registrar_vitoria(jogador_id)


func preparar_nova_partida() -> void:
	# Bloqueia o portal enquanto os jogadores ainda estiverem sobre ele.
	jogo_terminou = true
	aguardando_saida_dos_jogadores = true


func liberar_portal() -> void:
	# Só libera a vitória depois que todos os jogadores saírem da área.
	for body in get_overlapping_bodies():
		if body.name == "player" or body.name == "player2":
			return

	aguardando_saida_dos_jogadores = false
	jogo_terminou = false


func _physics_process(_delta: float) -> void:
	if not aguardando_saida_dos_jogadores:
		return

	var fase = get_tree().current_scene

	if fase == null or fase.get("rodada_terminou"):
		return

	liberar_portal()
