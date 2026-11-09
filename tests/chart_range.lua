local root=arg[1]or'.'
local A={};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','Dashboard.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
date=os.date
local function eq(a,b,msg)assert(a==b,(msg or'')..' expected '..tostring(b)..', got '..tostring(a))end
local function test(name,fn)fn();print('PASS chart range: '..name)end
local function setup()
 local today=20000;local now=today*86400+123
 A.Init({},'Me-Realm',now);A.InitAccount({},'mine',now)
 A.guildKey='Guild-Realm';A.members={['Me-Realm']=true,['Alt-Realm']=true};A.chartRange=nil
 A.account.characters['Alt-Realm']={days={},deathDays={}}
 return today,now,A.account.characters['Me-Realm'],A.account.characters['Alt-Realm']
end

test('strict timezone-independent Gregorian dates',function()
 local native=os;os=nil
 eq(A.ParseChartDate('1970-01-01'),0)
 eq(A.ParseChartDate('2000-02-29'),11016)
 eq(A.ParseChartDate('2024-02-29'),19782)
 eq(A.ParseChartDate('2024-03-01'),19783)
 eq(A.ParseChartDate('1900-03-01'),-25508)
 for _,s in ipairs({'2023-02-29','1900-02-29','2024-04-31','2024-00-01','2024-13-01','2024-01-00','2024-01-32','2024-2-01',' 2024-02-01','2024-02-01 ','2024-02-01x','0000-01-01','abcd',''})do local d,e=A.ParseChartDate(s);eq(d,nil,s);assert(type(e)=='string')end
 eq(A.ParseChartDate(false),nil);eq(A.ParseChartDate(nil),nil)
 os=native
end)
test('period bounds and Monday UTC calendar boundaries',function()
 local today,now=setup()
 for _,period in ipairs({'Today','7 days','30 days','This week','This month','This year'})do
  local first,last=A.ChartBounds(period,now);eq(first,A.FirstDay(period,now));eq(last,today)
 end
 for _,case in ipairs({{'2024-03-03','This week','2024-02-26'},{'2024-03-04','This week','2024-03-04'},{'2024-02-29','This month','2024-02-01'},{'2024-12-31','This year','2024-01-01'},{'2025-01-01','This year','2025-01-01'}})do
  local day=A.ParseChartDate(case[1]);local native=os;os=nil
  local first,last=A.ChartBounds(case[2],day*86400+86399);os=native
  eq(first,A.ParseChartDate(case[3]));eq(last,day)
 end
end)
test('Lifetime starts at retained effective own-account activity in view scope',function()
 local today,now,own,alt=setup()
 local first,last=A.ChartBounds('Lifetime',now);eq(first,today);eq(last,today)
 own.days[today-40]=2;alt.deathDays[today-60]=1
 A.account.characters['Out-Realm']={days={[today-100]=99},deathDays={}}
 A.PeerRecords()['Peer-Realm']={days={[today-200]=99}};A.members['Peer-Realm']=true
 first=A.ChartBounds('Lifetime',now);eq(first,today-60)
 own.days[today-500]=1;own.days[today+1]=1;alt.days[today-90]=0
 eq(A.ChartBounds('Lifetime',now),today-60)
 own.days[today-399]=1;eq(A.ChartBounds('Lifetime',now),today-399)
 local effective=A.GuildEffectiveRecord;local key='Cached-Realm';A.guildKey=nil
 A.account.guilds={[key]={}};A.account.guildMembership={[key]={members={['Alt-Realm']=true}}};A.account.viewGuilds={Realm=key}
 A.GuildEffectiveRecord=function(name,r,at,scope)eq(scope,key);eq(name,'Alt-Realm');eq(at,now);return{days={},deathDays={[today-80]=3}}end
 eq(A.ChartBounds('Lifetime',now),today-80)
 A.GuildEffectiveRecord=effective
end)
test('session selection validation, reset, rollover and bounds clamping',function()
 local today,now=setup()
 local first,last,min,max=A.GetChartRange('7 days',now);eq(first,today-6);eq(last,today);eq(min,first);eq(max,last)
 first,last=A.GetChartRange('7 days',now+86400);eq(first,today-5);eq(last,today+1)
 assert(A.SetChartRange('7 days',now,today-4,today-2));local saved=A.chartRange
 for _,pair in ipairs({{today-7,today},{today,today+1},{today,today-1},{today-1.5,today},{'bad',today},{0/0,today},{-math.huge,today},{false,today}})do
  local ok,err=A.SetChartRange('7 days',now,pair[1],pair[2]);eq(ok,false);assert(type(err)=='string');eq(A.chartRange,saved);eq(saved.first,today-4);eq(saved.last,today-2)
 end
 first,last=A.GetChartRange('7 days',now+86400);eq(first,today-4);eq(last,today-2)
 first,last=A.GetChartRange('7 days',now+5*86400);eq(first,today-1);eq(last,today-1)
 first,last=A.GetChartRange('30 days',now);eq(first,today-29);eq(last,today)
 assert(A.SetChartRange('30 days',now,today-10,today-8))
 first,last=A.ResetChartRange('30 days',now);eq(first,today-29);eq(last,today)
 first,last=A.GetChartRange('Today',now);eq(first,today);eq(last,today)
 eq(A.chartRange.period,'Today');eq(A.db.chartRange,nil);eq(A.account.chartRange,nil)
end)
test('handles round, clamp and never cross including same-day bounds',function()
 local today,now=setup();A.ResetChartRange('7 days',now)
 assert(A.SetChartHandle('7 days',now,'first',today-3.6));eq(A.chartRange.first,today-4)
 assert(A.SetChartHandle('7 days',now,'last',today-99));eq(A.chartRange.last,today-4)
 eq(A.SetChartHandle('7 days',now,'first',today+50),false);eq(A.chartRange.first,today-4)
 assert(A.SetChartHandle('7 days',now,'first',today-99));eq(A.chartRange.first,today-6)
 assert(A.SetChartHandle('7 days',now,'last',today+99));eq(A.chartRange.last,today)
 eq(A.SetChartHandle('7 days',now,'invalid',today),false)
 eq(A.SetChartHandle('7 days',now,'first',0/0),false)
 eq(A.SetChartHandle('7 days',now,'first','bad'),false)
 A.ResetChartRange('Today',now);eq(A.SetChartHandle('Today',now,'first',today-9),false);eq(A.SetChartHandle('Today',now,'last',today+9),false)
end)
test('daily series use complete periods and exact inclusive endpoints without truncation',function()
 local today,now,own,alt=setup();own.days[today-399]=1;own.days[today-80]=7;own.days[today]=3;alt.deathDays[today-79]=2
 local all=A.ActivityTrend('Lifetime',now);eq(#all,400);eq(all[1].day,today-399);eq(all[400].day,today)
 local selected=A.ActivityTrend('Lifetime',now,today-80,today-78)
 eq(#selected,3);eq(selected[1].kills,7);eq(selected[2].kills,0);eq(selected[2].deaths,2);eq(selected[3].day,today-78)
 for _,period in ipairs({'Today','7 days','30 days','This week','This month','This year','Lifetime'})do
  local min,max=A.ChartBounds(period,now);local data=A.ActivityTrend(period,now);eq(#data,max-min+1);eq(data[1].day,min);eq(data[#data].day,max)
 end
 assert(A.SetChartRange('Lifetime',now,today,today));eq(#A.ActivityTrend('Lifetime',now),400,'omitted endpoints ignore UI selection')
 for _,range in ipairs({{today,today-1},{today-400,today},{today,today+1},{'bad',today},{today-0.5,today},{0/0,today},{today,false}})do
  eq(#A.ActivityTrend('Lifetime',now,range[1],range[2]),0,'malformed ranges rejected')
 end
 eq(#A.ActivityTrend('Lifetime',now,nil,today),0,'partial range rejected')
 eq(#A.ActivityTrend('Lifetime',now,today,nil),0,'partial range rejected')
 local line=A.KillsLine('Lifetime',now,300,100,today-80,today-78)
 eq(#line.points,3);eq(line.points[1].day,today-80);eq(line.points[1].x,0);eq(line.points[3].x,300);eq(line.points[1].kills,7);eq(line.ticks[1],0);assert(line.ceiling>=7)
 eq(line.points[1].y,7/line.ceiling*100)
 local single=A.KillsLine('Lifetime',now,300,100,today-79,today-79);eq(#single.points,1);eq(single.points[1].x,150);eq(single.points[1].y,0);assert(single.ceiling>0)
 eq(#A.KillsLine('Lifetime',now,300,100,today,today-1).points,0)
 eq(#A.KillsLine('Lifetime',now,300,100).points,400)
end)
