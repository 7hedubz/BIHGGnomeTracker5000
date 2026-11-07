# BIHG GnomeKillTracker 5000

**Author: DoHeal** · World of Warcraft: Forever · Interface 16001 / Camelot

Gnome PvP kills, deaths to Gnomes, persistent Alliance encounter memory, and automatic guild leaderboards.

## Guild-only group observation (1.3.0)

- Track **yourself and fellow guildmates in your party/raid**, including controlled pets, even when those guildmates do not have the addon. Verified group guildmates are discovered automatically and appear as individual **[observed]** character entries.
- **Only current guildmates are tallied.** Non-guild party/raid players receive no credit. An unguilded player is not tallied either. The leaderboard, Top 10, personal cards and account kill-time chart filter out non-guild characters. Old saved history is retained rather than deleted.
- Each participant must independently qualify: at least 10% of the Gnome's observed peak maximum health in effective attributed damage **or** a confirmed supported CC aura, followed by a confirmed death within the participation window. Merely grouping with a killer, casting CC, or seeing health drop is not enough.
- Enemy nameplates, your target/focus/mouseover, and guild group members' target tokens provide observable targets. Aura source GUIDs resolve to guild characters/pet owners. Combat information that is secret or unavailable is skipped.
- **Forever's closed log still matters:** readable own/party CC can be observed, but damage-only participation cannot be reconstructed without readable combat-log data. Other players' deaths to Gnomes require a readable Gnome lethal hit followed by confirmed death; another player's corpse alone does not identify its killer. Your own fresh death recap remains supported. A non-addon player's encounter count is unknown (`-`), not invented.
- Different non-addon characters stay separate. Once they install the addon and initialize their characters, alias metadata groups those same character keys; witnessed history follows them instead of creating duplicate character rows.
- Observations synchronize through guild addon messages outside instances, including to members who were not present. Multiple witnesses share event-level records rather than summing witness totals. Duplicate/replayed reports are suppressed using participant/opponent GUIDs and a **three-second death-correlation window**, with contribution timing distinguishing later lives. Without a server-issued kill ID this is best-effort: extreme latency or very rapid repeat deaths can remain ambiguous.
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

Forever's installed Spy integration documents a closed combat-log stream. **Exact personal damage attribution cannot be reconstructed from enemy health changes.** The 10% damage rule is implemented when readable combat-log data exists; on a restricted client, damage-only kills cannot be awarded.

The fallback counts **confirmed own CC aura + confirmed enemy death** when readable unit/aura APIs expose that information. Unknown/secret data is skipped, never guessed. Out-of-sight auras/deaths cannot reliably be recovered. UI coverage text and `/gkt debug` report coverage. Live-client rendering and real multi-client PvP synchronization still require in-game validation.

## Statistics

- **Gnome kills:** a hostile Gnome player dies within 120 seconds of your last contribution, after you dealt at least 10% of its observed peak maximum health in effective damage or successfully applied supported CC. Current player/pet damage and CC qualify; overkill is excluded. Cast-success, misses/resists, unrelated debuffs, and nearby deaths alone do not qualify.
- **Deaths to Gnomes:** a Gnome player is confirmed as the killing-blow source by a fresh readable death recap or readable lethal combat-log damage. Nearby/targeting suspects, hidden/stale/untimed recaps, unknown killers, and unestablished pet owners are not guessed.
- **Gnomes encountered:** unique Gnome player GUIDs, not scan count. Repeated sightings count once per selected period; lifetime remains unique across reloads and sessions.
- **Alliance log:** saves GUID, name, race, first/last seen, and encounter dates. Gnomes are highlighted and ordered first by default. Detection uses nameplates, target, focus, and mouseover, not radar for units the client has not exposed. Enable enemy nameplates for better coverage. Newly discovered Gnomes optionally trigger chat alerts.

CC includes whitelisted Vanilla ranks of polymorph, stuns, fear, sap, incapacitate/disorient, roots, silence, mind control, sleep, and relevant pet control. Only successful aura applications/refreshes qualify. Ordinary slows and interrupts without a control aura are not included. Custom Forever spell IDs may need adding to `A.CCSpells` in Core.lua.

## UI

Open **`/gkt`**, `/gnomekills`, `/bihg`, or use the minimap gear.

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

On Guild leaderboard or Charts, select a period and click **Post Top 10 to Guild...** (or `/gkt top`). Review the exact report, then **Post to /guild** or Cancel. It ranks **aliases**, combining their guild characters, by kills regardless of the table's current sort/expansion state. Fewer than ten aliases with recorded kills produces a shorter list; an empty period is reported honestly.

The report uses cached addon scores, says so in its heading, and is readable in regular guild chat even without the addon. Posting is **never automatic**. Confirmed reports are paced at one chat line per second, limited to once per minute, and only sent outside instances. A guild/instance change, timeout or failed send stops the report rather than retrying potentially duplicate public messages. A successful API call only confirms handoff to the chat API, not server delivery. Legacy and namespaced chat APIs are supported.

