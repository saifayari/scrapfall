extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PileScript = preload("res://scripts/scrap_pile.gd")
const FxScript = preload("res://scripts/fx.gd")

var TEX_BG_SKY: Texture2D
var TEX_BG_INTERIOR: Texture2D
var TEX_PLATFORM: Texture2D
var TEX_ECO_BATTERY: Texture2D
var TEX_TELECOM: Texture2D
var TEX_SERVER: Texture2D

const GROUND_TOP := 620.0
const LEVEL_END := 2850.0
const STATION_X := 1500.0

var state := "menu"
var player: Node2D
var enemies: Array = []
var piles: Array = []
var pbullets: Array = []
var ebullets: Array = []
var particles: Array = []
var checkpoint := Vector2(220, 500)
var total_enemies := 0
var dismantled_count := 0
var fx: Node2D
var touch_layer: CanvasLayer
var ui: CanvasLayer
var hud: Control
var hud_labels := {}
var menu_layer: Control
var pause_layer: Control
var end_layer: Control
var craft_panel: Control
var craft_buttons := {}
var bg_layers: Array = []
var station_node: Node2D
var telecom_node: Sprite2D
var telecom_recycled := false

func _ready() -> void:
    randomize()
    TEX_BG_SKY = load("res://assets/bg_factory_skyline.jpg")
    TEX_BG_INTERIOR = load("res://assets/bg_factory_interior.jpg")
    TEX_PLATFORM = load("res://assets/platform_strip.png")
    TEX_ECO_BATTERY = load("res://assets/eco_battery.png")
    TEX_TELECOM = load("res://assets/telecom_scrap.png")
    TEX_SERVER = load("res://assets/server_rack.png")
    _build_background()
    _build_level()
    _build_props()
    _build_station()
    _build_player()
    _build_fx()
    _build_touch()
    _build_ui()
    _spawn_enemies()
    GameState.language_changed.connect(_refresh_ui)
    _show_menu()
    if GameState.autostart:
        GameState.autostart = false
        _start_game()

func _build_background() -> void:
    # Two oversized copies of the skyline give depth without a hard edge
    # at any point in the level.
    _add_bg_sprite(TEX_BG_SKY, 1.15, Color(0.62, 0.62, 0.72, 1.0), -30, 0.06)
    _add_bg_sprite(TEX_BG_SKY, 1.42, Color(0.30, 0.31, 0.38, 0.85), -29, 0.14)

    var tint := ColorRect.new()
    tint.color = Color(0.02, 0.03, 0.05, 0.34)
    tint.position = Vector2(-400, 0)
    tint.size = Vector2(6000, 720)
    tint.z_index = -28
    add_child(tint)

func _add_bg_sprite(tex: Texture2D, s: float, tint: Color, z: int, factor: float) -> void:
    var sp := Sprite2D.new()
    sp.texture = tex
    sp.centered = true
    sp.position = Vector2(1800, 360)
    sp.scale = Vector2(s, s)
    sp.modulate = tint
    sp.z_index = z
    sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(sp)
    bg_layers.append({"node": sp, "factor": factor, "base_x": 1800.0})

func _build_level() -> void:
    var g := StaticBody2D.new()
    var gs := CollisionShape2D.new()
    var gr := RectangleShape2D.new()
    gr.size = Vector2(3600, 80)
    gs.shape = gr
    gs.position = Vector2(1400, GROUND_TOP + 40)
    g.add_child(gs)
    g.collision_layer = 1
    g.collision_mask = 0
    add_child(g)
    var dirt := ColorRect.new()
    dirt.color = Color(0.13, 0.09, 0.07)
    dirt.position = Vector2(-400, GROUND_TOP + 90)
    dirt.size = Vector2(3600, 130)
    dirt.z_index = -2
    add_child(dirt)
    _make_world_texture(TEX_PLATFORM, Vector2(-400, GROUND_TOP - 20), Vector2(3600, 150), -1)
    var platforms := [
        Vector4(620, 450, 360, 40),
        Vector4(1150, 350, 360, 40),
        Vector4(1750, 450, 360, 40),
        Vector4(2350, 360, 300, 40),
    ]
    for p in platforms:
        var b := StaticBody2D.new()
        var cs := CollisionShape2D.new()
        var r := RectangleShape2D.new()
        r.size = Vector2(p.z, p.w)
        cs.shape = r
        cs.position = Vector2(p.x, p.y)
        b.add_child(cs)
        b.collision_layer = 1
        add_child(b)
        _make_world_texture(
            TEX_PLATFORM,
            Vector2(p.x - p.z/2, p.y - p.w/2 - 20),
            Vector2(p.z, 100),
            -1
        )
    var ext := ColorRect.new()
    ext.color = Color(0.15, 0.9, 0.4, 0.35)
    ext.position = Vector2(LEVEL_END, GROUND_TOP - 240)
    ext.size = Vector2(120, 240)
    add_child(ext)

