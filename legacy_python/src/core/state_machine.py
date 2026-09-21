"""State machine framework for game screen management."""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
import pygame


class State(ABC):
    """Abstract base class for all game states."""

    def __init__(self, state_machine: "StateMachine"):
        self.state_machine = state_machine
        self.engine = state_machine.engine

    def enter(self, enter_data: Optional[Dict[str, Any]] = None) -> None:
        """Called when this state becomes active."""
        pass

    def exit(self) -> None:
        """Called when transitioning away from this state."""
        pass

    @abstractmethod
    def handle_event(self, event: pygame.event.Event) -> None:
        """Process a single Pygame event."""
        pass

    @abstractmethod
    def update(self, dt: float) -> None:
        """Update state logic. dt is delta time in seconds."""
        pass

    @abstractmethod
    def render(self, surface: pygame.Surface) -> None:
        """Draw this state's visuals onto the target surface."""
        pass


class StateMachine:
    """Manages registered states and transitions between them."""

    def __init__(self, engine: Any):
        self.engine = engine
        self._states: Dict[Any, State] = {}
        self._current_state: Optional[State] = None
        self._current_state_id: Optional[Any] = None

    def register(self, state_id: Any, state: State) -> None:
        """Register a state instance with a unique ID."""
        self._states[state_id] = state

    def change_state(self, state_id: Any, enter_data: Optional[Dict[str, Any]] = None) -> None:
        """Transition from current state to the target state."""
        if state_id not in self._states:
            raise ValueError(f"State '{state_id}' is not registered in StateMachine.")

        if self._current_state:
            self._current_state.exit()

        self._current_state_id = state_id
        self._current_state = self._states[state_id]
        self._current_state.enter(enter_data)

    @property
    def current_state(self) -> Optional[State]:
        return self._current_state

    @property
    def current_state_id(self) -> Optional[Any]:
        return self._current_state_id

    def handle_event(self, event: pygame.event.Event) -> None:
        if self._current_state:
            self._current_state.handle_event(event)

    def update(self, dt: float) -> None:
        if self._current_state:
            self._current_state.update(dt)

    def render(self, surface: pygame.Surface) -> None:
        if self._current_state:
            self._current_state.render(surface)
