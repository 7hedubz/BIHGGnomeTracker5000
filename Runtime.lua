local addon,A=...
function A.Secret(v) return issecretvalue and issecretvalue(v) or false end
function A.Safe(fn,...)
 if type(fn)~='function' then return nil end
 local ok,v=pcall(fn,...); if not ok or A.Secret(v) then return nil end; return v
end
local function now()return A.Safe(GetServerTime) or time() end
local function readable(v)if not A.Secret(v) then return v end end
function A.DisplayName(name)
 if A.Secret(name) or type(name)~='string' or name=='' then return 'Unknown' end
 return name:match('^([^-]+)') or name
end
function A.Name(name)
 if type(name)~='string' or A.Secret(name) or name=='' then return nil end
 if not name:find('-',1,true) then name=name..'-'..(A.Safe(GetNormalizedRealmName) or (A.Safe(GetRealmName) or ''):gsub('%s','')) end
 return name
end
function A.Race(g)
 if A.Secret(g) or type(g)~='string' then return nil end
 local saved=A.db and A.db.seen and A.db.seen[g]
 if saved and saved.race then return saved.race end
 if GetPlayerInfoByGUID then
  local ok,_,_,_,race=pcall(GetPlayerInfoByGUID,g)
  if ok and not A.Secret(race) then return race end
 end
end
local function own(unit)
 return unit and (A.Safe(UnitIsUnit,unit,'player')==true or A.Safe(UnitIsUnit,unit,'pet')==true)
end
function A.Scan(unit)
 if not A.db or not A.Safe(UnitExists,unit) or not A.Safe(UnitIsPlayer,unit) then return end
 local g=A.Safe(UnitGUID,unit); if type(g)~='string' or not g:match('^Player%-') then return end
 local ok,_,race=pcall(UnitRace,unit); if not ok or A.Secret(race) then race=nil end
 if not race then race=A.Race(g)end
 local faction=A.Safe(UnitFactionGroup,unit)
 local name,realm
 if UnitName then local good,n,r=pcall(UnitName,unit); if good then name=readable(n);realm=readable(r) end end
 if type(name)=='string' then
  if type(realm)=='string' and realm~='' then name=name..'-'..realm end
  name=A.Name(name)
 end
 local t=now()
 local dead=A.Safe(UnitIsDeadOrGhost,unit);local selfGUID=A.Safe(UnitGUID,'player')
 if A.NearbyNotice and g~=selfGUID then
  -- Explicitly invisible units must not refresh the list; otherwise use the
  -- readable unit exposure, like Spy, without claiming an exact distance.
  local visible=A.Safe(UnitIsVisible,unit)~=false
  A.NearbyNotice(g,name,race,faction,t,dead,visible,A.Safe(UnitLevel,unit),A.Safe(UnitClass,unit))
 end
 if faction=='Alliance' and g~=selfGUID and A.members and A.members[A.owner]then
  local fresh=A.Encounter(g,name,race,faction,t)
  if fresh then
   A.QueueShare(true)
   if A.db.options.alerts~=false and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffb347BIHG: Gnome encountered:|r '..A.DisplayName(name)) end
  end
 end
 local hostile=A.Safe(UnitCanAttack,'player',unit)
 local hp=A.Safe(UnitHealthMax,unit)
 if A.GroupObserve then A.GroupObserve(g,race,hostile,hp,t,dead)else A.Observe(g,race,hostile,hp,t,dead)end
 -- Corpses and mind-controlled targets may no longer be attackable. Preserve
 -- hostility established while alive; never infer hostile credit from a corpse.
 local encounter=A.GroupObserve and A.groupTargets[g]or A.encounters[g]
 if race~='Gnome' or not (hostile or (encounter and encounter.hostile)) then return end
 if dead then if A.GroupDeath then A.GroupDeath(g,t)else A.Death(g,t)end;return end
 if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
  for i=1,80 do
   local a=A.Safe(C_UnitAuras.GetAuraDataByIndex,unit,i,'HARMFUL')
   if not a then break end
   if type(a)=='table' and not (issecrettable and issecrettable(a)) then
    local id=readable(a.spellId); local source=readable(a.sourceUnit)
    local instance=readable(a.auraInstanceID); local expires=readable(a.expirationTime)
    local sourceGUID=type(source)=='string'and A.Safe(UnitGUID,source)
    local eligible=A.GroupCC and sourceGUID and A.groupSources[sourceGUID]or(not A.GroupCC and own(source))
    local helpful=a.isHelpful;local harmful=a.isHarmful
    local explicitBuff=(not A.Secret(helpful)and helpful==true)or(not A.Secret(harmful)and harmful==false)
    if type(id)=='number'and id>0 and not explicitBuff and type(source)=='string' and eligible then
     -- Re-observing the same aura is not another successful application.
     local key=tostring(id)..':'..tostring(sourceGUID or '')..':'..tostring(instance or '')..':'..tostring(expires or '')
     A.auras[g]=A.auras[g] or {}
     if not A.auras[g][key]then
      local accepted;if A.GroupCC then accepted=A.GroupCC(g,id,sourceGUID,t,true)else accepted=A.CC(g,id,true,t,true)end
      if accepted then A.auras[g][key]=t end
     end
     A.coverage.cc=true
    end
   end
  end
 end