func _make_world_texture(tex: Texture2D, pos: Vector2, size: Vector2, z: int) -> TextureRect:
    var tr := TextureRect.new()
    tr.texture = tex
    tr.position = pos
    tr.size = size
    tr.stretch_mode = TextureRect.STRETCH_TILE
    tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tr.z_index = z
    add_child(tr)
    return tr

func _build_props() -> void:
    _add_server_prop(360.0, 0.34)
    _add_server_prop(1230.0, 0.30)
    _add_server_prop(2180.0, 0.36)
    _add_server_prop(2570.0, 0.28)
    _build_telecom()

func _add_server_prop(x: float, s: float) -> void:
    var sp := Sprite2D.new()
    sp.texture = TEX_SERVER
    sp.centered = false
    sp.scale = Vector2(s, s)
    sp.position = Vector2(x, GROUND_TOP - TEX_SERVER.get_height() * s)
    sp.modulate = Color(0.52, 0.52, 0.64, 0.9)
    sp.z_index = -3
    add_child(sp)

func _build_telecom() -> void:
    var s := 0.40
    telecom_node = Sprite2D.new()
    telecom_node.texture = TEX_TELECOM
    telecom_node.centered = false
    telecom_node.scale = Vector2(s, s)
    telecom_node.position = Vector2(
        1950.0 - TEX_TELECOM.get_width() * s * 0.5,
        GROUND_TOP - TEX_TELECOM.get_height() * s
    )
    telecom_node.z_index = -2
    add_child(telecom_node)

    var glow := Sprite2D.new()
    glow.texture = _radial_texture(Color(0.20, 1.0, 0.45, 0.30), 128)
    glow.position = Vector2(1950, GROUND_TOP - 24)
    glow.scale = Vector2(2.8, 0.8)
    glow.z_index = -2
    add_child(glow)

func _radial_texture(color: Color, size: int) -> GradientTexture2D:
    var grad := Gradient.new()
    grad.offsets = PackedFloat32Array([0.0, 1.0])
    grad.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = size
    tex.height = size
    return tex

func _build_station() -> void:
    station_node = Node2D.new()
    station_node.position = Vector2(STATION_X, GROUND_TOP)
    station_node.z_index = -1
    add_child(station_node)

    var glow := Sprite2D.new()
    glow.texture = _radial_texture(Color(0.25, 1.0, 0.45, 0.38), 128)
    glow.position = Vector2(0, -105)
    glow.scale = Vector2(1.8, 1.8)
    glow.z_index = -1
    station_node.add_child(glow)

    var battery := Sprite2D.new()
    battery.texture = TEX_ECO_BATTERY
    var s := 0.24
    battery.scale = Vector2(s, s)
    battery.position = Vector2(0, -TEX_ECO_BATTERY.get_height() * s * 0.5)
    station_node.add_child(battery)

func _build_player() -> void:
    player = PlayerScript.new()
    player.position = Vector2(220, 500)
    add_child(player)
    player.shoot_requested.connect(_on_player_shoot)
    player.died.connect(_on_player_died)
    player.health_changed.connect(func(_h, _m): _refresh_hud())
    player.shield_changed.connect(func(_s, _m): _refresh_hud())
    var cam := Camera2D.new()
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    cam.limit_left = 0
    cam.limit_right = 3200
    cam.limit_top = 0
    cam.limit_bottom = 720
    player.add_child(cam)
    cam.make_current()

