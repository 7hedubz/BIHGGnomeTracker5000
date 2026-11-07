local root=arg[1] or '.'
local A={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',A)end
local f=io.open(root..'/Dashboard.lua');assert(f,'Charts and guild reports not implemented');f:close();assert(loadfile(root..'/Dashboard.lua'))('BIHGGnomeKillTracker5000',A)
local now=1700000000;local day=A.Day(now);date=os.date
A.Init({},'Me-Realm',now);A.InitAccount({},'my-account',now)
A.guildKey='Guild-Realm';A.members={['Me-Realm']=true};local peers=A.PeerRecords()
for i=1,12 do local name='Peer'..i..'-Realm';A.members[name]=true;peers[name]={total=i,deaths=1,days={[day]=i},deathDays={[day]=1},alias='Alias'..i,accountID='peer'..i,aliasRev=now}end
local ranks=A.TopKillers('Lifetime',now)
assert(#ranks==10 and ranks[1].k==12 and ranks[10].k==3,'top ten aliases sorted by kills; zeroes excluded')
peers['Peer12-Realm'].alias=string.rep('é',30)
local lines=A.BuildTopReport('Lifetime',now)
assert(lines[2]:find(string.rep('é',30),1,true),'report preserves complete UTF-8 nickname')
assert(#lines==11 and lines[1]:find('Lifetime',1,true)and lines[1]:find('cached',1,true),'header plus one dedicated line for each of ten people')
for i=2,#lines do assert(lines[i]:match('^#'..(i-1)..' ')and not lines[i]:find(' ; ',1,true),'one ranked person per line, in order')end
for _,line in ipairs(lines)do assert(#line<=255,'chat line exceeds byte budget');assert(not line:find('-Realm',1,true),'report leaks realm suffix')end
local empty=A.BuildTopReport('Today',now+86400);assert(#empty==1 and empty[1]:find('No recorded',1,true),'empty period does not invent top ten')
A.db.owners[A.owner].days[day]=2;A.db.owners[A.owner].deathDays[day]=1
A.account.characters['Alt-Realm']={total=4,deaths=2,days={[day]=4,[day-2]=1},deathDays={[day]=2},seen={}}
A.members['Alt-Realm']=true
A.account.characters['NonGuild-Realm']={total=999,deaths=999,days={[day]=999},deathDays={[day]=999},seen={}}
local trend=A.ActivityTrend('7 days',now)
assert(#trend==7 and trend[7].kills==6 and trend[7].deaths==3,'trend aggregates account alts by UTC day')
assert(#A.ActivityTrend('Lifetime',now)==30,'lifetime trend is labeled last thirty days')
local sent={};A.Safe=function(fn,...)return fn and fn(...)end;A.Secret=function()return false end
IsInInstance=function()return false end
SendChatMessage=function(msg,channel)sent[#sent+1]={msg,channel}end
local combat=false;InCombatLockdown=function()return combat end
local guildRank='Member';GetGuildInfo=function()return'Guild',guildRank,3 end
assert(not A.StartTopPost(lines,now),'ordinary members cannot post a guild report')
guildRank='Council of BIHG'
assert(A.StartTopPost(lines,now),'explicit confirmation sends immediately')
assert(#sent==#lines and sent[1][2]=='GUILD'and not A.postJob,'all lines sent synchronously, only to guild, without pending work')
assert(not A.StartTopPost(lines,now),'duplicate click cannot start second report')
assert(not A.StartTopPost(lines,now+10),'cooldown prevents spam')
assert(A.PumpTopPost==nil,'public guild reports have no timer pump')
IsInInstance=function()return true end
assert(A.StartTopPost(lines,now+70),'dungeon allows an authorized out-of-combat report')
local beforeCombat=#sent
A.db.options.lastTopPost=nil;combat=true;assert(not A.StartTopPost(lines,now+71),'new report cannot start in combat')
assert(#sent==beforeCombat and not A.postJob,'combat rejection does not retain a deferred report');combat=false
local interrupted=0;SendChatMessage=function()interrupted=interrupted+1;combat=true end
assert(not A.StartTopPost(lines,now+72)and interrupted==1 and not A.postJob,'combat change stops remaining lines rather than deferring them')
combat=false;assert(not A.postJob,'leaving combat cannot resume an interrupted public report')
A.db.options.lastTopPost=now;IsInInstance=function()return false end
SendChatMessage=function()error('blocked')end
assert(not A.StartTopPost(lines,now+70))
assert(not A.postJob and A.postStatus:find('stopped',1,true),'failed chat send stops rather than spamming retries')
SendChatMessage=nil;local modernSent=0
C_ChatInfo={SendChatMessage=function(msg,channel)assert(channel=='GUILD');modernSent=modernSent+1 end}
assert(A.StartTopPost(lines,now+140))
assert(modernSent==#lines,'modern namespaced chat API sends the whole report synchronously')
local line=A.KillsLine('7 days',now,350,164)
assert(#line.points==7 and line.points[7].kills==6,'line uses account kill buckets, not deaths')
assert(line.points[1].x==0 and line.points[7].x==350,'time increases from left to right')
assert(line.points[7].y==6/line.ceiling*164,'vertical position represents kills')
assert(line.ticks[1]==0 and line.ticks[#line.ticks]>=6,'kill axis starts at zero and covers peak')
local today=A.KillsLine('Today',now,350,164)
assert(#today.points==1 and today.points[1].x==175,'single-day view has centered point')
local zero=A.KillsLine('Today',now+86400,350,164)
assert(zero.peak==0 and zero.points[1].y==0 and zero.ceiling>0,'zero activity has a valid flat zero scale')
A.postJob=nil;A.db.options.lastTopPost=nil;guildRank='The BIHG Cheese'
local restrictedSends=0;C_ChatInfo.SendChatMessage=function()restrictedSends=restrictedSends+1 end
assert(A.StartTopPost(lines,now+300),'The BIHG Cheese rank can post')
assert(restrictedSends==#lines,'second authorized rank can send its confirmed report')
A.db.options.lastTopPost=nil;restrictedSends=0;C_ChatInfo.SendChatMessage=function()restrictedSends=restrictedSends+1;guildRank='Member'end
assert(not A.StartTopPost(lines,now+301)and not A.postJob and restrictedSends==1,'rank loss cancels remaining lines without background retries')
guildRank='Guild Master';assert(not A.StartTopPost(lines,now+400),'no implicit guild-master or officer override')
guildRank=nil;assert(not A.StartTopPost(lines,now+400),'unreadable rank fails closed')
guildRank='Council of BIHG';A.guildUnverified=true;assert(not A.CanPostTopReport(),'cached unverified guild identity cannot authorize a public report');A.guildUnverified=nil
guildRank='council of bihg';assert(not A.CanPostTopReport(),'rank matching is exact and case sensitive')
GetGuildInfo=function()error('unavailable')end;assert(not A.CanPostTopReport(),'throwing rank API fails closed')
local secret={};A.Secret=function(v)return v==secret end;GetGuildInfo=function()return'Guild',secret end
assert(not A.CanPostTopReport(),'secret rank value fails closed before comparison')
print('PASS dashboard: top ten, bounded UTF-safe reports, charts, exact allowed ranks, rank-loss cancellation, direct-click sends/cooldown and chat API failures')
