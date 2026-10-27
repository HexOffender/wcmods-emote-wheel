# Emote wheel

A ring of your cat's emotes and the game's photo-mode poses, for [wcmods](https://github.com/HexOffender/warrior-cats-mods)
(Clan Mod Studio), the mod manager for *Warrior Cats: Clans of the Forest*.

**Hold T** (or **D-pad down** on a controller) and the wheel opens in the middle of the screen. Point at
an emote or a pose with the mouse or the right stick, and **let go** to play it. Let go with the pointer
in the middle to close it without playing anything, or click to play the one pointed at straight away.
While the wheel is open the world holds still, as in photo mode, so the camera doesn't turn with the mouse.

- **Emotes:** every emote your mods have: animations made in Blender that a mod's `animations.json`
  marks as an emote (Clan Mod Studio's Animations page makes them). Up to eight on a ring.
- **Poses:** the game's 14 photo-mode poses (Feral Frenzy, Loafing Lunar, Yoga Master...), named as the
  game names them in your language, on two rings of seven. Your cat holds a pose until it moves.
- **More rings:** 1 and 2, the mouse wheel, or LB and RB turn the page.
- Choosing what's playing again stops it, and walking off ends an emote or a pose, as the mod menu's
  Emotes page does.

It's drawn with the game's own UI art: the cat maker's round slots, the gold ring it puts round the chosen
one, its sitting-cat icon for the poses, and the paw for emotes.

## Getting it

- Download `emote-wheel-<version>.zip` from [Releases](../../releases) and drop it on Clan Mod Studio's
  Mods page, or `python wcmods.py add emote-wheel-<version>.zip` in your wcmods folder.
- It's an in-game Lua script, so like any script it runs only with **mods that run code allowed**
  (Options, on Clan Mod Studio's Settings and repair page), and it needs the script loader (UE4SS,
  which Get set up installs). Then Apply to game (or press Play).
- It needs wcmods 0.3.0 or newer (for `Game.anims` and the emotes' list).
- Emotes come from other mods: with none installed the wheel has just the poses.

## Settings

`settings.json` in the mod's folder; the mod menu (Insert) has a page for them under Mods.

| Setting | What it does |
|---|---|
| `key` | The key to hold for the wheel, by Unreal's name (`T`, `B`, `Tab`...). The game doesn't use T |
| `pad` | The controller button to hold (`Gamepad_DPad_Down`, `Gamepad_DPad_Up`...). The game doesn't use the D-pad while you play |
| `poses` | `true` puts the game's photo-mode poses on the wheel |
| `pause` | `true` holds the world still while the wheel is open (and the camera with it) |
| `mouse` | How far the mouse moves the pointer: 1 as made, 2 twice as far |

## How it's made

`emote-wheel/` is the mod as it goes in your mods folder:

```
emote-wheel/
  mod.json          its name, version and the game builds it was made for
  settings.json     its settings (MOD.settings in the script)
  scripts/main.lua  the wheel
```

It uses only what any script mod can, from wcmods' [docs/scripting.md](https://github.com/HexOffender/warrior-cats-mods/blob/main/docs/scripting.md):
`Game.anims` (the emotes' list, playing and stopping), `Game.onFrame`, `Game.pressed` and `Game.keyDown`
(the game's own input, keyboard and controller), and `WCModsDraw` (text and images in the game's UI).
The mouse and the stick are read as the game reads them (`GetInputAnalogKeyState` on `MouseX`, `MouseY`,
`Gamepad_RightX`, `Gamepad_RightY`); the world holds still with `SetGamePaused`, during which the
controller still reads input and the game's camera doesn't turn. The poses are the game's own sequences,
`A_CatMaster_Pose_Photo_Mode_1` to `_14`, played as a loop.

A test can point the wheel without a mouse: the UE4SS shared variable `EmoteWheel.point` set to `"x,y"`
(right and down from the middle, up to 1) points it there while it's open.

To try a change: `python wcmods.py agent install --with path\to\emote-wheel` in your wcmods folder
installs a test build with it, and `agent key T --hold 3` holds the key.

## Releasing

1. Raise `"version"` in `emote-wheel/mod.json`. After a game update, try it on the new build and add its
   number to `"game_builds"` (`python wcmods.py game build` shows it).
2. `python tools/pack.py` makes `dist/emote-wheel-<version>.zip`.
3. Make a GitHub release tagged `v<version>` with that .zip attached.
