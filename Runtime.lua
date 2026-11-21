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
 if A.Secret(name)or type(name)~='string'or name==''then return nil end
 if not name:find('-',1,true)then
  local realm=A.Safe(GetNormalizedRealmName)
  if type(realm)=='string'and realm~=''then name=name..'-'..realm end
 end
 return name
end
function A.Race(g)
 if A.Secret(g) or type(g)~='string' then return nil end
 local saved=(A.account and A.account.knownEncounters and A.account.knownEncounters[g])or(A.db and A.db.seen and A.db.seen[g])
 if saved and saved.race then return saved.race end
 if GetPlayerInfoByGUID then
  local ok,_,_,_,race=pcall(GetPlayerInfoByGUID,g)
  if ok and not A.Secret(race) then return race end
 end
end
local function own(unit)
 return unit and (A.Safe(UnitIsUnit,unit,'player')==true or A.Safe(UnitIsUnit,unit,'pet')==true)
end
-- Corpse auras can complete negative-feedback evidence, but are never new
-- contributions. Do not touch polling, application dedup or eligibility here.
local function corpseAurasComplete(unit)
 local provider=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
 if type(provider)~='function'then return false end
 for i=1,80 do
  local ok,a=pcall(provider,unit,i,'HARMFUL')
  if not ok or A.Secret(a)then return false end
  if a==nil then return true end
  if type(a)~='table'or(issecrettable and issecrettable(a))then return false end
  local good,readableRow=pcall(function()
   for _,key in ipairs({'spellId','sourceUnit','auraInstanceID','expirationTime','isHelpful','isHarmful'})do
    if A.Secret(a[key])then return false end
   end
   return type(a.spellId)=='number'and type(a.sourceUnit)=='string'and A.Safe(UnitGUID,a.sourceUnit)~=nil
  end)
  if not good or not readableRow then return false end
 end
 return false
