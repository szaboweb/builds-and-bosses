# Character Animation Assets

Character animation sheets use 32x32 pixel frames. Keep the character's feet on
the same baseline in every frame; transparent padding is allowed.

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

- `idle.png`: 4 frames, 128x32
- `walk.png`: 6 frames, 192x32
- `attack.png`: 6 frames, 192x32
- `block.png`: 4 frames, 128x32
- `hit.png`: 2 frames, 64x32
- `death.png`: 6 frames, 192x32

The first implementation uses one row per animation and the character's current facing direction can be added as additional rows later. Missing sheets fall back to `assets/characters/<class_id>.png`.