func _build_fx() -> void:
    fx = FxScript.new()
    fx.provider = self
    fx.z_index = 5
    add_child(fx)

func _circle_tex(radius: int, color: Color) -> ImageTexture:
    var size := radius * 2
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0,0,0,0))
    var r2 := float(radius * radius)
    for y in size:
        for x in size:
            var dx := float(x) + 0.5 - radius
            var dy := float(y) + 0.5 - radius
            if dx*dx + dy*dy <= r2:
                img.set_pixel(x, y, color)
    return ImageTexture.create_from_image(img)

func _build_touch() -> void:
    touch_layer = CanvasLayer.new()
    touch_layer.layer = 20
    add_child(touch_layer)
    var tn := _circle_tex(64, Color(0.15, 0.18, 0.22, 0.6))
    var tp := _circle_tex(64, Color(0.4, 0.9, 0.5, 0.8))
    var layout := [
        ["move_left", Vector2(150, 600)], ["move_right", Vector2(310, 600)],
        ["jump", Vector2(230, 450)], ["fire", Vector2(1130, 600)],
        ["recycle", Vector2(970, 600)], ["switch_weapon", Vector2(1050, 450)],
    ]
    for entry in layout:
        var b := TouchScreenButton.new()
        b.texture_normal = tn
        b.texture_pressed = tp
        b.position = entry[1] - Vector2(64, 64)
        b.z_index = 100
        touch_layer.add_child(b)
        b.pressed.connect(_touch_press.bind(entry[0]))
        b.released.connect(_touch_release.bind(entry[0]))

func _touch_press(action: String) -> void:
    Input.action_press(action)

func _touch_release(action: String) -> void:
    Input.action_release(action)

func _make_label(parent: Control, text: String, pos: Vector2, size: int = 22) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    parent.add_child(l)
    return l

