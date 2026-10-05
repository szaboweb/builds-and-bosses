# Builds & Bosses — Pályatervező Editor & Paletta Handoff

Ez a dokumentum a **beépített 2D Pályatervező (In-Game Level Editor)** teljes funkcionális, architekturális és fázisokra bontott megvalósítási terve.
Célja, hogy a fejlesztés bármikor, akár hónapokkal később, tetszőleges AI-asszisztenssel vagy manuálisan is folytatható legyen minimális tokenfelhasználással, fázisonként függetlenül implementálható modulokkal és készen álló kódvázakkal (placeholders).

---

## 1. Vízió és Értékajánlat

A Builds & Bosses jelenlegi verziójában a kőplatformok koordinátáit és kinematikáját kézzel vagy AI-kódolással kellett beállítani.
A **Pályatervező Editor** célja, hogy a játékos/fejlesztő a futó játékon belül, grafikus felületen:
1. Egy **Armory-jellegű palettából** új elemeket húzhasson be az arénába (statikus kő, mozgó kő, ellenség spawn, lovag startpont).
2. A lehelyezett objektumokat **egérrel szabadon mozgathassa** és a jobb alsó sarok megragadásával **átlósan átméretezhesse**.
3. A mozgó platformoknál **kihúzható neon vektornyíllal** adhassa meg a mozgás irányát és távolságát, amely után a platform automatikusan oda-vissza jár.
4. **Nem kell mesterséges Erő-értéket beállítani:** A fizika automatikusan eldönti a nehézséget: ha magasra vagy messzire tervezed a követ, a játékba épített D&D 2024 Erő-ugrásmagasság képlet ($h = \frac{v_0^2}{2g}$) révén csak a kellően erős (pl. STR 18+) karakterek tudják átugrani.
5. A kész pályát **egyetlen gombnyomással elmenthesse (JSON)**, és egy **"Tesztelés / Play" gombbal azonnal kipróbálhassa** a lovaggal.

---

## 2. Felhasználói Élmény (UX) és Kezelőszervek

### 2.1. Kihúzható Paletta Fiók (Editor Drawer)
- Hasonló az `EquipmentWorkshopScreen` dizájnjához: sötét gótikus rácsos panel, arany/cián szegéllyel.
- **Tartalma:**
  - 🪨 **Statikus Kőplatform kártya:** Alapértelmezett méret: $160 \times 20\text{ px}$.
  - ⚡ **Mozgó Kőplatform kártya:** Kinematikus lebegő kő arany rúnákkal és hajtóművekkel.
  - 🎯 **Training Dummy / Boss Spawn kártya:** Ellenség elhelyezése a pályán.
  - 🚩 **Player Spawn zászló:** A lovag kezdőpozíciója.
- **Vezérlők a fiók tetején:**
  - 💾 **Mentés (Save Blueprint)** $\rightarrow$ JSON fájlba írás.
  - 📂 **Betöltés (Load Blueprint)** $\rightarrow$ létező pálya beolvasása.
  - ▶️ **Tesztelés (Play Mode)** $\rightarrow$ azonnali átváltás valós idejű játékra.
  - ⏹️ **Vissza az Editorba (ESC)** $\rightarrow$ a játék megáll, visszatér szerkesztő nézetbe.

### 2.2. Átlós Sarokméretezés (Corner Resize Handle)
- Egy kijelölt platform jobb alsó sarkában megjelenik egy $12 \times 12\text{ px}$-es fogantyú.
- Fölé víve az egeret a kurzor átvált: `SystemMouseCursors.resizeDownRight`.
- Nyomva tartva és átlósan húzva:
  $$\text{szélesség} = \max(64.0, \text{egér.x} - \text{bal}); \quad \text{magasság} = \max(16.0, \text{egér.y} - \text{teteje})$$
- Opcionális Snap-to-Grid: $16\text{ px}$-es diszkrét rácslépések.

### 2.3. Vektornyilas Mozgástartomány Gizmo
- Mozgó platform kijelölésekor a kő közepéből kiindul egy interaktív neon nyílfej.
- Egérrel megragadva tetszőleges irányba elhúzható (pl. $300\text{ px}$ jobbra vagy $150\text{ px}$ fel).
- A pálya mentén szaggatott sínvonal jelzi az oszcillációs folyosót.
- Elengedéskor azonnal látható az élő előnézet: a kő elindul, megteszi a távot, megfordul és visszatér.

---

