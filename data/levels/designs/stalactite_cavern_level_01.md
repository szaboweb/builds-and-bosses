# Stalactite Cavern - Level 01 Design

**Difficulty**: Medium (2/5)  
**Theme**: Cavern / Stalactite Cave  
**Recommended Party Size**: 1-3 heroes

## Story/Context
An ancient cavern hidden beneath the mountains holds a secret: a hidden chamber above, marked with ancient wolf-eye runes. To reach it, adventurers must break through the crystallized stalactite ceiling and navigate the hazardous chasm below.

## Room Overview

### Main Chamber (Lower Level)
- **Layout**: Rectangular room
- **Hazard**: Central chasm with sharp stalactite formation in the middle (visually imposing)
- **Ceiling**: Destructible stalactite layer directly above the chasm
- **Entry/Exit**: Ground level on left and right sides (safe walkways)

### Hidden Chamber (Upper Level)
- **Layout**: Triangular/roof-shaped room
- **Visual Theme**: "Wolf's Eye" design - two triangular windows that resemble a wolf's watchful gaze
- **Access**: Only reachable after destroying ceiling in main chamber
- **Reward/Purpose**: Boss encounter or treasure vault

## Hazards & Mechanics

### 1. Central Chasm
- **Description**: Sharp, peaked stalactite formation protruding upward
- **Damage**: 10-20 HP if fallen into
- **Avoidance**: Stay on safe walkways (left/right paths)
- **Escape**: Ladders or climbing opportunity if fallen

### 2. Destructible Ceiling (Trigger Puzzle)
- **State**: Initially INTACT - appears as hanging stalactites
- **Destruction Methods**:
  - Warrior: Sword/axe attack (3 hits required)
  - Mage: Lightning or fire spell (2 casts)
  - Archer: 5 arrows to destructible weak points
- **Effect After Destruction**:
  - Ceiling crumbles and disappears
  - Opens direct path to upper chamber via climbing/flying
  - Ground tremors (low damage AoE, 5 HP) - short stun effect
- **Cannot Undo**: Once destroyed, it stays destroyed

### 3. Flying/Levitation Requirement
- **Only Fliers Can Enter Upper Chamber**: Requires hover/fly capability
- **Why**: Vertical access only (no stairs/ladders)
- **Alternatives**: Mage levitation spell, Rogue rope grapple, Paladin divine jump

## Enemies

### Lower Level (Main Chamber)
- **Type 1**: Stone Elemental (1-2 spawns)
  - Spawns near chasm edges
  - Attacks: Melee strikes, falling rock projectiles
  - Weakness: Lightning or crushing force
  - ~30 HP each
  
- **Type 2**: Stalactite Bats (3-4 swarms)
  - Fast flying creatures
  - Attacks: Swoops, tail whips
  - Weakness: Fire
  - ~5 HP each, but numerous

### Upper Level (Hidden Chamber)
- **Boss**: Wyvern Guardian or Wolf-Kin Shaman
  - Only encountered if players reach upper chamber
  - High HP (60+), ranged/melee attacks
  - Rewards: Rare loot, XP boost

## Loot & Rewards

### Main Chamber Floor
- Gold coins (50-100)
- Healing potion (1-2)
- Mana gem (1)

### Upper Chamber (Hidden)
- Legendary weapon or armor piece (quality varies by class)
- Rare crafting material (Crystal Fang)
- Boss treasure chest (randomized rare loot)
- XP multiplier (+50% for reaching secret area)

## Quest Gates & Conditions

### Gate 1: Defeat Stone Elemental
- **Requirement**: Kill the stone elemental(s) in main chamber
- **Reward**: Unlock southwest passage (optional shortcut)

### Gate 2: Destroy Ceiling
- **Requirement**: Deal enough damage to destroy stalactite ceiling (damage threshold)
- **Reward**: Access to upper chamber opens
- **Consequence**: Boss awakens if present

### Gate 3: Reach Upper Chamber
- **Requirement**: Flying capability + survived main chamber
- **Reward**: Boss encounter, legendary loot
- **Optional**: Can complete level without entering (shortcut exit available)

## Aesthetic Notes

- **Color Palette**: Greys, pale blues, icy whites for stalactites; warm amber for ground
- **Lighting**: Dimly lit; shafts of light from upper chamber windows
- **Sound**: Echoing drips, wind howls, distant growls
- **Destructible Particle Effects**: Rock dust, crystal shards on ceiling destruction

## Layout Diagram

```
          [UPPER CHAMBER - HIDDEN]
          (Triangle/Wolf-Eye)
                   ▲
                 / | \
                /  |  \  (2 windows as "eyes")
               / ◌ | ◌ \
              /___|___\
              
   [DESTROYED CEILING - Access Point]
       
   ╔═══════════════════════════════╗
   ║  L  |  C  |  C  |  C  |  R   ║
   ║     | ▼▼▼ | ▼▼▼ | ▼▼▼ |     ║
   ║  A  |▼▼▼▼▼|▼▼▼▼▼|▼▼▼▼▼|  B  ║ (Main Chamber)
   ║     |▼▼▼▼▼|▼▼▼▼▼|▼▼▼▼▼|     ║
   ║  E  |▼▼▼▼▼|▼▼▼▼▼|▼▼▼▼▼|  F  ║
   ║     | ▼▼▼ | ▼▼▼ | ▼▼▼ |     ║
   ╚═══════════════════════════════╝
   L=Left (Entry), R=Right
   A,B,E,F = Safe walking platforms
   C = Central chasm with stalactites
```

## Implementation Notes for Engine

- Use 3D layering system for upper/lower chambers
- Implement destructible mesh for stalactite ceiling
- Create flying-check gate at chamber entrance (restrict non-fliers)
- Add damage zone for chasm fall damage
- Trigger music shift when ceiling destroyed (boss warning)