func _make_button(parent: Control, text: String, pos: Vector2, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.custom_minimum_size = Vector2(220, 64)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(cb)
    parent.add_child(b)
    return b

func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 10
    add_child(ui)
    hud = Control.new()
    hud.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.add_child(hud)
    var hud_bg := ColorRect.new()
    hud_bg.color = Color(0.02, 0.03, 0.04, 0.58)
    hud_bg.position = Vector2(10, 10)
    hud_bg.size = Vector2(430, 185)
    hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hud_bg)
    hud_labels["health"] = _make_label(hud, "", Vector2(20, 16), 22)
    hud_labels["shield"] = _make_label(hud, "", Vector2(20, 48), 22)
    hud_labels["weapon"] = _make_label(hud, "", Vector2(20, 80), 22)
    hud_labels["materials"] = _make_label(hud, "", Vector2(20, 120), 18)
    hud_labels["eco"] = _make_label(hud, "", Vector2(20, 150), 20)
    hud_labels["eco"].add_theme_color_override("font_color", Color(0.30, 1.0, 0.50))
    hud_labels["warning"] = _make_label(hud, "", Vector2(480, 16), 26)
    hud_labels["warning"].add_theme_color_override("font_color", Color(1,0.8,0.2))
    hud_labels["hint"] = _make_label(hud, "", Vector2(420, 680), 18)
    hud_labels["hint"].add_theme_color_override("font_color", Color(0.7,0.8,0.9))
    hud_labels["interact"] = _make_label(hud, "", Vector2(420, 646), 20)
    hud_labels["interact"].add_theme_color_override("font_color", Color(0.30, 1.0, 0.50))
    craft_panel = Control.new()
    craft_panel.position = Vector2(860, 120)
    craft_panel.size = Vector2(380, 420)
    ui.add_child(craft_panel)
    var cpbg := ColorRect.new()
    cpbg.color = Color(0.08, 0.1, 0.12, 0.9)
    cpbg.size = Vector2(380, 420)
    craft_panel.add_child(cpbg)
    hud_labels["craft_title"] = _make_label(craft_panel, "", Vector2(16, 12), 22)
    var idx := 0
    for key in ["cannon", "electric", "shield"]:
        var b := _make_button(craft_panel, key.capitalize(), Vector2(16, 60 + idx * 110), _craft.bind(key))
        b.custom_minimum_size = Vector2(348, 90)
        craft_buttons[key] = b
        idx += 1
    craft_panel.visible = false
    menu_layer = _make_overlay(ui)
    hud_labels["menu_title"] = _make_label(menu_layer, "SCRAPFALL", Vector2(480, 140), 56)
    _make_button(menu_layer, "PLAY", Vector2(520, 280), _start_game)
    hud_labels["lang_btn"] = _make_button(menu_layer, "LANGUE", Vector2(520, 360), _cycle_language)
    hud_labels["credits_btn"] = _make_button(menu_layer, "CREDITS", Vector2(520, 440), _toggle_credits)
    _make_button(menu_layer, "QUIT", Vector2(520, 520), func(): get_tree().quit())
    hud_labels["credits_text"] = _make_label(menu_layer, "", Vector2(420, 600), 16)
    hud_labels["credits_text"].visible = false
    pause_layer = _make_overlay(ui)
    hud_labels["pause_title"] = _make_label(pause_layer, "", Vector2(540, 160), 48)
    hud_labels["resume_btn"] = _make_button(pause_layer, "", Vector2(520, 300), _resume)
    hud_labels["pause_menu_btn"] = _make_button(pause_layer, "", Vector2(520, 390), _to_menu)
    pause_layer.visible = false
    end_layer = _make_overlay(ui)
    hud_labels["end_title"] = _make_label(end_layer, "", Vector2(440, 120), 48)
    hud_labels["end_score"] = _make_label(end_layer, "", Vector2(440, 220), 28)
    hud_labels["end_rank"] = _make_label(end_layer, "", Vector2(440, 270), 28)
    hud_labels["end_restart_btn"] = _make_button(end_layer, "", Vector2(520, 360), _restart)
    hud_labels["end_menu_btn"] = _make_button(end_layer, "", Vector2(520, 450), _to_menu)
    end_layer.visible = false
    _refresh_ui()
    _refresh_hud()

func _make_overlay(parent: CanvasLayer) -> Control:
    var c := Control.new()
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    parent.add_child(c)
    var photo := TextureRect.new()
    photo.texture = TEX_BG_INTERIOR
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.set_anchors_preset(Control.PRESET_FULL_RECT)
    photo.modulate = Color(0.55, 0.60, 0.70, 0.75)
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.add_child(photo)
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.03, 0.04, 0.72)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    c.add_child(bg)
    return c

func _spawn_enemies() -> void:
    var data := [
        ["walker", Vector2(700, GROUND_TOP)],
        ["electro", Vector2(1350, GROUND_TOP)],
        ["drone", Vector2(1600, 600)],
        ["walker", Vector2(2100, GROUND_TOP)],
        ["boss", Vector2(2650, GROUND_TOP)],
    ]
    for d in data:
        var e := EnemyScript.new()
        add_child(e)
        e.setup(d[0], d[1], player)
        e.destroyed.connect(_on_enemy_destroyed)
        e.shoot_requested.connect(_on_enemy_shoot)
        e.melee_player.connect(_on_enemy_melee)
        enemies.append(e)
        total_enemies += 1

func _on_player_shoot(pos: Vector2, dir: int, weapon: String) -> void:
    var dmg := 1
    var spd := 700.0
    match weapon:
        "cannon": dmg = 3; spd = 620.0
        "electric": dmg = 2; spd = 820.0
    pbullets.append({"pos": pos, "vel": Vector2(dir * spd, 0), "dmg": dmg, "life": 1.3})

