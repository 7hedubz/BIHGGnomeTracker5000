local root=arg[1]or'.';date=os.date
local function eq(a,b,msg)assert(a==b,(msg or'')..' expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)fn();print('PASS chart scope: '..name)end
local function record(day,k,d)return{total=k,deaths=d,days={[day]=k},deathDays={[day]=d},seen={}}end
local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local function same(a,b,path)
 path=path or'';eq(type(a),type(b),path)
 if type(a)~='table'then eq(a,b,path);return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' unexpected '..tostring(k))end
end
local function setup()
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Dashboard.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 local today=20000;local now=today*86400+123
 A.Init({},'Me-Realm',now);A.InitAccount({},'mine',now)
 A.guildKey='Guild-Realm';A.members={['Me-Realm']=true,['Alt-Realm']=true,['Peer-Realm']=true,['Observed-Realm']=true}
 local own=A.account.characters['Me-Realm'];own.total=2;own.deaths=1;own.days[today]=2;own.deathDays[today]=1
 A.account.characters['Alt-Realm']=record(today,3,2)
 A.account.characters['Departed-Realm']=record(today,100,100)
 local peers=A.PeerRecords();peers['Me-Realm']=record(today,900,900);peers['Alt-Realm']=record(today,800,800)
 peers['Peer-Realm']=record(today,7,4);peers['Departed-Realm']=record(today,200,200)
 peers['Observed-Realm']={total=0,deaths=0,days={},deathDays={},observerOnly=true}
 -- Same target, separate member credit: do not deduplicate across members.
 A.account.guildObservations={['Guild-Realm']={events={
  one={kind='K',name='Observed-Realm',actor='Player-observed',target='Player-target',time=now,contribution=now-1},
  two={kind='D',name='Observed-Realm',actor='Player-observed',target='Player-enemy',time=now,contribution=now-1},
  three={kind='K',name='Peer-Realm',actor='Player-peer',target='Player-target',time=now,contribution=now-1},
 }}}
 return A,today,now,own,peers
end

test('Guild daily buckets union peers and authoritative local characters with effective witness credit',function()
 local A,today,now=setup()
 local personal=A.ActivityTrend('Today',now);eq(personal[1].kills,5);eq(personal[1].deaths,3)
 local guild=A.ActivityTrend('Today',now,nil,nil,'Guild')
 eq(guild[1].kills,13,'guild member kill credit');eq(guild[1].deaths,8)
 eq(A.ActivityTrend('Today',now,nil,nil,'Personal')[1].kills,5)
 A.chartScope='Guild';eq(A.ActivityTrend('Today',now)[1].kills,13)
 eq(A.ActivityTrend('Today',now,nil,nil,'unknown')[1].kills,5)
 A.chartScope='unknown';eq(A.ActivityTrend('Today',now)[1].kills,5)
end)

