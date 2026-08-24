#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/JvanKatwijk/drm-receiver.git"
TESTED_COMMIT="${DRM_RECEIVER_COMMIT:-ca8e7e06bb88a200365f908b680735587165d669}"
SRC="${DRM_RECEIVER_SRC:-$HOME/drm-receiver}"
HOST_ARCH="$(uname -m)"
BUILD="${DRM_RECEIVER_BUILD_DIR:-$SRC/build-$HOST_ARCH}"
BUILD_JOBS="${DRM_RECEIVER_BUILD_JOBS:-1}"

log(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "macOS required."
case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *) die "Unsupported Mac architecture: $HOST_ARCH" ;;
esac
command -v brew >/dev/null 2>&1 || die "Homebrew is required: https://brew.sh"
command -v python3 >/dev/null 2>&1 || die "python3 is required."
[[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]] || die "DRM_RECEIVER_BUILD_JOBS must be a positive integer."

BREW="$(command -v brew)"
BREW_PREFIX="$($BREW --prefix)"
case "$HOST_ARCH:$BREW_PREFIX" in
  arm64:/usr/local*)
    die "This arm64 shell is using an Intel/Rosetta Homebrew at $BREW_PREFIX. Use native ARM Homebrew."
    ;;
  x86_64:/opt/homebrew*)
    die "This x86_64 shell is using Apple Silicon Homebrew at $BREW_PREFIX. Use a native Intel Homebrew shell."
    ;;
esac

log "Installing required Homebrew packages for $HOST_ARCH"
"$BREW" install git pkg-config qt qwt fftw libsamplerate libsndfile faad2 fdk-aac librtlsdr libusb portaudio eigen mpg123

QT="$($BREW --prefix qt)"
QWT="$($BREW --prefix qwt)"
FFTW="$($BREW --prefix fftw)"
SAMPLERATE="$($BREW --prefix libsamplerate)"
SNDFILE="$($BREW --prefix libsndfile)"
FDK="$($BREW --prefix fdk-aac)"
RTL="$($BREW --prefix librtlsdr)"
USB="$($BREW --prefix libusb)"
PORTAUDIO="$($BREW --prefix portaudio)"
EIGEN="$($BREW --prefix eigen)"
RTL_DYLIB="$RTL/lib/librtlsdr.dylib"

QWT_HEADERS=""
for candidate in \
  "$QWT/lib/qwt.framework/Headers" \
  "$QWT/lib/qwt.framework/Versions/Current/Headers" \
  "$QWT/lib/qwt.framework/Versions/6/Headers" \
  "$QWT/include/qwt" \
  "$QWT/include"
do
  if [[ -f "$candidate/qwt_plot.h" ]]; then
    QWT_HEADERS="$candidate"
    break
  fi
done

[[ -n "$QWT_HEADERS" ]] || die "Qwt headers not found below $QWT."
[[ -d "$QWT/lib/qwt.framework" ]] || die "The installed Qwt package does not provide qwt.framework."
[[ -f "$RTL_DYLIB" ]] || die "librtlsdr.dylib not found at $RTL_DYLIB."
[[ -x "$QT/bin/qmake" ]] || die "Qt qmake not found at $QT/bin/qmake."

if [[ -d "$SRC/.git" ]]; then
  log "Using existing checkout at $SRC"
  git -C "$SRC" fetch --all --tags
else
  [[ ! -e "$SRC" ]] || die "$SRC exists but is not a Git checkout."
  log "Cloning upstream"
  git clone "$REPO_URL" "$SRC"
fi

if git -C "$SRC" diff --quiet && git -C "$SRC" diff --cached --quiet; then
  git -C "$SRC" cat-file -e "${TESTED_COMMIT}^{commit}" 2>/dev/null \
    || die "Tested commit $TESTED_COMMIT is unavailable."
  log "Checking out tested upstream commit"
  git -C "$SRC" checkout --detach "$TESTED_COMMIT"
else
  log "Local tracked changes detected; current checkout left untouched"
fi

log "Applying macOS compatibility edits"
python3 - "$SRC" "$RTL_DYLIB" <<'PY'
from pathlib import Path
import re
import sys

src = Path(sys.argv[1])
rtl_dylib = sys.argv[2]

qwt = src / "scopes-qwt6" / "spectrum-scope.cpp"
if not qwt.is_file():
    raise SystemExit(f"Missing upstream file: {qwt}")
s = qwt.read_text()
s, count = re.subn(r'#include\s*<QwtText>', '#include <qwt_text.h>', s)
if count == 0 and '#include <qwt_text.h>' not in s:
    raise SystemExit("Could not locate the QwtText include.")
qwt.write_text(s)

