local root=arg[1]or'.'
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local t,clock=1700000000,100
local secret={}
function issecretvalue(v)return rawequal(v,secret)end
local function setup()
 t=t+100;clock=clock+100
 IsInInstance=function()return false,'none'end
 C_DeathRecap=nil;C_Timer=nil
 local hp=1000
 function GetServerTime()return t end
 function GetTime()return clock end
 function CreateFrame()return {events={},scripts={},RegisterEvent=function(self,e)self.events[e]=true end,SetScript=function(self,k,v)self.scripts[k]=v end}end
 function UnitExists(u)return u=='player'end
 function UnitGUID(u)if u=='player'then return 'Player-me'end end
 function UnitName()return 'Me','Realm'end
 function UnitHealthMax()return hp end
 function UnitIsPlayer()return true end
 function UnitIsUnit(a,b)return a==b end
 function UnitAffectingCombat()return true end
 function UnitIsDeadOrGhost()return false end
 function GetGuildInfo()return 'Guild'end
 function GetNormalizedRealmName()return 'Realm'end
 function GetNumSubgroupMembers()return 0 end
 function IsInRaid()return false end
 local A={}
 for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','GroupTracker.lua','Runtime.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Init({},'Me-Realm',t);A.InitGroupTracking(t)
 A.guildName='Guild';A.guildKey='Guild-Realm';A.members={[A.owner]=true}
 A.plates={};A.auras={};A.coverage={};A.QueueShare=function()end;A.Changed=function()end;A.Roster=function()end
 A.Race=function(g)if g=='Player-a'or g=='Player-b'then return 'Gnome'elseif g=='Player-human'then return 'Human'end end
 local function event(e,...)
  assert(A.eventFrame.events[e],e);A.eventFrame.scripts.OnEvent(A.eventFrame,e,...);assert(not A.lastError,A.lastError)
 end
 A.ScanVisible();event('PLAYER_REGEN_DISABLED')
 return A,event,function(v)hp=v end
end
local function row(n,g,stamp)return{event='SPELL_DAMAGE',amount=n,sourceGUID=g or'Player-a',timestamp=stamp or t}end
local function recap(rows,id,hp)
 C_DeathRecap={GetRecapLink=function()return '|Hdeath:'..(id or 1)..'|h'end,GetRecapEvents=function()return rows end,GetRecapMaxHealth=function()return hp or 1000 end}
end
local function deaths(A)return A.db.owners[A.owner].deaths or 0 end
local function majority(stamp)return{row(300,'Player-a',stamp),row(301,'Player-b',stamp),row(399,'Player-human',stamp)}end
for _,change in ipairs({'control','unknown','zone','instance'})do
 test('delayed two Gnome majority survives '..change,function()
  local A,event=setup();local at=t;event('PLAYER_DEAD')
  if change=='unknown'then IsInInstance=function()return nil,nil end;A.ScanVisible()
  elseif change=='zone'then event('ZONE_CHANGED_NEW_AREA')
  elseif change=='instance'then IsInInstance=function()return true,'pvp'end;event('PLAYER_ENTERING_WORLD')end
  t=t+2;clock=clock+2;recap(majority(at));A.Recap()
  assert(deaths(A)==1,'frozen dead-life majority lost after '..change)
  event('PLAYER_DEAD');A.Recap();assert(deaths(A)==1,'same life duplicated')
 end)
