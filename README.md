# BIHG GnomeKillTracker 5000

**Author: DoHeal** · World of Warcraft: Forever · Interface 16001 / Camelot

Gnome PvP kills, deaths to Gnomes, persistent Alliance encounter memory, and automatic guild leaderboards.

## Current qualification (1.4.0)

Each guild participant independently needs **at least 2% effective attributed damage OR any successfully applied harmful debuff**, followed by a confirmed hostile Gnome-player death within the participation window. This includes Faerie Fire and curses. The lowered threshold and expanded debuff rule apply to new observations; previously unrecorded participation cannot be backfilled. Existing statistics are preserved.

## Guild-only group observation (1.3.0)

- Track **yourself and fellow guildmates in your party/raid**, including controlled pets, even when those guildmates do not have the addon. Verified group guildmates are discovered automatically and appear as individual **[observed]** character entries.
- **Only current guildmates are tallied.** Non-guild party/raid players receive no credit. An unguilded player is not tallied either. The leaderboard, Top 10, personal cards and account kill-time chart filter out non-guild characters. Old saved history is retained rather than deleted.
- Each participant must independently qualify: at least 2% of the Gnome's observed peak maximum health in effective attributed damage **or** any confirmed harmful debuff (including CC), followed by a confirmed death within the participation window. Merely grouping with a killer, casting CC, or seeing health drop is not enough.
- Enemy nameplates, your target/focus/mouseover, and guild group members' target tokens provide observable targets. Aura source GUIDs resolve to guild characters/pet owners. Combat information that is secret or unavailable is skipped.
- **Forever's closed log still matters:** readable own/party debuffs can be observed, but damage-only participation cannot be reconstructed without readable combat-log data. Other players' deaths to Gnomes require a readable Gnome lethal hit followed by confirmed death; another player's corpse alone does not identify its killer. Your own fresh death recap remains supported. A non-addon player's encounter count is unknown (`-`), not invented.
- Different non-addon characters stay separate. Once they install the addon and initialize their characters, alias metadata groups those same character keys; witnessed history follows them instead of creating duplicate character rows.
- Observations synchronize through guild addon messages out of combat, including to members who were not present. Multiple witnesses share event-level records rather than summing witness totals. Duplicate/replayed reports are suppressed using participant/opponent GUIDs and a **three-second death-correlation window**, with contribution timing distinguishing later lives. Without a server-issued kill ID this is best-effort: extreme latency or very rapid repeat deaths can remain ambiguous.
- Upgrade baselines preserve legacy totals. Before a character's upgrade boundary, potentially overlapping legacy and witnessed daily counts merge conservatively by maximum rather than addition; disjoint pre-upgrade activity cannot be reconstructed exactly. New event-era records merge by event identity. Adoption of a previously non-addon character retains its witnessed events.
- Lifetime event identities/timestamps are retained in account-wide, guild-separated storage to support deduplication and later adoption. Storage and full-history catch-up grow with activity; large histories take time at the paced send rate. Fresh new events get priority over an already queued historical replay. Personal characters keep their own lifetime history when changing guild, without importing unrelated former guildmates.

## Account-wide aliases (1.1.0)

- Your leaderboard entry is an **alias**, with the combined kills, deaths, recalculated K/D, and unique Gnome encounters of your known guild characters.
- Default alias: the first character to initialize the account-wide profile. Change it in **Settings → Nickname → Save nickname**.
- Click **[+] Alias (character count)** to expand the individual characters and their statistics. Click again to collapse. Period filters and sorting apply to the combined totals; character details use the same period.
- Alts on the same WoW account and installation automatically inherit the alias. A stable installation/account identifier groups them; merely choosing another player's nickname does **not** merge your characters with theirs. Names are cosmetic, not authentication or an anti-cheat guarantee.
- **Existing characters must each log in once after upgrading** to import their old statistics into the account profile. After that, any online guild character shares the account's known guild-alt records, including offline alts; guildmates do not have to catch every alt online. Characters never initialized on this installation cannot be discovered automatically.
- Rename once and all known characters use the new alias. Renaming does not reset statistics or create another score. Stale nickname updates cannot override newer revisions.
- Account grouping uses this WoW account's SavedVariables, not Battle.net identity. Separate WoW accounts/installations are not automatically linked. Copying/migrating account SavedVariables requires a fully closed client.
- The personal summary and guild leaderboard include **current guild-member characters only**, with no exception for an unguilded active character. The private Alliance encounter log remains the active character's log.
- An alias's encounter statistic deduplicates the **same Gnome GUID across its characters**. It does not sum daily or character unique counts. Guildmates receive a precomputed account-unique snapshot; stale/missing period data displays `-` instead of inventing a count.

