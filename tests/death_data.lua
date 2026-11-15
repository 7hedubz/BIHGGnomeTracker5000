local root=arg[1]or'.';local now=1700000000
local function addon()
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','Identity.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 return A
end
local function clone(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out end
local A=addon();local day=A.Day(now)
local function record(n)return{total=n,days={[day]=n},deaths=7,deathDays={[day]=7},guildBase={since=now-100,total=n,days={[day]=n},deaths=4,deathDays={[day]=4}},alias='Keep alias',characterGUID='Player-hero'}end
local function legacy()
 return{owners={['Main-Realm']=record(8)},characters={['Alt-Realm']=record(3)},guilds={['Guild-Realm']={['Peer-Realm']=record(5)}},identityArchives={['Player-hero']={old=record(6)}},guildObservations={['Guild-Realm']={events={kill={kind='K',actor='Player-hero',target='Player-victim',life='Player-victim:1',time=now},ownDeath={kind='D',actor='Player-hero',target='Player-gnome',time=now}}}},recaps={['death:1']=now},deathOutcomes={{reason='counted'}},deathRecapsSeen={['1']=now},playerDeaths={['death:1']=now},dead={['Player-victim']=now},knownEncounters={['Player-victim']={name='Tiny',race='Gnome',level=60,class='Mage',first=now,last=now,days={[day]=true}}}}
end
local function clean(t)
 if type(t)~='table'then return end
 assert(t.deaths==nil and t.deathDays==nil and t.deathOutcomes==nil and t.deathRecapsSeen==nil and t.playerDeaths==nil and t.recaps==nil,'legacy death persistence remains')
 assert(t.kind~='D','legacy death event remains')
 for _,v in pairs(t)do clean(v)end
end
-- Recursive migration reaches archived copies, offline alts and nested ledgers,
-- but enemy corpse/life identities are still required for kill deduplication.
local db,account=legacy(),legacy()
assert(type(A.RemoveDeathData)=='function','recursive death-data migration is missing')
A.RemoveDeathData(db);A.RemoveDeathData(account);clean(db);clean(account)
assert(db.owners['Main-Realm'].total==8 and db.owners['Main-Realm'].days[day]==8)
assert(db.owners['Main-Realm'].guildBase.total==8 and db.owners['Main-Realm'].guildBase.since==now-100)
assert(account.identityArchives['Player-hero'].old.total==6 and account.characters['Alt-Realm'].total==3)
assert(db.dead['Player-victim']==now and db.guildObservations['Guild-Realm'].events.kill.life=='Player-victim:1')
assert(db.owners['Main-Realm'].alias=='Keep alias'and db.owners['Main-Realm'].characterGUID=='Player-hero')
assert(db.knownEncounters['Player-victim'].level==60 and db.knownEncounters['Player-victim'].class=='Mage')
A.RemoveDeathData(db);clean(db)
-- Real initialization must purge both independently serialized saved roots
-- before account merging can clone a stale offline/archive/baseline record.
A=addon();db,account=legacy(),legacy();account.characters['Main-Realm']=record(9)
A.Init(db,'Main-Realm',now);A.InitAccount(account,'mine',now);clean(db);clean(account)
assert(db.owners['Main-Realm'].total==9 and db.owners['Main-Realm'].days[day]==9,'max merge retains kills without summing duplicate saved copies')
A.SnapshotAccount(now);clean(db);clean(account)
local B=addon();B.Init(clone(db),'Main-Realm',now+1);B.InitAccount(clone(account),'ignored',now+1);clean(B.db);clean(B.account)
assert(B.db.owners['Main-Realm'].total==9 and B.account.characters['Alt-Realm'].total==3,'reload retains per-character kills')
-- Legacy wire reserves two numeric death slots. Read their syntax only,
-- retain neither value, and always emit zeros (including offline-alt relays).
B.guildKey='Guild-Realm';B.members={['Peer-Realm']=true,['Unknown-Realm']=true,['Alt-Realm']=true}
assert(B.Receive('2|S|12|777|'..day..'|4|222','GUILD','Peer-Realm',now+1))
assert(B.Receive('2|S|12|0|'..day..'|4|9999999999999','GUILD','Peer-Realm',now+1),'retired reserved slots must not be interpreted as death counters')
clean(B.db);clean(B.account)
assert(B.PeerRecords()['Peer-Realm'].total==12 and B.PeerRecords()['Peer-Realm'].days[day]==5,'incoming kills merge monotonically')
assert(B.Receive('3|I|remote|'..B.EncodeAlias('Remote')..'|'..now,'GUILD','Peer-Realm',now+1))
assert(not B.Receive('4|R|'..B.EncodeAlias('Missing-Realm')..'|2|S|4|888|'..day..'|2|333','GUILD','Peer-Realm',now+1))
assert(B.pendingAltScores[1].msg:find('|2|S|4|0|'..day..'|2|0',1,true),'buffered alt packet must not retain discarded death values')
for _,p in ipairs(B.BuildPackets(true,now+1))do
 local k,d,bucket,dk,dd=p:match('2|S|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$')
 if k then assert(d=='0'and dd=='0','outgoing packet contains death stats')end
end
B.SnapshotAccount(now+2);clean(B.db);clean(B.account)
-- Identity reconciliation archives and merges another spelling without
-- rebuilding removed counters/baselines, even for pre-upgrade late copies.
local C=addon();C.Init({},'Hero Full-Realm',now);C.InitAccount({},'hero-account',now)
C.guildKey='Guild-Realm';C.members={['Hero Full-Realm']=true,['Hero-Realm']=true}
C.account.characters['Hero-Realm']=record(7)
assert(C.BindLocalCharacter('Player-hero',now));clean(C.db);clean(C.account)
assert(C.db.owners[C.owner].total==7 and C.account.identityArchives['Player-hero']['Hero-Realm'].total==7,'identity archive preserves kill provenance')
C.PeerRecords()['Remote-Realm']={total=2,days={[day]=2},characterGUID='Player-remote'}
C.PeerRecords()['Remote Alias-Realm']=record(4);C.PeerRecords()['Remote Alias-Realm'].characterGUID='Player-remote'
C.account.guildIdentities={['Guild-Realm']={guids={['Player-remote']='Remote-Realm'},names={}}}
assert(C.ObserveGuildCharacter('Remote Alias-Realm','Player-remote',now)=='Remote-Realm');clean(C.db);clean(C.account)
assert(C.PeerRecords()['Remote-Realm'].total==4,'roster identity merge retains kill max')
print('PASS death data: recursive legacy purge preserves kill totals, baselines, life IDs, aliases and encounter metadata')
