extends Node2D

const ARENA := Rect2(40.0, 60.0, 1200.0, 580.0)
const TOWER_POS := Vector2(640.0, 360.0)
const TURRET_SPOTS := [Vector2(260.0, 180.0), Vector2(980.0, 180.0), Vector2(260.0, 520.0), Vector2(980.0, 520.0)]
const AEGIS_POS := Vector2(1120.0, 120.0)

var state := "day"
var day_number := 1
var day_timer := 60.0
var dusk_timer := 10.0
var night_timer := 90.0
var wave_timer := 0.0
var acid_timer := 0.0
var swarm_timer := 0.0
var amalgam_timer := 0.0

var player := {
    "pos": Vector2(640.0, 360.0),
    "vel": Vector2.ZERO,
    "health": 100.0,
    "max_health": 100.0,
    "shoot_cd": 0.0,
    "facing": Vector2.RIGHT,
    "invuln": 0.0
}

var enemies := []
var piles := []
var turrets := []
var bullets := []
var acid_pools := []
var particles := []

var resources := {"scrap": 0, "alloy": 0, "lithium": 0, "core": 0}
var tower_health := 100.0
var tower_max := 100.0
var signal_strength := 100.0

var purification_index := -1
var purification_progress := 0.0
var shockwaves := []

var ui: CanvasLayer
var labels := {}

func _ready() -> void:
    _register_input()
    _build_ui()
    _start_day()

func _register_input() -> void:
    var actions := {
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "move_up": [KEY_W, KEY_UP],
        "move_down": [KEY_S, KEY_DOWN],
        "fire": [KEY_J],
        "interact": [KEY_E, KEY_K],
        "build_sentry": [KEY_B],
        "build_emp": [KEY_V],
        "trade": [KEY_T],
        "pause": [KEY_ESCAPE, KEY_P],
    }
    for a in actions:
        if not InputMap.has_action(a):
            InputMap.add_action(a)
        for k in actions[a]:
            var ev := InputEventKey.new()
            ev.physical_keycode = k
            if not InputMap.action_has_event(a, ev):
                InputMap.action_add_event(a, ev)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 10
    add_child(ui)
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.add_child(root)
    labels["phase"] = _label(root, "DAY", Vector2(20, 12), 24)
    labels["timer"] = _label(root, "60", Vector2(20, 42), 22)
    labels["scrap"] = _label(root, "Scrap: 0", Vector2(20, 76), 18)
    labels["alloy"] = _label(root, "Alloys: 0", Vector2(20, 100), 18)
    labels["lithium"] = _label(root, "Lithium: 0", Vector2(20, 124), 18)
    labels["core"] = _label(root, "Nano-Cores: 0", Vector2(20, 148), 18)
    labels["tower"] = _label(root, "Tower: 100", Vector2(20, 182), 18)
    labels["signal"] = _label(root, "Signal: 100%", Vector2(20, 206), 18)
    labels["prompt"] = _label(root, "", Vector2(420, 660), 20)
    labels["prompt"].add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
    labels["status"] = _label(root, "", Vector2(430, 300), 34)
    labels["status"].add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    labels["help"] = _label(root, "WASD move | Mouse/J fire | E/K purify | B sentry | V EMP | T trade AEGIS | Esc pause", Vector2(20, 690), 14)

func _label(parent: Control, text: String, pos: Vector2, size: int) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    parent.add_child(l)
    return l

func _process(delta: float) -> void:
    if state == "gameover" or state == "victory":
        return
    _update_phase(delta)
    _update_player(delta)
    _update_purification(delta)
    _update_turrets(delta)
    _update_enemies(delta)
    _update_bullets(delta)
    _update_acid(delta)
    _update_particles(delta)
    _update_shockwaves(delta)
    _update_ui()
    queue_redraw()