func _on_enemy_shoot(pos: Vector2, dir: int, kind: String) -> void:
    var spd := 300.0 if kind == "electro" else 260.0
    ebullets.append({"pos": pos, "vel": Vector2(dir * spd, 0), "life": 3.0, "electric": kind == "electro"})

func _on_enemy_melee() -> void:
    if player: player.take_damage(1)

func _on_enemy_destroyed(e: Node2D) -> void:
    var p := PileScript.new()
    add_child(p)
    p.setup(e)
    p.dismantled.connect(_on_pile_dismantled)
    p.regenerated.connect(_on_pile_regenerated)
    piles.append(p)
    _spawn_burst(e.position, Color(0.9, 0.5, 0.2), 10)
    AudioManager.play_sfx("destroy")

func _on_pile_dismantled(p: Node2D) -> void:
    var e = p.enemy
    var mats := {}
    match e.kind:
        "walker": mats = {"iron": 3, "aluminium": 2}
        "electro": mats = {"copper": 3, "electronics": 2}
        "drone": mats = {"copper": 1, "aluminium": 2, "electronics": 1}
        "boss": mats = {"iron": 6, "aluminium": 4, "copper": 3, "electronics": 3, "batteries": 2}
    for k in mats:
        GameState.add(k, mats[k])
    GameState.eco_score += 5
    e.permanently_dead = true
    e.queue_free()
    enemies.erase(e)
    piles.erase(p)
    dismantled_count += 1
    p.queue_free()
    _spawn_burst(p.position, Color(0.2, 1.0, 0.5), 16)
    AudioManager.play_sfx("recycle")
    _refresh_hud()

func _on_pile_regenerated(p: Node2D) -> void:
    p.enemy.revive()
    piles.erase(p)
    p.queue_free()
    _spawn_burst(p.position, Color(1.0, 0.85, 0.2), 12)
    AudioManager.play_sfx("regen")

func _on_player_died() -> void:
    state = "gameover"
    touch_layer.visible = false
    end_layer.visible = true
    hud_labels["interact"].text = ""
    hud_labels["end_title"].text = GameState.t("game_over")
    hud_labels["end_score"].text = GameState.t("score") + ": %d%%" % _score_pct()
    hud_labels["end_rank"].text = GameState.t("rank") + ": " + _rank()
    hud_labels["end_restart_btn"].text = GameState.t("restart")
    hud_labels["end_menu_btn"].text = GameState.t("menu")
    get_tree().paused = true
    end_layer.process_mode = Node.PROCESS_MODE_ALWAYS

func _score_pct() -> int:
    if total_enemies == 0: return 0
    return int(round(100.0 * dismantled_count / total_enemies))

func _rank() -> String:
    var s := _score_pct()
    if s >= 90: return "GOLD"
    if s >= 60: return "SILVER"
    return "BRONZE"

func _process(delta: float) -> void:
    if bg_layers.size() > 0 and player:
        var cx := player.global_position.x
        for b in bg_layers:
            b.node.position.x = b.base_x - (cx - 220.0) * b.factor
    if state != "playing":
        return
    _update_bullets(delta)
    _update_piles(delta)
    _update_station()
    _update_checkpoint()
    _update_telecom()
    _update_warning()
    if player.position.x > LEVEL_END:
        _complete_level()
    fx.queue_redraw()

func _update_bullets(delta: float) -> void:
    for i in range(pbullets.size() - 1, -1, -1):
        var b = pbullets[i]
        b.pos += b.vel * delta
        b.life -= delta
        var hit := false
        for e in enemies:
            if e.state == "alive" and (e.position + Vector2(0, -24)).distance_to(b.pos) < 40:
                e.take_damage(b.dmg)
                _spawn_burst(b.pos, Color(1.0, 0.9, 0.3), 4)
                hit = true
                break
        if hit or b.life <= 0:
            pbullets.remove_at(i)
    for i in range(ebullets.size() - 1, -1, -1):
        var b = ebullets[i]
        b.pos += b.vel * delta
        b.life -= delta
        if (player.position + Vector2(0, -28)).distance_to(b.pos) < 30:
            player.take_damage(1, b.electric)
            _spawn_burst(b.pos, Color(0.4, 0.8, 1.0), 6)
            ebullets.remove_at(i)
            continue
        if b.life <= 0:
            ebullets.remove_at(i)

