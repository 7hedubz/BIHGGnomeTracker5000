local root=arg[1]or'.'
if arg[2]~='notifications'then arg[2]='notifications';dofile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua');return end
return function(A,event,tick,clock,units,combat,sent)
 local chat={};DEFAULT_CHAT_FRAME.AddMessage=function(_,s)chat[#chat+1]=s end
 local function count(text)local n=0;for _,s in ipairs(chat)do if s:find(text,1,true)then n=n+1 end end;return n end
 if os.getenv('BIHG_TRACER')~='personal'then
  assert(A.Receive('2|V|1.10.0','GUILD','Friend-Realm',clock()),'validated peer version accepted')
  assert(count('update')==1,'actual Receive must immediately print newer peer version locally')
  print('PASS Receive -> local version notice')
  local first=clock()
  A.Receive('2|V|2.0.0','GUILD','Friend-Realm',first+1)
  assert(count('update')==1,'higher reports cannot bypass global 900-second cooldown')
  clock(first+899);tick();assert(count('update')==2,'regular runtime reminds at exact 900 boundary')
  assert(A.account.versionNotice.highest=='2.0.0','highest peer report persists account-wide')
  assert(A.account.versionNotice.last==first+900,'notice timestamp persists before callback')
  print('PASS repeated higher report cooldown and runtime reminder')
  assert(A.NewerVersion('1.10.0','1.9.9')and not A.NewerVersion('1.9.9','1.10.0'))
  local bad={'1.2','1.2.3.4','1.2.3-beta','01.2.3','1.02.3','-1.2.3','100000.0.0','1.2.3|x','1.2.3\n','1.2.3|https://evil'}
  for _,v in ipairs(bad)do assert(not A.Receive('2|V|'..v,'GUILD','Friend-Realm',clock()),'malformed version '..v)end
  local highest=A.account.versionNotice.highest
  for _,channel in ipairs({'WHISPER','PARTY','RAID','SAY'})do assert(not A.Receive('2|V|99.0.0',channel,'Friend-Realm',clock()))end
  assert(not A.Receive('2|V|99.0.0','GUILD','Intruder-Realm',clock()))
  A.guildUnverified=true;assert(not A.Receive('2|V|99.0.0','GUILD','Friend-Realm',clock()));A.guildUnverified=false
  local roster=A.rosterSeen;A.rosterSeen={}
  assert(not A.Receive('2|V|99.0.0','GUILD','Friend-Realm',clock()),'cached member alone is not fresh version authority')
  A.rosterSeen=roster
  assert(A.account.versionNotice.highest==highest,'rejected reports cannot poison highest')
  local secret={};local original=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end
  assert(not A.Receive(secret,'GUILD','Friend-Realm',clock()))
  assert(not A.Receive('2|V|99.0.0',secret,'Friend-Realm',clock()))
  assert(not A.Receive('2|V|99.0.0','GUILD',secret,clock()))
  assert(not A.NewerVersion(secret,'1.0.0'))
  assert(not A.Receive('2|V|99.0.0','GUILD','Friend-Realm',secret),'secret timestamp rejected before rate arithmetic')
  issecretvalue=original
  local n=count('update');local at=clock()
  for i=1,899 do A.Receive('2|V|'..(i%2==0 and'2.0.0'or'1.0.0'),'GUILD','Friend-Realm',at+i)end
  assert(count('update')==n,'old peers neither regress highest nor shift next deadline')
  clock(at+899);tick();assert(count('update')==n+1)
  -- Serialize only the bounded account reminder record, as a real reload/alt does.
  local saved=A.account.versionNotice;local serialized=string.format('return {highest=%q,last=%.0f}',saved.highest,saved.last)
  local account={versionNotice=assert(loadstring(serialized))()}
  local B={Secret=A.Secret};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('Test',B)end
  B.Init({},'Alt-Realm',clock());B.InitAccount(account,'alt',clock());B.CheckVersionNotice(clock()+899);assert(count('update')==n+1,'reload/alt cooldown')
  B.CheckVersionNotice(clock()+900);assert(count('update')==n+2,'reload reminder boundary')
  B.VERSION='2.0.0';B.CheckVersionNotice(clock()+1800);assert(count('update')==n+2,'equal running version silences reminders')
  B.VERSION='3.0.0';B.CheckVersionNotice(clock()+2700);assert(count('update')==n+2,'newer local version silences reminders')
  B.VERSION='1.0.0';B.CheckVersionNotice(clock()-10);B.CheckVersionNotice(clock()-9);assert(count('update')==n+2,'rollback cannot flood')
  account.versionNotice={highest='9.0.0',last='bad'};B.InitVersionNotice(clock());B.CheckVersionNotice(clock());assert(count('update')==n+2,'malformed timestamp is deferred')
  account.versionNotice={highest='evil|text',last=0};B.InitVersionNotice(clock());B.CheckVersionNotice(clock()+9999);assert(count('update')==n+2)
  print('PASS numeric schema, authority, serialized account/alt cooldown, rollback and local upgrade')
  -- Light discovery uses the existing paced/backed-off queue, not direct sends.
  local start=#sent;clock(clock()+60);for i=1,8 do tick()end
  local seen=false;for i=start+1,#sent do if sent[i][2]=='2|V|'..A.VERSION then seen=true end end
  assert(seen,'light minute query advertises local version')
  print('PASS queued light version discovery')
  local profile=false;for _,p in ipairs(A.BuildPackets(false,clock()))do if p=='2|V|'..A.VERSION then profile=true end end
  assert(profile,'profile and score shares include local version metadata')
  local accepted=0;A.rx={};A.rxGlobal=nil
  for i=1,500 do if A.Receive('2|V|2.0.0','GUILD','Friend-Realm',clock())then accepted=accepted+1 end end
  assert(accepted==450,'version packets share existing per-peer rate cap')
  local secret={};local old=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end
  for _,state in ipairs({secret,{highest=secret,last=secret},{highest='9.0.0',last=secret}})do
   account.versionNotice=state;B.InitVersionNotice(clock());B.CheckVersionNotice(clock())
  end
  account.versionNotice='broken';B.InitVersionNotice(clock());local beforeMalformed=count('update');B.ReceiveVersion('2|V|9.0.0',clock());assert(count('update')==beforeMalformed,'malformed persisted container cannot restart immediate notices')
  issecretvalue=old
  -- Version controls retain exactly their queued position across rejection/combat.
  local C={Secret=A.Secret};for _,f in ipairs({'Core.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('Test',C)end
  C.Init({},'Self',clock());C.guildKey='Guild-Realm';C.members={};C.lastRequest=clock();C.versionPending=true
  local native=C_ChatInfo.SendAddonMessage;local attempts=0;C_ChatInfo.SendAddonMessage=function(_,p)attempts=attempts+1;assert(p=='2|V|'..C.VERSION);return false end
  C.Pump(clock());assert(attempts==1 and C.versionPending)
  C.Pump(clock()+1);assert(attempts==1 and C.versionPending,'version backoff retained')
  combat(true);C.Pump(clock()+10);assert(attempts==1 and C.versionPending,'combat pauses version send')
  combat(false);C_ChatInfo.SendAddonMessage=function(_,p)attempts=attempts+1;return 0 end
  C.Pump(clock()+11);assert(attempts==2 and not C.versionPending)
  C_ChatInfo.SendAddonMessage=native
  print('PASS profile version, shared receive caps, protected persistence and outgoing retry/combat')
  local D={Secret=A.Secret};for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('Test',D)end
  D.Init({},'Self-Realm',clock());D.InitAccount({},'same',clock());D.guildKey='Guild-Realm';D.members={['Friend-Realm']=true};D.rosterSeen={['Friend-Realm']=true}
  local before=count('update')
  assert(D.Receive('2|V|'..D.VERSION,'GUILD','Friend-Realm',clock()))
  assert(D.Receive('2|V|1.0.0','GUILD','Friend-Realm',clock()));assert(count('update')==before,'fresh equal/lower reports do not notify')
  local capture=DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage=function(self,s)capture(self,s);D.CheckVersionNotice(clock());D.Receive('2|V|99.0.0','GUILD','Friend-Realm',clock())end
  D.Receive('2|V|9.0.0','GUILD','Friend-Realm',clock());DEFAULT_CHAT_FRAME.AddMessage=capture
  assert(count('update')==before+1,'timestamp reserved before reentrant chat callback')
  DEFAULT_CHAT_FRAME.AddMessage=function()error('injected version chat error')end
  D.CheckVersionNotice(clock()+900);assert(D.account.versionNotice.last==clock()+900,'failed local chat retains cooldown');DEFAULT_CHAT_FRAME.AddMessage=capture
  print('PASS equal/lower reports and reentrant/erroring chat do not spam')
 end
 if os.getenv('BIHG_TRACER')~='version'then
  local g='Player-notice';local t=clock();A.Observe(g,'Gnome',true,1000,t,false);A.Damage(g,20,0,true,t)
  assert(A.Death(g,t,true),'personal qualifying award')
  assert(count('Gnome kill recorded')==1,'actual personal award must print local confirmation')
  print('PASS personal award -> local confirmation')
  assert(not A.Death(g,t,true));assert(count('Gnome kill recorded')==1)
  local before=count('Gnome kill recorded')
  local gg='Player-group-notice';A.GroupObserve(gg,'Gnome',true,1000,t,false)
  assert(A.GroupDamage(gg,20,0,'Player-me',t));assert(A.GroupDeath(gg,t,true))
  assert(count('Gnome kill recorded')==before+1,'group personal commit confirms once')
  assert(not A.GroupDeath(gg,t,true));assert(count('Gnome kill recorded')==before+1)
  local proof={damage=501,maxHealth=1000,source='Player-gnome',time=t}
  local old=count('Death to Gnomes recorded')
  assert(A.PlayerDeath('notice-death','Gnome',t,'Player-gnome',proof))
  assert(count('Death to Gnomes recorded')==old+1,'own group death confirms once')
  assert(chat[#chat]:find('Tiny',1,true),'known opponent named without claiming final blow')
  assert(not A.PlayerDeath('notice-death','Gnome',t,'Player-gnome',proof));assert(count('Death to Gnomes recorded')==old+1)
  -- History/rebuild/ordinary Changed are not actual personal observations.
  local all=#chat;A.AddGuildEvent('K',A.owner,'Player-me','Player-history-notice',t+10,t+10,t+10);A.RebuildOwnGuildTotals(t+10);A.Changed();assert(#chat==all)
  print('PASS local group personal credit only; no replay/rebuild confirmations')
  local failures=count('You did not qualify for kill credit.')
  local missed='Player-missed';A.db.seen[missed]={name='Small-Realm',days={}}
  A.GroupObserve(missed,'Gnome',true,1000,t,false)
  A.groupSources['Player-friend']={name='Friend-Realm',guid='Player-friend'}
  assert(A.GroupDamage(missed,900,0,'Player-friend',t));assert(A.GroupDeath(missed,t,true))
  assert(count('You did not qualify for kill credit.')==failures+1,'guildmate-only kill reports local nonqualification once')
  assert(chat[#chat]:find('Gnome death observed: Small-Realm. You did not qualify for kill credit.',1,true))
  assert(not A.GroupDeath(missed,t,true));A.Death(missed,t,true)
  assert(count('You did not qualify for kill credit.')==failures+1,'fallback cannot duplicate corpse notice')
  local bare='Player-bare';A.Observe(bare,'Gnome',true,1000,t,false)
  assert(not A.Death(bare,t,true));assert(count('You did not qualify for kill credit.')==failures+2,'personal zero contribution confirms observed death without credit')
  print('PASS confirmed observed deaths without personal qualification')
  for _,group in ipairs({false,true})do
   local observe=group and A.GroupObserve or A.Observe
   local death=group and A.GroupDeath or A.Death
   for _,amount in ipairs({0,19,20})do
    local id='Player-boundary-'..tostring(group)..'-'..amount;local n=count('You did not qualify for kill credit.');local k=count('Gnome kill recorded')
    observe(id,'Gnome',true,1000,t,false)
    if group then A.GroupDamage(id,amount,0,'Player-me',t)else A.Damage(id,amount,0,true,t)end
    death(id,t,true)
    assert(count('You did not qualify for kill credit.')==n+(amount<20 and 1 or 0))
    assert(count('Gnome kill recorded')==k+(amount==20 and 1 or 0))
    death(id,t,true);assert(count('You did not qualify for kill credit.')==n+(amount<20 and 1 or 0))
   end
   local id='Player-rez-'..tostring(group);local n=count('You did not qualify for kill credit.')
   observe(id,'Gnome',true,1000,t,false);death(id,t,true)
   observe(id,'Gnome',true,1000,t+1,false);death(id,t+1,true)
   assert(count('You did not qualify for kill credit.')==n+2,'fresh confirmed living life gets a new notice')
   local cc='Player-notice-cc-'..tostring(group);local k=count('Gnome kill recorded');n=count('You did not qualify for kill credit.')
   observe(cc,'Gnome',true,1000,t,false)
   if group then A.GroupCC(cc,770,'Player-me',t,true)else A.CC(cc,770,true,t,true)end
   death(cc,t,true);assert(count('Gnome kill recorded')==k+1 and count('You did not qualify for kill credit.')==n)
   local unknown='Player-unknown-'..tostring(group);observe(unknown,'Gnome',true,1000,t,false)
   local record=group and A.groupTargets[unknown]or A.encounters[unknown];record.creditUnknown=true
   n=#chat;death(unknown,t,true);assert(#chat==n,'ambiguous evidence cannot assert nonqualification')
  end
  -- A real incomplete aura scan must mark ambiguity, not manufacture a negative.
  local secret={};local originalSecret=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)end
  local aura=C_UnitAuras.GetAuraDataByIndex
  C_UnitAuras.GetAuraDataByIndex=function()return secret end
  units.nameplateNotice={guid='Player-secret-notice',name='Hidden',race='Gnome',faction='Alliance',hp=1000,enemy=true}
  A.Scan('nameplateNotice',nil,true);local n=count('You did not qualify for kill credit.')
  units.nameplateNotice.dead=true;A.Scan('nameplateNotice',nil,true)
  assert(count('You did not qualify for kill credit.')==n,'secret aura scan cannot claim known nonqualification')
  C_UnitAuras.GetAuraDataByIndex=aura;issecretvalue=originalSecret;units.nameplateNotice=nil
  print('PASS 2%/debuff qualification, zero credit, duplicate/fresh lives and ambiguous evidence')
  local current=clock();local capture=DEFAULT_CHAT_FRAME.AddMessage
  for _,mode in ipairs({'group','personal'})do
   local observe=mode=='group'and A.GroupObserve or A.Observe;local death=mode=='group'and A.GroupDeath or A.Death
   local uid='Player-reentrant-'..mode;local n=count('You did not qualify for kill credit.');local total=A.db.owners[A.owner].total
   observe(uid,'Gnome',true,1000,current,false)
   DEFAULT_CHAT_FRAME.AddMessage=function(self,s)capture(self,s);death(uid,current,true);A.Death(uid,current,true);A.GroupDeath(uid,current,true)end
   death(uid,current,true);DEFAULT_CHAT_FRAME.AddMessage=capture
   assert(count('You did not qualify for kill credit.')==n+1 and A.db.owners[A.owner].total==total,'reentrant nonqualification does not award or repeat')
   local credited='Player-reentrant-success-'..mode;local k=count('Gnome kill recorded');n=count('You did not qualify for kill credit.')
   observe(credited,'Gnome',true,1000,current,false)
   if mode=='group'then A.GroupDamage(credited,20,0,'Player-me',current)else A.Damage(credited,20,0,true,current)end
   DEFAULT_CHAT_FRAME.AddMessage=function(self,s)capture(self,s);death(credited,current,true);A.Death(credited,current,true);A.GroupDeath(credited,current,true)end
   assert(death(credited,current,true));DEFAULT_CHAT_FRAME.AddMessage=capture
   assert(count('Gnome kill recorded')==k+1 and count('You did not qualify for kill credit.')==n,'reentrant success is one positive and no negative')
   for _,blocked in ipairs({'instance','guild','unverified','notplayer','friendly','unknownlife','unconfirmed'})do
    local id='Player-skip-'..mode..'-'..blocked
    if blocked=='notplayer'then id='Creature-skip'end
    observe(id,'Gnome',blocked~='friendly',1000,current,blocked=='unknownlife'and nil or false)
    if blocked=='unknownlife'then local r=mode=='group'and A.groupTargets[id]or A.encounters[id];if r then r.living=nil end end
    local native=IsInInstance;local member=A.members[A.owner]
    if blocked=='instance'then IsInInstance=function()return true,'pvp'end
    elseif blocked=='guild'then A.members[A.owner]=nil
    elseif blocked=='unverified'then A.guildUnverified=true end
    local all=#chat;death(id,current,blocked~='unconfirmed');assert(#chat==all,'no negative in '..blocked)
    IsInInstance=native;A.members[A.owner]=member;A.guildUnverified=false
   end
  end
  -- Actual scans: a living/removal event is not a death; readable corpse is.
  local aura=C_UnitAuras.GetAuraDataByIndex;C_UnitAuras.GetAuraDataByIndex=function()return nil end
  units.nameplateNotice={guid='Player-scan-missed',name='Uncredited',race='Gnome',faction='Alliance',hp=1000,enemy=true}
  local n=count('You did not qualify for kill credit.');A.Scan('nameplateNotice',nil,true)
  event('NAME_PLATE_UNIT_REMOVED','nameplateNotice');assert(count('You did not qualify for kill credit.')==n)
  units.nameplateNotice.dead=true;A.Scan('nameplateNotice',nil,true);A.Scan('nameplateNotice',nil,true)
  assert(count('You did not qualify for kill credit.')==n+1,'actual corpse scan reports once')
  units.nameplateNotice=nil;C_UnitAuras.GetAuraDataByIndex=aura
  combat(true);local id='Player-combat-notice';A.GroupObserve(id,'Gnome',true,1000,current,false);A.GroupCC(id,770,'Player-me',current,true)
  local k=count('Gnome kill recorded');A.GroupDeath(id,current,true);assert(count('Gnome kill recorded')==k+1,'local chat works in combat without network sends');combat(false)
  print('PASS real corpse scans, reentrancy, guild/location/life gates and combat-local confirmation')
  local n=count('You did not qualify for kill credit.');local id='Player-party-missed'
  A.GroupObserve(id,'Gnome',true,1000,current,false);event('PARTY_KILL','Player-friend',id)
  assert(count('You did not qualify for kill credit.')==n+1,'native confirmed kill event reports nonqualification without guessing disappearance')
  local id2='Player-collector-missed';A.GroupObserve(id2,'Gnome',true,1000,current,false)
  A.GroupCombat({[2]='UNIT_DIED',[8]=id2},current)
  assert(count('You did not qualify for kill credit.')==n+2,'confirmed death event reports nonqualification')
  for _,group in ipairs({false,true})do
   local observe=group and A.GroupObserve or A.Observe;local death=group and A.GroupDeath or A.Death
   local stale='Player-stale-notice-'..tostring(group);observe(stale,'Gnome',true,1000,current,false)
   local all=#chat;death(stale,current+A.WINDOW+1,true);assert(#chat==all,'expired living proof cannot correlate a new negative life notice')
  end
  local stale='Player-stale-observation';A.GroupObserve(stale,'Gnome',true,1000,current,false)
  local all=#chat;A.GroupObserve(stale,'Gnome',false,1000,current+A.WINDOW+1,true)
  assert(#chat==all,'late corpse refresh cannot renew expired living-life proof')
  print('PASS native death-event confirmation and conservative expired-life suppression')
  -- Restricted CLEU tuples must preserve uncertainty before being discarded.
  for _,mode in ipairs({'group','personal'})do
   local go,gc,gd,gcc=A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC
   if mode=='personal'then A.GroupObserve=nil;A.GroupCombat=nil;A.GroupDeath=nil;A.GroupCC=nil end
   local provider=C_UnitAuras.GetAuraDataByIndex;C_UnitAuras.GetAuraDataByIndex=function()return nil end
   local native=CombatLogGetCurrentEventInfo;local secret={};local old=issecretvalue
   issecretvalue=function(v)return rawequal(v,secret)end
   for _,field in ipairs({'amount','source','target','missing','throw'})do
    local id='Player-log-unknown-'..mode..'-'..field
    units.nameplateNotice={guid=id,name='Opaque',race='Gnome',faction='Alliance',hp=1000,enemy=true}
    A.Scan('nameplateNotice',nil,true)
    local v={[2]='SWING_DAMAGE',[4]='Player-me',[8]=id,[12]=20,[13]=0}
    if field=='amount'then v[12]=secret elseif field=='source'then v[4]=secret elseif field=='target'then v[8]=secret elseif field=='missing'then v[8]=nil;v[12]=secret end
    CombatLogGetCurrentEventInfo=function()if field=='throw'then error('restricted tuple')end;return unpack(v,1,13)end
    local n=#chat;local total=A.db.owners[A.owner].total
    A.ReadCombatLog();event('PARTY_KILL','Player-me',id)
    assert(#chat==n,'restricted '..field..' tuple cannot assert nonqualification ('..mode..')')
    assert(A.db.owners[A.owner].total==total,'restricted tuple cannot invent participation')
   end
   CombatLogGetCurrentEventInfo=native;issecretvalue=old;C_UnitAuras.GetAuraDataByIndex=provider;units.nameplateNotice=nil
   A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC=go,gc,gd,gcc
  end
  print('PASS restricted CLEU amount/source/target/unidentified/error uncertainty in both paths')
  for _,mode in ipairs({'group','personal'})do
   local go,gc,gd,gcc=A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC
   if mode=='personal'then A.GroupObserve=nil;A.GroupCombat=nil;A.GroupDeath=nil;A.GroupCC=nil end
   local provider=C_UnitAuras.GetAuraDataByIndex;local old=issecretvalue;local secret={}
   issecretvalue=function(v)return rawequal(v,secret)end
   for _,case in ipairs({'secret','missing','throw','cap','readable','positive'})do
    local id='Player-corpse-evidence-'..mode..'-'..case
    units.nameplateNotice={guid=id,name='Corpse',race='Gnome',faction='Alliance',hp=1000,enemy=true}
    C_UnitAuras.GetAuraDataByIndex=function()return nil end;A.Scan('nameplateNotice',nil,true)
    if case=='positive'then if mode=='group'then A.GroupDamage(id,20,0,'Player-me',clock())else A.Damage(id,20,0,true,clock())end end
    local record=mode=='group'and A.groupTargets[id]or A.encounters[id]
    local keys={sentinel=clock()};A.auras[id]=keys
    local calls=0
    C_UnitAuras.GetAuraDataByIndex=function(_,i)
     calls=calls+1
     if case=='throw'then error('corpse aura unavailable')end
     if case=='secret'or case=='positive'then return secret end
     if case=='cap'or i==1 then return {spellId=770,sourceUnit='player',auraInstanceID=2,expirationTime=clock()+20,isHarmful=true}end
    end
    if case=='missing'then C_UnitAuras.GetAuraDataByIndex=nil end
    local n=count('You did not qualify for kill credit.');local k=count('Gnome kill recorded')
    units.nameplateNotice.dead=true;A.Scan('nameplateNotice',nil,true)
    assert(count('You did not qualify for kill credit.')==n+(case=='readable'and 1 or 0),'corpse completeness before finalization: '..mode..' '..case)
    assert(count('Gnome kill recorded')==k+(case=='positive'and 1 or 0),'corpse auras cannot grant new credit: '..mode..' '..case)
    assert(not record.cc and(not record.actors or not record.actors['Player-me']or not record.actors['Player-me'].cc),'corpse inspection cannot create participation')
    assert(keys.sentinel and not keys['770:Player-me:2:'..tostring(clock()+20)],'corpse inspection cannot mutate aura dedup')
    local done=calls;A.Scan('nameplateNotice',nil,true);assert(calls==done,'consumed corpse must not be rescanned')
   end
   issecretvalue=old;C_UnitAuras.GetAuraDataByIndex=provider;units.nameplateNotice=nil
   A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC=go,gc,gd,gcc
  end
  print('PASS corpse completeness, pure inspection, positive credit and bounded repeats in both paths')
  for _,mode in ipairs({'group','personal'})do
   local go,gc,gd,gcc=A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC
   if mode=='personal'then A.GroupObserve=nil;A.GroupCombat=nil;A.GroupDeath=nil;A.GroupCC=nil end
   local observe=mode=='group'and A.GroupObserve or A.Observe
   local death=mode=='group'and A.GroupDeath or A.Death
   local function hit(id,t)if mode=='group'then A.GroupDamage(id,20,0,'Player-me',t)else A.Damage(id,20,0,true,t)end end
   local t=clock();local oldTarget=units.target;local provider=C_UnitAuras.GetAuraDataByIndex
   C_UnitAuras.GetAuraDataByIndex=function()return nil end
   for _,path in ipairs({'direct','native','legacy'})do for _,amount in ipairs({0,20})do
    local id='Player-replay-'..mode..'-'..path..'-'..amount
    observe(id,'Gnome',true,1000,t,false);hit(id,t);assert(death(id,t,true))
    observe(id,'Gnome',true,1000,t+1,false);if amount>0 then hit(id,t+1)end
    units.target={guid=id,name='Rearmed',race='Gnome',faction='Alliance',hp=1000,enemy=true}
    local records=mode=='group'and A.groupTargets or A.encounters;local living=records[id];local n=#chat;local total=A.db.owners[A.owner].total
    local function callback(at)
     clock(at)
     if path=='direct'then death(id,at,nil,true)
     elseif path=='native'then event('PARTY_KILL','Player-me',id)
     else local native=CombatLogGetCurrentEventInfo;CombatLogGetCurrentEventInfo=function()return 0,'UNIT_DIED',false,nil,nil,nil,nil,id end;A.ReadCombatLog();CombatLogGetCurrentEventInfo=native end
    end
    for _,delay in ipairs({4,30})do callback(t+delay);assert(records[id]==living and not A.db.dead[id],'old GUID replay must retain living life at +'..delay..' '..mode..' '..path);assert(#chat==n and A.db.owners[A.owner].total==total,'old GUID replay cannot award or print negative')end
    units.target.dead=true
    if path=='direct'then death(id,t+31,true)else callback(t+31)end
    local expected=amount>0 and 1 or 0
    assert(A.db.owners[A.owner].total==total+expected,'event with readable new corpse credits once '..mode..' '..path)
    assert(#chat==n+1,'actual new corpse emits exactly one positive or negative notice')
    callback(t+32);assert(A.db.owners[A.owner].total==total+expected and #chat==n+1)
   end end
   for _,delay in ipairs({1,2})do
    local id='Player-fast-life-'..mode..'-'..delay
    observe(id,'Gnome',true,1000,t,false);hit(id,t);assert(death(id,t,true))
    observe(id,'Gnome',true,1000,t+1,false);hit(id,t+1);assert(death(id,t+delay,true),'actual new corpse needs no arbitrary timeout')
   end
   units.target=oldTarget;C_UnitAuras.GetAuraDataByIndex=provider;clock(t)
   A.GroupObserve,A.GroupCombat,A.GroupDeath,A.GroupCC=go,gc,gd,gcc
  end
  print('PASS +4/+30 replays retain living life; new corpses credit once, native/legacy and fast lives')
  -- Instrument the real runtime; duplicate aliases and health churn stay cheap.
  local savedTarget,savedFocus,savedMouse=units.target,units.focus,units.mouseover
  local savedPlates=A.plates;A.plates={}
  local provider=C_UnitAuras.GetAuraDataByIndex;local calls=0
  C_UnitAuras.GetAuraDataByIndex=function(_,i)calls=calls+1;if i==1 then return {spellId=770,sourceUnit='player',auraInstanceID=9,isHarmful=true}end end
  units.target={guid='Player-scan-benchmark',name='Benchmark',race='Gnome',faction='Alliance',hp=1000,enemy=true}
  units.focus=units.target;units.mouseover=units.target
  A.ScanVisible();assert(calls==2,'duplicate alias benchmark must stay at 2 aura calls rather than 6')
  calls=0;for i=1,100 do event('UNIT_HEALTH','target')end
  assert(calls==0,'100 same-clock health events must cause zero aura calls')
  print('PASS benchmark: duplicate aliases 6 -> 2 aura calls; 100 health events -> '..calls)
  units.target,units.focus,units.mouseover=savedTarget,savedFocus,savedMouse;A.plates=savedPlates;C_UnitAuras.GetAuraDataByIndex=provider
 end
end
