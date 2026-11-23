-- Performance gates through actual production TOC; never send to the game.
local root=arg[1]or'.';local here=arg[0]:match('^(.*)/')or'tests'
local f=assert(io.open(here..'/integration.lua'));local lines={};for line in f:lines()do lines[#lines+1]=line;if #lines==126 then break end end;f:close()
local test=[[
event('PLAYER_LOGIN');assert(A.db and not A.lastError,A.lastError)
units.target=nil;units.focus=nil;units.mouseover=nil
A.db.seen={};A.db.owners[A.owner].seen=A.db.seen;A.account.knownEncounters={}
local function entry(i)return{name='Retained-'..i,race='Gnome',first=now-10000,last=now-i,level=70,class='Mage',days={[A.Day(now)]=true}}end
for i=1,2000 do local g='Player-retained'..i;A.db.seen[g]=entry(i);A.account.knownEncounters[g]=entry(i)end
A.knownEncounterSize=2000;A.PruneEncounters(now,true)
local function size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function newcomer(i)local u='nameplate'..i;units[u]={name='Arrival'..i,realm='Surname',guid='Player-arrival'..i,race='Gnome',faction='Alliance',hostile=true,health=100,max=100};return u end
for i=1,40 do A.plates[newcomer(i)]=true end
local prune=A.PruneEncounters;local full=0
A.PruneEncounters=function(t,force)if force or not A.encounterDeadline or t>=A.encounterDeadline then full=full+1 end;return prune(t,force)end
local total=A.db.owners[A.owner].total
A.ScanVisible();assert(not A.lastError,A.lastError)
assert(full==1,'40 fresh contacts at cap must prune once per scan, got '..full)
assert(size(A.db.seen)==2000 and size(A.account.knownEncounters)==2000,'scan returns with hard global cap enforced')
for i=1,40 do assert(A.db.seen['Player-arrival'..i]and A.account.knownEncounters['Player-arrival'..i],'fresh metadata retained')end
assert(not A.db.seen['Player-retained2000']and A.db.seen['Player-retained1'].level==70,'evict oldest and preserve keeper metadata')
assert(A.db.owners[A.owner].total==total,'retention must not alter kill statistics')
full=0;event('NAME_PLATE_UNIT_ADDED',newcomer(41))
assert(full==1,'single native contact must not double-prune')
assert(size(A.db.seen)==2000 and size(A.account.knownEncounters)==2000,'standalone native event is bounded before returning')
-- A failed scan must close its batch and enforce pending retention before
-- propagating the failure; otherwise all later native events stay unbounded.
units.target=units[newcomer(42)]
local scan=A.Scan
A.Scan=function(u,...)if u=='focus'then error('injected scan failure')end;return scan(u,...)end
full=0;local ok,err=pcall(A.ScanVisible);assert(not ok and tostring(err):find('injected scan failure',1,true))
A.Scan=scan;units.target=nil
assert(full==1 and size(A.account.knownEncounters)==2000,'failed scan must finalize pending retention')
full=0;event('NAME_PLATE_UNIT_ADDED',newcomer(43));assert(full==1 and size(A.db.seen)==2000,'failed batch must not leak into future events')
-- Synchronous snapshotting remains a hard serialization boundary even when
-- invoked from inside a scan transaction; it must not cause a second flush.
full=0
A.WithEncounterBatch(function()
 A.Encounter('Player-snapshot','Snapshot-Surname','Gnome','Alliance',now,71,'Warrior')
 A.SnapshotAccount(now)
 assert(size(A.account.knownEncounters)==2000,'snapshot must enforce cap before returning')
end)
assert(full==1,'completed snapshot must consume pending prune instead of duplicate final flush')
print('PASS retention workload: burst=1 full prune, standalone=1, error/nesting/snapshot boundaries safe')
]]
assert(loadstring(table.concat(lines,'\n')..'\n'..test))()
