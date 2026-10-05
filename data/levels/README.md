# Pályák (Levels) - Tervezés és Adatok

Ez a mappa tartalmazza a dungeon és pálya tervekeit, designjait és témáit.

## Mappastruktúra

### `/designs`
- **Célja**: A pályák logikai tervezetei és designjaitDokumentáció
- **Formátum**: JSON, YAML, vagy Markdown fájlok
- **Tartalom**: 
  - Pályák neve, szintje, nehézsége
  - Szobák/cellák leírása
  - Ellenségek elhelyezése
  - Lootok és kincsek
  - Quest gateways és feltételek

### `/layouts`
- **Célja**: A pályák térkép layoutjai
- **Formátum**: Grid-alapú JSON vagy YAML
- **Tartalom**:
  - Szoba koordináták (grid pozíciók)
  - Fal/akadály reprezentáció
  - Ajtók és átjárók
  - Spawn pontok
  - Exit pontok

### `/themes`
- **Célja**: Vizuális témák és szobastílusok
- **Formátum**: JSON konfigurációs fájlok
- **Tartalom**:
  - Szoba típusok (dungeon, cavern, castle, etc.)
  - Textúra és szín paletták
  - Tőle/padló/fal dekorációk
  - Hangeffektek és Music cues

## Konvenció

Pályák elnevezése: `<themeName>_level<level_number>.{json|yaml|md}`

Például:
- `crypt_level_01.json`
- `goblin_cavern_level_03.yaml`
- `haunted_castle_level_05.md`

## Jövőbeli Integrációs Pontok

- Blender level szerkesztő exportok
- Quaternius szobastílus templátok
- Quiz/Tripo3D generált szobák
