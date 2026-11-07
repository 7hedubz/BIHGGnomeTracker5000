# Bundled sound sources

Four unmodified short Ogg Vorbis warning cues from **Kenney Interface Sounds**, licensed **CC0-1.0**. Files were downloaded, renamed only, decoded and verified; no synthesized replacement or re-encoding.

Source: https://opengameart.org/content/interface-sounds
Archive: https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip

| File | Original archive member | Duration (seconds) | SHA-256 |
|---|---|---:|---|
| Media/alert-1.ogg | Audio/error_001.ogg | 0.164558 | `46e67425d16339772e8d328fb36a49426c9467418686e11beeb71ff84b0f6433` |
| Media/alert-2.ogg | Audio/error_002.ogg | 0.164558 | `76810ec365f41078fd0507101da5bb7b8730fe011dde43908329fdabd8575e79` |
| Media/alert-3.ogg | Audio/error_003.ogg | 0.533469 | `885b28175c7b511118bcffab95675b48bbac9005cf6514656ebdad979276b3ab` |
| Media/alert-4.ogg | Audio/error_004.ogg | 0.102698 | `0b574cea597d96507e782ae9764f88482ce49f46e931e57054bf7150047f2d69` |

All four have distinct original bytes, non-silent decoded signals and durations below 0.6 seconds. Preview remains subject to WoW channel volume/mute settings.

# Shared media libraries

Libraries are included unmodified and separately replaceable. The pinned compatible LSM 8.2.0 v3 source avoids introducing current upstream Midnight-only C_UIFileAsset APIs. Other installed addons can supply a newer compatible registry through normal LibStub versioning.

- **Libs/LibStub.lua** — Public Domain; source: https://repos.wowace.com/wow/libstub/trunk/LibStub.lua; SHA-256: `7ba7300471327c0de1b3e42a4edfd62cbad79bd30100d6377736d2c1080e9b96`.
- **Libs/CallbackHandler-1.0.lua** — BSD-3-Clause; source: https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0/CallbackHandler-1.0.lua; SHA-256: `8ab5d51799e8c67b6d17b523b3c191ff63ad24e081134ab8ac7d188ce69701b9`.
- **Libs/LibSharedMedia-3.0.lua** — LGPL-2.1-only; source: https://raw.githubusercontent.com/Bodify/BetterBlizzPlates/bcb8732159ae4de3cbe17ef26049efffeb718ff1/libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua; SHA-256: `88fb301fe15edc86b01407640fe587ccbbff72d54c9e06b08b3d792804e0899c`.

Full CC0, BSD, LGPL 2.1/GPL 2 texts and attribution/redistribution notices are in `../Licenses/`. LibStub retains its public-domain dedication in the source. No addon-wide relicensing is asserted.
