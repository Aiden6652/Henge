# Changelog

This fork collects the fixes from the community forks of [Leviidev/Henge](https://github.com/Leviidev/Henge)
into one build, with a few additions, aimed above all at iPad (tested hardware: iPad Pro M4).
Every change keeps its original author in the git history.

## Unreleased — older macOS, Chinese input, Simplified Chinese UI

### Older macOS (for 8 GB iPads)
- The install list is no longer a hard-coded limit. `MacOSRelease.builtIn` now offers
  **macOS Ventura 13.0 (22A380)** and **macOS Sonoma 14.6.1 (23G93)** alongside
  Sequoia, Tahoe and 27, with their real Apple CDN URLs and sizes. Ventura is a 12 GB
  download (Sequoia is 16 GB), and every release has its own `reserveGB`, so the free
  space check asks for 16/18 GB instead of a flat 24 GB.
- Sonoma 14.6.1 is the image `BootROM.swift` already takes AVPBooter from, so ROM and
  restore OS match. Ventura 13 is older than that ROM and is entirely untested.
- Any further build can be offered without a rebuild: put `Restore images/custom.json`
  in Henge's Documents folder. See `docs/custom-restore-images.json.example`.
- **Apple still decides whether an old build installs.** The restore is personalized by
  Apple's signing server for the Mac's ECID; Henge cannot bypass that. If a build is no
  longer signed, the restore stops near the end. `host/install.c` has no version check.

### Chinese input
- `CatcherView` now implements `UITextInput` instead of `UIKeyInput`: a UIKeyInput-only
  responder never activates IME keyboards, which is why only English worked. Marked
  text (pinyin composition, candidates, handwriting) is handled too.
- Non-ASCII text no longer disappears. `Keys.type` only maps ASCII to Linux key codes;
  Chinese now goes through the shared clipboard (`Sharing.deliver`) and is pasted with
  Command-V. `UnicodeTyper` batches submissions that arrive close together.
- Without the `henge-agent` helper there is no clipboard in the guest: Unicode text is
  kept on the device clipboard and logged instead of silently dropped. ASCII typing,
  hardware keys and sticky modifiers are unchanged.

### Simplified Chinese UI
- `ios/Localization/zh-Hans.lproj/Localizable.strings` with 208 keys, plus
  `CFBundleLocalizations` in Info.plist and a post-build step in project.yml that copies
  the `.lproj` into the bundle. SwiftUI literals are LocalizedStringKeys, so the Swift
  sources did not need rewriting; missing keys fall back to English.
- `ios/Localization/extract_ui_keys.py` re-extracts the keys from the Swift sources.
- Release notes, install-step labels and the version-row note now use LocalizedStringKey.
  Dynamically built strings (error messages, step names, log lines) are still English.

### Machine identity and Apple Account sign-in
- Every Mac used to report QEMU's placeholder serial `1234` and the same fixed MAC, so
  Apple's account servers saw the whole Henge user base as one invalid machine (upstream
  issue #37). `hv_cfg_identity()` now derives a 10-character Apple-style serial and four
  distinct locally-administered MACs from the ECID. The ECID is stored in `machine.json`
  and is the same during restore and every boot, so the identity is unique per Mac and
  never changes. `host/vm.c` and `host/hvf_ref.c` pass the same en0 MAC to the config
  region and the NIC, so macOS sees one consistent machine. The engine logs the identity.
- `HV_CFG_SERIAL` is a test hook for the config region; it is not a way to clone a real
  Mac's identity, which can lock an Apple Account.
- `host/dns_proxy.c`: Apple Account/activation/certificate hostnames (`*.apple.com`,
  `*.icloud.com`, the akamai/mzstatic CDNs) no longer add to the streak that switches
  DNS back to libslirp for the whole session. Sign-in resolves a burst of those names,
  and on IPv6-only networks libslirp has no working resolver, so a few late answers used
  to make every later lookup fail with a verification/connection error (issue #34).
- **This does not make Apple Account sign-in work.** Apple's servers ask for a Secure
  Enclave–signed device identity (`VZMacIdentityPayload`), which emulation cannot
  produce; even Apple's own virtual Macs only gained sign-in in macOS Sequoia 15.1.
  The README known limit is updated to say what is and is not possible.

## 0.2.0 (100)

Based on upstream `main` at b744a78.

### Display colour
- macOS no longer looks pale: the half-float display surface is shown as WindowServer wrote it
  instead of being sRGB-encoded a second time. Colour probe for diagnosis (`HV_COLOR_PROBE`).
  — [hungbenjamin402](https://github.com/hungbenjamin402/Henge)
- Colour matching for the iPad's P3 panel (the Mac's frames are tagged sRGB), with live
  *Color matching*, *Linear color conversion* and *Brightness* controls in the session's Details.
  — [sonnx0868](https://github.com/sonnx0868/Henge)

### iPad, Magic Keyboard and trackpad
- Magic Keyboard scrolling calibrated, smoother input, and the device's thermal state in Details.
- Smaller, sharper pointer on iPad, with a size and a sharp-edges setting.
- Video planes copied through the IOSurface's real layout.
  — all three: [sonnx0868](https://github.com/sonnx0868/Henge)
- iPadOS's own hide-keyboard key ends typing, so the Mac takes the full screen again.
  — [gavinnolan](https://github.com/gavinnolan/Henge)
- Screen modes for a Mac on iPad: *Retina* (every pixel of the panel, at 2x), *Performance*
  (about 30% fewer pixels), *Fit this iPad* and *16:9*. Retina is opt-in: it costs a lot of
  emulated GPU work.
  — Retina from [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge), Performance from sonnx0868
- 120 Hz ProMotion support, 4 GB default memory on 8 GB iPads, sampling profiler and GPU
  trace/shader dump tools. — [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge)

### External display
- A Mac on an external display before iOS 27 too (iOS 17–26), the picture coming back to the
  device when the monitor is unplugged, and unplugging one display no longer freezes the others.
  — [hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### JIT
- At launch, LocalDevVPN is connected first when it is off.
  — [braedonsaunders](https://github.com/braedonsaunders/Henge) (upstream PR #3)
- JIT on cellular: explains the failure and retries instead of blaming LocalDevVPN.
- Personal (free) teams can sign the app: `HENGE_ENTITLEMENTS`.
  — both: [hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### New in this fork
- **Performance settings** (Settings → Performance), applied each time a Mac starts:
  - *Mac refresh rate*: 60 Hz by default. Every frame is emulated and replayed, so 120 Hz
    halves the CPU left to apps; 120 Hz stays available.
  - *Faster disk writes* (on): `F_BARRIERFSYNC` instead of a full `fsync`.
  - *Quicker wake from idle* (off): an idle CPU watches for work for 50 µs before sleeping.
  - *Superblocks (experimental)* (off): translated code runs on past conditional branches.
  - `Documents/henge-env.txt` still overrides everything.
- **Hide the session controls**: a button left of Keyboard hides the bar over the Mac; a
  three-finger tap brings it back (a hint says so the first three times). iPadOS's own
  three-finger undo/copy/paste bar is turned off inside the session so it doesn't interfere.
- Merges kept the Xcode 27 build: the built-in StikJIT helper and the Liquid Glass icon stay
  (the m4 fork's Xcode 16 changes, which remove them, are left out).
- Display name back to *Henge*; version 0.2.0 (100) so sideloading stores treat it as an update.

### Not included
- `HV_GROUPS` (grouped memory accesses): upstream measured it no faster and it fills the JIT
  region sooner.

## Building

As upstream (see README): Xcode 27, `xcodegen`, `meson`, `rustup` with `aarch64-apple-ios`,
and a built [Husk](https://github.com/Leviidev/Husk) at `~/Documents/Coding/Husk`. Only Husk's
`build_ios.sh libffi glib libslirp` and `build_rppairing_ios.sh` are needed for Henge.
