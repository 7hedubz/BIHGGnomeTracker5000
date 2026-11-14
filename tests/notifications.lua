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
  -- Supersedes pre-1.9 percentage/nonqualification notifications. The actual
  -- local honor callback is authoritative; aura completeness is not own HK.
  -- Progress/rejection evidence belongs in manual debug, even with a saved
  -- legacy verbose flag. Only committed credit gets an automatic notice.
  for _,setting in ipairs({'unset',true,false})do
   A.db.options.killVerbose=setting;if setting=='unset'then A.db.options.killVerbose=nil end
   for _,reason in ipairs({'ambiguous HK','native death candidate','honor confirmation unavailable','HK unconfirmed'})do
    clock(clock()+3);local before=#chat
    A.KillOutcome(reason,clock(),'Player-quiet-'..tostring(setting)..reason)
    assert(#chat==before,'unconfirmed kill diagnostics must not print automatically')
    assert(table.concat(A.KillDebugLines(),' '):find(reason,1,true),'quiet diagnostic remains available on request')
   end
  end
  A.db.options.killVerbose=false;SlashCmdList.BIHGGKT('killverbose')
  assert(A.db.options.killVerbose==false,'legacy command must not re-enable automatic diagnostic chat')
  A.db.options.killVerbose=true
  COMBATLOG_HONORGAIN_NO_RANK='You killed %s (Honor: %d)'
  local function kills()return A.db.owners[A.owner].total end
  local function victim(id,name,source)
   clock(clock()+10)
   units.target={guid=id,name=name,race='Gnome',faction='Alliance',hp=1000,enemy=true}
   C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='target'and i==1 and source then return{spellId=702,sourceUnit=source,isHarmful=true}end end
   event('PLAYER_TARGET_CHANGED')
  end
  local function corpse()units.target.dead=true;event('UNIT_HEALTH','target')end
  local function honor(name)event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed '..name..' (Honor: 4)')end
  victim('Player-notice','Notice','player');local n=kills();local k=count('Gnome kill recorded')
  corpse();assert(kills()==n and count('Gnome kill recorded')==k,'debuff + corpse is pending, not personal credit')
  local negatives=count('You did not qualify for kill credit.')
  honor('Notice');assert(kills()==n+1 and count('Gnome kill recorded')==k+1,'own native named HK confirms locally once')
  honor('Notice');event('PARTY_KILL','Player-me','Player-notice')
  assert(kills()==n+1 and count('Gnome kill recorded')==k+1,'honor/corpse/PK replay is silent credit-wise')
  assert(count('You did not qualify for kill credit.')==negatives,'pending native death cannot assert old participation nonqualification')
  local all=#chat
  A.RebuildOwnGuildTotals(clock());A.Changed()
  assert(#chat==all,'history/rebuild is not a personal observation')
  print('PASS native own HK -> one local confirmation; pending and history never claim old nonqualification')
  local capture=DEFAULT_CHAT_FRAME.AddMessage
  victim('Player-reentrant-hk','Reentrant');corpse();n=kills();k=count('Gnome kill recorded')
  DEFAULT_CHAT_FRAME.AddMessage=function(self,text)capture(self,text);honor('Reentrant');event('PARTY_KILL','Player-me','Player-reentrant-hk')end
  honor('Reentrant');DEFAULT_CHAT_FRAME.AddMessage=capture
  assert(kills()==n+1 and count('Gnome kill recorded')==k+1,'chat reentry cannot duplicate a reserved life')
  victim('Player-chat-failure','ChatFailure');corpse();n=kills()
  DEFAULT_CHAT_FRAME.AddMessage=function()error('injected local chat failure')end
  honor('ChatFailure');DEFAULT_CHAT_FRAME.AddMessage=capture
  assert(kills()==n+1 and not A.lastError,'local chat failure cannot undo committed credit')
  print('PASS native honor reservations and local chat errors do not duplicate or roll back credit')
  victim('Player-late-notice','Again');corpse();honor('Again');n=kills()
  clock(clock()+1);units.target.dead=false;event('UNIT_FLAGS','target')
  for _,delay in ipairs({4,30})do
   clock(clock()+delay);event('PARTY_KILL','Player-me','Player-late-notice')
   assert(kills()==n and A.groupTargets['Player-late-notice']and not A.db.dead['Player-late-notice'],'late prior-life GUID callback cannot consume new living life')
  end
  corpse();honor('Again');assert(kills()==n+1,'readable actual second corpse and local HK counts new life once')
  print('PASS +4/+30 prior-life callbacks rejected; fresh second corpse and HK counts')
  for _,blocked in ipairs({'guild','unverified','instance'})do
   victim('Player-gated-'..blocked,'Gated'..blocked);corpse();n=kills()
   local key,unverified,instance=A.guildKey,A.guildUnverified,IsInInstance
   if blocked=='guild'then A.guildKey=nil elseif blocked=='unverified'then A.guildUnverified=true else IsInInstance=function()return true,'pvp'end end
   honor('Gated'..blocked);assert(kills()==n,'HK cannot bypass '..blocked..' authority')
   A.guildKey=key;A.guildUnverified=unverified;IsInInstance=instance
  end
  print('PASS local confirmed HK still requires guild and open-world eligibility')
  local savedTarget,savedFocus,savedMouse=units.target,units.focus,units.mouseover
  local savedPlates=A.plates;A.plates={};local calls=0
  C_UnitAuras.GetAuraDataByIndex=function(u,i)calls=calls+1;if u=='target'and i==1 then return{spellId=770,sourceUnit='player',auraInstanceID=9,isHarmful=true}end end
  units.target={guid='Player-scan-benchmark',name='Benchmark',race='Gnome',faction='Alliance',hp=1000,enemy=true}
  units.focus=units.target;units.mouseover=units.target
  A.ScanVisible();assert(calls==3,'duplicate aliases retain 2 hostile aura calls plus 1 incoming sentinel, not 6 hostile calls')
  calls=0;for i=1,100 do event('UNIT_HEALTH','target')end
  assert(calls==0,'100 same-clock health events cause zero aura calls')
  units.target,units.focus,units.mouseover=savedTarget,savedFocus,savedMouse;A.plates=savedPlates
  print('PASS benchmark: duplicate aliases 6 -> 2 aura calls; 100 health events -> 0')
 end
end
