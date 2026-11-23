local root=arg[1]or'.';date=os.date
local A={};local now=1700000000
for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
A.Safe=function(f,...)if f then return f(...)end end;A.Secret=function()return false end
A.Name=function(n)return n:find('-',1,true)and n or n..'-Realm'end
A.Init({},'Hero-Realm',now);A.InitAccount({},'local-account',now)
A.guildKey='Guild-Realm';A.guildName='Guild';A.members={['Hero-Realm']=true};A.InitGroupTracking(now)
local units={player={name='Hero',guid='Player-hero',guild='Guild'}}
for i=1,40 do units['raid'..i]={name=i==1 and'Hero'or('Peer'..i),guid=i==1 and'Player-hero'or('Player-peer'..i),guild='Guild'}end
local checks=0
function UnitExists(u)return units[u]~=nil end
function UnitGUID(u)return units[u]and units[u].guid end
function UnitName(u)return units[u]and units[u].name,'Realm'end
function GetGuildInfo(u)checks=checks+1;return units[u]and units[u].guild end
function IsInRaid()return true end
function GetNumGroupMembers()return 40 end
function GetServerTime()return now end
local events=A.account.guildObservations[A.guildKey].events
-- A synthetic large history, populated before a cold index build.
for i=1,10360 do local n=(i%40)+1;events['seed'..i]={kind='K',name=n==1 and'Hero-Realm'or('Peer'..n..'-Realm'),actor=n==1 and'Player-hero'or('Player-peer'..n),target='Player-enemy'..i,time=now-100,contribution=now-101}end
A.groupIndexes={}
A.RefreshGroupActors();A.GuildEffectiveRecord('Hero-Realm',nil,now)
local index=A.groupIndexes[A.guildKey];local rawpairs=pairs;local passes,visits=0,0
pairs=function(t)if t==events then passes=passes+1;local f,s,k=rawpairs(t);return function(state,key)local n,v=f(state,key);if n then visits=visits+1 end;return n,v end,s,k end;return rawpairs(t)end
checks=0
for i=1,60 do A.RefreshGroupActors()end
pairs=rawpairs
assert(passes==0,'unchanged refresh must not traverse full ledger: passes='..passes..' visits='..visits)
assert(A.groupIndexes[A.guildKey]==index,'unchanged refresh must retain indexes')
assert(checks==60*41,'each refresh still verifies every live unit guild')
units.raid2.guild='Foreign';A.RefreshGroupActors();assert(not A.groupOwners['Player-peer2'],'fresh conflicting guild excludes cached actor')
units.raid2.guild='Guild';A.RefreshGroupActors();assert(A.groupOwners['Player-peer2'],'verified actor returns')
print('PASS performance_identity stable: 60 refreshes, 10360 events, 0 full-ledger passes; live guild checks='..checks)
-- Late history must be indexed even after the unchanged actor was memoized.
local late='Late-Realm';local canonical='Late Canonical-Realm';local actor='Player-late'
A.members[late]=true;A.members[canonical]=true;A.groupBulk=true
A.ObserveGuildCharacter(late,actor,now)
assert(A.AddGuildEvent('K',late,actor,'Player-latevictim',now-10,now-11,now))
A.account.characterNamesByGUID=A.account.characterNamesByGUID or {};A.account.characterNamesByGUID[actor]=canonical
A.ObserveGuildCharacter(late,actor,now)
local effective=A.GuildEffectiveRecord(canonical,{observerOnly=true},now)
assert(effective.total==1,'late history follows newly canonical actor without dropping credit')
assert(A.GuildEffectiveRecord(late,{observerOnly=true},now).total==0,'old name index loses renamed event')
print('PASS performance_identity late insertion: canonical rename preserves exactly one credit')
local victim='Player-convert';local at=now-20
assert(A.AddGuildEvent('K',canonical,actor,victim,at,at-1,now))
index=A.groupIndexes[A.guildKey];passes=0
pairs=function(t)if t==events then passes=passes+1 end;return rawpairs(t)end
assert(not A.AddHonorClaim(canonical,actor,victim,at,at-1,now,'Player-observer:1','root','A'))
pairs=rawpairs
assert(passes==0,'legacy-to-typed conversion must use event key index, not scan ledger: '..passes)
assert(A.groupIndexes[A.guildKey]==index,'typed conversion must update indexes without rebuilding')
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==2,'conversion preserves exactly two credits')
A.ObserveGuildCharacter(late,actor,now)
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==2,'reconciliation after conversion preserves credit')
print('PASS performance_identity typed conversion: zero full-ledger passes or index replacement')
-- A same-canonical observation cannot memoize away later aliases or metadata.
local alias='Delayed-Realm';A.members[alias]=true
A.account.characterNamesByGUID[actor]=nil
A.account.guildIdentities[A.guildKey].guids[actor]=alias
assert(A.AddGuildEvent('K',alias,actor,'Player-afterwarm',now-30,now-31,now))
A.account.characterNamesByGUID[actor]=canonical
A.PeerRecords()[alias]={total=0,days={},observerOnly=true}
A.ObserveGuildCharacter(late,actor,now)
assert(not A.PeerRecords()[alias],'late alias summary must still reconcile')
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==3,'late history joins canonical credit after memoization')
-- Mutating timestamps/provenance keeps shared event references valid.
local typed=events['H:'..actor..':Player-observer:1'];assert(typed)
A.account.guildObservations[A.guildKey].killPolicySince=now
assert(not A.AddGuildEvent('K',canonical,actor,victim,at-1,at-2,now))
assert(typed.time==at-1,'reverse legacy arrival retimes the indexed typed event')
assert(not A.AddHonorClaim(canonical,actor,victim,at,at-1,now,'Player-observer:1','root','H'))
assert(typed.provenance=='H','own honor upgrades indexed assist provenance')
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==3,'retiming and provenance do not duplicate credits')
-- Replacing serialized history must invalidate cached buckets even without a Runtime hook.
local saved=events;events={}
for k,e in rawpairs(saved)do local c={};for f,v in rawpairs(e)do c[f]=v end;events[k]=c end
A.account.guildObservations[A.guildKey].events=events
A.ObserveGuildCharacter(late,actor,now)
assert(A.groupIndexes[A.guildKey]~=index,'replaced history gets fresh actor/name/key indexes')
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==3,'serialized history replacement preserves credits')
-- Carry history uses the insertion path, leaving the old namespace intact.
local oldGuild=A.guildKey;A.guildKey='Other-Realm';A.InitGroupTracking(now)
A.account.characters[canonical]={total=0,days={},observerOnly=true};A.CarryOwnGuildHistory(now)
A.ObserveGuildCharacter(late,actor,now)
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now).total==3,'carried history is actor-indexed in new guild')
assert(A.GuildEffectiveRecord(canonical,{observerOnly=true},now,oldGuild).total==3,'guild switch retains old indexed credit')
print('PASS performance_identity late aliases, retiming, provenance, serialized replacement and guild carry')