end
function A.ScanVisible()
 if A.RefreshGroupActors then A.RefreshGroupActors()end
 for _,u in ipairs({'target','focus','mouseover'}) do A.Scan(u) end
 for u in pairs(A.plates) do if A.Safe(UnitExists,u) then A.Scan(u) else A.plates[u]=nil end end
 for _,u in ipairs(A.groupUnits or {})do A.Scan(u..'target')end
 local t=now()
 for g,e in pairs(A.encounters) do if t-(e.last or e.seen or 0)>A.WINDOW then A.encounters[g]=nil end end
 for g,e in pairs(A.groupTargets or {})do if t-e.seen>A.WINDOW then A.groupTargets[g]=nil end end
 for g,keys in pairs(A.auras) do
  for k,stamp in pairs(keys) do if t-stamp>600 then keys[k]=nil end end
  if not next(keys) then A.auras[g]=nil end
 end
end
function A.GuildMembershipCache()
 if not A.guildKey then return end
 local r=A.account or A.db;r.guildMembership=r.guildMembership or {}
 local c=r.guildMembership[A.guildKey]
 if not c then
  c={members={},guids={}};r.guildMembership[A.guildKey]=c
  -- Old versions deleted observed rows on partial rosters. The witnessed
  -- ledger still proves their last-known membership and reconstructs scores.
  local peers=A.PeerRecords()
  for n,p in pairs(peers)do c.members[n]=true;c.guids[n]=p.characterGUID end
  local store=(r.guildObservations or {})[A.guildKey]
  for _,e in pairs(store and store.events or {})do
   local name=A.CanonicalCharacterName and A.CanonicalCharacterName(e.name,e.actor)or e.name
   c.members[name]=true;c.guids[name]=e.actor
   if not peers[name]and not(A.account and A.account.characters[name])then peers[name]={total=0,deaths=0,days={},deathDays={},observerOnly=true,characterGUID=e.actor}end
  end
 end
 return c
end
function A.RememberGuildMember(name,guid)
 local c=A.GuildMembershipCache();if not c then return end
 c.members[name]=true;if type(guid)=='string'then c.guids[name]=guid end
 A.members[name]=true
end
function A.ForgetGuildMember(name,guid)
 local c=A.GuildMembershipCache();if not c then return end
 for n in pairs(c.members)do if n==name or(guid and c.guids[n]==guid)then
  c.members[n]=false;A.members[n]=nil
  if A.CanonicalCharacterName then A.members[A.CanonicalCharacterName(n,c.guids[n])]=nil end
 end end
 A.members[name]=nil