func _update_phase(delta: float) -> void:
    match state:
        "day":
            day_timer -= delta
            if day_timer <= 0.0:
                _start_dusk()
        "dusk":
            dusk_timer -= delta
            if dusk_timer <= 0.0:
                _start_night()
        "night":
            night_timer -= delta
            wave_timer -= delta
            acid_timer -= delta
            swarm_timer -= delta
            amalgam_timer -= delta
            if wave_timer <= 0.0:
                wave_timer = 12.0
                _spawn_enemy("crawler", _edge_position())
                _spawn_enemy("crawler", _edge_position())
                if day_number >= 2 and randf() < 0.6:
                    _spawn_enemy("acid", _edge_position())
            if acid_timer <= 0.0 and day_number >= 2:
                acid_timer = 20.0
                _spawn_enemy("acid", _edge_position())
            if swarm_timer <= 0.0 and day_number >= 3:
                swarm_timer = 18.0
                _spawn_enemy("swarm", _edge_position())
            if amalgam_timer <= 0.0 and day_number >= 4:
                amalgam_timer = 28.0
                _spawn_enemy("amalgam", _edge_position())
            if night_timer <= 0.0:
                _start_day()

func _start_day() -> void:
    if day_number > 5:
        state = "victory"
        labels["status"].text = "ACT 1 COMPLETE"
        return
    state = "day"
    day_timer = 60.0
    labels["status"].text = "DAY %d" % day_number
    # Surviving night enemies retreat.
    enemies.clear()
    bullets.clear()
    acid_pools.clear()
    _spawn_piles(4)

func _start_dusk() -> void:
    state = "dusk"
    dusk_timer = 10.0
    labels["status"].text = "DUSK - PURIFY NOW"
    # Unpurified piles reform into monsters.
    for p in piles.duplicate():
        _spawn_enemy("crawler", p.pos)
        piles.erase(p)

func _start_night() -> void:
    state = "night"
    night_timer = 90.0
    wave_timer = 4.0
    acid_timer = 8.0
    swarm_timer = 12.0
    amalgam_timer = 28.0
    labels["status"].text = "NIGHT %d" % day_number
    _spawn_enemy("crawler", _edge_position())
    _spawn_enemy("crawler", _edge_position())

func _spawn_piles(n: int) -> void:
    for i in n:
        var pos := Vector2(randf_range(120.0, 1160.0), randf_range(120.0, 600.0))
        _spawn_pile(pos)

func _spawn_pile(pos: Vector2) -> void:
    for p in piles:
        if p.pos.distance_to(pos) < 64.0:
            piles.erase(p)
            _spawn_enemy("amalgam", (p.pos + pos) * 0.5)
            return
    piles.append({"pos": pos, "progress": 0.0, "purifying": false})

func _edge_position() -> Vector2:
    var side := randi() % 4
    match side:
        0: return Vector2(randf_range(40.0, 1240.0), 60.0)
        1: return Vector2(1240.0, randf_range(60.0, 620.0))
        2: return Vector2(randf_range(40.0, 1240.0), 620.0)
        _: return Vector2(40.0, randf_range(60.0, 620.0))

func _spawn_enemy(kind: String, pos: Vector2) -> void:
    var e := {
        "kind": kind,
        "pos": pos,
        "vel": Vector2.ZERO,
        "health": 0.0,
        "max_health": 0.0,
        "speed": 0.0,
        "damage": 0.0,
        "melee_cd": 0.0,
        "shoot_cd": 0.0,
        "paralysis": 0.0,
        "scale": 1.0,
        "armor": 0.0,
        "mutated": false,
        "alive": true,
        "suicide": false
    }
    match kind:
        "crawler":
            e.health = 80.0; e.max_health = 80.0; e.speed = 140.0; e.damage = 15.0; e.shoot_cd = 999.0
        "acid":
            e.health = 120.0; e.max_health = 120.0; e.speed = 90.0; e.damage = 10.0; e.shoot_cd = 2.5
        "swarm":
            e.health = 30.0; e.max_health = 30.0; e.speed = 220.0; e.damage = 20.0; e.shoot_cd = 999.0; e.suicide = true
        "amalgam":
            e.health = 450.0; e.max_health = 450.0; e.speed = 60.0; e.damage = 40.0; e.shoot_cd = 999.0
    enemies.append(e)

