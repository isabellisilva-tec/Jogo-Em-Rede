
extends Control

var botao_jogar_novamente: Button


func _ready() -> void:
	print("Tela de vitória do Jogador 2 aberta.")

	botao_jogar_novamente = find_child("Button", true, false) as Button

	if botao_jogar_novamente == null:
		push_error("Não encontrei um botão chamado Button na tela de vitória do Jogador 2.")
		return

	botao_jogar_novamente.disabled = false
