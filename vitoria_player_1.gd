
extends Control


func _ready() -> void:
	print("Tela de vitória do Jogador 1 aberta.")


func _process(_delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	var fase = get_tree().current_scene

	if fase != null and fase.has_method("solicitar_revanche"):
		fase.solicitar_revanche()
