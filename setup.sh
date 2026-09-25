#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASEPRITE_DIR="${ASEPRITE_DIR:-${HOME}/.local/share/aseprite}"

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--with-aseprite]

Installs the repository dependencies:
  default           Flutter packages and repository validation
  --with-aseprite   also clone the official free Aseprite source repo and print
                    the exact build commands for Linux/WSL or Windows toolchains

The script does not install system SDKs. Install Flutter before running it.
Aseprite source builds require Git, CMake, and a C++ toolchain; the script only
prepares the repo and prints the build steps.
EOF
}

log() {
  printf '\n==> %s\n' "$1"
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

WITH_ASEPRITE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-aseprite)
      WITH_ASEPRITE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown option: $1"
      ;;
  esac
  shift
done

command -v flutter >/dev/null 2>&1 || die "Flutter is required and must be on PATH."

log "Installing Flutter dependencies"
(cd "${ROOT_DIR}/app" && flutter pub get)

if command -v git >/dev/null 2>&1; then
  log "Installing repository architecture hook"
  git -C "${ROOT_DIR}" config core.hooksPath .githooks
fi

if [[ "${WITH_ASEPRITE}" == "1" ]]; then
  command -v git >/dev/null 2>&1 || die "git is required for --with-aseprite."

  log "Preparing Aseprite source"
  mkdir -p "$(dirname "${ASEPRITE_DIR}")"
  if [[ ! -d "${ASEPRITE_DIR}/.git" ]]; then
    git clone --depth 1 https://github.com/aseprite/aseprite.git "${ASEPRITE_DIR}"
  else
    git -C "${ASEPRITE_DIR}" pull --ff-only
  fi

  printf '\nAseprite source is available at: %s\n' "${ASEPRITE_DIR}"
  printf 'To build it on Linux/WSL, install the prerequisites first and then run:\n'
  printf '  cd "%s"\n' "${ASEPRITE_DIR}"
  printf '  cmake -S . -B build -G Ninja\n'
  printf '  cmake --build build -j$(nproc)\n'
  printf 'For Windows/MSVC builds, use the official Aseprite build instructions with Visual Studio and CMake.\n'
fi

cat <<EOF

Setup complete.
Flutter: app/.dart_tool
Run Flutter checks with: cd app && flutter test
EOF

if [[ "${WITH_ASEPRITE}" == "1" ]]; then
  printf '\nFree source build path for Aseprite: git clone https://github.com/aseprite/aseprite.git %s\n' "${ASEPRITE_DIR}"
fi