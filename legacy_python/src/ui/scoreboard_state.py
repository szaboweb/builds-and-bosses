"""
Scoreboard state — prototype placeholder.

Displays the result of the last run (victory/death, time, build).
TODO: persist results to data/scores.json
TODO: implement bracket ranking (+/- 5 levels)
TODO: load and display all-time leaderboard
"""

import pygame
from typing import Optional, Dict, Any

from src.core.state_machine import State, StateMachine
from src.core.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT,
    COLOR_BG_DARK, COLOR_ACCENT_GOLD, COLOR_ACCENT_RED,
    COLOR_ACCENT_GREEN, COLOR_TEXT_LIGHT, COLOR_TEXT_MUTED,
    GameStateId,
)
from src.entities.character import Character


class ScoreboardState(State):
    """Shows the run result and a placeholder leaderboard."""

    def __init__(self, state_machine: StateMachine):
        super().__init__(state_machine)
        self.character: Optional[Character] = None
        self.run_time: float = 0.0
        self.victory: bool = False
        self.font_title: Optional[pygame.font.Font] = None
        self.font_normal: Optional[pygame.font.Font] = None
        self.font_small: Optional[pygame.font.Font] = None

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        enter_data = enter_data or {}
        self.character = enter_data.get("character")
        self.run_time = enter_data.get("run_time", 0.0)
        self.victory = enter_data.get("victory", False)
        self._init_fonts()

    def _init_fonts(self) -> None:
        if self.font_title is None and pygame.font.get_init():
            self.font_title = pygame.font.SysFont("consolas,monospace", 38, bold=True)
            self.font_normal = pygame.font.SysFont("consolas,monospace", 24)
            self.font_small = pygame.font.SysFont("consolas,monospace", 18)

    def handle_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_ESCAPE):
                self.state_machine.change_state(GameStateId.MAIN_MENU)

    def update(self, dt: float) -> None:
        pass

    def render(self, surface: pygame.Surface) -> None:
        if not self.font_title:
            self._init_fonts()
        surface.fill(COLOR_BG_DARK)

        # Title
        title_color = COLOR_ACCENT_GOLD if self.victory else COLOR_ACCENT_RED
        title_text = "GYOZELEM!" if self.victory else "HALAL"
        title = self.font_title.render(title_text, True, title_color)
        surface.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 60))

        y = 150
        if self.character:
            # Build info
            build_str = " / ".join(
                f"{cid.capitalize()} {lvl}" for cid, lvl in self.character.class_levels.items()
            )
            lines = [
                f"Hős:   {self.character.name}",
                f"Build: [{build_str}]",
                f"Szint: {self.character.total_level}",
            ]
            for line in lines:
                surf = self.font_normal.render(line, True, COLOR_TEXT_LIGHT)
                surface.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, y))
                y += 34

        y += 20
        mins = int(self.run_time) // 60
        secs = int(self.run_time) % 60
        time_color = COLOR_ACCENT_GREEN if self.victory else COLOR_TEXT_MUTED
        time_surf = self.font_normal.render(
            f"Futam idő: {mins:02d}:{secs:02d}", True, time_color)
        surface.blit(time_surf, (SCREEN_WIDTH // 2 - time_surf.get_width() // 2, y))
        y += 50

        # Placeholder leaderboard notice
        note = self.font_small.render(
            "[ Ranglista mentés: hamarosan — TODO: data/scores.json ]",
            True, COLOR_TEXT_MUTED)
        surface.blit(note, (SCREEN_WIDTH // 2 - note.get_width() // 2, y))

        y += 80
        hint = self.font_small.render(
            "ENTER / SPACE / ESC — vissza a főmenübe", True, COLOR_TEXT_MUTED)
        surface.blit(hint, (SCREEN_WIDTH // 2 - hint.get_width() // 2, y))
