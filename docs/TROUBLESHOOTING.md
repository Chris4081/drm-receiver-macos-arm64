# Troubleshooting

## Wrong Homebrew architecture

The generic helper requires Homebrew libraries matching the process
architecture. On Apple Silicon, run the build from a native arm64 Terminal and
use native Homebrew (normally `/opt/homebrew`). On an Intel Mac, use native
x86_64 Homebrew (normally `/usr/local`).

Check both values with:

```bash
uname -m
brew --prefix
```

Do not mix an arm64 compiler with Intel libraries, or an Intel/Rosetta shell
with arm64 libraries.

## `sndfile.h` not found

```bash
brew install libsndfile
```

The build helper adds the Homebrew include path.

## `qwt_plot.h` not found

Homebrew Qwt was installed as a framework in the tested setup. The helper
searches the framework's standard `Headers` and `Versions/*/Headers` layouts.
One common result is:

```text
$(brew --prefix qwt)/lib/qwt.framework/Headers
```

## `QwtText` not found

The tested source used:

```cpp
#include <QwtText>
```

Homebrew Qwt exposed:

```cpp
#include <qwt_text.h>
```

The helper patches this automatically.

## `Eigen/Dense` not found

```bash
brew install eigen
```

The helper adds `$(brew --prefix eigen)/include/eigen3`.

## `ld: library 'faad_drm' not found`

The successful macOS build used FDK-AAC. The helper removes the Linux-oriented `-lfaad_drm` link flag on macOS.

## Qwt link failure / `-lqwt-qt6`

The tested Homebrew Qwt installation is a macOS framework. The build uses:

```text
-F$(brew --prefix qwt)/lib
-framework qwt
```

## Selecting `dabstick` crashes

The original runtime path attempted non-macOS RTL-SDR library names. The helper adds a macOS `librtlsdr.dylib` loader.

The original crash report showed `EXC_BAD_ACCESS` in `RadioInterface::setDevice()` after backend initialization failed. The helper now obtains the library path from `brew --prefix librtlsdr` instead of assuming the Apple Silicon Homebrew prefix.

## Build succeeds but the result does not run on another Mac

This project produces a machine-local build. It deliberately does not bundle
Qt, Qwt or the Homebrew dynamic libraries. Run the helper separately on the
other Mac so it links against that machine's native dependencies. Creating one
copyable app for Macs without those dependencies is a separate packaging,
signing and notarization task.

## `usb_claim_interface error -3`

Another application probably owns the RTL-SDR.

Close SDR++, Gqrx, welle.io and `rtl_test`, then unplug/replug the stick if necessary.

## All DRM sync indicators remain red

Check the current broadcast schedule, UTC time, exact frequency, antenna, signal quality and HF/direct-sampling settings.

## Time/FAC green but no audio

This can be normal with marginal DRM reception. SDC and AAC may require better signal quality. In the verified BBC test, BBC World Service and xHE-AAC were identified before audio appeared briefly.
