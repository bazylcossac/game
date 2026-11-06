# Licencje zasobów

Spis wszystkiego, co w grze pochodzi od innych autorów. Reszta grafiki i wszystkie dźwięki
powstają ze skryptów w `tools/`, a mapy buduje generator w `scripts/map/`.

Dopisuj tu każdy nowy zasób: skąd pochodzi, na jakiej licencji i gdzie leży w projekcie.

## Tekstury: ambientCG

Źródło: <https://ambientcg.com>. Licencja: CC0 1.0 (<https://docs.ambientcg.com/license/>).
Podanie autora nie jest wymagane. Tekstury mają zmniejszoną rozdzielczość i dopasowany kolor.

| Plik w `assets/textures` | Zasób ambientCG | Adres |
| --- | --- | --- |
| `brick_albedo.png`, `brick_normal.png` | Bricks105 | <https://ambientcg.com/view?id=Bricks105> |
| `plaster_albedo.png`, `plaster_normal.png` | Plaster007 | <https://ambientcg.com/view?id=Plaster007> |
| `concrete_albedo.png`, `concrete_normal.png` | Concrete044D | <https://ambientcg.com/view?id=Concrete044D> |
| `cobble_albedo.png`, `cobble_normal.png` | PavingStones142 | <https://ambientcg.com/view?id=PavingStones142> |
| `dirt_albedo.png`, `dirt_normal.png` | Ground108 | <https://ambientcg.com/view?id=Ground108> |
| `grass_albedo.png`, `grass_normal.png` | Ground003 | <https://ambientcg.com/view?id=Ground003> |
| `wood_albedo.png`, `wood_normal.png` | Planks039 | <https://ambientcg.com/view?id=Planks039> |
| `metal_albedo.png`, `metal_normal.png` | Metal063 | <https://ambientcg.com/view?id=Metal063> |
| `roof_albedo.png`, `roof_normal.png` | RoofingTiles014B | <https://ambientcg.com/view?id=RoofingTiles014B> |
| `sky_evening.exr` | EveningSkyHDRI030A | <https://ambientcg.com/view?id=EveningSkyHDRI030A> |
| `facade_night_*.png` | Facade017 | <https://ambientcg.com/view?id=Facade017> |
| `asphalt_*.png` | Asphalt025C | <https://ambientcg.com/view?id=Asphalt025C> |
| `panel_*.png` | MetalPlates017A | <https://ambientcg.com/view?id=MetalPlates017A> |
| `deck_*.png` | DiamondPlate008A | <https://ambientcg.com/view?id=DiamondPlate008A> |
| `tiles_*.png` | Tiles140 | <https://ambientcg.com/view?id=Tiles140> |

## Sprite'y cząsteczek: Kenney

Źródło: Particle Pack 1.1, Kenney Vleugels, <https://kenney.nl/assets/particle-pack>.
Licencja: CC0 1.0 (<https://creativecommons.org/publicdomain/zero/1.0/>).

| Plik w `assets/textures` | Plik z paczki |
| --- | --- |
| `smoke.png` | `smoke_04.png` |
| `fire.png` | `fire_01.png` |

## Fonty

Licencja: SIL Open Font License 1.1. Pełne teksty leżą obok plików w `assets/fonts`.

| Plik | Font | Licencja |
| --- | --- | --- |
| `Anton-Regular.ttf` | Anton, The Anton Project Authors | `OFL-Anton.txt` |
| `BarlowCondensed-*.ttf` | Barlow Condensed, The Barlow Project Authors | `OFL-BarlowCondensed.txt` |

## Modele Stacji Rdzeń: Godot TPS Demo

`assets/models/tps/cargo.glb`, `gas_tank.glb`, `machine.glb`:
Copyright (c) 2018 Juan Linietsky, Fernando Miguel Calabró.
Źródło: <https://github.com/godotengine/tps-demo>, `level/geometry/models/props.glb`.
Licencja: [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
Pełny oryginalny tekst: `assets/models/tps/LICENSE.txt`.
Zmiany: wyodrębnienie trzech modeli, normalizacja wymiarów, nowe materiały oraz nowy układ mapy.
Nie wykorzystano muzyki, kodu ani pełnego poziomu z dema. Narzędzie: `tools/extract_tps_props.py`.

## Własne generatory

Wymienione tu pliki nie mają zewnętrznego autora. Powstają ze skryptów i są częścią gry.

| Co | Skąd |
| --- | --- |
| `fabric_*.png`, `flare.png`, `soft_dot.png`, `scorch.png`, flagi i godła | `tools/gen_textures.py` |
| `armor_detail.png` | `tools/gen_armor.py` |
| Wszystkie pliki w `assets/audio` | `tools/gen_audio.py`, `tools/gen_audio_battle.py`, `tools/gen_audio_modes.py`, `tools/gen_audio_arenas.py` |
| Układy siedmiu map (z wyjątkiem wymienionych modeli TPS) | `scripts/map/` |
| `assets/models/armory/*.glb`, w tym modele broni, rakiety i żołnierza | `tools/blender_armory.py`; edytowalne źródła w `art_source/*.blend` |

Modele z `armory` są własną geometrią przygotowaną w Blenderze. Materiały metalu używają
normalnej `metal_normal.png` z ambientCG, na licencji CC0 wskazanej powyżej.
