# gnome-touchpad-scroll-speed

Ubuntu GNOME Wayland patch for changing two-finger touchpad scroll speed
system-wide.

The patch changes touchpad finger scrolling only. It does not change:

- mouse wheel scrolling
- TrackPoint / pointing stick scrolling
- pointer acceleration
- swipe gestures
- pinch gestures

## Quick Install

```bash
git clone https://github.com/niyazmukh/gnome-touchpad-scroll-speed ~/Repos/mutter-touchpad-scroll-speed && \
cd ~/Repos/mutter-touchpad-scroll-speed && \
./install.sh --multiplier 0.70
```

What the installer does:

- enables Ubuntu source repositories if needed
- installs Mutter build dependencies
- downloads the supported Ubuntu Mutter source package
- applies the patch
- builds and installs the patched runtime packages
- installs a helper command at `~/.local/bin/gnome-touchpad-scroll-speed`
- sets the initial multiplier

After installation:

1. log out
2. log back in

## Adjust Later

After install, use:

```bash
~/.local/bin/gnome-touchpad-scroll-speed 0.70
```

Examples:

```bash
~/.local/bin/gnome-touchpad-scroll-speed 0.50
~/.local/bin/gnome-touchpad-scroll-speed 1.20
~/.local/bin/gnome-touchpad-scroll-speed --unset
```

Rules:

- `1.0` is the default behavior
- below `1.0` is slower
- above `1.0` is faster
- changes take effect after logout/login

## Supported Version

This repository is intended for:

- Ubuntu `24.04` and newer

The installer detects the installed `libmutter-*` runtime package, derives the
matching Ubuntu Mutter source version, and rebuilds against that exact source
package version.

This is a best-effort compatibility promise, not a guarantee.

## Compatibility Disclaimer

This patch was originally developed and verified on Ubuntu `24.04` GNOME
Wayland. It is expected to work on later Ubuntu releases only as long as Mutter
keeps a compatible input path and the patch still applies cleanly.

Newer Ubuntu releases may fail in any of these ways:

- the patch no longer applies cleanly
- the relevant Mutter code moved or was refactored
- package names or binary package slots changed
- the package builds but the behavior needs adjustment

If that happens, the installer should fail rather than apply the patch
blindly, and the patch will need to be refreshed for that Ubuntu/Mutter
version.

## Files

- `install.sh`
  Full installer for Ubuntu 24.04 and newer, using best-effort Mutter version detection
- `mutter-touchpad-scroll.patch`
  The actual Mutter source patch
- `set-touchpad-scroll-speed.sh`
  Helper for changing the multiplier after installation

## Technical Scope

The code path is intentionally narrow. The multiplier is applied only when
Mutter handles:

- `LIBINPUT_EVENT_POINTER_SCROLL_FINGER`
- `CLUTTER_SCROLL_SOURCE_FINGER`

Everything else stays on the normal path.

## Runtime Integration

The patch reads:

```sh
MUTTER_TOUCHPAD_SCROLL_MULTIPLIER=0.70
```

On Ubuntu GNOME Wayland, the helper writes:

- `~/.config/systemd/user/org.gnome.Shell@wayland.service.d/90-touchpad-scroll.conf`

The GNOME Shell systemd user-service override is the one that matters.

## Why This Design

This patch uses an environment variable instead of introducing a GNOME UI or a
new GSettings key. That keeps the change small and local to Mutter, avoids
schema churn, and reduces the risk of touching unrelated input behavior.
