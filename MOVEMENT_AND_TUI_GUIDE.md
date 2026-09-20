# Builds & Bosses — Mozgás- és TUI-irányelvek

Ez a dokumentum a Dungeon Slasher-jellegű, oldalnézetes karakter-, boss- és lövedékmozgás megvalósítási szabályait, valamint a játék terminál-inspirált, pixel-art felületének ajánlásait rögzíti.

## 1. Grafikai alapértékek

- Alap frame-méret: `48×48 px`
- Pixel-art skálázás: nearest-neighbor (`pygame.transform.scale`)
- Színtér: RGBA PNG átlátszó háttérrel
- Tile-méret: `48×48 px`
- Kamera: oldalnézeti, vízszintesen követő kamera
- Belső logikai felbontás: `1280×720`
- Animáció: frame-alapú spritesheet, nem folyamatos blur vagy interpolált skálázás
- Asset-fájlnevek: kisbetűsek, szóköz nélkül, Linux case-sensitive kompatibilitással

## 2. Karakteranimációk

A motor a következő könyvtárstruktúrát keresi:

```text
assets/characters/<class_id>/
  idle.png
  run.png
  jump.png
  fall.png
  attack.png
  block.png
  cast.png
  hit.png
  dodge.png
  death.png
```

Az oldalnézeti játék egyetlen alap nézetet használ. A karakter jobbra néző sprite-jait balra vízszintesen tükrözni lehet, ezért külön bal és jobb spritesheet nem szükséges. A vertikális irányt a mozgásállapotok (`jump`, `fall`) és a testtartás fejezi ki.

### Ajánlott frame-számok

| Állapot | Frame | FPS | Loop |
|---|---:|---:|---|
| `idle` | 4 | 6 | igen |
| `run` | 6 | 10 | igen |
| `jump` | 4 | 10 | nem |
| `fall` | 2 | 8 | igen |
| `attack` | 6 | 12 | nem |
| `block` | 4 | 10 | nem |
| `cast` | 6 | 10 | nem |
| `hit` | 2 | 8 | nem |
| `dodge` | 5 | 14 | nem |
| `death` | 6 | 8 | nem |

Példa:

```text
run.png = 6 × 48 × 48 = 288×48 px
attack.png = 6 × 48 × 48 = 288×48 px
```

### Mozgásállapotok

A játéklogika és a vizuális állapot külön maradjon:

```text
IDLE      nincs irányinput
RUN       van balra vagy jobbra irányinput és a karakter a talajon van
JUMP      ugrás vagy emelkedő függőleges mozgás aktív
FALL      a karakter lefelé mozog és nincs talajkontaktus
ATTACK    támadási animáció aktív
BLOCK     parry/barrier időablak aktív
CAST      varázslat indul
HIT       sebzés érte a karaktert
DODGE     kitérés vagy dodge-roll aktív
DEATH     HP elérte a nullát
```

A sprite-animáció ne módosítsa a játékos valódi pozícióját. A pozíciót a mozgásrendszer számolja, az animátor csak a megjelenített frame-et és az offsetet választja ki.

## 3. Mozgás és harc

- A mozgás delta time alapján történjen, ne frame-számlálással.
- A vízszintes sebesség, gyorsulás és fékezés külön legyen konfigurálható.
- A gravitáció, ugrási sebesség és eséssebesség legyen adatvezérelt.
- A pálya collisionje külön platform-, fal- és sebzésréteget használjon.
- A játékos pozícióját a collision-rendszer korlátozza, ne csak a képernyő széle.
- A sprite vizuális bobbingja legfeljebb 2–4 pixel legyen a talajkontaktus körül.
- Az árnyék maradjon a valódi lábpozíció alatt, ugráskor pedig kisebb és halványabb legyen.
- A támadás és védekezés animációja ne blokkolja a teljes inputrendszert.
- A `SPACE` alapértelmezésben ugrás, a bal egérgomb vagy `J` alapértelmezésben támadás.
- A `SHIFT` alapértelmezésben dash, a `Q/E` pedig kasztképesség lehet.
- A parry/dodge/barrier eredménye a karakter fő kasztjához igazodjon.

## 4. Bossmozgás

A bossok oldalnézeti arénában, a platformokhoz és a játékos vízszintes pozíciójához igazodva három külön viselkedést használhatnak:

```text
  CHASE       vízszintesen közelíti a hőst
MELEE       ütőtávolságban közelharci támadás
RANGED      távolságból adatvezérelt lövedék indítása
```

A boss-adatokat JSON-ban kell tartani:

```json
{
  "projectile": {
    "kind": "necrotic_bolt",
    "speed": 240,
    "radius": 10,
    "damage_die": 6,
    "damage_count": 1
  }
}
```

A boss mozgásanimációi a következő könyvtárba kerüljenek:

```text
assets/bosses/<boss_id>/
  idle.png
  run.png
  jump.png
  cast.png
  hit.png
  death.png
  projectile.png
```

## 5. TUI-jellegű vizuális irány

A játék felülete legyen terminál-inspirált, de ne valódi terminál-emuláció. A cél egy olvasható, sűrű, retro-technikai RPG kezelőfelület.