test('Lifetime bounds and complete series follow selected scope without distributing lifetime totals',function()
 local A,today,now,own,peers=setup()
 own.days[today-40]=2;peers['Peer-Realm'].deathDays[today-90]=1
 eq(A.ChartBounds('Lifetime',now,'Personal'),today-40)
 eq(A.ChartBounds('Lifetime',now,'Guild'),today-90)
 local all=A.ActivityTrend('Lifetime',now,nil,nil,'Guild');eq(#all,91);eq(all[1].deaths,1)
 local selected=A.ActivityTrend('Lifetime',now,today-90,today-89,'Guild');eq(#selected,2);eq(selected[2].kills,0)
 eq(#A.ActivityTrend('Lifetime',now,today-90,today-89,'Personal'),0)
 peers['Peer-Realm'].days[today-399]=1;peers['Peer-Realm'].days[today-400]=99;peers['Peer-Realm'].days[today+1]=99
 eq(A.ChartBounds('Lifetime',now,'Guild'),today-399)
 eq(#A.ActivityTrend('Lifetime',now,nil,nil,'Guild'),400)
 A.chartScope='Guild';eq(A.ChartBounds('Lifetime',now),today-399)
 local line=A.KillsLine('Lifetime',now,300,100,today-399,today-399,'Guild')
 eq(#line.points,1);eq(line.points[1].kills,1);eq(line.points[1].x,150)
 eq(A.KillsLine('Today',now,300,100,nil,nil,'Guild').peak,13)
 -- Lifetime counters without daily evidence must not invent activity.
 local B,d,t,localRecord,p=setup();localRecord.days={};localRecord.deathDays={};localRecord.total=999999
 B.account.characters['Alt-Realm'].days={};B.account.characters['Alt-Realm'].deathDays={}
 eq(B.ChartBounds('Lifetime',t,'Personal'),d)
 eq(B.ActivityTrend('Lifetime',t,nil,nil,'Personal')[1].kills,0)
end)

test('scope changes preserve custom dates and move full ranges to new bounds',function()
 local A,today,now,own,peers=setup();own.days[today-40]=1;peers['Peer-Realm'].days[today-90]=1
 local first,last,min,max=A.ResetChartRange('Lifetime',now,'Guild')
 eq(first,today-90);eq(last,today);eq(min,first);eq(max,last)
 first=A.GetChartRange('Lifetime',now,'Personal');eq(first,today-40)
 first=A.GetChartRange('Lifetime',now,'Guild');eq(first,today-90,'full range expands back')
 assert(A.SetChartRange('Lifetime',now,today-80,today-60,'Guild'))
 first,last=A.GetChartRange('Lifetime',now,'Personal');eq(first,today-40);eq(last,today-40)
 first,last=A.GetChartRange('Lifetime',now,'Guild');eq(first,today-40);eq(last,today-40,'clamped custom range remains custom')
 assert(A.SetChartRange('Lifetime',now,today-30,today-10,'Guild'))
 A.chartScope='Personal';first,last=A.GetChartRange('Lifetime',now);eq(first,today-30);eq(last,today-10)
 A.chartScope='Guild';first,last=A.GetChartRange('Lifetime',now);eq(first,today-30);eq(last,today-10)
 -- Explicit scope overrides session scope through both handle and range validation.
 A.chartScope='Personal';assert(A.SetChartHandle('Lifetime',now,'first',today-85,'Guild'));eq(A.chartRange.first,today-85)
 eq(A.SetChartRange('Lifetime',now,today-85,today-10,'Personal'),false)
 first=A.ResetChartRange('Lifetime',now,'Guild');eq(first,today-90)
 A.chartScope='Guild';first=A.ResetChartRange('Lifetime',now);eq(first,today-90)
 first=A.ResetChartRange('Lifetime',now,'unknown');eq(first,today-40)
end)

test('cached guild uses selected witness ledger without statistics, report, permission or send changes',function()
 local A,today,now,own,peers=setup();local key=A.guildKey
 A.account.guilds[key]=peers
 A.account.guildMembership={[key]={members=clone(A.members)}}
 A.account.viewGuilds={Realm=key};A.guildKey=nil;A.members={}
 A.account.guilds['Other-Realm']={['Peer-Realm']=record(today,999,999)}
 A.account.guildObservations['Other-Realm']={events={}}
 local beforeAccount,beforeDB=clone(A.account),clone(A.db)
 local sends=0;SendChatMessage=function()sends=sends+1 end
 A.SendPacket=function()sends=sends+1;error('chart must not send')end
 A.QueueShare=function()sends=sends+1;error('chart must not queue')end
 local permission=A.CanPostTopReport();local job={lines={'frozen'},index=1};A.postJob=job;A.postStatus='unchanged'
 for _,scope in ipairs({'Personal','Guild'})do
  local expected=scope=='Guild'and 13 or 5
  eq(A.ActivityTrend('Today',now,nil,nil,scope)[1].kills,expected)
  eq(A.KillsLine('Today',now,300,100,nil,nil,scope).peak,expected)
  A.GetChartRange('Lifetime',now,scope)
 end
 eq(A.guildKey,nil);eq(A.CanPostTopReport(),permission);eq(permission,false);eq(sends,0)
 eq(A.postJob,job);eq(A.postStatus,'unchanged');eq(job.index,1)
 same(A.account,beforeAccount,'account');same(A.db,beforeDB,'db')
 -- Rank/report contents do not depend on the daily chart scope.
 A.chartScope='Personal';local report=A.BuildTopReport('Today',now)
 A.chartScope='Guild';same(A.BuildTopReport('Today',now),report,'report')
 SendChatMessage=nil
end)

test('both scopes retain UTC calendar windows, inclusive selections and zero or single-day geometry',function()
 local A,today,now=setup()
 for _,scope in ipairs({'Personal','Guild'})do
  for _,case in ipairs({{'2024-03-03','This week','2024-02-26'},{'2024-03-04','This week','2024-03-04'},{'2024-02-29','This month','2024-02-01'},{'2024-12-31','This year','2024-01-01'}})do
   local day=A.ParseChartDate(case[1]);local first,last=A.ChartBounds(case[2],day*86400+86399,scope)
   eq(first,A.ParseChartDate(case[3]));eq(last,day)
   eq(#A.ActivityTrend(case[2],day*86400,nil,nil,scope),last-first+1)
  end
  eq(#A.ActivityTrend('7 days',now,today-3,today-1,scope),3)
  eq(#A.ActivityTrend('7 days',now,today-7,today,scope),0)
  eq(#A.ActivityTrend('7 days',now,today,nil,scope),0)
  local zero=A.KillsLine('Today',now+86400,300,100,nil,nil,scope)
  eq(#zero.points,1);eq(zero.points[1].x,150);eq(zero.points[1].y,0);eq(zero.peak,0);assert(zero.ceiling>0)
 end
end)
