"""Character builder state — pick class, allocate levels, name your hero."""

import os
import pygame
from typing import Optional, Dict, Any, List, Tuple

from src.core.state_machine import State, StateMachine
from src.core.data_loader import DataLoader
from src.core.hero_save_manager import HeroSaveManager
from src.core.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT,
    COLOR_BG_DARK, COLOR_BG_PANEL, COLOR_PANEL_BORDER,
    COLOR_TEXT_LIGHT, COLOR_TEXT_MUTED,
    COLOR_ACCENT_GOLD, COLOR_ACCENT_RED, COLOR_ACCENT_GREEN,
    COLOR_ACCENT_BLUE, COLOR_ACCENT_PURPLE, GameStateId,
)
from src.entities.character import Character
from src.entities.attributes import Attribute
from src.entities.classes import CLASSES


# Classes available in this prototype
AVAILABLE_CLASSES = ["fighter", "rogue", "wizard", "paladin"]

# Total multiclass levels the player can distribute
TOTAL_LEVELS = 6

# Attribute editing: (attr_name, label, min, max)
ATTR_FIELDS = [
    ("STR", "Strength   (STR)",  8, 15),
    ("DEX", "Dexterity  (DEX)",  8, 15),
    ("CON", "Constitution (CON)", 8, 15),
    ("INT", "Intelligence (INT)", 8, 15),
    ("WIS", "Wisdom     (WIS)",  8, 15),
    ("CHA", "Charisma   (CHA)",  8, 15),
]

# D&D 5e Point Buy cost table (score -> points spent)
POINT_BUY_COST: dict[int, int] = {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}
POINT_BUY_BUDGET = 27
POINT_BUY_DEFAULT = 8    # all stats start at 8


def _pb_cost(score: int) -> int:
    """Points spent to reach this score (D&D 5e Point Buy table)."""
    return POINT_BUY_COST.get(max(8, min(15, score)), 9)


def _pb_spent(attr_values: dict[str, int]) -> int:
    return sum(_pb_cost(v) for v in attr_values.values())

# D&D 5e: which stat matters most per class
CLASS_PRIMARY_STAT: dict[str, str] = {
    "fighter":   "STR",
    "paladin":   "STR",
    "barbarian": "STR",
    "rogue":     "DEX",
    "ranger":    "DEX",
    "wizard":    "INT",
    "cleric":    "WIS",
    "bard":      "CHA",
}


