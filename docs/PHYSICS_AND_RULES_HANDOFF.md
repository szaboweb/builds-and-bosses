# PHYSICS_AND_RULES_HANDOFF.md: Integrált Szabály- és Fizikai Rendszer

**Állapot:** Véglegesített integrációs handoff és architektúra-terv (v1.1 — Onesheet kiegészítéssel)  
**Forrásanyagok:** 
- `Main.dc.html` (Fizikai Onesheet vizuális és strukturális specifikáció)
- `PHYSICS_HANDOFF.md` (Stat-leképezés és sebzés-csővezeték)
- `EMERGENT_RULES_SPEC.md` (Tag-alapú interakciók és lökés)
- `SPEC_04_GRAVITY_ZONES_AND_SURFACES.md` (Zónák, felületek, ooze, határok)
- `SPEC_05_MACHINE_LAYER_V1.md` (Hibrid fizika, nyomólapok, felhajtóerő, szállítás)
- `SPEC_02_RULES_ENGINE_AGENT_PROMPT.md` (Mérföldkövek M1–M6)  
**Érvényesíti:** [AGENTS.md](../AGENTS.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/CODE_QUALITY.md](CODE_QUALITY.md)

---

## 1. Vezetői összefoglaló & Kivitelezhetőség

A specifikációk és a `Main.dc.html` referenciaterv egyetlen összefüggő rendszerré állnak össze.

### Kivitelezhetőségi vizsgálat: **100%-ban megvalósítható, zéró külső C++ függőséggel**

1. **Determinizmus & Fixpontos Aritmetika (`lib/core/`):**
   * Szigorúan **`Fixed`** (ezredegység, 64 bites `int`: `1000 = 1.0 csempe = 5 láb`, `200 = 1 láb`) egész aritmetika. Tilos a `double`, a `dart:math` `Random` és a `DateTime.now`.
   * Fix 60 Hz szimulációs lépések (`1 tick = 1/60 mp`), a `dt`-ből történő közvetlen pozíciószámítás tilos.
2. **Feldolgozási sorrend:**
   * A fizikai testek leülepedése és ellenőrzése **alulról felfelé**, azonos magasság esetén **id szerint lexikografikusan rendezve** fut, garantálva a determinisztikus hash-egyezést.
3. **Réteghatárok (AGENTS.md):**
   * A `lib/core/` teljesen headless, 0 Flame/Flutter importtal bír.
   * A `lib/game/` Flame komponensei csak olvassák a `core` tick-eredményeit, és biztosítják a vizuális interpolációt.
4. **Traffic Light zóna-garancia:**
   * Minden új fájl a 🟢 Zöld zónában marad (<350 sor, cél: 150–250 sor/modul).

---

## 2. A Fizikai Rendszer 3 Alappillére

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. TÁMASZ-ELLENŐRZÉS (Support Check)                                   │
│    Minden tickben: van alatta fix objektum, talaj vagy támaszték?      │
│    Igen ──► Stabil (nyugvó/alvó állapot)                               │
│    Nem  ──► Falling állapot indul (kivéve airborne és gas tagek)        │
├────────────────────────────────────────────────────────────────────────┤
│ 2. SEBESSÉGINTEGRÁCIÓ & ÜTKÖZÉSEK (Movement & Collision)               │
│    Kinematikus lények (vezérlő + externalVelocity)                     │
│    Dinamikus tárgyak (vy += g·dt, nehezebb tolja a könnyebbet, láncolás)│
├────────────────────────────────────────────────────────────────────────┤
│ 3. LANDOLÁS & INTERAKCIÓ (Landing & Resolution)                        │
│    Talaj: fall sebzés (DEX-ellenállás)                                 │
│    Fal/Tárgy: impact sebzés (CON-csökkentés + elnyelés)                │
│    Ráeső test / Beszorulás: crush sebzés (fix adat + Stoneskin felezés) │
│    Szakadék: térfogati betömés (volume vs capacity)                    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Szabályütközés-vizsgálat és Feloldási Mátrix (Conflict Resolution)

