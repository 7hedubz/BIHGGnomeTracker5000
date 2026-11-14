local root=arg[1]or'.'
local t=1700000000
local function make(db,account)
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Safe=function(fn,...)if type(fn)=='function'then return fn(...)end end;A.Secret=function()return false end
 A.Init(db or{},'Me-Realm',t);A.InitAccount(account or{},'account',t)
 A.guildKey='Guild-Realm';A.members={['Me-Realm']=true};A.InitGroupTracking(t)
 return A
end
local A=make()
assert(A.AddHonorClaim('Me-Realm','Player-me','Player-victim',t,t,t,'Player-one:1','root','A'))
assert(not A.AddHonorClaim('Me-Realm','Player-me','Player-victim',t+4,t+4,t+4,'Player-two:1','root','H'))
assert(not A.AddHonorClaim('Me-Realm','Player-me','Player-victim',t-4,t-4,t+4,'Player-three:1','root','A'))
assert(A.db.owners[A.owner].total==1,'three observers with four-second skew merge one actor/victim life')
assert(A.AddHonorClaim('Me-Realm','Player-me','Player-victim',t+6,t+6,t+6,'Player-two:2','Player-two:1','H'))
assert(A.db.owners[A.owner].total==2,'explicit next-life predecessor counts a real resurrected kill')
local B=make();local packets=A.GroupPackets(true,t+6)
for _,packet in ipairs(packets)do B.ReceiveGroup(packet,'Me-Realm',t+6)end
for _,packet in ipairs(packets)do B.ReceiveGroup(packet,'Me-Realm',t+6)end
assert(B.db.owners[B.owner].total==2,'reordered history and replay preserve one credit per life')
assert(A.AddHonorClaim('Me-Realm','Player-me','Player-victim',t+12,t+12,t+12,'Player-one:3','Player-two:2','H'))
local C=make();for _,packet in ipairs(A.GroupPackets(true,t+12))do C.ReceiveGroup(packet,'Me-Realm',t+12)end
assert(C.db.owners[C.owner].total==3,'one reverse-ordered history transfer resolves all predecessor levels without replay')
C.PeerRecords()['Me-Realm']={total=0,deaths=0,days={},deathDays={},characterGUID='Player-me'}
assert(not C.AddHonorClaim('Me-Realm','Player-other','Player-spoof',t+12,t+12,t+12,'Player-attacker:1','root','H'),'literal member name cannot hide contradictory actor GUID')
assert(not C.ReceiveGroup('5|E|K|'..C.EncodeAlias('Me-Realm')..'|Player-me|Player-old-policy|'..(t+12)..'|'..(t+12),'Me-Realm',t+12),'legacy future CC-only claims cannot bypass new policy')
print('PASS typed honor claims merge observer aliases, upgrade provenance, preserve next life and history replay')
-- Three independently initialized observers, real typed wire + shared Receive.
local observers={make(),make(),make()};local viewer=make()
viewer.members['Witness-Realm']=true
for i,observer in ipairs(observers)do
 local offset=({0,4,-4})[i]
 assert(observer.AddHonorClaim('Me-Realm','Player-me','Player-shared',t+offset,t+offset,t+4,'Player-observer-'..i..':1','root',i==2 and'H'or'A'))
end
for _,i in ipairs({3,1,2,2,3,1})do for _,packet in ipairs(observers[i].GroupPackets(true,t+4))do viewer.Receive(packet,'GUILD','Witness-Realm',t+4)end end
assert(viewer.db.owners[viewer.owner].total==1,'three real observer stores and reordered +4/-4 wire replay merge one actor/life')
for i,observer in ipairs(observers)do
 assert(observer.AddHonorClaim('Me-Realm','Player-me','Player-shared',t+10,t+9,t+10,'Player-observer-'..i..':2','Player-observer-'..i..':1','H'))
end
for _,i in ipairs({2,3,1})do for _,packet in ipairs(observers[i].GroupPackets(true,t+10))do viewer.Receive(packet,'GUILD','Witness-Realm',t+10)end end
assert(viewer.db.owners[viewer.owner].total==2,'confirmed successor links merge later real life across three observers')
print('PASS three independent observer stores: reordered wire, clock skew, replay, self/assist provenance and successor life')
local moving=make();moving.members['Friend-Realm']=true
assert(moving.AddHonorClaim('Friend-Realm','Player-friend','Player-move',t,t,t,'Player-friend:1','root','H'))
assert(moving.AddHonorClaim('Me-Realm','Player-me','Player-move',t+10,t+9,t+10,'Player-me:2','Player-friend:1','H'))
moving.guildKey='NewGuild-Realm';moving.CarryOwnGuildHistory(t+10);moving.RebuildOwnGuildTotals(t+10)
assert(moving.db.owners[moving.owner].total==1,'own successor credit survives guild move even when its predecessor belonged only to another actor')
assert(moving.GuildEffectiveRecord('Friend-Realm',nil,t+10).total==0,'predecessor metadata must not carry another guildmate statistics')
local movedViewer=make();movedViewer.guildKey='NewGuild-Realm'
local movedPackets=moving.GroupPackets(true,t+10)
for i=#movedPackets,1,-1 do movedViewer.ReceiveGroup(movedPackets[i],'Me-Realm',t+10)end
assert(movedViewer.db.owners[movedViewer.owner].total==1,'a new-guild peer can resolve carried own history without former-guild actor records')
local bounded=make()
for i=1,100 do bounded.ReceiveHonorLineage('Player-orphan-'..i,'Player-context:'..i,'root',t)end
local orphanCount=0;for _,life in pairs(bounded.account.guildObservations[bounded.guildKey].killLives)do if life.contextOnly then orphanCount=orphanCount+1 end end
assert(orphanCount==64,'uncredited peer lineage context is capped at 64 rather than growing a second unbounded ledger')
assert(bounded.ReceiveHonorLineage('Player-orphan-new','Player-context:101','root',t+121),'uncredited expired peer contexts free their bounded slots')

