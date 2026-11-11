# BIHG GnomeKillTracker 5000

**Author: DoHeal** · World of Warcraft: Forever · Interface 16001 / Camelot

Gnome PvP kills, deaths to Gnomes, persistent Alliance encounter memory, and automatic guild leaderboards.

## Chronological encounter history (1.8.4)

Alliance encounter history is always ordered by **last seen, newest first**, regardless of race or the leaderboard's sorting selection. Equal timestamps use character name as a stable tie-break. History headers do not change the leaderboard's sort state. The separate Nearby overlay retains its Gnome-first ordering. Saved history, level/class, targeting and kill/death rules are unchanged.

## Death qualification: harmful debuff or 2% damage (1.8.3)

New own and tracked guild-party/raid deaths count **only after actual death**, when that combat contains **any confirmed Gnome-player-applied harmful debuff (including CC) OR combined effective attributed Gnome-player damage at least 2% of the victim's observed peak maximum health**. Exactly 20 of 1000 qualifies; 19 does not. Faerie Fire, curses, DoTs, bleeds and other harmful debuffs qualify, not only a hard-CC whitelist. A Gnome need not deliver the final blow. Healing does not erase captured proof; dropping max health does not lower the observed peak denominator. Damage excludes readable overkill/mitigation conservatively and is never inferred from shared health loss.

Living `UNIT_AURA` observations and throttled readable `C_UnitAuras` HARMFUL scans capture the caster's readable player GUID and positive native Gnome race for yourself and verified guild party/raid victims, independently of Nearby ON/OFF. Harmful proof needs no known maximum health. Helpful buffs, unknown/secret source/race/aura data, failed casts and aura absence do not qualify; corpse scans cannot grant fresh harmful proof. Optional explicitly supplied DEBUFF applied/refreshed/added-stack events can also prove participation; arbitrary non-damage recap rows cannot. Native CLEU registration remains disabled. Damage-only own deaths can use a readable matching recap; unavailable damage is not invented.

`PLAYER_DEAD` freezes the already-observed incoming harmful proof alongside the original damage/health/combat/life/guild context. Release, resurrection and zoning cannot erase or enlarge that dead life or borrow a later life's CC. Recap and collector proofs are alternatives, never summed. Death-time and commit-time membership/identity must both authorize the same guild; three-second witness deduplication, once-only local `Death to Gnomes recorded` confirmation, four pending contexts, eight-second deadline and last-32 local outcomes remain unchanged. Living combat/life/instance boundaries reset collectors, not frozen pending deaths. Deaths remain eligible in instances; the separate open-world-only kill rule is unchanged. Prior history is neither backfilled nor regraded. The existing diagnostic label “insufficient confirmed Gnome damage” denotes insufficient captured damage without accepted harmful proof, not proof of complete combat coverage.

This policy and encounter metadata ship together as **1.8.3**. No new runtime files, network schema or SavedVariables declaration. Actual-TOC tests cover native unit events and scans with mocked APIs; live native readability, taint/rendering and multi-client delivery still need in-game validation after review/install.

## Persistent encounter level/class (1.8.3)

Alliance encounters now retains readable native level and localized class across reloads and local account alts, even with Nearby OFF. The unchanged-width table shows **Level / Character / Class / Race / Last seen / Days seen** (retained UTC date memberships); hover reveals full identity, level/class and first/last timestamps. Secure targeting still uses the undecorated full name. Missing historical metadata stays **?** until a readable local sighting; native unknown-higher level is **??**, never substituted for an already known numeric level.

Fields merge independently using their own last valid observation timestamp, then deterministic character-provenance/value ties. Unknown, secret or malformed readings cannot erase known data; stale character snapshots cannot roll back newer account knowledge. Kills/deaths, GUID/date unions, Nearby combat targeting, feedback/update notices and sync rules/budgets are unchanged. There is no new enemy-detail network protocol or traffic. No statistics reset or historical class inference. Apply with `/reload` out of combat after review/install; native font truncation, tooltip layout and actual API readability still need in-game validation.

## Local credit feedback and peer update reminders (1.8.2)

- **New personal credit is confirmed locally:** `BIHG: Gnome kill recorded` and `BIHG: Death to Gnomes recorded`, with a readable opponent name when known. These confirm the current character's newly committed credit, **not** personal killing blows or necessarily a Gnome final blow. Guildmate credit, encounters, synchronization, imported/rebuilt totals and replayed corpses do not produce personal success messages. Delayed own-death proof confirms once when committed, including after resurrection; collector/recap duplicates stay silent. Local chat errors cannot undo credit.
- **Observed deaths without personal qualification:** a confirmed hostile Gnome-player corpse in the eligible open world produces `BIHG: Gnome death observed: <name>. You did not qualify for kill credit.` when your contribution was absent or below the existing threshold. Unknown names use `Unknown Gnome`. This adds **no** kills or deaths. Guildmates' damage does not qualify you. A qualifying harmful debuff or at least 2% effective personal damage instead produces the success confirmation after credit commits, never both. Duplicate callbacks share corpse deduplication; a readable fresh living life can be noticed again. Disappearance, living sightings, remote/history records, unverified guild/location/life evidence and incomplete/secret aura evidence cannot manufacture a nonqualification claim; ambiguous cases are skipped conservatively.
- **Conservative uncertainty and life correlation:** unreadable contribution tuples or incomplete corpse aura data suppress negative qualification claims instead of treating unknown participation as zero. After a confirmed resurrection, an ambiguous GUID-only death callback cannot consume the new life merely because time has passed; a readable matching corpse is required. Consequently, a subsequent out-of-view death without sufficient corpse evidence can remain uncredited rather than risk counting an old replay.
- **Peer-reported newer versions:** validated current guild peers advertise the bounded optional `2|V|major.minor.patch` packet during profile/score shares and light minute queries, using the existing queue, pacing, combat pause and rejection backoff. Older clients safely ignore this unknown optional packet. Strict numeric comparison handles `1.10.0 > 1.9.9`; components are canonical decimal integers of at most five digits (no leading zeros, suffixes, extra fields, control characters or remote URLs). Only the existing accepted GUILD sender path plus fresh roster/live same-guild-unit authority may contribute, under the existing sender/global receive caps. Cached membership alone, arbitrary whispers and GUID-bootstrap guesses do not authorize version reports.
- **One account-wide reminder per 15 minutes:** the first accepted higher report prints immediately, then the regular runtime update reminds at most once per **900 seconds** while the highest known peer version remains above the running version. Repeated reports and newly higher reports cannot reset or bypass the deadline. The existing `BIHGGKTAccountDB.versionNotice` stores only `{highest, last}`; serialized reloads and alts retain both the highest version and the last local notice timestamp. Lower/older reports never regress the highest value; installing an equal/newer local version silences it. Clock rollback/future timestamps defer the next notice rather than burst. Malformed/protected state is sanitized, with malformed existing cooldowns conservatively deferred. The timestamp is reserved before local chat callbacks, even if chat fails.

