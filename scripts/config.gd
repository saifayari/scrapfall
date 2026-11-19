extends Node

const PLAYER_SPEED := 220.0
const PLAYER_ACCEL := 1600.0
const PLAYER_FRICTION := 2200.0
const PLAYER_JUMP := -440.0
const PLAYER_GRAVITY := 1500.0
const PLAYER_COYOTE := 0.10
const PLAYER_BUFFER := 0.12
const PLAYER_IFRAME := 0.7
const PLAYER_MAX_HEALTH := 5
const MATERIALS := ["iron", "aluminium", "copper", "electronics", "batteries"]

const RECIPES := {
    "cannon": {"cost": {"iron": 8, "aluminium": 4}, "label": "Scrap Cannon"},
    "electric": {"cost": {"copper": 5, "electronics": 4}, "label": "Electric Pulse Gun"},
    "shield": {"cost": {"iron": 10, "aluminium": 5}, "label": "Shield Upgrade"},
}

const STRINGS := {
    "fr": {
        "play": "JOUER", "resume": "REPRENDRE", "menu": "MENU", "quit": "QUITTER",
        "language": "LANGUE", "credits": "CREDITS", "pause": "PAUSE",
        "game_over": "SYSTEME HORS LIGNE", "restart": "RECOMMENCER",
        "complete": "ZONE SECURISEE", "score": "SCORE DE RECYCLAGE",
        "rank": "RANG ECO", "health": "VIE", "shield": "BOUCLIER",
        "weapon": "ARME", "materials": "MATERIAUX", "warning": "REGENERATION !",
        "checkpoint": "POINT DE CONTROLE",
        "credits_text": "SCRAPFALL - Recycle or Rebuild\nGreen Hackathon prototype.",
        "unlocked": "Debloque", "station": "STATION DE RECYCLAGE",
        "telecom_hint": "DECHET TELECOM - APPUYEZ SUR K"
    },
    "en": {
        "play": "PLAY", "resume": "RESUME", "menu": "MENU", "quit": "QUIT",
        "language": "LANGUAGE", "credits": "CREDITS", "pause": "PAUSED",
        "game_over": "SYSTEM OFFLINE", "restart": "RESTART",
        "complete": "ZONE SECURED", "score": "RECYCLING SCORE",
        "rank": "ECO RANK", "health": "HEALTH", "shield": "SHIELD",
        "weapon": "WEAPON", "materials": "MATERIALS", "warning": "REGENERATING!",
        "checkpoint": "CHECKPOINT",
        "credits_text": "SCRAPFALL - Recycle or Rebuild\nGreen Hackathon prototype.",
        "unlocked": "Unlocked", "station": "RECYCLING STATION",
        "telecom_hint": "TELECOM SCRAP - PRESS K"
    },
    "ar": {
        "play": "العب", "resume": "متابعة", "menu": "القائمة", "quit": "خروج",
        "language": "اللغة", "credits": "شكر", "pause": "إيقاف",
        "game_over": "النظام معطل", "restart": "إعادة", "complete": "المنطقة آمنة",
        "score": "نتيجة إعادة التدوير", "rank": "الرتبة البيئية", "health": "صحة",
        "shield": "درع", "weapon": "سلاح", "materials": "مواد", "warning": "إعادة توليد!",
        "checkpoint": "نقطة تفتيش",
        "credits_text": "SCRAPFALL\nنموذج هاكاثون",
        "unlocked": "مفتوح", "station": "محطة إعادة التدوير",
        "telecom_hint": "مخلفات اتصالات - اضغط K"
    },
}

func _ready() -> void:
    _register_input()

func _register_input() -> void:
    var keys := {
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "jump": [KEY_SPACE, KEY_W, KEY_UP], "fire": [KEY_J],
        "recycle": [KEY_K], "switch_weapon": [KEY_Q], "pause": [KEY_ESCAPE, KEY_P],
    }
    for a in keys:
        if not InputMap.has_action(a):
            InputMap.add_action(a)
        for k in keys[a]:
            var ev := InputEventKey.new()
            ev.physical_keycode = k
            if not InputMap.action_has_event(a, ev):
                InputMap.action_add_event(a, ev)
    var pad := {
        "move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
        "jump": [JOY_BUTTON_A], "fire": [JOY_BUTTON_X],
        "recycle": [JOY_BUTTON_Y], "switch_weapon": [JOY_BUTTON_RIGHT_SHOULDER],
        "pause": [JOY_BUTTON_START],
    }
    for a in pad:
        for b in pad[a]:
            var ev := InputEventJoypadButton.new()
            ev.button_index = b
            if not InputMap.action_has_event(a, ev):
                InputMap.action_add_event(a, ev)
