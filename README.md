# BIHG GnomeKillTracker 5000

**Author: DoHeal** · World of Warcraft: Forever · Interface 16001 / Camelot

Gnome PvP kill/death statistics, a persistent Alliance encounter log, and automatic guild leaderboards.

## Important Forever limitation

Forever's installed Spy integration documents that `COMBAT_LOG_EVENT_UNFILTERED` is closed. **Exact personal damage attribution cannot be reconstructed from enemy health changes.** This addon implements the 10% rule when a readable combat log is available, but on a restricted client that branch cannot award damage-only kills. It never substitutes a killing blow, nearby death, or another player's damage for your contribution.

A restricted client can still count **confirmed own crowd-control aura + confirmed enemy death** where unit/aura APIs expose readable information. Unknown/secret information is skipped, not guessed. Auras or deaths missed while the enemy is out of sight cannot be recovered reliably. UI coverage text and `/gkt debug` make these restrictions explicit. These are not server-authoritative statistics.

## Statistics

- **Gnome kills:** a hostile Gnome *player* dies within 120 seconds of your last qualifying contribution. You must have dealt at least **10% of their observed maximum health** in effective damage, or successfully applied a supported CC aura. Current player-pet damage and CC also qualify. Overkill is excluded; observed peak maximum health is used conservatively. Merely casting a CC, a resisted/missed cast, unrelated debuffs, and nearby deaths do not qualify.
- **Deaths to Gnomes:** a Gnome player is confirmed as the killing-blow source in a fresh readable death recap or readable lethal combat-log damage. Being targeted by a Gnome is not proof. Unknown killers, hidden/untimed/stale recaps and pet owners that cannot be established are not guessed.
- **Gnomes encountered:** unique Gnome player GUIDs seen, not scan count. The same Gnome seen repeatedly contributes once per selected period. Lifetime remains unique across reloads and sessions.
- **Alliance log:** stores Alliance character GUID, name, race, first seen, last seen, and dates encountered. Gnomes are highlighted and placed first. Detection uses nameplates, target, focus and mouseover. It cannot radar-scan players that the client has not exposed. Enable enemy nameplates to improve coverage. Newly discovered Gnomes optionally produce a chat alert.

The CC whitelist includes Vanilla ranks of polymorph, stuns, fear, sap, incapacitate/disorient, roots, silence, mind control, sleep and relevant pet control. Only successful aura applications/refreshes count. It does not treat cast-success as landed CC. Ordinary slows and interrupts without a control aura are not currently included. Custom Forever spells with different IDs may need adding to `A.CCSpells` in Core.lua.

## UI

Open with **`/gkt`**, `/gnomekills`, `/bihg`, or the minimap gear button.

Minimap **left-click** opens the guild leaderboard; **right-click** opens Alliance encounters. Clicking the other view switches the open window instead of closing it. Clicking the current view's shortcut again closes it.

### 1.0.1 UI fixes
 
Version 1.0.2 additionally displays character names without realm suffixes in both tables and Gnome encounter alerts. Full identity keys remain unchanged in saved data and guild synchronization.

- Hide the unused fifth header and cells in Alliance encounters; expand Last seen into the free space.
- Make minimap left/right clicks consistently select the view named in their tooltip.
- Regression tests cover header visibility when switching views and both minimap shortcuts.

- Guild leaderboard columns: kills, deaths to Gnomes, K/D and unique Gnomes encountered. Click column headers to sort; click again to reverse.
- Your own summary is always visible.
- Lifetime, 7 days, 30 days, Today, This week, This month and This year filters.
- The 7/30-day filters include today plus the preceding 6/29 **UTC calendar days**, not a rolling-to-the-second window. Weeks start Monday. Month/year filters are UTC calendar periods.
- Alliance-log view highlights Gnomes and shows first/last seen dates.
- Drag the window; position persists. Mouse wheel or Previous/Next pages the rows. Escape closes it.
- K/D displays `-` for positive kills and zero deaths rather than dividing by zero.

## Guild synchronization

Every participating guildmate must install and enable the addon. Each character broadcasts **only its own** statistics. The guild channel supplies the sender identity; payloads cannot select a different owner. Third-party relaying is deliberately not allowed. Guildmates' reports are **unverified client claims**, not an anti-cheat system.

- Automatic sync on login, world entry, guild changes, personal score changes and periodic refresh (15 minutes), with a manual **Sync guild** button or `/gkt sync`.
- Forever blocks addon messaging inside instances. Results queue and send after leaving the battleground/dungeon. A failed send retains its packet for retry.
- Full sync sends lifetime totals and up to 400 days of nonzero daily totals, paced at at most two stats packets a second. Queries/replies are rate-limited. Duplicate or reordered cumulative packets do not add duplicate kills/deaths.
- Encounter counts are precomputed unique-character snapshots for each period: daily unique counts are **never summed** across days. Old snapshot timestamps cannot replace newer snapshots. A peer encounter snapshot from a previous UTC day displays `-` for recent periods until refreshed.
- Guild membership is checked; departed members do not appear. Guild caches are separated by guild and realm. Lifetime figures are **character lifetime**, including personal history before joining the current guild.
- Peers must overlap online outside instances to exchange data. Cached offline members remain visible, but missing data is not recoverable from the server. Partial packet delivery may leave an incomplete recent score until the next full sync. The board includes only members whose addon has reported, not fictional zeroes for everyone else.
- Only aggregate statistics are shared. Names/GUIDs in your Alliance encounter log are not broadcast. Adding together members' encounter totals does not give unique guild-wide Gnomes, because multiple members may see the same Gnome.

## Saved data

`BIHGGKTDB` is a **per-character SavedVariable**. Lifetime kills/deaths and unique Alliance identities persist indefinitely. Dated kill/death history is maintained for 400 days; encounter dates are trimmed when a character is seen again. Older first/last seen identities are retained for lifetime uniqueness. There is no reconstruction of activity from before installation. Do not edit SavedVariables while WoW is running.

## Install

Use the packaged zip, not GitHub's automatically named source folder:

```text
World of Warcraft/_forever_/Interface/AddOns/
  BIHGGnomeKillTracker5000/
    BIHGGnomeKillTracker5000.toc
    Core.lua
    Sync.lua
    Runtime.lua
    UI.lua
```

**Fully quit and relaunch the client** after installing this new addon or adding/changing its TOC files. Enable **BIHG GnomeKillTracker 5000** at character select. `/reload` alone will not discover a newly added addon folder.

## Commands

| Command | Action |
|---|---|
| `/gkt` | Toggle leaderboard window |
| `/gkt encounters` | Open Alliance encounter log |
| `/gkt sync` | Request/broadcast guild statistics outside instances |
| `/gkt alerts` | Toggle new-Gnome chat alerts |
| `/gkt debug` | Print combat-log/CC/recap coverage and last guarded error |

## Verification / development

Lua 5.1-compatible; no embedded libraries or dependencies. From the repository root:

```sh
luajit tests/run.lua .
luajit tests/integration.lua .
luac -p Core.lua
luac -p Sync.lua
luac -p Runtime.lua
luac -p UI.lua
```

The integration harness loads the actual TOC in order and exercises mocked WoW lifecycle, visible own-CC/death detection, fresh Gnome death recap, encounter memory, UI construction/paging, guild receive, instance-blocked sends and failed-send retries. Mocks validate logic and frame API usage, **not actual client rendering or API visibility**. Two live guild clients and real PvP encounters are still needed for in-game validation. Tests never write live SavedVariables.