All notifications are **local chat-frame output only**, including during combat: they never call public guild/party/whisper chat. Version information is **client-reported**, not GitHub-verified; there is no HTTP check, downloader, automatic installer or peer-supplied link. Download/review updates from the trusted repository: <https://github.com/7hedubz/BIHGGnomeTracker5000>. Existing participation/death thresholds, history, Nearby secure combat layers, layout and automatic party-alert settings are unchanged. No new runtime files, SavedVariables declarations or TOC load-list entries. Native event readability/rendering and actual peer delivery still require in-game validation after review/install; mocked regressions send nothing to the game.

## Live Nearby rows in combat (1.8.1)

Nearby continues updating new contacts, level/class, Gnome-first sorting, age, expiry and corpse removal during combat. Clear, pause, paging, collapse and visibility controls remain live, at the unchanged 340px window / 332px row widths. **All Nearby contact rows are unclickable and have no hover highlight or tooltip in combat**, including contacts already shown before combat.

After combat, the current displayed identities are rebound before the separate secure click layer is revealed; unused target actions are cleared first. Out of combat, native amber hover feedback, full-name/detail tooltips and hardware click-to-target return. Moving the header hides hit areas until drag-stop alignment is refreshed. Clients without secure state-driver support keep a display-only Nearby list. Combat login defers frame creation until safe.

Kill/death credit, history, synchronization, audio and party-alert policies are unchanged. Actual-TOC regressions exercise restricted hide-only state snippets and protected parent/anchor restrictions; native rendering, taint behavior and exact targeting still require an in-game check after review/install.

## Tracking correctness and workload controls (1.8.0)

- **Low-traffic synchronization:** light queries remain every 60 seconds, but they no longer trigger a lifetime-history replay each minute. Session hints (`2|H|token`) request bounded/coalesced catchup for newly loaded clients; legacy peers retain a 15-minute fallback. Initial load, guild changes, and explicit **Refresh data** / `/gkt sync` can request full catchup. Fresh sightings and ordinary same-guild world entry queue lightweight metadata, not full history. Large first-time catchups can take time.
- **Shared send controls:** addon packets and automatic party alerts share minimum 0.5-second spacing and a 256-byte/second budget with 512-byte capacity. Failed addon sends back off from 2 to at most 60 seconds; malformed packets are quarantined with local diagnostics rather than blocking the entire queue. Combat still pauses outgoing addon data. Incoming work is limited per sender and globally. Party sighting alerts additionally use a four-message allowance replenishing one message per ten seconds; failed public alerts are not retried automatically.
- **Less scan/UI work:** duplicate unit tokens are coalesced where evidence is readable, health-only changes do not repeatedly enumerate unchanged auras, and explicit aura events still process fresh applications. Network updates mark UI state dirty instead of rebuilding it per packet. Hidden dashboards are not redrawn; visible updates are coalesced. Combat-safe bindings, Nearby controls/width, and Personal/Guild date controls remain intact.
- **New lives and debuffs:** a readable new life can accept fresh participation without the old arbitrary two-second lockout. Complete readable aura absence rearms a later application even without instance/expiry metadata; failed/secret/incomplete scans do not establish absence. An unchanged continuous aura never renews credit merely through rescanning or cache aging. Still-readable corpses are inspected before nameplate removal; disappearance alone grants no credit. Same-second or late GUID-only death ambiguity remains conservative.
- **Baseline and identity preservation:** explicit preserved character baselines survive empty account copies. GUID-backed offline-alt metadata and exact roster-derived transport spellings reconcile before applicable name gates; arbitrary sender/GUID or nickname guesses are rejected. Local initialization uses the readable full Forever identity. Distinct GUIDs cannot silently share a legacy owner record; ambiguous originals are archived rather than blindly added or erased. In real snapshot replays, overlapping Damage-character history was archived, while actor-GUID-backed Heal totals were preserved in either login order. Uncertain historical kills are not backfilled.
- **Death recording:** the delayed-death fix described below is included. Original life/guild authority and health/combat evidence are frozen; pending recaps survive location/life transitions, cannot be stolen by another pending life, and never count in a newly joined/different guild. Local bounded outcome diagnostics explain supported rejection reasons.

