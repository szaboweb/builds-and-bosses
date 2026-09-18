# D&D Multiclass Boss-Rush RPG — Részletes Játékterv
**Munkacím:** *"Builds & Bosses"

---

## 1. Koncepció összefoglaló

**Műfaj:** 2D felülnézetes (top-down) akció-RPG (Pygame-CE alapokon) D&D multiclassing szabályrendszerrel és DDO-stílusú koreografált dungeon futamokkal.

**A Játék Alaptézise:**
A játékos egy szabadon alakítható multiclass karaktert épít (pl. Paladin/Sorcerer, Fighter/Rogue, stb.). A világban **12 egyedi Főboss** létezik, mindegyik a saját, kézzel tervezett dungeonjének a végén. 
A dungeonök nem véletlenszerű labirintusok, hanem szándékosan olyan összetett akadálypályák (csapdák, rúnakorlátok, hordák, környezeti veszélyek, mini-bossok), amelyek célja **a build gyenge pontjainak a próbára tétele**. 

Ha egy karakter nincs felkészülve egy adott típusú kihívásra (pl. nincs csapda-hatástalanítása, nincs mobilitása átugrani a méregtócsát, hiányzik az AoE hordairtása vagy nem tud dispel-ezni mágikus rúnát), a pályán át kell küzdenie magát, de **büntető hatásokat (Curse, csökkentett max HP, mana-vesztés, mozgáslassulás)** szenved el. Így a főboss elé nem tiszta lappal, hanem a dungeon során felhalmozott állapotban és nehezítésekkel érkezik meg!

A boss legyőzése után a játékos azonnal látja a futam idejét egy **szintre szabott ranglistán (+/- 5 szint tartományban)**, a végső dicsőséget pedig a **12 Boss összesített átlagos legyőzési ideje** jelenti.

---

## 2. Főbb Rendszerek & Alappillérek

### A. Akadályok és Gyengeség-Mechanika (Attrition & Curse System)
A dungeon nem puszta díszlet, hanem szűrő:
1. **Kaszt-specifikus megoldások vs. brute-force:**
   - **Csapdafolyosó:** Rogue/Ranger észreveszi és hatástalanítja. Egy nehézpáncélos Fighter kénytelen áttörni rajta → *Sérülés / Wounded debuff (-20% max HP a run végéig)*.
   - **Átkos Rúnakapu / Mana-kút:** Wizard/Cleric le tudja bontani vagy feloldani. Rogue kénytelen átlopakodni vagy feltörni → *Curse of Weakness (növelt spell cooldownok vagy folyamatos mana drain)*.
   - **Szűk Horda-torlasz (Undead/Goblin swarms):** AoE kasztok (Wizard/Sorcerer) azonnal elhamvasztják. Egy célpontra specializált Assassin sok időt veszít és körbeveszik → *Kifulladás / Fatigue (-15% stamina regeneráció)*.
   - **Mini-boss előőrs:** Megköveteli az aktív védekezést (Shield block, Parry, Dodge). Ha elrontod, a boss előtt már elhasználtad a védekező potionjeidet.
2. **A Boss-szobába lépés állapota:**
   - A boss harc nehézsége dinamikusan tükrözi, mennyire volt univerzális vagy taktikus a builded a folyosókon.
   - Nem a "sebzésmentes" beérkezés a cél, hanem hogy a játékos buildje képes legyen kompenzálni az elkerülhetetlen gyengeségeket.

---

### B. A 12 Boss és a Kampány Struktúra
A játék 12 ikonikus, egyedi mechanikával bíró boss-dungeonből áll, növekvő kihívással és szintekkel:

