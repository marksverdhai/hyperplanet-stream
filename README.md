# Hyperplanet Stream

Hyperplanet Stream is a headless, container-friendly YouTube live-production stack built from FFmpeg, HT Vibe, tmux, and Director. It drives a continuous 1080p scene and music rotation, spatial scene audio, an audio-reactive shader, a truecolor Clanker terminal overlay, live health supervision, and a spoof-resistant moderator instruction relay.

This repository contains **no media assets or credentials**. Supply video, music, sound effects, and YouTube credentials locally.

## Features

- Frame-aligned shuffled scene and playlist cycles
- 1080p24 H.264 CBR output at 10 Mbps with 256 kbps AAC
- HT Vibe WGSL visualizer input and included audio-reactive Mandelbulb shader
- Scene-specific spatial audio and SFX profiles
- Full ANSI/truecolor tmux rendering with transparent inactive frames
- Director-backed working/listening status
- Health-checked shader handoffs with automatic rollback
- Encoder and public-stream watchdog
- YouTube live-chat listener pinned to an exact moderator channel ID and moderator badge
- At-most-once Director delivery with no handle-only trust

## Requirements

The current deployment targets Arch Linux/Omarchy:

```bash
sudo pacman -S --needed ffmpeg git jq python-pillow python tmux
```

Install [HT Vibe](https://github.com/heiervang-technologies/ht-vibe), `director`, and `vibe-headless` separately. `vibe-headless` defaults to `~/.cargo/bin/vibe-headless`.

## Install

```bash
git clone https://github.com/marksverdhai/hyperplanet-stream.git
cd hyperplanet-stream
./install.sh
```

The installer writes executables to `~/.local/bin`, shaders and a Python virtual environment to `~/.local/share/hyperplanet-stream`, and sample configuration to `~/.config/hyperplanet-stream`. Existing config and secrets are never overwritten.

## Media Layout

Create media outside the repository:

```text
~/stream/
├── playlists/
│   ├── one/*.wav
│   └── two/*.mp3
├── scenes/
│   ├── catalog.json
│   ├── one/*.mp4
│   └── three/*.mp4
└── sfx/space-turbulence.mp3
```

Start with `config/catalog.example.json`. Asset paths are resolved beneath `HYPERPLANET_STREAM_ROOT` and escaping paths are rejected.

## Configure

1. Put the ingest key in `~/.config/hyperplanet-stream/secrets.env` and set mode `0600`.
2. Set the public watch URL in `stream-watchdog.json`.
3. Put the trusted moderator's immutable YouTube channel ID and enrollment handle in `chat-listener.json`.
4. Set `HYPERPLANET_TERMINAL_AGENT` to the Director agent name whose Clanker pane should appear.
5. Copy the example scene catalog into `~/stream/scenes/catalog.json` and adjust local asset paths.

Useful overrides include `HYPERPLANET_STREAM_ROOT`, `HYPERPLANET_VIBE_BINARY`, `HYPERPLANET_VIBE_SHADER`, `HYPERPLANET_STREAM_LABEL`, `HYPERPLANET_AGENT_LABEL`, and `HYPERPLANET_CONFIG_DIR`.

## Run

```bash
hyperplanet-start
```

The terminal overlay is owned by the FFmpeg lifecycle. It renders the active Clanker viewport at 12 FPS, preserves ANSI foreground/background color and block-cell pixel art, redacts common credential forms, and emits a fully transparent frame when inactive.

Apply a shader change without wedging the live stream:

```bash
hyperplanet-stream-reload \
  ~/.local/share/hyperplanet-stream/shaders/hai_mandelbulb.wgsl \
  --width 640 --height 360
```

Stop all managed sessions with `hyperplanet-stop`.

## YouTube OAuth

OAuth is required only for writing to chat. Put a Google desktop OAuth client at `~/.config/hyperplanet-stream/client_secret.json`, then run:

```bash
hyperplanet-youtube-chat auth
```

The incoming listener uses the public live-chat transport and therefore does not consume YouTube Data API quota. It still requires an exact channel-ID match and the current moderator badge before forwarding message text to Director.

## Security

- Never commit stream keys, OAuth files, runtime logs, channel enrollment, or media.
- The terminal overlay redacts common secrets, but broadcasting an interactive terminal remains inherently sensitive. Use a dedicated agent pane and avoid displaying credentials.
- The moderator relay trusts YouTube's immutable channel ID and moderator badge, not a mutable display name or handle.
- Message metadata is not converted into shell syntax; only authenticated message text is delivered.

## Validation

```bash
python -m pip install -r requirements.txt pytest
make check
```

## License

MIT. HT Vibe is a separate dependency under its own license.