These changes reduce demonstrated workload and correct reproduced counting defects; they do **not** prove the reported native disconnect cause or guarantee complete restricted-client combat evidence. Real in-game stability, event ordering, protected API behavior, targeting and delivery still require validation. No new runtime Lua files or SavedVariables declarations were added; the existing TOC load list remains unchanged.

## Delayed own-death recording and local outcomes (included in 1.8.0)

`PLAYER_DEAD` freezes the death timestamp, both clock domains, original combat start/end, observed maximum-health peak and any already-sufficient attributed incoming proof. Kill-location refreshes cannot erase this snapshot. A fresh matching recap may arrive after an unknown `IsInInstance()` result, an open-world area event, an actual instance transition, or `PLAYER_ALIVE`/`PLAYER_UNGHOST`. Release resets new-life collectors without editing the prior dead-life context; later combat health/damage cannot supplement it. Recap and collector proofs remain alternatives, never added together.

Pending contexts are session-only, expire after **eight seconds**, and are capped at **four** concurrent attempts. Expiry uses readable monotonic `GetTime()` elapsed duration, falling back to coarse server-time elapsed only when that clock is unavailable; integer epoch event timestamps are used separately for persisted death identity and epoch recap matching. Same-second, fractional-second and 1/2/3-second delayed recaps remain eligible through real release/resurrection callbacks when their life ownership is distinguishable. Overlapping pending windows are checked oldest-first, bounded by actual death timestamps in the recap's clock domain; later-life rows cannot qualify an earlier death. A payload crossing a prior death boundary is rejected, and a boundary-equal timestamp needs a distinct native ID from the one observed at release. If consecutive deaths have indistinguishable timestamps and no identifying release-time recap ID, attribution remains ambiguous and may undercount rather than guess. There are no invented fractional timestamp floors. Only a successfully counted recap is marked consumed. Elapsed time alone never proves resurrection/death or rearms a dead life. The normal half-second runtime update retries/cleans them independently of the initial delayed callbacks. The current recap must still match the frozen fight/time window, and a consumed native recap ID cannot qualify another life. Repeated `PLAYER_DEAD` callbacks in the same life do not create another attempt. Deaths now require **any confirmed harmful Gnome-player debuff OR at least 2% combined effective attributed Gnome-player damage**, followed by actual death; a non-Gnome may deliver the final blow. Death-time guild key, owner name/GUID and membership eligibility are frozen; late proof must also pass current membership gates in that same guild/identity, otherwise the outcome is membership rejection rather than credit to a newly joined guild. Existing three-second witness deduplication gates remain unchanged.

**`/gkt debug` is local-only** and now lists the last **32 own-death attempts** in character SavedVariables, with a timestamp and bounded fixed outcome label: counted, insufficient confirmed Gnome damage, unreadable/missing attribution, stale/unavailable recap, membership rejection, or generic deduplication/validation rejection. A waiting attempt is labeled pending; expiry finalizes its best supported outcome. Readable sub-threshold evidence does not establish complete fight capture; unreadable rows are not mislabeled as a proven exact under-threshold cause. Persisted pending labels become stale/unavailable on the next load because pending proof itself is not saved. Secret/malformed fields and arbitrary saved strings are not printed; these diagnostics are never synchronized or sent to chat channels. Coverage remains a capability flag, not proof that a particular death counted.

This is a targeted recording fix, not a change to kill filtering, Nearby, charts, reporting, sync schemas, historical/peer totals, or the separately audited debuff/rapid-resurrection/baseline/alternate-name undercounts. Partial or unreadable native recaps can still undercount; no proximity, shared-health-loss, pet-ownership or final-blow guesses are substituted. Native event ordering/API readability still need in-game validation. Instance-type transitions are detected only from readable native pairs; same-type instance moves still rely on combat/life boundaries. No new runtime files or TOC load-list changes; apply with `/reload` only after normal review/install.

## Open-world-only new kill credit (1.7.14)

New **locally observed** personal and independently qualified guild-group/pet Gnome kills count only in the open world. Battlegrounds, arenas, dungeons, raids, scenarios and any other instances are excluded. Both participation and confirmed death must be observed in the same uninterrupted eligible world context. The native `IsInInstance()` pair must be readable and exactly `false, "none"`; missing, throwing, secret or inconsistent results fail closed, without guessing from zone names or PvP flags.

World/area/login boundaries clear temporary kill participation and accepted-aura caches **before** scans. Blocked deaths do not mark the kill corpse cache. A fresh, confirmed living world observation after exit can qualify again, including the same opponent GUID/aura; an exit corpse alone cannot revive discarded credit. Incoming-death evidence is independent of this kill filter: **deaths remain eligible everywhere** under the harmful-debuff-or-at-least-2% Gnome contribution rule introduced in 1.8.3. A readable actual world/instance-type change isolates live incoming collectors, but never discards an already-frozen pending death. Unknown native location results and ordinary open-world area events do not reset incoming combat evidence. Fresh instance-side incoming evidence still counts deaths normally. Neither these resets nor the new kill gate erase saved statistics.

**Historical/peer limits:** existing totals have no recorded location and are preserved, not relabeled world-only. Wire schemas, legacy aggregate merging, received guild witness history, replay/adoption and synchronization are unchanged. Receiving a remote event while inside an instance does not invalidate that event. Old clients can still synchronize instance-inclusive observations/totals; **all guild participants should upgrade** to apply the same new local observation policy. This is not a server-enforced or retroactive world-only leaderboard.

Alliance encounter history, Nearby, detection audio/party alerts, instance-side synchronization and authorized out-of-combat reports continue independently. There are no layout, chart/date/report or TOC load-list changes. Apply with `/reload` out of combat after normal review/install. Native API readability, real zone-event ordering and multi-client delivery still require in-game validation; synthetic combat parser tests do not establish a native combat stream. Existing best-effort three-second witnessed-death correlation limits remain.

