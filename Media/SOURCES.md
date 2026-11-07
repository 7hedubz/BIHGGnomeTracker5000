# Bundled sound sources

Four short warning cues derived from downloaded **Kenney Interface Sounds**, licensed **CC0-1.0**. In v1.5.1 they were peak-limited and re-encoded to approximately **1.5x the decoded RMS level** of the original v1.5.0 files. This is a measured signal-level increase, not a promise of exactly 1.5x perceived loudness. Original source hashes and processing measurements are retained in `gain-report.json`.

Source: https://opengameart.org/content/interface-sounds
Archive: https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip

| File | Original archive member | Duration (seconds) | SHA-256 |
|---|---|---:|---|
| Media/alert-1.ogg | Audio/error_001.ogg | 0.164558 | `e3c79cd4fac587162d891b2fd1243014b350880dc07fc79c5c07deaf03a0c558` |
| Media/alert-2.ogg | Audio/error_002.ogg | 0.164558 | `5e75bd27242eea38ef6f9becad8791071f1032d23297e24c5ddb55e0b1ff80c9` |
| Media/alert-3.ogg | Audio/error_003.ogg | 0.533469 | `2e32737e15a1b92c06d8a5055a4abd1ce8c8cbf736016f30453265cd66c5450f` |
| Media/alert-4.ogg | Audio/error_004.ogg | 0.102698 | `0d0509487d135c81b9d5617249b836f2d6dd3286b28e667a5c6cfa5a7ec51c30` |

All four have distinct, non-silent decoded signals, durations below 0.6 seconds and decoded peaks below full scale. Preview remains subject to WoW channel volume/mute settings.

# Shared media libraries

Libraries are included unmodified and separately replaceable. The pinned compatible LSM 8.2.0 v3 source avoids introducing current upstream Midnight-only C_UIFileAsset APIs. Other installed addons can supply a newer compatible registry through normal LibStub versioning.

- **Libs/LibStub.lua** — Public Domain; source: https://repos.wowace.com/wow/libstub/trunk/LibStub.lua; SHA-256: `7ba7300471327c0de1b3e42a4edfd62cbad79bd30100d6377736d2c1080e9b96`.
- **Libs/CallbackHandler-1.0.lua** — BSD-3-Clause; source: https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0/CallbackHandler-1.0.lua; SHA-256: `8ab5d51799e8c67b6d17b523b3c191ff63ad24e081134ab8ac7d188ce69701b9`.
- **Libs/LibSharedMedia-3.0.lua** — LGPL-2.1-only; source: https://raw.githubusercontent.com/Bodify/BetterBlizzPlates/bcb8732159ae4de3cbe17ef26049efffeb718ff1/libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua; SHA-256: `88fb301fe15edc86b01407640fe587ccbbff72d54c9e06b08b3d792804e0899c`.

Full CC0, BSD, LGPL 2.1/GPL 2 texts and attribution/redistribution notices are in `../Licenses/`. LibStub retains its public-domain dedication in the source. No addon-wide relicensing is asserted.
