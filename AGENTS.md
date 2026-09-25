# AGENTS.md — Szigorú Építészeti és Kódolási Szabályzat Mesterséges Intelligencia Ágensek Számára

> [!CRITICAL]
> **MINDEN KÓDOLO ÁGENS SZÁMÁRA KÖTELEZŐ ÉRVÉNYŰ DOKUMENTUM!**
> Ebben a kódbázisban tilos az ad-hoc, átgondolatlan kódolás. Minden módosításnak szigorúan követnie kell a moduláris határokat, a konfiguráció- és statisztika-vezérelt elveket, valamint a strukturált naplózási és hibakezelési szabványokat.

---

## 1. Könyvtárstruktúra és Hatáskörök (Mit hova szabad implementálni?)

A `app` Flutter/Flame projekt 4 szigorúan elválasztott rétegre tagolódik:

```
app/
├── lib/
│   ├── core/         <-- [RÉTEG 1] Tiszta Üzleti Logika & Konfiguráció (Headless)
│   │   ├── config/   <-- Központi konfigurációs modellek (GameRulesConfig, PhysicsConfig, stb.)
│   │   ├── dnd/      <-- D&D 5e szabályrendszer (CharacterStats, CombatEngine, Dice)
│   │   ├── actions/  <-- Tervezhető akciók (GameAction, ActionQueue)
│   │   ├── combat/   <-- Harci naplózó (CombatLogger, LogLevel, CombatLogEntry)
│   │   └── errors/   <-- Hibakódok és kivételek (GameErrorCode, GameException)
│   ├── game/         <-- [RÉTEG 2] Flame Motor & Fizikai Komponensek
│   │   ├── components/ <-- Aréna, Player, Ellenség, Platformok, Ghost Preview, Vizuális VFX
│   │   └── tactical_game.dart <-- Fő játékhurok, fázisvezérlés, input dispatch
│   ├── ui/           <-- [RÉTEG 3] Flutter UI és Overlayek
│   │   ├── planning_hud.dart <-- Fejléc és állapotkijelzők
│   │   ├── action_bar_overlay.dart <-- Taktikai tervező akciómenü
│   │   └── character_builder_overlay.dart <-- Karakter Tervezőasztal
│   └── main.dart     <-- Belépési pont és overlay-regisztráció
└── test/             <-- [RÉTEG 4] Automatizált Egységtesztek (100% elvárt lefedettség)
```

### [RÉTEG 1] `lib/core/` — Szabályok:
* **Csak tiszta Dart domain logika és konfiguráció engedélyezett.**
* **TILOS** Flame komponenseket (`PositionComponent`, `FlameGame`), Flutter Widgeteket vagy grafikai elemeket ide importálni (kivéve tiszta matematikai `Vector2` az akciókoordinátákhoz).
* Ennek a rétegnek fej nélkül (headless) tesztelhetőnek kell lennie másodpercek alatt Flutter rendering nélkül.

### [RÉTEG 2] `lib/game/` — Szabályok:
* **Felelősség:** Flame entitások, fizikai mozgás ($g$ gravitáció, platformütközések, ugrásimpulzusok), spritok rajzolása, részecskék/VFX.
* **TILOS** közvetlen D&D harci sebzésképleteket vagy új kockadobási formulákat ide hardkódolni: minden harci kalkulációt a `CombatEngine`-nek és `CharacterStats`-nak kell delegálni!
* **TILOS** Flutter UI widgeteket közvetlenül a játékhurokba beégetni. Ha felhasználói felületre van szükség, azt a `lib/ui/` mappában, Flame overlayként kell megírni.

### [RÉTEG 3] `lib/ui/` — Szabályok:
* **Felelősség:** Felhasználói felület, gombok, életerőcsíkok, Tervezőasztal, menük.
* Csak olvassa a `game` és `core` állapotait (pl. `ValueNotifier` vagy `ChangeNotifier` segítségével).
* **TILOS** fizikai mozgásokat vagy harci logikát közvetlenül a widgetekben leprogramozni. A widgetek csak metódushívásokat indítanak a `game` vagy `player` felé (pl. `game.applyHeroBuild(...)`).