end
function A.Roster(confirmed)
 local guild=A.Safe(GetGuildInfo,'player');local old=A.guildKey
 local realm=A.Safe(GetNormalizedRealmName);local last=A.db.lastGuild
 A.guildUnverified=false
 if type(guild)=='string'and guild~=''and type(realm)=='string'and realm~=''then
  A.guildName=guild;A.guildKey=guild..'-'..realm;A.db.lastGuild={name=guild,key=A.guildKey}
 elseif A.Safe(IsInGuild)==true and last and type(last.name)=='string'and type(last.key)=='string'and(guild==nil or guild==last.name)then
  A.guildName=last.name;A.guildKey=last.key;A.guildUnverified=true;confirmed=false
 else A.guildName=nil;A.guildKey=nil end
 A.members={};A.rosterSeen={}
 if old~=A.guildKey then A.rosterCandidate=nil;A.rosterTargetNames={};A.outgoing=nil;A.request=true;A.rx={};A.queries={};A.lastRequest=nil;A.syncStatus=nil;A.QueueShare(true)end
 if A.guildKey then
  local c=A.GuildMembershipCache();local count=not A.guildUnverified and A.Safe(GetNumGuildMembers,true)or 0
  if type(count)~='number'or count<0 then count=0 end
  local complete=count>0 and count<=1000 and count==math.floor(count)and A.Safe(GetGuildRosterShowOffline)==true
  local signature={};local rawNames={};local seenGUIDs={}
  for i=1,math.min(math.floor(count),1000)do
   local v=type(GetGuildRosterInfo)=='function'and{pcall(GetGuildRosterInfo,i)}or{}
   local name=v[1]and not A.Secret(v[2])and A.Name(v[2]);local guid=v[1]and not A.Secret(v[18])and v[18]or nil
   if type(guid)~='string'or not guid:match('^Player%-[%w%-]+$')then guid=nil;complete=false end
   if not name or rawNames[name]or(guid and seenGUIDs[guid])then complete=false else
    rawNames[name]=true;if guid then seenGUIDs[guid]=true end
    signature[#signature+1]=name..':'..(type(guid)=='string'and guid or'')
    local targetName=name;if A.ObserveGuildCharacter then name=A.ObserveGuildCharacter(name,guid,now())end
    A.rosterTargetNames=A.rosterTargetNames or {};A.rosterTargetNames[name]=targetName
    A.rosterSeen[name]=true;A.RememberGuildMember(name,guid)
   end
  end
  complete=complete and A.rosterSeen[A.owner]==true
  local accepted=false
  if confirmed and complete then
   table.sort(signature);local key=table.concat(signature,'\031');local pending=A.rosterCandidate
   if pending and pending.key==key and now()-pending.time>=5 then
    for n in pairs(c.members)do local canonical=A.CanonicalCharacterName and A.CanonicalCharacterName(n,c.guids[n])or n
     if not A.rosterSeen[canonical]then c.members[n]=false end
    end
    accepted=true
   elseif not pending or pending.key~=key then
    A.rosterCandidate={key=key,time=now()}
    if C_Timer and C_Timer.After then local expected=A.guildKey;C_Timer.After(5,function()
     if A.guildKey==expected and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)end
    end)end
   end
  else A.rosterCandidate=nil end
  A.rosterStatus=A.guildUnverified and'cached history: guild identity pending'or(accepted and'guild membership confirmed'or'last-verified guild membership (roster pending/filtered)')
  A.members={}
  for n,present in pairs(c.members)do if present then local canonical=A.CanonicalCharacterName and A.CanonicalCharacterName(n,c.guids[n])or n;A.members[canonical]=true end end
  A.RememberGuildMember(A.owner,A.Safe(UnitGUID,'player'))
 else A.rosterStatus='guild information unavailable'end
 if A.RefreshGroupActors then A.RefreshGroupActors()end
 if A.ReconcileGuildMembership then A.ReconcileGuildMembership()end
 -- Membership controls presentation only: never delete persisted peer history.
 if A.RefreshGroupActors then if A.CarryOwnGuildHistory then A.CarryOwnGuildHistory(now())end;A.RebuildOwnGuildTotals(now())end
 if A.RefreshUI then A.RefreshUI()end