func _update_piles(delta: float) -> void:
    for p in piles:
        if p.done: continue
        if p.position.distance_to(player.position) < 95 and Input.is_action_pressed("recycle"):
            p.recycle(delta)
        else:
            p.decay(delta)

func _update_station() -> void:
    var near := player.position.distance_to(station_node.position) < 150
    craft_panel.visible = near
    if near:
        _refresh_craft()

func _update_checkpoint() -> void:
    if player.position.x > 900 and checkpoint.x < 900:
        checkpoint = Vector2(900, 500)
        hud_labels["hint"].text = GameState.t("checkpoint")
        hud_labels["hint"].modulate.a = 1.0
    if player.position.x > 1900 and checkpoint.x < 1900:
        checkpoint = Vector2(1900, 500)
        hud_labels["hint"].text = GameState.t("checkpoint")
        hud_labels["hint"].modulate.a = 1.0
    hud_labels["hint"].modulate.a = maxf(0.0, hud_labels["hint"].modulate.a - 0.005)

func _update_telecom() -> void:
    if telecom_recycled or telecom_node == null:
        hud_labels["interact"].text = ""
        return
    var focus := Vector2(1950.0, GROUND_TOP - 40.0)
    if player.position.distance_to(focus) < 155.0:
        hud_labels["interact"].text = GameState.t("telecom_hint")
        hud_labels["interact"].modulate.a = 1.0
        if Input.is_action_just_pressed("recycle"):
            telecom_recycled = true
            GameState.add("copper", 5)
            GameState.add("electronics", 2)
            GameState.eco_score += 15
            telecom_node.queue_free()
            telecom_node = null
            _spawn_burst(focus + Vector2(0, -90), Color(0.2, 1.0, 0.5), 30)
            hud_labels["interact"].text = ""
            AudioManager.play_sfx("recycle")
            _refresh_hud()
    else:
        hud_labels["interact"].text = ""

func _update_warning() -> void:
    var warn := false
    for p in piles:
        if not p.done and p.timer < 3.0:
            warn = true
    hud_labels["warning"].text = GameState.t("warning") if warn else ""

func _spawn_burst(pos: Vector2, color: Color, n: int) -> void:
    for i in n:
        particles.append({
            "pos": pos, "vel": Vector2(randf_range(-120,120), randf_range(-160,40)),
            "life": randf_range(0.3,0.7), "color": color
        })

func draw_fx(c: CanvasItem) -> void:
    for b in pbullets:
        c.draw_circle(b.pos, 5, Color(1.0, 0.9, 0.3))
    for b in ebullets:
        c.draw_circle(b.pos, 6, Color(0.4, 0.8, 1.0))
    for p in particles:
        c.draw_circle(p.pos, 3, p.color)