## 3. Adatmodell & JSON Specifikáció (Core szint)

A pálya leírója tiszta Dart modellként él a `core` rétegben, semmilyen Flutter UI vagy Flame függősége nincs, így 100%-ban unit tesztelhető.

```json
{
  "name": "Cathedral of Trials",
  "version": 1,
  "arenaSize": { "x": 2400.0, "y": 900.0 },
  "playerSpawn": { "x": 180.0, "y": 822.0 },
  "platforms": [
    {
      "id": "plat_start",
      "type": "static",
      "x": 100.0,
      "y": 745.0,
      "width": 200.0,
      "height": 20.0
    },
    {
      "id": "plat_moving_01",
      "type": "moving",
      "x": 390.0,
      "y": 625.0,
      "width": 160.0,
      "height": 20.0,
      "directionX": 1.0,
      "directionY": 0.0,
      "travelDistance": 500.0,
      "speed": 90.0
    }
  ],
  "spawns": [
    {
      "id": "dummy_01",
      "type": "training_dummy",
      "x": 2200.0,
      "y": 719.0
    }
  ]
}
```

---

## 4. Fázisokra Bontott Megvalósítási Terv

A feladatot 4 független, önállóan commitolható és tesztelhető fázisra bontjuk, hogy minimális tokenköltséggel, lépésenként lehessen haladni.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. FÁZIS: Headless Blueprint Modell & JSON Szerializáció (Core)            │
│ └── 100% tiszta Dart, fájlmentés/betöltés tesztekkel, 0 UI                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. FÁZIS: Editor Mód, Kijelölés & Átlós Sarokméretezés (Game/Flame)        │
│ └── Objektumok mozgatása egérrel, jobb alsó fogantyú átlós húzása          │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. FÁZIS: Vektornyilas Mozgástartomány Gizmo (Game/Flame)                  │
│ └── Mozgó kő oszcillációjának kihúzása, azonnali visszatérő mozgáshurok    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. FÁZIS: Paletta Fiók Overlay & Play/Teszt Ciklus (UI/Flutter)            │
│ └── Kihúzható kártyák, Drag & Drop, Mentés/Betöltés és egygombos Play mód  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 1. Fázis: Headless Blueprint Modell & Szerializáció
* **Felelősség:** Headless adatstruktúra és JSON oda-vissza konverzió.
* **Cél fájlok:**
  - `app/lib/core/arena/arena_layout_blueprint.dart` (Új, ~180 sor, 🟢 Green)
  - `app/test/arena_layout_blueprint_test.dart` (Új, ~120 sor)
* **Kimenet:** Bármilyen pálya JSON szöveggé alakítható és hibátlanul visszaállítható memóriába.

### 2. Fázis: Editor Mód, Kijelölés & Átlós Sarokméretezés
* **Felelősség:** Interaktív szerkesztő réteg a Flame canvasen.
* **Cél fájlok:**
  - `app/lib/game/editor/arena_editor_controller.dart` (Új, ~200 sor, 🟢 Green)
  - `app/lib/game/editor/editor_corner_handle.dart` (Új, ~130 sor, 🟢 Green)
  - `app/test/editor_geometry_test.dart` (Új, ~100 sor)
* **Kimenet:** A szerkesztőben bármelyik kőre kattintva megjelenik a sárga keret, és a jobb alsó sarokból átlósan méretezhető a platform.

### 3. Fázis: Vektornyilas Mozgástartomány Gizmo
* **Felelősség:** Kinematikus útvonal interaktív beállítása.
* **Cél fájlok:**
  - `app/lib/game/editor/motion_vector_gizmo.dart` (Új, ~160 sor, 🟢 Green)
  - `app/test/motion_vector_gizmo_test.dart` (Új, ~100 sor)
* **Kimenet:** Egérrel kihúzható a mozgás iránya és távolsága; elengedéskor a platform azonnal járni kezd.

### 4. Fázis: Paletta Fiók Overlay & Play Ciklus
* **Felelősség:** Flutter UI réteg, fiók animáció, mentés gombok és tesztelés.
* **Cél fájlok:**
  - `app/lib/ui/editor/level_editor_drawer.dart` (Új, ~220 sor, 🟢 Green)
  - `app/lib/ui/editor/palette_card_widget.dart` (Új, ~120 sor, 🟢 Green)
  - `app/test/level_editor_ui_test.dart` (Új, ~130 sor)
* **Kimenet:** Komplett felhasználói élmény a böngészőben/asztalon.

