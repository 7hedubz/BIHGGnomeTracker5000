local root=arg[1]or'.'
local passed=0
local function test(name,fn)fn();passed=passed+1;print('PASS '..name)end
local t=1700000000
local secret={}
function issecretvalue(v)return rawequal(v,secret)end
function IsInInstance()return false,'none'end
local function make(group)
 local A={}
 for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Init({},'Me-Realm',t)
 A.Secret=issecretvalue
 A.guildName='Guild';A.guildKey='Guild-Realm';A.members={['Me-Realm']=true,['Friend-Realm']=true}
 if group then
  assert(loadfile(root..'/GroupTracker.lua'))('BIHGGnomeKillTracker5000',A)
  A.InitGroupTracking(t)
  A.groupSources={['Player-me']={name=A.owner,guid='Player-me'},['Pet-me']={name=A.owner,guid='Player-me'},['Player-friend']={name='Friend-Realm',guid='Player-friend'},['Pet-friend']={name='Friend-Realm',guid='Player-friend'}}
 end
 return A
end
local function legacy(A,g)
 A.Observe(g,'Gnome',true,1000,t,false);A.Damage(g,20,0,true,t);A.CC(g,702,true,t,true)
 return A.Death(g,t+1)
end
test('legacy credit requires confirmed readable open world at every boundary',function()
 for _,kind in ipairs({'pvp','arena','party','raid','scenario'})do
  IsInInstance=function()return true,kind end
  local A=make();assert(not legacy(A,'Player-blocked'),'legacy '..kind..' kill must be blocked')
  A.Award(t);assert(A.db.owners[A.owner].total==0,'direct Award cannot bypass '..kind)
  assert(not A.db.dead['Player-blocked'],'blocked deaths cannot poison dedup')
 end
 local states={function()return nil,'none'end,function()return false end,function()error('unavailable')end,function()return false,'pvp'end,function()return true,'none'end,function()return 0,'none'end,function()return secret,'none'end,function()return false,secret end}
 for _,fn in ipairs(states)do IsInInstance=fn;local A=make();assert(not legacy(A,'Player-unknown'));assert(A.db.owners[A.owner].total==0)end
 IsInInstance=nil;local A=make();assert(not legacy(A,'Player-missing'))
 IsInInstance=function()return false,'none'end;assert(legacy(A,'Player-world'));assert(A.db.owners[A.owner].total==1)
end)
test('group and pet credit are independently world-only without receiver filtering',function()
 for _,kind in ipairs({'pvp','arena','party','raid','scenario'})do
  IsInInstance=function()return true,kind end
  local A=make(true)
  A.GroupObserve('Player-blocked','Gnome',true,1000,t,false)
  assert(not A.groupTargets['Player-blocked'],'instance group observation must be discarded')
  -- Even pre-existing entries cannot accept instance contributions or deaths.
  A.groupTargets['Player-blocked']={seen=t,hp=1000,actors={}}
  assert(not A.GroupDamage('Player-blocked',20,0,'Pet-friend',t))
  assert(not A.GroupCC('Player-blocked',702,'Pet-me',t,true))
  assert(not A.GroupDeath('Player-blocked',t+1))
  assert(not A.db.dead['Player-blocked'])
  -- Remote ledger replay/adoption is not a new local observation.
  assert(A.Receive('5|E|K|'..A.EncodeAlias('Me-Realm')..'|Player-me|Player-remote|'..(t+10)..'|'..(t+9),'GUILD','Friend-Realm',t+10))
  assert(A.db.owners[A.owner].total==1,'remote own history is adopted while recipient is instanced')
  assert(A.Receive('2|S|7|3|'..A.Day(t)..'|2|1','GUILD','Friend-Realm',t+10))
  assert(A.PeerRecords()['Friend-Realm'].total==7,'legacy summaries remain compatible')
 end
 IsInInstance=function()return false,'none'end
 local A=make(true);A.GroupObserve('Player-world','Gnome',true,1000,t,false)
 A.GroupDamage('Player-world',19,0,'Player-me',t)
 A.GroupDamage('Player-world',20,0,'Pet-friend',t)
 assert(A.GroupDeath('Player-world',t+1))
 assert(A.db.owners[A.owner].total==0,'under-threshold self cannot borrow pet owner credit')
 assert(A.GuildEffectiveRecord('Friend-Realm',A.PeerRecords()['Friend-Realm'],t+1).total==1)
 A.GroupObserve('Player-debuff','Gnome',true,1000,t+10,false)
 assert(A.GroupCC('Player-debuff',702,'Pet-me',t+10,true));assert(A.GroupDeath('Player-debuff',t+11))
 assert(A.db.owners[A.owner].total==1,'own pet debuff qualifies in world')
end)
local function runtime(A)
 local units={player={guid='Player-me',name='Me',race='Orc',faction='Horde'},target={guid='Player-same',name='Same',race='Gnome',faction='Alliance',enemy=true}}
 function GetServerTime()return t end;function GetTime()return t end
 function CreateFrame()return {events={},scripts={},RegisterEvent=function(self,e)self.events[e]=true end,SetScript=function(self,k,v)self.scripts[k]=v end}end
 function UnitExists(u)return units[u]~=nil end
 function UnitGUID(u)return units[u]and units[u].guid end
 function UnitName(u)return units[u].name,'Realm'end
 function UnitRace(u)return units[u].race,units[u].race end
 function UnitFactionGroup(u)return units[u].faction end
 function UnitIsPlayer(u)return units[u]~=nil end
 function UnitCanAttack(_,u)return units[u]and units[u].enemy and not units[u].dead or false end
 function UnitIsDeadOrGhost(u)return units[u]and units[u].dead or false end
 function UnitHealthMax()return 1000 end
 function UnitAffectingCombat()return true end
 function UnitIsUnit(a,b)return a==b end
 function GetNormalizedRealmName()return 'Realm'end
 function GetGuildInfo()return 'Guild'end
 function GetNumSubgroupMembers()return 0 end
 function IsInRaid()return false end
 C_UnitAuras={GetAuraDataByIndex=function(u,i)if u=='target'and i==1 then return{spellId=702,sourceUnit='player',auraInstanceID=1,expirationTime=t+100}end end}
 assert(loadfile(root..'/Runtime.lua'))('BIHGGnomeKillTracker5000',A)
 A.plates={};A.auras={};A.coverage={};A.QueueShare=function()end;A.Changed=function()end;A.Roster=function()end
 A.Race=function()return 'Gnome'end
 local function event(e,...)
  assert(A.eventFrame.events[e],e..' registered');A.eventFrame.scripts.OnEvent(A.eventFrame,e,...);assert(not A.lastError,A.lastError)
 end
 return units,event
