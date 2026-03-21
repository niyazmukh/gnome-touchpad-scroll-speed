# Mutter Touchpad Scroll Patch

This repository contains a narrow Ubuntu GNOME Wayland patch for changing
two-finger touchpad scroll speed system-wide.

The patch is designed to affect touchpad finger scrolling only. It does not
change mouse wheel scrolling, TrackPoint scrolling, pointer acceleration, or
touchpad swipe and pinch gestures.

## Scope

The code change applies a multiplier only when Mutter handles:

- `LIBINPUT_EVENT_POINTER_SCROLL_FINGER`
- `CLUTTER_SCROLL_SOURCE_FINGER`

Everything else stays on the stock path.

## Files

- `mutter-touchpad-scroll.patch`
  Patch against Ubuntu `mutter` `46.2-1ubuntu0.24.04.14`
- `set-touchpad-scroll-speed.sh`
  Helper that persists the runtime multiplier for GNOME Shell on Wayland

## Runtime Setting

The patch reads:

```sh
MUTTER_TOUCHPAD_SCROLL_MULTIPLIER=0.70
```

Values below `1.0` slow two-finger scrolling. Values above `1.0` speed it up.

## Ubuntu Notes

On this Ubuntu GNOME setup, the helper writes:

- `~/.config/systemd/user/org.gnome.Shell@wayland.service.d/90-touchpad-scroll.conf`
- `~/.config/environment.d/90-mutter-touchpad-scroll.conf`

The GNOME Shell systemd user-service override is the important one. The generic
environment file is kept as a fallback.

## Build Outline

1. Check out Ubuntu's Mutter source matching the installed package version.
2. Apply `mutter-touchpad-scroll.patch`.
3. Install the package build dependencies.
4. Build the package.
5. Install the rebuilt Mutter runtime packages.
6. Run `set-touchpad-scroll-speed.sh <multiplier>`.
7. Log out and back in.

## Design Choice

The patch uses an environment variable instead of adding a GSettings key. That
keeps the change small and avoids schema, UI, and settings-daemon churn.
