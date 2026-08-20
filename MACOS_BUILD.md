# Building the self-contained macOS app

The game uses x86-64 NASM. Consequently, the distributable is an `x86_64`
application: it runs natively on Intel Macs and through Rosetta 2 on Apple
Silicon Macs. A true universal (`arm64` + `x86_64`) executable is not possible
until the assembly implementation is ported to arm64.

The default deployment target is macOS 14 because the current Homebrew builds
of the SDL_ttf dependencies require it. Building for an older macOS release
also requires dependency libraries compiled against that older SDK.

From a macOS terminal with CMake, NASM, and the Xcode Command Line Tools:

```sh
cmake -S . -B build-macos -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DSNAKE_USE_VENDORED_TTF_DEPS=OFF
cmake --build build-macos --target publish
```

The result is `build-macos/dist/SnakeGame.app`. The publishing target copies
all non-system dynamic libraries into `Contents/Frameworks`, rewrites their
install names, validates the x86-64 architecture, and applies an ad-hoc code
signature. The `.app` can then be zipped for transfer:

```sh
ditto -c -k --sequesterRsrc --keepParent \
  build-macos/dist/SnakeGame.app build-macos/dist/SnakeGame-macOS.zip
```

For public Internet distribution without Gatekeeper warnings, replace the
ad-hoc signature with an Apple Developer ID signature and notarize the zip.
That requires the distributor's paid Apple Developer credentials; it is not a
library/runtime requirement for the recipient.