-- An old witness and a typed claim can describe the same preserved kill.
local function clone(v)if type(v)~='table'then return v end;local q={};for k,x in pairs(v)do q[k]=clone(x)end;return q end
for _,typedFirst in ipairs({false,true})do
 local day=math.floor(t/86400)
 local db={owners={['Me-Realm']={total=1,deaths=0,days={[day]=1},deathDays={}}}}
 local M=make(db);M.members['Witness-Realm']=true
 local when=t-1
 local legacy=table.concat({'5','E','K',M.EncodeAlias('Me-Realm'),'Player-me','Player-history',when,when},'|')
 local typed=table.concat({'5','H',M.EncodeAlias('Me-Realm'),'Player-me','Player-history',when,when,'Player-history:1','root','A'},'|')
 local first,second=typedFirst and typed or legacy,typedFirst and legacy or typed
 M.Receive(first,'GUILD','Witness-Realm',t);M.Receive(second,'GUILD','Witness-Realm',t)
 assert(M.db.owners[M.owner].total==1,'legacy/typed historical kill must count once in either wire order')
 M.Receive(typed,'GUILD','Witness-Realm',t);M.Receive(legacy,'GUILD','Witness-Realm',t)
 assert(M.db.owners[M.owner].total==1,'repeated mixed historical packets stay idempotent')
 local events=M.account.guildObservations[M.guildKey].events;local count,kept=0
 for _,e in pairs(events)do count=count+1;kept=e end
 assert(count==1 and kept.claim=='Player-history:1','matching legacy event upgrades to typed provenance without an extra event')
 M.Receive(typed:sub(1,-2)..'H','GUILD','Witness-Realm',t)
 assert(M.db.owners[M.owner].total==1 and kept.provenance=='H','self HK upgrades historical assist without another credit')
 local reload=make(clone(M.db),clone(M.account));reload.members['Witness-Realm']=true
 reload.Receive(typed,'GUILD','Witness-Realm',t);reload.Receive(legacy,'GUILD','Witness-Realm',t)
 assert(reload.db.owners[reload.owner].total==1,'serialized mixed replay stays one credit')
 assert(reload.AddHonorClaim('Me-Realm','Player-me','Player-history',t+1,t,t+1,'Player-history:2','Player-history:1','H'))
 assert(reload.db.owners[reload.owner].total==2,'a proved rapid successor remains a distinct kill')
end
print('PASS mixed legacy/typed historical credit: wire order, provenance upgrade, reload and rapid successor')

for _,offset in ipairs({1,-1,3})do for _,typedFirst in ipairs({false,true})do
 local day=math.floor(t/86400);local M=make({owners={['Me-Realm']={total=1,deaths=0,days={[day]=1},deathDays={}}}});M.members['Witness-Realm']=true
 local when=t-5
 local legacy=table.concat({'5','E','K',M.EncodeAlias('Me-Realm'),'Player-me','Player-skewed-history',when,when},'|')
 local typed=table.concat({'5','H',M.EncodeAlias('Me-Realm'),'Player-me','Player-skewed-history',when+offset,when,'Player-skew:1','root','H'},'|')
 M.Receive(typedFirst and typed or legacy,'GUILD','Witness-Realm',t)
 M.Receive(typedFirst and legacy or typed,'GUILD','Witness-Realm',t)
 assert(M.db.owners[M.owner].total==1,'compatible mixed-history clock skew must be order-independent: '..offset)
end end
print('PASS mixed historical root claims also reconcile compatible clock offsets')

local savedNow=t;t=(math.floor(t/86400)+1)*86400+20
for _,typedFirst in ipairs({false,true})do
 local when=t-21;local oldDay=math.floor(when/86400)
 local M=make({owners={['Me-Realm']={total=1,deaths=0,days={[oldDay]=1},deathDays={}}}});M.members['Witness-Realm']=true
 local legacy=table.concat({'5','E','K',M.EncodeAlias('Me-Realm'),'Player-me','Player-midnight',when,when},'|')
 local typed=table.concat({'5','H',M.EncodeAlias('Me-Realm'),'Player-me','Player-midnight',when+1,when,'Player-midnight:1','root','H'},'|')
 M.Receive(typedFirst and typed or legacy,'GUILD','Witness-Realm',t)
 M.Receive(typedFirst and legacy or typed,'GUILD','Witness-Realm',t)
 assert(M.db.owners[M.owner].total==1,'mixed migration must preserve baseline dates across midnight in either order')
end
t=savedNow
print('PASS mixed historical migration preserves the original daily allocation across midnight')