class CharacterBuilderState(State):
    """
    Minimal character builder:
      - Choose up to 2 classes and split 6 levels between them
      - Enter a name
      - Confirm -> launch DungeonRun

    TODO: add attribute point allocation
    TODO: add ability preview panel
    TODO: add more classes once content is ready
    """

    def __init__(self, state_machine: StateMachine):
        super().__init__(state_machine)
        self.font_title: Optional[pygame.font.Font] = None
        self.font_normal: Optional[pygame.font.Font] = None
        self.font_small: Optional[pygame.font.Font] = None

        # Builder state
        self.class_levels: Dict[str, int] = {}      # class_id -> allocated levels
        self.selected_class_idx: int = 0             # cursor in the class list
        self.char_name: str = "Hero"
        self.name_editing: bool = False
        self.error_msg: str = ""
        self.status_msg: str = ""

        # Attribute values (raw scores, overridden by player)
        self.attr_values: dict[str, int] = {k: 10 for k, *_ in ATTR_FIELDS}

        # Active tab: "classes" or "attributes"
        self.active_tab: str = "classes"
        self.attr_cursor: int = 0   # selected attribute row

        # Save/load panel
        self.show_load_panel: bool = False
        self.save_list: List[str] = []
        self.save_cursor: int = 0

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        self.class_levels = {}
        self.selected_class_idx = 0
        self.char_name = "Hero"
        self.name_editing = False
        self.error_msg = ""
        self.status_msg = ""
        self.show_load_panel = False
        self.save_list = []
        self.save_cursor = 0
        self.active_tab = "classes"
        self.attr_cursor = 0
        # Load defaults from JSON
        try:
            defaults = DataLoader.hero_defaults()["attributes"]
            raw = {k: defaults.get(k, POINT_BUY_DEFAULT) for k, *_ in ATTR_FIELDS}
            # Clamp to Point Buy range and reset if over budget
            clamped = {k: max(8, min(15, v)) for k, v in raw.items()}
            if _pb_spent(clamped) <= POINT_BUY_BUDGET:
                self.attr_values = clamped
            else:
                self.attr_values = {k: POINT_BUY_DEFAULT for k, *_ in ATTR_FIELDS}
        except Exception:
            self.attr_values = {k: POINT_BUY_DEFAULT for k, *_ in ATTR_FIELDS}
        self._init_fonts()

    def _init_fonts(self) -> None:
        if self.font_title is None and pygame.font.get_init():
            self.font_title = pygame.font.SysFont("consolas,monospace", 36, bold=True)
            self.font_normal = pygame.font.SysFont("consolas,monospace", 24)
            self.font_small = pygame.font.SysFont("consolas,monospace", 18)

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def levels_used(self) -> int:
        return sum(self.class_levels.values())

    @property
    def levels_remaining(self) -> int:
        return TOTAL_LEVELS - self.levels_used

    @property
    def active_classes(self) -> List[Tuple[str, int]]:
        return [(cid, lvl) for cid, lvl in self.class_levels.items() if lvl > 0]

    # ------------------------------------------------------------------
    # Events
    # ------------------------------------------------------------------

    def handle_event(self, event: pygame.event.Event) -> None:
        if self.name_editing:
            self._handle_name_input(event)
            return

        if self.show_load_panel:
            self._handle_load_panel(event)
            return

        if event.type == pygame.KEYDOWN:
            key = event.key
            if key == pygame.K_ESCAPE:
                self.state_machine.change_state(GameStateId.MAIN_MENU)
            elif key == pygame.K_TAB:
                self.active_tab = "attributes" if self.active_tab == "classes" else "classes"
                self.error_msg = ""
            elif self.active_tab == "classes":
                if key in (pygame.K_UP, pygame.K_w):
                    self.selected_class_idx = (self.selected_class_idx - 1) % len(AVAILABLE_CLASSES)
                elif key in (pygame.K_DOWN, pygame.K_s):
                    self.selected_class_idx = (self.selected_class_idx + 1) % len(AVAILABLE_CLASSES)
                elif key in (pygame.K_RIGHT, pygame.K_d):
                    self._add_level()
                elif key in (pygame.K_LEFT, pygame.K_a):
                    self._remove_level()
                elif key == pygame.K_n:
                    self.name_editing = True
                elif key == pygame.K_F5:
                    self._save_hero()
                elif key == pygame.K_F9:
                    self._open_load_panel()
                elif key == pygame.K_RETURN:
                    self._confirm()
            elif self.active_tab == "attributes":
                if key in (pygame.K_UP, pygame.K_w):
                    self.attr_cursor = (self.attr_cursor - 1) % len(ATTR_FIELDS)
                elif key in (pygame.K_DOWN, pygame.K_s):
                    self.attr_cursor = (self.attr_cursor + 1) % len(ATTR_FIELDS)
                elif key in (pygame.K_RIGHT, pygame.K_d, pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
                    self._nudge_attr(+1)
                elif key in (pygame.K_LEFT, pygame.K_a, pygame.K_MINUS, pygame.K_KP_MINUS):
                    self._nudge_attr(-1)
                elif key == pygame.K_n:
                    self.name_editing = True
                elif key == pygame.K_F5:
                    self._save_hero()
                elif key == pygame.K_F9:
                    self._open_load_panel()
                elif key == pygame.K_RETURN:
                    self._confirm()

    def _handle_name_input(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_RETURN:
                self.name_editing = False
            elif event.key == pygame.K_ESCAPE:
                self.name_editing = False
            elif event.key == pygame.K_BACKSPACE:
                self.char_name = self.char_name[:-1]
            elif event.unicode and len(self.char_name) < 20:
                self.char_name += event.unicode

    def _add_level(self) -> None:
        if self.levels_remaining <= 0:
            self.error_msg = "Max szintek elosztva! Vedd el mástól."
            return
        cid = AVAILABLE_CLASSES[self.selected_class_idx]
        self.class_levels[cid] = self.class_levels.get(cid, 0) + 1
        self.error_msg = ""

    def _remove_level(self) -> None:
        cid = AVAILABLE_CLASSES[self.selected_class_idx]
        if self.class_levels.get(cid, 0) > 0:
            self.class_levels[cid] -= 1
            if self.class_levels[cid] == 0:
                del self.class_levels[cid]
            self.error_msg = ""

    def _nudge_attr(self, direction: int) -> None:
        attr_name, _, amin, amax = ATTR_FIELDS[self.attr_cursor]
        current = self.attr_values.get(attr_name, POINT_BUY_DEFAULT)
        new_val = max(amin, min(amax, current + direction))
        if new_val == current:
            return
        # Check point budget before increasing
        if direction > 0:
            cost_now  = _pb_cost(current)
            cost_next = _pb_cost(new_val)
            extra = cost_next - cost_now
            if _pb_spent(self.attr_values) + extra > POINT_BUY_BUDGET:
                self.error_msg = (
                    f"Nincs elég pont! "
                    f"({POINT_BUY_BUDGET - _pb_spent(self.attr_values)} maradt, "
                    f"+{extra} kellene)"
                )
                return
        self.attr_values[attr_name] = new_val
        self.error_msg = ""

    def _save_hero(self) -> None:
        if self.levels_used == 0:
            self.error_msg = "Nincs mit menteni — adj hozzá osztályt!"
            return
        # Build a temporary character to save
        char = self._build_character()
        path = HeroSaveManager.save(char)
        self.status_msg = f"Mentve: {os.path.basename(path)}"
        self.error_msg = ""

    def _open_load_panel(self) -> None:
        self.save_list = HeroSaveManager.list_saves()
        if not self.save_list:
            self.error_msg = "Nincs mentett hős."
            return
        self.save_cursor = 0
        self.show_load_panel = True
        self.error_msg = ""

    def _handle_load_panel(self, event: pygame.event.Event) -> None:
        if event.type != pygame.KEYDOWN:
            return
        if event.key == pygame.K_ESCAPE:
            self.show_load_panel = False
        elif event.key in (pygame.K_UP, pygame.K_w):
            self.save_cursor = max(0, self.save_cursor - 1)
        elif event.key in (pygame.K_DOWN, pygame.K_s):
            self.save_cursor = min(len(self.save_list) - 1, self.save_cursor + 1)
        elif event.key == pygame.K_RETURN:
            name = self.save_list[self.save_cursor]
            try:
                char = HeroSaveManager.load(name)
                self.char_name = char.name
                self.class_levels = dict(char.class_levels)
                # Restore attribute values from loaded character
                for attr_name, *_ in ATTR_FIELDS:
                    self.attr_values[attr_name] = getattr(char.attributes, attr_name, 10)
                self.status_msg = f"Betoltve: {char.name}"
                self.show_load_panel = False
            except Exception as exc:
                self.error_msg = f"Betöltési hiba: {exc}"
                self.show_load_panel = False

    def _build_character(self) -> "Character":
        """Assemble a Character from current builder state (no state transition)."""
        char = Character(self.char_name.strip() or "Hero")
        for cid, lvl in self.class_levels.items():
            char.add_class(cid, lvl)
        for attr_name, *_ in ATTR_FIELDS:
            setattr(char.attributes, attr_name, self.attr_values.get(attr_name, 10))
        char.build()
        return char

    def _confirm(self) -> None:
        if self.levels_used == 0:
            self.error_msg = "Oszd el a szinteket legalabb egy osztályba!"
            return
        if not self.char_name.strip():
            self.error_msg = "Add meg a hős nevét (N gomb)!"
            return

        char = self._build_character()
        self.state_machine.change_state(GameStateId.DUNGEON_RUN, {"character": char})

    # ------------------------------------------------------------------
    # Update / Render
    # ------------------------------------------------------------------

    def update(self, dt: float) -> None:
        pass

    def render(self, surface: pygame.Surface) -> None:
        if not self.font_title:
            self._init_fonts()
        surface.fill(COLOR_BG_DARK)

        self._draw_header(surface)
        self._draw_class_list(surface)
        self._draw_attr_editor(surface)
        self._draw_derived_stats(surface)
        self._draw_name_row(surface)
        self._draw_controls(surface)
        if self.status_msg:
            s = self.font_small.render(self.status_msg, True, COLOR_ACCENT_GREEN)
            surface.blit(s, (SCREEN_WIDTH // 2 - s.get_width() // 2, SCREEN_HEIGHT - 76))
        if self.error_msg:
            self._draw_error(surface)
        if self.show_load_panel:
            self._draw_load_panel(surface)

    # ------------------------------------------------------------------
    # Layout constants
    # ------------------------------------------------------------------
    # Screen: 1280 x 720
    # Col A (classes):     x=30..390
    # Col B (attributes):  x=420..810
    # Col C (derived):     x=840..1250
    # Content rows: y=90..590  (500px)
    # Bottom bar:   y=600..720
    _COL_A = 30
    _COL_B = 420
    _COL_C = 840
    _COL_TOP = 90

    def _draw_header(self, surface: pygame.Surface) -> None:
        title = self.font_title.render("KARAKTER EPITES", True, COLOR_ACCENT_GOLD)
        surface.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 22))

        # Section headers with focus highlight
        sections = [
            (self._COL_A, "OSZTALYOK  [ ← → ]" , "classes"),
            (self._COL_B, "ATTRIBU\u0301TUMOK  [ + - ]" , "attributes"),
            (self._COL_C, "DERIVED STATS",         None),
        ]
        for sx, label, tid in sections:
            active = (tid == self.active_tab)
            color = COLOR_ACCENT_GOLD if active else COLOR_TEXT_MUTED
            surf = self.font_small.render(label, True, color)
            surface.blit(surf, (sx, 68))
            if active:
                pygame.draw.line(surface, COLOR_ACCENT_GOLD,
                                 (sx, 84), (sx + surf.get_width(), 84), 1)

        tab_hint = self.font_small.render("TAB — fókusz váltás", True, COLOR_TEXT_MUTED)
        surface.blit(tab_hint, (SCREEN_WIDTH // 2 - tab_hint.get_width() // 2, 68))

    def _draw_class_list(self, surface: pygame.Surface) -> None:
        x = self._COL_A
        y = self._COL_TOP
        ROW_H = 36

        for i, cid in enumerate(AVAILABLE_CLASSES):
            cls = CLASSES[cid]
            lvl = self.class_levels.get(cid, 0)
            selected = (i == self.selected_class_idx) and (self.active_tab == "classes")
            color = COLOR_ACCENT_GOLD if selected else COLOR_TEXT_LIGHT
            prefix = "> " if selected else "  "

            if selected:
                row_rect = pygame.Rect(x - 6, y - 2, 360, ROW_H - 2)
                pygame.draw.rect(surface, COLOR_BG_PANEL, row_rect, border_radius=5)
                pygame.draw.rect(surface, COLOR_PANEL_BORDER, row_rect, width=1, border_radius=5)

            bar = "[" + "#" * lvl + "." * (TOTAL_LEVELS - lvl) + "]"
            line = f"{prefix}{cls.name:<10} {bar}  Lv {lvl}"
            surf = self.font_normal.render(line, True, color)
            surface.blit(surf, (x, y + 4))
            y += ROW_H

        y += 8
        remaining_surf = self.font_normal.render(
            f"Szabad: {self.levels_remaining} / {TOTAL_LEVELS}",
            True, COLOR_ACCENT_GREEN if self.levels_remaining > 0 else COLOR_ACCENT_RED
        )
        surface.blit(remaining_surf, (x, y))

    def _draw_attr_editor(self, surface: pygame.Surface) -> None:
        x = self._COL_B
        y = self._COL_TOP
        ROW_H = 36
        # Fixed pixel columns inside Col B (420..820 = 400px wide)
        # Consolas 18px ~= 10.8px/char, 24px ~= 14.4px/char
        # Longest label: "Constitution" = 12 chars @ 18px = ~130px
        LBL_X   = x          # label start
        SCORE_X = x + 200    # 2-digit score (24px font, ~29px wide)
        MOD_X   = x + 240    # modifier "(+2)" ~46px
        COST_X  = x + 295    # "9p" badge ~28px
        BAR_X   = x + 330    # bar, 70px wide — stays within col
        BAR_W   = 70

        spent = _pb_spent(self.attr_values)
        remaining = POINT_BUY_BUDGET - spent
        budget_color = (
            COLOR_ACCENT_GREEN if remaining > 0 else
            COLOR_ACCENT_GOLD  if remaining == 0 else
            COLOR_ACCENT_RED
        )
        label_text = f"{remaining} pt szabad  ({spent}/{POINT_BUY_BUDGET})"
        surface.blit(self.font_small.render(label_text, True, budget_color), (x, y))
        y += 26

        primary_stats: set[str] = set()
        for cid in self.class_levels:
            ps = CLASS_PRIMARY_STAT.get(cid)
            if ps:
                primary_stats.add(ps)

        # Short labels to fit in ~190px at font_small (18px)
        SHORT_LABELS = {
            "STR": "Strength   STR",
            "DEX": "Dexterity  DEX",
            "CON": "Constitut. CON",
            "INT": "Intellect. INT",
            "WIS": "Wisdom     WIS",
            "CHA": "Charisma   CHA",
        }

        for i, (attr_name, _, amin, amax) in enumerate(ATTR_FIELDS):
            selected = (i == self.attr_cursor) and (self.active_tab == "attributes")
            val = self.attr_values.get(attr_name, POINT_BUY_DEFAULT)
            mod = (val - 10) // 2
            is_primary = attr_name in primary_stats
            cost = _pb_cost(val)
            next_cost = _pb_cost(val + 1) - cost if val < amax else None

            if selected:
                row_rect = pygame.Rect(LBL_X - 6, y - 2, 400, ROW_H - 2)
                pygame.draw.rect(surface, COLOR_BG_PANEL, row_rect, border_radius=5)
                pygame.draw.rect(surface, COLOR_PANEL_BORDER, row_rect, width=1, border_radius=5)

            lc = COLOR_ACCENT_GOLD if is_primary else (COLOR_TEXT_LIGHT if selected else COLOR_TEXT_MUTED)
            surface.blit(self.font_small.render(SHORT_LABELS[attr_name], True, lc), (LBL_X, y + 6))

            mod_str = f"+{mod}" if mod >= 0 else str(mod)
            surface.blit(self.font_normal.render(str(val), True, COLOR_TEXT_LIGHT), (SCORE_X, y + 3))
            surface.blit(self.font_small.render(f"({mod_str})", True, COLOR_TEXT_MUTED), (MOD_X, y + 7))

            cost_color = COLOR_ACCENT_RED if cost >= 7 else (COLOR_ACCENT_GOLD if cost >= 4 else COLOR_TEXT_MUTED)
            surface.blit(self.font_small.render(f"{cost}p", True, cost_color), (COST_X, y + 7))

            ratio = (val - amin) / max(amax - amin, 1)
            bar_rect = pygame.Rect(BAR_X, y + 10, BAR_W, 12)
            pygame.draw.rect(surface, COLOR_BG_DARK, bar_rect, border_radius=3)
            fill_w = int(BAR_W * ratio)
            if fill_w > 0:
                bc = (COLOR_ACCENT_RED if val >= 14 else
                      COLOR_ACCENT_GOLD if val >= 12 else
                      COLOR_ACCENT_GREEN if is_primary else COLOR_ACCENT_BLUE)
                pygame.draw.rect(surface, bc, pygame.Rect(BAR_X, y + 10, fill_w, 12), border_radius=3)
            pygame.draw.rect(surface, COLOR_PANEL_BORDER, bar_rect, width=1, border_radius=3)

            if selected and next_cost is not None:
                surface.blit(self.font_small.render(f"+{next_cost}p next", True, COLOR_TEXT_MUTED),
                             (BAR_X + BAR_W + 6, y + 7))

            y += ROW_H

        y += 4
        ref = "8=0  9=1  10=2  11=3  12=4  13=5  14=7  15=9pt"
        surface.blit(self.font_small.render(ref, True, COLOR_TEXT_MUTED), (x, y))

    def _draw_derived_stats(self, surface: pygame.Surface) -> None:
        x = self._COL_C
        y = self._COL_TOP

        if not self.active_classes:
            surface.blit(
                self.font_small.render("(válassz osztályt)", True, COLOR_TEXT_MUTED), (x, y)
            )
            return

        char = Character("preview")
        for cid, lvl in self.active_classes:
            char.add_class(cid, lvl)
        for attr_name, *_ in ATTR_FIELDS:
            setattr(char.attributes, attr_name, self.attr_values.get(attr_name, 10))
        char.build()

        rows = [
            ("Osztályok",  ", ".join(f"{CLASSES[c].name} {l}" for c, l in self.active_classes), COLOR_TEXT_LIGHT),
            ("Prof. Bonus", f"+{char.proficiency_bonus}",           COLOR_TEXT_MUTED),
            (None, None, None),
            ("Max HP",      str(char.stats.max_hp),                  COLOR_ACCENT_RED),
            ("Max Mana",    str(char.stats.max_mana),                COLOR_ACCENT_BLUE),
            ("Armor Class", str(char.stats.armor_class),             COLOR_ACCENT_GREEN),
            (None, None, None),
            ("Melee Atk",   f"+{char.stats.melee_attack_bonus}",     COLOR_ACCENT_GOLD),
            ("Melee Dmg",   f"+{char.stats.melee_damage_bonus}",     COLOR_ACCENT_GOLD),
            ("Spell Atk",   f"+{char.stats.spell_attack_bonus}",     COLOR_ACCENT_PURPLE),
            ("Initiative",  f"+{char.stats.initiative}",             COLOR_TEXT_LIGHT),
            ("Speed",       f"{int(char.stats.move_speed)} px/s",    COLOR_TEXT_MUTED),
        ]

        for label, val, color in rows:
            if label is None:
                y += 8
                pygame.draw.line(surface, COLOR_PANEL_BORDER, (x, y), (x + 370, y), 1)
                y += 8
                continue
            lbl_surf = self.font_small.render(f"{label:<13}", True, COLOR_TEXT_MUTED)
            val_surf = self.font_normal.render(str(val), True, color)
            surface.blit(lbl_surf, (x, y + 3))
            surface.blit(val_surf, (x + 160, y))
            y += 28

    def _draw_name_row(self, surface: pygame.Surface) -> None:
        y = SCREEN_HEIGHT - 98
        cursor = "|" if self.name_editing else ""
        color = COLOR_ACCENT_GOLD if self.name_editing else COLOR_TEXT_LIGHT
        label = self.font_normal.render(
            f"Hős neve:  {self.char_name}{cursor}  {'(gépelés...)' if self.name_editing else '(N = szerkeszt)'}" ,
            True, color
        )
        surface.blit(label, (self._COL_A, y))

    def _draw_load_panel(self, surface: pygame.Surface) -> None:
        pw, ph = 420, min(60 + len(self.save_list) * 30, 380)
        px = SCREEN_WIDTH // 2 - pw // 2
        py = SCREEN_HEIGHT // 2 - ph // 2
        pygame.draw.rect(surface, COLOR_BG_PANEL, (px, py, pw, ph))
        pygame.draw.rect(surface, COLOR_PANEL_BORDER, (px, py, pw, ph), 2)
        header = self.font_normal.render("Mentett hősök  (ENTER = betölt, ESC = vissza)", True, COLOR_ACCENT_GOLD)
        surface.blit(header, (px + 14, py + 12))
        for i, name in enumerate(self.save_list):
            color = COLOR_ACCENT_GOLD if i == self.save_cursor else COLOR_TEXT_LIGHT
            prefix = "> " if i == self.save_cursor else "  "
            s = self.font_normal.render(f"{prefix}{name}", True, color)
            surface.blit(s, (px + 20, py + 48 + i * 30))

    def _draw_controls(self, surface: pygame.Surface) -> None:
        if self.active_tab == "classes":
            line = "FEL/LE osztály  BAL/JOBB szint   TAB → Attr   N név   F5 ment   F9 betölt   ENTER indul   ESC vissza"
        else:
            line = "FEL/LE attr  BAL/JOBB/+/- érték   TAB → Osztály   N név   F5 ment   F9 betölt   ENTER indul   ESC vissza"
        surf = self.font_small.render(line, True, COLOR_TEXT_MUTED)
        surface.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, SCREEN_HEIGHT - 68))

    def _draw_error(self, surface: pygame.Surface) -> None:
        surf = self.font_small.render(self.error_msg, True, COLOR_ACCENT_RED)
        surface.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, SCREEN_HEIGHT - 56))
