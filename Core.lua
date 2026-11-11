local _, A = ...
A.VERSION='1.8.5'
-- Local-only feedback; a broken chat widget must never invalidate credit.
function A.LocalNotice(text)
 if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage)=='function'then pcall(DEFAULT_CHAT_FRAME.AddMessage,DEFAULT_CHAT_FRAME,'|cffffb347BIHG:|r '..text)end
end
function A.OpponentName(guid)
 local name
 local function readable(v)return not(A.Secret and A.Secret(v))end
 if readable(guid)and type(guid)=='string'then
  local r=A.db and A.db.seen and A.db.seen[guid]
  if r and readable(r.name)then name=r.name end
  if not name and type(GetPlayerInfoByGUID)=='function'then
   local ok,_,_,_,_,_,n,realm=pcall(GetPlayerInfoByGUID,guid)
   if ok and readable(n)and readable(realm)and type(n)=='string'then name=n end
  end
 end
 if not readable(name)or type(name)~='string'or #name>128 or name:find('[%c|]')then return nil end
 return name
end
function A.CreditNotice(kind,guid)
 local name=A.OpponentName(guid)
 A.LocalNotice((kind=='K'and'Gnome kill recorded'or'Death to Gnomes recorded')..(name and(': '..name)or''))
end
function A.NonqualifyingDeathNotice(guid,e,confirmed,now)
 if confirmed~=true or not e.living or e.creditUnknown or not e.hp or e.hp<=0
  or now<e.living or now-e.living>A.WINDOW
  or not A.guildKey or A.guildUnverified or not(A.members and A.members[A.owner])then return end
 A.LocalNotice('Gnome death observed: '..(A.OpponentName(guid)or'Unknown Gnome')..'. You did not qualify for kill credit.')
end
A.RETENTION = 400
A.DAMAGE_FRACTION = 0.02
-- IsInInstance has two independent returns; Safe intentionally keeps only one.
-- Never infer world from a missing, protected, or contradictory return.
local function openWorld()
 if type(IsInInstance)~='function' then return false end
 local ok,inside,kind=pcall(IsInInstance)
 if not ok then return false end
 local function readable(v)
  if type(issecretvalue)~='function' then return true end
  local good,hidden=pcall(issecretvalue,v)
  return good and hidden==false
 end
 if not readable(inside) or not readable(kind) then return false end
 return type(inside)=='boolean' and inside==false and type(kind)=='string' and kind=='none'
end
function A.RefreshKillLocation(boundary)
 local allowed=openWorld();local previous=A.killLocation
 if boundary or previous~=allowed or not allowed then
  A.encounters={};A.groupTargets={};A.auras={};A.auraPoll={};A.killLifeAfter={}
  -- Retain saved corpse dedup until a readable living observation proves a
  -- new life. A corpse on login/exit must never rearm the same old death.
  A.killBoundaryDead=A.killBoundaryDead or {}
  for guid in pairs(A.db and A.db.dead or {})do A.killBoundaryDead[guid]=true end
 end
 A.killLocation=allowed
 return allowed
end
function A.OpenWorldKillsAllowed()return A.RefreshKillLocation(false)end
function A.ObserveKillLife(g,dead,now)
 if dead~=false or A.killAwardActive then return end
 local previous=A.db.dead[g]
 if previous and (not now or now<=previous) and not(A.killBoundaryDead and A.killBoundaryDead[g])then return end
 if previous then
  -- Readable living state rearms observation, not credit. A new encounter
  -- starts empty and still needs fresh attributable participation.
  A.killLifeAfter=A.killLifeAfter or {};A.killLifeAfter[g]=previous
  A.db.dead[g]=nil
  if A.auras then A.auras[g]=nil end
  if A.auraPoll then A.auraPoll[g]=nil end
 end
 if A.killBoundaryDead then A.killBoundaryDead[g]=nil end