end
-- A GUID-only callback after rearming can replay the previous life forever.
-- Only an actually exposed, readable corpse can correlate it to the new life.
function A.ReadableKillCorpse(g)
 if A.Secret(g)or type(g)~='string'then return false end
 if not((A.encounters and A.encounters[g])or(A.groupTargets and A.groupTargets[g]))then return false end
 local units={'target','focus','mouseover'}
 for unit in pairs(A.plates or {})do units[#units+1]=unit end
 for _,unit in ipairs(A.groupUnits or {})do units[#units+1]=unit..'target' end
 for _,unit in ipairs(units)do
  if A.Safe(UnitExists,unit)==true and A.Safe(UnitIsPlayer,unit)==true
   and A.Safe(UnitGUID,unit)==g and A.Safe(UnitIsDeadOrGhost,unit)==true then
   if not corpseAurasComplete(unit)then
    local e=A.encounters and A.encounters[g];if e then e.creditUnknown=true end
    e=A.groupTargets and A.groupTargets[g];if e then e.creditUnknown=true end
   end
   return true
  end
 end
 return false
end
function A.Scan(unit,seen,forceAura)
 A.RefreshKillLocation(false)
 if not A.db or not A.Safe(UnitExists,unit) or not A.Safe(UnitIsPlayer,unit) then return end
 local g=A.Safe(UnitGUID,unit); if type(g)~='string' or not g:match('^Player%-') then return end
 local dead=A.Safe(UnitIsDeadOrGhost,unit)
 local previous=seen and seen[g]
 if previous and previous.complete and (dead~=true or previous.dead==true)then return end
 local scanState={dead=dead,complete=type(dead)=='boolean'};if seen then seen[g]=scanState end
 local ok,_,race=pcall(UnitRace,unit); if not ok or A.Secret(race) then race=nil end
 local freshRace=race
 if not freshRace and type(GetPlayerInfoByGUID)=='function'then
  local good,_,_,_,nativeRace=pcall(GetPlayerInfoByGUID,g)
  if good and not A.Secret(nativeRace)then freshRace=nativeRace end
 end
 if not race then race=A.Race(g)end
 if not race then scanState.complete=false end
 local faction=A.Safe(UnitFactionGroup,unit)
 local name,realm
 if UnitName then local good,n,r=pcall(UnitName,unit); if good then name=readable(n);realm=readable(r) end end
 if type(name)=='string' then
  if type(realm)=='string' and realm~='' then name=name..'-'..realm end
  name=A.Name(name)
 end
 local t=now()
 local level,class=A.Safe(UnitLevel,unit),A.Safe(UnitClass,unit)
 local selfGUID=A.Safe(UnitGUID,'player')
 if A.NearbyNotice and g~=selfGUID then
  -- Explicitly invisible units must not refresh the list; otherwise use the
  -- readable unit exposure, like Spy, without claiming an exact distance.
  local visible=A.Safe(UnitIsVisible,unit)~=false
  A.NearbyNotice(g,name,race,faction,t,dead,visible,level,class)
 end
 if faction=='Alliance' and g~=selfGUID and A.members and A.members[A.owner]then
  local fresh=A.Encounter(g,name,race,faction,t,level,class)
  if fresh then
   A.QueueShare(false)
   if A.RequestUIRefresh then A.RequestUIRefresh()end
   if A.db.options.nearbyEnabled~=false and A.db.options.alerts~=false and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffb347BIHG: Gnome encountered:|r '..A.DisplayName(name)) end
  end
 end
 local hostile=A.Safe(UnitCanAttack,'player',unit)
 if A.HonorSight then A.HonorSight(g,name,freshRace,hostile,dead,t)end
 if type(hostile)~='boolean' then scanState.complete=false end
 local hp=A.Safe(UnitHealthMax,unit)
 local prior=A.GroupObserve and A.groupTargets[g]or A.encounters[g]
 -- GroupObserve may finalize immediately, so completeness must precede it.
 if dead==true and prior and not corpseAurasComplete(unit)then scanState.complete=false end
 if prior and not scanState.complete then prior.creditUnknown=true end
 if A.GroupObserve then A.GroupObserve(g,race,hostile,hp,t,dead)else A.Observe(g,race,hostile,hp,t,dead)end
 -- Corpses and mind-controlled targets may no longer be attackable. Preserve
 -- hostility established while alive; never infer hostile credit from a corpse.
 local encounter=A.GroupObserve and A.groupTargets[g]or A.encounters[g]
 if encounter and not scanState.complete then encounter.creditUnknown=true end
 if race~='Gnome' or not (hostile or (encounter and encounter.hostile)) then return end
 if dead then if A.GroupDeath then A.GroupDeath(g,t,true)else A.Death(g,t,true)end;return end
 if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
  local clock=A.Safe(GetTime)or t
  A.auraPoll=A.auraPoll or {};local last=A.auraPoll[g]
  if not forceAura and not(previous and not previous.complete)and last and clock>=last and clock-last<1 then return end
  A.auraPoll[g]=clock
  local present,complete,unreadableRow={},false,false
  for i=1,80 do
   local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,unit,i,'HARMFUL')
   if not ok then break end
   if A.Secret(a) or (type(a)=='table' and issecrettable and issecrettable(a))then unreadableRow=true
   elseif a==nil then complete=not unreadableRow;break
   elseif type(a)~='table' then unreadableRow=true
   elseif A.Secret(a.spellId)or A.Secret(a.sourceUnit)or A.Secret(a.auraInstanceID)or A.Secret(a.expirationTime)or A.Secret(a.isHelpful)or A.Secret(a.isHarmful)then unreadableRow=true
   else
   local id,source=a.spellId,a.sourceUnit
   local instance,expires=a.auraInstanceID,a.expirationTime
   local sourceGUID=type(source)=='string'and A.Safe(UnitGUID,source)
   if type(id)~='number'or type(source)~='string'or not sourceGUID then
    unreadableRow=true;if A.KillOutcome then A.KillOutcome('participant debuff unknown',t,g)end
   end
   local eligible=sourceGUID and ((A.GroupCC and A.groupSources[sourceGUID])or(not A.GroupCC and own(source)))
   local helpful,harmful=a.isHelpful,a.isHarmful
   if A.Secret(helpful)or A.Secret(harmful)then break end
   local explicitBuff=helpful==true or harmful==false
   if type(id)=='number'and id>0 and not explicitBuff and type(source)=='string' and eligible then
    local key=tostring(id)..':'..tostring(sourceGUID or '')..':'..tostring(instance or '')..':'..tostring(expires or '')
    present[key]=true
    A.auras[g]=A.auras[g] or {}
    if not A.auras[g][key]then
     local accepted;if A.GroupCC then accepted=A.GroupCC(g,id,sourceGUID,t,true)else accepted=A.CC(g,id,true,t,true)end
     if accepted then A.auras[g][key]=t end
    end
    A.coverage.cc=true
   end
   end
  end
  -- Errors, secret rows and the enumeration cap never prove absence.
  -- A readable aura list cannot complete missing identity/life/hostility evidence.
  scanState.complete=scanState.complete and complete
  if encounter and not complete then encounter.creditUnknown=true;if A.KillOutcome then A.KillOutcome('participant debuff unknown',t,g)end end
  if complete then for key in pairs(A.auras[g]or {})do if not present[key]then A.auras[g][key]=nil end end end
 elseif encounter then encounter.creditUnknown=true
 end
end
function A.ScanVisible()
 A.RefreshKillLocation(false)
 if A.RefreshGroupActors then A.RefreshGroupActors()end
 local seen={}
 for _,u in ipairs({'target','focus','mouseover'}) do A.Scan(u,seen) end
 for u in pairs(A.plates) do if A.Safe(UnitExists,u) then A.Scan(u,seen) else A.plates[u]=nil end end
 for _,u in ipairs(A.groupUnits or {})do A.Scan(u..'target',seen)end
 local t=now()
 for g,e in pairs(A.encounters) do if t-(e.last or e.seen or 0)>A.WINDOW then A.encounters[g]=nil end end
 for g,e in pairs(A.groupTargets or {})do if t-e.seen>A.WINDOW then A.groupTargets[g]=nil end end
 -- Dedup keys describe applications, not timed contributions. Aging a key
 -- would turn an unchanged long-lived aura into a new application. Complete
 -- absence, readable new lives, deaths and location boundaries clear them.
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
   if not peers[name]and not(A.account and A.account.characters[name])then peers[name]={total=0,days={},observerOnly=true,characterGUID=e.actor}end
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
 local membership=A.Safe(IsInGuild)
 if type(guild)=='string'and guild~=''and not guild:find('[%c|]')and type(realm)=='string'and membership~=false then
  A.guildName=guild
  local guid=A.Safe(UnitGUID,'player');local r=A.account or A.db
  local historical,conflict
  if realm==''and A.HistoricalGuildKey then historical,conflict=A.HistoricalGuildKey(guild,guid,last)end
  A.guildKey=not conflict and(realm~=''and(guild..'-'..realm)or historical or guild)or nil
  A.guildUnverified=conflict==true
  if A.guildKey then
   A.db.lastGuild={name=guild,key=A.guildKey}
   r.guildScopesByGUID=r.guildScopesByGUID or{};if guid then r.guildScopesByGUID[guid]={name=guild,key=A.guildKey}end
  end
  if A.account and realm~=''then A.account.viewGuilds=A.account.viewGuilds or{};A.account.viewGuilds[realm]=A.guildKey end
 elseif A.Safe(IsInGuild)==true and last and type(last.name)=='string'and type(last.key)=='string'and(guild==nil or guild==last.name)then
  A.guildName=last.name;A.guildKey=last.key;A.guildUnverified=true;confirmed=false
 else A.guildName=nil;A.guildKey=nil end
 A.members={};A.rosterSeen={}
 if old~=A.guildKey then if A.ResetHonorEvidence then A.ResetHonorEvidence(now())end;A.rosterCandidate=nil;A.rosterTargetNames={};A.outgoing=nil;A.request=true;A.rx={};A.queries={};A.lastRequest=nil;A.syncStatus=nil;A.QueueShare(true)end
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
  if A.InitKillPolicy then A.InitKillPolicy(now())end
 else A.rosterStatus='guild information unavailable'end
 if A.RefreshGroupActors then A.RefreshGroupActors()end
 if A.ReconcileGuildMembership then A.ReconcileGuildMembership()end
 -- Membership controls presentation only: never delete persisted peer history.
 if A.RefreshGroupActors then if A.CarryOwnGuildHistory then A.CarryOwnGuildHistory(now())end;A.RebuildOwnGuildTotals(now())end
 if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
end
-- Dropped evidence is unknown participation, never evidence of zero damage.
-- A hidden/missing destination cannot safely narrow the affected encounters.
local function blockedParticipation(target)
 A.coverage.blocked=true
 local identified=not A.Secret(target)and type(target)=='string'and target:match('^Player%-')
 for _,records in ipairs({A.encounters or {},A.groupTargets or {}})do
  if identified then
   local e=records[target];if e then e.creditUnknown=true end
  else
   for _,e in pairs(records)do e.creditUnknown=true end
  end
 end
end
function A.ReadCombatLog()
 if not CombatLogGetCurrentEventInfo then return end
 local function pack(...)return {n=select('#',...),...} end
 local result=pack(pcall(CombatLogGetCurrentEventInfo))
 if not result[1] then blockedParticipation(nil); return end
 local v={}
 -- Combat logs contain nil source fields on deaths. Never use #/table.remove
 -- on this sparse tuple: Lua may stop at an interior nil and shift only a prefix.
 for i=2,result.n do
  local x=result[i]
  if A.Secret(x) then blockedParticipation(result[9]); return end
  v[i-1]=x
 end
 local event,src,dst=v[2],v[4],v[8]
 if type(event)~='string' then return end
 A.coverage.log=true
 local t=now()
 if(event=='UNIT_DIED'or event=='UNIT_DESTROYED')and A.ForgetNearby then A.ForgetNearby(dst)end
 if A.GroupCombat then A.GroupCombat(v,t);return end
 if event=='UNIT_DIED' or event=='UNIT_DESTROYED' then A.Death(dst,t,nil,true);return end
 local mine=src and (src==A.Safe(UnitGUID,'player') or src==A.Safe(UnitGUID,'pet'))
 if not mine then return end
 if event=='SWING_DAMAGE' then A.Damage(dst,v[12],v[13],true,t)
 elseif event=='SPELL_DAMAGE' or event=='SPELL_PERIODIC_DAMAGE' or event=='RANGE_DAMAGE' or event=='DAMAGE_SHIELD' then A.Damage(dst,v[15],v[16],true,t)
 elseif(event=='SPELL_AURA_APPLIED'or event=='SPELL_AURA_REFRESH'or event=='SPELL_AURA_APPLIED_DOSE')and v[15]=='DEBUFF'then A.CC(dst,v[12],true,t,true)end
end
function A.Changed()
 if A.account then A.SnapshotAccount(now()) end
 A.QueueShare(false)
 if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
end
local frame=CreateFrame('Frame'); A.eventFrame=frame
local function login()
 if A.db then return end
 local name
 if A.LocalCharacterName then name=A.LocalCharacterName()else name=A.Name(A.Safe(UnitName,'player'))end
 local identity=A.Safe(UnitGUID,'player')
 if not name or type(identity)~='string'or not identity:match('^Player%-[%w%-]+$')then return end
 BIHGGKTDB=BIHGGKTDB or {}; A.Init(BIHGGKTDB,name,now())
 if A.InitKillOutcomes then A.InitKillOutcomes()end
 BIHGGKTAccountDB=BIHGGKTAccountDB or {}
 A.InitAccount(BIHGGKTAccountDB,identity..'-'..now(),now())
 if A.BindLocalCharacter then A.BindLocalCharacter(A.Safe(UnitGUID,'player'),now())end
 if A.InitGroupTracking then A.InitGroupTracking(now())end
 if A.InitNearby then A.InitNearby()end
 A.plates={};A.auras={};A.coverage={};A.syncStatus='Waiting for guild roster'
 if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,A.PREFIX) end
 A.Roster();if A.ResetHonorEvidence then A.ResetHonorEvidence(now())end;A.QueueShare(true);A.request=true
 if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
 if A.CreateUI then A.CreateUI() end
 if A.CreateNearbyUI then A.CreateNearbyUI()end