rtl = src / "devices" / "rtlsdr-handler" / "rtlsdr-handler.cpp"
if not rtl.is_file():
    raise SystemExit(f"Missing upstream file: {rtl}")
s = rtl.read_text()
escaped_rtl_dylib = rtl_dylib.replace('\\', '\\\\').replace('"', '\\"')
apple_block = (
    '#if defined(__APPLE__)\n'
    f'\tHandle = dlopen ("{escaped_rtl_dylib}", RTLD_NOW);\n'
    '#else\n'
    '\tHandle = dlopen ("librtlsdr.so", RTLD_NOW);\n'
    '#endif'
)
existing_apple = re.compile(
    r'#if defined\(__APPLE__\)\s*\n'
    r'\s*Handle\s*=\s*dlopen\s*\([^\n]+RTLD_NOW\s*\);\s*\n'
    r'#else\s*\n'
    r'\s*Handle\s*=\s*dlopen\s*\(\s*"librtlsdr\.so"\s*,\s*RTLD_NOW\s*\);\s*\n'
    r'#endif'
)
if existing_apple.search(s):
    s = existing_apple.sub(lambda _: apple_block, s, count=1)
else:
    linux_loader = re.compile(
        r'Handle\s*=\s*dlopen\s*\(\s*"librtlsdr\.so"\s*,\s*RTLD_NOW\s*\)\s*;'
    )
    s, count = linux_loader.subn(lambda _: apple_block, s, count=1)
    if count == 0:
        raise SystemExit("Could not locate the RTL-SDR library loader.")
s = s.replace("Failed to open rtlsdr.dll", "Failed to open RTL-SDR library")
rtl.write_text(s)

pro = src / "drm-receiver.pro"
if not pro.is_file():
    raise SystemExit(f"Missing upstream file: {pro}")
p = pro.read_text()
marker = "# --- macOS / Homebrew compatibility ---"
old_marker = "# --- macOS Apple Silicon / Homebrew compatibility ---"
block = f'''\n\n{marker}
macx {{
    LIBS -= -lfaad_drm
    LIBS -= -lqwt-qt6
    LIBS -= -lrt
    LIBS -= -ldl
    LIBS -= -L/usr/lib64
    LIBS -= -L/lib64
    LIBS += -framework qwt
}}
'''
if old_marker in p:
    p = p[:p.index(old_marker)].rstrip() + block
elif marker not in p:
    p = p.rstrip() + block
pro.write_text(p)
PY

mkdir -p "$BUILD"
rm -f "$BUILD/Makefile"
cd "$BUILD"

DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-$(sw_vers -productVersion | awk -F. '{print $1 "." $2}')}"

log "Running qmake for $HOST_ARCH (deployment target $DEPLOYMENT_TARGET)"
"$QT/bin/qmake" "$SRC/drm-receiver.pro" \
  QMAKE_APPLE_DEVICE_ARCHS="$HOST_ARCH" \
  QMAKE_MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
  QMAKE_CXXFLAGS+=" -I$QWT_HEADERS -I$FDK/include -I$RTL/include -I$PORTAUDIO/include -I$SNDFILE/include -I$SAMPLERATE/include -I$USB/include -I$FFTW/include -I$EIGEN/include/eigen3" \
  QMAKE_LFLAGS+=" -F$QWT/lib -L$FDK/lib -L$RTL/lib -L$PORTAUDIO/lib -L$SNDFILE/lib -L$SAMPLERATE/lib -L$USB/lib -L$FFTW/lib"

LOG_FILE="${DRM_RECEIVER_BUILD_LOG:-$HOME/drm-receiver-$HOST_ARCH-build.log}"
log "Building with $BUILD_JOBS job(s)"
make -j"$BUILD_JOBS" 2>&1 | tee "$LOG_FILE"

log "Generated targets"
find "$BUILD" -maxdepth 7 \( -name "drm-receiver.app" -o -name "drm-receiver" \) -print

APP_BIN="$(find "$BUILD" -path '*/drm-receiver.app/Contents/MacOS/drm-receiver' -type f | head -1 || true)"
if [[ -z "$APP_BIN" ]]; then
  die "Build completed without producing the expected executable. See $LOG_FILE"
fi

ACTUAL_ARCHS="$(lipo -archs "$APP_BIN")"
case " $ACTUAL_ARCHS " in
  *" $HOST_ARCH "*) ;;
  *) die "Built executable does not contain $HOST_ARCH: $ACTUAL_ARCHS" ;;
esac

file "$APP_BIN"
printf '\nLaunch with:\n%s\n' "$APP_BIN"

cat <<EOF

Before selecting "dabstick", close SDR++, Gqrx, welle.io and rtl_test.
Optional hardware test:
  rtl_test -t

This is a machine-local build. Homebrew libraries are not bundled.
EOF
