"""Boss Editor state — view and edit boss stat-blocks, save to JSON."""

import json
import os
import pygame
import warnings
from typing import Any, Dict, List, Optional, Tuple

from src.core.state_machine import State, StateMachine
from src.core.data_loader import DataLoader
from src.core.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT,
    COLOR_BG_DARK, COLOR_BG_PANEL, COLOR_PANEL_BORDER,
    COLOR_TEXT_LIGHT, COLOR_TEXT_MUTED,
    COLOR_ACCENT_GOLD, COLOR_ACCENT_RED, COLOR_ACCENT_GREEN,
    COLOR_ACCENT_BLUE, COLOR_ACCENT_PURPLE,
    DATA_DIR, GameStateId,
)


# ---------------------------------------------------------------------------
# Editable fields: (json_path, label, type, min, max, step)
# json_path uses "." notation: "stats.max_hp"
# ---------------------------------------------------------------------------
EDITABLE_FIELDS: List[Tuple[str, str, type, Any, Any, Any]] = [
    ("name",               "Name",            str,   None, None, None),
    ("stats.max_hp",       "Max HP",          int,   10,   2000, 10),
    ("stats.armor_class",  "Armor Class",     int,   5,    30,   1),
    ("stats.speed",        "Speed (px/s)",    float, 10.0, 300.0, 5.0),
    ("stats.attack_rate",  "Attack Rate (s)", float, 0.3,  5.0,  0.1),
    ("stats.attack_bonus", "Attack Bonus",    int,   -5,   20,   1),
    ("stats.damage_die",   "Damage Die",      int,   4,    20,   1),
    ("stats.damage_count", "Damage Count",    int,   1,    10,   1),
    ("radius",             "Radius (px)",     int,   12,   80,   4),
]


def _get_nested(d: dict, path: str) -> Any:
    keys = path.split(".")
    for k in keys:
        d = d[k]
    return d


def _set_nested(d: dict, path: str, value: Any) -> None:
    keys = path.split(".")
    for k in keys[:-1]:
        d = d[k]
    d[keys[-1]] = value


