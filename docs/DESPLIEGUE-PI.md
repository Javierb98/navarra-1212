# Despliegue en la Raspberry Pi

Development happens on the Mac; the Pi only ever runs an exported build.

> **Untested paths.** I could not verify the export or the cabinet setup from
> here — there is no Pi on this machine and the Linux export templates are a
> separate download. The renderer choice and the project settings are correct
> and verified; everything below the "Export" heading is written from how this
> is normally done and should be treated as a first draft to check against your
> hardware.

## Hardware assumptions

- Raspberry Pi 4 (4 GB) or Pi 5. A Pi 3 will probably run this — the game is
  2D, turn-based and low fill-rate — but it has not been tried.
- Raspberry Pi OS **64-bit**, Bookworm or later.
- USB arcade encoder (Zero Delay, IPAC or similar). Both the joystick and the
  keyboard-emulating kinds are already mapped — see below.

## Why GL Compatibility

`project.godot` sets:

```ini
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

**Do not change this to Forward+.** Forward+ needs Vulkan, and the Pi has no
usable Vulkan path for this; GL Compatibility targets OpenGL ES 3.0, which the
Pi's Mesa/V3D driver provides. Everything in `shaders/` is written against ES 3
and stays within it.

## Export

One-time setup on the Mac:

1. Open the editor once so it writes `.godot/` and validates the project.
2. **Editor → Manage Export Templates → Download and Install** for 4.7.1.
   Roughly 1 GB. Without this, exporting fails with "no export template found".
3. **Project → Export**. There is a starting preset in `export_presets.cfg`
   named *Raspberry Pi*; confirm it shows platform **Linux**, architecture
   **arm64**, and *Embed PCK* on. If it looks wrong, delete it and add a fresh
   Linux preset with those three settings — a hand-written preset file is the
   most likely thing here to be slightly off for your editor version.

Then:

```sh
./tools/export_pi.sh              # builds to build/pi/
./tools/export_pi.sh pi@navarra   # builds and scp's it across
```

The result is a single self-contained binary with the game data embedded.

## Running it on the Pi

```sh
chmod +x navarra-1212
./navarra-1212 --fullscreen
```

`Cfg` also honours a `fullscreen` flag saved in `~/.local/share/godot/app_userdata/…/cabinet.cfg`,
so once set on the cabinet the flag is not needed.

## Kiosk setup

Two routes. Take the first unless you want a clean boot with no desktop.

### Simple: desktop autologin + autostart

```sh
sudo raspi-config
#   System Options  → Boot / Auto Login → Desktop Autologin
#   Display Options → Screen Blanking   → No
```

Then:

```sh
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/navarra.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=1212 Las Cadenas de Navarra
Exec=/home/pi/navarra/navarra-1212 --fullscreen
X-GNOME-Autostart-enabled=true
EOF
```

### Clean: Lite + cage

Raspberry Pi OS Lite, no desktop, with `cage` (a Wayland kiosk compositor) as
the only thing on screen:

```sh
sudo apt install cage
sudo cp tools/pi/navarra-1212.service /etc/systemd/system/
sudo systemctl enable --now navarra-1212
```

The unit file is in `tools/pi/` and is commented. Boots straight to the attract
screen with no desktop, no cursor and no window decorations.

## Controls

`src/autoload/arcade_input.gd` binds every action three ways at once — a Mac
keyboard, MAME's default keyboard layout, and a gamepad — so the panel works
however the encoder presents itself. Nothing to configure if you wire it to a
standard encoder.

Panel layout assumed, one player:

```
 B1 confirmar   B2 volver      B3 dar la orden
 B4 habilidad   B5 compañía ←  B6 compañía →
 START          COIN
```

To rebind at runtime, `ArcadeInput.rebind(action, event)` persists the change;
`ArcadeInput.reset_bindings()` restores defaults. There is no remap *screen*
yet — that is a to-do.

## Cabinet housekeeping

**Screen blanking** must be off, or the cabinet goes dark mid-attract. The
`raspi-config` setting above covers the desktop route; under `cage` it is not
an issue.

**Power cuts.** An arcade machine is switched off at the wall, and Godot writes
progress to `user://` with `ConfigFile.save()`. A cut during that write can
truncate the file. Options, in increasing order of effort:

- Accept it. The file is small, writes are rare (once per battle), and a lost
  save costs the player their unlock list, not the game.
- Mount `~/.local/share/godot` on a small dedicated partition so a corrupted
  save cannot damage anything else.
- Read-only root with an overlay (`raspi-config` → Performance → Overlay File
  System) plus that writable partition. The robust answer, and the most work.

**Safe shutdown button.** Wire a normally-open button to a spare GPIO and add
to `/boot/firmware/config.txt`:

```ini
dtoverlay=gpio-shutdown,gpio_pin=3,active_low=1,gpio_pull=up
```

**Audio.** There is no sound yet. When there is, force the output device —
`raspi-config` → System Options → Audio — rather than relying on autodetection,
which changes with what is plugged into HDMI.

**Resolution.** The game renders at 1280×720 and scales with
`stretch/mode="canvas_items"`, `aspect="keep"`, so any 16:9 panel is fine and
letterboxes cleanly on anything else. For a 4:3 arcade monitor, consider
switching `aspect` to `keep_height`.

## Updating the cabinet

The binary is self-contained, so an update is one file:

```sh
scp build/pi/navarra-1212 pi@navarra:~/navarra/
ssh pi@navarra 'sudo systemctl restart navarra-1212'
```
