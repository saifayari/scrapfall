extends CharacterBody2D

signal shoot_requested(pos: Vector2, dir: int, weapon: String)
signal died
signal health_changed(h: int, m: int)
signal shield_changed(s: int, m: int)

var speed := Config.PLAYER_SPEED
var health := Config.PLAYER_MAX_HEALTH
var max_health := Config.PLAYER_MAX_HEALTH
var shield := 0
var max_shield := 0
var shield_disabled := 0.0
var weapon := "standard"
var weapons := ["standard"]
var fire_cd := 0.0
var facing := 1
var coyote := 0.0
var buffer := 0.0
var invuln := 0.0
var sprite: AnimatedSprite2D

func _ready() -> void:
    var frames := SpriteFrames.new()
    frames.add_animation("walk")
    frames.set_animation_speed("walk", 8.0)
    frames.set_animation_loop("walk", true)
    for i in 4:
        var tex := load("res://assets/player_walk_%d.png" % i)
        if tex:
            frames.add_frame("walk", tex)
    if frames.get_frame_count("walk") > 0:
        sprite = AnimatedSprite2D.new()
        sprite.sprite_frames = frames
        sprite.animation = "walk"
        var target_h := 72.0
        var first_tex := frames.get_frame_texture("walk", 0)
        var s := target_h / maxf(1.0, float(first_tex.get_height()))
        sprite.scale = Vector2(s, s)
        sprite.position = Vector2(0, -target_h * 0.5)
        sprite.z_index = 0
        sprite.flip_h = false
        add_child(sprite)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(36, 72)
    shape.shape = rect
    shape.position = Vector2(0, -36)
    add_child(shape)
    collision_layer = 2
    collision_mask = 1
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += Config.PLAYER_GRAVITY * delta
    var dir := 0.0
    if Input.is_action_pressed("move_left"): dir -= 1.0
    if Input.is_action_pressed("move_right"): dir += 1.0
    if dir != 0.0:
        velocity.x = move_toward(velocity.x, dir * speed, Config.PLAYER_ACCEL * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, Config.PLAYER_FRICTION * delta)
    if is_on_floor(): coyote = Config.PLAYER_COYOTE
    else: coyote = maxf(coyote - delta, 0.0)
    if Input.is_action_just_pressed("jump"): buffer = Config.PLAYER_BUFFER
    else: buffer = maxf(buffer - delta, 0.0)
    if buffer > 0.0 and coyote > 0.0:
        velocity.y = Config.PLAYER_JUMP
        buffer = 0.0
        coyote = 0.0
    if Input.is_action_just_released("jump") and velocity.y < 0.0:
        velocity.y *= 0.5
    move_and_slide()
    if dir != 0.0:
        var nf := int(signf(dir))
        if nf != facing:
            facing = nf
            if sprite:
                sprite.flip_h = facing < 0
            queue_redraw()
    if sprite and sprite.sprite_frames and sprite.sprite_frames.get_frame_count("walk") > 0:
        if dir != 0.0:
            if not sprite.is_playing():
                sprite.play("walk")
        else:
            sprite.stop()
            sprite.frame = 0

func _process(delta: float) -> void:
    invuln = maxf(invuln - delta, 0.0)
    shield_disabled = maxf(shield_disabled - delta, 0.0)
    if sprite:
        sprite.visible = not (invuln > 0.0 and int(invuln * 20.0) % 2 == 0)
    fire_cd = maxf(fire_cd - delta, 0.0)
    if Input.is_action_pressed("fire") and fire_cd <= 0.0:
        fire_cd = _fire_rate()
        shoot_requested.emit(position + Vector2(facing * 22, -46), facing, weapon)
    if Input.is_action_just_pressed("switch_weapon"):
        _cycle_weapon()
    queue_redraw()

func _fire_rate() -> float:
    match weapon:
        "cannon": return 0.55
        "electric": return 0.22
        _: return 0.28

func _cycle_weapon() -> void:
    if weapons.size() <= 1: return
    var idx := weapons.find(weapon)
    weapon = weapons[(idx + 1) % weapons.size()]

func unlock_weapon(w: String) -> void:
    if not weapons.has(w):
        weapons.append(w)

func add_shield() -> void:
    max_shield += 1
    shield = max_shield
    shield_changed.emit(shield, max_shield)

func take_damage(amount: int, electric := false) -> void:
    if invuln > 0.0: return
    if electric:
        shield_disabled = 3.0
    if shield > 0 and shield_disabled <= 0.0:
        shield -= 1
        shield_changed.emit(shield, max_shield)
    else:
        health -= amount
        health_changed.emit(health, max_health)
        if health <= 0:
            died.emit()
    invuln = Config.PLAYER_IFRAME

func respawn(pos: Vector2) -> void:
    position = pos
    velocity = Vector2.ZERO
    health = max_health
    shield = max_shield
    invuln = 1.5
    health_changed.emit(health, max_health)
    shield_changed.emit(shield, max_shield)

func _draw() -> void:
    if sprite == null or sprite.sprite_frames == null or sprite.sprite_frames.get_frame_count("walk") == 0:
        if invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
            return
        draw_rect(Rect2(-18, -72, 36, 72), Color(0.85, 0.35, 0.15))
        draw_rect(Rect2(-13, -84, 26, 18), Color(0.78, 0.78, 0.82))
        var vx := 0.0 if facing > 0 else -13.0
        draw_rect(Rect2(vx, -80, 13, 8), Color(0.2, 0.95, 0.5))
        draw_rect(Rect2(-16, 0, 10, 5), Color(0.25, 0.25, 0.28))
        draw_rect(Rect2(6, 0, 10, 5), Color(0.25, 0.25, 0.28))
        draw_rect(Rect2(facing * 20 - 5, -48, 16, 8), Color(0.55, 0.55, 0.6))
    if shield > 0 and shield_disabled <= 0.0:
        draw_arc(Vector2(0, -36), 52, 0, TAU, 28, Color(0.3, 0.7, 1.0, 0.45), 3.0)