end
function A.ReadCombatLog()
 if not CombatLogGetCurrentEventInfo then return end
 local function pack(...)return {n=select('#',...),...} end
 local result=pack(pcall(CombatLogGetCurrentEventInfo))
 if not result[1] then A.coverage.blocked=true; return end
 local v={}
 -- Combat logs contain nil source fields on deaths. Never use #/table.remove
 -- on this sparse tuple: Lua may stop at an interior nil and shift only a prefix.
 for i=2,result.n do
  local x=result[i]
  if A.Secret(x) then A.coverage.blocked=true; return end
  v[i-1]=x
 end
 local event,src,dst=v[2],v[4],v[8]
 if type(event)~='string' then return end
 A.coverage.log=true
 local t=now()
 if(event=='UNIT_DIED'or event=='UNIT_DESTROYED')and A.ForgetNearby then A.ForgetNearby(dst)end
 if A.GroupCombat then A.GroupCombat(v,t);return end
 if event=='UNIT_DIED' or event=='UNIT_DESTROYED' then A.Death(dst,t);return end
 local mine=src and (src==A.Safe(UnitGUID,'player') or src==A.Safe(UnitGUID,'pet'))
 if not mine then
  if dst==A.Safe(UnitGUID,'player') then
   local index=event=='SWING_DAMAGE' and 13 or ((event=='SPELL_DAMAGE' or event=='SPELL_PERIODIC_DAMAGE' or event=='RANGE_DAMAGE') and 16)
   if index and type(v[index])=='number' and v[index]>=0 then A.killingBlow={guid=src,time=t} end
  end
  return
 end
 if event=='SWING_DAMAGE' then A.Damage(dst,v[12],v[13],true,t)
 elseif event=='SPELL_DAMAGE' or event=='SPELL_PERIODIC_DAMAGE' or event=='RANGE_DAMAGE' or event=='DAMAGE_SHIELD' then A.Damage(dst,v[15],v[16],true,t)
 elseif(event=='SPELL_AURA_APPLIED'or event=='SPELL_AURA_REFRESH'or event=='SPELL_AURA_APPLIED_DOSE')and v[15]=='DEBUFF'then A.CC(dst,v[12],true,t,true)end
end
function A.Recap()
 if not A.pendingDeath then return end
 local pending=A.pendingDeath; local t=now()
 if t-pending.time>8 then A.pendingDeath=nil;return end
 local recap=C_DeathRecap
 if recap and recap.GetRecapEvents then
  local link=A.Safe(recap.GetRecapLink)
  local id=type(link)=='string' and link:match('death:(%d+)')
  local events=A.Safe(recap.GetRecapEvents)
  if type(events)=='table' and not (issecrettable and issecrettable(events)) then
   local e=events[1]
   if type(e)=='table' and not (issecrettable and issecrettable(e)) then
    local stamp,hide,g=readable(e.timestamp),readable(e.hideCaster),readable(e.sourceGUID)
    -- Do not attribute stale/untimed recaps or hidden casters.
    if id and type(stamp)=='number' and math.abs(stamp-pending.time)<=10 and hide~=true and type(g)=='string' and g:match('^Player%-') then
     A.coverage.recap=true
     A.PlayerDeath('recap:'..id..':'..stamp,A.Race(g),pending.time,g); A.pendingDeath=nil; return
    end
   end
  end
 end
 local k=A.killingBlow
 if k and math.abs(k.time-pending.time)<=2 then
  A.PlayerDeath('combat:'..pending.time,A.Race(k.guid),pending.time,k.guid);A.pendingDeath=nil
 end
end
function A.Changed()
 if A.account then A.SnapshotAccount(now()) end
 A.QueueShare(false)
 if A.RefreshUI then A.RefreshUI() end
end
local frame=CreateFrame('Frame'); A.eventFrame=frame
local function login()
 if A.db then return end
 local name=A.Safe(UnitName,'player'); if not name then return end
 BIHGGKTDB=BIHGGKTDB or {}; A.Init(BIHGGKTDB,A.Name(name),now())
 BIHGGKTAccountDB=BIHGGKTAccountDB or {}
 local identity=A.Safe(UnitGUID,'player') or A.owner:gsub('[^%w_%-]',''):sub(1,50)
 A.InitAccount(BIHGGKTAccountDB,identity..'-'..now(),now())
 if A.BindLocalCharacter then A.BindLocalCharacter(A.Safe(UnitGUID,'player'),now())end
 if A.InitGroupTracking then A.InitGroupTracking(now())end
 if A.InitNearby then A.InitNearby()end
 A.plates={};A.auras={};A.coverage={};A.syncStatus='Waiting for guild roster'
 if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,A.PREFIX) end
 A.Roster();A.QueueShare(true);A.request=true
 if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
 if A.CreateUI then A.CreateUI() end
 if A.CreateNearbyUI then A.CreateNearbyUI()end
