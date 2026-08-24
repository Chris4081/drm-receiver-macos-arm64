# drm-receiver on macOS Apple Silicon (ARM64)

> **Unofficial community port/build guide**

Native macOS ARM64 build notes and helper script for running
[`JvanKatwijk/drm-receiver`](https://github.com/JvanKatwijk/drm-receiver)
on Apple Silicon Macs with an RTL-SDR Blog V4.

## Verified result

This procedure was developed and tested on an **Apple M4 Mac** with native ARM64 Homebrew libraries.

The resulting application:

- built as **ARM64 native** (`translated: false`)
- launched successfully with Qt 6 / Qwt
- loaded `librtlsdr.dylib` on macOS
- detected an **RTL-SDR Blog V4 / R828D**
- received HF through the RTL-SDR path
- achieved real DRM synchronization
- identified **BBC World Service**
- identified **QAM16 / xHE-AAC**
- produced brief decoded BBC audio during a marginal-signal reception test

A representative successful decoder state showed **time sync** and **FAC sync** green and the service label **BBC World Service**. Audio was decoded briefly when signal quality became sufficient.

This is a real-world functionality test, not merely a successful compilation claim.

## Important scope note

`drm-receiver` is an upstream GPL-2.0 project. This repository does **not** relicense it and does not claim official macOS support.

The helper script clones upstream source, applies a small set of macOS compatibility edits locally, and builds it against native Homebrew ARM64 libraries.

## Tested environment

```text
Hardware:       Apple Silicon M4
Architecture:   arm64
macOS:          26.5.2
Qt:             6.11.1
Qwt:            6.3.0
FDK-AAC:        2.0.3
librtlsdr:      2.0.3
Homebrew:       native ARM64 (/opt/homebrew)
```

Upstream commit used during the successful porting session:

```text
ca8e7e06bb88a200365f908b680735587165d669
```

## Quick build

```bash
chmod +x build_drm_receiver_macos_arm64.sh
./build_drm_receiver_macos_arm64.sh
```

By default the helper uses:

```text
~/drm-receiver
```

To use another source directory:

```bash
DRM_RECEIVER_SRC="$HOME/src/drm-receiver" ./build_drm_receiver_macos_arm64.sh
```

The helper intentionally does **not** use `sudo`.

## What the helper changes

The tested upstream source was strongly Linux-oriented in a few places. The helper applies these local compatibility fixes:

1. Adds native Homebrew include/library paths for Qt 6, Qwt, libsndfile, libsamplerate, PortAudio, libusb, FFTW, Eigen, FDK-AAC and librtlsdr.
2. Changes `#include <QwtText>` to `#include <qwt_text.h>` for Homebrew Qwt.
3. Removes Linux-oriented linker assumptions such as `-lfaad_drm`, `-lqwt-qt6`, `-lrt`, `-ldl`, `-L/usr/lib64` and `-L/lib64` on macOS.
4. Links Qwt as a macOS framework.
5. Adds a macOS RTL-SDR runtime loader for `/opt/homebrew/opt/librtlsdr/lib/librtlsdr.dylib`.

## Build output

Find the generated app with:

```bash
find ~/drm-receiver/build-arm64 -maxdepth 7 \
  \( -name "drm-receiver.app" -o -name "drm-receiver" \) -print
```

A path observed during testing was:

```text
~/drm-receiver/build-arm64/linux-bin/drm-receiver.app
```

Launch from Terminal for diagnostics:

```bash
~/drm-receiver/build-arm64/linux-bin/drm-receiver.app/Contents/MacOS/drm-receiver
```

## RTL-SDR Blog V4 notes

Before selecting the `dabstick` backend, close SDR++, Gqrx, welle.io, `rtl_test`, or any other program that may already own the SDR.

A busy device may produce:

```text
usb_claim_interface error -3
Opening dabstick failed
```

Verify the stick independently with:

```bash
rtl_test -t
```

A working Blog V4 should report:

```text
Found Rafael Micro R828D tuner
RTL-SDR Blog V4 Detected
```

Stop `rtl_test` before opening `drm-receiver`.

## HF / DRM reception

For shortwave DRM, the tested receiver exposed a **direct sampling** option in the RTL-SDR control window.

A real DRM lock progresses through:

```text
time sync
FAC sync
SDC sync
aac Sync
```

During the verified BBC test, the decoder displayed:

```text
BBC WS
BBC World Service
QAM16
xHE-AAC
```

and produced brief decoded audio.

Weak DRM can show green time/FAC sync while SDC/AAC remain intermittent.

## Troubleshooting

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Patch documentation

See [`patches/README.md`](patches/README.md).

## Licensing

This repository uses **GNU GPL version 2** for compatibility with the upstream project.

`drm-receiver` itself remains copyright its upstream authors/contributors and remains governed by its upstream **GPL-2.0** terms.

This is an unofficial community project and is not affiliated with or endorsed by the upstream maintainer. Third-party dependencies remain governed by their own licenses.

## Status

```text
Native ARM64 build       VERIFIED
Qt GUI                    VERIFIED
RTL-SDR Blog V4           VERIFIED
HF input                  VERIFIED
DRM time/FAC sync         VERIFIED
BBC World Service ID      VERIFIED
xHE-AAC identification    VERIFIED
Decoded audio             VERIFIED BRIEFLY
Long-term stable decode   NOT YET CLAIMED
```
