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
+    Handle = dlopen("/opt/homebrew/opt/librtlsdr/lib/librtlsdr.dylib", RTLD_NOW);
+#else
     Handle = dlopen("librtlsdr.so", RTLD_NOW);
 #endif
+#endif
```

For an upstream-quality patch, a library-name search strategy would be preferable to a hardcoded Homebrew path.

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