end
local function handler(_,event,...)
 local arg1,arg2,arg3,arg4=...
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then login() end
 if event=='ADDON_ACTION_BLOCKED'or event=='ADDON_ACTION_FORBIDDEN'then
  if not A.Secret(arg1)and arg1=='BIHGGnomeKillTracker5000'then
   if A.RecordReportRestriction then A.RecordReportRestriction(event,arg1,arg2,now())
   elseif not A.Secret(arg2)and type(arg2)=='string'then A.pendingReportRestriction={event=event,func=arg2,at=now()}end
  end
  return
 end
 if not A.db then return end
 if event=='PLAYER_ENTERING_WORLD' then if A.ClearNearby then A.ClearNearby()end;A.Roster();A.QueueShare(true);A.ScanVisible()
 elseif event=='ZONE_CHANGED_NEW_AREA'then if A.ClearNearby then A.ClearNearby()end;A.ScanVisible()
 elseif event=='GUILD_ROSTER_UPDATE' or event=='PLAYER_GUILD_UPDATE' then A.Roster(event=='GUILD_ROSTER_UPDATE')
 elseif event=='GROUP_ROSTER_UPDATE'or event=='UNIT_PET'then if A.RefreshGroupActors then A.RefreshGroupActors()end
 elseif event=='NAME_PLATE_UNIT_ADDED' then if not A.Secret(arg1) and type(arg1)=='string' then A.plates[arg1]=true;A.Scan(arg1) end
 elseif event=='NAME_PLATE_UNIT_REMOVED' then if not A.Secret(arg1) then A.plates[arg1]=nil end
 elseif event=='UNIT_AURA' or event=='UNIT_HEALTH' or event=='UNIT_FLAGS' then if not A.Secret(arg1) and type(arg1)=='string' then A.Scan(arg1) end
 elseif event=='PLAYER_TARGET_CHANGED' then A.Scan('target')
 elseif event=='UPDATE_MOUSEOVER_UNIT' then A.Scan('mouseover')
 elseif event=='PLAYER_FOCUS_CHANGED' then A.Scan('focus')
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then A.ReadCombatLog()
 elseif event=='PARTY_KILL' then if not A.Secret(arg2)then if A.ForgetNearby then A.ForgetNearby(arg2)end;if A.GroupDeath then A.GroupDeath(arg2,now())else A.Death(arg2,now())end end
 elseif event=='PLAYER_DEAD' then
  if A.deathActive then return end
  A.deathActive=true;A.pendingDeath={time=now()}
  A.Recap(); if C_Timer then C_Timer.After(0.5,A.Recap);C_Timer.After(2,A.Recap) end
 elseif event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then A.killingBlow=nil;A.deathActive=false
 elseif event=='CHAT_MSG_ADDON' then
  if A.Secret(arg1) or A.Secret(arg2) or A.Secret(arg3) or A.Secret(arg4) then return end
  if arg1==A.PREFIX then A.Receive(arg2,arg3,A.Name(arg4),now()) end
 end
end
frame:SetScript('OnEvent',function(...)
 local ok,err=pcall(handler,...)
 if not ok then A.lastError=tostring(err); if not A.errorShown and DEFAULT_CHAT_FRAME then A.errorShown=true;DEFAULT_CHAT_FRAME:AddMessage('|cffff5555BIHG error:|r '..A.lastError..' (/gkt debug)') end end
end)
-- Forever forbids native CLEU registration; pcall does not prevent its
-- ADDON_ACTION_FORBIDDEN event. Keep the parser for explicitly supplied data.
for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','ZONE_CHANGED_NEW_AREA','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE','GROUP_ROSTER_UPDATE','UNIT_PET','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_AURA','UNIT_HEALTH','UNIT_FLAGS','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED','PARTY_KILL','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','CHAT_MSG_ADDON'}) do pcall(frame.RegisterEvent,frame,event) end
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt; if elapsed<0.5 or not A.db then return end;elapsed=0
 local ok,err=pcall(function()
  if A.TargetingLocked and not A.TargetingLocked()then if not A.window and A.CreateUI then A.CreateUI()end;if not A.nearbyFrame and A.CreateNearbyUI then A.CreateNearbyUI()end end
  A.ScanVisible();A.Pump(now());if A.PumpTopPost then A.PumpTopPost(now())end;if A.window and A.window:IsShown()then A.RefreshUI()end;if A.RefreshNearby then A.RefreshNearby(now())end;if A.PumpNearbySounds then A.PumpNearbySounds(now())end;if A.PumpPartyAlerts then A.PumpPartyAlerts(now())end
 end)
 if not ok then A.lastError=tostring(err) end
end)
