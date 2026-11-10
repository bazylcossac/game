---
name: char-render
description: Build, render and check the soldier models of Corp Wars (Korpo robots, Rebellion people). Use after any change to tools/blender_korpo.py, tools/blender_rebels.py, tools/blender_char.py, shaders/character.gdshaderinc, scripts/game/char_assets.gd or the body code in soldier_model.gd, and whenever the user says a character looks wrong, flickers or blinks.
---

# Rendering and checking the soldiers

Paths: Blender is `C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe`, Godot is
`C:\Users\stroj\Godot\Godot_v4.7.2-stable_win64_console.exe`. Write pictures to the scratchpad,
never into the project.

## 1. Build the meshes

```
blender --background --factory-startup --python tools/blender_korpo.py  -- --preview <dir>
blender --background --factory-startup --python tools/blender_rebels.py -- --preview <dir>
```

Each prints triangle counts per mesh and level of detail, writes `assets/models/chars/*.glb` and,
with `--preview`, renders `front`, `back`, `mid`, `far` (the three levels side by side at x = 0,
10, 20) and a bust of each class. Blender previews show shape only: skin and ties are painted by
the game, so judge colour in Godot.

A new `.glb` needs `meshes/generate_lods=false` and `animation/import=false` in its `.import`
file, then `tools/check.sh` (which re-imports). Re-importing rewrites the texture `.import` files:
finish with `git restore -- assets/textures`.

## 2. Look at them in the game

```
godot --path . -- --test=char-gallery --out=<dir> [--only=rebel|korpo] [--shots=lineup,detail,poses,far,flicker] --progress-file=<tmp> --token=test
```

- `lineup`: every class in a row, front, back and three-quarter. Check the builds differ.
- `detail`: each class alone, whole, bust and back. A class alone at the origin also catches a
  body that fails to draw.
- `poses`: stand, sprint, crouch, prone, aim up, aim down. This is where skinning breaks.
- `far`: the row at 20, 40 and 70 m through a long lens, so the far meshes fill the frame.
- On the night map, as players see them: `--test=menu-art --only=check_rebels` (or `check_korpo`,
  `check_fight`), one scene per run.

## 3. Measure flicker

`--shots=flicker --drift=0` holds camera and soldiers still under the game's own anti-aliasing and
scores the change between frames at 3, 5, 8, 14, 24 and 45 m. It saves `*_migotanie_<m>.png` (the
change, amplified) and `*_spokoj_<m>.png` (the frame). Read the picture, not only the number: what
is lit up is what shimmers. With `--drift=0` a steady body scores about 3 at 3 m falling to about 1
at 45 m; the weapons' edges alone give that much. Without `--drift=0` the camera moves by a
fraction of a pixel and every edge lights up, which is normal.

The menu's class preview has its own test, because it differs from the game (MSAA instead of
TAA, two strong studio lights, the finest meshes always): `--test=preview-flicker --out=<dir>`.
It turns the model at a fixed time step and scores how far each frame strays from halfway between
its neighbours, so smooth motion cancels and only blinking remains; read `*_diff.png`. After the
fix of 2026-11-10 a body scores roughly 40-170, most of it outlines; `--variant=` switches causes
off one by one (see the script's header).

What has caused flicker here, in the order to suspect it:

0.  **Halos blinking on the edges of a multisampled view (the menu preview).** MSAA shades an
    edge pixel at its centre, outside the triangle, so vertex colours are read past their ends
    and can go negative; `pow()` of that is NaN and the glow pass spreads it into a halo. Clamp
    any vertex input before `pow`, `sqrt` or `log`. Telltale: it goes away with glow off but no
    glow threshold changes it.
1. **A soldier blinking out a few metres away.** Level-of-detail meshes must hand over at one
   exact distance. Any `visibility_range_*_margin` leaves a band where neither mesh is drawn.
2. **Bright things on dark bodies.** White plates in sunlight cross the bloom threshold and grow a
   pulsing halo. Keep paint under about 0.6 linear; only `glow` and `lamp` kinds should bloom.
3. **Parts thinner than a pixel.** Seams, laces, studs and eye whites belong in `fine(0)`, which
   the game shows only within `LOD_FROM[1]` metres.
4. **Glossy facets.** The shader dulls gloss where the surface turns away from the eye (`facing`);
   a kind that still sparkles needs a higher value in `ROUGH`. Roughening by the pixel
   derivative of the normal was tried and measured to make no difference.
5. **A coarse layer sinking into what it lies on.** Far shells get extra clearance in
   `Form.shell`; a patch in a hollow (an eye socket) needs lift of its own.

## 4. Before calling it done

`tools/check.sh` prints nothing, `--test=sides`, `--test=shield` and `--test=lang` pass headless,
and the pictures from step 2 have been looked at.
