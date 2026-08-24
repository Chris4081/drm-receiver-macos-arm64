# Troubleshooting

## `sndfile.h` not found

```bash
brew install libsndfile
```

The build helper adds the Homebrew include path.

## `qwt_plot.h` not found

Homebrew Qwt was installed as a framework in the tested setup. The helper uses:

```text
$(brew --prefix qwt)/lib/qwt.framework/Versions/6/Headers
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

The original crash report showed `EXC_BAD_ACCESS` in `RadioInterface::setDevice()` after backend initialization failed.

## `usb_claim_interface error -3`

Another application probably owns the RTL-SDR.

Close SDR++, Gqrx, welle.io and `rtl_test`, then unplug/replug the stick if necessary.

## All DRM sync indicators remain red

Check the current broadcast schedule, UTC time, exact frequency, antenna, signal quality and HF/direct-sampling settings.

## Time/FAC green but no audio

This can be normal with marginal DRM reception. SDC and AAC may require better signal quality. In the verified BBC test, BBC World Service and xHE-AAC were identified before audio appeared briefly.