| # | Terület | Potenciális konfliktus | Végleges feloldási szabály |
|---|---|---|---|
| **C1** | **Hibrid Fizika:** Hős vs. Gép-tárgyak | A lények kinematikusak, a tárgyak dinamikusak. Ki tol kit? | **Kétirányú szerződés:**<br>1. *Lény tol tárgyat:* Izomerőből (`30·STR` lb limit, `tolhatóság`), nincs rugalmas visszarúgás.<br>2. *Mozgó tárgy csapódik lénynek:* Tárgy lendülete `ImpactEvent`-et vált ki (`v⊥` alapján). Ha a lény nem állítja meg, a lény `Displaced` lesz. |
| **C2** | **Lökés (Shove) vs. Falak & Test-test ütközés** | Mi történik, ha a lökött célpont falnak vagy egy másik lénynek csapódik? | **Akadály-megszakítás és Becsapódási Sebzés:**<br>Ha a lökés távolsága (`distance`) előtt falba vagy szilárd testbe ütközik, a mozgás leáll, a maradék sebességből felületre merőleges `v⊥` számítódik, és lefut a `damage_pipeline` `impact` ága. Másik lény esetén a lökés átadódik láncolva (`chainDepthMax = 8`). |
| **C3** | **Gravitáció-fordítás vs. Platformok & DropDown** | Hogyan viselkedik a semi-solid platform és a `dropDown` fordított gravitációban? | **Normálvektor-alapú felületek:**<br>Egyirányú (semi-solid) platformok csak a normálisuk felől szilárdak (`top`). Fordított gravitációban a lény felfelé zuhan át rajtuk, és a mennyezeten landol (ami padlóként viselkedik). A `dropDown` ilyenkor felfelé léptet. |
| **C4** | **`airborne` származtatás vs. Felhajtóerő (`lift`)** | A stat-szabály Fly/Levitate varázslatot vár, a gép-réteg felhajtóerőt (`lift >= weight`). | **Egységes felhajtóerő-modell:**<br>`effectiveLoad = max(0, weight − lift)`. Ha `effectiveLoad == 0`, a test lebeg (`airborne = true`), nem esik, nem nyom lapot, de a szél (STR ellenállás szerint) továbbra is hat rá. |
| **C5** | **Gáz állapot (`Gaseous Form`) lejárata szilárd testben** | Mi történik, ha a gáz-alak egy sziklában vagy falban jár le? | **Crush és Kilökődés:**<br>Ha szilárd anyagban jár le a hatás, a lény súlyos `crush` sebzést szenved el, és kilökődik a legközelebbi szabad koordinátára. |
| **C6** | **Szakadék és Tetemek / Betömés** | Hogyan működik a szakadék betömése? | **Térfogat-megmaradás:**<br>A szakadék rendelkezik egy `capacity` (térfogat) értékkel. A beleeső objektumok és elhullott lények `volume`-ja csökkenti a kapacitást és a mélységet. Amikor betelik, szilárd talajjá válik, a betömő testek pedig kikerülnek a fizikai szimulációból. |

---

## 4. A Három Sebzéstípus Kötött Csővezetéke

A `Main.dc.html` alapján pontosan **3 ütő (bludgeoning) típusú sebzés** létezik, amelyekre a Stoneskin (×0.5) egységesen érvényesül:

| Lépés | `fall` (zuhanás talajra) | `impact` (falnak/tárgynak csapódás) | `crush` (ráeső test / beszorulás) |
|---|---|---|---|
| **1. Nyers érték** | `max(0, hEq − 2) · 3` (`vy` alapján) | `max(0, hEqImpact − 2) · 3` (`v⊥` alapján) | Fix érték az adatból (`crushValue`) |
| **2. Elnyelés** | ❌ Nem | ✅ **Igen** (`clamp(1 − súly/limit, 0, 0.8)`) | ❌ Nem |
| **3. DEX-ellenállás** | ✅ **Igen** (`clamp((DEX - 8)/16, 0, 1)`) | ❌ Nem | ❌ Nem |
| **4. CON csökkentés** | ❌ Nem | ✅ **Igen** (`max(0, CONmod)`, min 1) | ✅ **Igen** (`max(0, CONmod)`, min 1) |
| **5. Stoneskin** | ✅ **Igen** (×0.5) | ✅ **Igen** (×0.5) | ✅ **Igen** (×0.5) |
| **6. Levonás** | Temp HP $\rightarrow$ HP | Temp HP $\rightarrow$ HP | Temp HP $\rightarrow$ HP |

---

## 5. Stat-Felelősségi Regiszter (1 Stat = 1 Tulajdonos)

