# Contributing to NebulaBuds

Requires macOS 14 or later and Xcode. Pair your earbuds in System Settings before
running the app. The current app bundle script targets Apple Silicon.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build-app.sh
open "build/NebulaBuds.app"
```

For bug reports, include your macOS version, earbud model, firmware version,
steps to reproduce, and expected versus actual behavior. Buds4 Pro is the only
hardware-tested model so far.

Keep protocol changes focused and add tests for decoding or request handling.
Distinguish hardware captures from constructed test cases, and label inferred
commands as experimental until verified on the target model and firmware.

Protocol Inspector captures can contain device identifiers and other private
data. Remove serial numbers, Bluetooth addresses, and any pairing keys before
sharing them in issues or pull requests. Never publish credentials or pairing keys.