### Tipográfia

- Monospace betűtípus használata.
- Címsor: nagyobb, félkövér, arany vagy borostyán szín.
- Adatértékek: világos szürke vagy fehér.
- Másodlagos feliratok: tompa kékesszürke.
- Üzenetek: rövidek, egysorosak, ne takarják el a játéktér fontos elemeit.

### Színrendszer

```text
Háttér       #0F111A
Panel        #191C2A
Keretszín    #373E58
Főszöveg     #EBF0F5
Másodlagos   #8C94AA
Arany        #E6AF2D
Élet         #D2373C
Mana         #3C8CF0
Siker        #32BE6E
Átok         #9B4BE1
```

A színeknek funkciójuk legyen, ne csak dekorációként jelenjenek meg:

- piros: sebzés, veszély, alacsony HP
- kék: mana és mágikus erőforrás
- zöld: sikeres védekezés, gyógyítás, buff
- arany: aktív fókusz, ritkaság, fontos választás
- lila: átok, void, nekromancia

### Panel- és blokkajánlás

A fő képernyők legfeljebb három jól elkülönülő blokkot használjanak:

```text
[ BAL ]      karakter / kaszt / vezérlés
[ KÖZÉP ]    attribútumok / pálya / aktív tartalom
[ JOBB ]     derived statok / eseménynapló / állapotok
```

Szabályok:

- A blokkok között legalább 48 pixel vizuális tér maradjon.
- Egy panelen belül a címke és az érték fix oszloppozíciót használjon.
- Hosszú szöveg ne fusson át a következő blokkba.
- A fontos állapotértékek mindig azonos helyen jelenjenek meg.
- A navigációs segítség a képernyő alján egy rövid sor legyen.
- A TUI-keretek lehetnek szögletesek vagy legfeljebb enyhén lekerekítettek.

### Interakciós jelzések

- Aktív sor: arany szöveg és sötétebb panelháttér.
- Kiválasztott érték: arany keret vagy kiemelés.
- Hiba: piros, de ne villogjon folyamatosan.
- Sikeres parry/dodge/barrier: rövid zöld felirat a játéktér fölött.
- Cooldown: numerikus érték és egyszerű sáv együtt.
- Lövedékveszély: jól látható szín és kontrasztos kontúr.

## 6. Asset-ellenőrző lista

Minden új karakter vagy boss előtt ellenőrizni kell:

- [ ] Minden frame pontosan `48×48 px`.
- [ ] Nincs nem kívánt háttérszín.
- [ ] A lábpozíció frame-ről frame-re stabil.
- [ ] A fegyver vagy varázshatás nem vágódik le.
- [ ] A spritesheet frame-sorrendje dokumentált.
- [ ] A fájlnevek kisbetűsek.
- [ ] A hiányzó asset fallbackkel is fut a játék.
- [ ] Windows és Linux alatt azonos útvonalról töltődik be.
- [ ] A játék headless smoke tesztje sikeres.

## 7. Fejlesztési sorrend

1. Fighter: `idle`, `walk`, `attack`, `hit`
2. Malakar: `idle`, `cast`, `hit`, `death`
3. Lövedék: nekrotikus bolt 4–6 frame
4. Fighter: `block`, `dodge`, `death`
5. Rogue, Wizard, Paladin alapanimációi
6. További bossok és kaszt-specifikus effektek

## 8. Grafikai eszközök és asset-pipeline

A grafikai munkához két külön eszköz használható, eltérő felelősségi körrel:

- **Aseprite:** karakterek, bossok, fegyverek, varázslatok, lövedékek és részecske-effektek frame-alapú pixelanimációja.
- **Tiled:** dungeonök, szobák, tilemapek, collision rétegek, objektumok és pályaelemek elhelyezése.
- **pygame-ce:** az exportált PNG-k és Tiled pályák betöltése, rétegezése, időzített animálása és megjelenítése.

### Asset-rétegek

A játék renderelési sorrendje legyen:

1. háttér és padló tile-ok
2. falak, dekorációk és animált környezeti elemek
3. karakterek, ellenfelek és bossok
4. varázslat-, lövedék- és részecske-effektek
5. HUD és TUI-elemek

Az animált fáklya, víz, köd vagy más környezeti effekt elkészülhet Aseprite-ben spritesheetként, majd pygame-ce-ben ugyanúgy frame-alapú animációként fusson, mint a karakterek. Tiled a pálya szerkezetét, a tile-rétegeket és az objektumok pozícióját tárolja; az animáció lejátszását a játék kezeli.

### Javasolt könyvtárstruktúra

```text
assets/
  characters/
    fighter/
    rogue/
    wizard/
    cleric/
  bosses/
  dungeons/
    crypt/
      crypt.tmx
      ground.tsx
      walls.tsx
      objects.tsx
  backgrounds/
    torch.png
    water.png
    fog.png
```

Az Aseprite-forrásfájlokat és a Tiled szerkeszthető fájljait is érdemes a projektben megőrizni. A játék futásához exportált PNG-ket és a szükséges Tiled pályafájlokat használjuk. Az export legyen determinisztikus, hogy a Windows és Linux build ugyanazokat az asseteket kapja.