class BossEditorState(State):
    """
    Keyboard-driven boss stat editor.

    Controls:
      LEFT / RIGHT arrow  — switch between bosses
      UP / DOWN arrow     — move field cursor
      +  /  -             — increment / decrement numeric field
      ENTER on name field — start text editing mode (type new name, ENTER confirms)
      F5                  — save changes to JSON
      ESC                 — return to main menu (prompts if unsaved changes)
    """

    def __init__(self, state_machine: StateMachine) -> None:
        super().__init__(state_machine)
        self._bosses: List[dict] = []       # raw dicts, mutable
        self._boss_files: List[str] = []    # absolute paths
        self._boss_idx: int = 0             # selected boss
        self._field_idx: int = 0            # selected field row
        self._dirty: bool = False           # unsaved changes
        self._text_edit: bool = False       # name string editing mode
        self._text_buf: str = ""
        self._status_msg: str = ""
        self._status_timer: float = 0.0

        self.font_title: Optional[pygame.font.Font] = None
        self.font_normal: Optional[pygame.font.Font] = None
        self.font_small: Optional[pygame.font.Font] = None

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        self._load_all_bosses()
        self._boss_idx = 0
        self._field_idx = 0
        self._dirty = False
        self._text_edit = False
        self._status_msg = ""
        self._init_fonts()

    def exit(self) -> None:
        pass

    def _init_fonts(self) -> None:
        if self.font_title is None and pygame.font.get_init():
            self.font_title  = pygame.font.SysFont("consolas,monospace", 30, bold=True)
            self.font_normal = pygame.font.SysFont("consolas,monospace", 22)
            self.font_small  = pygame.font.SysFont("consolas,monospace", 17)

    # ------------------------------------------------------------------
    # Data helpers
    # ------------------------------------------------------------------

    def _load_all_bosses(self) -> None:
        DataLoader.clear_cache()
        bosses_dir = os.path.join(DATA_DIR, "bosses")
        self._bosses = []
        self._boss_files = []
        if not os.path.isdir(bosses_dir):
            return
        for fname in sorted(os.listdir(bosses_dir)):
            if fname.endswith(".json"):
                fpath = os.path.join(bosses_dir, fname)
                with open(fpath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self._bosses.append(data)
                self._boss_files.append(fpath)

    @property
    def _current(self) -> dict:
        return self._bosses[self._boss_idx]

    @property
    def _current_file(self) -> str:
        return self._boss_files[self._boss_idx]

    def _field_value(self, idx: int) -> Any:
        path, _, _, _, _, _ = EDITABLE_FIELDS[idx]
        return _get_nested(self._current, path)

    def _save_current(self) -> None:
        fpath = self._current_file
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(self._current, f, indent=2, ensure_ascii=False)
        DataLoader.clear_cache()
        self._dirty = False
        self._set_status(f"Saved: {os.path.basename(fpath)}", COLOR_ACCENT_GREEN)

    def _set_status(self, msg: str, color=None) -> None:
        self._status_msg = msg
        self._status_color = color or COLOR_TEXT_MUTED
        self._status_timer = 3.0

    # ------------------------------------------------------------------
    # Events
    # ------------------------------------------------------------------

    def handle_event(self, event: pygame.event.Event) -> None:
        if not self._bosses:
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                self._go_back()
            return

        if event.type == pygame.KEYDOWN:
            self._handle_key(event)

    def _handle_key(self, event: pygame.event.Event) -> None:
        key = event.key

        # --- Text edit mode for Name field ---
        if self._text_edit:
            if key == pygame.K_RETURN:
                if self._text_buf.strip():
                    _set_nested(self._current, "name", self._text_buf.strip())
                    self._dirty = True
                self._text_edit = False
            elif key == pygame.K_ESCAPE:
                self._text_edit = False
            elif key == pygame.K_BACKSPACE:
                self._text_buf = self._text_buf[:-1]
            else:
                ch = event.unicode
                if ch and ch.isprintable() and len(self._text_buf) < 40:
                    self._text_buf += ch
            return

        # --- Navigation ---
        if key in (pygame.K_UP, pygame.K_w):
            self._field_idx = (self._field_idx - 1) % len(EDITABLE_FIELDS)
        elif key in (pygame.K_DOWN, pygame.K_s):
            self._field_idx = (self._field_idx + 1) % len(EDITABLE_FIELDS)

        elif key == pygame.K_LEFT:
            self._boss_idx = (self._boss_idx - 1) % len(self._bosses)
            self._dirty = False
        elif key == pygame.K_RIGHT:
            self._boss_idx = (self._boss_idx + 1) % len(self._bosses)
            self._dirty = False

        # --- Edit value ---
        elif key in (pygame.K_PLUS, pygame.K_KP_PLUS, pygame.K_EQUALS):
            self._nudge(+1)
        elif key in (pygame.K_MINUS, pygame.K_KP_MINUS):
            self._nudge(-1)

        # --- Enter on name field starts text edit ---
        elif key == pygame.K_RETURN:
            path, _, ftype, *_ = EDITABLE_FIELDS[self._field_idx]
            if ftype is str:
                self._text_buf = str(self._field_value(self._field_idx))
                self._text_edit = True

        # --- Save ---
        elif key == pygame.K_F5:
            self._save_current()

        # --- Back ---
        elif key == pygame.K_ESCAPE:
            if self._dirty:
                self._set_status("Unsaved changes! F5 to save, ESC again to discard.", COLOR_ACCENT_RED)
                self._dirty = False   # second ESC will leave without save
            else:
                self._go_back()

    def _nudge(self, direction: int) -> None:
        path, label, ftype, fmin, fmax, step = EDITABLE_FIELDS[self._field_idx]
        if ftype is str:
            return
        current = _get_nested(self._current, path)
        new_val = current + direction * step
        if fmin is not None:
            new_val = max(fmin, new_val)
        if fmax is not None:
            new_val = min(fmax, new_val)
        if ftype is int:
            new_val = int(round(new_val))
        else:
            new_val = round(float(new_val), 2)
        _set_nested(self._current, path, new_val)
        self._dirty = True

    def _go_back(self) -> None:
        if GameStateId.MAIN_MENU in self.state_machine._states:
            self.state_machine.change_state(GameStateId.MAIN_MENU)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------

    def update(self, dt: float) -> None:
        if self._status_timer > 0:
            self._status_timer -= dt

    # ------------------------------------------------------------------
    # Render
    # ------------------------------------------------------------------

    def render(self, surface: pygame.Surface) -> None:
        self._init_fonts()
        surface.fill(COLOR_BG_DARK)
        if not self.font_title:
            return

        cx = SCREEN_WIDTH // 2
        y = 28

        # --- Title ---
        title_surf = self.font_title.render("BOSS EDITOR", True, COLOR_ACCENT_PURPLE)
        surface.blit(title_surf, title_surf.get_rect(center=(cx, y)))
        y += 46

        if not self._bosses:
            msg = self.font_normal.render("No boss JSON files found in data/bosses/", True, COLOR_ACCENT_RED)
            surface.blit(msg, msg.get_rect(center=(cx, SCREEN_HEIGHT // 2)))
            self._draw_footer(surface)
            return

        # --- Boss selector header ---
        boss_name = self._current.get("name", "???")
        boss_id   = self._current.get("id", "???")
        nav_text  = f"< {self._boss_idx + 1}/{len(self._bosses)} >  [{boss_id}]"
        if self.font_normal:
            nav_surf = self.font_normal.render(nav_text, True, COLOR_TEXT_MUTED)
            surface.blit(nav_surf, nav_surf.get_rect(center=(cx, y)))
        y += 30

        name_color = COLOR_ACCENT_GOLD if not self._dirty else (245, 130, 32)
        name_surf = self.font_title.render(boss_name, True, name_color)
        surface.blit(name_surf, name_surf.get_rect(center=(cx, y)))
        if self._dirty:
            dot = self.font_small.render("[unsaved]", True, (245, 130, 32))
            surface.blit(dot, (name_surf.get_rect(center=(cx, y)).right + 8, y + 6))
        y += 50

        # --- Field rows ---
        self._draw_fields(surface, y)

        # --- Status bar ---
        if self._status_timer > 0 and self.font_small:
            st_surf = self.font_small.render(self._status_msg, True, self._status_color)
            surface.blit(st_surf, st_surf.get_rect(center=(cx, SCREEN_HEIGHT - 60)))

        self._draw_footer(surface)

    def _draw_fields(self, surface: pygame.Surface, start_y: int) -> None:
        if not self.font_normal or not self.font_small:
            return
        ROW_H = 38
        LABEL_X = 120
        VALUE_X = 520
        BAR_X   = 680
        BAR_W   = 380

        y = start_y
        for i, (path, label, ftype, fmin, fmax, step) in enumerate(EDITABLE_FIELDS):
            selected = (i == self._field_idx)

            # Row background
            row_rect = pygame.Rect(LABEL_X - 10, y - 4, BAR_X + BAR_W - LABEL_X + 20, ROW_H - 4)
            if selected:
                pygame.draw.rect(surface, COLOR_BG_PANEL, row_rect, border_radius=6)
                pygame.draw.rect(surface, COLOR_PANEL_BORDER, row_rect, width=1, border_radius=6)

            # Label
            lc = COLOR_ACCENT_GOLD if selected else COLOR_TEXT_MUTED
            label_surf = self.font_normal.render(label, True, lc)
            surface.blit(label_surf, (LABEL_X, y))

            # Value
            raw = _get_nested(self._current, path)
            if ftype is str:
                display = self._text_buf + "|" if (selected and self._text_edit) else str(raw)
                vc = COLOR_ACCENT_BLUE if (selected and self._text_edit) else COLOR_TEXT_LIGHT
            else:
                display = str(raw)
                vc = COLOR_TEXT_LIGHT
            val_surf = self.font_normal.render(display, True, vc)
            surface.blit(val_surf, (VALUE_X, y))

            # Progress bar for numeric fields
            if ftype is not str and fmin is not None and fmax is not None:
                ratio = max(0.0, min(1.0, (raw - fmin) / (fmax - fmin)))
                bar_rect = pygame.Rect(BAR_X, y + 6, BAR_W, 16)
                pygame.draw.rect(surface, COLOR_BG_PANEL, bar_rect, border_radius=4)
                fill_w = int(BAR_W * ratio)
                if fill_w > 0:
                    bar_color = COLOR_ACCENT_RED if "hp" in path else (
                        COLOR_ACCENT_GREEN if "speed" in path else COLOR_ACCENT_BLUE
                    )
                    pygame.draw.rect(surface, bar_color,
                                     pygame.Rect(BAR_X, y + 6, fill_w, 16), border_radius=4)
                pygame.draw.rect(surface, COLOR_PANEL_BORDER, bar_rect, width=1, border_radius=4)

            y += ROW_H

    def _draw_footer(self, surface: pygame.Surface) -> None:
        if not self.font_small:
            return
        hints = (
            "[UP/DOWN] field   [+/-] value   [ENTER] edit name   "
            "[LEFT/RIGHT] boss   [F5] save   [ESC] back"
        )
        hint_surf = self.font_small.render(hints, True, COLOR_TEXT_MUTED)
        surface.blit(hint_surf, hint_surf.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT - 28)))
