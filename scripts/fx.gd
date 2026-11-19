extends Node2D

var provider: Node

func _draw() -> void:
    if provider:
        provider.draw_fx(self)
