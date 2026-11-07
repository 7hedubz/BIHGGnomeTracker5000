local root=arg[1]or'.';local A={};local now=1700000000;date=os.date
for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
A.Safe=function(fn,...)if fn then return fn(...)end end;A.Secret=function()return false end
A.Name=function(name)return name:find('-',1,true)and name or name..'-Realm'end
local day=A.Day(now);local canonical='Hero Heal-Realm';local legacy='Hero-Realm';local observed='Hero-Heal'
local old={total=5,deaths=0,days={[day]=5},deathDays={},guildBase={since=now-100,total=5,deaths=0,days={[day]=5},deathDays={}},seen={['Player-gnome']={race='Gnome',first=now-200,last=now-150,days={[day]=true}}}}
local db={owners={[legacy]=old,[canonical]={total=0,deaths=0,days={},deathDays={},guildBase={since=now,total=0,deaths=0,days={},deathDays={}}}},seen=old.seen};local account={id='my-account',alias='Hero',characters={[legacy]=old},guilds={['Guild-Realm']={[observed]={total=0,deaths=0,days={},deathDays={},observerOnly=true},['Hero-OtherRealm']={accountID='other-account',alias='Hero',bindingDirect=true,characterGUID='Player-other',total=9,deaths=0,days={[day]=9},deathDays={}}}},guildObservations={['Guild-Realm']={events={['K:Player-self:Player-target:1699999950']={kind='K',name=observed,actor='Player-self',target='Player-target',time=now-50,contribution=now-55}}}}}
account.characters[canonical]=db.owners[canonical]
A.Init(db,canonical,now);A.InitAccount(account,'ignored',now);A.guildKey='Guild-Realm';A.guildName='Guild';A.members={[canonical]=true,[legacy]=true,[observed]=true,['Hero-OtherRealm']=true}
local f=io.open(root..'/Identity.lua');assert(f,'GUID-based identity reconciliation is missing');f:close();assert(loadfile(root..'/Identity.lua'))('BIHGGnomeKillTracker5000',A)
assert(A.BindLocalCharacter('Player-self',now));A.InitGroupTracking(now);A.RebuildOwnGuildTotals(now)
local groups=A.LeaderboardGroups('Lifetime',now);local own,other
for _,g in ipairs(groups)do if g.id=='account:my-account'then own=g elseif g.id=='account:other-account'then other=g end end
assert(#groups==2 and own and #own.children==1 and own.k==6,'one real character, one own alias, legacy five plus witnessed kill exactly once')
assert(own.encountered==1 and other and other.k==9,'encounters preserved; equal display alias never merges unrelated GUIDs')
assert(not account.characters[legacy]and not db.owners[legacy]and not A.PeerRecords()[observed],'obsolete identity rows removed rather than cosmetically hidden')
assert(account.identityArchives and account.identityArchives['Player-self'][legacy],'original legacy record archived')
A.BindLocalCharacter('Player-self',now+1);A.RebuildOwnGuildTotals(now+1);assert(A.db.owners[A.owner].total==6,'migration is idempotent')
assert(not A.AddGuildEvent('K',observed,'Player-self','Player-target',now-50,now-55,now+1),'old-name witness replay cannot double count')
assert(A.CanonicalCharacterName(observed,'Player-self')==canonical,'known player GUID resolves alternate unit format')
assert(A.CanonicalCharacterName(observed,'Player-unrelated')==observed,'different GUID never follows a matching name alias')
-- A guildmate learns the same link from direct account metadata plus character GUID.
local B={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',B)end
B.Safe=A.Safe;B.Secret=A.Secret;B.Init({},'Viewer-Realm',now);B.InitAccount({},'viewer-account',now);B.guildKey='Guild-Realm';B.members={['Viewer-Realm']=true,[canonical]=true,[observed]=true};B.InitGroupTracking(now)
B.AddGuildEvent('K',observed,'Player-self','Player-target',now-50,now-55,now)
assert(B.Receive('3|I|my-account|'..B.EncodeAlias('Hero')..'|'..now,'GUILD',canonical,now))
assert(B.Receive('6|C|Player-self','GUILD',canonical,now),'direct guild character GUID binding accepted')
local remote
for _,g in ipairs(B.LeaderboardGroups('Lifetime',now))do if g.id=='account:my-account'then remote=g end end
assert(remote and remote.k==1 and #remote.children==1 and not B.PeerRecords()[observed],'remote witnessed kill follows account identity with no duplicate row')
assert(not B.Receive('6|C|not-a-guid','GUILD',canonical,now),'malformed GUID rejected')
assert(not B.Receive('6|C|Player-unrelated','GUILD',canonical,now),'an established character GUID cannot silently change')
B.members['Stranger-Realm']=true;assert(B.Receive('3|I|other-owner|'..B.EncodeAlias('Other')..'|'..now,'GUILD','Stranger-Realm',now))
assert(not B.Receive('6|C|Player-self','GUILD','Stranger-Realm',now),'conflicting account cannot take over a known GUID')
local mage='Mage Heal-Realm'
A.Init({owners={[mage]={total=3,deaths=0,days={[day]=3},deathDays={}}}},mage,now+10);A.InitAccount(account,'ignored',now+10);A.members[mage]=true
A.BindLocalCharacter('Player-alt',now+10);A.InitGroupTracking(now+10);A.RebuildOwnGuildTotals(now+10)
local joined;for _,g in ipairs(A.LeaderboardGroups('Lifetime',now+10))do if g.id=='account:my-account'then joined=g end end
assert(joined and #joined.children==2 and joined.k==9,'genuine different-GUID alts remain separate children under one alias')
local C={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',C)end
C.Safe=A.Safe;C.Secret=A.Secret;C.Init({},'Viewer-Realm',now);C.InitAccount({},'third-viewer',now);C.guildKey='Guild-Realm';C.members={['Viewer-Realm']=true,[canonical]=true,[observed]=true,[mage]=true};C.InitGroupTracking(now)
C.AddGuildEvent('K',observed,'Player-self','Player-target',now-50,now-55,now)
for _,packet in ipairs(A.BuildPackets(true,now+10))do C.Receive(packet,'GUILD',mage,now+10)end
local offline;for _,g in ipairs(C.LeaderboardGroups('Lifetime',now+10))do if g.id=='account:my-account'then offline=g end end
assert(offline and #offline.children==2 and offline.k==9 and not C.PeerRecords()[observed],'one online alt relays known offline GUID links and preserves all credit without a duplicate observed row')
print('PASS identity: local name-variant provenance, GUID linkage, legacy archive, exact witness migration, replay idempotence, independent GUID/alias isolation and guild metadata reconciliation')
local D={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',D)end
D.Safe=A.Safe;D.Secret=A.Secret
local early={total=5,deaths=0,days={[day]=5},deathDays={},updated=now-100};local ghost={total=0,deaths=0,days={},deathDays={},guildBase={since=now,total=0,deaths=0,days={},deathDays={}}}
local profile={id='legacy-account',characters={[legacy]=early,[canonical]=ghost},guildObservations={['Guild-Realm']={events={one={kind='K',name=observed,actor='Player-self',target='Player-target',time=now-50,contribution=now-55}}}}}
D.Init({owners={[legacy]=early,[canonical]=ghost}},canonical,now);D.InitAccount(profile,'ignored',now);D.guildKey='Guild-Realm';D.members={[canonical]=true,[observed]=true}
D.BindLocalCharacter('Player-self',now);D.InitGroupTracking(now);D.RebuildOwnGuildTotals(now)
assert(D.db.owners[canonical].total==6,'pre-group legacy counters without a baseline survive newer empty variants and later witnessed kills')
-- A delayed legacy summary may arrive after the GUID metadata already linked
-- its transport spelling. It must not recreate a second identity.
assert(B.Receive('2|S|1|0|'..day..'|1|0','GUILD',observed,now+1))
assert(not B.PeerRecords()[observed],'late raw-name summary cannot resurrect a reconciled remote character')
B.PeerRecords()[observed]={total=1,deaths=0,days={[day]=1},deathDays={},updated=now+2}
B.ObserveGuildCharacter(canonical,'Player-self',now+2)
assert(not B.PeerRecords()[observed],'roster reconciliation folds cached pre-upgrade aliases even when their late summary lacked a GUID')
local transport='Hero Transport-Realm';account.guildIdentities=account.guildIdentities or {}
account.guildIdentities['Guild-Realm']={names={[transport]='Player-self'},guids={['Player-self']=canonical}}
account.guilds['Guild-Realm'][transport]={total=2,deaths=0,days={[day]=2},deathDays={},updated=now+100}
-- Reload into the original real character, not its genuine mage alt.
A.Init(db,canonical,now+100);A.InitAccount(account,'ignored',now+100);A.members={[canonical]=true,[transport]=true}
A.BindLocalCharacter('Player-self',now+100);A.InitGroupTracking(now+100);A.RebuildOwnGuildTotals(now+100)
assert(not A.PeerRecords()[transport]and A.db.owners[canonical].total==6,'persisted verified aliases remove cached self echoes without moving the authoritative baseline')
assert(not A.Receive('2|S|2|0|'..day..'|2|0','GUILD',transport,now+100)and not A.PeerRecords()[transport],'own transport echo is ignored before it can recreate a peer')