## Important Forever limitation

Forever's installed Spy integration documents a closed combat-log stream. **Exact personal damage attribution cannot be reconstructed from enemy health changes.** The 2% damage rule is implemented when readable combat-log data exists; on a restricted client, damage-only kills cannot be awarded.

The fallback counts **confirmed guild-character/pet debuff + confirmed enemy death** when readable unit/aura APIs expose that information. Unknown/secret data is skipped, never guessed. Out-of-sight auras/deaths cannot reliably be recovered. UI coverage text and `/gkt debug` report coverage. Live-client rendering and real multi-client PvP synchronization still require in-game validation.

## Statistics

- **Gnome kills:** a hostile Gnome player dies within 120 seconds of your last contribution, after you dealt at least 2% of its observed peak maximum health in effective damage or successfully applied any harmful debuff. Current guild player/pet damage and debuffs qualify; overkill is excluded. Cast-success, misses/resists, other players' debuffs and nearby deaths alone do not qualify.
- **Deaths to Gnomes:** a Gnome player is confirmed as the killing-blow source by a fresh readable death recap or readable lethal combat-log damage. Nearby/targeting suspects, hidden/stale/untimed recaps, unknown killers, and unestablished pet owners are not guessed.
- **Gnomes encountered:** unique Gnome player GUIDs, not scan count. Repeated sightings count once per selected period; lifetime remains unique across reloads and sessions.
- **Alliance log:** saves GUID, name, race, first/last seen, and encounter dates. Gnomes are highlighted and ordered first by default. Detection uses nameplates, target, focus, and mouseover, not radar for units the client has not exposed. Enable enemy nameplates for better coverage. Newly discovered Gnomes optionally trigger chat alerts.

Debuff qualification is **not limited to a spell whitelist**: confirmed harmful effects include CC, Faerie Fire, curses, DoTs, bleeds, slows and other debuffs. Attribution must identify the contributing guild character or their current pet. Readable `DEBUFF` combat-log applications/refreshes/added stacks or source-attributed `HARMFUL` unit auras provide confirmation. Buffs, unknown aura types and cast-success alone do not qualify. An interrupt without an applied harmful aura does not satisfy the debuff branch.

## UI

Open **`/gkt`**, `/gnomekills`, `/bihg`, or use the minimap gear.

### Spy-style Nearby Alliance window (1.4.0)

A separate compact overlay is enabled by default, independently of the dashboard. Its header shows **Nearby count** and **Gnome count**; when empty/collapsed it remains a small header like Spy's Nearby bar.

- Lists readable **Alliance players**, with **Gnomes always first** and highlighted gold. Other races follow by recency. Repeated target/nameplate detections share one GUID entry; NPCs, pets, Horde and your own character are excluded.
- Uses the existing nameplate, target/focus/mouseover and group-target scans. Explicitly invisible units do not refresh their sighting. This is a **readable/recent sighting list, not a range radar** or proof that an enemy is still present. Entries fade after five seconds without refresh and expire after 30 seconds. Confirmed deaths are removed; world/area changes clear the nearby cache.
- Names omit internal realm suffixes. Rows show race and last-seen age; hover for known level and sighting details. Up to eight rows are displayed per page, with paging controls for longer lists.
- Drag the header to move it; **L/U** locks/unlocks its position. **-/+** collapses/expands, **H** opens the separate historical Alliance encounter log, **< / >** pages, and **X** hides it. Position, lock, collapse and visibility are remembered per character.
- Restore/toggle with **`/gkt nearby`** or **Settings → Nearby overlay**. **`/gkt nearby clear`** clears only this temporary list; persistent encounter history is untouched. Hiding the overlay does not stop tracking or guild sync.
- The overlay is a display/hover list; it does not implement protected click-to-target or automated targeting/casting. It has no dependency on Spy and does not modify Spy's files/settings.

Nearby opponents are not leaderboard participants. The guild-only qualification/tally rules remain unchanged. Nearby cache contents themselves are not broadcast or rehydrated from historical SavedVariables.

### Character identity repair (1.5.0)

