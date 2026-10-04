# NebulaBuds

**Your Galaxy Buds, at home on macOS.**

[![CI](https://github.com/RiklloD/NebulaBuds/actions/workflows/ci.yml/badge.svg)](https://github.com/RiklloD/NebulaBuds/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

NebulaBuds is a native SwiftUI replacement for the Galaxy Wearable app, built for (and tested on) the
**Galaxy Buds4 Pro** (SM-R640, firmware R640XXU0AZD2). It talks straight to the Buds'
private Samsung control channel over Bluetooth RFCOMM.

## Features

| Page | What it does |
|---|---|
| Overview / menu bar | L / R / case battery, charging, in-ear state, one-click noise control. Launches at login into the menu bar (toggle in the menu bar popup); the Dock icon only shows while the window is open |
| Noise Control | Off / ANC / Ambient / Adaptive, ANC strength (5 levels), ambient level, custom ambient (per-ear level + tone), conversation detection, ANC with one earbud, touch-and-hold cycle per earbud |
| Sound | EQ presets, 9-band custom EQ (re-sent automatically after noise-control changes because the firmware forgets it), experimental Adaptive EQ requests with acknowledgement/timeout feedback, 360 Audio, L/R balance |
| Touch Controls | Lock touch, allow/deny each gesture (incl. during calls), touch-and-hold action per earbud |
| Head Tracking | Live 3D head from the earbuds' rotation sensor (~35 Hz), recenter |
| Find & Fit | Find my earbuds (with per-side mute), ear-tip fit test |
| Advanced | Seamless connection, sidetone, extra-clear calls, call audio switching, auto-pause, speak seamlessly |
| Diagnostics | Model/SKU, firmware, serials, case firmware + serial, MAC addresses, temperatures, fuel gauge, battery charge cycles |
| Protocol Inspector | Every frame in/out with names, hex/ASCII dump, raw sender, capture export |

## Build & run

```sh
./scripts/build-app.sh             # → build/NebulaBuds.app
./scripts/build-app.sh --install   # also copy to /Applications (Raycast, Spotlight, Launchpad)
open "build/NebulaBuds.app"
```

The build script currently produces an Apple Silicon (`arm64`) app.

Requires macOS 14+ and Xcode installed (the script uses Xcode's toolchain automatically;
SwiftUI's macros aren't in the Command Line Tools). The Buds must be paired in System Settings
first. On first launch macOS asks for Bluetooth permission.

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` runs protocol
tests against sanitized frames captured from a real Buds4 Pro and request-tracking
tests for experimental controls.
`BUDS_TRACE=1 "build/NebulaBuds.app/Contents/MacOS/GalaxyBuds"` prints every frame to stderr.

## Protocol notes (Buds4 Pro)

Reverse engineered by probing the device, cross-checked against
[GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient)'s research on older models.

### Transport

SDP advertises several Samsung RFCOMM services. The control channel is **GEARMANAGER**,
UUID `2e73a4ad-332d-41fc-90e2-16bef06523f2` (channel 27 on this unit — always resolve via SDP).
Others seen: SAMSUNGDEVICE, SPPSERVICE4, HEARINGAID, FACTORY, DEVICEID, BTIS.

### Framing

```
FD | hdr (u16 LE) | id | payload | crc16 (LE) | DD
hdr bits 0-9  = len(id + payload + crc)
hdr bit 12    = response · bit 13 = fragment · bits 14-15 = rolling sequence (bud → host)
crc           = CRC-16/XMODEM over id + payload
```

Host → bud frames need no sequence/flags. Every accepted setting is acknowledged with
`0x42 [cmd id, value…]`.

### Pushed by the buds on connect

`0x61` extended status · `0xCD` case firmware + serial · `0x68` firmware L/R · `0xC2` spatial events ·
`0x76` multipoint info · `0xF2` debug event log (prefixed `L`/`R`) · `0xF4` periodic stats blob ·
after `0x88` manager info: `0x21` per-bud stats. Later: `0x60` status (battery/wear/case), `0x41` metering.

### Extended status (0x61, revision 4, 62 bytes)

| Byte | Meaning |
|---|---|
| 0 | revision |
| 2 / 3 | battery L / R |
| 4 | buds coupled |
| 5 | primary bud (1 = left) |
| 6 | placement L (high nibble) / R (low): 1 in ear, 2 out, 3 in case, 4 case closed |
| 7 | case battery (0 = not reporting) |
| 9 | EQ (0 off, 1-5 presets, 6 custom) |
| 10 | touch lock bits: 0 hold, 1 triple, 2 double, 3 single, 4 double (call), 5 hold (call), 7 enabled |
| 11 | touch-and-hold action L / R nibble (1 assistant, 2 noise control, 3 volume, 4 Spotify) |
| 12 | noise control (0 off, 1 ANC, 2 ambient, 3 adaptive) |
| 14-15 | color id (359 black, 360 white, 361 apricot) |
| 19 | seamless connection (0 = on) |
| 21 | noise cycle L / R nibble: 1 ambient, 2 adaptive, 4 off, 8 ANC |
| 22 | speak seamlessly |
| 23 | ambient level (0-4) |
| 24 | ANC strength (0-4) |
| 25 | L/R balance (0-32, 16 = centre) |
| 26 / 27 | detect conversations / timeout (0 5 s, 1 10 s, 2 15 s) |
| 28 | noise controls with one earbud |
| 29-31 | custom ambient on / L·R levels nibble / tone |
| 33 | sidetone |
| 34 | call path control (0 = on) |
| 35 | 360 Audio |
| 41 | head tracking |
| 42 | charging bits: 4 L, 2 R, 0 case |
| 43 | extra-clear call |
| 45 | pause when one bud removed |
| 49 | adaptive volume |
| 52 / 53 | siren detect / adapt sound |
| 57-61 | new in Buds4 Pro, undecoded (byte 59 changes at runtime) |

### Commands verified on Buds4 Pro

| ID | Payload |
|---|---|
| `0x78` | noise control mode |
| `0x79` | `[cycle L, cycle R]` bitmasks as above |
| `0x7A` / `0x7B` | detect conversations / timeout |
| `0x7C` | 360 Audio |
| `0x7D` | speak seamlessly |
| `0x82` | custom ambient `[on, L, R, tone]` |
| `0x83` | ANC strength 0-4 |
| `0x84` | ambient level 0-4 |
| `0x86` | EQ preset (6 = custom) |
| `0x89` | custom EQ `[9, g1…g9]` (signed) |
| `0x8B` | sidetone |
| `0x8F` | L/R balance |
| `0x90` | touch lock `[enabled, tap, double, triple, hold, double-call, hold-call]` |
| `0x92` | touch-and-hold action `[L, R]` |
| `0x6C` | pause when one bud removed |
| `0x6E` / `0xAF` | call path control / seamless connection (both inverted: 0 = on) |
| `0x6F` | noise controls with one earbud |
| `0x48` | extra-clear call |
| `0x9D` | fit test start (1) / stop (0) → result `0x9E [L, R]` (1 good, 0 bad, 2 failed) |
| `0xA0` / `0xA1` / `0xA2` | find start / stop / mute `[L, R]` |
| `0xC3` | spatial sensor: 0 attach, 1 detach, 4 keep-alive (every 2 s) |

No acknowledgement (probably unsupported or silent): `0xC5` adaptive volume, `0x96` extra-high ambient, `0x97` voice wake-up.

### Experimental Adaptive EQ controls

The Sound page offers Enable / Disable requests for Buds4 Pro only (SKU prefix
`SM-R640`). The candidate command is `0xDA` (`ADAPTIVE_EQ_CONTROL`) with a single
boolean byte (`1` / `0`), inferred from the protocol's setting convention. **The
payload and its effect are not hardware-verified.** The app sends this command
only when the user presses a button; it is never applied at startup or reconnect.

Only an exact `0x42 [0xDA, requested value]` response counts as an acknowledgement.
Controls wait up to five seconds and report send failures or missing acknowledgements.
Acknowledgement means the request was echoed, not that Adaptive EQ is confirmed
enabled or disabled. The `0xDB` (`ADAPTIVE_EQ_STATUS`) layout and any interaction
with custom EQ remain unknown, so the app does not infer an active setting from
it, the Adapt Sound flag, or undecoded extended-status bytes. Request feedback
is cleared on disconnect/reconnect. Tests exercise candidate encoding and request
tracking, not device functionality.

### Read requests

| ID | Response |
|---|---|
| `0x26` | debug data (answered twice, first with only the primary bud's sensors): hw rev, 20-char firmware, MACs, proximity, temperature ÷10 °C @55/57, fuel gauge @59/65 |
| `0x29` | serial L / R (11 chars each) |
| `0x22` | SKU (`SM-R640NZKAEUC`), twice |
| `0xCE` | charge cycles: two u64 **big endian** ÷ 10000 |
| `0x69` | EQ table: `[active preset, band count, 6 × 9 signed gains]`: bass boost, soft, dynamic, clear, treble boost, **custom** |
| `0x76` | multipoint info |
| `0xC2` event `0x20` | head pose: 4 × int16 LE ÷ 10000 quaternion + 28 undecoded bytes (likely raw IMU) |

### ⚠️ Security finding

`0xD4` (`UNK_DUMP_BONDED_DEVICES`) makes the Buds send, **unauthenticated and in plaintext**, the BR/EDR link
keys and LE LTKs of every device they have ever been paired with, over `0xD6` text frames. Any host that can open
the SPP channel (i.e. anything the Buds are connected to) can read them. The app never sends it and the raw sender
blocks it.


## Contributing

Bug reports, protocol research, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for build instructions and guidance on sharing device captures.

## License

[MIT](LICENSE) © 2026 Lorik Dalloshi.

NebulaBuds is an independent project and is not affiliated with Samsung.
Samsung and Galaxy Buds are trademarks of their respective owners.
