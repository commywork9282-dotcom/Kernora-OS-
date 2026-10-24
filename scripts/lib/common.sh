#!/usr/bin/env bash

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly PROJECT_ROOT

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

load_upstream_config() {
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/upstream/base.env"
  export BASE_CODENAME BASE_VERSION BASE_ARCH SNAPSHOT_TIMESTAMP
  export DEBIAN_SNAPSHOT DEBIAN_SECURITY_SNAPSHOT
  export DEBIAN_SIGNER_KEYRING_VERSION DEBIAN_SIGNER_KEYRING_SHA256
  export MMDEBSTRAP_VERSION MMDEBSTRAP_SHA256
  export MTOOLS_VERSION MTOOLS_SHA256
}

load_librewolf_config() {
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/upstream/librewolf.env"
  export LIBREWOLF_REPOSITORY LIBREWOLF_SUITE LIBREWOLF_VERSION
  export LIBREWOLF_FILENAME LIBREWOLF_SHA256
}

load_quickshare_config() {
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/upstream/quickshare.env"
  export QUICKSHARE_VENDOR_SHA256
}

load_live_config() {
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/live/live-user.env"
  export LIVE_USER LIVE_USER_UID LIVE_USER_GECOS LIVE_USER_GROUPS
  export LIVE_USER_PASSWORD_HASH LIVE_SESSION
}

load_project_config() {
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/project.env"
  export DIST_NAME DIST_ID DIST_CODENAME DIST_VERSION
  export DIST_HOME_URL DIST_SUPPORT_URL DIST_BUG_URL
  export DIST_ARCHIVE_KEY_FINGERPRINT PARENT_DISTRO BASE_CODENAME
  export DIST_UPDATES_URL DIST_UPDATES_REPOSITORY
}
