# Builds & Bosses — 0.1 Handoff

Ez a dokumentum a `v0.1.0` állapot teljes fejlesztési handoffja. A célja, hogy egy másik AI-asszisztens (például Gemini) a projekttervezést és a következő feature-ök specifikációját a repository beolvasásával el tudja végezni, miközben a konkrét Dart/Flutter kódolás ebben a repositoryban történik.

## 1. Projektállapot

- Játékmotor: Flutter + Flame 1.38.2.
- Nyelv: Dart 3.13.4.
- Elsődleges cél: Windows desktop, fejlesztéshez Chrome/Web.
- Játékmodell: szigorúan single-player és offline-first.
- Steam: csak opcionális terjesztés, achievement és Hall of Fame/stat sync adapter.
- Aktuális stabil commit: `b85f6ce`.
- Release alap: `v0.1.0`.
- Aktív branches: `main`, `dev`.
- Branch protection: jelenleg szándékosan nincs bekapcsolva.

## 2. Játékvízió

2D oldalnézeti, D&D 2024 szabályokra építő akció-RPG/prototípus. A játékos hőst épít, mozog a nagyobb dungeon-arénában, majd közelharci, távolsági vagy mágikus támadásokkal küzd.

Tervezett hosszú távú struktúra:

- 12 kézzel tervezett boss-dungeon.
- Build- és multiclass-alapú karakterfejlődés.
- Faj-, kaszt-, fegyver-, inventory- és equipment set-rendszer.
- Attrition/curse mechanikák a dungeon során.
- Idő, build és boss teljesítmény alapján működő Hall of Fame.
- Tiled pályák a procedurális PoC Canvas-renderelés későbbi kiváltására.
- Aseprite sprite-sheet workflow a procedurális karakter-VFX mellett.

## 3. Aktuális játékélmény

### Mozgás

- `A/D` vagy bal/jobb nyíl: vízszintes mozgás.
- `W/S` vagy fel/le nyíl: szabad függőleges repülés.
- `SPACE`: ugrás.
- A mozgás fizikája és a hős sebessége `DEX`-ből származik.
- Az ugrási impulzus és elméleti magasság `STR`-ből származik.
- A kamera mindkét tengelyen dead-zone alapján követi a hőst.

### Harci módok

`Tab` ciklikusan vált:

```text
MELEE -> RANGED -> SPELL -> MELEE
```

- Melee: `STR + Proficiency` a célpont AC-je ellen.
- Ranged/Bow: `DEX + Proficiency` a célpont AC-je ellen.
- Spell: Wizard esetén `INT`, Cleric esetén `WIS`, egyébként `CHA`, mindehhez Proficiency.
- Natural 1: kritikus kudarc.
- Natural 20: kritikus találat és dupla damage dice.
- `E`/jobb `AltGr`: realtime Slash.
- `C`: realtime spell attack.
- `F`: fix, nem reaktív auto-combat pipeline.
- Tactical Mode: `ENTER`, majd HUD/action célzás és `EXECUTE`.

### Hatótávok

A `CombatConfig` config-driven:

- melee reach: alapértelmezett 110 pixel.
- ranged normal: 420 pixel.
- ranged long: 900 pixel.
- spell range: 600 pixel.

Ranged long range esetén disadvantage van; long range fölött a támadás out-of-range. A melee range a hős fegyverprofiljából származik.

## 4. Fajok, kasztok és felszerelés

Jelenlegi kasztok:

- Fighter: frontline.
- Rogue: ranged/mobilis támadó.
- Cleric: divine caster.
- Wizard: arcane caster.

Darkvision:

- Human: nincs fajból eredő darkvision.
- Elf: konfigurált közepes sugár.
- Dwarf: konfigurált nagyobb sugár.

Equipment role-ok:

- `frontline`.
- `ranged`.
- `divineCaster`.
- `arcaneCaster`.

Az adatbázis jelenlegi helye:

```text
data/items/equipment_sets.json
```

Négy példa set van, egy mindegyik szerephez:

- Frontline Guard.
- Shadow Ranger.
- Divine Light.
- Arcane Stars.

Az inventory és armory kapacitásai a `InventoryConfig` alatt módosíthatók.

## 5. Rétegek és felelősségek

### `app/lib/core/`

Headless domain logika:

- `config/`: fizika, combat, cooldown, vision, inventory és weapon config.
- `dnd/`: `CharacterStats`, `Dice`, `CombatEngine`, catalog.
- `actions/`: action típusok, queue, cooldown és replay action payload.
- `combat/`: strukturált `CombatLogger`.
- `inventory/`: equipment item, set, inventory, armory és adatbázis modell.
- `platform/`: platform service contract, Steam/local adapter interface.
- `debug/`: determinisztikus replay snapshot.

Core szabály: nincs Flutter Material UI, Flame runtime, Canvas vagy platform-specifikus megjelenítés. A `flutter/foundation.dart` csak headless observable állapothoz engedélyezett. A `flame/extensions.dart` csak tiszta koordinátatípushoz használható.

### `app/lib/game/`

Flame runtime:

- world/entity komponensek.
- player/enemy mozgás és collision.
- projectile és VFX.
- kamera-follow.
- lighting/darkvision.
- developer visualization.
- `TacticalModeGame` koordinátor.

Game komponens nem számol saját D&D sebzést, nem dob közvetlenül kockát, és nem tart inventory-szabályt.

### `app/lib/ui/`

Flutter UI és overlay:

- Planning HUD.
- Action bar.
- Combat Log.
- Combat outcome overlay.
- Debug info overlay.
- Character Builder.

UI csak intentet küld a game felé és observable állapotot olvas.

### `app/lib/platform/`

Platformfüggő adapterek:

- desktop window manager.
- local persistent cache.
- későbbi Steamworks adapter.

## 6. Offline és Steam contract

A játék futása nem függ internettől. A `PlatformServices` contract tartalmazza:

- achievement unlock.
- cloud-like save API.
- combat statistics sync.
- pending statistics betöltés.

Jelenleg a `LocalPlatformServices` `SharedPreferences` cache-be ír. A későbbi Steam adapter ezt a contractot implementálja, és a sikertelen sync nem blokkolhatja a játékot.

## 7. Debug és replay

Developer mode: `F3`.

Megjeleníti:

- phase.
- combat mode.
- player/camera pozíció.
- target distance.
- cooldown.
- melee/ranged/spell/darkvision range-ek.
- hero/target triggerpontok.

A `DebugReplayRecorder` JSON snapshotot képes készíteni:

- seed.
- ruleset (`dnd2024`).
- hero.
- boss.
- action pipeline.
- outcome.

Hibareprodukció minta:

```text
commit: <git commit>
ruleset: dnd2024
seed: 12345
action: ranged
target: boss_001
```

## 8. Adat- és schema-rendszer

Minden adatfájl `_schema` mezőt használ:

- `hero_defaults/v1`.
- `hero_save/v1`.
- `boss/v1`.
- `equipment_database/v1`.

Validáció:

```powershell
pwsh -NoProfile -File tooling/validate_data.ps1
```

A fájlnevek lowercase `snake_case` formátumúak. A D&D ability kulcsok nagybetűsek maradnak, mert domain-standard kivételek.

## 9. Quality gates

Módosítás előtt/után:

```powershell
cd app
flutter analyze lib test
flutter test
flutter build web --no-wasm-dry-run
cd ..
pwsh -NoProfile -File tooling/validate_architecture.ps1
pwsh -NoProfile -File tooling/validate_data.ps1
```

CI további ellenőrzéseket futtat:

- secret scan.
- Windows build.
- architecture/data validation.
- analyzer/test.

## 10. Gemini tervezési workflow

Gemini használható magas szintű tervezésre, de a kódolási contractokat változatlanul kell átadni neki.

Ajánlott prompt:

```text
Olvasd be a docs/HANDOFF_0.1.md, docs/ARCHITECTURE.md és AGENTS.md fájlokat.
Tervezz egyetlen új feature-t.
Ne módosíts kódot.
Add meg: domain model, config/schema változás, tesztek, UI/game határ,
migrációs és debug kockázatok.
```

Kódolási prompt ebben a repositoryban:

```text
A tervet implementáld az app/ projektben.
Tartsd be az ARCHITECTURE.md réteghatárait.
Használj config/schema-driven adatot.
Írj headless tesztet.
Futtasd az architecture validator, data validator, flutter analyze, flutter test és build ellenőrzéseket.
```

## 11. Következő mérföldkövek

1. Inventory/Armory UI a Character Builderben.
2. Equipment modifier-ek tényleges alkalmazása a `CharacterStats` eredményekre.
3. Tiled első dungeon map.
4. Boss AI és dungeon attrition/curse rendszer.
5. Steam Hall of Fame adapter a lokális pending statistics queue-ra.
6. Golden/integration tesztek kamera, lighting, projectile és outcome overlay állapotokra.