Player GUIDs and per-character SavedVariables provenance reconcile alternate API spellings of the same character. Old name records are archived, their encounter identities and cumulative counters merge conservatively, and witnessed event identities are preserved rather than added twice. The leaderboard uses one physical-character entry per linked GUID; actual different-GUID alts remain separate expandable children under the account nickname. Equal nicknames alone never merge accounts.

Migration runs in the addon at login; do not manually edit live SavedVariables. Log each existing alt in once after this upgrade to establish its GUID. One online guild character then relays its known offline-alt GUID associations as well as their scores. Updated guildmates use the new identity packets to combine observed and declared name variants; older clients must upgrade for this reconciliation. Guild identity/statistics are still client-reported, not cryptographic ownership verification.

### Report-send diagnostics and event safety (1.7.3)

This is a **diagnostic update, not a confirmed fix for missing native guild delivery**. The old `/gkt debug` coverage flags described combat log/CC/recap data and could not diagnose chat. Confirmation now prints a **local-only** queued/rejected status, and `/gkt debug` additionally prints report request/send counters, queue progress, current rank/guild/combat gates, selected global/modern chat API, its actual return or caught error, and BIHG protected-action events. Diagnostics persist in the per-character database; no report text or test message is sent by the debug command. A nil/success API return is not server delivery confirmation.

Native error records identified a forbidden call from BIHG's event-registration loop. Stop registering `COMBAT_LOG_EVENT_UNFILTERED` on this Forever client; wrapping registration in `pcall` does not prevent `ADDON_ACTION_FORBIDDEN`. The optional combat-log parser remains for explicitly supplied/synthetic data. Readable harmful-aura participation and native death/recap handling remain active; unavailable damage attribution is not reconstructed from health loss. Removing this known startup error is **not proof it caused the guild-send symptom**.

To capture the actual send issue: `/reload` out of combat, click **Post to /guild** once, wait a few seconds, then run `/gkt debug` and collect **all** BIHG lines. Do not reload again before collecting the current queue/status. Cooldown and rank rules are unchanged. No live public chat was posted during the regression tests.

### Anywhere out-of-combat communication (1.7.2)

The addon no longer blocks outgoing guild data or manually confirmed guild reports solely because you are inside an instance. Both may send **anywhere while out of combat**. Outgoing sync and remaining public-report lines pause in combat and resume afterward without skipping queued data. Incoming data can still be received; PvP tracking and the separately configured party sighting alerts continue during combat. Missing, unreadable or throwing combat-state APIs fail closed.

Rank authorization, guild identity validation, one-person-per-line reports, confirmation, pacing and cooldowns remain in place. Public reports retain their two-minute overall expiry, so a long fight may require a fresh preview/confirmation. Rejected addon packets stay queued; failed public chat sends stop rather than risking duplicate retries. This is an addon scheduling policy, not a claim that the client/server will accept every send. Apply with `/reload` out of combat.

### Readable guild reports (1.7.1)

Public Top 10 reports and their preview now show **one person per line**, after the heading. A full Top 10 therefore contains eleven paced chat lines: one heading plus ten ranked people. Existing rank restrictions, confirmation, byte limits and one-second send pacing remain unchanged. Upgrade with `/reload` out of combat.

### Automatic party Alliance announcements (1.7.0)

**Settings → Local notifications & Party alerts → Party Alliance alerts** defaults **ON**. Fresh readable Alliance-player contacts are announced to **PARTY**, independently of sound selection, local chat alerts, nearby visibility and guild-report ranks. This continues during combat even while protected target rows are frozen. Solo/raid contexts do not post; there is no guild, raid, instance-chat or channel fallback.

Regular message: `[BIHG] Alliance detected: <name> - <readable level/race/class> - near me: <location>`.
For Gnomes the message starts exactly **`GNOME DETECTED : `**, before the regular message. Names retain their surnames; only a known realm suffix is omitted. Unknown details are omitted. Zone/subzone and optional map coordinates describe **your position when the sighting was queued**, not a measured enemy location. Whole optional fields are dropped if needed to stay within the chat byte limit.

Announcements are GUID-suppressed while continuously observed in an active party, with a new alert after **60 seconds unseen**. Suppression survives Clear and reload. A newly learned Gnome race can trigger its stronger notification. Gnomes are prioritized, the queue is bounded, sends are spaced by at least two seconds and stale/dead contacts are discarded. Leaving the party or switching the feature off cancels queued sends; failed sends are not automatically spam-retried. Suppression is **per client**: multiple addon users may announce independently, so turn off extra announcers if desired. Clear cancels the currently queued messages without deleting statistics.

