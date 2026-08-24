# macOS compatibility changes

The helper applies the tested changes programmatically rather than shipping a modified upstream source tree.

## Qwt include

```diff
-#include <QwtText>
+#include <qwt_text.h>
```

## RTL-SDR dynamic library

Conceptually:

```diff
 #ifdef _WIN32
     Handle = LoadLibrary((wchar_t *)L"rtlsdr.dll");
 #else
+#if defined(__APPLE__)
+    Handle = dlopen("<brew --prefix librtlsdr>/lib/librtlsdr.dylib", RTLD_NOW);
+#else
     Handle = dlopen("librtlsdr.so", RTLD_NOW);
 #endif
+#endif
```

The helper substitutes the actual Homebrew path on the Mac performing the
build. This supports native Homebrew on Apple Silicon and Intel without a fixed
`/opt/homebrew` assumption. For an upstream-quality source patch, a runtime
library-name search strategy would still be preferable to any build-time
absolute path.

## Linker cleanup

On macOS the tested build removed:

```text
-lfaad_drm
-lqwt-qt6
-lrt
-ldl
-L/usr/lib64
-L/lib64
```

and linked Qwt as a framework.
