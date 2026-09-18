"""Core Game Engine orchestrating window, loop, timing, and states."""

import sys
import pygame
from typing import Optional

from src.core.constants import (
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
    FPS,
    TITLE,
    COLOR_BG_DARK,
    GameStateId
)
from src.core.state_machine import StateMachine


class GameEngine:
    """The central engine running the 60 FPS update and render cycle."""

    def __init__(self, headless: bool = False, max_frames: Optional[int] = None):
        """
        Args:
            headless: If True, uses dummy video driver for automated tests/CI.
            max_frames: If set, engine runs only for N frames then stops (useful for testing).
        """
        self.headless = headless
        self.max_frames = max_frames
        self.is_running = False
        self.clock = None
        self.screen = None
        self.state_machine = StateMachine(self)

    def initialize(self) -> None:
        """Initialize Pygame modules, display surface, and fonts."""
        if self.headless:
            import os
            os.environ["SDL_VIDEODRIVER"] = "dummy"

        pygame.init()
        pygame.font.init()

        if self.headless:
            self.screen = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        else:
            self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
            pygame.display.set_caption(TITLE)

        self.clock = pygame.time.Clock()
        self._register_default_states()

    def _register_default_states(self) -> None:
        """Register the primary states into the state machine."""
        from src.ui.menu_state import MainMenuState
        from src.ui.character_builder_state import CharacterBuilderState
        from src.ui.dungeon_run_state import DungeonRunState
        from src.ui.scoreboard_state import ScoreboardState

        self.state_machine.register(GameStateId.MAIN_MENU, MainMenuState(self.state_machine))
        self.state_machine.register(GameStateId.CHARACTER_BUILDER, CharacterBuilderState(self.state_machine))
        self.state_machine.register(GameStateId.DUNGEON_RUN, DungeonRunState(self.state_machine))
        self.state_machine.register(GameStateId.SCOREBOARD, ScoreboardState(self.state_machine))
        self.state_machine.change_state(GameStateId.MAIN_MENU)

    def run(self) -> None:
        """Main game loop."""
        self.is_running = True
        frame_count = 0

        while self.is_running:
            # dt in seconds (capped at 0.1s to prevent spiral on lag spike)
            raw_dt = self.clock.tick(FPS)
            dt = min(raw_dt / 1000.0, 0.1)

            # Process window/input events
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.stop()
                    break
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE and self.state_machine.current_state_id == GameStateId.MAIN_MENU:
                        self.stop()
                        break
                self.state_machine.handle_event(event)

            if not self.is_running:
                break

            # Update logic
            self.state_machine.update(dt)

            # Render
            self.screen.fill(COLOR_BG_DARK)
            self.state_machine.render(self.screen)

            if not self.headless:
                pygame.display.flip()

            frame_count += 1
            if self.max_frames is not None and frame_count >= self.max_frames:
                self.stop()

        self.shutdown()

    def stop(self) -> None:
        """Signal the engine to exit the loop."""
        self.is_running = False

    def shutdown(self) -> None:
        """Clean up Pygame resources."""
        pygame.quit()
