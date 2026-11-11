local root=arg[1]or'.'
if arg[2]~='native_deaths'then arg[2]='native_deaths';dofile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua');return end
return function(A,event,tick,clock,units,combat)
 if os.getenv('BIHG_INCOMING_BENCH')then
  UnitAffectingCombat=function()return true end
  IsInRaid=function()return true end;GetNumGroupMembers=function()return 40 end
  for i=1,40 do units['raid'..i]={guid='Player-bench-'..i,name='Bench'..i,race='Orc',faction='Horde',hp=1000}end
  local calls=0;C_UnitAuras.GetAuraDataByIndex=function()calls=calls+1 end
  A.db.options.nearbyEnabled=false;A.ScanVisible();calls=0
  local started=os.clock()
  for i=1,2000 do clock(clock()+0.5);A.ScanVisible()end
  assert(not A.lastError,A.lastError)
  print(string.format('BENCH 2000 half-second scans / 40 raid victims + own: %.6f CPU seconds; %d aura API calls',os.clock()-started,calls))
  return
 end
 local chat={};DEFAULT_CHAT_FRAME.AddMessage=function(_,s)chat[#chat+1]=s end
 local function deaths()return A.db.owners[A.owner].deaths or 0 end
 local function notices()local n=0;for _,s in ipairs(chat)do if s:find('Death to Gnomes recorded',1,true)then n=n+1 end end;return n end
 C_DeathRecap=nil;C_Timer=nil
 UnitAffectingCombat=function(u)return units[u]and units[u].fighting==true end
 units.player.fighting=true;units.player.hp=nil
 A.db.options.nearbyEnabled=false
 units.enemycaster={guid='Player-native-source',name='Caster',race='Gnome',faction='Alliance',hp=1000,enemy=true}
 local aura={spellId=172,sourceUnit='enemycaster',isHarmful=true,isHelpful=false}
 C_UnitAuras.GetAuraDataByIndex=function(u,i,filter)assert(filter=='HARMFUL');if u=='player'and i==1 then return aura end end
 event('PLAYER_REGEN_DISABLED');event('UNIT_AURA','player')
 assert(deaths()==0 and notices()==0,'harmful aura alone is not a death')
 units.player.dead=true;event('PLAYER_DEAD')
 assert(deaths()==1 and notices()==1,'native living harmful Gnome aura must qualify actual own death without HP')
 event('PLAYER_DEAD');A.Recap();assert(deaths()==1 and notices()==1,'duplicate death cannot repeat credit')
 print('PASS native own UNIT_AURA: harmful proof without HP, Nearby OFF, actual death, once-only chat')
 local function life()
  clock(clock()+10);units.player.dead=false;units.player.hp=1000;units.player.fighting=true
  event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED')
 end
 local function ownAura(value)
  C_UnitAuras.GetAuraDataByIndex=function(u,i,filter)assert(filter=='HARMFUL');if u=='player'and i==1 then return value end end
 end
 local function die()units.player.dead=true;event('PLAYER_DEAD');assert(not A.lastError,A.lastError)end
 -- Latest validated living evidence, not the first application, bounds long fights.
 for _,kind in ipairs({'native new spell','same-source refresh','different-source refresh','living reinspection'})do
  life();ownAura(aura);event('UNIT_AURA','player');local before=deaths()
  local first=A.groupIncoming['Player-me'].harmful.time
  clock(clock()+A.WINDOW+1)
  assert(not A.IncomingDeathEvidence('Player-me',clock()),'first harmful proof must expire')
  local source=kind=='different-source refresh'and'Player-gnome'or'Player-native-source'
  if kind=='native new spell'then
   ownAura({spellId=6770,sourceUnit='enemycaster',isHarmful=true});event('UNIT_AURA','player')
  elseif kind=='living reinspection'then event('UNIT_AURA','player')
  else assert(A.IncomingHarmful('Player-me',source,172,clock(),'SPELL_AURA_REFRESH','DEBUFF','Gnome',nil,'player'))end
  local latest=A.groupIncoming['Player-me'].harmful
  assert(latest.time==clock()and latest.source==source,'fresh '..kind..' must replace expired first proof')
  assert(A.IncomingHarmful('Player-me','Player-native-source',172,first,'SPELL_AURA_REFRESH','DEBUFF','Gnome',nil,'player'))
  assert(A.groupIncoming['Player-me'].harmful==latest,'out-of-order valid application must not regress latest proof')
  assert(deaths()==before,'fresh harmful evidence without death cannot count')
  ownAura(nil);die();assert(deaths()==before+1,'fresh '..kind..' must qualify long-fight actual death')
 end
 print('PASS long-fight latest harmful proof: new spell, same/different-source refresh, living reinspection, no timestamp regression')
 for _,failure in ipairs({'absent','error','secret','corpse'})do
  life();ownAura(aura);event('UNIT_AURA','player');local before=deaths()
  local first=A.groupIncoming['Player-me'].harmful
  clock(clock()+A.WINDOW+1)
  if failure=='error'then C_UnitAuras.GetAuraDataByIndex=function()error('failed scan')end
  elseif failure=='secret'then local hidden={};issecretvalue=function(v)return v==hidden end;ownAura(hidden)
  elseif failure=='corpse'then units.player.dead=true
  else ownAura(nil)end
  event('UNIT_AURA','player');issecretvalue=function()return false end
  assert(A.groupIncoming['Player-me'].harmful==first,'failed/absent/corpse inspection must not refresh proof')
  die();assert(deaths()==before,'expired proof cannot be renewed by '..failure)
 end
 print('PASS expired harmful evidence is not refreshed by absent/failed/secret/corpse scans')
 -- Sap does not necessarily put its living victim into native combat.
 life();units.player.fighting=false;units.player.hp=nil
 local sap={spellId=6770,sourceUnit='enemycaster',isHarmful=true,isHelpful=false}
 ownAura(sap);event('UNIT_AURA','player');local sapBefore=deaths()
 assert(A.groupIncoming['Player-me']and A.groupIncoming['Player-me'].harmful,'out-of-combat native Sap must capture living proof')
 tick();tick();assert(deaths()==sapBefore,'Sap without actual death cannot count')
 event('PLAYER_REGEN_DISABLED');ownAura(nil);tick()
 die();assert(deaths()==sapBefore+1,'combat start after Sap must preserve same-life proof')
 print('PASS out-of-combat Sap survives polling and combat start, actual own death required')
 for _,flag in ipairs({'false','unavailable'})do
  life();units.player.fighting=false;units.player.hp=nil
  local combatFlag=UnitAffectingCombat
  if flag=='unavailable'then UnitAffectingCombat=nil end
  ownAura(sap);event('UNIT_AURA','player');local before=deaths();tick();tick()
  assert(deaths()==before,'living Sap cannot count with '..flag..' combat flag')
  ownAura(nil);die();assert(deaths()==before+1,'native Sap actual death must not require combat flag '..flag)
  UnitAffectingCombat=combatFlag
 end
 for _,boundary in ipairs({'regen','instance','PLAYER_ALIVE','PLAYER_UNGHOST','expired'})do
  life();units.player.fighting=false;ownAura(sap);event('UNIT_AURA','player');local before=deaths()
  ownAura(nil)
  if boundary=='regen'then event('PLAYER_REGEN_ENABLED');clock(clock()+3)
  elseif boundary=='instance'then IsInInstance=function()return false,'none'end;event('ZONE_CHANGED_NEW_AREA')
   IsInInstance=function()return true,'pvp'end;event('ZONE_CHANGED_NEW_AREA')
  elseif boundary=='expired'then clock(clock()+A.WINDOW+1)
  else event(boundary)end
  tick();die();assert(deaths()==before,'old out-of-combat Sap must not cross '..boundary)
  IsInInstance=function()return false,'none'end;event('ZONE_CHANGED_NEW_AREA')
 end
 print('PASS false/unavailable combat flags, no HP, direct actual death; regen/context/rez/expiry isolate Sap')
 life();units.player.fighting=false;ownAura(nil);event('PLAYER_REGEN_ENABLED');clock(clock()+10)
 ownAura(sap);event('UNIT_AURA','player');local afterRegen=deaths();tick();die()
 assert(deaths()==afterRegen+1,'fresh out-of-combat Sap after an ended combat must establish its own proof context')
 print('PASS fresh out-of-combat Sap after old combat end qualifies its own actual death')
 for _,ingress in ipairs({'direct','synthetic parser','native'})do
  life();units.player.hp=9000;event('UNIT_MAXHEALTH','player')
  units.player.fighting=false;ownAura(nil);event('PLAYER_REGEN_ENABLED');clock(clock()+10)
  units.player.hp=1000
  local before=deaths();local server=clock();local originalClock=GetTime
  GetTime=function()return server-1600000000 end
  if ingress=='direct'then
   assert(A.IncomingHarmful('Player-me','Player-native-source',6770,server,nil,'DEBUFF','Gnome',nil,'player'))
  elseif ingress=='synthetic parser'then
   local oldLog=CombatLogGetCurrentEventInfo
   CombatLogGetCurrentEventInfo=function()return server,'SPELL_AURA_APPLIED',false,'Player-gnome',nil,nil,nil,'Player-me',nil,nil,nil,6770,nil,nil,'DEBUFF'end
   A.ReadCombatLog();CombatLogGetCurrentEventInfo=oldLog
  else ownAura(sap);event('UNIT_AURA','player')end
  local fight=A.deathFight
  assert(fight and not fight.ended and fight.started==server,'accepted '..ingress..' must establish matching own context')
  assert(fight.clockStart==GetTime()and fight.health==1000,'new context must use current monotonic clock and current-life/context peak, not old peak')
  assert(A.IncomingDeathEvidence('Player-me',server).harmful,'accepted ingress must retain source proof')
  assert(deaths()==before,'accepted harmful ingress alone is not death')
  local process=A.Recap;A.Recap=function()end;ownAura(nil);die()
  local pending=A.pendingDeath;local frozen=pending.fight;local frozenProof=pending.incoming
  assert(not A.IncomingHarmful('Player-me','Player-gnome',172,server,nil,'DEBUFF','Gnome',nil,'player'),'corpse cannot establish another context')
  assert(pending.fight==frozen and pending.incoming==frozenProof,'accepted-ingress helper must not mutate frozen pending death')
  A.Recap=process;A.Recap();GetTime=originalClock
  assert(deaths()==before+1,'accepted '..ingress..' after old combat end must count actual death without aura scan/recap')
 end
 print('PASS shared direct/synthetic/native accepted harmful context: old end cleared, peak isolated, clocks distinct, frozen pending unchanged')
 local secret={};issecretvalue=function(v)return rawequal(v,secret)end
 for _,kind in ipairs({'helpful','not harmful','secret aura','secret source','secret spell','secret race','unknown source','human','NPC','absent','corpse only','failed cast'})do
  life();local before=deaths()
  local value={spellId=172,sourceUnit='enemycaster',isHarmful=true,isHelpful=false}
  units.enemycaster.race='Gnome';units.enemycaster.guid='Player-native-source'
  if kind=='helpful'then value.isHelpful=true
  elseif kind=='not harmful'then value.isHarmful=false
  elseif kind=='secret aura'then value=secret
  elseif kind=='secret source'then value.sourceUnit=secret
  elseif kind=='secret spell'then value.spellId=secret
  elseif kind=='secret race'then units.enemycaster.race=secret
  elseif kind=='unknown source'then value.sourceUnit='missing'
  elseif kind=='human'then units.enemycaster.race='Human'
  elseif kind=='NPC'then units.enemycaster.guid='Creature-native-source'
  elseif kind=='absent'or kind=='failed cast'then value=nil end
  ownAura(value)
  if kind=='corpse only'then units.player.dead=true end
  event('UNIT_AURA','player')
  if kind=='failed cast'then A.GroupCombat({[2]='SPELL_CAST_FAILED',[4]='Player-native-source',[8]='Player-me',[12]=172,[15]='DEBUFF'},clock())end
  die();assert(deaths()==before,kind..' must not qualify native incoming death')
 end
 units.enemycaster.race='Gnome';units.enemycaster.guid='Player-native-source'
 print('PASS native negative matrix: secret/helpful/non-Gnome/NPC/missing/failed cast/corpse-only cannot qualify')
 for _,boundary in ipairs({'zone','instance','PLAYER_ALIVE','PLAYER_UNGHOST'})do
  life();local before=deaths();ownAura(aura);event('UNIT_AURA','player')
  local process=A.Recap;A.Recap=function()end
  die();local pending=A.pendingDeath;local frozen=pending.incoming
  assert(frozen and frozen.harmful and frozen.source=='Player-native-source','freeze accepted living source proof')
  units.enemycaster.race='Human';units.player.hp=100000
  if boundary=='zone'then event('ZONE_CHANGED_NEW_AREA')
  elseif boundary=='instance'then IsInInstance=function()return true,'pvp'end;event('PLAYER_ENTERING_WORLD')
  else event(boundary)end
  A.Recap=process;A.Recap()
  assert(deaths()==before+1 and pending.incoming==frozen,'frozen harmful dead-life proof lost or enlarged after '..boundary)
  units.enemycaster.race='Gnome';IsInInstance=function()return false,'none'end;event('ZONE_CHANGED_NEW_AREA')
 end
 print('PASS frozen CC survives zone/instance/release/resurrection without consulting later source race or health')
 life();ownAura(nil);local before=deaths();local process=A.Recap;A.Recap=function()end;die();local prior=A.pendingDeath
 life();ownAura(aura);event('UNIT_AURA','player');A.Recap=process;A.Recap()
 assert(deaths()==before and not prior.incoming,'later life harmful proof cannot qualify an earlier pending death')
 die();assert(deaths()==before+1,'fresh second-life harmful proof qualifies only second death')
 print('PASS prior pending life cannot borrow a later life harmful application')
 for _,state in ipairs({'unguilded','unverified','nonmember','guild switch','membership loss'})do
  life();ownAura(aura);event('UNIT_AURA','player');local before=deaths()
  local guild,members=A.guildKey,A.members
  if state=='unguilded'then A.guildKey=nil
  elseif state=='unverified'then A.guildUnverified=true
  elseif state=='nonmember'then A.members[A.owner]=nil end
  local process=A.Recap;A.Recap=function()end;die()
  if state=='guild switch'then A.guildKey='Other-Realm'
  elseif state=='membership loss'then A.members[A.owner]=nil
  else A.guildKey=guild;A.guildUnverified=false;A.members[A.owner]=true end
  A.Recap=process;A.Recap();assert(deaths()==before,'harmful proof bypassed frozen/current guild gate: '..state)
  A.guildKey=guild;A.members=members;A.members[A.owner]=true;A.guildUnverified=false
 end
 print('PASS native harmful frozen/current guild authority rejects joining/switching/unverified/nonmember/lost membership')
 local friend='NoAddon-Realm'
 units.party1={guid='Player-friend-victim',name='NoAddon',race='Orc',faction='Horde',hp=1000,fighting=false}
 units.player.dead=false;units.player.hp=1000;event('PLAYER_ALIVE');event('GROUP_ROSTER_UPDATE')
 C_UnitAuras.GetAuraDataByIndex=function(u,i,filter)assert(filter=='HARMFUL');if u=='party1'and i==1 then return sap end end
 tick();tick()
 local function friendDeaths()local peers=A.PeerRecords();return A.GuildEffectiveRecord(friend,peers[friend],clock()).deaths end
 assert(friendDeaths()==0,'periodic aura evidence is not death')
 units.party1.dead=true;event('UNIT_HEALTH','party1')
 assert(friendDeaths()==1,'periodic native harmful aura must qualify a guild party victim on actual death')
 tick();event('UNIT_FLAGS','party1');assert(friendDeaths()==1,'native repeated corpse cannot duplicate group death')
 clock(clock()+4)
 A.GroupCombat({[2]='SWING_DAMAGE',[4]='Player-gnome',[8]='Player-friend-victim',[12]=20,[13]=0},clock())
 A.GroupCombat({[2]='UNIT_DIED',[8]='Player-friend-victim'},clock())
 assert(friendDeaths()==1,'synthetic late damage/death must not rearm a natively confirmed group corpse')
 assert(not A.lastError,A.lastError)
 print('PASS periodic incoming aura -> native guild party death, no CLEU or recap, duplicate corpse suppressed')
 clock(clock()+10);units.party1.dead=false
 C_UnitAuras.GetAuraDataByIndex=function()end;event('UNIT_FLAGS','party1')
 units.party1.dead=true;event('UNIT_HEALTH','party1');assert(friendDeaths()==1,'new life cannot reuse previous group harmful proof')
 clock(clock()+10);units.raid1=units.party1;units.party1=nil;units.raid1.dead=false
 IsInRaid=function()return true end;GetNumGroupMembers=function()return 1 end
 IsInInstance=function()return true,'raid'end;event('GROUP_ROSTER_UPDATE');event('ZONE_CHANGED_NEW_AREA')
 C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='raid1'and i==1 then return aura end end
 combat(true);event('UNIT_AURA','raid1');units.raid1.dead=true;event('UNIT_FLAGS','raid1')
 assert(friendDeaths()==2,'native raid victim harmful proof must count in instances and combat with Nearby OFF')
 assert(not next(A.groupTargets),'incoming deaths must not open instance kill eligibility')
 combat(false);assert(not A.lastError,A.lastError)
 print('PASS native raid UNIT_AURA -> UNIT_FLAGS death in instance/combat, fresh-life reset and independent kill gate')
 for i=1,80 do
  units.raid1={guid='Player-bound-'..i,name='Bound'..i,race='Orc',faction='Horde',hp=1000,fighting=true}
  event('GROUP_ROSTER_UPDATE')
 end
 local stored=0;for _ in pairs(A.groupIncoming)do stored=stored+1 end
 assert(stored<=2,'live incoming proof must remain bounded to current tracked victims, not every departed session member')
 print('PASS incoming proof storage is bounded to current tracked victims')
 -- Duplicate roster aliases must not veto a readable observed victim token.
 life();units.player.fighting=false
 units.raid1={guid=units.player.guid,name=units.player.name,race='Orc',faction='Horde',hp=1000}
 local deadFlag=UnitIsDeadOrGhost
 UnitIsDeadOrGhost=function(u)if u=='raid1'then return nil end;return deadFlag(u)end
 event('GROUP_ROSTER_UPDATE');assert(A.groupOwners['Player-me'].unit=='raid1')
 ownAura(sap);local aliasBefore=deaths();event('UNIT_AURA','player')
 assert(A.groupIncoming['Player-me']and A.groupIncoming['Player-me'].harmful,'readable player alias must bypass unreadable stored raid1 death flag')
 die();assert(deaths()==aliasBefore+1,'own actual death must use frozen valid alias proof, not stored unreadable alias')
 UnitIsDeadOrGhost=deadFlag
 for _,flag in ipairs({'dead','secret','error'})do
  life();units.player.fighting=false
  UnitIsDeadOrGhost=function(u)
   if u=='raid1'then if flag=='dead'then return true elseif flag=='secret'then return secret else error('unreadable life')end end
   return deadFlag(u)
  end
  event('GROUP_ROSTER_UPDATE');ownAura(sap);local before=deaths();event('UNIT_AURA','player')
  die();assert(deaths()==before+1,'readable player must override duplicate alias '..flag..' life flag')
  UnitIsDeadOrGhost=deadFlag
 end
 print('PASS readable observed victim alias survives unreadable/dead/secret/error duplicate roster token through actual own death')
 for _,failure in ipairs({'error','secret','read error'})do
  life();units.player.fighting=false;units.raid1.dead=false
  C_UnitAuras.GetAuraDataByIndex=function(u,i)
   if u=='raid1'then
    if failure=='error'then error('unreadable provider')end
    if failure=='secret'then return secret end
    return setmetatable({},{__index=function()error('unreadable aura field')end})
   end
   if u=='player'and i==1 then return sap end
  end
  local before=deaths()
  assert(pcall(A.ScanIncomingAuras,'raid1'),'failed aura row read must be contained')
  A.ScanIncomingAuras('player')
  assert(A.groupIncoming['Player-me'].harmful,'failed alias provider must not throttle immediate readable alias: '..failure)
  die();assert(deaths()==before+1,'readable fallback proof must qualify actual death')
 end
 print('PASS failed/secret/read-error aura provider permits immediate readable alias fallback')
 -- Aura polling must not erase the independent ended-combat damage grace.
 life();units.player.hp=2000;event('UNIT_MAXHEALTH','player')
 A.GroupCombat({[2]='SWING_DAMAGE',[4]='Player-gnome',[8]='Player-me',[12]=40,[13]=0},clock())
 units.player.fighting=false;units.player.hp=1000;ownAura(nil);tick()
 local ended=A.groupIncoming['Player-me']
 assert(ended and ended.health==2000 and #ended.events==1,'empty out-of-combat aura poll must preserve ended damage and peak health')
 assert(not A.IncomingHarmful('Player-me','Player-native-source',0,clock(),nil,'DEBUFF','Gnome',nil,'player'))
 assert(A.groupIncoming['Player-me']==ended,'invalid harmful row must not replace ended damage proof')
 die()
 print('PASS out-of-combat aura observation preserves independent collector damage and peak-health bounds')
 life();units.player.fighting=false;event('PLAYER_ALIVE');ownAura(nil);event('UNIT_AURA','player')
 local s=A.groupIncoming['Player-me']
 assert(not A.IncomingHarmful('Player-me','Player-native-source',6770,clock(),nil,'DEBUFF','Gnome',nil,'enemycaster'),'conflicting victim GUID must not be trusted')
 units.guest={guid='Player-guest-victim',name='Guest',race='Orc',faction='Horde',guild='Other'}
 assert(not A.IncomingHarmful(units.guest.guid,'Player-native-source',6770,clock(),nil,'DEBUFF','Gnome',nil,'guest'),'untracked nonguild victim cannot accept proof')
 A.GroupCombat({[2]='SWING_DAMAGE',[4]='Player-gnome',[8]='Player-me',[12]=1000,[13]=0},clock())
 assert(not s.combat and #s.events==0,'out-of-combat aura scan must not authorize collector damage')
 local calls=0;C_UnitAuras.GetAuraDataByIndex=function()calls=calls+1 end
 clock(clock()+1)
 for i=1,100 do A.ScanIncomingAuras('player')end
 assert(calls==1,'out-of-combat poll must be throttled per readable token')
 clock(clock()+0.5);A.ScanIncomingAuras('player');assert(calls==1)
 clock(clock()+0.5);A.ScanIncomingAuras('player');assert(calls==2)
 local before=deaths();die();assert(deaths()==before,'arbitrary out-of-combat damage cannot qualify actual death')
 print('PASS conflicting/untracked victim rejection, conservative out-of-combat damage gate and bounded one-second aura polling')
end
