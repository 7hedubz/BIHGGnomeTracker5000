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
for _,kind in ipairs({'SWING_DAMAGE','SPELL_DAMAGE','SPELL_PERIODIC_DAMAGE','RANGE_DAMAGE','DAMAGE_SHIELD'})do
 local T=make('Me-Realm');local first=kind=='SWING_DAMAGE'and 12 or 15
 local hit={[2]=kind,[4]='Player-gnome',[8]='Player-friend'}
 hit[first]=11;hit[first+1]=10;hit[first+4]=1
 T.GroupCombat(hit,now)
 assert(not T.IncomingDeathEvidence('Player-friend',now),'incoming effective damage must subtract blocked mitigation: '..kind)
 hit[first+4]=0;hit[3]=true;T.groupIncoming={};T.GroupCombat(hit,now)
 assert(not T.IncomingDeathEvidence('Player-friend',now),'hidden caster must not prove incoming damage')
end
for _,event in ipairs({'SPELL_AURA_APPLIED','SPELL_AURA_REFRESH','SPELL_AURA_APPLIED_DOSE'})do
 local T=make('Me-Realm')
 local aura={[2]=event,[4]='Player-gnome',[8]='Player-friend',[12]=172,[15]='DEBUFF',[3]=true}
 T.GroupCombat(aura,now+200)
 assert(not T.IncomingDeathEvidence('Player-friend',now+200),'hidden harmful caster is not proof')
 aura[3]=false;T.GroupCombat(aura,now+200)
 assert(T.IncomingDeathEvidence('Player-friend',now+200),'explicit synthetic '..event..' must collect incoming harmful proof')
 T.GroupCombat({[2]='UNIT_DIED',[8]='Player-friend'},now+201)
 assert(T.GuildEffectiveRecord('Friend-Realm',T.PeerRecords()['Friend-Realm'],now+201).deaths==1,'harmful contribution plus actual death counts')
end
local A=make('Me-Realm')
assert(A.PeerRecords()['Friend-Realm'].observerOnly,'guild group member is discovered before earning any credit')
assert(A.groupSources['Player-friend'] and A.groupSources['Pet-friend'],'guild group players and their pets resolve to character')
assert(not A.groupSources['Player-guest'],'non-guild group member excluded')
A.GroupObserve('Player-gnome','Gnome',true,1000,now,false)
A.GroupCC('Player-gnome',172,'Player-friend',now,true)
A.GroupDamage('Player-gnome',1000,0,'Player-guest',now)
A.GroupCC('Player-gnome',118,'Player-me',now)
assert(A.GroupDeath('Player-gnome',now+1),'eligible guild contributions awarded on death')
local friend=A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+1)
assert(friend.total==1 and A.db.owners[A.owner].total==1,'own and non-addon guildmate credited independently')
assert(not A.PeerRecords()['Guest-Realm'],'guest never gets a statistics record')
assert(not A.GroupDeath('Player-gnome',now+1),'duplicate corpse ignored')
A.GroupObserve('Player-gnome','Gnome',true,1000,now+10,false)
A.GroupDamage('Player-gnome',19,0,'Player-friend',now+10)
A.GroupDeath('Player-gnome',now+11,true)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+11).total==1,'under two percent is not credit')
A.GroupObserve('Player-gnome','Gnome',true,nil,now+20,false)
A.GroupCC('Player-gnome',118,'Pet-friend',now+20);A.GroupDeath('Player-gnome',now+21,true)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+21).total==2,'confirmed guildmate pet CC qualifies without guessed max HP')
local packets=A.GroupPackets(true,now+22);assert(#packets>0)
for _,p in ipairs(packets)do assert(#p<=255,'observer protocol exceeds packet bound')end
local C=make('Viewer-Realm')
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
assert(L.GuildEffectiveRecord('Friend-Realm',L.PeerRecords()['Friend-Realm'],now+110).total==6,'post-upgrade contributions add to preserved legacy history')
-- Other players' deaths require readable lethal damage plus confirmed death.
local damage={};damage[2]='SWING_DAMAGE';damage[4]='Player-gnome';damage[8]='Player-friend';damage[12]=1000;damage[13]=0
A.GroupCombat(damage,now+35)
local died={};died[2]='UNIT_DIED';died[8]='Player-friend';A.GroupCombat(died,now+35)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+35).deaths==1,'confirmed Gnome killing blow records group death')
A.GroupCombat(died,now+36)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+36).deaths==1,'a corpse alone does not assign another killer')
damage[12]=19;A.GroupCombat(damage,now+38)
local human={};human[2]='SWING_DAMAGE';human[4]='Player-human';human[8]='Player-friend';human[12]=1000;human[13]=0
A.GroupCombat(human,now+39);A.GroupCombat(died,now+39)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+39).deaths==2,'any positive Gnome damage is sufficient despite another final blow')
damage[12]=20;A.GroupCombat(damage,now+43);A.GroupCombat(human,now+44);A.GroupCombat(died,now+44)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+44).deaths==3,'positive Gnome contribution counts despite a Human final blow')
local oldCombat=UnitAffectingCombat;local fighting=true;UnitAffectingCombat=function()return fighting end
A.GroupCombat(damage,now+50);fighting=false;A.UpdateDeathCombat('Player-friend','party1',now+51)
fighting=true;A.UpdateDeathCombat('Player-friend','party1',now+52);A.GroupCombat(human,now+53);A.GroupCombat(died,now+53)
assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],now+53).deaths==3,'a new combat cannot reuse Gnome damage from the prior fight');UnitAffectingCombat=oldCombat
local D=make('Me-Realm')
assert(D.AddGuildEvent('D','Friend-Realm','Player-friend','Player-gnome-a',now+60,now+60,now+60))
assert(not D.AddGuildEvent('D','Friend-Realm','Player-friend','Player-gnome-b',now+60,now+60,now+60),'different qualifying contributors cannot duplicate one victim death')
assert(D.GuildEffectiveRecord('Friend-Realm',D.PeerRecords()['Friend-Realm'],now+60).deaths==1,'death witness deduplication remains one per victim event')
-- Confirmed incoming Gnome kills only; merely seeing a guildmate dead must not invent a killer.
local proof={damage=600,maxHealth=1000,source='Player-gnome',time=now+40}
A.GroupOwnDeath('recap1','Gnome',now+40,'Player-gnome',proof)
A.GroupOwnDeath('recap1','Gnome',now+40,'Player-gnome',proof)
assert(A.db.owners[A.owner].deaths==1,'own confirmed Gnome death deduplicates')
local oldRaid=IsInRaid;IsInRaid=function()return true end;units.raid1=units.party1;units.raidpet1=units.partypet1;units.raid2=units.party2
A.RefreshGroupActors();assert(A.groupSources['Pet-friend']and not A.groupSources['Player-guest'],'raid pets retain guild-only ownership')
IsInRaid=oldRaid
-- Moving guild preserves one's own history, without importing unrelated old guild members.
local oldGuild=A.guildKey;A.guildKey='NewGuild-Realm';A.CarryOwnGuildHistory(now+45);A.RebuildOwnGuildTotals(now+45)
assert(A.db.owners[A.owner].total==3 and A.db.owners[A.owner].deaths==1,'own lifetime history survives guild change')
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
print('PASS group tracker: guild-only party/pets, HK-confirmed harmful assists, non-addon characters, corpse and multi-observer dedup, alias adoption, confirmed deaths, departed/unguilded filtering')