## Contribution qualification (1.4.0)

Each guild participant independently needs **at least 2% effective attributed damage OR any successfully applied harmful debuff**, followed by a confirmed hostile Gnome-player death within the participation window. This includes Faerie Fire and curses. The lowered threshold and expanded debuff rule apply to new observations; previously unrecorded participation cannot be backfilled. Existing statistics are preserved.

## Guild-only group observation (1.3.0)

- Track **yourself and fellow guildmates in your party/raid**, including controlled pets, even when those guildmates do not have the addon. Verified group guildmates are discovered automatically and appear as individual **[observed]** character entries.
- **Only current guildmates are tallied.** Non-guild party/raid players receive no credit. An unguilded player is not tallied either. The leaderboard, Top 10, personal cards and account kill-time chart filter out non-guild characters. Old saved history is retained rather than deleted.
- Each participant must independently qualify: at least 2% of the Gnome's observed peak maximum health in effective attributed damage **or** any confirmed harmful debuff (including CC), followed by a confirmed death within the participation window. Merely grouping with a killer, casting CC, or seeing health drop is not enough.
- Enemy nameplates, your target/focus/mouseover, and guild group members' target tokens provide observable targets. Aura source GUIDs resolve to guild characters/pet owners. Combat information that is secret or unavailable is skipped.
- **Forever's closed log still matters:** readable own/party debuffs can be observed, but damage-only participation cannot be reconstructed without readable combat-log data. Deaths to Gnomes require any confirmed harmful Gnome-player debuff OR at least 2% combined effective attributed Gnome-player damage against the observed combat peak maximum health, followed by actual death. Readable living victim auras, a matching own death recap or explicitly supplied attributed combat events can provide proof; a corpse, nearby Gnome or final blow alone cannot. A non-addon player's encounter count is unknown (`-`), not invented.
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
- The personal summary and guild leaderboard include **current guild-member characters only**, with no exception for an unguilded active character. The private Alliance encounter log is account-wide local knowledge; personal sighting attribution remains separate.
- An alias's encounter statistic deduplicates the **same Gnome GUID across its characters**. It does not sum daily or character unique counts. Guildmates receive a precomputed account-unique snapshot; stale/missing period data displays `-` instead of inventing a count.

## Important Forever limitation

Forever's installed Spy integration documents a closed combat-log stream. **Exact personal damage attribution cannot be reconstructed from enemy health changes.** The 2% damage rule is implemented when readable combat-log data exists; on a restricted client, damage-only kills cannot be awarded.

The fallback counts **confirmed guild-character/pet debuff + confirmed enemy death** when readable unit/aura APIs expose that information. Unknown/secret data is skipped, never guessed. Out-of-sight auras/deaths cannot reliably be recovered. UI coverage text and `/gkt debug` report coverage. Live-client rendering and real multi-client PvP synchronization still require in-game validation.

## Statistics

- **Gnome kills (new local observations: open world only):** a hostile Gnome player dies within 120 seconds of your last contribution, after you dealt at least 2% of its observed peak maximum health in effective damage or successfully applied any harmful debuff. Current guild player/pet damage and debuffs qualify; overkill is excluded. Cast-success, misses/resists, other players' debuffs and nearby deaths alone do not qualify.
- **Deaths to Gnomes:** actual death after **any confirmed harmful Gnome-player debuff OR at least 2% combined effective attributed Gnome-player damage** against the victim's observed peak maximum health during that combat. Harmful proof needs no known maximum health; a Gnome need not land the final blow, and survival never increments deaths. Unknown/secret source or amount, NPC/pet ownership guesses, stale recaps and health-loss inference do not qualify. Partial records can establish a sufficient lower bound, not prove complete fight coverage. Existing historical and peer-reported totals are not retroactively regraded.
- **Gnomes encountered:** unique Gnome player GUIDs, not scan count. Repeated sightings count once per selected period; lifetime remains unique across reloads and sessions.
- **Alliance log:** saves GUID, name, race, first/last seen, and encounter dates. Gnomes are highlighted and ordered first by default. Detection uses nameplates, target, focus, and mouseover, not radar for units the client has not exposed. Enable enemy nameplates for better coverage. Newly discovered Gnomes optionally trigger chat alerts.

Debuff qualification is **not limited to a spell whitelist**: confirmed harmful effects include CC, Faerie Fire, curses, DoTs, bleeds, slows and other debuffs. Attribution must identify the contributing guild character or their current pet. Readable `DEBUFF` combat-log applications/refreshes/added stacks or source-attributed `HARMFUL` unit auras provide confirmation. Buffs, unknown aura types and cast-success alone do not qualify. An interrupt without an applied harmful aura does not satisfy the debuff branch.

## UI

Open **`/gkt`**, `/gnomekills`, `/bihg`, or use the minimap gear.

### Nearby level/class and ON/OFF checkbox (1.7.15)

- Rows show **level → character name → localized class**, followed by race/age, within the unchanged **340px** window and **332px** rows. Fields stay single-line and truncate to fit; hover shows full name, level, class and race. Unknown metadata displays `?`; the native higher/unknown-level sentinel displays `??`. Secure targeting still uses the actual character name, never the decorated display text.
- The header's saved checkbox is **checked + green ON** when Nearby detection is running, **unchecked + red OFF** when paused. This is separate from hiding the window; pausing leaves the header accessible. It defaults ON and retains an explicitly saved OFF setting.
- OFF clears current Nearby contacts and cancels pending general/Gnome sounds and party sighting announcements. It also suppresses local sighting chat. Re-enabling resumes detection on the next scan without resetting contact-repeat suppression. Explicit sound Preview remains usable.
- This switch **does not pause open-world kill/death recording, persistent encounter history, or guild synchronization**. During combat, the entire Nearby display remains live; all contact targeting/hover hit areas are securely hidden until fresh bindings are ready after combat.
- Automated tests cover actual native scan-to-label wiring, unchanged widths/column order, unknown/secret metadata, row cleanup, checkbox callbacks, saved state, alert cancellation/resume, live display-only combat transitions, and continuing kill recording while Nearby is OFF. Native clipping/readability and checkbox appearance still need an in-game check.

