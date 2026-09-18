"""
Dungeon run state — prototype version with one room and one boss.

Layout:
  - Player spawns at bottom-center
  - Boss spawns at top-center
  - Simple rectangular arena, no map tiles yet

Controls:
  WASD / arrow keys  — move
  SPACE              — basic attack (melee or ranged depending on primary class)
  ESC                — abandon run -> main menu

TODO: add tile-based room rendering
TODO: add trap zones (attrition / curse system)
TODO: add multiple rooms and mini-bosses
TODO: add ability bar (1-6 keys)
TODO: add loot drop on boss kill
"""

import math
import time
import pygame
from typing import Optional, Dict, Any

from src.core.state_machine import State, StateMachine
from src.core.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT,
    COLOR_BG_DARK, COLOR_ACCENT_GOLD, COLOR_ACCENT_RED,
    COLOR_ACCENT_BLUE, COLOR_ACCENT_GREEN,
    COLOR_TEXT_LIGHT, COLOR_TEXT_MUTED, COLOR_PANEL_BORDER,
    GameStateId,
)
from src.core.data_loader import DataLoader
from src.combat.combat_resolver import resolve_player_attack, resolve_boss_attack, AttackResult
from src.entities.character import Character


# ---------------------------------------------------------------------------
# Simple Boss definition (prototype — no sprite, just a coloured rectangle)
# ---------------------------------------------------------------------------

class Boss:
    """Prototype boss entity."""

    def __init__(self, name: str, max_hp: int, speed: float, damage: int, color, icon: str = "\U0001F480"):
        self.name = name
        self.icon = icon
        self.max_hp = max_hp
        self.current_hp = max_hp
        self.speed = speed           # pixels / second
        self.damage = damage         # damage per hit
        self.color = color
        self.x: float = SCREEN_WIDTH / 2
        self.y: float = 130.0
        self.radius: int = 32
        self.attack_cooldown: float = 0.0
        self.attack_rate: float = 1.5    # seconds between attacks
        self.alive: bool = True

    @property
    def hp_ratio(self) -> float:
        return self.current_hp / max(self.max_hp, 1)

    def take_damage(self, amount: int) -> None:
        self.current_hp = max(0, self.current_hp - amount)
        if self.current_hp == 0:
            self.alive = False

    def update(self, dt: float, px: float, py: float) -> Optional[int]:
        """
        Move toward player and attack if close enough.
        Returns damage dealt this frame, or None.
        """
        if not self.alive:
            return None

        # Move toward player
        dx, dy = px - self.x, py - self.y
        dist = math.hypot(dx, dy)
        if dist > self.radius + 28:
            speed = self.speed * dt
            self.x += dx / dist * speed
            self.y += dy / dist * speed

        # Attack
        self.attack_cooldown -= dt
        if dist < self.radius + 28 + 10 and self.attack_cooldown <= 0:
            self.attack_cooldown = self.attack_rate
            return self.damage
        return None


# ---------------------------------------------------------------------------
# Dungeon Run State
# ---------------------------------------------------------------------------

ARENA_LEFT = 80
ARENA_RIGHT = SCREEN_WIDTH - 80
ARENA_TOP = 80
ARENA_BOTTOM = SCREEN_HEIGHT - 120

PLAYER_RADIUS = 18
PLAYER_COLOR = (80, 180, 255)

# Boss roster is loaded at runtime from data/bosses/*.json via DataLoader
# To add a boss: create data/bosses/boss_00N_name.json — no code change needed.
BOSS_ORDER = [
    "boss_001_malakar",
    # "boss_002_ignis",     # TODO
    # "boss_003_serytha",   # TODO
]

# Weapon icon per primary class
CLASS_WEAPON_ICON: dict[str, str] = {
    "fighter":  "\U00002694",   # crossed swords
    "paladin":  "\U0001F531",   # trident / holy symbol
    "rogue":    "\U0001F462",   # boot (thief)
    "wizard":   "\U0001FA84",   # magic wand
    "cleric":   "\U0001F6F0",   # staff / satellite (placeholder)
    "ranger":   "\U0001F3F9",   # bow
    "barbarian":"\U0001FA93",   # axe
    "bard":     "\U0001F3B5",   # music note
}
DEFAULT_WEAPON_ICON = "\U00002694"  # crossed swords fallback