Upgrade from 1.6.0 with **`/reload` out of combat**; the TOC file load list is unchanged. Tests mock chat APIs and never send real party/guild messages. Native party-chat delivery still needs in-game validation.

### Stable roster history and name targeting (1.6.0)

- Partial, empty and offline-filtered guild lists no longer delete cached participant records. Last-verified membership is persisted per guild/realm and labeled as cached while the roster is unresolved. Where witnessed events remain, missing observed-character rows are rebuilt from those events; this does not invent lost or never-recorded counters.
- Confirmed departures change active membership, not stored history. Absence needs two consistent, complete offline-inclusive roster updates with readable GUIDs, at least five seconds apart; a readable different guild on a live group unit excludes that character immediately. If the full roster cannot be read, last-verified membership remains visible rather than treating absence as proof of departure.
- New group credit requires readable same-guild unit information or a positive roster entry from this session, not merely an old display-cache entry. When your own guild identity is temporarily unavailable, cached history can remain visible but new awards and sync are paused to avoid crossing guild namespaces.
- Guild-roster and live-unit GUIDs link alternate name formats. Received sender names are resolved through established GUID links before creating records or filtering self echoes, so late legacy summaries cannot recreate a duplicate physical character. Local self-summary echoes never move the authoritative local history baseline.
- Left-click names in Nearby, encounter history, character rows, or single-character chart entries to **attempt targeting the actual character**. A single-character alias header targets its child, not the alias string; multi-character aliases expand/open the character list instead of guessing an alt.
- Targeting uses pre-bound secure hardware-click buttons and exact name alternatives for Forever's first/surname transport and known realm suffixes. This does not rewrite stored identities, use fuzzy first-name matching, cast spells, or start attacks. Unavailable/out-of-range characters may not resolve; the attempt clears the previous target before trying the exact alternatives.
- Protected rows and their matching labels/layout freeze in combat; already-bound targets remain clickable, while new bindings and layout changes apply after combat. Nearby shows **combat locked**. Clear/collapse/hide changes to the protected nearby list may be visually deferred. Tracking/sounds continue. Opening/switching the main views is unavailable during combat.
- Upgrading from 1.5.1 changes existing loaded Lua files only: use **`/reload` while out of combat**. Older versions that lack the 1.5.0 files/libraries still require a full client relaunch.

### Louder bundled alarms (1.5.1)

The four bundled alarms are calibrated to approximately **150% of their original decoded RMS level**, with peak limiting to prevent file-level clipping. Clip durations remain below 0.6 seconds. This changes only BIHG audio assets, not global game volume or third-party sound files. Fully quit/relaunch to ensure cached native sound data is replaced. The Settings Preview buttons use the updated clips.

### Sound alerts and Clear (1.5.0)

**Settings → Local notifications** has independent Alliance and extra-Gnome sound toggles, separate sound selectors and Preview buttons, plus a sound-channel selector. General Alliance audio defaults ON; the extra Gnome sound defaults OFF. A new Gnome can play the general alarm followed by the optional extra sound, or use the Gnome sound alone if general audio is disabled.

- Four very short bundled alarm cues are available without another addon. Their source/license information is in `Media/SOURCES.md` and `Licenses/`.
- The searchable, paginated picker includes **all valid sound entries registered with LibSharedMedia by loaded addons**, not just the bundled presets. Select a name to save it; Preview does not change the selection. Reopening or filtering reads the current registry, including late registrations. Standard `None` is silent. An unavailable saved third-party sound falls back to a bundled alarm without erasing the saved name.
- Master is the default output; SFX, Dialog, Ambience and Music are also selectable. Game volume/mute settings still apply. No audio CVars are changed. A successful playback API return confirms client acceptance, not that speakers are audible.
- Alerts come from fresh **local readable Alliance sightings**, not guild packets or historical encounter rows. Repeated scans/duplicate unit tokens stay silent. A contact can alert again after more than 30 seconds unseen. Crowd detections coalesce, with a two-second batch cooldown and a short separation before the optional extra Gnome cue.
- **Clear** in the Nearby header clears current contacts and queued sounds only. It retains statistics, encounter history and recent-contact sound suppression. Still-visible players can repopulate on the next scan without immediately repeating their alert. It does not disable detection.
- Sound settings are per character, separate from new-Gnome **chat messages** and overlay visibility. Playback failures cannot stop detection, kill tracking or guild sync.

### Dashboard layout (1.2.0)