### Spy-style Nearby Alliance window (1.4.0)

A separate compact overlay is enabled by default, independently of the dashboard. Its header shows **Nearby count** and **Gnome count**; when empty/collapsed it remains a small header like Spy's Nearby bar.

- Lists readable **Alliance players**, with **Gnomes always first** and highlighted gold. Other races follow by recency. Repeated target/nameplate detections share one GUID entry; NPCs, pets, Horde and your own character are excluded.
- Uses the existing nameplate, target/focus/mouseover and group-target scans. Explicitly invisible units do not refresh their sighting. This is a **readable/recent sighting list, not a range radar** or proof that an enemy is still present. Entries fade after five seconds without refresh and expire after 30 seconds. Confirmed deaths are removed; world/area changes clear the nearby cache.
- Names omit internal realm suffixes. Rows show race and last-seen age; hover for known level and sighting details. Up to eight rows are displayed per page, with paging controls for longer lists.
- Drag the header to move it; **L/U** locks/unlocks its position. **-/+** collapses/expands, **H** opens the separate historical Alliance encounter log, **< / >** pages, and **X** hides it. Position, lock, collapse and visibility are remembered per character.
- Restore/toggle with **`/gkt nearby`** or **Settings → Nearby overlay**. **`/gkt nearby clear`** clears only this temporary list; persistent encounter history is untouched. Hiding the overlay does not stop tracking or guild sync.
- The overlay supports secure hardware click-to-target out of combat and display-only rows during combat; it never automatically targets or casts. It has no dependency on Spy and does not modify Spy's files/settings.

Nearby opponents are not leaderboard participants. The guild-only qualification/tally rules remain unchanged. Nearby cache contents themselves are not broadcast or rehydrated from historical SavedVariables.

### Character identity repair (1.5.0)

Player GUIDs and per-character SavedVariables provenance reconcile alternate API spellings of the same character. Old name records are archived, their encounter identities and cumulative counters merge conservatively, and witnessed event identities are preserved rather than added twice. The leaderboard uses one physical-character entry per linked GUID; actual different-GUID alts remain separate expandable children under the account nickname. Equal nicknames alone never merge accounts.

Migration runs in the addon at login; do not manually edit live SavedVariables. Log each existing alt in once after this upgrade to establish its GUID. One online guild character then relays its known offline-alt GUID associations as well as their scores. Updated guildmates use the new identity packets to combine observed and declared name variants; older clients must upgrade for this reconciliation. Guild identity/statistics are still client-reported, not cryptographic ownership verification.

### Personal and Guild daily chart scopes (1.7.16)

- **Charts → Kills over time** has **Personal** and **Guild** buttons. Personal shows recorded daily credit for your account's current guild-member characters. Guild adds recorded/synced current guild-member credit, including effective witnessed kills for members without the addon. The selected button is highlighted and saved; older profiles default to Personal.
- Both scopes work with **every PERIOD**, the UTC From/To dates, and both slider handles. Scope changes preserve valid custom endpoints and clamp them to available bounds; a full-range selection follows the new scope's full bounds. Lifetime starts at the oldest retained daily activity in the selected scope, up to 400 days.
- Guild is a **sum of member kill credit**, not unique enemy deaths. Several qualifying members credited for one Gnome contribute several member credits. It uses the existing per-character effective records, with local characters overriding cached self echoes rather than counting them twice. It is cached recorded data, not a guarantee that every guild kill was observed or synchronized.
- Zero-fill daily recorded buckets; do not distribute lifetime-only totals into unknown dates. Guild/Personal selection affects only the daily graph, not account summary cards, Top 10 rankings, reports, saved statistics, authority, or network sends. Existing world-credit policies and previously audited undercount issues are unchanged by this chart-only release.

### Chart dates and PERIOD-bounded range slider (1.7.13)

- In **Charts → Kills over time**, enter **From** and **To** as `YYYY-MM-DD` UTC dates and click **Apply dates** or press Enter. Both endpoint days are included. Invalid, reversed, or out-of-PERIOD dates display an error and leave the last valid chart unchanged.
- Drag the **upper amber start handle** and **lower blue end handle** to change the first and last displayed day. Handles cannot cross. Their vertical offset lets you grab either handle even when both dates are the same.
- The slider's outer dates come from **PERIOD**: Today, rolling 7/30 days, current Monday-based UTC week, current UTC month/year, or Lifetime. Lifetime begins at the oldest retained daily kill/death record of your guild-member characters; no daily history means today only. Daily storage remains bounded to 400 days. The old additional 30-day plotting cap is removed.
- Selecting PERIOD resets the handles to its full range. Manual date selections are session-only. An untouched full range follows UTC day rollover; a custom selection is kept within updated bounds. Unapplied edits survive normal refreshes; Escape restores the actual chart dates.
- These controls change only the selected Personal/Guild daily time chart, not leaderboard/ranking/report period filters, saved scores, or guild messages. Dates with no retained recorded kills display zero recorded kills. Legacy lifetime totals cannot be backfilled into unknown dates.
- Combat/menu closure releases date-field focus and ends dragging. Native visuals and mouse behavior still require the normal in-game check; automated coverage exercises UTC calendars, long ranges, both scaled-UI drag paths, invalid input, edit preservation, and combat closure.

