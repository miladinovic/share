#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/vash909/WSJT-CB.git"
REPO_DIR="${HOME}/WSJT-CB"
BRANCH="main"
BUILD_DIR="${REPO_DIR}/build"
INSTALL_PREFIX="/usr/local"
APP_NAME="wsjtcb"

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*"
}

fail() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

on_error() {
  local exit_code=$?
  printf '\n[ERROR] Build script failed at line %s with exit code %s\n' "$1" "$exit_code" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

if [ "$(id -u)" -eq 0 ]; then
  fail "Do not run this script as root. Run it as your normal user; sudo will be used when needed."
fi

SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  fail "sudo is required on Raspberry Pi OS but was not found."
fi

JOBS="1"

log "Checking system details"
require_cmd bash
require_cmd apt

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
KERNEL="$(uname -r)"
HOSTNAME_NOW="$(hostname)"
printf 'User: %s\nHost: %s\nArch: %s\nKernel: %s\nJobs: %s\n' "$USER" "$HOSTNAME_NOW" "$ARCH" "$KERNEL" "$JOBS"

log "Refreshing package lists"
$SUDO apt update

log "Installing required build tools and libraries"
$SUDO apt install -y \
  git \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  gfortran \
  qtbase5-dev \
  qttools5-dev \
  qttools5-dev-tools \
  qtmultimedia5-dev \
  libqt5websockets5-dev \
  libqt5serialport5-dev \
  libfftw3-dev \
  libhamlib-dev \
  libudev-dev \
  libboost-all-dev \
  dpkg-dev \
  fakeroot \
  file

log "Verifying installed dependencies"
require_cmd git
require_cmd cmake
require_cmd ninja
require_cmd pkg-config
require_cmd gfortran

pkg-config --exists Qt5Core || fail "Qt5Core development files not found"
pkg-config --exists Qt5Widgets || fail "Qt5Widgets development files not found"
pkg-config --exists Qt5Network || fail "Qt5Network development files not found"
pkg-config --exists Qt5Multimedia || fail "Qt5Multimedia development files not found"
pkg-config --exists fftw3 || fail "fftw3 development files not found"
pkg-config --exists hamlib || fail "hamlib development files not found"
pkg-config --exists libudev || fail "libudev development files not found"

log "Cloning or updating source repository"
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
else
  printf 'Repository already exists at %s\n' "$REPO_DIR"
fi

cd "$REPO_DIR"

CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
  warn "Origin URL differs from expected repository. Setting origin to $REPO_URL"
  git remote set-url origin "$REPO_URL"
fi

git fetch --all --tags --prune
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH" || warn "Fast-forward pull was not possible; continuing with checked out branch state"

log "Preparing build directory"
mkdir -p "$BUILD_DIR"
rm -f "$BUILD_DIR"/*.deb

log "Configuring project with CMake"
cmake -S . -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DWSJT_SKIP_MANPAGES=ON \
  -DWSJT_GENERATE_DOCS=OFF \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

log "Compiling project"
cmake --build "$BUILD_DIR" --parallel "$JOBS"

log "Building .deb package"
DEB_FILE=""
if command -v cpack >/dev/null 2>&1; then
  (
    cd "$BUILD_DIR"
    cpack -G DEB
  )
  DEB_FILE="$(find "$BUILD_DIR" -maxdepth 2 -type f -name '*.deb' | head -n 1 || true)"
  if [ -n "$DEB_FILE" ]; then
    printf 'DEB package: %s\n' "$DEB_FILE"
  else
    warn "cpack ran, but no .deb file was found. The project may be missing CPack packaging rules."
  fi
else
  warn "cpack command not found, skipping .deb packaging step."
fi

log "Checking build outputs"
BIN_CANDIDATE_1="$BUILD_DIR/$APP_NAME"
BIN_CANDIDATE_2="$BUILD_DIR/bin/$APP_NAME"
FOUND_BIN=""

if [ -x "$BIN_CANDIDATE_1" ]; then
  FOUND_BIN="$BIN_CANDIDATE_1"
elif [ -x "$BIN_CANDIDATE_2" ]; then
  FOUND_BIN="$BIN_CANDIDATE_2"
else
  FOUND_BIN="$(find "$BUILD_DIR" -type f -name "$APP_NAME" -perm -111 | head -n 1 || true)"
fi

if [ -z "$FOUND_BIN" ]; then
  warn "Compiled binary named $APP_NAME was not found automatically."
  find "$BUILD_DIR" -maxdepth 3 -type f | sort
  fail "Build completed but executable discovery failed"
fi

printf 'Built executable: %s\n' "$FOUND_BIN"

log "Installing application"
$SUDO cmake --install "$BUILD_DIR"

log "Checking installed application"
INSTALLED_PATH="$(command -v "$APP_NAME" || true)"
if [ -n "$INSTALLED_PATH" ]; then
  printf 'Installed command found at: %s\n' "$INSTALLED_PATH"
else
  if [ -x "$INSTALL_PREFIX/bin/$APP_NAME" ]; then
    INSTALLED_PATH="$INSTALL_PREFIX/bin/$APP_NAME"
    printf 'Installed binary found at: %s\n' "$INSTALLED_PATH"
  else
    warn "Installed command is not on PATH yet."
  fi
fi

log "Done"
printf 'Repository: %s\n' "$REPO_DIR"
printf 'Build dir:   %s\n' "$BUILD_DIR"
printf 'Binary:      %s\n' "$FOUND_BIN"
if [ -n "${DEB_FILE:-}" ]; then
  printf 'DEB:         %s\n' "$DEB_FILE"
fi
if [ -n "${INSTALLED_PATH:-}" ]; then
  printf 'Installed:   %s\n' "$INSTALLED_PATH"
fi
printf '\nYou can try running:\n'
printf '  %s\n' "${INSTALLED_PATH:-$FOUND_BIN}"
if [ -n "${DEB_FILE:-}" ]; then
  printf '\nTo install the package later:\n'
  printf '  sudo apt install ./%s\n' "$(basename "$DEB_FILE")"
fi