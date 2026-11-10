local root=arg[1]or'.'
local passed=0
local function test(n,f)f();passed=passed+1;print('PASS '..n)end
local t,dead,aura=1700000000,false,true
local secret={}
function issecretvalue(v)return rawequal(v,secret)end
local function setup(group)
 t=t+1000;dead=false;aura=true
 function IsInInstance()return false,'none'end
 function GetServerTime()return t end
 function GetTime()return t end
 function CreateFrame()return{events={},scripts={},RegisterEvent=function(s,e)s.events[e]=true end,SetScript=function(s,k,f)s.scripts[k]=f end}end
 function UnitExists(u)return u=='player'or u=='target'or u=='nameplate1'end
 function UnitGUID(u)if UnitExists(u)then return u=='player'and'Player-me'or'Player-enemy'end end
 function UnitName(u)return u=='player'and'Me'or'Enemy','Realm'end
 function UnitRace(u)return u=='player'and'Orc'or'Gnome',u=='player'and'Orc'or'Gnome'end
 function UnitFactionGroup(u)return u=='player'and'Horde'or'Alliance'end
 function UnitIsPlayer()return true end
 function UnitIsUnit(a,b)return a==b end
 function UnitIsDeadOrGhost(u)return u~='player'and dead end
 function UnitCanAttack(_,u)return u~='player'and not dead end
 function UnitHealthMax()return 1000 end
 function GetNormalizedRealmName()return'Realm'end
 function GetGuildInfo()return'Guild'end
 function GetNumSubgroupMembers()return 0 end
 function IsInRaid()return false end
 C_UnitAuras={GetAuraDataByIndex=function(_,i)if aura=='error'then error('unreadable')end;if aura==secret then return secret end;if aura and i==1 then return{spellId=770,sourceUnit='player'}end end}
 local A={}
 for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua',group and'GroupTracker.lua'or'Core.lua','Runtime.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Init({},'Me-Realm',t);A.guildName='Guild';A.guildKey='Guild-Realm';A.members={[A.owner]=true}
 if group then A.InitGroupTracking(t);A.RefreshGroupActors()end
 A.plates={};A.auras={};A.coverage={}
 local function event(e,...)A.eventFrame.scripts.OnEvent(A.eventFrame,e,...);assert(not A.lastError,A.lastError)end
 return A,event
end
local function count(A)return A.db.owners[A.owner].total end
for _,group in ipairs({false,true})do
 for _,gap in ipairs({1,2,3})do
  test('fresh readable resurrection '..tostring(group)..' gap '..gap,function()
   local A,event=setup(group);event('UNIT_AURA','target');dead=true;event('UNIT_HEALTH','target');assert(count(A)==1)
   t=t+gap;dead=false;event('UNIT_AURA','target');dead=true;event('UNIT_HEALTH','target')
   assert(count(A)==2,'fresh same-GUID life lost inside dead cache/ledger window')
   t=t+5;event('PARTY_KILL','Player-me','Player-enemy');event('UNIT_FLAGS','target');assert(count(A)==2,'corpse replay duplicated')
  end)
 end
end
for _,group in ipairs({false,true})do
 test('readable absence rearms metadata-free debuff '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');aura=false;t=t+1;event('UNIT_AURA','target')
  aura=true;t=t+99;event('UNIT_AURA','target');t=t+21;dead=true;event('UNIT_HEALTH','target')
  assert(count(A)==1,'new application after confirmed absence kept stale dedup key')
 end)
end
for _,group in ipairs({false,true})do
 test('readable removal corpse counts '..tostring(group),function()
  local A,event=setup(group);event('NAME_PLATE_UNIT_ADDED','nameplate1');dead=true;t=t+1
  event('NAME_PLATE_UNIT_REMOVED','nameplate1')
  assert(count(A)==1,'last readable corpse lost at removal')
  assert(not A.plates.nameplate1);event('NAME_PLATE_UNIT_REMOVED','nameplate1');assert(count(A)==1)
 end)
end
for _,group in ipairs({false,true})do
 test('continuous aura never renews contribution after cache maintenance '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');t=t+601;A.ScanVisible();t=t+1;event('UNIT_AURA','target')
  dead=true;event('UNIT_HEALTH','target');assert(count(A)==0,'continuous old aura renewed after key TTL')
 end)
end
for _,group in ipairs({false,true})do
 test('late death callback cannot kill a freshly observed living target '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');dead=true;event('UNIT_HEALTH','target')
  t=t+1;dead=false;event('UNIT_AURA','target');event('PARTY_KILL','Player-me','Player-enemy')
  assert(count(A)==1,'delayed prior-life death callback consumed a readable new living life')
  dead=true;event('UNIT_HEALTH','target');assert(count(A)==2,'ignored ambiguous callback destroyed fresh eligibility')
 end)