- **View navigation:** separate Guild leaderboard, Alliance encounters, Charts, and Settings tabs.
- **Period filters:** all seven UTC periods are visible, with the selected period highlighted; no cycling button.
- **Summary cards:** account kills, deaths to Gnomes, K/D, and deduplicated encounters.
- **Guild actions:** **Refresh guild data** is an optional silent data refresh, not a chat message. The status explicitly shows automatic sync.
- **Settings:** nickname editing and local Gnome-alert toggles no longer share the navigation row.
- Dark panels, flat buttons, selected-tab borders, tooltips, and separated content/action regions distinguish purpose. The window scales down to fit smaller screens.

### Charts

**Charts** contains a horizontal Top 10 guild-alias kill ranking and a **Kills over time line graph**. The line combines your characters' recorded daily kills: **X = UTC date/time, Y = kills per day**. Numeric Y-axis ticks start at zero, date ticks run from oldest to newest, and hovering a point shows its exact date/count. This is daily activity, not a cumulative lifetime-total curve. A single-day view shows one point rather than an invented time segment.

The line shows the latest **up to 30 UTC days within the selected period**; Lifetime therefore shows the latest 30 days rather than the entire lifetime on the time axis. Labels identify this limit. Guild rankings use cached reports; empty rankings show an explicit no-data message rather than fictional zero-score leaders. Version 1.2.1 replaces the former daily kill/death bars with this kills-only line graph.

### Send the Top 10 to guild chat

Only the exact current guild ranks **`Council of BIHG`** and **`The BIHG Cheese`** may see/use **Post Top 10 to Guild...**. There is no generic officer/guild-master override. Unreadable rank/guild data denies access. The preview/slash command, confirmation, and each queued send enforce authorization; losing eligibility stops the remaining report. Other members still receive normal automatic data synchronization. This is an addon UI/report restriction, not a server-side ban on manual guild chat; guildmates must install this version to receive the restriction.

On Guild leaderboard or Charts, an eligible member selects a period and clicks **Post Top 10 to Guild...** (or `/gkt top`). Review the exact report, then **Post to /guild** or Cancel. It ranks **aliases**, combining their guild characters, by kills regardless of the table's current sort/expansion state. Fewer than ten aliases with recorded kills produces a shorter list; an empty period is reported honestly.

The report uses cached addon scores, says so in its heading, and is readable in regular guild chat even without the addon. Posting is **never automatic**. Confirmed reports are paced at one chat line per second, limited to once per minute, and only sent out of combat. Combat pauses remaining lines; a guild change, timeout or failed send stops the report rather than retrying potentially duplicate public messages. A successful API call only confirms handoff to the chat API, not server delivery. Legacy and namespaced chat APIs are supported.

- Minimap **left-click:** guild leaderboard. **Right-click:** Alliance encounters. A different shortcut switches an open window; repeating the same shortcut closes it.
- Click leaderboard column headers to sort; click again to reverse. Alias expansion keeps character details under their owner.
- Lifetime, Today, 7 days, 30 days, This week, This month, and This year filters. The 7/30-day periods include today plus the previous 6/29 **UTC calendar days**, not rolling-to-the-second windows. Weeks start Monday.
- Drag to move; position persists. Mouse wheel or Previous/Next pages the rows; Escape closes the window. K/D is `-` when deaths are zero.
- Character names in tables/alerts omit internal realm suffixes. Full identifiers remain intact in saved data and synchronization.
- Alliance encounters has four meaningful headers; the unused fifth column is hidden.

## Guild synchronization

At least one observer must run the addon to witness grouped guildmates. Guildmates need it themselves for account aliases, their own full-coverage reports and receiving the synced UI, but not for witnessed group credit. Direct score packets are attributed to the guild-channel sender. Account snapshots share **the sender's locally known alts**, not arbitrary cached aggregate peer totals; event-level guild observations may be relayed separately. Alt targets must be current guild members; conflicting direct account bindings are rejected. Account identities, ownership claims, statistics and witness events remain **unverified client reports**, not server-authoritative or cryptographically verified ownership.

