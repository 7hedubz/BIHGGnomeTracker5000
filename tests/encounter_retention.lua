local root=arg[1]or'.';date=os.date
local function clone(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=clone(v)end;return r end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local now=1700000000;local age=90*86400
local function entry(last)return {first=last-100,last=last,name='Enemy-Realm',race='Gnome',level=70,class='Mage',levelAt=last,classAt=last,days={[math.floor(last/86400)]=true}}end
local function addon(db,account,t)
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Identity.lua'})do assert(loadfile(root..'/'..f))('test',A)end
 A.Init(db or{},'Main-Realm',t or now);A.InitAccount(account or{},'account',t or now);return A
end
-- Native startup initializes character storage before the account union exists.
-- The locally oldest player is globally newest through another character.
local pending={seen={},guilds={Guild={CachedSelfArchive={seen={}}}}}
for i=1,2001 do pending.seen['Player-'..i]=entry(now-i)end
local personal=pending.seen['Player-2001'];personal.name='Personal-Realm';personal.level=60;personal.class='Warlock'
personal.days={[math.floor(now/86400)-1]=true};personal.levelBy='Main-Realm';personal.classBy='Main-Realm'
pending.guilds.Guild.CachedSelfArchive.seen['Player-2001']=clone(personal)
local expectedPersonal=clone(personal)
local startup={};for _,f in ipairs({'Core.lua','Accounts.lua','Identity.lua'})do assert(loadfile(root..'/'..f))('test',startup)end
pending.seen['Player-expired-startup']=entry(now-age)
startup.Init(pending,'Main-Realm',now)
startup.PruneEncounters(now,true) -- Also safe for Core-only callers with no account initialization.
assert(count(startup.db.seen)==2001 and not pending.encounterBoundary,'without the account union, defer destructive cap selection and its replay boundary')
assert(not startup.db.seen['Player-expired-startup'],'pre-account age expiry remains active')
startup.InitAccount({characters={Alt={total=0,days={},seen={['Player-2001']=entry(now)}}}},'account',now)
assert(startup.KnownEncounters()['Player-2001']and startup.db.seen['Player-2001'],'pre-account local cap must not erase personal evidence for a global keeper')
assert(count(startup.KnownEncounters())==2000 and count(startup.db.seen)==2000 and not startup.db.seen['Player-2000'],'InitAccount must enforce the actual global cap before returning')
local function samePersonal(actual)
 assert(actual,'global keeper must survive in every persisted personal copy')
 for _,key in ipairs({'first','last','name','race','level','class','levelAt','classAt','levelBy','classBy'})do assert(actual[key]==expectedPersonal[key],'global keeper retains personal '..key)end
 assert(count(actual.days)==1 and actual.days[math.floor(now/86400)-1],'global keeper retains only personal sighting days')
end
samePersonal(startup.db.seen['Player-2001'])
samePersonal(startup.db.guilds.Guild.CachedSelfArchive.seen['Player-2001'])
print('PASS pre-account local-cap regression: global keeper preserves personal evidence and cached self archive')
local account={characters={Alt={total=41,deaths=12,days={},deathDays={},seen={}}}}
local db={owners={['Main-Realm']={total=17,deaths=3,days={},deathDays={}}},seen={}}
for i=1,2205 do local g=string.format('Player-1-%08X',i);local e=entry(now-i);account.characters.Alt.seen[g]=clone(e);db.seen[g]=clone(e)end
local stale=clone(db);local started=os.clock();local A=addon(db,account);local initCPU=os.clock()-started
assert(count(A.KnownEncounters())==2000,'account-wide union must retain only 2000 newest players')
assert(count(A.db.seen)==2000 and count(A.account.characters.Alt.seen)==2000,'every persisted personal copy intersects shared keepers')
assert(A.account.characters.Alt.total==41 and A.db.owners[A.owner].total==17 and A.db.owners[A.owner].deaths==3,'retention cannot erase kill/death totals')
local B=addon(stale,clone(A.account))
assert(count(B.KnownEncounters())==2000 and not B.db.seen['Player-1-0000089D'],'serialized stale character cannot resurrect evicted oldest')
local e=B.KnownEncounters()['Player-1-00000001'];assert(e.level==70 and e.class=='Mage'and e.first==now-101,'retained metadata remains intact')
B.Encounter('Player-1-0000089D','Fresh-Realm','Gnome','Alliance',now+1,71,'Warrior')
assert(B.KnownEncounters()['Player-1-0000089D'].last==now+1 and count(B.KnownEncounters())==2000,'fresh re-sighting is admitted and evicts next oldest')
print(string.format('PASS retention cap/replay: 2205 input -> 2000 keepers; init CPU %.6fs',initCPU))
-- A keeper's older personal evidence must not be replaced by another alt's
-- more recent sighting, nor dropped just because it predates the cap boundary.
local shared=clone(B.account);shared.characters.Alt.seen['Player-1-00000001']=entry(now-3000)
local C=addon({},shared,now+2)
assert(C.account.characters.Alt.seen['Player-1-00000001']and C.account.characters.Alt.seen['Player-1-00000001'].last==now-3000,'shared keepers preserve each characters own last-seen semantics')
local malformed=entry(now-1);malformed.first='bad';malformed.days={bad=true,[false]=true,[math.floor(now/86400)]=true}
local D=addon({seen={['Player-malformed']=malformed,['Player-expired']=entry(now-age),['Player-live']=entry(now-age+1),['Player-future']=entry(now+1),['Player-nan']={last=0/0}}},{},now)
assert(not D.KnownEncounters()['Player-expired']and not D.KnownEncounters()['Player-future']and not D.KnownEncounters()['Player-nan'],'exact 90-day boundary, future and nonfinite timestamps cannot survive initialization')
assert(D.db.seen['Player-malformed'].first==now-1 and not D.db.seen['Player-malformed'].days.bad,'malformed first/day values are normalized without granting recency')
D.PruneEncounters(now+1,false)
assert(not D.KnownEncounters()['Player-live'],'earliest expiry deadline is exact, not an extra minute of history')
D.Encounter('Player-refresh','Refresh-Realm','Gnome','Alliance',now,60,'Mage')
D.Encounter('Player-refresh',nil,nil,'Alliance',now+age-1,nil,nil)
D.PruneEncounters(now+age,true)
assert(D.KnownEncounters()['Player-refresh'].last==now+age-1,'expiry uses last seen, not first seen or UTC bucket')
D.PruneEncounters(now+age-10,true)
assert(D.KnownEncounters()['Player-refresh'].last==now+age-1,'clock rollback does not erase valid current history as future')
print('PASS exact expiry, refresh, malformed timestamps/dates and rollback')
local F=addon()
for i=2205,1,-1 do F.RememberKnownEncounter(string.format('Player-2-%08X',i),entry(now-1))end
assert(count(F.KnownEncounters())==2000 and F.KnownEncounters()['Player-2-00000001']and not F.KnownEncounters()['Player-2-0000089D'],'direct history merges enforce the cap with deterministic ascending GUID ties')
print('PASS direct merge bounds and deterministic ties')
local I=addon();I.db.owners[I.owner].characterGUID='Player-owner';I.Encounter('Player-shared','Shared-Realm','Gnome','Alliance',now,70,'Mage')
I.account.characters.Legacy={characterGUID='Player-owner',total=8,deaths=4,days={},deathDays={},seen={['Player-shared']={first='broken',last=now-1,days={}},['Player-dead-history']=entry(now-age)}}
assert(I.BindLocalCharacter('Player-owner',now))
assert(not I.KnownEncounters()['Player-dead-history']and not I.account.identityArchives['Player-owner'].Legacy.seen['Player-dead-history'],'identity reconciliation also prunes archived persisted copies')
assert(I.db.owners[I.owner].total==8 and I.db.owners[I.owner].deaths==4 and I.db.seen['Player-shared'].level==70,'identity merge retains credit and metadata')
print('PASS identity merge/archive retention')
-- Disjoint alt histories share ONE cap, not a separate allowance per child.
local disjoint={characters={One={total=20,deaths=5,days={},deathDays={},seen={}},Two={total=30,deaths=6,days={},deathDays={},seen={}}},guildObservations={Guild={events={credit={kind='K',actor='Player-owner',time=now-100,opponent='Player-ledger-only'}}}}}
for i=1,1200 do disjoint.characters.One.seen[string.format('Player-3-%08X',i)]=entry(now-i);disjoint.characters.Two.seen[string.format('Player-4-%08X',i)]=entry(now-i)end
local ledger=clone(disjoint.guildObservations)
disjoint.characters.One.guildBase={since=now-10,total=20,deaths=5,days={[math.floor(now/86400)]=20},deathDays={[math.floor(now/86400)]=5}}
disjoint.characters.One.encounterScores={Lifetime=9000};disjoint.characters.One.encounterStamp=now-1
disjoint.characters.One.accountEncounterScores={Lifetime=15000};disjoint.characters.One.accountEncounterStamp=now-1
local preservedCredit=clone(disjoint.characters.One)
local G=addon({},disjoint)
assert(count(G.KnownEncounters())==2000 and count(G.account.characters.One.seen)==1000 and count(G.account.characters.Two.seen)==1000,'disjoint alt histories cannot grow account union past 2000')
local function serialize(t)
 if type(t)~='table'then return type(t)=='string'and string.format('%q',t)or tostring(t)end
 local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]='['..serialize(k)..']='..serialize(t[k])end;return '{'..table.concat(out,',')..'}'