end
for _,group in ipairs({false,true})do
 for _,mode in ipairs({'error','secret row','secret field','cap','continuous'})do
  test('unproven aura absence retains application '..tostring(group)..' '..mode,function()
   local A,event=setup(group);event('UNIT_AURA','target');local original=C_UnitAuras.GetAuraDataByIndex
   t=t+1
   C_UnitAuras.GetAuraDataByIndex=function(_,i)
    if mode=='error'then error('unavailable')elseif mode=='secret row'then return secret
    elseif mode=='secret field'then return{spellId=secret,sourceUnit='player'}
    elseif mode=='cap'then return{spellId=999,sourceUnit='other'}else return original('target',i)end
   end
   event('UNIT_AURA','target');C_UnitAuras.GetAuraDataByIndex=original
   t=t+99;event('UNIT_AURA','target');t=t+21;dead=true;event('UNIT_HEALTH','target')
   assert(count(A)==0,'failed/incomplete/continuous enumeration manufactured fresh application')
  end)
 end
 for _,state in ipairs({'alive','missing','secret death'})do
  test('removal without readable corpse never counts '..tostring(group)..' '..state,function()
   local A,event=setup(group);event('NAME_PLATE_UNIT_ADDED','nameplate1')
   if state=='missing'then UnitExists=function(u)return u=='player'end
   elseif state=='secret death'then UnitIsDeadOrGhost=function()return secret end end
   event('NAME_PLATE_UNIT_REMOVED','nameplate1');assert(count(A)==0)
  end)
 end
 test('readable changed refresh metadata renews contribution '..tostring(group),function()
  local A,event=setup(group);local expires=200
  C_UnitAuras.GetAuraDataByIndex=function(_,i)if i==1 then return{spellId=770,sourceUnit='player',auraInstanceID=1,expirationTime=expires}end end
  event('UNIT_AURA','target');t=t+100;expires=300;event('UNIT_AURA','target');t=t+21;dead=true;event('UNIT_HEALTH','target')
  assert(count(A)==1,'readable native refresh metadata was not new participation')
 end)
end
for _,group in ipairs({false,true})do
 test('unreadable caster GUID cannot prove application absence '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');local guid=UnitGUID
  t=t+1;UnitGUID=function(u)if u=='player'then return secret end;return guid(u)end;event('UNIT_AURA','target');UnitGUID=guid
  t=t+99;event('UNIT_AURA','target');t=t+21;dead=true;event('UNIT_HEALTH','target')
  assert(count(A)==0,'protected caster GUID cleared or forked the same application key')
 end)
end
for _,group in ipairs({false,true})do
 test('unreadable unrelated aura cannot hide later readable own debuff '..tostring(group),function()
  local A,event=setup(group)
  C_UnitAuras.GetAuraDataByIndex=function(_,i)if i==1 then return secret elseif i==2 then return{spellId=770,sourceUnit='player'}end end
  event('UNIT_AURA','target');dead=true;event('UNIT_HEALTH','target');assert(count(A)==1,'unrelated hidden aura gated fresh readable own Faerie Fire')
 end)
end
for _,group in ipairs({false,true})do
 test('GUID dedup retries readable aura alias after incomplete scan '..tostring(group),function()
  local A,event=setup(group);A.plates.nameplate1=true
  C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='target'then error('unreadable target aura')elseif i==1 then return{spellId=770,sourceUnit='player'}end end
  A.ScanVisible();dead=true;event('UNIT_HEALTH','nameplate1');assert(count(A)==1,'GUID dedup discarded the only readable own debuff exposure')
 end)
 test('GUID dedup cannot hide readable corpse alias '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');A.plates.nameplate1=true;t=t+1
  UnitIsDeadOrGhost=function(u)if u=='nameplate1'then return true elseif u=='target'then return secret else return false end end
  A.ScanVisible();assert(count(A)==1,'GUID dedup discarded readable corpse behind protected target flags')
 end)
end
for _,group in ipairs({false,true})do
 test('GUID dedup retries readable race alias '..tostring(group),function()
  local A,event=setup(group);A.plates.nameplate1=true;A.Race=function()end
  UnitRace=function(u)if u=='target'then return secret,secret else return'Gnome','Gnome'end end
  A.ScanVisible();dead=true;event('UNIT_HEALTH','nameplate1');assert(count(A)==1,'unreadable target race hid the readable alias')
 end)
end
for _,group in ipairs({false,true})do
 test('GUID dedup retries readable hostility alias '..tostring(group),function()
  local A,event=setup(group);A.plates.nameplate1=true
  local attack=UnitCanAttack
  UnitCanAttack=function(source,u)if u=='target'then return secret end;return attack(source,u)end
  A.ScanVisible();dead=true;event('UNIT_HEALTH','nameplate1')
  assert(count(A)==1,'protected target hostility hid readable hostile alias and its own debuff')
 end)
end
for _,group in ipairs({false,true})do
 test('GUID dedup retries readable living alias after resurrection '..tostring(group),function()
  local A,event=setup(group);event('UNIT_AURA','target');dead=true;event('UNIT_HEALTH','target');assert(count(A)==1)
  t=t+1;dead=false;A.plates.nameplate1=true
  local life=UnitIsDeadOrGhost
  UnitIsDeadOrGhost=function(u)if u=='target'then return secret end;return life(u)end
  A.ScanVisible();dead=true;event('UNIT_HEALTH','nameplate1')
  assert(count(A)==2,'protected target life hid readable resurrection and fresh own debuff')
  event('UNIT_FLAGS','nameplate1');event('PARTY_KILL','Player-me','Player-enemy');assert(count(A)==2,'corpse replay duplicated readable-alias life')
 end)
end
print('ALL '..passed..' KILL LIFECYCLE TESTS PASSED')