- Automatic sync at login, world entry, guild changes, personal score changes, alias changes, and every minute. Manual **Refresh guild data** or `/gkt sync` is also available. These silent addon packets do not post a chat report.
- Outgoing sync is attempted anywhere, including dungeons/raids/battlegrounds, while out of combat. Combat pauses the queue without advancing it; it resumes afterward. Failed/rejected addon sends retain the packet for retry; full history is paced at at most two data packets/second. Actual client/server API restrictions still apply: API acceptance is not proof of remote delivery.
- Lifetime totals plus up to 400 days of nonzero daily kill/death totals use cumulative merges, so duplicate/reordered score packets do not double-count.
- Guild caches are account-wide and separated by guild/realm. Current membership is checked. Already-known offline members remain cached; unknown data cannot be recovered from the server. Partial delivery can leave incomplete recent scores until another full exchange.
- Aggregates/account labels are shared. Group observation records additionally share participating character names/GUIDs, opponent GUIDs and event/contribution timestamps for deduplication. The private Alliance name/sighting log is not broadcast. Summing different guildmates' unique encounters is **not** a unique guild-wide Gnome count.
- Older addon versions can exchange legacy character totals, but must upgrade for group observation/event deduplication and the latest guild-only display behavior.

## Saved data and upgrade

`BIHGGKTDB` remains per-character. New **`BIHGGKTAccountDB`** is account-wide and retains nickname, stable grouping ID, known character records, and shared guild caches. Existing totals migrate by cumulative maximum, not addition, and remain after renaming. Lifetime totals and unique identities persist; dated history is retained for 400 days. Activity before addon installation cannot be reconstructed. Do not edit live SavedVariables while WoW is running.

**For 1.5.0, fully quit and relaunch Forever**: `Identity.lua`, `Sounds.lua` and bundled shared-media libraries were added to the TOC. Upgrading from before 1.1.0 also adds account-wide data; log each existing alt once to import it. No statistics reset is needed.

## Install

Use the release zip, not GitHub's automatically named source directory:

```text
World of Warcraft/_forever_/Interface/AddOns/
  BIHGGnomeKillTracker5000/
    BIHGGnomeKillTracker5000.toc
    Libs/LibStub.lua
    Libs/CallbackHandler-1.0.lua
    Libs/LibSharedMedia-3.0.lua
    Media/alert-1.ogg ... alert-4.ogg
    Media/SOURCES.md
    Licenses/
    Core.lua
    Accounts.lua
    Sync.lua
    GroupTracker.lua
    Identity.lua
    Runtime.lua
    Dashboard.lua
    Sounds.lua
    Nearby.lua
    UI.lua
```

Enable **BIHG GnomeKillTracker 5000** at character select. New addon folders and TOC load-list upgrades require a full relaunch, not just `/reload`.

## Commands

| Command | Action |
|---|---|
| `/gkt` | Toggle statistics window |
| `/gkt encounters` | Open Alliance encounter log |
| `/gkt charts` | Open ranking and daily activity charts |
| `/gkt settings` | Open nickname and local notification settings |
| `/gkt nearby` | Toggle/restore compact Nearby Alliance overlay |
| `/gkt nearby clear` | Clear temporary nearby list, not history |
| `/gkt top` | Authorized ranks only: preview Top 10; does not send until confirmed |
| `/gkt sync` | Request/broadcast guild statistics out of combat |
| `/gkt alerts` | Toggle new-Gnome chat alerts |
| `/gkt debug` | Print coverage and last guarded error |

## Verification / development

Lua 5.1-compatible, with bundled LibStub/CallbackHandler/LibSharedMedia. Audio regression checks additionally require Python 3 and FFmpeg/ffprobe:

```sh
luajit tests/run.lua .
luajit tests/accounts.lua .
luajit tests/dashboard.lua .
luajit tests/group.lua .
luajit tests/nearby.lua .
luajit tests/sounds.lua .
luajit tests/identity.lua .
luajit tests/roster.lua .
luajit tests/targeting.lua .
luajit tests/party.lua .
luajit tests/report_diagnostics.lua .
luajit tests/integration.lua .
python3 tests/media_gain.py .
luac -p Core.lua Accounts.lua Sync.lua GroupTracker.lua Identity.lua Runtime.lua Dashboard.lua Sounds.lua Nearby.lua UI.lua Libs/*.lua
```

Regression tests cover qualification, attribution, duplicate deaths, UTC periods, bounded packets, cumulative sync, account initialization/alt migration, nickname changes/collisions, cross-character encounter uniqueness, and identity exchange. The actual-TOC integration harness covers mocked lifecycle, own-CC/death detection, exact-damage parsing, recap attribution, account profile UI/editing/expansion, view transitions, secret values, and failed sends, out-of-combat dungeon sends and combat-paused queues. Mocks validate logic and API usage, **not actual client rendering or API visibility**. Tests never write live SavedVariables.