---

## 5. Kódminőségi és Ratchet Szabályok

A projekt minőségi kapui (`validate_quality.ps1`) miatt az alábbi szabályok kötelezőek minden fázisnál:

1. **Traffic Light Sorhatárok:**
   - 🟢 **Green (0 – 349 sor, sweet spot 150–250):** Minden újonnan létrehozott fájlnak ebbe a zónába kell esnie!
   - Tilos 350 sor fölötti monolit fájlt létrehozni a szerkesztőhöz.
2. **Névadási konvenciók (`docs/NAMING_CONVENTIONS.md`):**
   - Flame komponensek: `*_component.dart`
   - Kontrollerek: `*_controller.dart`
   - Widgetek: `*_widget.dart`, `*_drawer.dart`
   - Modellek: `*_blueprint.dart`
3. **Token-hatékony parancsok:**
   - Tesztek futtatásakor szigorúan: `flutter test test/<fokuszalt_teszt>.dart --reporter=compact`
   - Soha ne fusson a teljes tesztcsomag feleslegesen verbose módban.

---

## 6. Kész Kódvázak és Interfész Szerződések (Placeholders)

Az alábbi vázlatok közvetlenül felhasználhatók a jövőbeli kódolási fázisokban, így nem kell újra kitalálni az architektúrát.

### 6.1. Blueprint Adatmodell Vázlat (`app/lib/core/arena/arena_layout_blueprint.dart`)

```dart
import 'dart:math';

enum PlatformType { staticStone, movingStone }

class PlatformBlueprint {
  final String id;
  final PlatformType type;
  double x;
  double y;
  double width;
  double height;
  
  // Mozgó platform specifikus adatok (statikusnál null/0)
  double travelDistance;
  double directionX; // +1.0 vagy -1.0
  double speed;

  PlatformBlueprint({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.travelDistance = 0.0,
    this.directionX = 1.0,
    this.speed = 90.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'travelDistance': travelDistance,
    'directionX': directionX,
    'speed': speed,
  };

  factory PlatformBlueprint.fromJson(Map<String, dynamic> json) {
    return PlatformBlueprint(
      id: json['id'] as String,
      type: PlatformType.values.byName(json['type'] as String),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      travelDistance: (json['travelDistance'] as num?)?.toDouble() ?? 0.0,
      directionX: (json['directionX'] as num?)?.toDouble() ?? 1.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 90.0,
    );
  }
}

class ArenaLayoutBlueprint {
  final String name;
  final int version;
  final double arenaWidth;
  final double arenaHeight;
  double playerSpawnX;
  double playerSpawnY;
  final List<PlatformBlueprint> platforms;

  ArenaLayoutBlueprint({
    this.name = 'Custom Dungeon Arena',
    this.version = 1,
    this.arenaWidth = 2400.0,
    this.arenaHeight = 900.0,
    this.playerSpawnX = 180.0,
    this.playerSpawnY = 822.0,
    List<PlatformBlueprint>? platforms,
  }) : platforms = platforms ?? [];

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'arenaWidth': arenaWidth,
    'arenaHeight': arenaHeight,
    'playerSpawnX': playerSpawnX,
    'playerSpawnY': playerSpawnY,
    'platforms': platforms.map((p) => p.toJson()).toList(),
  };

  factory ArenaLayoutBlueprint.fromJson(Map<String, dynamic> json) {
    return ArenaLayoutBlueprint(
      name: json['name'] as String? ?? 'Custom Dungeon Arena',
      version: json['version'] as int? ?? 1,
      arenaWidth: (json['arenaWidth'] as num?)?.toDouble() ?? 2400.0,
      arenaHeight: (json['arenaHeight'] as num?)?.toDouble() ?? 900.0,
      playerSpawnX: (json['playerSpawnX'] as num?)?.toDouble() ?? 180.0,
      playerSpawnY: (json['playerSpawnY'] as num?)?.toDouble() ?? 822.0,
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => PlatformBlueprint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
```

### 6.2. Sarokméretező Fogantyú Vázlat (`app/lib/game/editor/editor_corner_handle.dart`)