### Separate copy/cut report and direct guild-post actions (1.7.12)

**Copy report...** opens a local editable multiline report, using the selected period and the same ranked alias report builder as direct posting. Each person occupies a separate text line. Text starts selected and focused: **Ctrl+C copies**, **Ctrl+X cuts**, and Select all selects it again. Editing/cutting affects only the export box, never saved scores, source data or active guild-post progress. No messages are sent, no public-post cooldown is consumed, and no posting job is created by export. Local export does not require the officer-only direct-post rank.

**Post to guild... remains a separate action**, preserving preview, exact authorized ranks, one line per physical click, spacing, cooldown and failure/cancellation rules. Both actions are available on leaderboard/charts alongside Refresh data. Copying an export does not cancel a direct report already in progress.

The export closes and releases keyboard focus on Close, Escape or main-window/combat auto-close. It does not write the OS clipboard directly: the normal native edit-box keyboard shortcuts perform cut/copy. When manually pasting into in-game chat, paste/send individual lines; do not assume one multiline clipboard paste becomes several chat messages. All data and transport behavior are otherwise unchanged. Apply with `/reload` out of combat; no load-list changes. Native clipboard interaction still needs the normal in-game check.

### Historical Gnome contribution-based deaths (1.7.11; superseded by 1.8.3)

The following describes the historical 1.7.11 policy, **not the current threshold**. At that release, new locally recorded deaths used **strictly more than half observed combat maximum health in confirmed Gnome-player damage**, combined across Gnomes, followed by actual death. A non-Gnome finishing blow no longer prevents a qualifying count; a tiny Gnome finishing blow no longer suffices. Readable overkill and mitigation are conservatively excluded. Healing does not erase confirmed damage already dealt; this is a fraction of maximum health, not a majority of all incoming damage.

Own deaths use a fresh death recap with source GUIDs, damaging-event types, timestamps, amounts and readable max health (GetRecapMaxHealth where available, otherwise observed own max health). Observed combat health peaks prevent a buff/health drop from lowering the threshold. Epoch and monotonic recap timestamps are normalized, already-consumed recap IDs cannot qualify a later life, and stale combat/unknown evidence is rejected. Final-blow-only fallback is removed.

Optional readable combat-event input tracks guild group victims separately, with combat-boundary resets and peak-health sampling. Native CLEU registration remains disabled on this client; explicit/synthetic parser tests do not claim a live combat stream. Group deaths now deduplicate by victim/time window rather than requiring observers to choose the same contributing Gnome. The event's opponent GUID is a qualifying contributor, not necessarily the killer. Recap and event-stream evidence are never added together, preventing overlap double counting.

**Availability:** a truncated recap or blocked combat stream can miss a qualifying death. Only readable lower-bound evidence above the threshold is counted; health loss, proximity and unknown damage are not substituted. Prior saved history remains unchanged, and older peers' already-reported totals remain unverified legacy data, not automatically recalculated under the new policy. Upgrade guild clients for consistent new recording rules.

Tests cover strict boundaries, combined Gnomes/non-Gnome final blows, overkill/mitigation, hidden/secret/malformed values, stale/new-combat isolation, health-peak drops, replayed recap IDs, both timestamp domains, duplicate death events and differing witness contributor choices. Apply with `/reload` out of combat; there are no new runtime Lua files or load-list changes. Actual native recap readability still requires in-game validation.

### Clickable-name hover feedback (1.7.10)

Clickable rows now show a translucent amber highlight under the mouse: the guild leaderboard and Alliance history highlight the full clickable row, the top-killers chart highlights its clickable name area, and Nearby highlights its contact row. The highlight uses the native button highlight texture, so it follows the actual hit area and clears on mouse leave/hide rather than becoming a persistent selection.

Textures are prepared out of combat during normal frame construction. Native hover feedback does not replace secure OnClick or tooltip scripts, modify macros/target attributes, alter frozen combat rows, or cast/attack. Account-group expansion and exact-character targeting behavior are unchanged. Actual-TOC regressions verify highlight attachment/geometry/opacity on all three clickable surfaces, and targeting tests guard combat setup and preservation of existing scripts. Mock tests do not prove native visual appearance; check after `/reload` out of combat. No load-list, statistics or synchronization changes.

### Kills-and-deaths leaderboard (1.7.9)

The main summary now has two wider cards: **Your Gnome kills** and **Deaths to Gnomes**. The guild leaderboard shows only **Alias / character**, **Kills** and **Deaths**, with the released space given back to those columns. The Encountered and K/D metrics and their board sorting controls are removed from this UI; alias expansion, character targeting, periods, kill/death sorting, charts, reports and the compact footer/version remain.

The separate **Alliance encounters** view now shows Level/Character/Class/Race/Last seen/Days seen, including account-wide shared history; First seen remains in its tooltip. Sightings, existing totals, identity metadata, guild event ledgers and compatibility sync packets are not deleted or reset. This is a display-only change, not a remote identity-reconciliation fix. Actual-TOC tests cover the two-card/three-column layout and both directions of transitions to the six-field encounter view so hidden dates do not leak into the leaderboard. Apply with `/reload` out of combat; no load-list changes.

### Compact status footer and visible version (1.7.8)

The main window footer now keeps only the current descriptive sync state (for example, **Send blocked / retrying**) and guild-membership status. Automatic-sync policy, report-rank boilerplate, tracking coverage prose and the sent-status disclaimer are removed from this footer. Report attempts/errors still appear in local confirmation feedback, and full coverage/report diagnostics remain available through `/gkt debug`.