### [RÉTEG 4] `test/` — Szabályok:
* Minden új szabályhoz, kalkulációhoz, képességhez és konfigurációhoz kötelező egységtesztet írni a `test/` mappában.
* A teszteknek azonnal le kell futniuk a `flutter test` paranccsal.

---

## 2. ZÉRÓ Hardkódolt Mágikus Szám (Config-Driven & Stat-Driven Szabály)

> [!WARNING]
> Tilos a komponensekben vagy widgetekben ad-hoc konstans mágikus számokat (pl. `speed = 190.0`, `jump = -440.0`, `cost = 25`) elszórni!

1. **Konfiguráció-vezérelt tervezés (`GameRulesConfig`)**:
   - Minden globális játékparamétert (alap gravitáció, ugrási impulzus, futási sebesség, sebességskálázások, point-buy költségtáblák) a `lib/core/config/game_rules_config.dart` fájlban kell definiálni.
   - A konfigurációnak JSON-ből szerializálhatónak/deszerializálhatónak kell lennie (`fromJson`, `toJson`), lehetővé téve a külső fájlokból való betöltést.
2. **Statisztika-vezérelt játékmenet (Stat-Driven Gameplay)**:
   - A hős képességei dinamikusan a statisztikákból származnak:
     - **STR (Erő)** $\implies$ Ugrási magasság és impulzus (`stats.jumpVelocity`, `stats.maxJumpHeight`), Közelharci találati bónusz és sebzés.
     - **DEX (Ügyesség)** $\implies$ Futási sebesség (`stats.moveSpeed`), kezdeményezés, kitérés.
     - **CON (Állóképesség)** $\implies$ Maximális életerő (`stats.maxHp`), Második szél gyógyítás.

---

## 3. Strukturált Naplózás és Hibakezelés (CombatLogger & GameErrorCode)

1. **TILOS a nyers `print()`**:
   - Egyetlen kódoló ágens sem helyezhet el `print()` utasítást a production kódban.
2. **Kizárólag a `CombatLogger` használata**:
   - Minden harci eseményt a `CombatLogger.instance.logCombatAttack(...)` metódussal rögzítünk.
   - Minden gyógyítást a `CombatLogger.instance.logCombatHeal(...)` metódussal rögzítünk.
   - Minden fázisváltást a `CombatLogger.instance.logPhaseChange(...)` metódussal rögzítünk.
   - Minden taktikai tervezési/végrehajtási eseményt a `CombatLogger.instance.logTacticalAction(...)` metódussal rögzítünk.
   - Minden karakter build módosítást a `CombatLogger.instance.logBuildChange(...)` metódussal rögzítünk.
3. **Szabványos Hibakódok (`GameErrorCode` & `GameException`)**:
   - A hibáknak géppel olvasható hibakóddal kell rendelkezniük (`GameErrorCode` `1001-1299`).
   - Kivételek naplózása a `CombatLogger.instance.logGameException(e)` metóduson keresztül kötelező.

---

## 4. Determinizmus és Véletlenszám-generálás (RNG)

* **TILOS** közvetlen, kezeletlen `dart:math` `Random()` hívásokat elhelyezni harci szituációkban.
* Minden kockadobás kizárólag a `Dice` osztályon keresztül történhet (`Dice.d20()`, `Dice.rollMultiple(...)`), amely támogatja az előre meghatározott seed-eket és determinisztikus tesztelést.

---

## 5. Védjegy- és Szerzői Jogi Megkötések

> [!CAUTION]
> Tilos harmadik fél levédett megnevezéseinek (pl. *Transistor*, *Turn()*, *Jaunt*, *Crash*, *Supergiant*) használata a kódbázisban, kommentekben vagy tesztekben!
> A tervezési fázis neve hivatalosan és kizárólag: **Tactical Mode** (Taktikai Mód).

---

## 6. Minőségi Kapuk (Quality Gates)

Minden kódolási feladat után kötelező érvényű az alábbi két ellenőrzés futtatása:
1. `flutter analyze` $\implies$ **0 hiba, 0 figyelmeztetés, 0 lint issue**.
2. `flutter test` $\implies$ **100%-os sikeresség**, egyetlen elbukó teszt sem engedélyezett.