| # | Boss Név | Típus / Téma | Dungeon Fő Akadályai | Boss Fő Mechanikája |
|:---|:---|:---|:---|:---|
| 1 | **Gravekeeper Malakar** | Undead / Necromancy | Csontváz hordák, mérgező kriptagázok | Minion idézés, életerő-elszívás (Lifesteal) |
| 2 | **Ignis the Flamboyant** | Fire Elemental / Mage | Időzített tűzcsapdák, lávafolyamok | Telegrafált lángrobbanások, dühöngő fázis |
| 3 | **Gorgon Queen Serytha** | Monstrosity / Gaze | Kőcsapdák, bénító nyilak, tükör-rejtvények | Kővé dermesztő pillantás (irányváltás szükséges) |
| 4 | **Shadowstalker Vane** | Rogue / Assassin | Sötét szobák, rejtett csapóajtók, orgyilkosok | Láthatatlanság, hátbatámadás, árnyékmásolatok |
| 5 | **Iron Colossus** | Golem / Construct | Zúzó kalapácsok, széteső padlólapok | Fizikai páncél (Armor Break fázisok kellenek) |
| 6 | **Broodmother Xilith** | Beast / Swarm | Pókhálók (lassítás), tojáskamrák (adds) | Méregköpés, fonalon lógó fázisok |
| 7 | **Archmage Thundercall** | Elemental Mage | Villámkapuk, manaelnyelő mezők | Mozgó villámgömbök, láncvillámok |
| 8 | **Bloodlord Draven** | Vampire Lord | Vérelvezető csatornák, vérfarkasok | Teleportáció, vérköd (immunitás periódusok) |
| 9 | **Dune Tyrant Skar** | Beast / Sandstorm | Homokcsapdák, süllyedő homok | Föld alá ásás, lökéshullámok |
| 10 | **Frost Lich Kel'Vara** | Undead / Ice | Jéghideg aura (DOT sebzés), fagyos tüskék | Jégbörtön, jégvihar arénaszűkítés |
| 11 | **Demonforged Behemoth** | Fiend / Chaos | Kaotikus rúnák, tűzeső, robbanó kristályok | Padlót felszaggató ütések, düh fázis |
| 12 | **The Eldritch Sovereign** | Aberration / Void | Elmebontó csapdák (fordított irányítás), void portálok | Többfázisos harc: valóságváltás, void sugarak |

---

### C. Szintrendszer és a Scoreboard Ranglisták
1. **Karakterszintek & Skálázódás:**
   - A karakter fejlődik a játék során (pl. Lvl 1-től Lvl 30-ig terjedő skála).
   - Multiclass: minden szintlépésnél eldöntheted, melyik kaszt szintjét növeled (pl. Fighter 4 / Wizard 2).
2. **Scoreboard: +/- 5 Szint Sávos Összehasonlítás (Bracket Ranking):**
   - Ha egy játékos pl. **Level 12-es** karakterrel győzi le a 4. Boss-t, a játék a **[Level 7 – Level 17]** sávba tartozó futamokkal hasonlítja össze.
   - Ez kizárja az unfair összehasonlításokat (egy lvl 30-as karakter nem egy lvl 5-össel versenyez).
   - Metrikák a boss után:
     - **Kill Time / Run Time:** Másodpercre pontos idő a dungeon elejétől a boss haláláig.
     - **Elszenvedett átkok száma.**
     - **Build összetétel:** Kiírja pl. `[Paladin 8 / Rogue 4]`.
3. **12 Boss Összesített Átlagidő Ranglista (The Grand Gauntlet):**
   - Külön elit ranglista azoknak, akik mind a 12 boss-t legyőzték az adott karakterrel:
   $$\text{Átlagos Idő} = \frac{\sum_{i=1}^{12} \text{Boss } i \text{ Kill Time}}{12}$$
   - Megmutatja, melyik build a legstabilabb, legkiegyensúlyozottabb a játék összes akadályával szemben.

---

### D. Loot & Set Rendszer: Epic és Legendary Szettek
Nem cél a végtelen szemét farmolása. Ehelyett ikonikus, jellegzetes darabok és szettek találhatók:

1. **Loot Források:**
   - Bossok első és ismételt legyőzése.
   - A dungeonök nehezen megközelíthető, rejtett kincseskamrái (titkos ajtók, Perception / Lockpick / Strength próbák mögött).
2. **Ritkaságok:**
   - **Rare:** Alap attribútum- és védelembónuszok.
   - **Epic Set-ek (3 részesek):** Erős mechanikai módosítók (pl. csapda-sebzés csökkentés, spell kritikus esély).
   - **Legendary Set-ek (4 részesek):** Build-definíciót átíró bónuszok!
