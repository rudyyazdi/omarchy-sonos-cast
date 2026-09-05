# Sonos Cast — Omarchy plugin

Send all audio from your Omarchy (Hyprland/PipeWire) machine to a Sonos
speaker, with a bar widget, volume slider, and volume-key passthrough.

Built for a Sonos Play:1 (no line-in / AirPlay / Bluetooth). The path is
PipeWire null sink → `parec` → uncompressed 16-bit PCM WAV over HTTP → Sonos.
No encoding step, so the only delay is the speaker's own HTTP buffer
(roughly 1–2 s).

## Features

- Bar icon (**S**): left click opens the panel, middle click toggles casting,
  scroll adjusts speaker volume while casting
- Panel: cast on/off, speaker volume slider, mute
- Volume keys drive the speaker while casting and fall back to local audio otherwise
- Auto hand-back: if something else takes over the speaker (Spotify from a phone,
  the Sonos app), casting turns itself off and your local output is restored
- Watchdog restarts the stream if the speaker stops on its own

## Install

```sh
git clone https://github.com/rudyyazdi/omarchy-sonos-cast ~/.config/omarchy/plugins/user.sonos-cast
ln -sf ~/.config/omarchy/plugins/user.sonos-cast/sonos-cast ~/.local/bin/sonos-cast
```

1. Edit `config.env` and set `SONOS_HOST` to your speaker's IP
   (`avahi-browse -rt _sonos._tcp` or the Sonos app → About My System).
2. Let the speaker reach the stream port through ufw:
   ```sh
   sudo ufw allow from <SONOS_IP> to any port 8765 proto tcp comment 'sonos-cast'
   ```
3. Add the widget to `~/.config/omarchy/shell.json` under `bar.layout.right`:
   ```json
   { "id": "user.sonos-cast" }
   ```
4. Optional keybindings, in `~/.config/hypr/bindings.lua`:
   ```lua
   hl.unbind("XF86AudioRaiseVolume"); hl.unbind("XF86AudioLowerVolume"); hl.unbind("XF86AudioMute")
   hl.unbind("ALT + XF86AudioRaiseVolume"); hl.unbind("ALT + XF86AudioLowerVolume")
   o.bind("XF86AudioRaiseVolume", "Volume up", "sonos-cast key raise", { locked = true, repeating = true })
   o.bind("XF86AudioLowerVolume", "Volume down", "sonos-cast key lower", { locked = true, repeating = true })
   o.bind("XF86AudioMute", "Mute", "sonos-cast key mute-toggle", { locked = true })
   o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "sonos-cast key +1", { locked = true, repeating = true })
   o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "sonos-cast key -1", { locked = true, repeating = true })
   o.bind("SUPER + CTRL + S", "Toggle Sonos cast", "sonos-cast toggle")
   ```

## CLI

```
sonos-cast on | off | toggle
sonos-cast status [--json]
sonos-cast volume <N|+N|-N>
sonos-cast mute-toggle
sonos-cast key <raise|lower|mute-toggle|+N|-N>   # volume-key shim
```

## Files

| File            | Purpose                                            |
|-----------------|----------------------------------------------------|
| `sonos-cast`    | Python CLI, stream server, Sonos SOAP control      |
| `SonosCast.qml` | Quickshell bar widget and panel                    |
| `config.env`    | `SONOS_HOST`, `PORT`, `STEP`, `LATENCY_MS`         |
| `manifest.json` | Omarchy plugin manifest                            |

Runtime state and `server.log` live in `$XDG_RUNTIME_DIR/sonos-cast/`.

## Requirements

Omarchy with the Quickshell shell, PipeWire with `pipewire-pulse` (`pactl`, `parec`),
Python 3. Tested against a Play:1 on S1 firmware; any Sonos player that accepts
`SetAVTransportURI` with an HTTP WAV URL should work.

MIT License.