func _update_player(delta: float) -> void:
    var dir := Vector2.ZERO
    if Input.is_action_pressed("move_left"): dir.x -= 1.0
    if Input.is_action_pressed("move_right"): dir.x += 1.0
    if Input.is_action_pressed("move_up"): dir.y -= 1.0
    if Input.is_action_pressed("move_down"): dir.y += 1.0
    if dir.length() > 0.0:
        dir = dir.normalized()
        player.facing = dir
    player.vel = dir * 180.0
    player.pos += player.vel * delta
    player.pos.x = clamp(player.pos.x, ARENA.position.x + 16.0, ARENA.end.x - 16.0)
    player.pos.y = clamp(player.pos.y, ARENA.position.y + 16.0, ARENA.end.y - 16.0)
    player.shoot_cd = max(0.0, player.shoot_cd - delta)
    player.invuln = max(0.0, player.invuln - delta)
    if (Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and player.shoot_cd <= 0.0:
        player.shoot_cd = 0.22
        bullets.append({"pos": player.pos + player.facing * 18.0, "vel": player.facing * 420.0, "damage": 12.0, "life": 1.2, "acid": false})
    if Input.is_action_just_pressed("build_sentry"):
        _build_turret("sentry")
    if Input.is_action_just_pressed("build_emp"):
        _build_turret("emp")
    if Input.is_action_just_pressed("trade"):
        _trade_aegis()

func _build_turret(kind: String) -> void:
    var spot_index := -1
    var best := 100000.0
    for i in TURRET_SPOTS.size():
        var occupied := false
        for t in turrets:
            if t.pos.distance_to(TURRET_SPOTS[i]) < 20.0:
                occupied = true
                break
        if occupied:
            continue
        var d: float = player.pos.distance_to(TURRET_SPOTS[i])
        if d < 70.0 and d < best:
            best = d
            spot_index = i
    if spot_index < 0:
        return
    var pos: Vector2 = TURRET_SPOTS[spot_index]
    if kind == "sentry":
        if resources.scrap < 50 or resources.alloy < 1:
            return
        resources.scrap -= 50
        resources.alloy -= 1
        turrets.append({"pos": pos, "kind": "sentry", "health": 100.0, "max_health": 100.0, "cd": 0.0})
    else:
        if resources.scrap < 80 or resources.lithium < 1 or resources.alloy < 3:
            return
        resources.scrap -= 80
        resources.lithium -= 1
        resources.alloy -= 3
        turrets.append({"pos": pos, "kind": "emp", "health": 100.0, "max_health": 100.0, "cd": 0.0})

func _trade_aegis() -> void:
    if player.pos.distance_to(AEGIS_POS) > 70.0:
        return
    if resources.alloy >= 5:
        resources.alloy -= 5
        resources.lithium += 1
        labels["prompt"].text = "AEGIS: Lithium acquired"
    else:
        labels["prompt"].text = "AEGIS: Need 5 Pure Alloys"

func _update_purification(delta: float) -> void:
    purification_index = -1
    for i in piles.size():
        if piles[i].pos.distance_to(player.pos) < 48.0:
            purification_index = i
            break
    if purification_index >= 0 and Input.is_action_pressed("interact"):
        purification_progress += delta
        if purification_progress >= 0.8:
            _complete_purification(purification_index)
            purification_progress = 0.0
            purification_index = -1
    else:
        purification_progress = 0.0

func _complete_purification(index: int) -> void:
    if index < 0 or index >= piles.size():
        return
    var pos: Vector2 = piles[index].pos
    piles.remove_at(index)
    resources.alloy += 1
    resources.scrap += 2
    shockwaves.append({"pos": pos, "radius": 0.0, "max_radius": 150.0, "life": 0.35})
    for e in enemies:
        if e.pos.distance_to(pos) <= 150.0:
            _damage_enemy(e, 150.0)
            e.paralysis = 3.0

func _update_turrets(delta: float) -> void:
    for t in turrets:
        t.cd = max(0.0, t.cd - delta)
        if t.cd > 0.0:
            continue
        var target_index := -1
        var best := 320.0
        for i in enemies.size():
            var d: float = t.pos.distance_to(enemies[i].pos)
            if d < best:
                best = d
                target_index = i
        if target_index < 0:
            continue
        var target_pos: Vector2 = enemies[target_index].pos
        if t.kind == "sentry":
            bullets.append({"pos": t.pos, "vel": (target_pos - t.pos).normalized() * 360.0, "damage": 10.0, "life": 1.0, "acid": false})
            t.cd = 0.35
        else:
            for e in enemies:
                if e.pos.distance_to(t.pos) <= 130.0:
                    _damage_enemy(e, 25.0)
                    e.paralysis = max(e.paralysis, 2.0)
            t.cd = 4.0

func _update_enemies(delta: float) -> void:
    var to_remove := []
    for ei in enemies.size():
        var e = enemies[ei]
        e.paralysis = max(0.0, e.paralysis - delta)
        e.melee_cd = max(0.0, e.melee_cd - delta)
        e.shoot_cd = max(0.0, e.shoot_cd - delta)
        if e.paralysis <= 0.0:
            var target := _enemy_target(e)
            var d: Vector2 = target - e.pos
            if d.length() > 4.0:
                e.pos += d.normalized() * e.speed * delta * e.scale
            e.pos.x = clamp(e.pos.x, ARENA.position.x + 12.0, ARENA.end.x - 12.0)
            e.pos.y = clamp(e.pos.y, ARENA.position.y + 12.0, ARENA.end.y - 12.0)
        if e.kind == "acid" and e.shoot_cd <= 0.0:
            var target := _enemy_target(e)
            if e.pos.distance_to(target) < 360.0:
                bullets.append({"pos": e.pos, "vel": (target - e.pos).normalized() * 220.0, "damage": 8.0, "life": 2.0, "acid": true})
                e.shoot_cd = 2.5
        if e.kind == "swarm" and e.pos.distance_to(TOWER_POS) < 55.0:
            tower_health -= 20.0
            for t in turrets:
                if t.pos.distance_to(e.pos) < 80.0:
                    t.health -= 15.0
            if player.pos.distance_to(e.pos) < 80.0:
                _damage_player(10.0)
            e.health = 0.0
        if e.melee_cd <= 0.0:
            if e.pos.distance_to(player.pos) < 30.0:
                _damage_player(e.damage)
                e.melee_cd = 0.8
            else:
                for t in turrets:
                    if t.pos.distance_to(e.pos) < 32.0:
                        t.health -= e.damage
                        e.melee_cd = 0.8
                        break
        # Devour scrap piles at night.
        if state == "night":
            for p in piles:
                if e.pos.distance_to(p.pos) < 28.0:
                    _mutate_enemy(e)
                    piles.erase(p)
                    break
        if e.health <= 0.0:
            to_remove.append(ei)
            _spawn_pile(e.pos)
            resources.scrap += 5
            if e.kind == "amalgam":
                resources.core += 1
    for i in range(to_remove.size() - 1, -1, -1):
        enemies.remove_at(to_remove[i])
    # Remove destroyed turrets.
    var t_remove := []
    for ti in turrets.size():
        if turrets[ti].health <= 0.0:
            t_remove.append(ti)
    for i in range(t_remove.size() - 1, -1, -1):
        turrets.remove_at(t_remove[i])
    if tower_health <= 0.0:
        tower_health = 0.0
        state = "gameover"
        labels["status"].text = "TOWER CORE DESTROYED"

func _mutate_enemy(e: Dictionary) -> void:
    if e.mutated:
        return
    e.mutated = true
    e.max_health *= 1.5
    e.health = e.max_health
    e.scale *= 1.3
    e.armor = 0.3
    e.speed *= 1.2

func _damage_enemy(e: Dictionary, amount: float) -> void:
    e.health -= amount * (1.0 - e.armor)

func _enemy_target(e: Dictionary) -> Vector2:
    if turrets.size() > 0 and randf() < 0.6:
        var best := 100000.0
        var pos := TOWER_POS
        for t in turrets:
            var d: float = e.pos.distance_to(t.pos)
            if d < best:
                best = d
                pos = t.pos
        return pos
    if player.pos.distance_to(e.pos) < 300.0:
        return player.pos
    return TOWER_POS

func _damage_player(amount: float) -> void:
    if player.invuln > 0.0:
        return
    player.health -= amount
    player.invuln = 0.7
    if player.health <= 0.0:
        player.health = 0.0
        state = "gameover"
        labels["status"].text = "SAMI IS DOWN"

func _update_bullets(delta: float) -> void:
    var to_remove := []
    for i in bullets.size():
        var b = bullets[i]
        b.pos += b.vel * delta
        b.life -= delta
        var hit := false
        if b.acid:
            if player.pos.distance_to(b.pos) < 14.0:
                _damage_player(b.damage)
                acid_pools.append({"pos": b.pos, "radius": 32.0, "timer": 5.0})
                hit = true
            for t in turrets:
                if t.pos.distance_to(b.pos) < 18.0:
                    t.health -= b.damage
                    acid_pools.append({"pos": b.pos, "radius": 32.0, "timer": 5.0})
                    hit = true
                    break
        else:
            for e in enemies:
                if e.pos.distance_to(b.pos) < 16.0:
                    _damage_enemy(e, b.damage)
                    hit = true
                    break
        if hit or b.life <= 0.0 or not ARENA.grow(120.0).has_point(b.pos):
            to_remove.append(i)
    for i in range(to_remove.size() - 1, -1, -1):
        bullets.remove_at(to_remove[i])

func _update_acid(delta: float) -> void:
    var to_remove := []
    for i in acid_pools.size():
        var p = acid_pools[i]
        p.timer -= delta
        if player.pos.distance_to(p.pos) < p.radius:
            _damage_player(2.0 * delta)
        for t in turrets:
            if t.pos.distance_to(p.pos) < p.radius:
                t.health -= 2.0 * delta
        if p.timer <= 0.0:
            to_remove.append(i)
    for i in range(to_remove.size() - 1, -1, -1):
        acid_pools.remove_at(to_remove[i])

func _update_particles(delta: float) -> void:
    var to_remove := []
    for i in particles.size():
        var p = particles[i]
        p.pos += p.vel * delta
        p.vel.y += 120.0 * delta
        p.life -= delta
        if p.life <= 0.0:
            to_remove.append(i)
    for i in range(to_remove.size() - 1, -1, -1):
        particles.remove_at(to_remove[i])

func _update_shockwaves(delta: float) -> void:
    var to_remove := []
    for i in shockwaves.size():
        var s = shockwaves[i]
        s.life -= delta
        s.radius = min(s.max_radius, s.radius + 420.0 * delta)
        if s.life <= 0.0:
            to_remove.append(i)
    for i in range(to_remove.size() - 1, -1, -1):
        shockwaves.remove_at(to_remove[i])

func _update_ui() -> void:
    var phase_name := "DAY"
    var timer_value := int(day_timer)
    if state == "dusk":
        phase_name = "DUSK"
        timer_value = int(dusk_timer)
    elif state == "night":
        phase_name = "NIGHT"
        timer_value = int(night_timer)
    elif state == "gameover":
        phase_name = "GAME OVER"
        timer_value = 0
    elif state == "victory":
        phase_name = "VICTORY"
        timer_value = 0
    labels["phase"].text = "%s %d" % [phase_name, day_number]
    labels["timer"].text = "Time: %d" % timer_value
    labels["scrap"].text = "Scrap: %d" % resources.scrap
    labels["alloy"].text = "Pure Alloys: %d" % resources.alloy
    labels["lithium"].text = "Lithium: %d" % resources.lithium
    labels["core"].text = "Nano-Cores: %d" % resources.core
    labels["tower"].text = "Tower Core: %d/%d" % [int(tower_health), int(tower_max)]
    labels["signal"].text = "Signal: %d%%" % int(signal_strength)
    if purification_index >= 0:
        labels["prompt"].text = "Hold E/K to purify scrap"
    elif player.pos.distance_to(AEGIS_POS) < 70.0:
        labels["prompt"].text = "Press T to trade 5 Pure Alloys for Lithium"
    else:
        var near_spot := false
        for spot in TURRET_SPOTS:
            if player.pos.distance_to(spot) < 70.0:
                near_spot = true
                break
        if near_spot:
            labels["prompt"].text = "B: Scrap Sentry (50 Scrap + 1 Alloy) | V: EMP Pulsar (80 Scrap + 1 Lithium + 3 Alloys)"
        else:
            labels["prompt"].text = ""

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.03, 0.04, 0.06))
    draw_rect(ARENA, Color(0.08, 0.09, 0.11))
    draw_rect(ARENA, Color(0.2, 0.35, 0.55), false, 2.0)
    # Turret spots.
    for spot in TURRET_SPOTS:
        draw_circle(spot, 18.0, Color(0.12, 0.16, 0.22))
        draw_circle(spot, 18.0, Color(0.3, 0.5, 0.75), false, 2.0)
    # Tower core.
    draw_circle(TOWER_POS, 42.0, Color(0.08, 0.18, 0.32))
    draw_circle(TOWER_POS, 42.0, Color(0.2, 0.8, 1.0), false, 3.0)
    draw_string(ThemeDB.fallback_font, TOWER_POS + Vector2(-42, -52), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 1.0))
    # AEGIS.
    draw_circle(AEGIS_POS, 20.0, Color(0.2, 0.8, 0.35))
    draw_string(ThemeDB.fallback_font, AEGIS_POS + Vector2(-24, -28), "AEGIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 1.0, 0.6))
    # Acid pools.
    for p in acid_pools:
        draw_circle(p.pos, p.radius, Color(0.45, 0.85, 0.2, 0.35))
    # Scrap piles.
    for i in piles.size():
        var p = piles[i]
        var col := Color(0.55, 0.4, 0.25)
        draw_circle(p.pos, 16.0, col)
        draw_circle(p.pos, 16.0, Color(0.95, 0.75, 0.2), false, 2.0)
        if i == purification_index and purification_progress > 0.0:
            draw_arc(p.pos, 24.0, -PI / 2.0, -PI / 2.0 + TAU * (purification_progress / 0.8), 24, Color(0.2, 1.0, 0.5), 3.0)
    # Turrets.
    for t in turrets:
        var col := Color(0.35, 0.6, 0.85) if t.kind == "sentry" else Color(0.7, 0.4, 0.9)
        draw_rect(Rect2(t.pos - Vector2(12, 12), Vector2(24, 24)), col)
        draw_rect(Rect2(t.pos - Vector2(12, 12), Vector2(24, 24)), Color(0.9, 0.95, 1.0), false, 2.0)
        var ratio: float = t.health / t.max_health
        draw_rect(Rect2(t.pos + Vector2(-12, -20), Vector2(24, 4)), Color(0.2, 0.2, 0.2))
        draw_rect(Rect2(t.pos + Vector2(-12, -20), Vector2(24 * ratio, 4)), Color(0.9, 0.2, 0.2))
    # Enemies.
    for e in enemies:
        var col := Color(0.8, 0.3, 0.25)
        match e.kind:
            "acid": col = Color(0.4, 0.8, 0.35)
            "swarm": col = Color(0.9, 0.85, 0.2)
            "amalgam": col = Color(0.55, 0.35, 0.75)
        var r := 12.0
        if e.kind == "amalgam":
            r = 22.0
        elif e.kind == "swarm":
            r = 8.0
        draw_circle(e.pos, r * e.scale, col)
        draw_circle(e.pos, r * e.scale, Color(0.95, 0.95, 1.0), false, 2.0)
        var ratio: float = e.health / e.max_health
        draw_rect(Rect2(e.pos + Vector2(-r, -r - 10), Vector2(r * 2, 4)), Color(0.2, 0.2, 0.2))
        draw_rect(Rect2(e.pos + Vector2(-r, -r - 10), Vector2(r * 2 * ratio, 4)), Color(0.9, 0.2, 0.2))
    # Player.
    draw_circle(player.pos, 14.0, Color(0.2, 0.9, 0.5))
    draw_circle(player.pos, 14.0, Color(0.8, 1.0, 0.9), false, 2.0)
    draw_line(player.pos, player.pos + player.facing * 24.0, Color(0.9, 1.0, 0.95), 3.0)
    # Bullets.
    for b in bullets:
        var col := Color(0.95, 0.9, 0.3) if not b.acid else Color(0.45, 0.9, 0.25)
        draw_circle(b.pos, 4.0, col)
    # Shockwaves.
    for s in shockwaves:
        draw_arc(s.pos, s.radius, 0.0, TAU, 48, Color(0.2, 0.8, 1.0, 0.7), 3.0)
    # Off-screen threat indicators.
    for e in enemies:
        var sp: Vector2 = e.pos
        if sp.x < 20.0 or sp.x > 1260.0 or sp.y < 20.0 or sp.y > 700.0:
            var edge := Vector2(clamp(sp.x, 20.0, 1260.0), clamp(sp.y, 20.0, 700.0))
            var dir: Vector2 = (sp - edge).normalized()
            draw_line(edge, edge + dir * 18.0, Color(1.0, 0.25, 0.2), 3.0)
            draw_circle(edge + dir * 18.0, 4.0, Color(1.0, 0.25, 0.2))

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        get_tree().change_scene_to_file("res://Main.tscn")
    if (state == "gameover" or state == "victory") and (event.is_action_pressed("fire") or event.is_action_pressed("interact")):
        get_tree().reload_current_scene()
