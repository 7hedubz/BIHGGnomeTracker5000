# BIHG GnomeKillTracker 5000

**Author: DoHeal** · World of Warcraft: Forever · Interface 16001 / Camelot

Gnome PvP kills, deaths to Gnomes, persistent Alliance encounter memory, and automatic guild leaderboards.

## Account-wide aliases (1.1.0)

- Your leaderboard entry is an **alias**, with the combined kills, deaths, recalculated K/D, and unique Gnome encounters of your known guild characters.
- Default alias: the first character to initialize the account-wide profile. Change it using the **Alias** field and **Save alias** button at the bottom of `/gkt`.
- Click **[+] Alias (character count)** to expand the individual characters and their statistics. Click again to collapse. Period filters and sorting apply to the combined totals; character details use the same period.
- Alts on the same WoW account and installation automatically inherit the alias. A stable installation/account identifier groups them; merely choosing another player's nickname does **not** merge your characters with theirs. Names are cosmetic, not authentication or an anti-cheat guarantee.
- **Existing characters must each log in once after upgrading** to import their old statistics into the account profile. After that, any online guild character shares the account's known guild-alt records, including offline alts; guildmates do not have to catch every alt online. Characters never initialized on this installation cannot be discovered automatically.
- Rename once and all known characters use the new alias. Renaming does not reset statistics or create another score. Stale nickname updates cannot override newer revisions.
- Account grouping uses this WoW account's SavedVariables, not Battle.net identity. Separate WoW accounts/installations are not automatically linked. Copying/migrating account SavedVariables requires a fully closed client.
- The personal summary combines all locally known characters. The guild leaderboard includes current guild-member characters, plus your active character. The private Alliance encounter log remains the active character's log.
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

- Minimap **left-click:** guild leaderboard. **Right-click:** Alliance encounters. A different shortcut switches an open window; repeating the same shortcut closes it.
- Click leaderboard column headers to sort; click again to reverse. Alias expansion keeps character details under their owner.
- Lifetime, Today, 7 days, 30 days, This week, This month, and This year filters. The 7/30-day periods include today plus the previous 6/29 **UTC calendar days**, not rolling-to-the-second windows. Weeks start Monday.
- Drag to move; position persists. Mouse wheel or Previous/Next pages the rows; Escape closes the window. K/D is `-` when deaths are zero.
- Character names in tables/alerts omit internal realm suffixes. Full identifiers remain intact in saved data and synchronization.
- Alliance encounters has four meaningful headers; the unused fifth column is hidden.

## Guild synchronization

Each guildmate must install/enable the addon. Direct score packets are attributed to the guild-channel sender. The new account protocol also shares **the sender's locally known alts**, not arbitrary cached guild peers. Alt targets must be current guild members; an alt claim cannot overwrite another account's already-known direct binding, and a character's own declaration takes precedence over an inherited claim. Account identities, nickname/alt ownership claims, scores, and account-unique summaries remain **unverified client reports**, not server-authoritative or cryptographically verified ownership.

- Automatic sync at login, world entry, guild changes, personal score changes, alias changes, and every 15 minutes. Manual **Sync guild** or `/gkt sync` is also available.
- Forever blocks addon messages inside instances. Results queue until leaving. Failed sends retain the packet for retry; full history is paced at at most two data packets/second.
- Lifetime totals plus up to 400 days of nonzero daily kill/death totals use cumulative merges, so duplicate/reordered score packets do not double-count.
- Guild caches are account-wide and separated by guild/realm. Current membership is checked. Already-known offline members remain cached; unknown data cannot be recovered from the server. Partial delivery can leave incomplete recent scores until another full exchange.
- Only aggregates/account labels are shared. Names and GUIDs from the private Alliance log are not broadcast. Summing different guildmates' unique encounters is **not** a unique guild-wide Gnome count.
- Older addon versions can still exchange legacy character totals, but must upgrade for alias grouping and expansion.

## Saved data and upgrade

`BIHGGKTDB` remains per-character. New **`BIHGGKTAccountDB`** is account-wide and retains nickname, stable grouping ID, known character records, and shared guild caches. Existing totals migrate by cumulative maximum, not addition, and remain after renaming. Lifetime totals and unique identities persist; dated history is retained for 400 days. Activity before addon installation cannot be reconstructed. Do not edit live SavedVariables while WoW is running.

**For 1.1.0, fully quit and relaunch the client**: this version adds `Accounts.lua` to the TOC and a new account-wide SavedVariable. Then log each existing alt once to import it. No statistics reset is needed.

## Install

Use the release zip, not GitHub's automatically named source directory:

```text
World of Warcraft/_forever_/Interface/AddOns/
  BIHGGnomeKillTracker5000/
    BIHGGnomeKillTracker5000.toc
    Core.lua
    Accounts.lua
    Sync.lua
    Runtime.lua
    UI.lua
```

Enable **BIHG GnomeKillTracker 5000** at character select. New addon folders and TOC load-list upgrades require a full relaunch, not just `/reload`.

## Commands

| Command | Action |
|---|---|
| `/gkt` | Toggle statistics window |
| `/gkt encounters` | Open Alliance encounter log |
| `/gkt sync` | Request/broadcast guild statistics outside instances |
| `/gkt alerts` | Toggle new-Gnome chat alerts |
| `/gkt debug` | Print coverage and last guarded error |

## Verification / development

Lua 5.1-compatible; no embedded libraries/dependencies:

```sh
luajit tests/run.lua .
luajit tests/accounts.lua .
luajit tests/integration.lua .
luac -p Core.lua Accounts.lua Sync.lua Runtime.lua UI.lua
```

Regression tests cover qualification, attribution, duplicate deaths, UTC periods, bounded packets, cumulative sync, account initialization/alt migration, nickname changes/collisions, cross-character encounter uniqueness, and identity exchange. The actual-TOC integration harness covers mocked lifecycle, own-CC/death detection, exact-damage parsing, recap attribution, account profile UI/editing/expansion, view transitions, secret values, and failed/instance-blocked sends. Mocks validate logic and API usage, **not actual client rendering or API visibility**. Tests never write live SavedVariables.
