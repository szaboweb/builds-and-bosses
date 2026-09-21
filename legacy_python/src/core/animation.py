"""Small frame-based animation primitives for 48 px pixel sprites."""

from dataclasses import dataclass
from typing import Optional

import pygame


@dataclass(frozen=True)
class AnimationClip:
    """A named sequence of frames played at a fixed rate."""

    frames: list[pygame.Surface]
    fps: float = 8.0
    loop: bool = True

    @property
    def duration(self) -> float:
        return len(self.frames) / max(self.fps, 1.0)


class SpriteAnimator:
    """Select frames for named animation states without owning game logic."""

    def __init__(self, clips: Optional[dict[str, AnimationClip]] = None):
        self.clips = clips or {}
        self.state = "idle"
        self.elapsed = 0.0

    def set_state(self, state: str, *, restart: bool = False) -> None:
        if state != self.state or restart:
            self.state = state
            self.elapsed = 0.0

    def update(self, dt: float) -> None:
        self.elapsed += max(dt, 0.0)

    def frame(self) -> Optional[pygame.Surface]:
        clip = self.clips.get(self.state) or self.clips.get("idle")
        if not clip or not clip.frames:
            return None
        index = int(self.elapsed * clip.fps)
        if clip.loop:
            index %= len(clip.frames)
        else:
            index = min(index, len(clip.frames) - 1)
        return clip.frames[index]