The loaded Lua version is shown in the **bottom-right corner**. The version label and debug output use the same Core version constant; actual-TOC integration asserts that it matches the packaged TOC and is bottom-right anchored. No transport, identity reconciliation, scoring or report behavior is changed. In particular, this footer update is **not a fix for duplicate remote character identities**. Apply with `/reload` out of combat; the load list is unchanged.

### Shared local cache across characters (1.7.7)

The persistent Alliance encounter history now shows a **GUID-deduplicated account-wide local knowledge cache**, not just the active character's personal sightings. On load it imports the already-saved sightings of initialized local characters; future sightings update the shared cache immediately. Earliest/latest timestamps and daily presence are merged, and newer names/races cannot be rolled back by loading an older character file. Personal sighting attribution, per-character kills/deaths and guild witness event credit stay separate: shared knowledge is not shared kill credit. Nearby remains a separate live/recent overlay, not the full historical list.

Guild records and witnessed kill/death events were already account-wide. A fresh alt with no character-local lastGuild can now display existing same-realm guild history **read-only**, including derived observed scores, account totals and charts, without waiting to redownload it. A verified guild selection is remembered per realm; before that preference exists, fallback is allowed only for one unambiguous same-realm cached guild. Conflicting/cross-realm caches are not arbitrarily combined. Cached membership still excludes confirmed departures; opening the view does not make the alt a guild member.

The cached view never sets the live guild identity. Public reports, incoming/outgoing guild sync, and new guild contribution credit retain their existing live guild/membership gates. New verified guild information selects the active scope normally, and subsequent local/network updates use the same account cache. No live SavedVariables are edited by installation. Existing offline characters contribute their old character-only data when next logged in; files not loaded by the game cannot be imported through addon Lua.

The shared-cache regression suite serializes/clones account data between fresh addon namespaces, checks main-to-alt-to-third-character updates, metadata freshness, separate ownership, witness-ledger totals, read-only authorization/transport isolation, and same-realm cache selection. Actual-TOC UI tests check shared sightings and cached-view labeling. A read-only replay of the real Pallydo snapshot exposed all **213 known Alliance identities** and all **five leaderboard groups** with unchanged scores and unchanged personal attribution through three migration passes; source SavedVariables hashes stayed unchanged. Apply with **/reload**; no TOC load-list changes. Native character switching still needs the normal in-game check.

### Ordered manual guild-report posting (1.7.6)

**Send one line per physical click.** Open Post Top 10 to Guild, click **Send heading**, wait for that message to appear in guild chat, then use the same button to send **#1**, **#2**, and so on. The button shows the next ranked player and line position; the preview shows how many lines were attempted. There is a one-second minimum between attempts, using the monotonic GetTime clock when available, to prevent double-click bursts. Waiting for the prior line to actually appear is still the user's responsibility; the addon does not pretend to acknowledge delivery.

The native 1.7.5 burst reached guild chat, but its separate messages displayed out of order. This replaces that burst with exactly one synchronous native send per explicit action. There is no timer/OnUpdate/chat-event sending or automatic retry. The report is frozen to the preview snapshot; receiving new stats or reopening the preview cannot reshuffle a report in progress. The final attempt closes the preview.

Cancel, Escape/preview closure, and combat-entry menu auto-close discard remaining manual progress. Each next click rechecks combat, guild, exact authorized rank, and a five-minute snapshot expiry. New reports retain the 60-second cooldown; continuing an existing report does not restart it. API failures or captured native protection blocks stop the session. Closing/reloading never resumes unsent lines. Silent automatic addon-data sync is unchanged.

Tests cover one header per first click, one ranked line per subsequent click, progress labels, duplicate-click spacing (including fractional GetTime across an integer server-time boundary), frozen snapshots, completion, manual/combat cancellation, expiry, guild/rank changes, API errors and native blocks. Actual-TOC tests reject sends outside click context and assert that idle update ticks never send. All public sends are mocked. Apply with **/reload out of combat**; the load list is unchanged. Native ordered display still requires the normal in-game check using the wait-for-visible-line workflow.

### Send guild reports directly from confirmation (1.7.5)

**Post to /guild now attempts all previewed lines synchronously in the confirmation button's click handler**, using a bounded loop (one heading plus up to ten separate ranking lines). There is no public-report timer queue, OnUpdate send, deferred combat resume or automatic retry. This supersedes the report pacing/queue behavior documented for earlier versions; silent addon-data sync is unchanged and remains paced/out-of-combat.

Native diagnosis: the protected-action stack reached SendChatMessage from PumpTopPost/OnUpdate. A user-run direct `/run` guild-send test delivered; the same call delayed by C_Timer.After did not, even though both returned `pcall=true, result=nil`. Keep native guild sends in the confirming action's call stack rather than moving them to background callbacks. Native behavior of the full multi-line button send still needs an in-game check, including any server burst limits.

Preview, exact Council of BIHG / The BIHG Cheese authorization, current guild/combat checks, line limits and 60-second cooldown remain. Authorization/combat/guild are checked again before each line. A readable API failure or a protected-action event captured during a send stops the remaining lines with no background resume. Diagnostics record `mode=direct-click`; the status says **delivery unconfirmed** because a nil/zero API result is not a server acknowledgement. A partially attempted report is never automatically retried.

Regression tests invoke the actual confirmation handler with a mock that rejects guild sends outside that click's call stack, assert all previewed lines were attempted before return, then run actual update ticks and assert no extra sends. Other tests cover cooldown, ranks, in-burst rank/combat changes, API failure/fallback and native protection events. All public chat APIs are mocked in tests; no guild test messages are sent by the tooling. Apply with `/reload` out of combat; the TOC load list is unchanged. Combat-entry menu auto-close from 1.7.4 remains.