- Minimap **left-click:** guild leaderboard. **Right-click:** Alliance encounters. A different shortcut switches an open window; repeating the same shortcut closes it.
- Click leaderboard column headers to sort; click again to reverse. Alias expansion keeps character details under their owner.
- Lifetime, Today, 7 days, 30 days, This week, This month, and This year filters. The 7/30-day periods include today plus the previous 6/29 **UTC calendar days**, not rolling-to-the-second windows. Weeks start Monday.
- Drag to move; position persists. Mouse wheel or Previous/Next pages the rows; Escape closes the window. K/D is `-` when deaths are zero.
- Character names in tables/alerts omit internal realm suffixes. Full identifiers remain intact in saved data and synchronization.
- Alliance encounters has four meaningful headers; the unused fifth column is hidden.

## Guild synchronization

At least one observer must run the addon to witness grouped guildmates. Guildmates need it themselves for account aliases, their own full-coverage reports and receiving the synced UI, but not for witnessed group credit. Direct score packets are attributed to the guild-channel sender. Account snapshots share **the sender's locally known alts**, not arbitrary cached aggregate peer totals; event-level guild observations may be relayed separately. Alt targets must be current guild members; conflicting direct account bindings are rejected. Account identities, ownership claims, statistics and witness events remain **unverified client reports**, not server-authoritative or cryptographically verified ownership.

- Automatic sync at login, world entry, guild changes, personal score changes, alias changes, and every 15 minutes. Manual **Refresh guild data** or `/gkt sync` is also available. These silent addon packets do not post a chat report.
- Forever blocks addon messages inside instances. Results queue until leaving. Failed sends retain the packet for retry; full history is paced at at most two data packets/second.
- Lifetime totals plus up to 400 days of nonzero daily kill/death totals use cumulative merges, so duplicate/reordered score packets do not double-count.
- Guild caches are account-wide and separated by guild/realm. Current membership is checked. Already-known offline members remain cached; unknown data cannot be recovered from the server. Partial delivery can leave incomplete recent scores until another full exchange.
- Aggregates/account labels are shared. Group observation records additionally share participating character names/GUIDs, opponent GUIDs and event/contribution timestamps for deduplication. The private Alliance name/sighting log is not broadcast. Summing different guildmates' unique encounters is **not** a unique guild-wide Gnome count.
- Older addon versions can exchange legacy character totals, but must upgrade for group observation/event deduplication and the latest guild-only display behavior.

## Saved data and upgrade

`BIHGGKTDB` remains per-character. New **`BIHGGKTAccountDB`** is account-wide and retains nickname, stable grouping ID, known character records, and shared guild caches. Existing totals migrate by cumulative maximum, not addition, and remain after renaming. Lifetime totals and unique identities persist; dated history is retained for 400 days. Activity before addon installation cannot be reconstructed. Do not edit live SavedVariables while WoW is running.

**For 1.3.0, fully quit and relaunch Forever**: `GroupTracker.lua` was added to the TOC. Upgrading from before 1.1.0 also adds account-wide data; log each existing alt once to import it. No statistics reset is needed.

## Install

Use the release zip, not GitHub's automatically named source directory:

```text
World of Warcraft/_forever_/Interface/AddOns/
  BIHGGnomeKillTracker5000/
    BIHGGnomeKillTracker5000.toc
    Core.lua
    Accounts.lua
    Sync.lua
    GroupTracker.lua
    Runtime.lua
    Dashboard.lua
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
| `/gkt top` | Preview Top 10 report; does not send until confirmed |
| `/gkt sync` | Request/broadcast guild statistics outside instances |
| `/gkt alerts` | Toggle new-Gnome chat alerts |
| `/gkt debug` | Print coverage and last guarded error |

## Verification / development

Lua 5.1-compatible; no embedded libraries/dependencies:

```sh
luajit tests/run.lua .
luajit tests/accounts.lua .
luajit tests/dashboard.lua .
luajit tests/group.lua .
luajit tests/integration.lua .
luac -p Core.lua Accounts.lua Sync.lua GroupTracker.lua Runtime.lua Dashboard.lua UI.lua
```

Regression tests cover qualification, attribution, duplicate deaths, UTC periods, bounded packets, cumulative sync, account initialization/alt migration, nickname changes/collisions, cross-character encounter uniqueness, and identity exchange. The actual-TOC integration harness covers mocked lifecycle, own-CC/death detection, exact-damage parsing, recap attribution, account profile UI/editing/expansion, view transitions, secret values, and failed/instance-blocked sends. Mocks validate logic and API usage, **not actual client rendering or API visibility**. Tests never write live SavedVariables.
