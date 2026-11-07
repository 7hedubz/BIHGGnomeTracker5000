local root=arg[1]or'.';local now=1700000000;date=os.date
local frame={};function frame:SetScript(k,v)self[k]=v end;function frame:RegisterEvent()end
function CreateFrame()return frame end
local units={player={name='Me',realm='Realm',guid='Player-me',guild='Guild'}}
local rows={{name='Me-Realm',guid='Player-me'}};local offline=false
function GetServerTime()return now end
function GetNormalizedRealmName()return'Realm'end
function UnitName(u)local r=units[u];return r and r.name,r and r.realm end
function UnitExists(u)return units[u]~=nil end
function UnitGUID(u)return units[u]and units[u].guid end
function GetGuildInfo(u)return units[u or'player']and units[u or'player'].guild,'Member',3 end
function GetNumGuildMembers()return #rows end
function GetGuildRosterInfo(i)local r=rows[i];if r then return r.name,nil,nil,nil,nil,nil,nil,nil,true,nil,nil,nil,nil,nil,nil,nil,r.guid end end
function GetGuildRosterShowOffline()return offline end
function GetNumSubgroupMembers()return units.party1 and 1 or 0 end
function IsInRaid()return false end
function IsInGuild()return true end
local A={};for _,file in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Identity.lua','Runtime.lua'})do assert(loadfile(root..'/'..file))('BIHGGnomeKillTracker5000',A)end
A.Init({},'Me-Realm',now);A.InitAccount({},'own-account',now);A.BindLocalCharacter('Player-me',now)
A.Roster();A.InitGroupTracking(now)
units.party1={name='Buddy',realm='Full',guid='Player-buddy',guild='Guild'}
A.RefreshGroupActors();assert(A.members['Buddy-Full'],'readable guild party member accepted')
assert(A.AddGuildEvent('K','Buddy-Full','Player-buddy','Player-gnome',now+1,now,now+1))
local function score()for _,g in ipairs(A.LeaderboardGroups('Lifetime',now+2))do for _,r in ipairs(g.children)do if r.name:find('Buddy',1,true)then return g.k end end end end
assert(score()==1,'guild party contribution appears')
units.party1=nil;A.Roster()
assert(A.PeerRecords()['Buddy-Full']and score()==1,'partial roster/group departure must not delete or hide recorded guild contribution')
A.members={};A.guildKey=nil;A.rosterSeen=nil;A.Roster()
assert(score()==1,'persisted last-verified membership survives reload before full roster arrives')
rows[2]={name='Buddy Full-Realm',guid='Player-buddy'};A.Roster(true)
local canonical=A.CanonicalCharacterName('Buddy-Full','Player-buddy')
local copies=0;for _,r in pairs(A.PeerRecords())do if r.characterGUID=='Player-buddy'then copies=copies+1 end end
assert(score()==1 and copies==1 and A.CanonicalCharacterName('Buddy Full-Realm','Player-buddy')==canonical,'roster GUID reconciles alternate unit format into one stable physical identity')
rows[2]=nil;offline=true;rows[1].guid=nil;A.Roster(true);now=now+6;A.Roster(true)
assert(score()==1,'unreadable roster GUIDs cannot confirm an absence across name formats')
rows[1].guid='Player-me'
rows[2]=nil;offline=true;A.Roster(true);assert(score()==1,'first smaller roster is not enough to remove cached member')
now=now+6;A.Roster(true)
assert(not score()and A.PeerRecords()[canonical],'two stable complete offline-inclusive rosters remove membership, not history')
rows[2]={name='Buddy Full-Realm',guid='Player-buddy'};A.Roster(true);assert(score()==1,'returning roster member immediately reuses preserved score')
A.PeerRecords()[canonical]=nil;A.account.guildMembership=nil;rows[2]=nil;offline=false;A.Roster()
assert(score()==1 and A.PeerRecords()[canonical],'upgrade reconstructs rows previously pruned by old versions using retained witnessed events')
units.player.guild=nil;A.Roster();assert(score()==1 and A.guildUnverified,'temporary unreadable guild identity keeps labeled cached history')
assert(not A.AddGuildEvent('K',canonical,'Player-buddy','Player-pending-identity',now,now-1,now),'unverified guild identity cannot award a newly confirmed cached contribution')
local guildSends=0;C_ChatInfo={SendAddonMessage=function()guildSends=guildSends+1;return 0 end};function IsInInstance()return false end
assert(not A.SendPacket('2|Q')and guildSends==0,'unverified cached guild identity cannot leak sync into a different guild channel')
units.player.guild='Guild';A.Roster();assert(not A.guildUnverified and score()==1,'readable guild identity resumes without resetting history')
units.party1={name='Buddy',realm='Full',guid='Player-buddy',guild='Other'};A.RefreshGroupActors()
assert(not A.groupSources['Player-buddy']and not score(),'explicit different guild removes membership and cannot contribute')
units.party1=nil;rows[2]=nil;offline=false;A.Roster();assert(not score(),'confirmed departure is not resurrected by partial roster')
rows[2]={name='Legacy Full-Realm',guid='Player-legacy'};A.Roster()
A.PeerRecords()['Legacy-Full']={total=4,deaths=0,days={[A.Day(now)]=4},deathDays={},updated=now-10}
units.party1={name='Legacy',realm='Full',guid='Player-legacy',guild='Guild'};A.RefreshGroupActors()
local linked=A.CanonicalCharacterName('Legacy-Full','Player-legacy')
assert(linked=='Legacy Full-Realm'and not A.PeerRecords()['Legacy-Full']and A.PeerRecords()[linked].total==4,'live unit GUID binds legacy format to roster identity without losing its cached score')
print('PASS roster: guild-only group observation, partial/offline roster persistence, reload stability, GUID name reconciliation, confirmed-departure filtering and retained historical records')
