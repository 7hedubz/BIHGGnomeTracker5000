local root=arg[1]or'.';local now=1700000000;date=os.date
-- Parser/account tests explicitly run in the readable native world contract.
function IsInInstance()return false,'none'end
local function addon()
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua','Dashboard.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Safe=function(fn,...)if type(fn)=='function'then local ok,v=pcall(fn,...);if ok then return v end end end;A.Secret=function()return false end
 return A
end
local function clone(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=clone(v)end;return r end
local A=addon();local day=A.Day(now);A.Init({},'Main-Realm',now);A.InitAccount({},'local-account',now)
A.Encounter('Player-known','Original','Gnome','Alliance',now);A.Award(now);A.SnapshotAccount(now)
-- Simulate serialization and a fresh Lua session, not shared in-memory aliases.
local account=clone(A.account);local B=addon();B.Init({},'Alt-Realm',now+1);B.InitAccount(account,'ignored',now+1)
assert(type(B.KnownEncounters)=='function','persistent encounter knowledge must be shared across character sessions')
assert(B.KnownEncounters()['Player-known'].name=='Original','fresh alt immediately sees the main character sighting without network sync')
assert(not B.db.seen['Player-known']and B.db.owners[B.owner].total==0,'shared knowledge does not invent personal sighting or kill credit')
B.Encounter('Player-known','Updated','Gnome','Alliance',now+2);B.Encounter('Player-new','Other','Human','Alliance',now+2);B.SnapshotAccount(now+2)
local C=addon();C.Init({},'Third-Realm',now+3);C.InitAccount(clone(B.account),'ignored',now+3)
local known=C.KnownEncounters();assert(known['Player-known'].first==now and known['Player-known'].last==now+2 and known['Player-known'].name=='Updated','shared sighting merges earliest/latest dates and freshest metadata')
assert(known['Player-new']and C.AccountEncounterCount('Lifetime',now+3)==1,'shared identity union retains updates and Gnome counts without duplicates')
assert(C.account.characters['Main-Realm'].total==1 and C.account.characters['Alt-Realm'].total==0,'character kill totals remain independent')
local fresh=C.account.characters['Main-Realm'];fresh.seen['Player-known'].name='Latest';fresh.seen['Player-known'].last=now+20
local stale=addon();stale.Init({seen={['Player-known']={name='Old disk copy',race='Gnome',first=now,last=now,days={[day]=true}}}},'Main-Realm',now+21);stale.InitAccount(clone(C.account),'ignored',now+21)
assert(stale.KnownEncounters()['Player-known'].name=='Latest','loading a stale character file cannot roll back newer account-wide encounter metadata')
C.account.guilds['Guild-Realm']={['Peer-Realm']={total=0,deaths=0,days={},deathDays={},observerOnly=true}}
C.account.guildMembership={['Guild-Realm']={members={['Main-Realm']=true,['Peer-Realm']=true,['Departed-Realm']=false},guids={}}}
C.account.guildObservations={['Guild-Realm']={events={one={kind='K',name='Peer-Realm',actor='Player-peer',target='Player-victim',time=now,contribution=now-1}}}}
C.members={};C.guildKey=nil
assert(type(C.ViewGuildKey)=='function'and C.ViewGuildKey()=='Guild-Realm','a fresh alt can select its same-realm shared guild history for read-only display')
local peer;for _,g in ipairs(C.LeaderboardGroups('Lifetime',now+3))do if g.name=='Peer'then peer=g end end
assert(peer and peer.k==1,'read-only cache includes ledger-derived observed kills, not just raw zero records')
assert(C.guildKey==nil and not C.CanPostTopReport()and not C.SendPacket('2|Q'),'cached display cannot grant active guild identity, report authorization or outgoing sync')
assert(C.account.guildMembership['Guild-Realm'].members['Third-Realm']==nil,'viewing a cache does not manufacture alt guild membership')
C.account.guilds['Other-Realm']={};assert(C.ViewGuildKey()==nil,'ambiguous cached guilds do not select an arbitrary scope')
C.account.viewGuilds={Realm='Guild-Realm'};assert(C.ViewGuildKey()=='Guild-Realm','last verified same-realm scope resolves cache ambiguity without changing active identity')
C.account.guilds['Foreign-Elsewhere']={};C.account.viewGuilds.Realm='Foreign-Elsewhere';assert(C.ViewGuildKey()==nil,'a stale cross-realm preference cannot choose foreign history')
print('PASS shared local cache: serialized alt transitions, sighting union, fresh metadata, independent attribution, scoped read-only guild view and transport isolation')