end
test('release and new combat cannot erase or enlarge pending dead life',function()
 for _,release in ipairs({'PLAYER_ALIVE','PLAYER_UNGHOST'})do
  local A,event,sethp=setup();local at=t
  event('PLAYER_DEAD');event(release);sethp(3000);event('PLAYER_REGEN_DISABLED')
  t=t+2;clock=clock+2;recap(majority(at));A.Recap()
  assert(deaths(A)==1,'release must preserve immutable dead-life context')
 end
end)
test('later incoming damage cannot qualify a prior death',function()
 local A,event=setup();event('PLAYER_DEAD')
 A.groupIncoming['Player-me']={started=t,health=1000,events=majority()}
 A.Recap();assert(deaths(A)==0,'live collector contaminated frozen death')
end)
test('each own death attempt has bounded local persisted outcome diagnostics',function()
 local A,event=setup();recap({row(500)});event('PLAYER_DEAD')
 t=t+9;clock=clock+9;A.Recap()
 assert(A.db.deathOutcomes and #A.db.deathOutcomes==1,'missing persisted death outcome')
 assert(A.db.deathOutcomes[1].reason=='insufficient confirmed Gnome damage')
 local lines=A.DeathDebugLines();assert(table.concat(lines,' '):find('insufficient confirmed Gnome damage',1,true))
end)
test('kill policy refresh never resets ongoing incoming combat evidence',function()
 for _,change in ipairs({'unknown','zone'})do
  local A,event=setup();local fight=A.deathFight;local incoming=A.groupIncoming['Player-me']
  if change=='unknown'then IsInInstance=function()return nil,nil end;A.ScanVisible()else event('ZONE_CHANGED_NEW_AREA')end
  assert(A.deathFight==fight and A.groupIncoming['Player-me']==incoming,'generic kill refresh reset incoming combat')
 end
end)
test('a second life death retains the earlier delayed attempt until expiry',function()
 local A,event=setup();local first=t;event('PLAYER_DEAD');event('PLAYER_ALIVE')
 t=t+4;clock=clock+4;event('PLAYER_REGEN_DISABLED');event('PLAYER_DEAD')
 recap(majority(first),11);A.Recap();assert(deaths(A)==1,'older dead life was overwritten')
 recap(majority(t),12);A.Recap();assert(deaths(A)==2,'newer dead life was lost')
end)
test('runtime update expires pending work without needing another death',function()
 local A,event=setup();A.Pump=function()end;event('PLAYER_DEAD');t=t+9;clock=clock+9
 A.eventFrame.scripts.OnUpdate(A.eventFrame,1);assert(not A.lastError,A.lastError)
 assert(not A.pendingDeath and #A.pendingDeaths==0,'expired context retained beyond eight seconds')
 assert(A.db.deathOutcomes[1].reason=='stale/unavailable recap')
end)
test('pending diagnostics and proof use only readable bounded state',function()
 local A,event=setup()
 for i=1,40 do
  recap(majority(),i);event('PLAYER_DEAD');event('PLAYER_ALIVE');t=t+10;clock=clock+10;event('PLAYER_REGEN_DISABLED')
 end
 assert(#A.db.deathOutcomes==32 and #A.DeathDebugLines()==33,'diagnostics must retain at most 32 records')
 A.db.deathOutcomes={secret,{time=secret,reason='counted'},{time=t,reason=secret},{time=t,reason=string.rep('x',10000)}}
 assert(#A.DeathDebugLines()==1,'secret or arbitrary persisted fields must not be rendered')
end)
test('readable insufficient versus missing attribution are not conflated',function()
 for _,n in ipairs({499,500,501})do
  local A,event=setup();recap({row(n)});event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap()
  assert(deaths(A)==(n>500 and 1 or 0))
  assert(A.db.deathOutcomes[1].reason==(n>500 and 'counted'or'insufficient confirmed Gnome damage'))
 end
 local A,event=setup();recap({row(secret)});event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap()
 assert(deaths(A)==0 and A.db.deathOutcomes[1].reason=='unreadable/missing attribution')
end)
test('observed transient health peaks and original proof clocks stay frozen',function()
 for _,monotonic in ipairs({false,true})do
  for _,n in ipairs({600,1001})do
   local A,event,sethp=setup();sethp(2000);event('UNIT_MAXHEALTH','player');sethp(1000);event('UNIT_MAXHEALTH','player')
   local at=monotonic and clock or t;event('PLAYER_DEAD');event('PLAYER_UNGHOST')
   sethp(10000);event('PLAYER_REGEN_DISABLED');t=t+2;clock=clock+2
   recap({row(n,'Player-a',at)},1,1000);A.Recap()
   assert(deaths(A)==(n>1000 and 1 or 0),'frozen peak/clock changed')
  end
 end
end)
test('recap and collector damage are alternative proofs and never summed',function()
 local A,event=setup();A.groupIncoming['Player-me']={started=t,health=1000,events={row(300)}}
 recap({row(300)});event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap();assert(deaths(A)==0,'overlapping collector/recap damage added')
end)
test('stale and consumed recaps cannot qualify another life',function()
 local A,event=setup();recap(majority(t-30));event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap()
 assert(deaths(A)==0 and A.db.deathOutcomes[1].reason=='stale/unavailable recap')
 event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');recap(majority(),2);event('PLAYER_DEAD');assert(deaths(A)==1)
 t=t+5;clock=clock+5;event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');recap(majority(),2);event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap()
 assert(deaths(A)==1 and A.db.deathOutcomes[3].reason=='stale/unavailable recap')
end)
test('guild authority rejection is reported without changing membership policy',function()
 for _,unverified in ipairs({false,true})do
  local A,event=setup();A.guildUnverified=unverified;if not unverified then A.members[A.owner]=nil end
  recap(majority());event('PLAYER_DEAD')
  assert(deaths(A)==0 and A.db.deathOutcomes[1].reason=='membership rejection')
 end
end)
test('persisted diagnostics normalize pending reloads and bound stored payload',function()
 local A=setup();A.db.deathOutcomes={}
 for i=1,40 do A.db.deathOutcomes[i]={time=t,reason='pending recap',untrusted=string.rep('x',10000)}end
 A.InitDeathOutcomes()
 assert(#A.db.deathOutcomes==32)
 for _,e in ipairs(A.db.deathOutcomes)do assert(e.reason=='stale/unavailable recap' and not e.untrusted)end
 A.db.deathOutcomes={secret,{time=t,reason=secret},{time=secret,reason='counted'}};A.InitDeathOutcomes();assert(#A.db.deathOutcomes==0)
end)
test('PLAYER_DEAD samples one immutable proof timestamp',function()
 local A,event=setup()
 GetServerTime=function()t=t+1;return t end
 A.IncomingDeathEvidence=function(_,at)return{damage=601,maxHealth=1000,source='Player-a',time=at}end
 event('PLAYER_DEAD');assert(deaths(A)==1,'proof clock sampled again after freezing death time')
end)
test('frozen collector outcomes retain their supported reason without a native recap',function()
 local A,event=setup();A.groupIncoming['Player-me']={started=t,health=1000,events={row(500)}}
 event('PLAYER_DEAD');t=t+9;clock=clock+9;A.Recap()
 assert(deaths(A)==0 and A.db.deathOutcomes[1].reason=='insufficient confirmed Gnome damage','lost readable collector outcome')
end)
test('collector cannot widen the independently observed own combat window',function()
 local A,event=setup()
 A.groupIncoming['Player-me']={started=t-10,health=1000,events=majority(t-1)}
 event('PLAYER_DEAD');assert(deaths(A)==0,'collector widened own fight start')
end)
test('unreadable native location pairs never discard a matching death recap',function()
 local states={false,function()error('unknown native state')end,function()return secret,'none'end,function()return false,secret end,function()return false,'raid'end}
 for _,state in ipairs(states)do
  local A,event=setup();local at=t;event('PLAYER_DEAD');IsInInstance=state or nil;A.ScanVisible()
  recap(majority(at));A.Recap();assert(deaths(A)==1)
 end
end)
test('pending context count stays bounded and repeated callbacks do not add attempts',function()
 local A,event=setup()
 for i=1,6 do
  event('PLAYER_DEAD');local n=#A.pendingDeaths;event('PLAYER_DEAD');assert(#A.pendingDeaths==n)
  event('PLAYER_ALIVE');t=t+1;clock=clock+1;event('PLAYER_REGEN_DISABLED')
 end
 assert(#A.pendingDeaths==4 and #A.db.deathOutcomes==6,'pending bound or one-record-per-attempt violated')
 t=t+9;clock=clock+9;A.Recap();assert(#A.pendingDeaths==0)
end)
test('release without a combat callback still establishes a new life lower bound',function()
 local A,event=setup();local first=t;event('PLAYER_DEAD');t=t+4;clock=clock+4;event('PLAYER_ALIVE');event('PLAYER_DEAD')
 recap(majority(first),81);A.Recap();assert(deaths(A)==1)
 local events=A.db.guildObservations[A.guildKey].events
 for _,e in pairs(events)do assert(e.time==first,'new life borrowed the old delayed recap window')end
end)
test('same-second fresh evidence is not discarded by release timestamp floors',function()
 for _,release in ipairs({'PLAYER_ALIVE','PLAYER_UNGHOST'})do
  local A,event=setup();event(release);recap(majority(),91);event('PLAYER_DEAD')
  assert(deaths(A)==1,'legitimate same-second fresh recap was discarded')
 end
end)
test('monotonic elapsed time bounds pending work independently of integer epoch',function()
 local A,event=setup();event('PLAYER_DEAD');clock=clock+8.01;A.Recap()
 assert(not A.pendingDeath and #A.pendingDeaths==0,'pending expiry used epoch timestamps instead of elapsed duration')
end)
test('same-second and one two three second recap delays survive real life callbacks',function()
 for _,delay in ipairs({0,0.25,1,2,3})do
  for _,release in ipairs({'none','PLAYER_ALIVE','PLAYER_UNGHOST'})do
   for _,monotonic in ipairs({false,true})do
    local A,event=setup();local epoch,start=t,clock;local stamp=monotonic and clock or t
    event('PLAYER_DEAD');t=epoch+math.floor(delay);clock=start+delay
    if release~='none'then event(release)end
    recap(majority(stamp),101);A.Recap();assert(deaths(A)==1,'delayed recap/callback boundary lost')
    for _,late in ipairs({1,2,3,9})do
     t=t+late;clock=clock+late;A.Recap();assert(deaths(A)==1,'late duplicate recap counted again')
    end
   end
  end
 end
end)
test('time passing cannot manufacture a resurrection or a death',function()
 local A,event=setup();recap(majority(),111);clock=clock+3;t=t+3;A.Recap();assert(deaths(A)==0)
 event('PLAYER_DEAD');assert(deaths(A)==1)
 t=t+30;clock=clock+30;recap(majority(),112);event('PLAYER_DEAD');A.Recap()
 assert(deaths(A)==1 and #A.db.deathOutcomes==1,'elapsed time rearmed the same dead life')
end)
test('same-second location and life boundaries exclude old IDs not fresh timestamps',function()
 for _,boundary in ipairs({'instance','PLAYER_ALIVE','PLAYER_UNGHOST'})do
  local A,event=setup();recap(majority(),121)
  if boundary=='instance'then IsInInstance=function()return true,'pvp'end;event('PLAYER_ENTERING_WORLD')else event(boundary)end
  event('PLAYER_DEAD');assert(deaths(A)==0,'pre-boundary recap ID replayed')
  recap(majority(),122);A.Recap();assert(deaths(A)==1,'fresh same-second recap discarded')
 end
end)
test('eight second deadline accepts on-boundary evidence and rejects expired evidence',function()
 for _,delay in ipairs({8,8.001})do
  local A,event=setup();local stamp=t;event('PLAYER_DEAD');clock=clock+delay
  recap(majority(stamp),131);A.Recap();assert(deaths(A)==(delay==8 and 1 or 0))
 end
end)
test('overlapping pending lives retain recap ownership in epoch and monotonic domains',function()
 for _,monotonic in ipairs({false,true})do
  local A,event=setup();local first=t;local stamp=monotonic and clock or t
  event('PLAYER_DEAD');event('PLAYER_ALIVE') -- no recap ID or new-combat callback
  t=t+4;clock=clock+4;event('PLAYER_DEAD')
  recap(majority(stamp),201);A.Recap()
  assert(deaths(A)==1,'first delayed recap lost')
  for _,e in pairs(A.db.guildObservations[A.guildKey].events)do
   assert(e.time==first,'newer life stole earlier recap')
  end
  recap(majority(monotonic and clock or t),202);A.Recap()
  assert(deaths(A)==2 and #A.pendingDeaths==0,'second genuine recap lost')
 end
end)
test('later life damage and health cannot supplement an insufficient earlier recap',function()
 for _,monotonic in ipairs({false,true})do
  local A,event,sethp=setup();local first=t;local stamp=monotonic and clock or t
  event('PLAYER_DEAD');event('PLAYER_ALIVE');sethp(200);event('UNIT_MAXHEALTH','player')
  t=t+1;clock=clock+1;event('PLAYER_DEAD')
  recap({row(300,'Player-a',stamp),row(301,'Player-b',monotonic and clock or t)},211,200)
  A.Recap();assert(deaths(A)==0,'later life damage/health supplemented earlier death')
  assert(not(A.db.deathRecapsSeen and A.db.deathRecapsSeen['211']),'nonqualifying context consumed recap ID')
  recap(majority(stamp),212);A.Recap()
  for _,e in pairs(A.db.guildObservations[A.guildKey].events)do assert(e.time==first,'earlier proof attributed to newer life')end
 end
end)
test('indistinguishable same-second life recaps remain unclaimed',function()
 for _,monotonic in ipairs({false,true})do
  local A,event=setup();local stamp=monotonic and clock or t
  event('PLAYER_DEAD');event('PLAYER_ALIVE');event('PLAYER_DEAD')
  recap(majority(stamp),221);A.Recap()
  assert(deaths(A)==0,'ambiguous same-second recap assigned an invented life')
  assert(not(A.db.deathRecapsSeen and A.db.deathRecapsSeen['221']),'ambiguous ID consumed')
  t=t+9;clock=clock+9;A.Recap();assert(deaths(A)==0)
 end
end)
test('death-time guild authority is frozen for immediate and delayed proofs',function()
 for _,state in ipairs({'unguilded','unverified','nonmember','guild switch','owner GUID switch'})do
  for _,delayed in ipairs({false,true})do
   local A,event=setup();local at=t
   if state=='unguilded'then A.guildKey=nil;A.members={}
   elseif state=='unverified'then A.guildUnverified=true
   elseif state=='nonmember'then A.members[A.owner]=nil end
   if not delayed then recap(majority(at),231)end
   event('PLAYER_DEAD')
   if state=='guild switch'then A.guildKey='Other-Realm'
   elseif state=='owner GUID switch'then UnitGUID=function(u)if u=='player'then return 'Player-other'end end
   else A.guildKey='Guild-Realm';A.guildUnverified=false;A.members[A.owner]=true end
   if delayed then recap(majority(at),231);A.Recap()end
   local rejected=delayed or(state~='guild switch'and state~='owner GUID switch')
   assert(deaths(A)==(rejected and 0 or 1),state..' death authority changed with late proof')
   assert(A.db.deathOutcomes[1].reason==(rejected and 'membership rejection'or'counted'),state..' rejection diagnostic lost')
   if rejected then
    for _,store in pairs(A.db.guildObservations or {})do assert(not next(store.events or {}),'rejected death written to a guild')end
    assert(not(A.db.deathRecapsSeen and A.db.deathRecapsSeen['231']),'membership rejection consumed ID')
   end
  end
 end
end)
test('commit-time guild membership gates still reject formerly eligible deaths',function()
 for _,state in ipairs({'unguilded','unverified','nonmember'})do
  local A,event=setup();local at=t;event('PLAYER_DEAD')
  if state=='unguilded'then A.guildKey=nil
  elseif state=='unverified'then A.guildUnverified=true
  else A.members[A.owner]=nil end
  recap(majority(at),241);A.Recap()
  assert(deaths(A)==0 and A.db.deathOutcomes[1].reason=='membership rejection')
 end
end)
print('ALL '..passed..' DEATH RUNTIME TESTS PASSED')
