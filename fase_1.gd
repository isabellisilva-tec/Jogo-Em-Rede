
extends Node2D

const PORT := 7000
const MAX_CLIENTS := 1

const PLAYER_1_SCENE: PackedScene = preload("res://player.tscn")
const PLAYER_2_SCENE: PackedScene = preload("res://player_2.tscn")
const VITORIA_1: PackedScene = preload("res://vitoria_player_1.tscn")
const VITORIA_2: PackedScene = preload("res://vitoria_player_2.tscn")

var rede_ativa := false
var rodada_terminou := false
var jogador2_peer_id := 0
var confirmacoes_revanche: Dictionary = {}
var pedido_revanche_enviado := false
var reinicio_em_andamento := false
var player2_reiniciado := false

# Identifica cada sequência de vitória para cancelar esperas antigas.
var vitoria_versao := 0

var status_label: Label
var endereco_input: LineEdit
var host_button: Button
var join_button: Button

var camada_vitoria: CanvasLayer
var tela_vitoria: Control

@onready var players: Node2D = $Players
@onready var spawn_host: Marker2D = $SpawnHost
@onready var spawn_client: Marker2D = $SpawnClient


func _ready() -> void:
	print("Cena iniciada: ", name)

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	_criar_interface_rede()


func _criar_interface_rede() -> void:
	var camada := CanvasLayer.new()
	camada.name = "InterfaceRede"
	add_child(camada)

	var painel := PanelContainer.new()
	painel.position = Vector2(12, 12)
	painel.custom_minimum_size = Vector2(330, 0)
	camada.add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "JOGO EM REDE"
	coluna.add_child(titulo)

	status_label = Label.new()
	status_label.text = "Escolha Host ou informe o IP e clique Join."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(status_label)

	endereco_input = LineEdit.new()
	endereco_input.placeholder_text = "IP do servidor"
	endereco_input.text = "127.0.0.1"
	coluna.add_child(endereco_input)

	var linha := HBoxContainer.new()
	coluna.add_child(linha)

	host_button = Button.new()
	host_button.text = "Host (Jogador 1)"
	host_button.pressed.connect(host_game)
	linha.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join (Jogador 2)"
	join_button.pressed.connect(join_game)
	linha.add_child(join_button)


func host_game() -> void:
	var peer_atual = multiplayer.multiplayer_peer

	if peer_atual != null and not (peer_atual is OfflineMultiplayerPeer):
		if multiplayer.is_server():
			status_label.text = "Servidor já está ativo!"
			_criar_jogador_host()
		else:
			status_label.text = "Esta instância já está conectada como cliente."
		return

	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_server(PORT, MAX_CLIENTS)

	if erro != OK:
		status_label.text = "Não foi possível criar o servidor. Código: %s" % erro
		push_error("Erro ao criar servidor: %s" % erro)
		return

	multiplayer.multiplayer_peer = peer

	rede_ativa = false
	rodada_terminou = false
	jogador2_peer_id = 0
	confirmacoes_revanche.clear()
	pedido_revanche_enviado = false
	reinicio_em_andamento = false

	_criar_jogador_host()

	status_label.text = "Servidor ativo. Aguardando Jogador 2..."
	host_button.disabled = true
	join_button.disabled = true
	endereco_input.editable = false

	print("Servidor criado na porta ", PORT)


func join_game() -> void:
	var endereco := endereco_input.text.strip_edges()

	if endereco.is_empty():
		status_label.text = "Informe o IP do servidor."
		return

	var peer_atual = multiplayer.multiplayer_peer

	if peer_atual != null and not (peer_atual is OfflineMultiplayerPeer):
		status_label.text = "Esta instância já possui uma conexão."
		return

	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_client(endereco, PORT)

	if erro != OK:
		status_label.text = "Não foi possível conectar. Código: %s" % erro
		push_error("Erro ao conectar: %s" % erro)
		return

	multiplayer.multiplayer_peer = peer

	status_label.text = "Conectando a %s:%d..." % [endereco, PORT]
	host_button.disabled = true
	join_button.disabled = true
	endereco_input.editable = false

	print("Tentando conectar a ", endereco, ":", PORT)


func _criar_jogador_host() -> void:
	if not multiplayer.is_server():
		return

	if players.get_node_or_null("player") != null:
		return

	var jogador1 := PLAYER_1_SCENE.instantiate()
	jogador1.name = "player"
	jogador1.set_multiplayer_authority(1, true)
	jogador1.global_position = spawn_host.global_position
	players.add_child(jogador1, true)