end
A.frames = {'Lifetime','7 days','30 days','Today','This week','This month','This year'}
function A.Day(t) return math.floor(t / 86400) end
function A.Init(db, owner, now)
 db.version=1; db.owners=db.owners or {}; db.dead=db.dead or {}; db.options=db.options or {}
 A.db=db; A.owner=owner; A.now=now
 db.owners[owner]=db.owners[owner] or {total=0,days={}}
 A.encounters={};A.killLifeAfter={};A.auraPoll={}
 local records={}
 for _,r in pairs(db.owners) do records[#records+1]=r end
 for _,guild in pairs(db.guilds or {}) do for _,r in pairs(guild) do records[#records+1]=r end end
 for _,r in ipairs(records) do
  r.days=r.days or {};r.deathDays=r.deathDays or {}
  for _,buckets in ipairs({r.days,r.deathDays}) do
   for d in pairs(buckets) do if tonumber(d)<A.Day(now)-A.RETENTION+1 then buckets[d]=nil end end
  end
 end
 for g,t in pairs(db.dead) do if now-t>86400 then db.dead[g]=nil end end
 A.PruneEncounters(now,true)
end
function A.Award(now)
 if not A.OpenWorldKillsAllowed() then return false end
 local r=A.db.owners[A.owner]; local d=A.Day(now)
 r.total=r.total+1; r.days[d]=(r.days[d] or 0)+1
 if A.Changed then A.Changed() end
 return true
end
local deathDamageEvents={SWING_DAMAGE=true,RANGE_DAMAGE=true,SPELL_DAMAGE=true,SPELL_PERIODIC_DAMAGE=true,DAMAGE_SHIELD=true}
local function deathSecret(v) return A.Secret and A.Secret(v) end
local function deathTable(v)
 return not deathSecret(v) and type(v)=='table' and not (issecrettable and issecrettable(v))
end
local function deathNumber(v)
 return not deathSecret(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function deathPlayer(v)
 return not deathSecret(v) and type(v)=='string' and v:match('^Player%-.+')~=nil
end
local function deathMitigation(v,overkill)
 if deathSecret(v) then return nil end
 if v==nil then return 0 end
 if not deathNumber(v) or (not overkill and v<0) then return nil end
 return math.max(0,v)
end
local function deathRow(e,deathTime,combatStart)
 if not deathTable(e) then return end
 local event,t,g,amount,hidden=e.event,e.timestamp,e.sourceGUID,e.amount,e.hideCaster
 if deathSecret(event) or type(event)~='string' or not deathDamageEvents[event]
  or not deathNumber(t) or t<combatStart or t>deathTime+1
  or not deathPlayer(g) or not deathNumber(amount) or amount<0
  or deathSecret(hidden) or (hidden~=nil and hidden~=false) then return end
 local overkill=deathMitigation(e.overkill,true)
 local absorbed=deathMitigation(e.absorbed)
 local resisted=deathMitigation(e.resisted)
 local blocked=deathMitigation(e.blocked)
 if not overkill or not absorbed or not resisted or not blocked then return end
 if type(A.Race)~='function' then return end
 local ok,race=pcall(A.Race,g)
 if not ok or deathSecret(race) or type(race)~='string' or race=='' then return end
 if race~='Gnome' then return nil,0,true end
 return g,math.max(0,amount-overkill-absorbed-resisted-blocked),true
end
local deathAuraEvents={SPELL_AURA_APPLIED=true,SPELL_AURA_REFRESH=true,SPELL_AURA_APPLIED_DOSE=true}
local function deathHarmfulRow(e,deathTime,combatStart,sourceRace)
 if not deathTable(e) then return end
 local event,t,g,spell,aura,hidden=e.event,e.timestamp,e.sourceGUID,e.spellId,e.auraType,e.hideCaster
 if deathSecret(event) or type(event)~='string' or not deathAuraEvents[event]
  or not deathNumber(t) or t<combatStart or t>deathTime+1 or not deathPlayer(g)
  or not deathNumber(spell) or spell<1 or spell%1~=0 or deathSecret(aura) or aura~='DEBUFF'
  or deathSecret(hidden) or(hidden~=nil and hidden~=false)then return end
 if deathSecret(sourceRace)then return end
 if sourceRace~=nil then if sourceRace=='Gnome'then return g end;return end
 if type(A.Race)~='function'then return end
 local ok,race=pcall(A.Race,g)
 if ok and not deathSecret(race)and race=='Gnome'then return g end
end
function A.GnomeHarmfulEvidence(row,t,start,race)
 if not deathNumber(t)or not deathNumber(start)or start>t then return end
 local source=deathHarmfulRow(row,t,start,race)
 if source then return {damage=0,source=source,time=t,harmful=true}end
end
function A.GnomeDeathEvidence(events,maxHealth,deathTime,combatStart)
 if not deathTable(events)
  or not deathNumber(deathTime) or not deathNumber(combatStart) or combatStart>deathTime then return nil end
 local health=deathNumber(maxHealth)and maxHealth>0 and maxHealth or nil
 local total,sources,harmful,overflow=0,{},nil,false
 local rows,unreadable=0,false
 for _,e in pairs(events) do
  local guid,damage,confirmed=deathRow(e,deathTime,combatStart)
  local applied=deathHarmfulRow(e,deathTime,combatStart)
  if applied and(not harmful or applied<harmful)then harmful=applied end
  rows=rows+1;if not confirmed and not applied then unreadable=true end
  if guid then
   total=total+damage
   if not deathNumber(total) then overflow=true end
   sources[guid]=(sources[guid] or 0)+damage
  end
 end
 if harmful then return {damage=0,maxHealth=health,source=harmful,time=deathTime,harmful=true}end
 if overflow then return nil end
 if not health or total<health*A.DAMAGE_FRACTION then
  if rows==0 then return nil end
  return nil,unreadable and 'unreadable/missing attribution' or 'insufficient confirmed Gnome damage'
 end
 local source,best=nil,0
 for guid,damage in pairs(sources) do
  if damage>best or (damage==best and (not source or guid<source)) then source,best=guid,damage end
 end
 return {damage=total,maxHealth=maxHealth,source=source,time=deathTime}
end
function A.ValidGnomeDeathEvidence(proof,now)
 if not deathTable(proof) or not deathNumber(now) then return false end
 local damage,hp,source,time=proof.damage,proof.maxHealth,proof.source,proof.time
 if not deathPlayer(source) or not deathNumber(time) or time~=now or deathSecret(proof.harmful)then return false end
 if proof.harmful==true then return deathNumber(damage)and damage>=0 end
 return deathNumber(damage) and damage>0 and deathNumber(hp) and hp>0
  and damage>=hp*A.DAMAGE_FRACTION
end
function A.PlayerDeath(id,race,now,killer,proof)
 if not A.ValidGnomeDeathEvidence(proof,now) or deathSecret(killer) or killer~=proof.source then return false end
 if A.GroupOwnDeath then return A.GroupOwnDeath(id,race,now,killer,proof)end
 if deathSecret(race) or race~='Gnome' or deathSecret(id) or type(id)~='string' then return false end
 A.db.recaps=A.db.recaps or {}
 if A.db.recaps[id] then return false end
 A.db.recaps[id]=now
 for k,t in pairs(A.db.recaps) do if now-t>86400 then A.db.recaps[k]=nil end end
 local r=A.db.owners[A.owner]; r.deaths=(r.deaths or 0)+1
 r.deathDays=r.deathDays or {}; local d=A.Day(now)
 r.deathDays[d]=(r.deathDays[d] or 0)+1
 A.CreditNotice('D',killer)
 if A.Changed then A.Changed() end
 return true
end
function A.Score(r,frame,now,metric)
 if metric=='deaths' then r={total=r.deaths or 0,days=r.deathDays or {}} end
 if frame=='Lifetime' then return r.total end
 local today=A.Day(now); local first=today
 if frame=='7 days' then first=today-6
 elseif frame=='30 days' then first=today-29
 elseif frame=='This week' then first=today-((today+3)%7)
 elseif frame=='This month' or frame=='This year' then
  local dt=os and os.date and os.date('!*t',now) or date('!*t',now)
  if frame=='This month' then first=today-dt.day+1 else first=today-(tonumber((os and os.date or date)('!%j',now))-1) end
 end
 local n=0; for d,v in pairs(r.days) do if tonumber(d)>=first and tonumber(d)<=today then n=n+v end end; return n
end
A.WINDOW=120
function A.Observe(g,race,hostile,hp,now,dead)
 if not A.OpenWorldKillsAllowed() then return end
 if type(g)~='string' or not g:match('^Player%-') or race~='Gnome' or hostile~=true then return end
 A.ObserveKillLife(g,dead,now)
 if A.db.dead[g] then return end
 local e=A.encounters[g]
 if not e or (e.last and now-e.last>A.WINDOW) then e={damage=0}; A.encounters[g]=e end
 e.seen=now; e.race=race; e.hostile=true;if dead==false then e.living=now end
 if type(hp)=='number' and hp>0 then e.hp=math.max(e.hp or 0,hp) end
end
function A.Damage(g,amount,overkill,own,now)
 if not A.OpenWorldKillsAllowed() then return end
 local e=A.encounters[g]
 if not e or not own or type(amount)~='number' or amount<0 then return end
 if e.last and now-e.last>A.WINDOW then e.damage=0; e.cc=nil end
 e.damage=e.damage+math.max(0,amount-math.max(0,tonumber(overkill) or 0)); e.last=now
end
function A.Death(g,now,corpseConfirmed,deathConfirmed)
 if not A.OpenWorldKillsAllowed() then return false end
 if corpseConfirmed~=true and A.killLifeAfter and A.killLifeAfter[g]then
  if not(A.ReadableKillCorpse and A.ReadableKillCorpse(g))then return false end
  corpseConfirmed=true
 end
 local e=A.encounters[g]; A.encounters[g]=nil
 if not e or A.db.dead[g] then return false end
 if not e.last or now-e.last>A.WINDOW then
  if corpseConfirmed==true or deathConfirmed==true then A.db.dead[g]=now;A.NonqualifyingDeathNotice(g,e,true,now)end
  return false
 end
 if A.auras then A.auras[g]=nil end
 local qualified=e.cc or (e.hp and e.damage>=e.hp*A.DAMAGE_FRACTION)
 -- Reserve the corpse before Award invokes synchronous Changed callbacks.
 A.db.dead[g]=now
 if qualified then
  A.killAwardActive=true;local awarded=A.Award(now);A.killAwardActive=nil
  if not awarded then A.db.dead[g]=nil;return false end
  A.CreditNotice('K',g)
 else A.NonqualifyingDeathNotice(g,e,corpseConfirmed==true or deathConfirmed==true,now)
 end
 return qualified and true or false
end
-- Legacy known-effect helper; live parsers may confirm any harmful aura.
A.CCSpells={}
for _,id in ipairs({118,12824,12825,12826,28271,28272,61305,61721,61780,20066,
853,5588,5589,10308,408,8643,1833,1776,1777,8629,11285,11286,2094,
6770,2070,11297,3355,14308,14309,19386,24132,24133,19503,1513,14326,14327,
5782,6213,6215,5484,17928,6789,17925,17926,6358,710,18647,
8122,8124,10888,10890,605,10911,10912,9484,9485,10955,
339,1062,5195,5196,9852,9853,2637,18657,18658,5211,6798,8983,
9005,9823,9827,22570,18469,15487,24259,19244,19647,1330,
122,865,6131,10230,12494,33395,16979,20253,20614,20615,11578,7922,
5246,20549,12355,12809,
770,778,9749,9907,16857,17390,17391,17392}) do A.CCSpells[id]=true end
function A.CC(g,id,own,now,harmful)
 if not A.OpenWorldKillsAllowed() then return false end
 local e=A.encounters[g]
 if not e or not own or type(id)~='number'or id<1 or id%1~=0 or harmful==false or(not A.CCSpells[id]and harmful~=true)then return false end
 if e.last and now-e.last>A.WINDOW then e.damage=0 end
 e.cc=true; e.last=now; return true
end
function A.FirstDay(frame,now)
 local today=A.Day(now)
 local date=date or (os and os.date)
 if frame=='Lifetime' then return -1 end
 if frame=='7 days' then return today-6 elseif frame=='30 days' then return today-29 end
 if frame=='This week' then return today-((today+3)%7) end
 if frame=='This month' then return today-tonumber(date('!%d',now))+1 end
 if frame=='This year' then return today-tonumber(date('!%j',now))+1 end
 return today
end
-- Readable unit metadata only; never infer class from GUID/race.
function A.EncounterLevel(value)
 if A.Secret and A.Secret(value)then return nil end
 if type(value)=='number'and value==value and value~=math.huge and value~=-math.huge and(value==-1 or(value>0 and value%1==0))then return value end
end
function A.EncounterClass(value)
 if A.Secret and A.Secret(value)then return nil end
 if type(value)~='string'or #value>128 or value:find('[%c|]')then return nil end
 value=value:match('^%s*(.-)%s*$');if value~=''and value~='?'then return value end
end
-- Merge each readable field at its own observation boundary, not the record's
-- latest unknown sighting. Persist provenance; ties converge by owner then value.
function A.MergeEncounterMetadata(target,source)
 for _,field in ipairs({'level','class'})do
  local validate=field=='level'and A.EncounterLevel or A.EncounterClass
  local at,by=field..'At',field..'By'
  local old,value=validate(target[field]),validate(source[field])
  local function stamp(record)
   local v=record[at]
   if A.Secret and A.Secret(v)then return 0 end
   if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then v=record.last end
   if A.Secret and A.Secret(v)then return 0 end
   return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge and v or 0
  end
  local function provenance(record)
   local v=record[by];if A.Secret and A.Secret(v)then return ''end
   return type(v)=='string'and #v<=256 and not v:find('[%c|]')and v or ''
  end
  local oldAt,newAt=stamp(target),stamp(source);local oldBy,newBy=provenance(target),provenance(source)
  local replace=value and(not old or newAt>oldAt or(newAt==oldAt and(newBy>oldBy or(newBy==oldBy and value>old))))
  -- -1 is native unknown-higher, not a measured level. Keep it only until
  -- a positive reading exists; it must never erase a known measurement.
  if field=='level'and old and value then
   if value==-1 and old>0 then replace=false elseif old==-1 and value>0 then replace=true end
  end
  if replace then
   target[field]=value;target[at]=newAt;target[by]=newBy
  elseif old then target[field]=old;target[at]=oldAt;target[by]=oldBy
  else target[field]=nil;target[at]=nil;target[by]=nil end
 end
end
-- Encounter retention is independent of the 400-day credit buckets. A single
-- account boundary (timestamp + GUID) rejects stale offline-alt replays without
-- retaining an ever-growing per-player tombstone ledger.
A.ENCOUNTER_AGE=90*86400
A.ENCOUNTER_LIMIT=2000
local function encounterTable(v)return not(A.Secret and A.Secret(v))and type(v)=='table'and not(issecrettable and issecrettable(v))end
local function encounterNumber(v)return not(A.Secret and A.Secret(v))and type(v)=='number'and v==v and v>-math.huge and v<math.huge end
local function encounterGUID(v)return not(A.Secret and A.Secret(v))and type(v)=='string'and v:match('^Player%-[%w%-]+$')~=nil end
function A.ValidEncounterRecord(g,e)
 if not encounterGUID(g)or not encounterTable(e)or not encounterNumber(e.last)or e.last<0 then return false end
 if A.encounterNow and e.last<=A.encounterNow-A.ENCOUNTER_AGE then return false end
 local boundary=(A.account or A.db or{}).encounterBoundary
 if encounterTable(boundary)and encounterNumber(boundary.last)and encounterGUID(boundary.guid)and not(A.encounterKeepers and A.encounterKeepers[g])then
  if e.last<boundary.last or(e.last==boundary.last and g>boundary.guid)then return false end
 end
 return true
end
local function newer(a,b)return a.last>b.last or(a.last==b.last and a.guid<b.guid)end
function A.PruneEncounters(now,force)
 if not encounterNumber(now)or now<0 then return end
 -- Never move the retention clock backwards on a local clock rollback.
 local state=A.account or A.db;if not state then return end
 local previous=state.encounterClock
 if encounterNumber(previous)and previous<=now+A.ENCOUNTER_AGE then now=math.max(now,previous)end
 state.encounterClock=now;A.encounterNow=now
 if not force and A.encounterDeadline and now<A.encounterDeadline then return end
 A.encounterDeadline=now+60
 local copies,visited={},{}
 local function add(t)if encounterTable(t)and not visited[t]then visited[t]=true;copies[#copies+1]=t end end
 local function records(t)
  if not encounterTable(t)then return end
  for _,r in pairs(t)do if encounterTable(r)then add(r.seen)end end
 end
 add(A.db.seen);records(A.db.owners)
 if A.account then add(A.account.knownEncounters);records(A.account.characters)end
 -- Identity archives and cached self records are real persisted duplicates too.
 for _,root in ipairs({A.db,A.account or A.db})do
  for _,group in pairs(root.identityArchives or{})do records(group)end
  for _,group in pairs(root.guilds or{})do records(group)end
 end
 local boundary=state.encounterBoundary
 if not encounterTable(boundary)or not encounterNumber(boundary.last)or not encounterGUID(boundary.guid)or boundary.last>now then boundary=nil;state.encounterBoundary=nil end
 local best={}
 for _,t in ipairs(copies)do for g,e in pairs(t)do
  if not encounterGUID(g)or not encounterTable(e)or not encounterNumber(e.last)or e.last<=now-A.ENCOUNTER_AGE or e.last>now then t[g]=nil
  else
   if not encounterNumber(e.first)or e.first<0 or e.first>e.last then e.first=e.last end
   if not encounterTable(e.days)then e.days={}end
   for day in pairs(e.days)do
    if not encounterNumber(day)or day%1~=0 or day<A.Day(now)-A.RETENTION+1 or day>A.Day(now)then e.days[day]=nil end
   end
   A.encounterDeadline=math.min(A.encounterDeadline,e.last+A.ENCOUNTER_AGE)
   if not best[g]or e.last>best[g]then best[g]=e.last end
  end
 end end
 -- Until InitAccount exposes the union, only age/validity pruning is safe:
 -- another character may make a locally old player's personal copy a keeper.
 if not A.account then return end
 local ranked={};for g,last in pairs(best)do
  local candidate={guid=g,last=last}
  if not boundary or newer(candidate,boundary)or(last==boundary.last and g==boundary.guid)then ranked[#ranked+1]=candidate end
 end
 if #ranked>A.ENCOUNTER_LIMIT then table.sort(ranked,newer)end
 local keep={};for i=1,math.min(#ranked,A.ENCOUNTER_LIMIT)do keep[ranked[i].guid]=true end
 if #ranked>A.ENCOUNTER_LIMIT then state.encounterBoundary=ranked[A.ENCOUNTER_LIMIT]end
 for _,t in ipairs(copies)do for g in pairs(t)do if not keep[g]then t[g]=nil end end end
 A.encounterKeepers=keep
 A.encounterSize=math.min(#ranked,A.ENCOUNTER_LIMIT)
 A.knownEncounterSize=0;for _ in pairs(A.account and A.account.knownEncounters or{})do A.knownEncounterSize=A.knownEncounterSize+1 end
end
function A.Encounter(g,name,race,faction,now,level,class)
 if not encounterGUID(g)or(A.Secret and A.Secret(faction))or faction~='Alliance'or not encounterNumber(now)or now<0 then return false end
 A.PruneEncounters(now,false)
 A.db.seen=A.db.seen or {}; local r=A.db.seen[g]; local fresh=not r
 if not r then r={first=now,days={}}; A.db.seen[g]=r end
 A.MergeEncounterMetadata(r,{level=level,class=class,levelAt=now,classAt=now,levelBy=A.owner,classBy=A.owner})
 r.name=name or r.name or g; r.race=race or r.race; r.last=math.max(r.last or now,now); r.days=r.days or {}; r.days[A.Day(now)]=true
 for d in pairs(r.days) do if d<A.Day(now)-A.RETENTION+1 then r.days[d]=nil end end
 if A.RememberKnownEncounter then A.RememberKnownEncounter(g,r)end
 if fresh then A.PruneEncounters(now,true)end
 return fresh and race=='Gnome'
end
function A.EncounterCount(frame,now)
 A.PruneEncounters(now,false)
 local n=0; local first=A.FirstDay(frame,now); local today=A.Day(now)
 for _,r in pairs(A.db.seen or {}) do
  if r.race=='Gnome' then
   if frame=='Lifetime' then n=n+1 else
    for d in pairs(r.days or {}) do if d>=first and d<=today then n=n+1; break end end
   end
  end
 end
 return n
end
_G.BIHGGnomeKillTracker5000=A