end
test('actual runtime transitions isolate lives and clear eligibility before scans',function()
 for _,eventName in ipairs({'PLAYER_ENTERING_WORLD','ZONE_CHANGED_NEW_AREA','PLAYER_LOGIN'})do
  for _,kind in ipairs({'pvp','arena','party','raid','scenario'})do
   IsInInstance=function()return false,'none'end
   local A=make(true);local units,event=runtime(A)
   A.ScanVisible();assert(A.groupTargets['Player-same'].actors['Player-me'].cc)
   A.groupIncoming['Player-me']={started=t,health=1000,events={{event='SWING_DAMAGE',timestamp=t,sourceGUID='Player-gnome',amount=600}}}
   A.pendingDeath={time=t,health=1000};A.deathFight={started=t,health=1000}
   IsInInstance=function()return true,kind end
   units.target.dead=true;event(eventName)
   assert(not next(A.groupTargets),'transition must discard world eligibility before instance scans')
   assert(not next(A.auras),'transition must discard aura acceptance keys')
   for _,state in pairs(A.groupIncoming)do assert(#state.events==0,'incoming evidence cannot cross location boundary')end
   assert(A.pendingDeath and A.pendingDeath.time==t,'kill boundary must not erase already-frozen own death')
   event('PARTY_KILL','Player-me','Player-same')
   assert(not A.db.dead['Player-same'],'blocked corpse never marks dedup')
   IsInInstance=function()return false,'none'end;event(eventName)
   assert(A.db.owners[A.owner].total==0,'exit corpse cannot reuse world or instance credit')
   units.target.dead=false;t=t+1;event('UNIT_AURA','target')
   units.target.dead=true;t=t+1;event('UNIT_HEALTH','target')
   assert(A.db.owners[A.owner].total==1,'fresh same-GUID world life accepts the same aura again')
   event('PARTY_KILL','Player-me','Player-same');assert(A.db.owners[A.owner].total==1)
   -- A confirmed living post-transition target can qualify even inside the old dedup window.
   IsInInstance=function()return true,kind end;event(eventName)
   IsInInstance=function()return false,'none'end;units.target.dead=false;event(eventName);A.Scan('target')
   units.target.dead=true;t=t+4;event('UNIT_HEALTH','target')
   assert(A.db.owners[A.owner].total==2,'prior world dead cache cannot poison a fresh post-exit life')
  end
 end
end)
test('instance deaths keep strict majority evidence and instance detection remains independent',function()
 for _,kind in ipairs({'pvp','arena','party','raid','scenario'})do
  IsInInstance=function()return true,kind end
  local A=make(true);local units,event=runtime(A)
  local notices=0;A.NearbyNotice=function()notices=notices+1 end
  A.ScanVisible();assert(notices==1 and A.db.seen['Player-same'],'instance encounter and Nearby detection continue')
  assert(not next(A.groupTargets),'detection must not seed instance kill eligibility')
  local damage={[2]='SWING_DAMAGE',[4]='Player-gnome',[8]='Player-me',[12]=500,[13]=0}
  local died={[2]='UNIT_DIED',[8]='Player-me'}
  A.GroupCombat(damage,t);A.GroupCombat(died,t)
  assert((A.db.owners[A.owner].deaths or 0)==0,'exactly half is still rejected in instances')
  t=t+5;damage[12]=501;A.GroupCombat(damage,t);A.GroupCombat(died,t)
  assert(A.db.owners[A.owner].deaths==1,'strict majority incoming damage still counts in instances')
  -- Own native recap path is also not a kill-location gate.
  t=t+5;event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');t=t+1
  C_DeathRecap={GetRecapLink=function()return '|Hdeath:99|h'end,GetRecapMaxHealth=function()return 1000 end,GetRecapEvents=function()return{{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=t}}end}
  event('PLAYER_DEAD');assert(A.db.owners[A.owner].deaths==2,'fresh own recap still qualifies in instances')
  C_DeathRecap=nil
 end
end)
test('automatic policy checks discard stale personal and guild contributions on state changes',function()
 for _,group in ipairs({false,true})do
  IsInInstance=function()return false,'none'end;local A=make(group)
  local observe=group and A.GroupObserve or A.Observe
  local cc=function()if group then return A.GroupCC('Player-stale',702,'Player-me',t,true)else return A.CC('Player-stale',702,true,t,true)end end
  local death=group and A.GroupDeath or A.Death
  observe('Player-stale','Gnome',true,1000,t,false);assert(cc())
  IsInInstance=function()return true,'pvp'end
  assert(not death('Player-stale',t+1));assert(not A.db.dead['Player-stale'])
  IsInInstance=function()return false,'none'end
  assert(not death('Player-stale',t+2),'world contribution cannot survive a blocked death')
  observe('Player-stale','Gnome',true,1000,t+3,false);assert(cc());assert(death('Player-stale',t+4))
 end
end)
test('native recap and group incoming evidence cannot cross either transition direction',function()
 for _,entering in ipairs({true,false})do
  IsInInstance=function()return not entering,entering and 'none'or'pvp'end
  local A=make(true);local units,event=runtime(A)
  A.ScanVisible()
  local damage={[2]='SWING_DAMAGE',[4]='Player-gnome',[8]='Player-me',[12]=600,[13]=0}
  A.GroupCombat(damage,t)
  local before=t
  C_DeathRecap={GetRecapLink=function()return '|Hdeath:199|h'end,GetRecapMaxHealth=function()return 1000 end,GetRecapEvents=function()return{{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=before}}end}
  IsInInstance=function()return entering,entering and 'pvp'or'none'end
  event('PLAYER_ENTERING_WORLD');t=t+1;event('PLAYER_DEAD')
  assert((A.db.owners[A.owner].deaths or 0)==0,'old incoming/recap proof cannot cross boundary')
  event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');t=t+1
  C_DeathRecap.GetRecapLink=function()return '|Hdeath:200|h'end
  C_DeathRecap.GetRecapEvents=function()return{{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=t}}end
  event('PLAYER_DEAD');assert(A.db.owners[A.owner].deaths==1,'fresh destination-side recap qualifies')
  C_DeathRecap=nil
 end
end)
test('unreadable native state cannot bypass any personal or group lifecycle entry',function()
 local invalid={function()return false end,function()error('native error')end,function()return secret,'none'end,function()return false,secret end,function()return false,'raid'end}
 for _,fn in ipairs(invalid)do
  for _,group in ipairs({false,true})do
   for _,entry in ipairs({'damage','cc','death','observe'})do
    IsInInstance=function()return false,'none'end;local A=make(group)
    local observe=group and A.GroupObserve or A.Observe;observe('Player-boundary','Gnome',true,1000,t,false)
    IsInInstance=fn
    if entry=='damage'then
     if group then assert(not A.GroupDamage('Player-boundary',1000,0,'Player-me',t))else A.Damage('Player-boundary',1000,0,true,t)end
    elseif entry=='cc'then
     if group then assert(not A.GroupCC('Player-boundary',702,'Player-me',t,true))else assert(not A.CC('Player-boundary',702,true,t,true))end
    elseif entry=='death'then assert(not (group and A.GroupDeath or A.Death)('Player-boundary',t))
    else observe('Player-boundary','Gnome',true,1000,t,false)end
    IsInInstance=function()return false,'none'end
    assert(not (group and A.GroupDeath or A.Death)('Player-boundary',t+1))
    assert(A.db.owners[A.owner].total==0 and not A.db.dead['Player-boundary'],'unknown observation must not leak or mark death')
   end
  end
 end
 local checker=issecretvalue;issecretvalue=function()error('unreadable checker')end
 IsInInstance=function()return false,'none'end;local A=make();assert(not legacy(A,'Player-checker-error'));issecretvalue=checker
end)
test('legacy death reserves corpse before Changed can reenter personal or group credit',function()
 for _,group in ipairs({false,true})do
  IsInInstance=function()return false,'none'end
  local A=make(group);local g='Player-reentrant'
  A.Observe(g,'Gnome',true,1000,t,false);assert(A.CC(g,770,true,t,true))
  local nested,callbackDead,called
  A.Changed=function()
   if called then return end;called=true;callbackDead=A.db.dead[g]
   A.Observe(g,'Gnome',true,1000,t,false);A.CC(g,770,true,t,true)
   nested=A.Death(g,t)
   if group then
    A.GroupObserve(g,'Gnome',true,1000,t,false);A.GroupCC(g,770,'Player-me',t,true)
    assert(not A.GroupDeath(g,t),'group fallback cannot credit an in-flight personal death')
   end
  end
  assert(A.Death(g,t),'outer qualified death must succeed')
  assert(nested==false,'Changed reentry must reject the same corpse')
  assert(callbackDead==t and A.db.dead[g]==t,'corpse must be reserved before Changed')
  assert(A.db.owners[A.owner].total==1,'Changed reentry must not award twice')
 end
end)
test('legacy final award recheck cannot mark a newly blocked death as credited',function()
 IsInInstance=function()return false,'none'end
 local A=make();A.Observe('Player-race','Gnome',true,1000,t,false);A.CC('Player-race',702,true,t,true)
 local calls=0;IsInInstance=function()calls=calls+1;if calls==1 then return false,'none'else return true,'pvp'end end
 assert(not A.Death('Player-race',t+1),'failed final Award must not report a kill')
 assert(A.db.owners[A.owner].total==0 and not A.db.dead['Player-race'],'blocked final award must not mark corpse dedup')
 IsInInstance=function()return false,'none'end
 assert(not A.Death('Player-race',t+2),'rejected final award cannot leave stale eligibility')
 assert(A.db.owners[A.owner].total==0 and not A.db.dead['Player-race'])
end)
print('ALL '..passed..' WORLD POLICY TESTS PASSED')