end
assert(serialize(ledger)==serialize(G.account.guildObservations),'all ledger bytes remain equivalent through retention')
local ledgerBefore=serialize(G.account.guildObservations)
local totalsBefore=serialize({G.account.characters.One.total,G.account.characters.One.deaths,G.account.characters.Two.total,G.account.characters.Two.deaths})
G.PruneEncounters(now+age,true)
assert(next(G.KnownEncounters())==nil and ledgerBefore==serialize(G.account.guildObservations),'full expiration leaves credit ledger unchanged')
assert(totalsBefore==serialize({G.account.characters.One.total,G.account.characters.One.deaths,G.account.characters.Two.total,G.account.characters.Two.deaths}),'full expiration leaves all alt kill/death totals unchanged')
for _,key in ipairs({'total','deaths','days','deathDays','guildBase','encounterScores','encounterStamp','accountEncounterScores','accountEncounterStamp'})do assert(serialize(preservedCredit[key])==serialize(G.account.characters.One[key]),'credit/transport field preserved byte-for-byte: '..key)end
local J=addon(clone(B.db),clone(B.account),now+2);local sorts=0;local sort=table.sort;table.sort=function(...)sorts=sorts+1;return sort(...)end
started=os.clock();for i=1,10000 do J.Encounter('Player-1-00000001',nil,nil,'Alliance',now+2,nil,nil)end
local updateCPU=os.clock()-started;table.sort=sort
assert(sorts==0,'repeated existing player scans must not sort bounded history')
started=os.clock();for i=1,100 do J.Encounter(string.format('Player-5-%08X',i),'New-Realm','Human','Alliance',now+3,nil,nil)end
local insertCPU=os.clock()-started
assert(count(J.KnownEncounters())==2000 and count(J.db.seen)<=2000,'stress insertions remain bounded')
local secret={};J.Secret=function(v)return rawequal(v,secret)end
assert(not J.Encounter(secret,nil,nil,'Alliance',now+3)and not J.Encounter('Player-secret',nil,nil,'Alliance',secret),'secret GUID/timestamps never undergo comparisons')
J.db.seen['Player-secret-record']={last=secret};J.PruneEncounters(now+3,true);assert(not J.db.seen['Player-secret-record'],'secret persisted timestamp is rejected safely')
print(string.format('PASS disjoint alts/ledger invariants; 10000 existing scans %.6fs (0 sorts), 100 cap insertions %.6fs; 2000 retained',updateCPU,insertCPU))
local prior=J.KnownEncounters()['Player-1-00000001'].last
J.Encounter('Player-1-00000001',nil,nil,'Alliance',now-10,nil,nil)
assert(J.db.seen['Player-1-00000001'].last==prior,'a rollback sighting cannot move last-seen backwards')
J.RememberKnownEncounter('Player-secret-merge',{last=secret,first=secret,days=secret})
assert(not J.KnownEncounters()['Player-secret-merge'],'secret direct merge timestamp is ignored safely')
J.RememberKnownEncounter('Player-secret-fields',{last=now+3,first=secret,days=secret})
assert(J.KnownEncounters()['Player-secret-fields'],'invalid optional first/days do not discard a valid last-seen record')
local function reload(t)return assert(loadstring('return '..serialize(t)))()end
local R=addon(reload(stale),reload(B.account),now+4)
assert(count(R.KnownEncounters())==2000 and not R.db.seen['Player-1-0000089C'],'actual Lua serialization/reload cannot resurrect the next evicted old player')
assert(R.account.knownEncounters~=R.db.seen,'serialized cache remains separate from personal history')
local forward=addon({},{});local reverse=addon({},{})
for i=1,2205 do forward.RememberKnownEncounter(string.format('Player-9-%08X',i),entry(now-1))end
for i=2205,1,-1 do reverse.RememberKnownEncounter(string.format('Player-9-%08X',i),entry(now-1))end
assert(serialize(forward.KnownEncounters())==serialize(reverse.KnownEncounters()),'equal-timestamp keeper selection and metadata converge in either replay order')
print('PASS actual serialized stale snapshot and reverse-order convergence')
G.RememberKnownEncounter('Player-expired-replay',entry(now-1))
assert(not G.KnownEncounters()['Player-expired-replay'],'direct stale merge after expiration cannot temporarily resurrect expired history')
local slim=clone(B.account);slim.knownEncounters={};slim.characters={}
local S=addon({},slim,now+4)
S.RememberKnownEncounter('Player-1-0000089D',entry(now-2205))
assert(not S.KnownEncounters()['Player-1-0000089D'],'bounded eviction boundary rejects stale imports even below the cap')