end
local function handler(_,event,...)
 local arg1,arg2,arg3,arg4=...
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' or event=='ZONE_CHANGED_NEW_AREA' then A.RefreshKillLocation(true) end
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then login() end
 if event=='ADDON_ACTION_BLOCKED'or event=='ADDON_ACTION_FORBIDDEN'then
  if not A.Secret(arg1)and arg1=='BIHGGnomeKillTracker5000'then
   if A.RecordReportRestriction then A.RecordReportRestriction(event,arg1,arg2,now())
   elseif not A.Secret(arg2)and type(arg2)=='string'then A.pendingReportRestriction={event=event,func=arg2,at=now()}end
  end
  return
 end
 if not A.db then return end
 if event=='PLAYER_ENTERING_WORLD' then if A.ClearNearby then A.ClearNearby()end;A.Roster();A.QueueShare(false);A.ScanVisible()
 elseif event=='ZONE_CHANGED_NEW_AREA'then if A.ClearNearby then A.ClearNearby()end;A.ScanVisible()
 elseif event=='GUILD_ROSTER_UPDATE' or event=='PLAYER_GUILD_UPDATE' then A.Roster(event=='GUILD_ROSTER_UPDATE')
 elseif event=='GROUP_ROSTER_UPDATE'or event=='UNIT_PET'then if A.RefreshGroupActors then A.RefreshGroupActors()end
 elseif event=='NAME_PLATE_UNIT_ADDED' then if not A.Secret(arg1) and type(arg1)=='string' then A.plates[arg1]=true;A.Scan(arg1) end
 elseif event=='NAME_PLATE_UNIT_REMOVED' then if not A.Secret(arg1) and type(arg1)=='string'then
  -- Removal is not death. Only inspect a still-readable actual corpse;
  -- never retarget, mutate secure buttons, or manufacture a vanished unit.
  if A.Safe(UnitExists,arg1)==true and A.Safe(UnitIsDeadOrGhost,arg1)==true then A.Scan(arg1)end
  A.plates[arg1]=nil
 end
 elseif event=='UNIT_AURA' or event=='UNIT_HEALTH' or event=='UNIT_FLAGS' or event=='UNIT_MAXHEALTH' then if not A.Secret(arg1) and type(arg1)=='string' then
  if(event=='UNIT_FLAGS'or event=='UNIT_MAXHEALTH')and A.RefreshGroupActors then A.RefreshGroupActors()end
  A.Scan(arg1,nil,event=='UNIT_AURA')
 end
 elseif event=='PLAYER_REGEN_ENABLED'then
  if A.CreateNearbyUI and not A.nearbyFrame then A.CreateNearbyUI()end
  if A.RefreshNearby then A.RefreshNearby(now())end
 elseif event=='PLAYER_TARGET_CHANGED' then A.Scan('target')
 elseif event=='UPDATE_MOUSEOVER_UNIT' then A.Scan('mouseover')
 elseif event=='PLAYER_FOCUS_CHANGED' then A.Scan('focus')
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then A.ReadCombatLog()
 elseif event=='PLAYER_PVP_KILLS_CHANGED'then A.HonorProgress(now())
 elseif event=='CHAT_MSG_COMBAT_HONOR_GAIN'then A.HonorMessage(arg1,now())
 elseif event=='PARTY_KILL'then
  if not A.Secret(arg1)and not A.Secret(arg2)and type(arg1)=='string'and arg1:match('^[%w%-]+$')
   and type(arg2)=='string'and arg2:match('^Player%-[%w%-]+$')then
   if A.ForgetNearby then A.ForgetNearby(arg2)end
   if A.GroupDeath then A.GroupDeath(arg2,now(),nil,true,true)else A.Death(arg2,now(),nil,true)end
  elseif A.MarkHonorUncertainty and(A.Secret(arg1)or A.Secret(arg2)or arg2==nil)then A.MarkHonorUncertainty(now())end
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
for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','ZONE_CHANGED_NEW_AREA','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE','GROUP_ROSTER_UPDATE','UNIT_PET','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_AURA','UNIT_HEALTH','UNIT_FLAGS','UNIT_MAXHEALTH','PLAYER_REGEN_ENABLED','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED','CHAT_MSG_COMBAT_HONOR_GAIN','PLAYER_PVP_KILLS_CHANGED','PARTY_KILL','CHAT_MSG_ADDON'}) do pcall(frame.RegisterEvent,frame,event) end
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt; if elapsed<0.5 or not A.db then return end;elapsed=0
 local ok,err=pcall(function()
  if A.TargetingLocked and not A.TargetingLocked()then if not A.window and A.CreateUI then A.CreateUI()end;if not A.nearbyFrame and A.CreateNearbyUI then A.CreateNearbyUI()end end
  A.ScanVisible();local t=now()
  if A.HonorProgress then A.HonorProgress(t)end
  A.PruneEncounters(t,false)
  if A.CheckVersionNotice then A.CheckVersionNotice(t)end
  -- Sparse, independently throttled party alerts get a budget slot before
  -- bulk history; otherwise a full queue can consume every available slot.
  if A.PumpPartyAlerts then A.PumpPartyAlerts(t)end;A.Pump(t)
  if A.window and A.window:IsShown()then
   if A.uiDirty or A.uiDay~=A.Day(t)or(A.mode=='Encounters'and A.uiMinute~=math.floor(t/60))then A.RefreshUI()
   elseif A.RefreshUIStatus and(A.uiSyncStatus~=A.syncStatus or A.uiRosterStatus~=A.rosterStatus)then A.RefreshUIStatus()end
  end
  if A.RefreshNearby then A.RefreshNearby(t)end;if A.PumpNearbySounds then A.PumpNearbySounds(t)end
 end)
 if not ok then A.lastError=tostring(err) end
end)
