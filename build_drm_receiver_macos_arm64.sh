#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/JvanKatwijk/drm-receiver.git"
TESTED_COMMIT="${DRM_RECEIVER_COMMIT:-ca8e7e06bb88a200365f908b680735587165d669}"
SRC="${DRM_RECEIVER_SRC:-$HOME/drm-receiver}"
BUILD="$SRC/build-arm64"

log(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "macOS required."
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon arm64 required."
command -v brew >/dev/null 2>&1 || die "Homebrew is required."

log "Installing required Homebrew packages"
brew install git pkg-config qt qwt fftw libsamplerate libsndfile faad2 fdk-aac librtlsdr libusb portaudio eigen mpg123

QT="$(brew --prefix qt)"
QWT="$(brew --prefix qwt)"
FFTW="$(brew --prefix fftw)"
SAMPLERATE="$(brew --prefix libsamplerate)"
SNDFILE="$(brew --prefix libsndfile)"
FDK="$(brew --prefix fdk-aac)"
RTL="$(brew --prefix librtlsdr)"
USB="$(brew --prefix libusb)"
PORTAUDIO="$(brew --prefix portaudio)"
EIGEN="$(brew --prefix eigen)"
QWT_HEADERS="$QWT/lib/qwt.framework/Versions/6/Headers"
RTL_DYLIB="$RTL/lib/librtlsdr.dylib"

[[ -d "$QWT_HEADERS" ]] || die "Qwt framework headers not found."
[[ -f "$RTL_DYLIB" ]] || die "librtlsdr.dylib not found."

if [[ -d "$SRC/.git" ]]; then
  log "Using existing checkout at $SRC"
  git -C "$SRC" fetch --all --tags
else
  [[ ! -e "$SRC" ]] || die "$SRC exists but is not a Git checkout."
  log "Cloning upstream"
  git clone "$REPO_URL" "$SRC"
fi

if git -C "$SRC" diff --quiet && git -C "$SRC" diff --cached --quiet; then
  if git -C "$SRC" cat-file -e "${TESTED_COMMIT}^{commit}" 2>/dev/null; then
    log "Checking out tested upstream commit"
    git -C "$SRC" checkout --detach "$TESTED_COMMIT"
  fi
else
  log "Local changes detected; current checkout left untouched"
fi

log "Applying macOS compatibility edits"
python3 - "$SRC" "$RTL_DYLIB" <<'PY'
from pathlib import Path
import re, sys
src = Path(sys.argv[1])
rtl_dylib = sys.argv[2]

qwt = src/"scopes-qwt6"/"spectrum-scope.cpp"
if qwt.exists():
    s=qwt.read_text()
    qwt.write_text(re.sub(r'#include\s*<QwtText>', '#include <qwt_text.h>', s))

rtl = src/"devices"/"rtlsdr-handler"/"rtlsdr-handler.cpp"
s=rtl.read_text()
if rtl_dylib not in s:
    pat=r'Handle\s*=\s*dlopen\s*\(\s*"librtlsdr\.so"\s*,\s*RTLD_NOW\s*\)\s*;'
    repl=(
        '#if defined(__APPLE__)\\n'
        f'\\tHandle = dlopen ("{rtl_dylib}", RTLD_NOW);\\n'
        '#else\\n'
        '\\tHandle = dlopen ("librtlsdr.so", RTLD_NOW);\\n'
        '#endif'
    )
    s,n=re.subn(pat,repl,s,count=1)
    if n==0:
        raise SystemExit("Could not locate librtlsdr.so loader line.")
s=s.replace("Failed to open rtlsdr.dll","Failed to open RTL-SDR library")
rtl.write_text(s)

pro=src/"drm-receiver.pro"
p=pro.read_text()
marker="# --- macOS Apple Silicon / Homebrew compatibility ---"
if marker not in p:
    p += f"""

{marker}
macx {{
    LIBS -= -lfaad_drm
    LIBS -= -lqwt-qt6
    LIBS -= -lrt
    LIBS -= -ldl
    LIBS -= -L/usr/lib64
    LIBS -= -L/lib64
    LIBS += -framework qwt
}}
"""
    pro.write_text(p)
PY

mkdir -p "$BUILD"
rm -f "$BUILD/Makefile"
cd "$BUILD"

log "Running qmake"
"$QT/bin/qmake" ../drm-receiver.pro \
  QMAKE_CXXFLAGS+=" -I$QWT_HEADERS -I$FDK/include -I$RTL/include -I$PORTAUDIO/include -I$SNDFILE/include -I$SAMPLERATE/include -I$USB/include -I$FFTW/include -I$EIGEN/include/eigen3" \
  QMAKE_LFLAGS+=" -F$QWT/lib -L$FDK/lib -L$RTL/lib -L$PORTAUDIO/lib -L$SNDFILE/lib -L$SAMPLERATE/lib -L$USB/lib -L$FFTW/lib"

log "Building"
make -j1 2>&1 | tee "$HOME/drm-receiver-arm64-build.log"

log "Generated targets"
find "$BUILD" -maxdepth 7 \( -name "drm-receiver.app" -o -name "drm-receiver" \) -print

APP_BIN="$(find "$BUILD" -path '*/drm-receiver.app/Contents/MacOS/drm-receiver' -type f | head -1 || true)"
if [[ -n "$APP_BIN" ]]; then
  file "$APP_BIN"
  printf '\nLaunch with:\n%s\n' "$APP_BIN"
fi

cat <<EOF

Before selecting "dabstick", close SDR++, Gqrx, welle.io and rtl_test.
Optional hardware test:
  rtl_test -t

EOF