class DungeonRunState(State):
    """Top-level state for a single dungeon run (prototype: one room, one boss)."""

    def __init__(self, state_machine: StateMachine):
        super().__init__(state_machine)
        self.character: Optional[Character] = None
        self.boss: Optional[Boss] = None

        # Player runtime position and HP
        self.px: float = SCREEN_WIDTH / 2
        self.py: float = ARENA_BOTTOM - 40
        self.current_hp: int = 0
        self.current_mana: int = 0

        # Player attack
        self.attack_cooldown: float = 0.0
        self.attack_range: int = 200           # prototype: ranged basic attack
        self.attack_damage: int = 0

        # Run timer
        self.run_start: float = 0.0
        self.run_time: float = 0.0
        self.state: str = "running"            # "running" | "victory" | "dead"
        self.result_timer: float = 3.0         # seconds before returning to menu

        # Fonts
        self.font_hud: Optional[pygame.font.Font] = None
        self.font_big: Optional[pygame.font.Font] = None
        self.font_small: Optional[pygame.font.Font] = None
        self.font_icon_large: Optional[pygame.font.Font] = None
        self.font_icon_small: Optional[pygame.font.Font] = None
        self._weapon_icon: str = DEFAULT_WEAPON_ICON

        # Attack flash effect
        self.hit_flash: float = 0.0

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        enter_data = enter_data or {}
        self.character = enter_data.get("character")

        if self.character is None:
            # Fallback: create a default character for testing
            from src.entities.character import Character
            self.character = Character("TestHero")
            self.character.add_class("fighter", 3)
            self.character.add_class("rogue", 2)
            self.character.build()

        self.current_hp = self.character.stats.max_hp
        self.current_mana = self.character.stats.max_mana
        # attack_damage is now derived per-roll in combat_resolver; keep as fallback min
        self.attack_damage = 1  # unused directly — resolver handles it

        # Spawn player
        self.px = SCREEN_WIDTH / 2
        self.py = ARENA_BOTTOM - 40

        # Spawn boss from JSON
        boss_data = DataLoader.boss(BOSS_ORDER[0])
        self.boss = Boss.from_data(boss_data)

        self.run_start = time.monotonic()
        self.run_time = 0.0
        self.state = "running"
        self.result_timer = 3.0
        self.attack_cooldown = 0.0
        self.hit_flash = 0.0
        self._last_player_attack: Optional[AttackResult] = None
        self._last_boss_attack: Optional[AttackResult] = None
        self._weapon_icon: str = self._resolve_weapon_icon()
        self._init_fonts()

    def _resolve_weapon_icon(self) -> str:
        """Pick weapon icon based on the highest-level class."""
        if not self.character or not self.character.class_levels:
            return DEFAULT_WEAPON_ICON
        primary = max(self.character.class_levels, key=lambda c: self.character.class_levels[c])
        return CLASS_WEAPON_ICON.get(primary, DEFAULT_WEAPON_ICON)

    def _init_fonts(self) -> None:
        if self.font_hud is None and pygame.font.get_init():
            self.font_hud = pygame.font.SysFont("consolas,monospace", 22, bold=True)
            self.font_big = pygame.font.SysFont("consolas,monospace", 48, bold=True)
            self.font_small = pygame.font.SysFont("consolas,monospace", 18)
            # Emoji font for boss/player icons
            self.font_icon_large = pygame.font.SysFont("segoeuiemoji,notocoloremoji,unifont", 52)
            self.font_icon_small = pygame.font.SysFont("segoeuiemoji,notocoloremoji,unifont", 26)

    # ------------------------------------------------------------------
    # Events
    # ------------------------------------------------------------------

    def handle_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.state_machine.change_state(GameStateId.MAIN_MENU)
            elif event.key == pygame.K_SPACE and self.state == "running":
                self._try_attack()

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def update(self, dt: float) -> None:
        if self.state != "running":
            self.result_timer -= dt
            if self.result_timer <= 0:
                self.state_machine.change_state(
                    GameStateId.SCOREBOARD,
                    {
                        "character": self.character,
                        "run_time": self.run_time,
                        "victory": self.state == "victory",
                    }
                )
            return

        self.run_time = time.monotonic() - self.run_start
        self.attack_cooldown = max(0.0, self.attack_cooldown - dt)
        self.hit_flash = max(0.0, self.hit_flash - dt)

        self._move_player(dt)

        if self.boss and self.boss.alive:
            signal = self.boss.update(dt, self.px, self.py)
            if signal == "pending":
                result = resolve_boss_attack(
                    self.boss.attack_bonus,
                    self.boss.damage_die,
                    self.boss.damage_count,
                    self.character.stats.armor_class,
                )
                self._last_boss_attack = result
                if result.hit:
                    self.current_hp -= result.damage
                    self.hit_flash = 0.3
                    if self.current_hp <= 0:
                        self.current_hp = 0
                        self.state = "dead"
                        self.result_timer = 3.5

        if self.boss and not self.boss.alive and self.state == "running":
            self.state = "victory"
            self.result_timer = 4.0

    def _move_player(self, dt: float) -> None:
        keys = pygame.key.get_pressed()
        spd = self.character.stats.move_speed * dt
        dx = dy = 0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            dx -= 1
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            dx += 1
        if keys[pygame.K_UP] or keys[pygame.K_w]:
            dy -= 1
        if keys[pygame.K_DOWN] or keys[pygame.K_s]:
            dy += 1

        if dx and dy:
            spd /= math.sqrt(2)

        self.px = max(ARENA_LEFT + PLAYER_RADIUS, min(ARENA_RIGHT - PLAYER_RADIUS, self.px + dx * spd))
        self.py = max(ARENA_TOP + PLAYER_RADIUS, min(ARENA_BOTTOM - PLAYER_RADIUS, self.py + dy * spd))

    def _try_attack(self) -> None:
        if self.attack_cooldown > 0 or not self.boss or not self.boss.alive:
            return
        dist = math.hypot(self.boss.x - self.px, self.boss.y - self.py)
        if dist <= self.attack_range:
            result = resolve_player_attack(self.character, self.boss.armor_class)
            self._last_player_attack = result
            if result.hit:
                self.boss.take_damage(result.damage)
            self.attack_cooldown = 0.6

    # ------------------------------------------------------------------
    # Render
    # ------------------------------------------------------------------

    def render(self, surface: pygame.Surface) -> None:
        if not self.font_hud:
            self._init_fonts()

        # Background
        surface.fill(COLOR_BG_DARK)

        # Arena border
        pygame.draw.rect(surface, COLOR_PANEL_BORDER,
                         (ARENA_LEFT, ARENA_TOP,
                          ARENA_RIGHT - ARENA_LEFT, ARENA_BOTTOM - ARENA_TOP), 2)

        # Boss
        if self.boss and self.boss.alive:
            self._draw_entity_icon(
                surface, self.boss.icon, int(self.boss.x), int(self.boss.y),
                self.boss.radius, self.boss.color, large=True
            )
            self._draw_hp_bar(surface, self.boss.x - 40, self.boss.y - self.boss.radius - 14,
                              80, 8, self.boss.hp_ratio, COLOR_ACCENT_RED)
            name_surf = self.font_small.render(self.boss.name, True, COLOR_TEXT_MUTED)
            surface.blit(name_surf, (int(self.boss.x) - name_surf.get_width() // 2,
                                     int(self.boss.y) - self.boss.radius - 30))

        # Player body
        p_color = (255, 80, 80) if self.hit_flash > 0 else PLAYER_COLOR
        pygame.draw.circle(surface, p_color, (int(self.px), int(self.py)), PLAYER_RADIUS)
        # Weapon icon next to player
        self._draw_weapon_icon(surface, int(self.px), int(self.py))

        # Attack range indicator (faint)
        if self.attack_cooldown <= 0 and self.state == "running":
            pygame.draw.circle(surface, (60, 90, 120),
                               (int(self.px), int(self.py)), self.attack_range, 1)

        self._draw_hud(surface)
        self._draw_overlay(surface)

    def _draw_entity_icon(
        self, surface: pygame.Surface, icon: str,
        cx: int, cy: int, radius: int, glow_color, large: bool = True
    ) -> None:
        """Render a Unicode emoji icon centered at (cx, cy) with a coloured glow circle."""
        # Glow/background circle
        pygame.draw.circle(surface, glow_color, (cx, cy), radius)
        font = self.font_icon_large if large else self.font_icon_small
        if font:
            try:
                icon_surf = font.render(icon, True, (255, 255, 255))
                surface.blit(icon_surf, (cx - icon_surf.get_width() // 2,
                                         cy - icon_surf.get_height() // 2))
            except Exception:
                pass  # font doesn't support this glyph — glow circle is enough

    def _draw_weapon_icon(self, surface: pygame.Surface, px: int, py: int) -> None:
        """Draw the weapon icon to the right of the player token."""
        if not self.font_icon_small:
            return
        try:
            w_surf = self.font_icon_small.render(self._weapon_icon, True, COLOR_ACCENT_GOLD)
            surface.blit(w_surf, (px + PLAYER_RADIUS + 4, py - w_surf.get_height() // 2))
        except Exception:
            pass

    def _draw_hp_bar(self, surface, x, y, w, h, ratio, color) -> None:
        pygame.draw.rect(surface, (50, 50, 50), (x, y, w, h))
        pygame.draw.rect(surface, color, (x, y, int(w * ratio), h))
        pygame.draw.rect(surface, COLOR_PANEL_BORDER, (x, y, w, h), 1)

    def _draw_hud(self, surface: pygame.Surface) -> None:
        # Player HP bar
        hp_ratio = self.current_hp / max(self.character.stats.max_hp, 1)
        self._draw_hp_bar(surface, 20, SCREEN_HEIGHT - 90, 220, 18, hp_ratio, COLOR_ACCENT_RED)
        hp_txt = self.font_hud.render(
            f"HP  {self.current_hp} / {self.character.stats.max_hp}", True, COLOR_TEXT_LIGHT)
        surface.blit(hp_txt, (20, SCREEN_HEIGHT - 114))

        # Mana bar
        mana_ratio = self.current_mana / max(self.character.stats.max_mana, 1)
        self._draw_hp_bar(surface, 20, SCREEN_HEIGHT - 60, 220, 14, mana_ratio, COLOR_ACCENT_BLUE)
        mana_txt = self.font_small.render(
            f"Mana  {self.current_mana} / {self.character.stats.max_mana}", True, COLOR_TEXT_MUTED)
        surface.blit(mana_txt, (20, SCREEN_HEIGHT - 78))

        # Timer
        mins = int(self.run_time) // 60
        secs = int(self.run_time) % 60
        timer_surf = self.font_hud.render(f"{mins:02d}:{secs:02d}", True, COLOR_ACCENT_GOLD)
        surface.blit(timer_surf, (SCREEN_WIDTH // 2 - timer_surf.get_width() // 2, 20))

        # Character info
        build_str = " / ".join(f"{cid.capitalize()} {lvl}" for cid, lvl in self.character.class_levels.items())
        build_surf = self.font_small.render(
            f"{self.character.name}  [{build_str}]", True, COLOR_TEXT_MUTED)
        surface.blit(build_surf, (SCREEN_WIDTH - build_surf.get_width() - 20, 20))

        # Attack cooldown hint
        if self.attack_cooldown > 0:
            cd_surf = self.font_small.render(
                f"Tamadas: {self.attack_cooldown:.1f}s", True, COLOR_TEXT_MUTED)
        else:
            cd_surf = self.font_small.render("SPACE = Tamadas", True, COLOR_ACCENT_GREEN)
        surface.blit(cd_surf, (SCREEN_WIDTH - cd_surf.get_width() - 20, SCREEN_HEIGHT - 50))

    def _draw_overlay(self, surface: pygame.Surface) -> None:
        if self.state == "running":
            return

        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        surface.blit(overlay, (0, 0))

        if self.state == "victory":
            msg = "GYOZELEM!"
            color = COLOR_ACCENT_GOLD
            mins = int(self.run_time) // 60
            secs = int(self.run_time) % 60
            sub = f"Ido: {mins:02d}:{secs:02d}   Pontszam betoltodik..."
        else:
            msg = "HALAL"
            color = COLOR_ACCENT_RED
            sub = "Jobb lesz legkozelebbi alkalommal..."

        big = self.font_big.render(msg, True, color)
        surface.blit(big, (SCREEN_WIDTH // 2 - big.get_width() // 2, SCREEN_HEIGHT // 2 - 50))
        small = self.font_small.render(sub, True, COLOR_TEXT_MUTED)
        surface.blit(small, (SCREEN_WIDTH // 2 - small.get_width() // 2, SCREEN_HEIGHT // 2 + 20))