3. **Példa Szettekre:**
   - **"Shadowdancer's Regalia" (Epic - Rogue/Fighter szett):**
     - *(2 db):* Sikeres kitérés után 3 másodpercig +30% kritikus esély.
     - *(3 db):* A csapdák 50%-kal kevesebb sebzést okoznak; mozgási sebesség +20%.
   - **"Spellblade of the Spellguard" (Legendary - Fighter/Mage szett):**
     - *(2 db):* Fegyveres közelharci találat visszatölt 5 pont manát.
     - *(4 db):* Varázslás után a következő fegyvertámadás az elmondott varázslat elemi típusával sebez extra 50%-ot; a nehézpáncél nem rontja a varázslási időt.
   - **"Aegis of the Sun Soul" (Legendary - Paladin/Cleric szett):**
     - *(2 db):* A gyógyító hatások 25%-kal erősebbek és eloszlatnak egy aktív átkot (Dispel Curse).
     - *(4 db):* Amikor a HP 25% alá esik, automatikus isteni pajzs aktiválódik 5 másodpercre.

---

## 3. Technikai Architektúra & Megvalósítás (Pygames)

* **Nyelv:** Python 3.12
* **Keretrendszer:** `pygame-ce` (Pygame Community Edition)
* **Projekt Struktúra:**
  ```
  Pygames/
  ├── assets/                # Sprite-ok, hangok, betűtípusok
  │   ├── characters/
  │   ├── dungeons/
  │   ├── bosses/
  │   └── ui/
  ├── data/                  # Konfigurációs fájlok (JSON/YAML)
  │   ├── classes.json       # Kasztok, szintek, képességek statjai
  │   ├── items_sets.json    # Epic & Legendary szettek definíciói
  │   ├── dungeons.json      # A 12 dungeon és boss paraméterei
  │   └── leaderboards.json  # Lokális / mock globális scoreboard adatok
  ├── src/
  │   ├── core/              # Motor, állapotgép (State Machine), ablakkezelő
  │   ├── entities/          # Játékos, ellenségek, bossok, lövedékek
  │   ├── combat/            # Sebzésszámítás, debuff/curse rendszer, statisztikák
  │   ├── dungeon/           # Szobák, csapdák, akadályok, logikai triggérer
  │   ├── items/             # Tárgyak, inventory, szettbónusz menedzser
  │   ├── ui/                # HUD, build menü, scoreboard képernyők
  │   └── main.py            # Belépési pont
  ├── GAME_DESIGN.md         # Játékterv a gyökérben
  └── requirements.txt       # Függőségek
  ```

---

## 4. Mérföldkövek & Fejlesztési Lépések

* **Mérföldkő 1: Alap játékmotor & Környezet (Foundation)**
  - Virtuális környezet előkészítése `Pygames` mappában, `pygame-ce` telepítése.
  - Alap ablakkezelés, 60 FPS loop, Állapotgép (`State Machine`).
* **Mérföldkő 2: Karakter & Multiclass Rendszer**
  - Mozgás és vezérlés (WASD + egér célzás/támadás).
  - Kasztválasztás, szintelosztás és aktív skillbar.
* **Mérföldkő 3: Akadályok, Csapdák & Átok-rendszer (Attrition & Curse)**
  - Tűzcsapdák, mérgező zónák, rúnakorlátok.
  - Átkok és sebesülések (Curse, Max HP csökkentés, mana szívás), ha a karakter nem tudja ártalmatlanítani az akadályt.
* **Mérföldkő 4: 1. Dungeon & Főboss (Gravekeeper Malakar)**
  - Kripta dungeon felépítése (folyosók, csapdák, hordák, mini-boss).
  - Malakar több-fázisú bossfight-ja (minion idézés, fázisváltások).
* **Mérföldkő 5: Loot & Epic/Legendary Szettek**
  - Felszereléskezelő, szettbónusz kalkulátor.
* **Mérföldkő 6: Scoreboard Rendszer (+/- 5 szint & 12 Boss átlagidő)**
  - Eredménykijelző a boss halálakor.
  - Ranglista szűrés szint szerint és globális átlagidő kalkuláció.
