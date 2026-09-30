# D&D Multiclass Boss-Rush RPG — Részletes Játékterv
**Munkacím:** *"Builds & Bosses"

---

## 1. Koncepció összefoglaló

**Műfaj:** 2D akció-RPG Flutter/Flame alapon, D&D multiclassing szabályrendszerrel és koreografált dungeon futamokkal.

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

## 3. Technikai Architektúra & Megvalósítás (Flutter/Flame)

* **Nyelv:** Dart
* **Keretrendszer:** Flutter és Flame
* **Grafikai rács:** 48 pixeles tile-ok és alap karakter-sprite-ok; a nagyobb ellenfelek ennek egész számú többszörösei.
* **Célplatformok:** Windows és Linux, közös játéklogikával és platformonként külön csomagolt kiadással.
* **Projekt Struktúra:**
  ```
  builds-and-bosses/
  ├── assets/                # Sprite-ok, hangok, betűtípusok
  │   ├── characters/
  │   ├── dungeons/
  │   ├── bosses/
  │   └── ui/
  ├── data/                  # Adatvezérelt játék- és mentésadatok
  │   ├── bosses/
  │   └── heroes/
  ├── app/
  │   ├── lib/core/          # Headless D&D, combat, actions, config, platform contracts
  │   ├── lib/game/          # Flame world, entities, physics, camera, VFX
  │   ├── lib/ui/            # Flutter HUD és overlayek
  │   ├── lib/platform/      # Desktop window adapterek
  │   └── test/              # Headless és Flutter tesztek
  ├── data/                  # Verziózott JSON tartalom és mentések
  ├── schemas/               # JSON schema-k
  └── docs/                  # Projekt- és fejlesztési dokumentáció
  ```

### 3.1. Platformfüggetlen Fejlesztési Szabványok

* A játéklogika nem használhat Windows- vagy Linux-specifikus API-t. Platformfüggő műveleteket Flutter/Dart absztrakciókon keresztül kezelünk.
* Fájlutakat platformfüggetlen Dart API-kon keresztül építünk fel; tilos a kézzel összefűzött `\\` vagy `/` útvonal.
* Az assetek, a statikus adatfájlok és a felhasználói mentések külön kezelendők. A mentés nem kerülhet a telepítési könyvtárba.
* A fájlnevek kisbetűsek és case-sensitive kompatibilisek legyenek, hogy Windows és Linux alatt azonosan működjenek.
* A képernyőméret, DPI, billentyűzet és kontroller nem lehet hard-coded feltételezés. A bemenetet absztrakciós rétegen keresztül kezeljük.
* A játékidő és a fizika delta time alapján működjön, hogy az eltérő FPS ne változtassa meg a játékmenetet.
* A játékadatok JSON-ban maradnak, a Dart core réteg pedig a szabályokat és a végrehajtást tartalmazza. A tartalom hozzáadása lehetőleg kódmódosítás nélkül történjen.
* A kliens Steam nélkül is indítható marad; a Steam API integráció opcionális adapterként kerül a platformszolgáltatások rétegébe.

### 3.2. Programozói és Játékfejlesztési Alapelvek

* **Egy felelősség:** egy modul vagy osztály egy jól körülhatárolt feladatért felel; a UI nem számol harci sebzést, az entity nem ment JSON-t.
* **Adatvezérelt tervezés:** bossok, kasztok, tárgyak, pályák és balanszértékek konfigurációs adatokból töltődnek.
* **Determinista játékszabályok:** ugyanaz a bemenet és ugyanaz a seed azonos harci eredményt adjon; ez szükséges a hibakereséshez és a ranglisták hitelességéhez.
* **Függőségek irányítása:** a core réteg ne importáljon UI-t; az állapotok a core és domain szolgáltatások nyilvános interfészeit használják.
* **Kis, tesztelhető egységek:** a sebzésszámítás, mentődobások, debuffok, loot és időmérés Flutter-renderelés nélkül is tesztelhető.
* **Fail-safe betöltés:** hibás vagy hiányzó asset esetén placeholder jelenjen meg és fejlesztői figyelmeztetés készüljön; a játék ne omoljon össze.
* **Visszafelé kompatibilis mentések:** a mentésformátum verziózott legyen, és a régebbi mentések migrálhatók maradjanak.
* **Kiadás előtti ellenőrzés:** minden változtatás után szintaxisellenőrzés, headless smoke test és a releváns domain tesztek fussanak le Windows és Linux buildben is.
* **Minimális, olvasható kód:** meglévő absztrakciót használunk új párhuzamos rendszer létrehozása helyett; a komment csak nem egyértelmű döntést dokumentál.

---

## 4. Mérföldkövek & Fejlesztési Lépések

* **Mérföldkő 1: Alap játékmotor & Környezet (Foundation)**
  - Flutter/Flame projekt és a platformfüggetlen core réteg előkészítése.
  - Alap ablakkezelés, játékhurok és állapotgép (`State Machine`).
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

---

## 2. Játékmechanikák

### 2.1. Dinamikus Harcrendszer

- **Tökéletes Hárítás (Parry):** A támadás előtti utolsó képkockákon (frames) aktiválva kivédi a sebzést, stunnolja az ellenfelet, és "Opportunity Attack" kontrát ad (STR stat növeli a hatékonyságát).
- **Elugrás (Dodge Roll):** Területi (AoE) és háríthatatlan támadások ellen. Sebezhetetlenségi ablakot (i-frame) ad (DEX stat skálázza az i-frame hosszát).
- **Mágikus Barrier:** Ideiglenes extra pajzs, amely elnyeli a státuszhatásokat (méreg, átok) és a sebzést. A sikeres varázslatok vagy a WIS/INT statok csökkentik az újrahasználati idejét (Cooldown).

### 2.2. A Bossig Vezető Út (Dungeon Gauntlet)
Előre koreografált pályák, ahol a hős erőforrásait és D&D mentődobásait (Save Checks) teszteli a játék.

- **Hordák:** Ügyesség és erőforrás-menedzsment (HP/Mana) tesztelése.
- **Környezeti Veszélyek (D&D Mentődobások):**

- *Csapdák (Reflex Save / DEX):* Sikertelen mentődobás esetén HP vesztés és lassítás. Rogue/Ranger kasztok előnyben.
- *Mérgek (Fortitude Save / CON):* Sikertelen mentő esetén DoT (Damage over Time) és stat-debuff a boss-ra. Barbarian/Paladin előnyben.
- *Átkok (Will Save / WIS/CHA):* Sikertelen mentő esetén Cooldown növekedés vagy gyógyulás-csökkenés. Cleric/Paladin előnyben.

