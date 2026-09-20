"""Core package exports with lazy pygame-dependent imports."""

from src.core.constants import *


def __getattr__(name):
    """Load runtime engine types only when they are explicitly requested."""
    if name in {"State", "StateMachine"}:
        from src.core.state_machine import State, StateMachine
        return {"State": State, "StateMachine": StateMachine}[name]
    if name == "GameEngine":
        from src.core.engine import GameEngine
        return GameEngine
    raise AttributeError(f"module 'src.core' has no attribute {name!r}")