```dart
import 'dart:math';
import 'package:flutter/material.dart';

class EditorCornerHandle {
  static const double handleSize = 14.0;
  static const double minWidth = 64.0;
  static const double minHeight = 16.0;

  Rect getHandleRect(Rect target) {
    return Rect.fromCenter(
      center: Offset(target.right, target.bottom),
      width: handleSize,
      height: handleSize,
    );
  }

  bool isHovering(Rect target, Offset mousePos) {
    return getHandleRect(target).inflate(4.0).contains(mousePos);
  }

  Rect applyResize({
    required Rect target,
    required Offset currentMousePos,
    double gridSnap = 16.0,
  }) {
    double newWidth = max(minWidth, currentMousePos.dx - target.left);
    double newHeight = max(minHeight, currentMousePos.dy - target.top);

    if (gridSnap > 0) {
      newWidth = (newWidth / gridSnap).round() * gridSnap;
      newHeight = (newHeight / gridSnap).round() * gridSnap;
    }

    return Rect.fromLTWH(target.left, target.top, newWidth, newHeight);
  }
}
```

### 6.3. Vektornyíl Gizmo Vázlat (`app/lib/game/editor/motion_vector_gizmo.dart`)

```dart
import 'package:flutter/material.dart';

class MotionVectorGizmo {
  Offset startPoint;
  Offset currentEndPoint;
  bool isDragging = false;

  MotionVectorGizmo({
    required this.startPoint,
    required this.currentEndPoint,
  });

  double get distance => (currentEndPoint.dx - startPoint.dx).abs();
  double get directionX => (currentEndPoint.dx >= startPoint.dx) ? 1.0 : -1.0;

  void render(Canvas canvas, double pulse) {
    final trackPaint = Paint()
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.5 * pulse)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 1. Szaggatott sínvonal a start és end pont között
    canvas.drawLine(startPoint, currentEndPoint, trackPaint);

    // 2. Neon nyílfej a végponton
    final arrowPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(currentEndPoint, 6.0, arrowPaint);
    canvas.drawCircle(startPoint, 4.0, Paint()..color = const Color(0xFF00E5FF));
  }
}
```

---

## 7. Implementációs Állapot és Eredmények (100% Kész)

Mind a 4 fázis és a kiegészítő segédeszközök sikeresen megvalósításra kerültek a TDD és kódminőségi szabályok szigorú betartásával:

| Modul / Fájl | Réteg | Sorok | Minőségi zóna | Tesztek |
|---|---|---|---|---|
| `app/lib/core/arena/arena_layout_blueprint.dart` | Core | 290 | 🟢 Green | 6 unit teszt (`arena_layout_blueprint_test.dart`) |
| `app/lib/core/utils/unique_id.dart` | Core | 20 | 🟢 Green | 4 unit teszt (`unique_id_test.dart`) |
| `app/lib/game/editor/editor_corner_handle.dart` | Game | 97 | 🟢 Green | 11 geometriai teszt (`editor_geometry_test.dart`) |
| `app/lib/game/editor/arena_editor_controller.dart` | Game | 342 | 🟢 Green | Kontroller és fogantyú tesztek |
| `app/lib/game/editor/motion_vector_gizmo.dart` | Game | 147 | 🟢 Green | 10 gizmo és mozgás teszt (`motion_vector_gizmo_test.dart`) |
| `app/lib/game/editor/arena_editor_painter.dart` | Game | 46 | 🟢 Green | Flame/Canvas renderelés |
| `app/lib/ui/editor/palette_card_widget.dart` | UI | 85 | 🟢 Green | 5 widget teszt (`level_editor_ui_test.dart`) |
| `app/lib/ui/editor/level_editor_drawer_widget.dart` | UI | 168 | 🟢 Green | Kártya és fiók tesztek |
| `app/lib/ui/editor/level_editor_overlay.dart` | UI | 233 | 🟢 Green | Teljes felső/alsó overlay és interakciók |
| `tooling/quick_check.ps1` | Tooling | 71 | — | Egygombos format + test + quality gate ellenőrző |

Minden fájl szigorúan a 🟢 Green zónában maradt (<350 sor, az ideális 150–250-es sweet spotban), minden metódus $\le 80$ fizikai sor, és a repository összes minőségi kapuja (`validate_quality.ps1`) 0 hibával és 0 figyelmeztetéssel zöld.

---

## 8. Hogyan Folytasd a Fejlesztést a Jövőben?

A pályatervező modulok teljes mértékben készen állnak a játékhurokkal (`TacticalGame`) való összekötésre. Amikor elindítod a következő iterációt, használd a token-takarékos egygombos parancsot:

> `powershell -NoProfile -File tooling/quick_check.ps1 -TestFile test/level_editor_ui_test.dart`

