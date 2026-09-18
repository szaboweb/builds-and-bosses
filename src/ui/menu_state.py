"""Main menu state with rich visual layout, keyboard and mouse support."""

import pygame
import math
from typing import List, Tuple, Dict, Any, Optional

from src.core.state_machine import State, StateMachine
from src.core.constants import (
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
    COLOR_BG_DARK,
    COLOR_BG_PANEL,
    COLOR_PANEL_BORDER,
    COLOR_TEXT_LIGHT,
    COLOR_TEXT_MUTED,
    COLOR_ACCENT_GOLD,
    COLOR_ACCENT_RED,
    COLOR_ACCENT_BLUE,
    GameStateId
)


class MainMenuState(State):
    """Interactive main menu state."""

    def __init__(self, state_machine: StateMachine):
        super().__init__(state_machine)
        self.menu_items: List[str] = [
            "Új Játék / Karakter Készítés",
            "12 Boss Ranglista (Scoreboard)",
            "Boss Editor",
            "Kilépés"
        ]
        self.selected_index: int = 0
        self.anim_time: float = 0.0

        # Fonts will be loaded upon enter/init
        self.font_title: Optional[pygame.font.Font] = None
        self.font_subtitle: Optional[pygame.font.Font] = None
        self.font_menu: Optional[pygame.font.Font] = None
        self.font_info: Optional[pygame.font.Font] = None

        self.item_rects: List[pygame.Rect] = []

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        self.selected_index = 0
        self.anim_time = 0.0
        self._init_fonts()

    def _init_fonts(self) -> None:
        if self.font_title is None and pygame.font.get_init():
            # Use sysfonts with clean fallbacks
            self.font_title = pygame.font.SysFont("Georgia", 48, bold=True)
            self.font_subtitle = pygame.font.SysFont("Segoe UI", 20, italic=True)
            self.font_menu = pygame.font.SysFont("Segoe UI", 24, bold=True)
            self.font_info = pygame.font.SysFont("Segoe UI", 16)

    def handle_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_UP, pygame.K_w):
                self.selected_index = (self.selected_index - 1) % len(self.menu_items)
            elif event.key in (pygame.K_DOWN, pygame.K_s):
                self.selected_index = (self.selected_index + 1) % len(self.menu_items)
            elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._activate_selected()
        elif event.type == pygame.MOUSEMOTION:
            mouse_pos = event.pos
            for idx, rect in enumerate(self.item_rects):
                if rect.collidepoint(mouse_pos):
                    self.selected_index = idx
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # Left click
                for idx, rect in enumerate(self.item_rects):
                    if rect.collidepoint(event.pos):
                        self.selected_index = idx
                        self._activate_selected()

    def _activate_selected(self) -> None:
        if self.selected_index == 0:
            # Start run / Character Builder
            # If state exists, switch; otherwise log/display
            if GameStateId.CHARACTER_BUILDER in self.state_machine._states:
                self.state_machine.change_state(GameStateId.CHARACTER_BUILDER)
            else:
                print("Mérföldkő 2: Karakterépítő még fejlesztés alatt.")
        elif self.selected_index == 1:
            # Scoreboard
            if GameStateId.SCOREBOARD in self.state_machine._states:
                self.state_machine.change_state(GameStateId.SCOREBOARD)
            else:
                print("Mérföldkő 6: Scoreboard még fejlesztés alatt.")
        elif self.selected_index == 2:
            # Boss Editor
            if GameStateId.BOSS_EDITOR in self.state_machine._states:
                self.state_machine.change_state(GameStateId.BOSS_EDITOR)
        elif self.selected_index == 3:
            # Exit
            self.engine.stop()

    def update(self, dt: float) -> None:
        self.anim_time += dt

    def render(self, surface: pygame.Surface) -> None:
        self._init_fonts()

        # Decorative background ambient glow
        center_x = SCREEN_WIDTH // 2
        pulse = (math.sin(self.anim_time * 2.0) + 1.0) * 0.5  # 0.0 .. 1.0

        # Title banner
        if self.font_title:
            title_surf = self.font_title.render("BUILDS & BOSSES", True, COLOR_ACCENT_GOLD)
            title_rect = title_surf.get_rect(center=(center_x, 150))
            
            # Subtle title shadow
            shadow_surf = self.font_title.render("BUILDS & BOSSES", True, (40, 30, 10))
            surface.blit(shadow_surf, (title_rect.x + 3, title_rect.y + 3))
            surface.blit(title_surf, title_rect)

        # Subtitle
        if self.font_subtitle:
            sub_text = "D&D Multiclass Action RPG — 12 Boss Gauntlet & Attrition Trial"
            sub_surf = self.font_subtitle.render(sub_text, True, COLOR_TEXT_MUTED)
            sub_rect = sub_surf.get_rect(center=(center_x, 210))
            surface.blit(sub_surf, sub_rect)

        # Menu Panel Box
        panel_width = 540
        panel_height = 240
        panel_x = center_x - panel_width // 2
        panel_y = 280
        panel_rect = pygame.Rect(panel_x, panel_y, panel_width, panel_height)

        # Draw panel background & border
        pygame.draw.rect(surface, COLOR_BG_PANEL, panel_rect, border_radius=8)
        pygame.draw.rect(surface, COLOR_PANEL_BORDER, panel_rect, width=2, border_radius=8)

        # Draw menu items
        self.item_rects.clear()
        start_y = panel_y + 40
        item_spacing = 60

        for i, item_text in enumerate(self.menu_items):
            is_selected = (i == self.selected_index)
            item_y = start_y + i * item_spacing
            item_box = pygame.Rect(panel_x + 30, item_y - 12, panel_width - 60, 48)
            self.item_rects.append(item_box)

            if is_selected:
                # Highlight fill with pulse
                highlight_alpha = int(40 + pulse * 30)
                highlight_surface = pygame.Surface((item_box.width, item_box.height), pygame.SRCALPHA)
                highlight_surface.fill((230, 175, 45, highlight_alpha))
                surface.blit(highlight_surface, item_box.topleft)
                pygame.draw.rect(surface, COLOR_ACCENT_GOLD, item_box, width=2, border_radius=6)

                arrow = "►  "
                text_color = COLOR_ACCENT_GOLD
            else:
                arrow = "   "
                text_color = COLOR_TEXT_LIGHT

            if self.font_menu:
                label_surf = self.font_menu.render(arrow + item_text, True, text_color)
                label_rect = label_surf.get_rect(midleft=(item_box.x + 20, item_box.centery))
                surface.blit(label_surf, label_rect)

        # Footer info
        if self.font_info:
            info_text = "Navigáció: [FEL/LE] vagy Egér  |  Kiválasztás: [ENTER] vagy Kattintás  |  Kilépés: [ESC]"
            info_surf = self.font_info.render(info_text, True, COLOR_TEXT_MUTED)
            info_rect = info_surf.get_rect(center=(center_x, SCREEN_HEIGHT - 50))
            surface.blit(info_surf, info_rect)
