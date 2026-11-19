extends Node2D

signal regenerated(pile)
signal dismantled(pile)

var TEX_SCRAP: Texture2D

var enemy: Node2D
var timer := 8.0
var progress := 0.0
var done := false
var sprite: Sprite2D

func setup(e: Node2D) -> void:
    enemy = e
    position = e.position
    queue_redraw()

func _ready() -> void:
    TEX_SCRAP = load("res://assets/scrap_pile.png")
    sprite = Sprite2D.new()
    sprite.texture = TEX_SCRAP
    var target_h := 58.0
    var s := target_h / maxf(1.0, float(sprite.texture.get_height()))
    sprite.scale = Vector2(s, s)
    sprite.position = Vector2(0, -target_h * 0.5)
    sprite.z_index = 1
    add_child(sprite)

func _process(delta: float) -> void:
    if done: return
    timer -= delta
    if timer <= 0.0:
        done = true
        regenerated.emit(self)
    queue_redraw()

func recycle(delta: float) -> void:
    if done: return
    progress += delta
    if progress >= 2.0:
        done = true
        dismantled.emit(self)

func decay(delta: float) -> void:
    progress = maxf(0.0, progress - delta * 0.6)

func _draw() -> void:
    var ratio := clampf(timer / 8.0, 0.0, 1.0)
    draw_arc(Vector2(0, -24), 28, -PI/2, -PI/2 + TAU * ratio, 32, Color(0.95, 0.75, 0.2), 3.0)
    if progress > 0.0:
        draw_arc(Vector2(0, -24), 34, -PI/2, -PI/2 + TAU * clampf(progress/2.0, 0, 1), 32, Color(0.2, 1.0, 0.5), 4.0)
    if sprite == null:
        draw_circle(Vector2(0, -12), 20, Color(0.35, 0.3, 0.25))
        draw_circle(Vector2(0, -12), 14, Color(0.5, 0.45, 0.35))