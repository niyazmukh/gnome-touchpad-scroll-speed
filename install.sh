#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${REPO_DIR}/mutter-touchpad-scroll.patch"
HELPER_SRC="${REPO_DIR}/set-touchpad-scroll-speed.sh"
HELPER_DEST="${HOME}/.local/bin/gnome-touchpad-scroll-speed"
BUILD_ROOT="${TMPDIR:-/tmp}/gnome-touchpad-scroll-build"
EXPECTED_VERSION="46.2-1ubuntu0.24.04.14"
LOCAL_VERSION="${EXPECTED_VERSION}+touchpad1"
DEFAULT_MULTIPLIER="0.70"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--multiplier VALUE] [--keep-build-dir]

Examples:
  ./install.sh
  ./install.sh --multiplier 0.70
  ./install.sh --multiplier 0.50 --keep-build-dir

What it does:
  - enables Ubuntu source repositories if needed
  - installs Mutter build dependencies
  - downloads Ubuntu's Mutter source for the supported version
  - applies the touchpad scroll patch
  - builds the runtime packages
  - installs the rebuilt packages
  - installs a helper command at ~/.local/bin/gnome-touchpad-scroll-speed
  - sets the initial touchpad scroll multiplier

Notes:
  - this installer currently targets Ubuntu 24.04 with Mutter 46.2-1ubuntu0.24.04.14
  - it requires sudo for apt and package installation
  - you still need to log out and back in after installation
EOF
}

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

validate_multiplier() {
  local value="$1"

  if ! [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    die "expected a positive number for --multiplier, got '$value'"
  fi

  awk -v value="$value" 'BEGIN { exit !(value > 0.0) }' ||
    die "multiplier must be greater than zero"
}

ensure_supported_os() {
  [[ -r /etc/os-release ]] || die "/etc/os-release is missing"
  # shellcheck disable=SC1091
  source /etc/os-release

  [[ "${ID:-}" == "ubuntu" ]] || die "this installer currently supports Ubuntu only"
  [[ "${VERSION_ID:-}" == "24.04" ]] || die "this installer currently supports Ubuntu 24.04 only"
}

ensure_supported_mutter_version() {
  local installed_version

  installed_version="$(dpkg-query -W -f='${Version}' libmutter-14-0 2>/dev/null || true)"
  [[ -n "$installed_version" ]] || die "libmutter-14-0 is not installed"

  case "$installed_version" in
    "$EXPECTED_VERSION"|"$EXPECTED_VERSION"+*)
      ;;
    *)
      die "installed libmutter-14-0 version is '$installed_version', but this patch targets '$EXPECTED_VERSION'"
      ;;
  esac
}

ensure_prereqs() {
  command -v sudo >/dev/null || die "sudo is required"
  command -v apt-get >/dev/null || die "apt-get is required"
  command -v dpkg-buildpackage >/dev/null || die "dpkg-buildpackage is required"
  command -v patch >/dev/null || die "patch is required"
}

enable_source_repos() {
  local sources_file="/etc/apt/sources.list.d/ubuntu.sources"

  [[ -f "$sources_file" ]] || die "expected Ubuntu sources file at $sources_file"

  if grep -Eq '^Types: .*deb-src' "$sources_file"; then
    log "Ubuntu source repositories are already enabled"
    return
  fi

  log "Enabling Ubuntu source repositories"
  sudo perl -0pi -e 's/^Types: deb$/Types: deb deb-src/mg' "$sources_file"
}

prepare_build_root() {
  if [[ -d "$BUILD_ROOT" ]]; then
    log "Removing previous build root $BUILD_ROOT"
    rm -rf "$BUILD_ROOT"
  fi

  mkdir -p "$BUILD_ROOT"
}

download_source() {
  log "Updating apt metadata"
  sudo apt-get update

  log "Installing Mutter build dependencies"
  sudo apt-get build-dep -y mutter

  log "Downloading Mutter source $EXPECTED_VERSION"
  (
    cd "$BUILD_ROOT"
    apt-get source "mutter=${EXPECTED_VERSION}"
  )
}

prepare_source_tree() {
  local source_dir
  source_dir="$(find "$BUILD_ROOT" -maxdepth 1 -mindepth 1 -type d -name 'mutter-*' | head -n 1)"
  [[ -n "$source_dir" ]] || die "could not find extracted Mutter source tree in $BUILD_ROOT"

  log "Applying patch"
  (
    cd "$source_dir"
    patch -p1 < "$PATCH_FILE"
  )

  log "Adding local changelog entry"
  (
    cd "$source_dir"
    tmp_file="$(mktemp)"
    {
      printf 'mutter (%s) noble; urgency=medium\n\n' "$LOCAL_VERSION"
      printf '  * Add touchpad-only finger scroll multiplier patch.\n\n'
      printf ' -- Local Builder <local@localhost>  %s\n\n' "$(date -R)"
      cat debian/changelog
    } > "$tmp_file"
    mv "$tmp_file" debian/changelog
  )

  printf '%s\n' "$source_dir"
}

build_packages() {
  local source_dir="$1"

  log "Building patched Mutter packages"
  (
    cd "$source_dir"
    DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -uc -us
  )
}

install_packages() {
  local debs=(
    "$BUILD_ROOT"/gir1.2-mutter-14_"$LOCAL_VERSION"_*.deb
    "$BUILD_ROOT"/libmutter-14-0_"$LOCAL_VERSION"_*.deb
    "$BUILD_ROOT"/mutter-common_"$LOCAL_VERSION"_*.deb
    "$BUILD_ROOT"/mutter-common-bin_"$LOCAL_VERSION"_*.deb
  )

  log "Installing patched runtime packages"
  sudo apt-get install -y "${debs[@]}"
}

install_helper() {
  log "Installing helper command to $HELPER_DEST"
  mkdir -p "$(dirname "$HELPER_DEST")"
  install -m 0755 "$HELPER_SRC" "$HELPER_DEST"
  rm -f "${HOME}/.config/environment.d/90-mutter-touchpad-scroll.conf"
}

apply_multiplier() {
  local multiplier="$1"

  log "Setting initial touchpad scroll multiplier to $multiplier"
  "$HELPER_DEST" "$multiplier"
}

main() {
  local multiplier="$DEFAULT_MULTIPLIER"
  local keep_build_dir=0
  local source_dir

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --multiplier)
        [[ $# -ge 2 ]] || die "--multiplier requires a value"
        multiplier="$2"
        shift 2
        ;;
      --keep-build-dir)
        keep_build_dir=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  validate_multiplier "$multiplier"
  ensure_supported_os
  ensure_supported_mutter_version
  ensure_prereqs
  enable_source_repos
  prepare_build_root
  download_source
  source_dir="$(prepare_source_tree)"
  build_packages "$source_dir"
  install_packages
  install_helper
  apply_multiplier "$multiplier"

  if [[ "$keep_build_dir" -eq 0 ]]; then
    log "Cleaning up build root $BUILD_ROOT"
    rm -rf "$BUILD_ROOT"
  else
    log "Keeping build root at $BUILD_ROOT"
  fi

  cat <<EOF

Install complete.

Next steps:
  1. Log out and back in
  2. Adjust the multiplier later with:
     ${HELPER_DEST} 0.70
EOF
}

main "$@"
