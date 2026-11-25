-- Actual TOC: report-only leaderboard projections never mutate old history.
local root=arg[1]or'.';local here=arg[0]:match('^(.*)/')or'tests'
local f=assert(io.open(here..'/integration.lua'));local lines={};for line in f:lines()do lines[#lines+1]=line;if #lines==126 then break end end;f:close()
local test=[[
units.target=nil;event('PLAYER_LOGIN');assert(A.db and not A.lastError,A.lastError)
local scope=A.guildKey;local day=A.Day(now)
local observed='WitnessOnly-Realm';local reported='Reported-Realm'
local old={total=999,days={[day]=999},observerOnly=true,characterGUID='Player-witness',accountID='old-witness',alias='WitnessOnly'}
local direct={total=7,days={[day]=7},guildBase={since=now-100,total=0,days={}},observerOnly=false,characterGUID='Player-reported',accountID='reported-account',alias='Reported'}
-- Partial old witness history must not override the subject's reported totals.
local store=A.account.guildObservations[scope]
store.events.reportedOldAssist={kind='K',name=reported,actor='Player-reported',target='Player-old-assist',time=now-10,contribution=now-10,provenance='A'}
A.groupIndexes=nil
A.PeerRecords()[observed]=old;A.PeerRecords()[reported]=direct;A.members[observed]=true;A.members[reported]=true
local views=A.ViewPeerRecords()
assert(not views[observed]and views[reported]==direct,'view must exclude observed-only statistics but retain addon-reported records')
local groups=A.LeaderboardGroups('Lifetime',now);local found=false
for _,g in ipairs(groups)do assert(not g.observed,'projection must not expose observed group flag');for _,child in ipairs(g.children)do assert(child.name~=observed and child.observed==nil,'no observed-only child or observed label flag');if child.name==reported then assert(child.k==7);found=true end end end
assert(found,'reported character remains ranked')
local report=table.concat(A.BuildTopReport('Lifetime',now),'\n');assert(report:find('Reported',1,true)and not report:find('WitnessOnly',1,true),'copy/post ranking excludes observed-only history')
local trend=A.ActivityTrend('Today',now,nil,nil,'Guild');assert(trend[1].kills==7,'guild chart excludes observed-only counters')
A.OpenView('Leaderboard',false)
assert(not A.heading.text:lower():find('observed',1,true),'leaderboard heading must remove observed explanation')
for _,row in ipairs(A.rows)do assert(not(row[1].text or''):find('[observed]',1,true),'no observed row badge')end
assert(A.PeerRecords()[observed]==old and old.total==999 and old.days[day]==999,'hidden historical record remains untouched')
-- Cached/read-only guild projections apply the same rule.
local cache=A.account.guildMembership[scope];cache.members[observed]=true;cache.members[reported]=true
A.guildKey=nil;A.guildName=nil;A.account.viewGuilds.Realm=scope
local cached=A.ViewPeerRecords();assert(not cached[observed]and cached[reported]==direct,'cached leaderboard also excludes observed-only entries')
assert(A.account.guilds[scope][observed]==old and old.total==999,'cached filtering must not delete historical counters')
print('PASS reported-only views: guild/cached leaderboard, charts, ranking/copy/post, no labels; old saved totals preserved')
]]
assert(loadstring(table.concat(lines,'\n')..'\n'..test))()
