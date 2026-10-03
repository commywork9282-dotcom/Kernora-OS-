#!/usr/bin/env bash

# shellcheck source=common.sh
source "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

configure_project_apt() {
  load_upstream_config

  APT_STATE="$PROJECT_ROOT/_state/apt"
  APT_CACHE="$PROJECT_ROOT/_cache/apt"
  DEBIAN_KEYRING="$PROJECT_ROOT/_state/trust/debian-trixie-archive-keyring.gpg"
  APT_SOURCES="$APT_STATE/debian.sources"

  [[ -s "$DEBIAN_KEYRING" ]] || die "Debian keyring is missing; run scripts/bootstrap-debian-keyring"

  mkdir -p "$APT_STATE/lists/partial" "$APT_CACHE/archives/partial"
  : > "$APT_STATE/status"

  sed \
    -e "s|@DEBIAN_SNAPSHOT@|$DEBIAN_SNAPSHOT|g" \
    -e "s|@DEBIAN_SECURITY_SNAPSHOT@|$DEBIAN_SECURITY_SNAPSHOT|g" \
    -e "s|@SNAPSHOT_TIMESTAMP@|$SNAPSHOT_TIMESTAMP|g" \
    -e "s|@BASE_CODENAME@|$BASE_CODENAME|g" \
    -e "s|@BASE_ARCH@|$BASE_ARCH|g" \
    -e "s|@DEBIAN_KEYRING@|$DEBIAN_KEYRING|g" \
    "$PROJECT_ROOT/configs/upstream/debian.sources.in" > "$APT_SOURCES"

  APT_OPTIONS=(
    -o "Dir::Etc::sourcelist=$APT_SOURCES"
    -o "Dir::Etc::sourceparts=-"
    -o "Dir::Etc::trusted=/dev/null"
    -o "Dir::Etc::trustedparts=-"
    -o "Dir::State::Lists=$APT_STATE/lists"
    -o "Dir::State::status=$APT_STATE/status"
    -o "Dir::Cache::Archives=$APT_CACHE/archives"
    -o "Dir::Cache::pkgcache=$APT_STATE/pkgcache.bin"
    -o "Dir::Cache::srcpkgcache=$APT_STATE/srcpkgcache.bin"
    -o "APT::Architecture=$BASE_ARCH"
    -o "Acquire::Languages=none"
    -o "APT::Get::List-Cleanup=0"
  )

  export APT_STATE APT_CACHE DEBIAN_KEYRING APT_SOURCES
}

