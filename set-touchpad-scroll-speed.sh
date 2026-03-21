#!/usr/bin/env bash
set -euo pipefail

ENV_CONF_DIR="${HOME}/.config/environment.d"
ENV_CONF_FILE="${ENV_CONF_DIR}/90-mutter-touchpad-scroll.conf"
UNIT_DIR="${HOME}/.config/systemd/user/org.gnome.Shell@wayland.service.d"
UNIT_FILE="${UNIT_DIR}/90-touchpad-scroll.conf"
ENV_NAME="MUTTER_TOUCHPAD_SCROLL_MULTIPLIER"

usage() {
  cat <<'EOF'
Usage:
  set-touchpad-scroll-speed.sh <multiplier>
  set-touchpad-scroll-speed.sh --unset

Examples:
  set-touchpad-scroll-speed.sh 0.70
  set-touchpad-scroll-speed.sh 1.35

Notes:
  - 1.0 is the default
  - values below 1.0 slow two-finger touchpad scrolling
  - values above 1.0 speed it up
  - changes take effect after logging out and back in
  - on this machine the setting is pinned to the GNOME Shell Wayland service
EOF
}

validate_multiplier() {
  local value="$1"

  if ! [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf 'Expected a positive number, got: %s\n' "$value" >&2
    exit 1
  fi

  awk -v value="$value" 'BEGIN { exit !(value > 0.0) }'
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  --unset)
    rm -f "$ENV_CONF_FILE" "$UNIT_FILE"
    rmdir --ignore-fail-on-non-empty "$UNIT_DIR" 2>/dev/null || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    printf 'Removed %s and %s. Log out and back in to restore the default scroll speed.\n' \
      "$ENV_CONF_FILE" "$UNIT_FILE"
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
esac

validate_multiplier "$1"
mkdir -p "$ENV_CONF_DIR" "$UNIT_DIR"
printf '%s=%s\n' "$ENV_NAME" "$1" > "$ENV_CONF_FILE"
cat > "$UNIT_FILE" <<EOF
[Service]
Environment=${ENV_NAME}=$1
EOF
systemctl --user daemon-reload >/dev/null 2>&1 || true

cat <<EOF
Saved $ENV_NAME=$1 to:
  $ENV_CONF_FILE
  $UNIT_FILE
Log out and back in for GNOME Shell to pick up the new touchpad scroll speed.
EOF
