# Character Animation Assets

Character animation sheets use 48x48 pixel frames.

## Directory layout

```text
assets/characters/<class_id>/
  idle.png
  walk.png
  attack.png
  block.png
  hit.png
  death.png
```

Each PNG contains one animation row. Frames are arranged left to right:

- `idle.png`: 4 frames, 192x48
- `walk.png`: 6 frames, 288x48
- `attack.png`: 6 frames, 288x48
- `block.png`: 4 frames, 192x48
- `hit.png`: 2 frames, 96x48
- `death.png`: 6 frames, 288x48

The first implementation uses one row per animation and the character's current facing direction can be added as additional rows later. Missing sheets fall back to `assets/characters/<class_id>.png`.