### Close the main menu on combat entry (1.7.4)

The large dashboard/config window automatically closes when combat starts, including its report preview and sound-picker popup. It stays closed when combat ends; reopen with the minimap button or `/gkt`. The independent Nearby overlay, tracking and configured party detection alerts remain active, and outgoing guild queues retain their existing combat pause/resume policy.

The window uses **SecureHandlerStateTemplate** with a pre-registered custom combat state driver that only hides on entry. This avoids an insecure Hide call on a protected target-button ancestor during lockdown, and unlike a hide/show visibility driver it does not force the menu open after combat. Apply with `/reload` out of combat. Native client behavior still needs an in-game check; mocked state transitions and popup cleanup are regression-tested. This change is not a guild-message-delivery fix.

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
- Main dashboard protected rows remain unavailable during combat. Nearby instead keeps its unprotected display and controls live, with every contact hit area securely hidden: no contact clicks or hover highlights until fresh bindings are prepared after combat. Tracking/sounds continue. Opening/switching the main views is unavailable during combat.
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

**Charts** contains a horizontal Top 10 guild-alias kill ranking and a **Kills over time line graph**. The line shows recorded daily kills for the selected **Personal** (your account) or **Guild** (current guild-member credit) scope: **X = UTC date/time, Y = kills per day**. Numeric Y-axis ticks start at zero, date ticks run from oldest to newest, and hovering a point shows its exact date/count. This is daily activity, not a cumulative lifetime-total curve. A single-day view shows one point rather than an invented time segment.

The line shows the inclusive UTC date window selected by the chart's date fields or two-handle slider, bounded by PERIOD and retained daily history (up to 400 days). PERIOD initially displays its full range; Lifetime begins at the oldest retained guild-member daily activity for the selected Personal/Guild scope. Guild rankings use cached reports; empty rankings show an explicit no-data message rather than fictional zero-score leaders. Version 1.2.1 replaced daily kill/death bars with this kills-only line graph; 1.7.13 removes its former extra 30-day display cap.

### Send the Top 10 to guild chat

Only the exact current guild ranks **`Council of BIHG`** and **`The BIHG Cheese`** may see/use **Post Top 10 to Guild...**. There is no generic officer/guild-master override. Unreadable rank/guild data denies access. The preview/slash command, confirmation, and each queued send enforce authorization; losing eligibility stops the remaining report. Other members still receive normal automatic data synchronization. This is an addon UI/report restriction, not a server-side ban on manual guild chat; guildmates must install this version to receive the restriction.

On Guild leaderboard or Charts, an eligible member selects a period and clicks **Post Top 10 to Guild...** (or `/gkt top`). Review the exact report, then **Post to /guild** or Cancel. It ranks **aliases**, combining their guild characters, by kills regardless of the table's current sort/expansion state. Fewer than ten aliases with recorded kills produces a shorter list; an empty period is reported honestly.

The report uses cached addon scores, says so in its heading, and is readable in regular guild chat even without the addon. Posting is **never automatic**. Confirmed reports are paced at one chat line per second, limited to once per minute, and only sent out of combat. Combat pauses remaining lines; a guild change, timeout or failed send stops the report rather than retrying potentially duplicate public messages. A successful API call only confirms handoff to the chat API, not server delivery. Legacy and namespaced chat APIs are supported.

- Minimap **left-click:** guild leaderboard. **Right-click:** Alliance encounters. A different shortcut switches an open window; repeating the same shortcut closes it.
- Click leaderboard column headers to sort; click again to reverse. Alias expansion keeps character details under their owner.
- Lifetime, Today, 7 days, 30 days, This week, This month, and This year filters. The 7/30-day periods include today plus the previous 6/29 **UTC calendar days**, not rolling-to-the-second windows. Weeks start Monday.
- Drag to move; position persists. Mouse wheel or Previous/Next pages the rows; Escape closes the window. K/D is `-` when deaths are zero.
- Character names in tables/alerts omit internal realm suffixes. Full identifiers remain intact in saved data and synchronization.
- Alliance encounters has six meaningful headers; history-only columns are hidden and cleared when returning to the leaderboard.

## Guild synchronization

At least one observer must run the addon to witness grouped guildmates. Guildmates need it themselves for account aliases, their own full-coverage reports and receiving the synced UI, but not for witnessed group credit. Direct score packets are attributed to the guild-channel sender. Account snapshots share **the sender's locally known alts**, not arbitrary cached aggregate peer totals; event-level guild observations may be relayed separately. Alt targets must be current guild members; conflicting direct account bindings are rejected. Account identities, ownership claims, statistics and witness events remain **unverified client reports**, not server-authoritative or cryptographically verified ownership.

- Automatic lightweight updates at world entry and score/sighting changes, with a light query every minute. Initial load, guild changes, peer-session catchup and explicit **Refresh data** or `/gkt sync` can request paced history. Repeated minute queries do not replay all history. These silent addon packets do not post a chat report.
- Outgoing sync is attempted anywhere, including dungeons/raids/battlegrounds, while out of combat. Combat pauses the queue without advancing it; it resumes afterward. Failed/rejected addon sends retain valid packets with capped exponential retry backoff. Full history shares the application-level message/byte budget with automatic party alerts; invalid packets are explicitly quarantined, never marked sent. Actual client/server API restrictions still apply: API acceptance is not proof of remote delivery.
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
luajit tests/encounters.lua .
luajit tests/encounter_metadata.lua .
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
