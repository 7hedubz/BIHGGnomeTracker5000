local root=arg[1] or '.'
-- Parser/account tests explicitly run in the readable native world contract.
function IsInInstance()return false,'none'end
local now=1700000000;date=os.date
local units={player={name='Me',guid='Player-me',guild='Guild'},pet={guid='Pet-me'},party1={name='Friend',guid='Player-friend',guild='Guild'},partypet1={guid='Pet-friend'},party2={name='Guest',guid='Player-guest',guild='Other'}}
function UnitExists(u)return units[u]~=nil end
function UnitGUID(u)return units[u] and units[u].guid end
function UnitName(u)return units[u] and units[u].name,'Realm' end
function UnitHealthMax()return 1000 end
function UnitAffectingCombat()return true end
function UnitIsDeadOrGhost()return false end
function GetGuildInfo(u)return units[u] and units[u].guild end
function IsInRaid()return false end
function GetNumSubgroupMembers()return 2 end
function GetNumGroupMembers()return 3 end
local function make(owner)
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Safe=function(fn,...)if not fn then return end;local ok,v=pcall(fn,...);if ok then return v end end
 A.Secret=function()return false end
 A.Name=function(n)return n and (n:find('-',1,true) and n or n..'-Realm')end
 A.Race=function(g)return g=='Player-gnome' and 'Gnome' or 'Human' end
 A.Init({},owner,now);A.InitAccount({},owner:gsub('%W',''),now)
 A.guildName='Guild';A.guildKey='Guild-Realm';A.members={['Me-Realm']=true,['Friend-Realm']=true,['Alt-Realm']=true,['Witness-Realm']=true}
 local f=io.open(root..'/GroupTracker.lua');assert(f,'Guild-only group observation not implemented');f:close()
 assert(loadfile(root..'/GroupTracker.lua'))('BIHGGnomeKillTracker5000',A)
 A.InitGroupTracking(now);A.RefreshGroupActors()
 -- Synthetic HK injection for ledger/actor unit tests; native delivery is
 -- exercised separately by honor_kills.lua through the actual TOC.
 local observe,death=A.GroupObserve,A.GroupDeath
 A.GroupObserve=function(g,r,h,hp,t,dead)
  A.OpenWorldKillsAllowed()
  A.HonorSight(g,g..'-Realm',r,h,dead,t);return observe(g,r,h,hp,t,dead)
 end
 A.GroupDeath=function(g,t,corpse,confirmed)
  death(g,t,corpse,confirmed)
  local c=(A.killCandidates or{})[g]
  if c and not c.confirmed then return A.ConfirmHonorCandidate(c,t)end
  return false
 end
 return A
