extends Node

signal inventory_changed
signal language_changed

var inventory := {"iron": 0, "aluminium": 0, "copper": 0, "electronics": 0, "batteries": 0}
var unlocked := {"standard": true, "cannon": false, "electric": false}
var shield_level := 0
var eco_score := 0
var language := "fr"

func add(k: String, n: int) -> void:
    inventory[k] = inventory.get(k, 0) + n
    inventory_changed.emit()

func can_afford(cost: Dictionary) -> bool:
    for k in cost:
        if inventory.get(k, 0) < cost[k]:
            return false
    return true

func spend(cost: Dictionary) -> void:
    for k in cost:
        inventory[k] -= cost[k]
    inventory_changed.emit()

func t(key: String) -> String:
    return Config.STRINGS.get(language, Config.STRINGS["fr"]).get(key, key)

func set_language(l: String) -> void:
    language = l
    language_changed.emit()

var autostart := false

func reset_progress() -> void:
    for k in inventory:
        inventory[k] = 0
    unlocked = {"standard": true, "cannon": false, "electric": false}
    shield_level = 0
    eco_score = 0
    inventory_changed.emit()