---

## 3. RPG Rendszer: Statok és Multiclassing
A DDO (Dungeons & Dragons Online) szabályaira épülő első képességtábla:

- **Alapstatok:** STR (Parry/Sebzés), DEX (Dodge/Kritikus), CON (HP/Méreg-ellenállás/**DoT tick rate**), INT (Képzettség/Barrier tartósság/**környezet manipulálása**), WIS (Spell Cooldown/Átok-ellenállás/**gyenge pontok és rejtett útvonalak**), CHA (Buffok ideje/Különleges képességek/**csatlós-befolyásolás**).
- **Kezdő képességek:** minden érték 8-ról indul, a játékos 28 pontos DDO point-buy keretből emelhet 18-ig. A költségek: `8=0, 9=1, 10=2, 11=3, 12=4, 13=5, 14=6, 15=8, 16=10, 17=13, 18=16`.
- **Képességmódosító:** `floor((érték - 10) / 2)`, tehát a nyers érték mellett mindenhol a módosító kerül felhasználásra.
- **Multiclass hatás:** a kasztok elsődleges képességei meghatározzák a támadás és a varázslás hatékonyságát; a karakter összszintje adja a proficiency bónuszt.
- **Következő bővítés:** 4. karakter-szintenként +1 képességpont, később DDO-szerű tome- és enhancement-rendszer.
- **Szintlépés & Multiclassing:** Minden szinten választható egy alapkast (Melee, Ranged, Arcane, Divine) subclass-sza. A játék támogatja a hibrid buildeket (pl. Fighter/Wizard = Eldritch Knight).

---

## 4. Tárgyrendszer és Looting
Nincs hagyományos mob-farmolás. Felszerelést kizárólag a 12 Boss garantált dobásából lehet szerezni.

- **A 4-ből 1 Szabály:** A boss halála után 4 tárgy esik (Kardforgató, Vándor, Varázshasználó, Szentséges). A játékos **csak egyet** tarthat meg.
- **Kaszthez Kötött Felszerelés (Restriction):** A játékos csak olyan archetípusú tárgyat vehet fel, amilyen kasztba már tett legalább 1 szintet (Multiclass).

### 4.1. A 3x3-as Felszerelés Mátrix (9 Slot)
A karakter 9 vizuális és funkcionális slotot tölthet ki.

| Slot | Kardforgató (Melee) | Vándor (Ranged) | Varázshasználó (Arcane) | Szentséges (Divine) |
|:---|:---|:---|:---|:---|
| **Fent Bal** | Nehéz Vállvért | Állati Követő (Pet) | Familiáris | Szent Nyaklánc |
| **Fent Közép** | Lovagi Sisak | Árny Csuklya | Mágus Tiara | Égi Áldás |
| **Fent Jobb** | Páncél Kesztyű | Zsivány Gyűrű | Demonius Szárny | Divine Szárny |
| **Közép Bal** | Kard / Fejsze | Íj / Számszeríj | Varázspálca | Papi Vándorbot |
| **Közép Közép** | Teljes Mellkas-Páncél | Bőrvért / Vadász ruha | Mágus Köntös | Papi Csuha |
| **Közép Jobb** | Nehéz Pajzs | Tőr / Kézíj | Grimoire / Rúna | Szent Szimbólum |
| **Lent Bal** | Csatás Deréköv | Eszköztár Öv | Mana-kristály Öv | Áldott Ereklye |
| **Lent Közép** | Teljes Lábvért | Vadász Csizma | Mágus Papucs | Papi Szandál |
| **Lent Jobb** | Sarkantyús Csizma | Lopódzó Bokapánt | Mágikus Nyomvonal | Rúnás Amulett |

---

## 5. Metagame: Cloud Scoreboard és Progresszió
A 12 boss-t egy lineáris térképen lehet megközelíteni, de a 9 slot feltöltéséhez (és az ideális tárgyak megszerzéséhez) a játékosnak döntenie kell a visszatérés (Backtrack/Grind) és a kockázatvállalás (Risk-Run) között.

A játék bár Singleplayer, a Cloud Scoreboard teremti meg a PvP-t.

**Rögzített és Szűrhető Leaderboard Adatok:**

1. **Kill Time:** A tiszta harci idő a Boss ellen (Speedrun metrika).
2. **Fight Count (Harcok Száma):** Hány összes harcot (beleértve a backtrack-et és a halálokat is) vívott a játékos az aktuális győzelemig. (A "Minimalist Run" metrikája).
3. **Karakter Szint és Multiclass Build:** Pl. "Lv. 6 (Fighter 4 / Wizard 2)".
4. **Harci Mód (Manual vs. Auto-Roll):** Egy jelzés (és szűrőfeltétel) a ranglistán, ami megkülönbözteti a reflex-alapú és a stat-alapú játékosokat.

### Auto-Kitérés (Stat-Based Combat Toggle)
Az Auto-kitérés bevezetése zseniális híd a reflexekre építő akció-RPG-k (pl. *Dead Cells*) és a klasszikus kockadobásos cRPG-k (pl. *Baldur's Gate, DDO*) között. Ezzel a funkcióval megduplázható a játék célközönsége: azok is élvezhetik a mély loot- és multiclass-rendszert, akik a taktikai tervezést szeretik a "twitch-reflex" gombnyomkodás helyett.

#### Így működik a gyakorlatban:

- **Nincs gombnyomás:** Bekapcsolt állapotban a játékosnak nem kell a megfelelő képkockán (frame) megnyomnia a Dodge vagy Parry gombot. A karakter magától mozog és reagál a beérkező támadásokra.
- **Passzív Mentődobások (Saving Throws):** A harc kimenetele tisztán a karakter buildjén és az elosztott statisztikákon múlik. Amikor a Boss támad, a rendszer a háttérben azonnal dob (pl. egy virtuális D20-at):

- **Fizikai elugrás (Dodge):** A rendszer a játékos **DEX (Ügyesség)** statját és Reflex mentőjét veti össze a Boss támadó értékével. Ha sikeres, a pixel-karakter automatikusan elgurul.
- **Hárítás (Parry):** Nehéz fizikai támadásoknál a játékos **STR (Erő)** statját használja a rendszer. Sikeres dobásnál a karakter automatikusan blokkol és kontráz.
- **Mágikus Barrier / Átkok:** A **WIS/CON (Bölcsesség/Állóképesség)** statok döntik el, hogy a karakter automatikusan elnyeli-e a sebzést, vagy megkapja a debuffot.
- **Build-központú kihívás:** Ebben a módban a játékos feladata a harc *előtt* dől el. A megfelelő kasztok összeválogatása, a szinergiák megtalálása és a 9 slot optimális feltöltése (hogy a védődobások a lehető legmagasabbak legyenek) válik a játék fő fókuszává.

A Scoreboard "Harci Mód" szűrője biztosítja, hogy a hardcore reflex-játékosok ne érezzék úgy, hogy "csalókkal" vannak egy listán, miközben az asztali D&D szabályok szerelmesei egy saját, tisztán a statok optimalizálásáról szóló bajnokságban versenyezhetnek.

---

## 6. Összefoglaló
A játék célja, hogy a boss-rush, a D&D-szerű stat- és kasztépítés, valamint a szigorúan korlátozott loot-kiválasztás kombinációjával a gamerek számára azonnal értelmezhető, de mélyen optimalizálható élményt nyújtson. A fő játékmeneti hurok egyszerű: lineáris útvonal a bossig, boss legyőzése, egy tárgy kiválasztása, majd a következő kihívás vagy a korábbi szintre való visszatérés. Ez a struktúra összhangban van a speedrun, a build-kutatás és a kontrollált kockázatvállalás szeretetével, miközben a változatos boss-mechanikák és a 9 slotos felszerelési mátrix garantálja a hosszú távú reprodukálhatóságot és újrajátszhatóságot.

## 7. Campaign Blueprint és Level-Gap állapotgép

A Campaign Blueprint a futam egyetlen forrása a hős szintjéhez, a multiclass elosztáshoz, az attribútumokhoz, a feat-ekhez és az enhancement pontokhoz. Egy blueprint legfeljebb három különböző kasztot tartalmazhat. Az `app/lib/core/campaign/` domain-modellje validálja a választásokat.

Az állapotgép fázisai:

1. `BLUEPRINT`: a játékos kiválasztja a bosst és a `LEVEL_DOWN` vagy `LEVEL_UP` szintmódot.
2. `GAUNTLET`: egymás után lefut a három reflex-, fortitude- és will-alapú szoba.
3. `BOSS`: a boss szintje rögzített, a hős szintje a mátrixból származik.
4. `COMPLETE`: győzelem után a futam eredménye scoreboard payload-dá alakítható; a következő boss új blueprint fázissal indul.

A kiválasztott blueprint összszintjének pontosan egyeznie kell a mátrix szerinti hősszinttel. Így a level-gap nem csak UI-szöveg, hanem futamindításkor ellenőrzött szabály. A 11. boss a mátrixban marad, és a `complete_boss()` után nem lép automatikusan további kampánybossra; ez az Open Arena feloldásának belépési pontja.

## 8. Minimális játszható munkafázis: Blueprint Table + Malakar

Az első vertical slice célja egy teljes, röviden végigjátszható hurok:

1. A játékos belép a **Tervezőasztalra**, és kiválasztja az első boss előtti `LEVEL UP` vagy `LEVEL DOWN` módot.
2. A játékos a mátrix szerinti szintet osztja el legfeljebb három kaszt között, kiosztja a hat alapattribútumot, majd ENTER-rel megerősíti a blueprintet.
3. A rendszer validálja a kasztlimitet és a pontos összszintet, létrehozza a `Character` modellt, és elindítja az első boss arénát.
4. A játékos megküzd **Gravekeeper Malakarral**: mozoghat, ugorhat, támadhat és védekezhet; a boss lövedéket és közelharci támadást használ, valamint 40%-os HP alatt enrage fázisba lép.
5. Győzelem vagy halál után a futam eredménye a scoreboard állapotba kerül.

Az első slice elfogadási feltételei:

- `LEVEL DOWN`: Hero Lv 1 vs Boss Lv 4; `LEVEL UP`: Hero Lv 2 vs Boss Lv 4.
- A blueprint legfeljebb három különböző kasztot tartalmazhat.
- Hibás összszinttel vagy üres builddel a futam nem indítható el.
- A headless smoke test képes a Tervezőasztalról Malakar BOSS állapotába eljutni.

A három gauntlet szoba, a feat/enhancement választófelület, a további bossok és a cloud scoreboard payloadja ezután külön, egymásra épülő munkafázis.

## 9. További Game Design Irányvonalak

### 9.1. Vizuális és Audio Irányvonal (A Kontraszt)

A játék a klasszikus dark fantasy asztali szerepjátékok vizualitását váratlan, modern zenei és kulturális réteggel ötvözi.

- **A tér (dioráma):** 3D-s térérzetet adó, fix kamerás asztali terepasztal, ahol a karakterek animálatlan 2D-s papírbábukként csúsznak és pattognak.
- **Audio és vibe:** Klasszikus szimfonikus zenék helyett modern, kemény trap beatek és generációs ad-libek, például „Wait!” vagy „Sheesh!”. A zenei produceri munkát és a hangeffekteket Samu készíti, ami önironikus meme-alapanyagot biztosít a promóciókhoz.
- **Dinamikus háttér (DoF):** A mélységélességgel elmosott háttérben fokozatosan bontakozik ki a valóság: a gyertyafényes szobáról kiderül, hogy a Játékmester egy kapucnis, húszéves srác, aki a saját beatjeit bömböltetve próbálja legyőzni az ellenfelét.

### 9.2. Játékmenet: D&D 5e és a Situational OP

A játék a taktikai gondolkodást és a kreativitást jutalmazza a monoton farmolás helyett. A harcrendszer alapja a D&D 5e matematikája: d20, Advantage, AC és Saving Throw-k.

- **Hibrid harcrendszer (RTwP):** Valós idejű WASD-mozgás, amely a Space lenyomására azonnal megfagy. A trap zene lelassul, és felugrik a Tervezőasztal UI.
- **Situational OP:** Egy okos builddel a játékos egy adott boss ellen átmenetileg érinthetetlenné válhat; például a Tolvaj egy közelharcos boss ellen magaslatot használhat.
- **Anti-spam dizájn:** A következő boss kíméletlenül bünteti az előző tökéletes taktikát, például területi mérgező gázzal vagy AC helyett Saving Throw-t követelő mágiával. Ez kikényszeríti a 3x3-as Armory folyamatos újraépítését.

### 9.3. Anti-Grind Zsákmányrendszer

A játék elveti az RNG-alapú százalékos lootolást és a végtelen szörnydarálást.

- **Kimerülő boss loot:** Minden boss minden kaszt számára pontosan 9 fix tárgyat tartalmazó loot poollal rendelkezik. Legfeljebb 9 győzelem után a boss nem dob több tárgyat, így a zsákmány 100%-osan kifarmolható.
- **3x3-as Class-Locked Armory:** A megszerzett tárgyakat egy 9 rekeszes gridbe kell behúzni drag-and-drop módszerrel. A tárgyak kaszt-specifikusak, a multiclassing azonban lehetővé teszi a kombinálásukat.

### 9.4. Szezonális Live Service Lite Modell

A szóló fejlesztésből fakadó túlvállalás elkerülése érdekében a tartalom adagolása szezonális modellre épül.

- **MVP, 1.0 rajt, Tavasz szezon:** A teljes 12 boss helyett a rajt 3 bosst és a hozzájuk tartozó 3 tavaszi pályát tartalmazza.
- **Globális modifikátorok:** A szezonok, például a Fojtogató Nyár vagy a Túlburjánzó Tavasz, globális vizuális és mechanikai szabályokat adnak a játékhoz. A tavaszi indák lefogják a hősöket, a téli jég pedig csúszóssá teszi a WASD-irányítást.
- **Költséghatékony tartalomgyártás:** Új szezonhoz nem feltétlenül kell új AI. A meglévő bossok harcait a környezeti modifikátorok és időjárási mechanikák, például a kimerülés vagy a csúszás, alakítják új feladvánnyá.

### 9.5. Meta-narratíva

- **A halál mint fejlődés:** A Game Over nem puszta büntetés. A játékos halála után a Tervezőasztal Hub reagál a kudarcra: új párbeszédek és tippek nyílnak meg a háttérben lévő Entitástól, vagyis a Játékmestertől.

### 9.6. Kickstarter Stratégia

A közösségi kampány Pay-to-Win és drága fizikai jutalmak nélkül működik, az impulzusvásárlás és a tömegbázis helyett a közösségi részvételre építve.

- **5 EUR:** Taverna Támogató, Discord-rang és név a stáblistán.
- **10 EUR:** Kalandor, digitális Steam-kulcs.
- **15 EUR, limitált:** Fegyverkovács, egy fegyver vagy páncél elnevezése az Armoryban.
- **50 EUR, erősen limitált:** Káosz Ura, egy boss vagy elit csatlós elnevezési joga.
- **Stretch Goals:** A kampánycélok a következő szezonok garantált, ingyenes elkészítésére fókuszálnak; például 15 000 EUR-nál elkészülhet a Nyári szezon.

### 9.7. Adatbázis-architektúra

- **Statikus, csak olvasható core:** JSON vagy konstans Dart modellek tartalmazzák az `Abilities_DB`-t, az `Items_DB`-t és a kimerülő `Boss_Loot_Tables`-t.
- **Dinamikus mentési core:** Lokális adatbázis, például Isar vagy Hive, legfeljebb 4 mentési slottal. Tárolja a hősök szintjét, az `Armory_DB` megszerzett tárgylistáját és az `Equipments_DB` 3x3-as rácsának mentett állapotát.

---

## 10. Motor-szintű Tervezési Szempontok

Ez a fejezet azokat a technikai pilléreket rögzíti, amelyeket minden új rendszer tervezésekor figyelembe kell venni. A három pillér: a stat-vezérelt fizika, a komponensalapú architektúra és az adatvezérelt balanszolás.

### 10.1. Fizika és Tömegkezelés: Flame + Forge2D

**Döntés:** nem írunk saját fizikai motort. Az egyszerűség és a stabilitás kedvéért a Flame hivatalosan támogatott **Forge2D** motorjára (a Box2D Dart portja) építjük rá a D&D stat-számításokat. Az ütközésdetektálást, a lendületszámítást és az impulzusfeloldást a Forge2D végzi; a mi felelősségünk az, hogy a statokból helyes fizikai paramétereket származtassunk.

**Statok leképezése Forge2D `Body` tulajdonságokra:**

- **STR → dinamikus test-tömeg (`MassData`):** a Box2D minden testnek külön tömeget és tehetetlenségi nyomatékot (inertia) tart nyilván. Amikor a karakter felszerelést vesz fel vagy STR-t növel, a test tömegét közvetlenül újraszámoljuk — vagy a fixture `density` értékének módosításával és `resetMassData()`-val, vagy explicit `body.setMassData(...)` hívással.
  - Ütközéskor (`beginContact`) a motor automatikusan az aktuális tömegek alapján osztja el a visszalökést: a magas STR karakter elsöpri a könnyebb ellenfelet, a gyenge karaktert viszont a fizika veti hátra.
  - A célzott, képesség-alapú knockback továbbra is explicit `applyLinearImpulse()`, a STR-ből számolt impulzusértékkel.
  - A tömegváltozás mindig a felszerelés- vagy stat-változás eseményéhez kötött, nem képkockánként futó számítás.
- **DEX → lineáris sebesség, irányíthatóság és csillapítás:** a DEX szabja meg a `linearVelocity.x` plafonját, a mozgáserőt (`applyForce`) és a levegőben elérhető irányíthatóságot (air control), például szeles vagy viharos pályákon.
  - A Box2D `friction` és `linearDamping` paramétereivel hangoljuk, hogy a magas DEX-es karakter milyen élesen fordul meg és fékez, illetve hogy az alacsony DEX-es karakter mennyire csúszik meg síkos vagy jeges pályán.
  - A szezonális modifikátorok (pl. a téli jég) a talaj `friction` értékét módosítják, így a DEX értéke pályánként eltérő súlyt kap.
- **CON → knockback-ellenállás:** a bejövő impulzust a CON-ból származó stagger-ellenállás csökkenti, illetve a `linearDamping` növelésével tompítjuk.
- Páncél és felszerelés súlya hozzáadódik az effektív tömeghez, így a nehézpáncélos build lassabb, de nehezebben eltolható.

**Kötelező tervezési szabályok:**

- **Egy igazságforrás:** a Forge2D `Body` a pozíció és a sebesség egyetlen forrása. A komponensek nem írják felül kézzel a pozíciót, hanem erőt/impulzust alkalmaznak.
- **Body típusok:** a karakterek és lövedékek `dynamic`, a pályageometria `static`, a mozgó platformok `kinematic` testek.
- **Collision kategóriák és maszkok:** a hős, az ellenfél, a lövedék, a csapda és a terep külön kategóriában van; a hitbox és a hurtbox `isSensor` fixture-ként létezik, és sosem azonos a fizikai collision fixture-rel.
- **Gyors lövedékek:** `bullet` flag-gel, hogy a continuous collision detection megakadályozza az átugrást (tunneling) a vékony falakon.
- **Determinizmus:** a világot fix időlépéssel léptetjük, a renderelés interpolál. Ugyanaz a seed és bemenet ugyanazt a futamot adja eltérő FPS mellett is, ami a ranglisták hitelességének feltétele.
- A D&D szabályok (kockadobás, sebzés, mentődobás) továbbra is a headless core-ban maradnak; a Forge2D réteg csak a mozgás és az ütközés fizikai következményeit kezeli.

### 10.1.1. Komponensalapú architektúra (ECS-jelleg)

A Flame `Component` rendszere adja a moduláris vázat:

- Egy alap `CharacterComponent` hordozza a Forge2D testet, és külön csatolható hozzá a `StatComponent` (D&D statok és származtatott fizikai paraméterek), a cooldown- és erőforrás-figyelő timer komponens, valamint az animációs állapotkezelő.
- A komponensek nem tartalmaznak D&D képleteket: intentet küldenek a core szolgáltatásoknak, és a visszakapott domain eredményt jelenítik meg vagy alakítják impulzussá.
- Ugyanez a kompozíció használható bossokra, minionokra és lövedékekre is, így egy új kaszt vagy ellenfél összeállítás kérdése, nem új osztályhierarchiáé.

### 10.1.2. INT → Környezetátlátás és Manipuláció (Tactical Commander)

Az INT nem csak passzív bonusz: **a pálya interaktív felületét nyitja meg**, és ezzel taktikai parancsnokká teszi a játékost. Az INT a *külső világot* (környezet, pályaelemek) fordítja a játékos malmára; ennek párja a WIS, amely a *belső világot* (ellenfelek felépítése, rejtett útvonalak) látja át (lásd 10.1.5).

- **Alacsony INT:** a világ lineáris, statikus akadálypálya. Az omladozó sziklafal, a felvonóhíd vagy a mágikus kristály csak díszlet; a karakternek nyers erővel és kitartással kell átverekednie magát.
- **Magas INT:** a karakter „látja a rendszerben a hibát”. Odalép a háttérdekorációnak tűnő instabil oszlophoz, aktiválja, és egy leomló lavinával maga alá temeti az ellenfeleket, vagy átformálja a pályát a saját javára.
- Ugyanaz a pálya így egy alacsony INT-jű, magas STR-es tanknak brutális közelharci daráló, egy magas INT-jű buildnek viszont **kreatív játszótér**, ahol a környezetet fordítja szembe a szörnyekkel.

**Megvalósítás Flame + Forge2D alatt:**

1. **`InteractiveEnvironmentComponent`:** minden olyan pályaelem, ami alacsony INT mellett puszta `SpriteComponent`, magas INT esetén kap egy Forge2D testet és egy `InteractionSensor` triggert. Az elem INT-küszöbét, a jutalmazó hatást és a fizikai paramétereket JSON írja le, nem kód.
2. **Környezeti fizika (lavina / omlás):** aktiváláskor a test típusa `static`-ról `dynamic`-ra vált, így a gravitáció és a tömeg azonnal munkába áll: a sziklák lezúdulnak, ütköznek az ellenfelekkel, sebeznek és lökik őket. A sebzés ekkor is a core D&D szabályokból származik, a becsapódás ereje pedig a fizikai lendületből.
3. **Észlelés és visszajelzés:** az interaktív elem csak akkor kap kiemelést (outline, tooltip), ha a hős INT-je eléri a küszöböt. Alacsony INT mellett az elem létezik, de nem jelzett és nem aktiválható.
4. **Balansz és determinizmus:** a környezeti összeomlások a fix időlépéses világban futnak, így azonos seed és bemenet mellett a speedrun-futamok reprodukálhatók maradnak.
5. **Anti-abuse:** minden interaktív elem egyszer használható futamonként (vagy számlált), hogy a környezet ne váljon végtelen sebzésforrássá.

### 10.1.3. CON → Metabolizmus és DoT-időzítés

A mérgek, átkok és folyamatos sebzések (*Damage over Time*) nem fix összsebzést jelentenek, hanem **időzítőhöz kötött tick-sorozatot**. A CON ezt az időzítőt hangolja:

- **Alacsony CON:** a méreg gyorsan és sűrűn tickel (pl. másodpercenként), így a karakter hamar elvérzik.
- **Magas CON:** a szervezet „lelassítja” a mérget — megnő a tickek közötti idő, és/vagy drasztikusan rövidül a hatás teljes időtartama (kevesebb összes tick).
- **Passzív környezeti csillapítás:** a csapdasebzésnél a CON egyfajta páncélként működik, ami elnyeli a környezeti ütések élét; emellett továbbra is a knockback-ellenállást adja.
- A tick rate, a tick-sebzés, az időtartam és a CON-skálázás görbéje JSON konfiguráció, és a DoT-időzítők a fix időlépéses szimulációban futnak, hogy a futamok reprodukálhatók maradjanak.
- Az Attrition & Curse rendszer démoni átkai ugyanezt a tick-modellt használják, így egy magas CON build a dungeon büntető hatásait is tovább bírja.

**A DoT nyilvántartása (`DamageOverTimeTracker`):**

Minden entitás saját aktív DoT-nyilvántartást vezet; egy bejegyzés a következőket tárolja:

| Mező | Jelentés |
|:---|:---|
| `sourceId` | Ki vagy mi okozta (boss, csapda, környezeti zóna, átok) |
| `damageType` | Méreg, vérzés, tűz, void, átok — külön ellenállásokkal |
| `tickDamage` | Egy tick nyers sebzése |
| `tickInterval` | Tickek közötti idő (CON-skálázott) |
| `remainingDuration` | Hátralévő idő (CON-skálázott) |
| `elapsedSinceTick` | A következő tickig eltelt idő |
| `stacks` / `stackRule` | Halmozódás: `refresh`, `stack`, `strongestWins` |
| `revocable` | Dispel/gyógyítás eltávolíthatja-e |

A CON-skálázás képletei (a konkrét együtthatók JSON-ból jönnek):

$$\text{tickInterval} = \text{baseInterval} \times \left(1 + k_i \cdot \text{CONmod}\right)$$
$$\text{duration} = \text{baseDuration} \times \left(1 - k_d \cdot \text{CONmod}\right)$$
$$\text{tickDamage} = \max\left(1,\; \text{baseTick} - \text{CONmitigation}\right)$$

Ahol a `CONmod` a szokásos `floor((CON - 10) / 2)` képességmódosító, az együtthatók pedig alsó/felső korláttal rendelkeznek (clamp), hogy egy szélsőséges CON build se tegye teljesen hatástalanná a mérgeket.

**Működési szabályok:**

- A tracker a fix időlépéses órán fut, és akár több ticket is végrehajthat egy hosszabb frame alatt (akkumulátor-minta), így az FPS nem befolyásolja az összsebzést.
- A DoT-ok a **modifier pipeline** részei: ha futs közben változik a CON (felszerelés, buff, átok), a már aktív effektek `tickInterval` és `remainingDuration` értéke újraszámolódik a következő ticktől — a már megtörtént sebzés nem íródik vissza.
- Eltérő `damageType`-ok külön bejegyzésként futnak; azonos típus és forrás a `stackRule` szerint egyesül.
- A futam végén a tracker összesítést ad (összes DoT-sebzés típusonként, leghosszabb aktív átok), ami a scoreboard „elszenvedett átkok” metrikáját és a halál utáni visszajelzést táplálja.
- A HUD minden aktív DoT-ot külön ikonnal, hátralévő idővel és tick-ütemmel mutat, hogy a játékos lássa a CON hatását.

### 10.1.4. CHA → Harctéri Manipuláció és Lojális Csatlósok

A csatlósok nem puszta ágyútöltelékek: a CHA egy aktív **befolyásolási küszöböt** (threshold) ad.

- Ha egy minion HP-ja egy megadott százalék alá esik (pl. 25%) és kedvező helyzetben van (pl. sarokba szorult), a magas CHA-jú hős **Demoralize / Charm** fázist indíthat.
- Siker esetén a csatlós nem öngyilkos rohamot indít, hanem átáll a hős oldalára, és a bosst támadja, amíg el nem pusztul.
- A próba klasszikus D&D mentődobás: a hős CHA-alapú értéke a minion Will mentője ellen. Sikertelen dobásnál a minion enrage-elhet, tehát a kísérlet kockázatos.
- Az átállt csatlós üj collision kategóriát és AI célpontot kap, de a játékos nem irányítja közvetlenül; élettartama korlátozott (charm duration), amit a CHA skáláz.
- Bossonként korlátozott, hogy egyszerre hány csatlós fordulhat át, így a mechanika taktikai és nem végtelen hadsereg-építés.
- A küszöbértékek, az időtartam, a párhuzamos limit és a kudarc következménye adatvezérelt JSON értékek.

### 10.1.5. WIS → Gyenge Pontok és Rejtett Útvonalak

Míg az INT a külső világot nyitja meg, a WIS a *belső felépítést* látja át: az ellenfelek szerkezetét és a pálya rejtett járatait.

**1. Szörnyek gyenge pontjai (harci képesség):**

- A magas WIS-ű karakter aktív fókuszálással (vagy passzív instinkt-triggerrel) észleli a páncél illesztéseit, a mutáns lény izomgyengeségét vagy a mechanikus boss belső áramkörét.
- A célpont ekkor egy `WeakPointComponent` sávot kap: egy külön Forge2D sensor fixture, saját collision kategóriával. Az ide érkező találat extra (kritikus) sebzést kap, és meg is akaszthatja a szörny támadását (*interrupt*), az animációs állapot megszakításával.
- Alacsony WIS mellett a gyenge pont rejtve marad: nincs kiemelés és nincs aktív sensor, a karakter csak a vastag páncélt püföli kevesebb eredménnyel.
- A gyenge pont helye, mérete, sebzésszorzója, WIS-küszöbe és a fókusz cooldownja bossonkénti JSON adat. A kritikus sebzést továbbra is a core D&D szabályok számolják.

**2. Csapda-kerülőutak (navigációs alternatíva):**

- Egy mozgó fűrészekkel és tüskékkel teli folyosó, ami alacsony DEX vagy CON mellett rémálom, magas WIS-szel rejtett lehetőségeket tartogat.
- A WIS „felfedezi” a falak mögötti szerelőjáratokat, a karbantartó alagutakat vagy a csapdaritmus holtterét, így a játékos teljesen kikerülheti a legveszélyesebb zónákat ahelyett, hogy átugrálna rajtuk.
- Motor szinten ez egy `HiddenRouteComponent`: WIS-küszöb alatt zárt és jelöletlen geometria, küszöb felett kiemelt és járható útvonal (a blokkoló fixture kikapcsol vagy sensorré válik).
- A kerülőút nem ingyen előny: jellemzően hosszabb vagy saját kihívást tartalmaz, hogy a speedrun-idő és a biztonság között valódi döntés legyen.

### 10.1.6. Stat → Motor Összkép

A hat alapstat egy-egy külön motor-rendszert vezérel, így a build metroidvania-szerűen más-más rétege nyitja meg a pályát:

| Stat | Motor-rendszer | Hatás |
|:---|:---|:---|
| **STR** | Forge2D `MassData`, impulzus | Tömeg, lendület, knockback, átgázolás |
| **DEX** | `linearVelocity`, `friction`, `linearDamping` | Sebesség, gyorsulás, air control, jeges/szeles pályák |
| **CON** | DoT tick-időzítők, sebzéscsillapítás | Mérgek és átkok lassítása, csapdasebzés tompítása |
| **INT** | `InteractiveEnvironmentComponent` | Környezeti elemek (lavina, híd, kristály) aktiválása |
| **WIS** | `WeakPointComponent`, `HiddenRouteComponent` | Gyenge pontok feltárása és csapda-kerülőutak |
| **CHA** | Minion influence threshold | Boss-csatlósok átállítása kritikus HP alatt |

### 10.1.7. Modifier Pipeline: Folyamatos újraszámolás és Kikapcsolás

A statok **soha nem közvetlenül** vezérlik a Forge2D testeket. Köztük egy determinista számítási lánc áll, így egy átok vagy környezeti hatás bármikor átírhatja vagy inaktívvá teheti az adott képességet:

```text
base stats -> modifier rétegek -> effective stats -> származtatott paraméterek -> Forge2D body / capability set
```

**A modifier rétegek rögzített sorrendben értékelődnek ki** (a determinizmus feltétele):

1. base stats (point-buy + szint)
2. felszerelés és szettbónuszok
3. feat / enhancement
4. aktív buffok
5. átkok és debuffok (Attrition & Curse)
6. környezeti és szezonális modifikátorok (jeges talaj, fojtogató nyar, void zóna)

**Miert olcsó ez futas közben:**

- **Eseményvezérelt, nem képkockánkénti:** az effective stat blokk csak akkor számítódik újra, ha egy modifier hozzáadódik, lejár vagy megváltozik (dirty flag). Közben a gyorsítótárazott értékeket olvassuk.
- **Egy helyen dől el minden:** az újraszámolás után egyetlen `applyToBody()` lépés írja át a `MassData`-t, a `friction`-t, a `linearDamping`-et és a sebességplafont. Nincs szórt, több helyen kavaró stat-logika.
- **Additív és multiplikatív részek külön:** a modifierek `+flat` és `×mult` mezőkben érkeznek, így a visszavonás nem lebegőpontos hibával történik, hanem a forrás eltávolításával és teljes újraértékeléssel.

**Képességek kikapcsolása (capability set):**

- A küszöbhöz kötött képességek (INT-es környezeti aktiválás, WIS-es gyenge pont és rejtett útvonal, CHA-s charm) nem állandóan futnak, hanem egy **capability set**-ből olódódnak fel, amit az effective statok újraszámolása frissít.
- Ha egy átok lehuzza az INT-et a küszöb alá, az érintett `InteractiveEnvironmentComponent` azonnal elveszti a kiemelést és a sensorát — a pálya ugyanabban a pillanatban „bezárul” a játékos előtt.
- A már elindított hatások viselkedése **expliciten deklarált**: a már leomlott szikla nem kerül vissza, de a már átállított minion charm-ideje a frissített CHA szerint rövidülhet. Ezt a szabályt minden képesség adata tartalmazza (`revocable: true/false`).
- **Hiszterézis:** a küszöbök alá/fölé ingadozás (flapping) ellen a be- és kikapcsolási küszöb eltérő, illetve minimális tartási idő van, hogy egy pulzáló átok ne villogtassa a pályaelemeket.

**Fizikai állapotátírás közben:**

- A `MassData` és a fixture-paraméterek módosítása mindig a fizikai lépések között történik, sosem ütközés-callback (`beginContact`) belsejében — a változások egy várakozó sorba kerülnek és a step végén érvényesülnek.
- A tartós DoT-ok és a mozgás paraméterei fix időlépéses órán futnak, így az átkok dinamikus be- és kikapcsolása sem rontja el a replay reprodukálhatóságát.
- A UI mindig az effective statot és a ható modifierek listáját mutatja, hogy a játékos lássa, *miért* tűnt el egy képessége.

### 10.1.8. Irányítási Pipeline: Stat- és Környezetfüggő Kontroll

Az irányítás nem közvetlen gomb → mozgás leképezés. A nyers bemenet és a fizikai test között ugyanolyan rétegzett lánc áll, mint a statoknál, hogy minden külső hatás (átok, jeges talaj, void zóna, szél) becsatlakozhasson:

```text
nyers bemenet -> InputIntent -> ControlModifier rétegek -> EffectiveControl -> Forge2D erő/impulzus
```

**Rétegek és felelősségük:**

1. **Bemeneti absztrakció:** billentyűzet, egér és kontroller egységes `InputIntent`-té alakul (`moveAxis`, `jump`, `attack`, `dodge`, `parry`, `interact`, `focus`, `tacticalPause`). A játéklogika soha nem lát nyers billentyűkódot, így a remapping és az új eszköztípus ködség nélkül hozzáadható.
2. **Stat-alapú kontroll:** a DEX a gyorsulást, a fordulás élességét, a levegőbeli irányíthatóságot (air control) és a coyote/input buffer ablakot skálázza; a STR a tömeget, így a nehezebb karakter tehetetlenebbül indul és áll meg; a CON a stagger és a megszakítás utáni visszanyügvési időt.
3. **Állapot-alapú korlátozás:** stun, fagyasztott, gyökérbe fogott, elmebontott (invertált irány), néma (képességtiltás), túlterhelt (encumbrance). Ezek nem önálló speciális ágak a kódban, hanem `ControlModifier` bejegyzések.
4. **Környezeti és szezonális réteg:** jeges padló (csökkentett `friction`), szél (folyamatos oldalerő), sár és indák (sebességplafon), víz alatti közeg (más gravitáció és damping), void zóna (fordított vagy késleltetett bemenet).
5. **Harci mód réteg:** a Manual és az Auto-Roll mód, valamint a Tactical Pause (RTwP) ugyanezen a láncon ül — auto módban a rendszer maga állít elő `dodge`/`parry` intentet a mentődobások alapján, de a végrehajtási út azonos.

**Egy `ControlModifier` deklarált mezői:**

| Mező | Jelentés |
|:---|:---|
| `source` | Átok, terep, időjárás, felszerelés, boss-képesség |
| `priority` | Rögzített kiértékelési sorrend a determinizmus miatt |
| `speedMult` / `accelMult` | Sebesség- és gyorsulásszorzó |
| `frictionOverride` | Talajsúrlódás felülírása (jég, sár) |
| `externalForce` | Állandó külső erő (szél, sodrás, vonzás) |
| `axisTransform` | Iránytranszformáció: invertálás, tengelycsere, holttér |
| `inputDelay` | Bemeneti késleltetés (elmebontó hatások) |
| `blockedActions` | Letiltott intentek listája |
| `duration` / `revocable` | Időtartam és eltávolíthatóság (dispel) |

**Bővíthetőségi szabályok (kötelező):**

- Új irányítást befolyásoló hatás **kizárólag** új `ControlModifier` adatbejegyzés lehet. Tilos a mozgáskódba ágazni (`if (isFrozen) ...`).
- Az összes mező opcionális és alapértelmezett értékkel rendelkezik, így egy új mező hozzáadása nem töri a meglévő JSON adatokat (visszafelé kompatibilis sémabővítés).
- A rétegek rögzített `priority` sorrendben értékelődnek ki, és az eredmény clamp-elve kerül a fizikára, hogy két egyszerre ható átok se okozzon játékképtelen állapotot (mindig marad minimális mozgásképesség, kivéve az expliciten teljes stunt).
- Az `InputIntent` és az `EffectiveControl` szerializálható, így a debug replay a bemenetet is rögzíti — azonos seed és intent-sorozat azonos futamot ad.
- A HUD jelzi az aktív kontroll-modifiereket (pl. „csúszik”, „fordított irány”), hogy a játékos ne „elromlott irányításként” élje meg a mechanikát.
- Minden új kontroll-modifier típushoz headless teszt készül, amely intent-sorozattal ellenőrzi a származtatott mozgásparamétereket Flame renderelés nélkül.

### 10.2. Animációs és Képkocka-kezelő (Sprite / Marionette Pipeline)

A 12–14 képkockás marionett-váz animációkhoz a Flame beépített renderelő elemeit használjuk: alap esetben `SpriteAnimationComponent`, sok egyszerre mozgó ellenfélnél a nagy teljesítményű `SpriteBatch`, hogy az FPS a hordáknál is stabil maradjon.

- **Sprite Sheet / Texture Atlas:** A textúrákat összefűzött atlaszokban töltjük memóriába, és batch-elt rajzolással jelenítjük meg, hogy a draw call-ok száma alacsony és az FPS stabil maradjon. Karakterenként/bossonként egy atlasz a cél.
- **Frame-számláló logika:** Rugalmas időzítő, amely az animáció lejátszási sebességét a DEX-hez, a támadási sebességhez vagy az aktuális cselekvéshez igazítva gyorsítja/lassítja. Az animáció sebessége adat, nem hard-coded konstans.
- **Animation events:** A képkockákhoz eseményeket kötünk (pl. a támadás aktív hitbox ablaka, a parry frame-ek, a lépészaj). A harci logika ezeket az eseményeket kapja meg, nem a nyers frame indexet.
- A *marionette* réteg (papírbábu-szerű, csúszó-pattogó mozgás) ugyanezen a pipeline-on ül: a bábu transzformációi a Forge2D testhez vannak csatolva, a vizuális réteg sosem írja vissza a fizikai állapotot.
- Hiányzó vagy hibás sprite esetén placeholder és fejlesztői figyelmeztetés jelenik meg; a játék nem omolhat össze.

**Helyben animálás és valódi elmozdulás (locomotion):**

A két dolog külön rétegben él: a sprite **helyben** jár, a karaktert a fizika viszi előre.

- **Root motion nincs a kockákban.** Minden póz ugyanarra a függőleges tengelyre és ugyanarra a talajvonalra van igazítva, csak a végtagok mozognak. A vizuális elmozdulást kizárólag a Forge2D test pozíciója adja.
- **Az animációs állapotot a test sebessége választja ki**, nem a lenyomott gomb: `|vx|` küszöbök alapján idle / walk / run, a függőleges sebesség és a ground sensor alapján jump / fall. Így a jégen csúszva vagy szélben felékelve is a tényleges mozgás látszik.
- **Lépéshossz-szinkron a lábcsúszkálás ellen:** a lejátszási sebesség nem fix, hanem a tényleges sebességhez kötött:

$$\text{stepTime} = \frac{\text{strideLength}}{\max(|v_x|,\; v_{min})}$$

  Ahol a `strideLength` az adott animáció adatából jön (hány pixelt „lép” egy ciklus). Ez automatikusan megadja a 10.1.8-ban leírt DEX-függő animációsebességet is: a gyorsabb karakter gyorsabban szedi a lábát, mert ténylegesen gyorsabban halad.
- **Irányváltás:** a sebesség előjelének váltásakor a turn kocka játszik le átkötésként (nem loop), majd az új irány walk/run ciklusa folytatódik. A turn nem szakítja meg a fizikai mozgást.
- **A támadás, parry és dodge animációk felülírják a locomotion állapotot**, de a test továbbra is a fizika szerint mozog; az i-frame és a hitbox ablak animation event-ből jön, nem az állapotváltásból.

### 10.3. Adatvezérelt Architektúra (Data-Driven Design)

A 12 pálya és a havonta érkező új kasztok miatt folyamatos balanszolásra van szükség, ezért **tilos** a játékértékeket kódba égetni:

- A D&D statok, fegyverek, képességek, cooldownok, a 12 pálya paraméterei, valamint a Forge2D-nek átadott fizikai paraméterek (sűrűség, súrlódás, restitúció, damping, gravitáció, gyorsulás, knockback-impulzus szorzók, i-frame hossz) külső konfigurációs fájlokból (**JSON**, szükség esetén TOML) töltődnek be.
- Egyetlen érték átírásával azonnal tesztelhető a fizikai és harci változás, újrafordítás nélkül.
- Minden konfigurációs fájl verziózott sémával (`_schema`) rendelkezik, és a `tooling/validate_data.ps1` ellenőrzi a biztonságos értéktartományokat.
- Az animációs definíciók (frame-szám, sorrend, sebesség, loop, animation event-ek) szintén adatként léteznek, így új kaszt hozzáadása lehetőleg kódmódosítás nélkül történik.
- Minden új konfigurációs értékhez headless teszt tartozik, amely rögzíti a várt viselkedést.

### 10.4. Tervezési Ellenőrzőlista Új Rendszerekhez

Új mechanika vagy boss tervezésekor végig kell menni ezen a listán:

1. Milyen Forge2D body típus, fixture, sensor (hitbox/hurtbox) és collision kategória tartozik hozzá?
2. Milyen tömeg-, impulzus- és knockback-viselkedést vár el, és melyik stat skálázza (STR/DEX/CON)?
3. Van-e INT-küszöbhöz kötött interaktív környezeti alternatíva, és mi az alacsony INT-es brute-force útvonal?
4. Determinista-e fix időlépés és azonos seed mellett?
5. Milyen animációs állapotok és animation event-ek kellenek hozzá?
6. Melyik JSON konfigurációs fájlba kerülnek a hangolható értékek, és van-e sémája?
7. Van-e rá headless teszt a Flame renderelés nélkül?
