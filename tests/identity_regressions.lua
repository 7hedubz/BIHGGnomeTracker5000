local root=arg[1]or'.';local now=1700000000;date=os.date
local function clone(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out end
local function addon()
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Safe=function(fn,...)if fn then return fn(...)end end;A.Secret=function()return false end
 return A
end
local function record(n,d,since)local r={total=n,deaths=0,days={[d]=n},deathDays={}};if since then r.guildBase={since=since,total=n,deaths=0,days={[d]=n},deathDays={}}end;return r end
-- Init prunes expired buckets before a first baseline is captured. Lifetime
-- credit without retained dates can overlap old witnesses; it is not zero.
for _,kind in ipairs({'K','D'})do
 local A=addon();local owner='Hero Heal-Realm';local expired=now-401*86400;local day=A.Day(expired)
 local r={total=kind=='K'and 5 or 0,deaths=kind=='D'and 5 or 0,days=kind=='K'and{[day]=5}or{},deathDays=kind=='D'and{[day]=5}or{}}
 local db={owners={[owner]=r}};local account={}
 local function init()
  A=addon();A.Init(db,owner,now);A.InitAccount(account,'hero',now);A.guildKey='Guild-Realm';A.members={[owner]=true,['Mage-Realm']=true};A.InitGroupTracking(now)
 end
 local function replay(at,target)
  return A.Receive('5|E|'..kind..'|'..A.EncodeAlias(owner)..'|Player-hero|'..target..'|'..at..'|'..(at-1),'GUILD','Mage-Realm',now)
 end
 init();assert(not next(db.owners[owner][kind=='K'and'days'or'deathDays']),'fresh Init really prunes 401-day bucket')
 assert(replay(expired,'Player-old'),'old witness accepted as evidence')
 local key=kind=='K'and'total'or'deaths'
 assert(db.owners[owner][key]==5,'expired baseline unknown lifetime history absorbs overlapping '..kind..' witness')
 assert(replay(now+1,'Player-new'),'post-cutoff witness accepted');assert(db.owners[owner][key]==6,'post-cutoff increment remains additive')
 A.SnapshotAccount(now);db=clone(db);account=clone(account);init();A.RebuildOwnGuildTotals(now)
 assert(db.owners[owner][key]==6,'serialized unknown overlap stays idempotent')
end
-- Known dates prove disjoint credit; only the unallocated part of lifetime
-- history may absorb extra old witnesses. This must not become a global max.
for _,case in ipairs({{5,1,7},{7,1,8},{7,3,9}})do
 for _,kind in ipairs({'K','D'})do
  local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Hero-Realm']=true,['Mage-Realm']=true};A.InitGroupTracking(now)
  local key=kind=='K'and'total'or'deaths';local days=kind=='K'and'days'or'deathDays';local day=A.Day(now)
  local r={total=0,deaths=0,days={},deathDays={},guildBase={since=now,total=0,deaths=0,days={},deathDays={}}};r.guildBase[key]=case[1];r.guildBase[days][day]=5;A.PeerRecords()['Hero-Realm']=r
  local function replay(at,id)assert(A.Receive('5|E|'..kind..'|'..A.EncodeAlias('Hero-Realm')..'|Player-hero|Player-'..id..'|'..at..'|'..(at-1),'GUILD','Mage-Realm',now+1))end
  replay(now-10,'same');for i=1,case[2]do replay(now-86400-i*10,'disjoint'..i)end;replay(now+1,'post')
  local effective=A.GuildEffectiveRecord('Hero-Realm',r,now+1)
  assert(effective[key]==case[3],'dated disjoint evidence consumes only unknown baseline budget, not all lifetime history')
  assert(effective[days][day]==6 and effective[days][day-1]==case[2],'daily disjoint evidence and post-cutoff increments retained')
 end
end
-- Separately serialized account and character copies must retain explicit evidence.
do
 local A=addon();local day=A.Day(now);local name='Me-Realm';local account={characters={[name]=record(0,day,now)}}
 local db={owners={[name]=record(5,day,now-100)}}
 A.Init(db,name,now);A.InitAccount(account,'mine',now);A.guildKey='Guild-Realm';A.members={[name]=true};A.BindLocalCharacter('Player-me',now);A.InitGroupTracking(now);A.RebuildOwnGuildTotals(now)
 assert(db.owners[name].total==5,'nonempty per-character baseline survives empty account baseline')
 account=clone(account);db=clone(db);A=addon();A.Init(db,name,now+1);A.InitAccount(account,'mine',now+1);A.guildKey='Guild-Realm';A.members={[name]=true};A.InitGroupTracking(now+1);A.RebuildOwnGuildTotals(now+1)
 assert(db.owners[name].total==5,'serialized baseline reconciliation is idempotent')
 assert(A.AddGuildEvent('K',name,'Player-me','Player-old',now-150,now-151,now+1));assert(db.owners[name].total==5,'overlapping old witness is not blindly added to baseline')
 assert(A.AddGuildEvent('K',name,'Player-me','Player-new',now-50,now-51,now+1));assert(db.owners[name].total==6,'post-baseline witness remains additive')
end
do
 local A=addon();GetNormalizedRealmName=function()return'Realm'end;UnitName=function()return'Druiddo','Heal'end;UnitGUID=function()return'Player-heal'end
 assert(type(A.LocalCharacterName)=='function','readable full local identity helper exists')
 assert(A.LocalCharacterName()=='Druiddo Heal-Realm','Forever surname belongs to full character name, not realm')
 UnitName=function()return'Druiddo|bad','Heal'end;assert(A.LocalCharacterName()==nil,'malformed identity is rejected, never repaired');assert(A.localCharacterGUID==nil and A.localCharacterName==nil,'failed identity read cannot retain stale successful provenance')
 UnitName=function()return'Druiddo',nil end;assert(A.LocalCharacterName()==nil,'missing surname fails closed')
 UnitName=function()return'Druiddo','Heal'end;A.Secret=function(v)return v=='Heal'end;assert(A.LocalCharacterName()==nil,'secret surname fails closed')
 UnitName=nil;UnitGUID=nil;GetNormalizedRealmName=nil
end
-- A validated account may link an offline alt's foreign spelling only using
-- the current authoritative roster GUID; both packet orders are supported.
for _,metadataFirst in ipairs({false,true})do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Hero-Heal']=true,['Mage-Realm']=true};A.InitGroupTracking(now)
 A.ObserveGuildCharacter('Hero-Heal','Player-hero',now)
 assert(A.Receive('3|I|hero-account|'..A.EncodeAlias('Hero')..'|'..now,'GUILD','Mage-Realm',now))
 local name='Hero Heal-Realm';local score='4|R|'..A.EncodeAlias(name)..'|2|S|5|0|'..A.Day(now)..'|5|0';local meta='6|R|'..A.EncodeAlias(name)..'|Player-hero'
 if metadataFirst then assert(A.Receive(meta,'GUILD','Mage-Realm',now),'GUID-first validated offline variant binds')end
 local accepted=A.Receive(score,'GUILD','Mage-Realm',now)
 if not metadataFirst then assert(not accepted,'unknown name score waits for GUID proof');assert(A.Receive(meta,'GUILD','Mage-Realm',now),'score-first validated offline variant binds')else assert(accepted,'linked variant score accepted')end
 local r=A.PeerRecords()['Hero-Heal'];assert(r and r.total==5 and r.accountID=='hero-account','queued or linked score reaches one GUID-backed child')
 assert(not A.PeerRecords()[name],'foreign spelling does not create duplicate child')
 assert(not A.Receive('6|R|'..A.EncodeAlias('Unrelated-Realm')..'|Player-arbitrary','GUILD','Mage-Realm',now),'arbitrary GUID cannot invent guild membership')
 A.members['Thief-Realm']=true;assert(A.Receive('3|I|thief|'..A.EncodeAlias('Hero')..'|'..now,'GUILD','Thief-Realm',now))
 assert(not A.Receive(meta,'GUILD','Thief-Realm',now),'different account cannot claim an established GUID')
end
-- Pending scores belong to the validated account declaration at receipt time.
do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Mage-Realm']=true,['Hero-Heal']=true};A.InitGroupTracking(now);A.ObserveGuildCharacter('Hero-Heal','Player-hero',now)
 local function account(id,rev)assert(A.Receive('3|I|'..id..'|'..A.EncodeAlias('Hero')..'|'..rev,'GUILD','Mage-Realm',now))end
 account('original',now);local alt='Hero Heal-Realm';assert(not A.Receive('4|R|'..A.EncodeAlias(alt)..'|2|S|5|0|'..A.Day(now)..'|5|0','GUILD','Mage-Realm',now))
 account('replacement',now+1);assert(A.Receive('6|R|'..A.EncodeAlias(alt)..'|Player-hero','GUILD','Mage-Realm',now))
 assert(A.PeerRecords()['Hero-Heal'].total==0,'queued scores cannot cross a sender account declaration change')
end
-- A conflicting established canonical GUID cannot be overwritten via a cached link.
do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Mage-Realm']=true,['Hero-Heal']=true,['Hero Heal-Realm']=true};A.InitGroupTracking(now)
 assert(A.Receive('3|I|hero-account|'..A.EncodeAlias('Hero')..'|'..now,'GUILD','Mage-Realm',now))
 A.account.guildIdentities={['Guild-Realm']={names={},guids={['Player-wrong']='Hero-Heal'}}}
 local r=record(7,A.Day(now));r.characterGUID='Player-right';r.accountID='hero-account';A.PeerRecords()['Hero-Heal']=r
 assert(not A.Receive('6|R|'..A.EncodeAlias('Hero Heal-Realm')..'|Player-wrong','GUILD','Mage-Realm',now),'conflicting canonical GUID must reject relay')
 assert(r.characterGUID=='Player-right'and r.total==7,'rejected conflicting relay leaves original untouched')
end
-- Reject contradictory roster/name evidence before GUID canonicalization mutates it.
for _,claimed in ipairs({'Player-other','Player-fake'})do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Mage-Realm']=true,['Hero Heal-Realm']=true,['Other Full-Realm']=true};A.InitGroupTracking(now)
 A.ObserveGuildCharacter('Hero Heal-Realm','Player-hero',now);A.ObserveGuildCharacter('Other Full-Realm','Player-other',now)
 assert(A.Receive('3|I|mage-account|'..A.EncodeAlias('Mage')..'|'..now,'GUILD','Mage-Realm',now))
 assert(A.AddGuildEvent('K','Hero Heal-Realm','Player-hero','Player-victim',now-10,now-11,now))
 assert(not A.Receive('6|R|'..A.EncodeAlias('Hero Heal-Realm')..'|'..claimed,'GUILD','Mage-Realm',now),'roster-known name rejects contradictory or invented GUID before canonicalization')
 local s=A.account.guildIdentities[A.guildKey]
 assert(s.names['Hero Heal-Realm']=='Player-hero'and s.names['Other Full-Realm']=='Player-other','rejected relay preserves identity maps')
 assert(not A.PeerRecords()['Other Full-Realm']or not A.PeerRecords()['Other Full-Realm'].accountID,'rejected relay cannot assign another character account')
 for _,e in pairs(A.account.guildObservations[A.guildKey].events)do assert(e.name=='Hero Heal-Realm','rejected relay cannot rewrite events')end
end
-- Cached membership/identity evidence alone is never fresh GUID authority.
do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Hero-Heal']=true,['Mage-Realm']=true};A.InitGroupTracking(now)
 A.account.guildIdentities={['Guild-Realm']={names={['Hero-Heal']='Player-hero'},guids={['Player-hero']='Hero-Heal'},rosterGUIDs={['Player-hero']='Hero-Heal'}}}
 assert(A.Receive('3|I|hero-account|'..A.EncodeAlias('Hero')..'|'..now,'GUILD','Mage-Realm',now))
 assert(not A.Receive('6|R|'..A.EncodeAlias('Hero Heal-Realm')..'|Player-hero','GUILD','Mage-Realm',now),'serialized roster cache alone cannot authorize a new identity link')
end
-- Same display/owner key is not proof that records describe the same player.
do
 local A=addon();local day=A.Day(now);local legacy='Druiddo-Realm';local heal=record(18,day,now-100);heal.characterGUID='Player-heal'
 local damage=record(6,day,now-100);damage.characterGUID='Player-damage'
 local account={characters={[legacy]=heal},guilds={},guildObservations={['Guild-Realm']={events={}}}}
 for i=1,18 do account.guildObservations['Guild-Realm'].events['heal'..i]={kind='K',name=legacy,actor='Player-heal',target='Player-victim'..i,time=now-200+i,contribution=now-201+i}end
 A.Init({owners={[legacy]=damage}},legacy,now);A.InitAccount(account,'mine',now)
 assert(account.characters[legacy].characterGUID~='Player-heal' or account.characters[legacy].total==18,'same-key distinct GUID initialization must not mutate known character credit')
 assert(A.db.owners[legacy]~=heal,'distinct GUID source and account target are never silently coalesced')
end
-- Bootstrap only an exact roster-proven transport spelling, never nickname or
-- first-name matching. Sync calls this before its raw sender membership gate.
do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Hero Heal-Realm']=true};A.InitGroupTracking(now);A.ObserveGuildCharacter('Hero Heal-Realm','Player-hero',now)
 assert(type(A.ResolveGuildSender)=='function','pre-gate roster identity resolver exists')
 local identity='3|I|hero-account|'..A.EncodeAlias('Hero')..'|'..now
 assert(A.ResolveGuildSender(identity,'GUILD','Hero-Heal',now)=='Hero-Heal','unverified bootstrap identity is not yet a member')
 assert(A.ResolveGuildSender('6|C|Player-hero','GUILD','Stranger-Realm',now)=='Stranger-Realm','known GUID alone cannot authenticate arbitrary transport sender')
 assert(A.ResolveGuildSender('6|C|Player-arbitrary','GUILD','Hero-Heal',now)=='Hero-Heal','transport shape alone cannot authenticate arbitrary GUID')
 assert(A.ResolveGuildSender('6|C|Player-hero','PARTY','Hero-Heal',now)=='Hero-Heal','non-guild bootstrap rejected')
 assert(A.ResolveGuildSender('6|C|Player-hero','GUILD','Hero-Heal',now)=='Hero Heal-Realm','exact readable roster-backed transport variant resolves')
 assert(A.Receive('6|C|Player-hero','GUILD','Hero-Heal',now),'buffered direct declaration binds only after roster-backed sender proof')
 assert(A.PeerRecords()['Hero Heal-Realm'].accountID=='hero-account','bootstrap direct declaration is applied to proven canonical character')
end
-- Exercise the actual Sync pre-gate path, not only the resolver in isolation.
do
 local A=addon();A.Init({},'Viewer-Realm',now);A.InitAccount({},'viewer',now);A.guildKey='Guild-Realm';A.members={['Hero Heal-Realm']=true};A.InitGroupTracking(now);A.ObserveGuildCharacter('Hero Heal-Realm','Player-hero',now)
 assert(not A.Receive('3|I|hero-account|'..A.EncodeAlias('Hero')..'|'..now,'GUILD','Hero-Heal',now),'unverified direct declaration remains fail closed while awaiting GUID proof')
 assert(A.Receive('6|C|Player-hero','GUILD','Hero-Heal',now),'Sync must resolve roster-proven transport spelling before raw membership gate')
 assert(A.PeerRecords()['Hero Heal-Realm'].accountID=='hero-account','pre-gate bootstrap safely replays buffered direct declaration')
end
-- Optional read-only real SavedVariables fixture root (the account directory).
if arg[2]then
 local fixture=arg[2];local realm='CAMWOWUS2Realm8PvP';local old='Druiddo-'..realm;local healGUID='Player-6934-0056A09F';local damageGUID='Player-6934-01A3FEB6'
 local function saved(path)local env={};local f=assert(loadfile(path));setfenv(f,env);f();return env end
 local sourceAccount=saved(fixture..'/SavedVariables/BIHGGnomeKillTracker5000.lua').BIHGGKTAccountDB
 local expectedHeal=assert(sourceAccount.characters[old]).total;local epoch=1794281571
 local proven=0;for _,s in pairs(sourceAccount.guildObservations or{})do for _,e in pairs(s.events or{})do epoch=math.max(epoch,e.time+1);if e.actor==healGUID and e.kind=='K'then proven=proven+1 end end end
 assert(proven==expectedHeal,'fixture heal total is independently actor-GUID ledger backed')
 for _,order in ipairs({{'Damage','Heal'},{'Heal','Damage'}})do
  local account=clone(sourceAccount);local latest
  for _,surname in ipairs(order)do
   local A=addon();local db=saved(fixture..'/91/Druiddo-'..surname..'/SavedVariables/BIHGGnomeKillTracker5000.lua').BIHGGKTDB
   UnitName=function()return'Druiddo',surname end;UnitGUID=function()return surname=='Heal'and healGUID or damageGUID end;GetNormalizedRealmName=function()return realm end
   local owner=assert(A.LocalCharacterName());A.Init(db,owner,epoch);A.InitAccount(account,'ignored',epoch);A.guildKey='Boy I Hate Gnomes-'..realm;A.members={};for n,v in pairs(account.guildMembership[A.guildKey].members)do A.members[n]=v end;A.members[owner]=true
   assert(A.BindLocalCharacter(UnitGUID(),epoch),'real fixture identity binds');A.InitGroupTracking(epoch);A.RebuildOwnGuildTotals(epoch);A.SnapshotAccount(epoch)
   local own=db.owners[owner];assert(own.characterGUID==UnitGUID(),'real GUID retained')
   assert(own.total==(surname=='Heal'and expectedHeal or 0),'real '..surname..' credit must match fixture-proven Heal / zero unproven Damage, got '..own.total)
   account=clone(account);latest=A
  end
  local healName='Druiddo Heal-'..realm;local damageName='Druiddo Damage-'..realm
  assert(account.characters[healName].total==expectedHeal and account.characters[damageName].total==0,'distinct GUID children survive serialized transitions')
  assert(account.identityArchives and account.identityArchives[damageGUID]and account.identityArchives[damageGUID][old]and account.identityArchives[damageGUID][old].total==6,'ambiguous damage snapshot is archived unchanged, not destroyed or double counted')
  assert(account.identityArchives[healGUID][old].total==expectedHeal,'known heal legacy record archived unchanged')
  latest.members[healName]=true;latest.members[damageName]=true
  local ownGroup;for _,g in ipairs(latest.LeaderboardGroups('Lifetime',epoch))do if g.id=='account:'..account.id then ownGroup=g end end
  assert(ownGroup and ownGroup.k==expectedHeal,'real alias group does not add overlapping historical six')
  assert(latest.CanonicalCharacterName(old)==old,'ambiguous legacy spelling must not select either distinct GUID without proof')
  assert(not latest.Receive('2|S|6|2|'..latest.Day(epoch)..'|6|2','GUILD',old,epoch),'unqualified old collision spelling cannot recreate duplicate credit')
 end
 UnitName=nil;UnitGUID=nil;GetNormalizedRealmName=nil
 print('PASS actual read-only snapshot replay: both login orders preserve heal '..expectedHeal..', quarantine damage 6, distinct GUID children')
end
print('PASS identity regressions: baselines, local full identity, relay packet orders and GUID conflict isolation')
