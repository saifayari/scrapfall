# SCRAPFALL — Recycle or Rebuild

Green Hackathon prototype. Godot 4.2+, 2D, landscape 1280x720, GL Compatibility.

## Run
Open folder in Godot 4.2+ -> F5.

## Controls
- Keyboard: A/D or arrows move, Space/W/Up jump, J fire, K recycle (hold), Q switch weapon, Esc/P pause.
- Touch: left/right, jump, fire, recycle, switch. Multitouch supported.
- Gamepad: D-pad / left stick, A jump, X fire, Y recycle, RB switch, Start pause.

## Loop
Kill SCRAPBORN -> scrap piles -> hold Recycle within 95px for 2s to dismantle -> materials added -> craft at x=1500 -> piles regenerate in 8s if ignored.

## Crafting (see scripts/config.gd)
- Scrap Cannon: 8 iron + 4 aluminium
- Electric Pulse Gun: 5 copper + 4 electronics
- Shield Upgrade: 10 iron + 5 aluminium

## Export APK
JDK 17 + Android SDK + build-tools -> Editor Settings -> Export -> Android SDK paths -> Android preset -> create debug keystore -> Project -> Export.

## Swap in real art/audio
Replace `_draw()` in player.gd / enemy.gd / scrap_pile.gd with AnimatedSprite2D. Sizes in ASSETS.md. Audio: fill AudioManager.play_sfx() with OGG files.

## Limitations
- No audio (stub).
- Boss is one big walker.
- Arabic uses default font (may need Arabic-capable font).
- Bullets/particles are dictionaries, not node pools.
- No destructible crates / health pickups.

## Next steps
1. Multi-part Reclaimer boss.
2. Real audio.
3. Crates + health pickups.
4. Pooled projectile nodes.
5. Arabic font + translation CSV.
6. Real pixel art + AnimatedSprite2D.
