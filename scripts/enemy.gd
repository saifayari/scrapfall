extends Node2D

signal destroyed(enemy)
signal shoot_requested(pos: Vector2, dir: int, kind: String)
signal melee_player

var kind := "walker"
var health := 3
var max_health := 3
var player: Node2D
var state := "alive"
var base_y := 0.0
var t := 0.0
var shoot_cd := 3.0
var melee_cd := 0.0
var permanently_dead := false
var sprite: Sprite2D
var tex: Texture2D

func setup(k: String, pos: Vector2, pl: Node2D) -> void:
    kind = k
    player = pl
    position = pos
    base_y = pos.y
    match kind:
        "walker": max_health = 4; health = 4
        "electro": max_health = 3; health = 3
        "drone": max_health = 2; health = 2
        "boss": max_health = 14; health = 14
    match kind:
        "electro": shoot_cd = 3.0
        "drone": shoot_cd = 2.5
        _: shoot_cd = 999.0
    match kind:
        "walker", "drone":
            tex = load("res://assets/virus_1.png")
        "electro", "boss":
            tex = load("res://assets/virus_2.png")
    if sprite:
        sprite.queue_free()
        sprite = null
    if tex:
        sprite = Sprite2D.new()
        sprite.texture = tex
        var target := 42.0 if kind != "boss" else 82.0
        var s := target / maxf(1.0, float(tex.get_height()))
        sprite.scale = Vector2(s, s)
        sprite.position = Vector2(0, -target * 0.5)
        sprite.z_index = 0
        add_child(sprite)
    queue_redraw()

func _process(delta: float) -> void:
    if state != "alive" or permanently_dead:
        return
    t += delta
    melee_cd = maxf(melee_cd - delta, 0.0)
    var dx := player.position.x - position.x
    var dir := 1 if dx >= 0 else -1
    match kind:
        "walker", "boss":
            var spd := 60.0 if kind == "walker" else 45.0
            position.x += dir * spd * delta
            if absf(dx) < 38 and melee_cd <= 0.0:
                melee_player.emit()
                melee_cd = 1.1
        "electro":
            if absf(dx) > 260:
                position.x += dir * 40 * delta
            shoot_cd -= delta
            if shoot_cd <= 0.0:
                shoot_requested.emit(position + Vector2(0, -30), dir, kind)
                shoot_cd = 4.0
        "drone":
            position.x += dir * 50 * delta
            position.y = base_y + sin(t * 2.0) * 40.0
            shoot_cd -= delta
            if shoot_cd <= 0.0:
                shoot_requested.emit(position + Vector2(0, -10), dir, kind)
                shoot_cd = 3.5
    if sprite:
        sprite.flip_h = dir < 0
    queue_redraw()

func take_damage(d: int) -> void:
    if state != "alive": return
    health -= d
    if health <= 0:
        state = "destroyed"
        visible = false
        destroyed.emit(self)

func revive() -> void:
    if permanently_dead: return
    state = "alive"
    health = max_health
    position.y = base_y
    visible = true
    queue_redraw()

func _draw() -> void:
    if state != "alive": return
    if sprite == null or sprite.texture == null:
        var col := Color(0.55, 0.55, 0.6)
        match kind:
            "walker": col = Color(0.7, 0.35, 0.2)
            "electro": col = Color(0.3, 0.7, 0.9)
            "drone": col = Color(0.7, 0.65, 0.25)
            "boss": col = Color(0.8, 0.25, 0.25)
        var size := Vector2(34, 34) if kind != "boss" else Vector2(70, 70)
        draw_rect(Rect2(-size.x/2, -size.y, size.x, size.y), col)
    var bw := 34.0 if kind != "boss" else 70.0
    var by := -46.0 if kind != "boss" else -94.0
    draw_rect(Rect2(-bw/2, by, bw, 4), Color(0.2, 0.2, 0.2))
    draw_rect(Rect2(-bw/2, by, bw * (float(health) / max_health), 4), Color(0.9, 0.2, 0.2))