func _physics_process(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p = particles[i]
        p.pos += p.vel * delta
        p.vel.y += 400 * delta
        p.life -= delta
        if p.life <= 0:
            particles.remove_at(i)

func _refresh_hud() -> void:
    if not player: return
    hud_labels["health"].text = "%s %d/%d" % [GameState.t("health"), player.health, player.max_health]
    hud_labels["shield"].text = "%s %d/%d" % [GameState.t("shield"), player.shield, player.max_shield]
    hud_labels["weapon"].text = "%s: %s" % [GameState.t("weapon"), player.weapon.to_upper()]
    var parts := []
    for k in Config.MATERIALS:
        parts.append("%s:%d" % [k.capitalize(), GameState.inventory.get(k, 0)])
    hud_labels["materials"].text = " | ".join(parts)
    hud_labels["eco"].text = "ECO: %d" % GameState.eco_score

func _refresh_craft() -> void:
    hud_labels["craft_title"].text = GameState.t("station")
    for key in craft_buttons:
        var b: Button = craft_buttons[key]
        var recipe: Dictionary = Config.RECIPES[key]
        var owned := false
        if key == "shield": owned = GameState.shield_level > 0
        else: owned = GameState.unlocked.get(key, false)
        if owned:
            b.text = "%s - %s" % [recipe.label, GameState.t("unlocked")]
            b.disabled = true
        else:
            var cost_txt := ""
            for m in recipe.cost:
                cost_txt += "%s:%d " % [m.capitalize(), recipe.cost[m]]
            b.text = "%s (%s)" % [recipe.label, cost_txt]
            b.disabled = not GameState.can_afford(recipe.cost)

func _craft(key: String) -> void:
    var recipe: Dictionary = Config.RECIPES[key]
    if not GameState.can_afford(recipe.cost): return
    GameState.spend(recipe.cost)
    if key == "shield":
        GameState.shield_level += 1
        player.add_shield()
    else:
        GameState.unlocked[key] = true
        player.unlock_weapon(key)
    GameState.eco_score += 10
    AudioManager.play_sfx("craft")
    _refresh_craft()
    _refresh_hud()

func _refresh_ui() -> void:
    if not hud_labels.has("menu_title"): return
    hud_labels["menu_title"].text = "SCRAPFALL"
    hud_labels["lang_btn"].text = GameState.t("language") + " (" + GameState.language.to_upper() + ")"
    hud_labels["credits_btn"].text = GameState.t("credits")
    hud_labels["credits_text"].text = GameState.t("credits_text")
    hud_labels["pause_title"].text = GameState.t("pause")
    hud_labels["resume_btn"].text = GameState.t("resume")
    hud_labels["pause_menu_btn"].text = GameState.t("menu")
    _refresh_hud()
    _refresh_craft()

func _show_menu() -> void:
    state = "menu"
    menu_layer.visible = true
    pause_layer.visible = false
    end_layer.visible = false
    craft_panel.visible = false
    touch_layer.visible = false
    hud.visible = false
    player.set_physics_process(false)
    player.set_process(false)
    for e in enemies:
        e.set_process(false)
    if hud_labels.has("interact"):
        hud_labels["interact"].text = ""

func _start_game() -> void:
    state = "playing"
    menu_layer.visible = false
    pause_layer.visible = false
    end_layer.visible = false
    hud.visible = true
    touch_layer.visible = true
    GameState.reset_progress()
    player.set_physics_process(true)
    player.set_process(true)
    for e in enemies:
        e.set_process(true)
    hud_labels["interact"].text = ""
    player.respawn(Vector2(220, 500))

func _resume() -> void:
    get_tree().paused = false
    state = "playing"
    pause_layer.visible = false

func _to_menu() -> void:
    get_tree().paused = false
    GameState.autostart = false
    get_tree().reload_current_scene()

func _restart() -> void:
    get_tree().paused = false
    GameState.autostart = true
    get_tree().reload_current_scene()

func _complete_level() -> void:
    if state != "playing": return
    state = "complete"
    touch_layer.visible = false
    end_layer.visible = true
    hud_labels["interact"].text = ""
    hud_labels["end_title"].text = GameState.t("complete")
    hud_labels["end_score"].text = "%s: %d%%   ECO: %d" % [GameState.t("score"), _score_pct(), GameState.eco_score]
    hud_labels["end_rank"].text = "%s: %s" % [GameState.t("rank"), _rank()]
    hud_labels["end_restart_btn"].text = GameState.t("restart")
    hud_labels["end_menu_btn"].text = GameState.t("menu")
    get_tree().paused = true
    end_layer.process_mode = Node.PROCESS_MODE_ALWAYS

func _cycle_language() -> void:
    var idx := ["fr", "ar", "en"].find(GameState.language)
    GameState.set_language(["fr", "ar", "en"][(idx + 1) % 3])

func _toggle_credits() -> void:
    hud_labels["credits_text"].visible = not hud_labels["credits_text"].visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and state == "playing":
        state = "paused"
        get_tree().paused = true
        pause_layer.visible = true
        pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    elif event.is_action_pressed("pause") and state == "paused":
        _resume()