func _criar_jogadores() -> void:
	if not multiplayer.is_server():
		return

	_criar_jogador_host()

	if players.get_node_or_null("player2") != null:
		return

	var jogador2 := PLAYER_2_SCENE.instantiate()
	jogador2.name = "player2"
	jogador2.set_multiplayer_authority(jogador2_peer_id, true)
	jogador2.global_position = spawn_client.global_position
	players.add_child(jogador2, true)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server() or id == 1:
		return

	jogador2_peer_id = id
	_criar_jogadores()

	rede_ativa = true
	rodada_terminou = false
	confirmacoes_revanche.clear()
	pedido_revanche_enviado = false

	status_label.text = "Jogador 2 conectado! Corrida iniciada!"

	host_button.hide()
	join_button.hide()
	endereco_input.hide()

	print("Jogador conectado. ID: ", id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or id != jogador2_peer_id:
		return

	rede_ativa = false
	rodada_terminou = false
	jogador2_peer_id = 0
	confirmacoes_revanche.clear()
	pedido_revanche_enviado = false
	reinicio_em_andamento = false
	vitoria_versao += 1

	var jogador2 := players.get_node_or_null("player2")
	if jogador2 != null:
		jogador2.queue_free()

	status_label.text = "Jogador 2 desconectou."
	_reexibir_conexao()


func _on_connected_to_server() -> void:
	jogador2_peer_id = multiplayer.get_unique_id()
	rede_ativa = true

	status_label.text = "Conectado! Você controla o Jogador 2."

	host_button.hide()
	join_button.hide()
	endereco_input.hide()

	print("Cliente conectado ao servidor.")


func _on_connection_failed() -> void:
	rede_ativa = false
	jogador2_peer_id = 0
	vitoria_versao += 1
	status_label.text = "Falha na conexão. Confira o IP e a porta 7000."

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reexibir_conexao()


func _on_server_disconnected() -> void:
	rede_ativa = false
	jogador2_peer_id = 0
	rodada_terminou = false
	pedido_revanche_enviado = false
	reinicio_em_andamento = false
	vitoria_versao += 1

	status_label.text = "O servidor desconectou."

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reexibir_conexao()


func _reexibir_conexao() -> void:
	host_button.show()
	join_button.show()
	endereco_input.show()

	host_button.disabled = false
	join_button.disabled = false
	endereco_input.editable = true


func servidor_registrar_vitoria(jogador_id: int) -> void:
	if not multiplayer.is_server() or rodada_terminou:
		return

	rodada_terminou = true
	anunciar_vitoria.rpc(jogador_id)


@rpc("authority", "call_local", "reliable")
func anunciar_vitoria(jogador_id: int) -> void:
	rodada_terminou = true
	rede_ativa = false
	confirmacoes_revanche.clear()
	pedido_revanche_enviado = false
	reinicio_em_andamento = false

	# Guarda a versão desta vitória.
	vitoria_versao += 1
	var minha_versao := vitoria_versao

	var p1 = players.get_node_or_null("player")
	var p2 = players.get_node_or_null("player2")

	if p1 != null:
		p1.set("travado", true)
		p1.set("velocity", Vector2.ZERO)

	if p2 != null:
		p2.set("travado", true)
		p2.set("velocity", Vector2.ZERO)

	print("JOGADOR %d GANHOU!" % jogador_id)

	await get_tree().create_timer(2.0).timeout

	# Uma vitória antiga não pode mostrar sua tela após a revanche.
	if not is_inside_tree():
		return

	if minha_versao != vitoria_versao:
		return

	if rodada_terminou:
		_mostrar_tela_vitoria(jogador_id)


func _mostrar_tela_vitoria(jogador_id: int) -> void:
	if is_instance_valid(camada_vitoria):
		camada_vitoria.queue_free()

	camada_vitoria = CanvasLayer.new()
	camada_vitoria.name = "CamadaVitoria"
	camada_vitoria.layer = 10
	add_child(camada_vitoria)

	var cena_vitoria: PackedScene = VITORIA_1 if jogador_id == 1 else VITORIA_2

	tela_vitoria = cena_vitoria.instantiate()
	tela_vitoria.name = "TelaVitoria"

	if tela_vitoria is Control:
		tela_vitoria.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	camada_vitoria.add_child(tela_vitoria)

	var botao := tela_vitoria.find_child("Button", true, false) as Button

	if botao == null:
		push_error("Não encontrei um botão chamado Button na tela de vitória.")
		return

	for conexao in botao.pressed.get_connections():
		var callback: Callable = conexao["callable"]
		botao.pressed.disconnect(callback)

	botao.disabled = false
	botao.pressed.connect(_on_botao_vitoria_pressed)


func _on_botao_vitoria_pressed() -> void:
	if pedido_revanche_enviado:
		return

	solicitar_revanche()


func solicitar_revanche() -> void:
	if not is_inside_tree() or not rodada_terminou:
		return

	var peer = multiplayer.multiplayer_peer

	if peer == null or peer is OfflineMultiplayerPeer:
		status_label.text = "A conexão foi perdida. Reinicie o jogo."
		return

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		status_label.text = "Aguardando conexão. Tente novamente."
		return

	pedido_revanche_enviado = true

	if is_instance_valid(tela_vitoria):
		var botao := tela_vitoria.find_child("Button", true, false) as Button
		if botao != null:
			botao.disabled = true

	if multiplayer.is_server():
		_registrar_confirmacao(1)
	else:
		pedir_revanche.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func pedir_revanche() -> void:
	if not is_inside_tree():
		return

	if not multiplayer.is_server() or not rodada_terminou:
		return

	var id := multiplayer.get_remote_sender_id()

	if id != jogador2_peer_id:
		return

	_registrar_confirmacao(id)


func _registrar_confirmacao(id: int) -> void:
	if not multiplayer.is_server() or not rodada_terminou:
		return

	confirmacoes_revanche[id] = true
	print("Confirmações para revanche: ", confirmacoes_revanche)

	if (
		confirmacoes_revanche.has(1)
		and confirmacoes_revanche.has(jogador2_peer_id)
		and not reinicio_em_andamento
	):
		reinicio_em_andamento = true
		player2_reiniciado = false
		reiniciar_partida.rpc()


@rpc("authority", "call_local", "reliable")
func reiniciar_partida() -> void:
	if not rodada_terminou:
		reinicio_em_andamento = false
		return

	# Invalida qualquer temporizador de vitória anterior.
	vitoria_versao += 1

	# Impede o portal de registrar outra vitória durante o reinício.
	var portal = get_node_or_null("portal")
	if portal != null:
		if portal.has_method("preparar_nova_partida"):
			portal.preparar_nova_partida()
		else:
			portal.set("jogo_terminou", true)

	var p1 = players.get_node_or_null("player")
	var p2 = players.get_node_or_null("player2")

	if multiplayer.is_server():
		# O servidor reposiciona o Player 1, que tem autoridade local.
		if p1 != null and p1.has_method("reiniciar_jogador"):
			p1.reiniciar_jogador(spawn_host.global_position)

		# Aguarda o cliente reposicionar o Player 2, que é controlado por ele.
		while not player2_reiniciado and is_inside_tree():
			await get_tree().create_timer(0.05).timeout

		if not is_inside_tree():
			return

		# Aguarda a posição do Player 2 chegar ao servidor antes de reabrir o portal.
		await get_tree().physics_frame
		await get_tree().physics_frame
		liberar_nova_rodada.rpc()
	else:
		# O cliente reposiciona o Player 2, pois é a autoridade desse personagem.
		if p2 == null or not p2.has_method("reiniciar_jogador"):
			return

		p2.reiniciar_jogador(spawn_client.global_position)
		await get_tree().physics_frame
		await get_tree().physics_frame
		confirmar_reinicio_player2.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func confirmar_reinicio_player2() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != jogador2_peer_id:
		return

	var p2 = players.get_node_or_null("player2")
	if p2 != null and p2.has_method("reiniciar_jogador"):
		# Atualiza também a cópia do Player 2 no servidor para evitar uma posição antiga no portal.
		p2.reiniciar_jogador(spawn_client.global_position)

	player2_reiniciado = true


@rpc("authority", "call_local", "reliable")
func liberar_nova_rodada() -> void:
	if is_instance_valid(camada_vitoria):
		camada_vitoria.queue_free()

	camada_vitoria = null
	tela_vitoria = null

	for player in players.get_children():
		if player.has_method("liberar_jogador"):
			player.liberar_jogador()
		else:
			player.set("velocity", Vector2.ZERO)
			player.set("travado", false)
			player.reset_physics_interpolation()

	confirmacoes_revanche.clear()
	rodada_terminou = false
	rede_ativa = true
	pedido_revanche_enviado = false
	reinicio_em_andamento = false
	player2_reiniciado = false

	print("Revanche iniciada.")