- **STR (Erő):**
  - Ugrásmagasság: `max(1.0, 2.0 + 0.25·STRmod)` csempe
  - Tolás/lökés limit: `30·STR` lb
  - Szélállóság: `szélhatás = szél·(1 − 0.12·STRmod)` (földön a hatás feleződik)
- **DEX (Ügyesség):**
  - Földi sebesség: `5.0·(1 + 0.05·DEXmod)` csempe/s
  - Repülési sebesség szorzó: ugyanaz a szorzó, mint a földön
  - Csúszás-fékezés: `1 + 0.15·DEXmod`
  - Esési ellenállás: `clamp((DEX - 8)/16, 0, 1)` (DEX 24 $\rightarrow$ 100% védelem)
- **CON (Állóképesség):**
  - HP és mérgek ellenállása
  - Fizikai találatból fix csökkentés: `max(0, CONmod)` (csak `impact` és `crush`, `fall`-ra NEM!)

---

## 6. Determinisztikus 60 Hz Tick Életciklus

```text
 1. Input olvasás & Irányvektorok beállítása
 2. Szállítás & Külső erők (mozgó felületek súrlódása, szélhatás STR szerint)
 3. Mozgásintegráció (kinematikus lények + dinamikus gép-tárgyak alulról felfelé)
 4. Környezeti ütközések (falak, talaj, egyirányú platformok, támaszték-ellenőrzés)
 5. Lény-lény és Lény-tárgy ütközések (szilárd test-blokkolás + falvédett STR lökés)
 6. Nyomólapok & Kapcsolók kiértékelése (hiszterézis és debounce szűréssel)
 7. Szabálymotor események futtatása (prioritási sorrendben, maxChainDepth védelemmel)
 8. Állapotok frissítése & Lejáratkezelés (StatusExpired események)
 9. Sebzés-csővezeték végrehajtása (fall, impact és crush események lezárása)
```

---

## 7. Moduláris Felépítés & Mérföldkövek (M1–M6)

A kód felosztása a Traffic Light 🟢 Zöld zónás szabályoknak megfelelően (100–250 sor közötti fókuszált modulok):

```
app/lib/core/
├── physics/
│   ├── fixed_units.dart              # M1: Ezredegység aritmetika, clamp, konverziók (<120 sor)
│   ├── deterministic_hash.dart       # M2: Platformfüggetlen seedelt hash & kockadobás (<100 sor)
│   ├── capability_registry.dart      # M1: Stat-felelősségi regiszter (<150 sor)
│   ├── modifier.dart                 # M1: Stat/képesség módosítók és prioritások (<180 sor)
│   ├── derived_stats.dart            # M1: Stat-származtató belépési pont (<200 sor)
│   ├── damage_pipeline.dart          # M5: 6 lépéses fall, impact & crush csővezeték (<240 sor)
│   ├── displacement_resolver.dart    # M6: Shove & knockback, contest skálázás (<220 sor)
│   ├── machine_body.dart             # M6: Tárgyak és lények tömeg/felhajtóerő modellje (<200 sor)
│   └── pressure_plate.dart           # M6: Nyomólap hiszterézissel és csatornákkal (<160 sor)
└── rules/
    ├── status_tracker.dart           # M3: Időzített állapotok és lejárati események (<200 sor)
    ├── tag_dictionary.dart           # M4: Tagek és feltétel-kiértékelő (<150 sor)
    ├── rule_engine.dart              # M4: Eseménybusz prioritásos szabályokkal (<250 sor)
    ├── gravity_zone.dart             # M6: Anchored inversion zónák (<220 sor)
    └── pit_fill_tracker.dart         # M6: Szakadék-betömés kapacitás és térfogat (<160 sor)
```

---

## 8. Onesheet Design Referencia a Flame Debug Overlay-hez

A `Main.dc.html` alapján az elkészülő Flame debug overlay pontosan ezt a palettát és elrendezést fogja tükrözni:
- **Háttér:** `#14161c` és `#1d2029` kártyák, lekerekített sarkok (`border-radius: 10px`)
- **Kiemelés / Arany (Központ/Gravitáció):** `#f2b84b`
- **Gáz / Zónák (Teal):** `#5ec8c0`
- **Sebzés / Veszély (Piros):** `#e5645a`
- **Határok / Rendszer (Szürke):** `#9aa0ae`
- **Tipográfia:** Tiszta numerikus adatok, tick-számláló, hiba nélkül olvasható fixpontos értékek.
