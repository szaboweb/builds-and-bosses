"""Character builder state — pick class, allocate levels, name your hero."""

import pygame
from typing import Optional, Dict, Any, List, Tuple

from src.core.state_machine import State, StateMachine
from src.core.data_loader import DataLoader
from src.core.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT,
    COLOR_BG_DARK, COLOR_BG_PANEL, COLOR_PANEL_BORDER,
    COLOR_TEXT_LIGHT, COLOR_TEXT_MUTED,
    COLOR_ACCENT_GOLD, COLOR_ACCENT_RED, COLOR_ACCENT_GREEN,
    COLOR_ACCENT_BLUE, GameStateId,
)
from src.entities.character import Character
from src.entities.classes import CLASSES


# Classes available in this prototype
AVAILABLE_CLASSES = ["fighter", "rogue", "wizard", "paladin"]

# Total multiclass levels the player can distribute
TOTAL_LEVELS = 6


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

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        self.class_levels = {}
        self.selected_class_idx = 0
        self.char_name = "Hero"
        self.name_editing = False
        self.error_msg = ""
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

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.state_machine.change_state(GameStateId.MAIN_MENU)
            elif event.key in (pygame.K_UP, pygame.K_w):
                self.selected_class_idx = (self.selected_class_idx - 1) % len(AVAILABLE_CLASSES)
            elif event.key in (pygame.K_DOWN, pygame.K_s):
                self.selected_class_idx = (self.selected_class_idx + 1) % len(AVAILABLE_CLASSES)
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self._add_level()
            elif event.key in (pygame.K_LEFT, pygame.K_a):
                self._remove_level()
            elif event.key == pygame.K_n:
                self.name_editing = True
            elif event.key == pygame.K_RETURN:
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

    def _confirm(self) -> None:
        if self.levels_used == 0:
            self.error_msg = "Oszd el a szinteket legalabb egy osztályba!"
            return
        if not self.char_name.strip():
            self.error_msg = "Add meg a hős nevét (N gomb)!"
            return

        # Build the character
        char = Character(self.char_name.strip())
        for cid, lvl in self.class_levels.items():
            char.add_class(cid, lvl)
        # Load default attributes from data/heroes/default_hero.json
        defaults = DataLoader.hero_defaults()["attributes"]
        char.attributes.STR = defaults["STR"]
        char.attributes.DEX = defaults["DEX"]
        char.attributes.CON = defaults["CON"]
        char.attributes.INT = defaults["INT"]
        char.attributes.WIS = defaults["WIS"]
        char.attributes.CHA = defaults["CHA"]
        char.build()

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

        self._draw_title(surface)
        self._draw_class_list(surface)
        self._draw_build_summary(surface)
        self._draw_name_row(surface)
        self._draw_controls(surface)
        if self.error_msg:
            self._draw_error(surface)

    def _draw_title(self, surface: pygame.Surface) -> None:
        title = self.font_title.render("KARAKTER EPITES", True, COLOR_ACCENT_GOLD)
        surface.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 30))

    def _draw_class_list(self, surface: pygame.Surface) -> None:
        x, y = 120, 110
        header = self.font_normal.render("Osztályok  (← / → szintek)", True, COLOR_TEXT_MUTED)
        surface.blit(header, (x, y))
        y += 36

        for i, cid in enumerate(AVAILABLE_CLASSES):
            cls = CLASSES[cid]
            lvl = self.class_levels.get(cid, 0)
            selected = (i == self.selected_class_idx)
            color = COLOR_ACCENT_GOLD if selected else COLOR_TEXT_LIGHT
            prefix = "> " if selected else "  "
            bar = "[" + "#" * lvl + "." * (TOTAL_LEVELS - lvl) + "]"
            line = f"{prefix}{cls.name:<12} {bar}  Lv {lvl}"
            surf = self.font_normal.render(line, True, color)
            surface.blit(surf, (x, y))
            y += 34

        remaining = self.font_normal.render(
            f"Szabad szintek: {self.levels_remaining} / {TOTAL_LEVELS}",
            True, COLOR_ACCENT_GREEN if self.levels_remaining > 0 else COLOR_ACCENT_RED
        )
        surface.blit(remaining, (x, y + 10))

    def _draw_build_summary(self, surface: pygame.Surface) -> None:
        x = SCREEN_WIDTH // 2 + 60
        y = 110
        header = self.font_normal.render("Build összesítő", True, COLOR_TEXT_MUTED)
        surface.blit(header, (x, y))
        y += 36

        if not self.active_classes:
            msg = self.font_small.render("(még nincs osztály kiválasztva)", True, COLOR_TEXT_MUTED)
            surface.blit(msg, (x, y))
            return

        for cid, lvl in self.active_classes:
            cls = CLASSES[cid]
            line = f"{cls.name}  Lv {lvl}  |  d{cls.hit_die} HP"
            surf = self.font_small.render(line, True, COLOR_TEXT_LIGHT)
            surface.blit(surf, (x, y))
            y += 26

        # Quick stat preview
        if self.levels_used > 0:
            char = Character("preview")
            for cid, lvl in self.active_classes:
                char.add_class(cid, lvl)
            char.attributes.CON = 14
            char.build()
            y += 14
            for label, val in [
                ("Max HP", char.stats.max_hp),
                ("Max Mana", char.stats.max_mana),
                ("Sebesség", int(char.stats.move_speed)),
            ]:
                surf = self.font_small.render(f"{label}: {val}", True, COLOR_ACCENT_BLUE)
                surface.blit(surf, (x, y))
                y += 22

    def _draw_name_row(self, surface: pygame.Surface) -> None:
        y = SCREEN_HEIGHT - 160
        cursor = "|" if self.name_editing else ""
        color = COLOR_ACCENT_GOLD if self.name_editing else COLOR_TEXT_LIGHT
        label = self.font_normal.render(
            f"Hős neve:  {self.char_name}{cursor}  {'(gépelés...)' if self.name_editing else '(N = szerkeszt)'}",
            True, color
        )
        surface.blit(label, (120, y))

    def _draw_controls(self, surface: pygame.Surface) -> None:
        lines = [
            "FEL/LE — osztály kijelölés    BAL/JOBB — szint -/+",
            "N — név szerkesztése    ENTER — indulás    ESC — vissza",
        ]
        y = SCREEN_HEIGHT - 110
        for line in lines:
            surf = self.font_small.render(line, True, COLOR_TEXT_MUTED)
            surface.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, y))
            y += 24

    def _draw_error(self, surface: pygame.Surface) -> None:
        surf = self.font_small.render(self.error_msg, True, COLOR_ACCENT_RED)
        surface.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, SCREEN_HEIGHT - 56))
