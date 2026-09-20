# Builds & Bosses - FNA port

This directory contains the first C# port of the playable vertical slice:

- Blueprint Table with Level Up / Level Down mode (`Q`)
- Campaign level matrix and three-class blueprint validation
- Left-side hero spawn
- Gravekeeper Malakar boss fight
- JSON data loading from the existing `data/` directory
- Pixel-art-friendly rendering with `SamplerState.PointClamp`

## Linux / WSL setup

The project targets .NET 8 and references a locally built FNA assembly.

```bash
export PATH="$HOME/.dotnet:$PATH"
export FNA_PATH="$HOME/.local/share/FNA/bin/Release/netstandard2.0"

# FNA source with submodules
mkdir -p "$HOME/.local/share"
git clone --recurse-submodules https://github.com/FNA-XNA/FNA.git "$HOME/.local/share/FNA"
dotnet build "$HOME/.local/share/FNA/FNA.NetStandard.csproj" -c Release

# Build this port
cd builds-and-bosses
dotnet build FnaPort/BuildsAndBosses.Fna.csproj -c Release
```

On Ubuntu, FNA may additionally require these native libraries:

```bash
sudo apt update
sudo apt install libsdl2-2.0-0 libopenal1 libfaudio0
```

The WSL environment used during this port already provided SDL2 and OpenAL.

## Controls

- Blueprint: `Q` switches level mode, `Right` adds a Fighter level, `Left` removes one, `Enter` starts the fight.
- Boss: `A/D` or arrows move, `W` jumps, `Space` attacks, `Escape` exits.

The current renderer intentionally uses generated rectangles as placeholders. Replace these draw calls with hand-drawn `Texture2D` sprite sheets as the pixel-art assets are produced.