end
local A=make('Me-Realm')
local baseline=make('Me-Realm')
assert(baseline.ReceiveGroup('5|B|'..baseline.EncodeAlias('Friend-Realm')..'|'..now..'|4|retired|'..baseline.Day(now)..'|2|ignored','Friend-Realm',now),'legacy baseline death slots are ignored rather than validated')
local preserved=baseline.PeerRecords()['Friend-Realm'].guildBase
assert(preserved.total==4 and preserved.days[baseline.Day(now)]==2 and preserved.deaths==nil and preserved.deathDays==nil,'legacy baseline preserves only kill evidence')
assert(not A.PeerRecords()['Friend-Realm'],'group discovery creates no observed-only peer row')
assert(A.groupSources['Player-friend'] and A.groupSources['Pet-friend'],'guild group players and their pets resolve to character')
assert(not A.groupSources['Player-guest'],'non-guild group member excluded')
A.GroupObserve('Player-gnome','Gnome',true,1000,now,false)
assert(A.GroupDeath('Player-gnome',now+1),'injected personal HK confirms local corpse credit')
assert(A.GuildEffectiveRecord('Friend-Realm',nil,now+1).total==0,'own HK does not award a guild group assist')
assert(A.AddHonorClaim('Friend-Realm','Player-friend','Player-gnome',now+1,now+1,now+1,'Player-friend:1','root','H'),'guildmate independently reported H remains accepted')
local friend=A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+1)
assert(friend.total==1 and A.db.owners[A.owner].total==1,'own HK and independent peer H are credited separately')
assert(not A.PeerRecords()['Guest-Realm'],'guest never gets a statistics record')
assert(not A.GroupDeath('Player-gnome',now+1),'duplicate corpse ignored')
A.GroupObserve('Player-gnome','Gnome',true,1000,now+10,false)
A.GroupDeath('Player-gnome',now+11,true)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+11).total==1,'another personal HK does not add to the guildmate reported history')
A.GroupObserve('Player-gnome','Gnome',true,nil,now+20,false)
A.GroupDeath('Player-gnome',now+21,true)
assert(A.AddHonorClaim('Friend-Realm','Player-friend','Player-friend-next',now+21,now+21,now+21,'Player-friend:2','root','H'))
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+21).total==2,'independent reported H credits count without contribution collectors')
local packets=A.GroupPackets(true,now+22);assert(#packets>0)
for _,p in ipairs(packets)do assert(#p<=255,'observer protocol exceeds packet bound')end
local C=make('Viewer-Realm')
C.Receive('2|S|2|0|'..A.Day(now)..'|2|0','GUILD','Friend-Realm',now+22)
for _,p in ipairs(packets)do C.Receive(p,'GUILD','Me-Realm',now+22)end
for _,p in ipairs(packets)do C.Receive(p,'GUILD','Witness-Realm',now+22)end
for _,p in ipairs(packets)do if p:match('^5|E|')then local f={};for x in p:gmatch('[^|]+')do f[#f+1]=x end;f[7]=tostring(tonumber(f[7])+1);C.Receive(table.concat(f,'|'),'GUILD','Witness-Realm',now+23)end end
assert(C.GuildEffectiveRecord('Friend-Realm',C.PeerRecords()['Friend-Realm'],now+22).total==2,'multiple observers and replay cannot double-count')
local standalone
for _,g in ipairs(C.LeaderboardGroups('Lifetime',now+22))do if g.name=='Friend' then standalone=g end end
assert(standalone and standalone.k==2,'non-addon guildmate remains separate character')
-- Installing the addon later must retain prior witnessed kills and join an alias, not duplicate them.
local B=make('Friend-Realm');B.SetAlias('Buddy',now+30)
for _,p in ipairs(packets)do B.Receive(p,'GUILD','Me-Realm',now+31)end
B.RebuildOwnGuildTotals(now+31)
assert(B.db.owners[B.owner].total==2,'installing later imports observed character history')
local adopted
for _,g in ipairs(B.LeaderboardGroups('Lifetime',now+31))do if g.name=='Buddy' then adopted=g end end
assert(adopted and adopted.k==2,'observed history follows new alias')
for _,p in ipairs(B.BuildPackets(true,now+31))do C.Receive(p,'GUILD','Friend-Realm',now+32)end
local remoteAlias
for _,g in ipairs(C.LeaderboardGroups('Lifetime',now+32))do if g.name=='Buddy'then remoteAlias=g end end
assert(remoteAlias and remoteAlias.k==2,'guild sees alias adoption without duplicated observed totals')
-- Existing legacy counters may overlap pre-upgrade witnesses: use a conservative max per day.
local L=make('Legacy-Realm');local day=A.Day(now)
L.PeerRecords()['Friend-Realm']={total=5,deaths=0,days={[day]=5},deathDays={},guildBase={since=now+100,total=5,deaths=0,days={[day]=5},deathDays={}}}
for _,p in ipairs(packets)do L.Receive(p,'GUILD','Me-Realm',now+22)end
assert(L.GuildEffectiveRecord('Friend-Realm',L.PeerRecords()['Friend-Realm'],now+22).total==5,'legacy overlap does not sum twice')
L.AddGuildEvent('K','Friend-Realm','Player-friend','Player-new-victim',now+110,now+109,now+110)
assert(L.GuildEffectiveRecord('Friend-Realm',L.PeerRecords()['Friend-Realm'],now+110).total==6,'post-cutoff history adds above preserved legacy counters')
local oldRaid=IsInRaid;IsInRaid=function()return true end;units.raid1=units.party1;units.raidpet1=units.partypet1;units.raid2=units.party2
A.RefreshGroupActors();assert(A.groupSources['Pet-friend']and not A.groupSources['Player-guest'],'raid pets retain guild-only ownership')
IsInRaid=oldRaid
-- Moving guild preserves one's own history, without importing unrelated old guild members.
local oldGuild=A.guildKey;A.guildKey='NewGuild-Realm';A.CarryOwnGuildHistory(now+45);A.RebuildOwnGuildTotals(now+45)
assert(A.db.owners[A.owner].total==3 and A.db.owners[A.owner].deaths==nil,'own lifetime history survives guild change')
assert(A.GuildEffectiveRecord('Friend-Realm',nil,now+45).total==0,'old guild peer history is not carried as personal history')
A.guildKey=oldGuild
local sentPacket
InCombatLockdown=function()return false end
C_ChatInfo={SendAddonMessage=function(_,packet)sentPacket=packet;return 0 end}
A.outgoing={'OLD_PACKET'};A.outIndex=1;A.request=false;A.lastRequest=now+46;A.groupPriorityBurst=0
A.AddGuildEvent('K','Friend-Realm','Player-friend','Player-priority-victim',now+46,now+45,now+46)
A.Pump(now+46)
assert(sentPacket and sentPacket:find('Player-priority-victim',1,true),'fresh witness events bypass historical backlog')
A.members['Friend-Realm']=nil
for _,g in ipairs(A.LeaderboardGroups('Lifetime',now+50))do for _,r in ipairs(g.children)do assert(r.name~='Friend-Realm','departed member remains on leaderboard')end end
A.guildKey=nil;A.members={};A.RefreshGroupActors()
assert(not next(A.groupSources),'unguilded player cannot observe/award group statistics')
assert(#A.LeaderboardGroups('Lifetime',now+50)==0,'only guildmates are tallied, including self')
print('PASS group tracker: guild-only party/pets, independent H reports, no discovery-only score rows, corpse and multi-observer dedup, alias adoption, retired death counters, departed/unguilded filtering')
