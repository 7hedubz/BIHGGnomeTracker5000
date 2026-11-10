local addon,A=...
function A.Secret(v) return issecretvalue and issecretvalue(v) or false end
function A.Safe(fn,...)
 if type(fn)~='function' then return nil end
 local ok,v=pcall(fn,...); if not ok or A.Secret(v) then return nil end; return v
end
local function now()return A.Safe(GetServerTime) or time() end
local function readable(v)if not A.Secret(v) then return v end end
local function recapID()
 local link=C_DeathRecap and A.Safe(C_DeathRecap.GetRecapLink)
 return type(link)=='string' and link:match('death:(%d+)') or nil
end
-- Only readable actual instance-context changes isolate live incoming data.
-- Kill-policy unknown/world-area refreshes never reset frozen dead-life data.
function A.ResetIncomingLocation()
 A.groupIncoming={};A.killingBlow=nil
 local t=now();local clock=A.Safe(GetTime)
 A.deathFight={started=t,clockStart=type(clock)=='number' and clock or nil,health=0}
 A.deathExcludedRecap=recapID()
end
function A.RefreshDeathLocation()
 if type(IsInInstance)~='function' then return end
 local ok,inside,kind=pcall(IsInInstance)
 if not ok or A.Secret(inside) or A.Secret(kind) or type(inside)~='boolean' or type(kind)~='string' then return end
 if (inside and (kind=='' or kind=='none')) or (not inside and kind~='none') then return end
 local key=(inside and 'instance:' or 'world:')..kind
 if A.deathLocation and A.deathLocation~=key then A.ResetIncomingLocation()end
 A.deathLocation=key
end
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
function A.Scan(unit,seen,forceAura)
 A.RefreshKillLocation(false)
 if not A.db or not A.Safe(UnitExists,unit) or not A.Safe(UnitIsPlayer,unit) then return end
 local g=A.Safe(UnitGUID,unit); if type(g)~='string' or not g:match('^Player%-') then return end
 local dead=A.Safe(UnitIsDeadOrGhost,unit)
 local previous=seen and seen[g]
 if previous and previous.complete and (dead~=true or previous.dead==true)then return end
 local scanState={dead=dead,complete=type(dead)=='boolean'};if seen then seen[g]=scanState end
 local ok,_,race=pcall(UnitRace,unit); if not ok or A.Secret(race) then race=nil end
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
 local selfGUID=A.Safe(UnitGUID,'player')
 if A.NearbyNotice and g~=selfGUID then
  -- Explicitly invisible units must not refresh the list; otherwise use the
  -- readable unit exposure, like Spy, without claiming an exact distance.
  local visible=A.Safe(UnitIsVisible,unit)~=false
  A.NearbyNotice(g,name,race,faction,t,dead,visible,A.Safe(UnitLevel,unit),A.Safe(UnitClass,unit))
 end
 if faction=='Alliance' and g~=selfGUID and A.members and A.members[A.owner]then
  local fresh=A.Encounter(g,name,race,faction,t)
  if fresh then
   A.QueueShare(false)
   if A.RequestUIRefresh then A.RequestUIRefresh()end
   if A.db.options.nearbyEnabled~=false and A.db.options.alerts~=false and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffb347BIHG: Gnome encountered:|r '..A.DisplayName(name)) end
  end
 end
 local hostile=A.Safe(UnitCanAttack,'player',unit)
 if type(hostile)~='boolean' then scanState.complete=false end
 local hp=A.Safe(UnitHealthMax,unit)
 if A.GroupObserve then A.GroupObserve(g,race,hostile,hp,t,dead)else A.Observe(g,race,hostile,hp,t,dead)end
 -- Corpses and mind-controlled targets may no longer be attackable. Preserve
 -- hostility established while alive; never infer hostile credit from a corpse.
 local encounter=A.GroupObserve and A.groupTargets[g]or A.encounters[g]
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
   if type(id)~='number'or type(source)~='string'or not sourceGUID then unreadableRow=true end
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
  if complete then for key in pairs(A.auras[g]or {})do if not present[key]then A.auras[g][key]=nil end end end
 end
end
function A.ObserveOwnDeathHealth(newCombat)
 local hp=A.Safe(UnitHealthMax,'player');local t=now();local clock=A.Safe(GetTime)
 if newCombat then A.deathFight={started=t,clockStart=clock,health=0}end
 if type(hp)=='number'and hp>0 and hp<math.huge then
  A.ownHealth=hp;local f=A.deathFight;if f and not f.ended then f.health=math.max(f.health,hp)end
 end
end
function A.ScanVisible()
 A.RefreshDeathLocation()
 A.RefreshKillLocation(false)
 A.ObserveOwnDeathHealth()
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
  if A.account then A.account.viewGuilds=A.account.viewGuilds or{};A.account.viewGuilds[realm]=A.guildKey end
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
 if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
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
local deathReasons={['pending recap']=true,['counted']=true,['insufficient confirmed Gnome damage']=true,
 ['unreadable/missing attribution']=true,['stale/unavailable recap']=true,['membership rejection']=true,
 ['credit rejected (deduplication or validation)']=true}
local function deathRecord(e)
 if A.Secret(e) or type(e)~='table' or (issecrettable and issecrettable(e)) then return end
 local at,reason=e.time,e.reason
 if not A.Secret(at) and type(at)=='number' and at==at and at>0 and at<math.huge
  and not A.Secret(reason) and type(reason)=='string' and deathReasons[reason] then return at,reason end
end
function A.InitDeathOutcomes()
 local list=A.db.deathOutcomes;local clean={}
 if not A.Secret(list) and type(list)=='table' and not(issecrettable and issecrettable(list)) then
  for i=math.max(1,#list-31),#list do
   local at,reason=deathRecord(list[i])
   if at then clean[#clean+1]={time=at,reason=reason=='pending recap' and 'stale/unavailable recap' or reason}end
  end
 end
 A.db.deathOutcomes=clean
end
local function deathOutcome(p,reason)
 if not p.outcome then
  local list=A.db.deathOutcomes
  if A.Secret(list) or type(list)~='table' or (issecrettable and issecrettable(list)) then list={};A.db.deathOutcomes=list end
  p.outcome={time=p.time};list[#list+1]=p.outcome
  while #list>32 do table.remove(list,1)end
 end
 p.outcome.reason=reason
end
function A.DeathDebugLines()
 local lines={'BIHG own death outcomes (local; last 32 attempts):'}
 local list=A.db and A.db.deathOutcomes
 if A.Secret(list) or type(list)~='table' or (issecrettable and issecrettable(list)) then return lines end
 for i=math.max(1,#list-31),#list do
  local at,reason=deathRecord(list[i])
  if at then lines[#lines+1]='BIHG death '..at..': '..reason end
 end
 return lines
end
local function recapPending(pending)
 local t=now()
 local clock=A.Safe(GetTime)
 local age=t-pending.time
 if type(clock)=='number' and clock==clock and clock<math.huge and type(pending.clock)=='number' and clock>=pending.clock then age=clock-pending.clock end
 if age>8 then deathOutcome(pending,pending.reason or 'stale/unavailable recap');return true end
 local fight=pending.fight
 if fight and fight.ended and pending.time-fight.ended>2 then deathOutcome(pending,'stale/unavailable recap');return true end
 local proof,provenRecap;local recap=C_DeathRecap
 if recap and recap.GetRecapEvents then
  local link=A.Safe(recap.GetRecapLink)
  local id=type(link)=='string' and link:match('death:(%d+)')
  local events=A.Safe(recap.GetRecapEvents,id and tonumber(id))
  if type(events)=='table' and not (issecrettable and issecrettable(events)) then
   local stamp,first
   for _,e in ipairs(events)do if not A.Secret(e)and type(e)=='table'and not(issecrettable and issecrettable(e))then
    local v=readable(e.timestamp);if type(v)=='number'and v==v and v<math.huge then stamp=math.max(stamp or v,v);first=math.min(first or v,v)end
   end end
   local diedAt,start=pending.time,fight and fight.started or pending.time-10
   local previous,following=pending.previousTime,pending.nextTime
   if stamp and type(pending.clock)=='number'and math.abs(stamp-pending.clock)<=10 then
    diedAt=pending.clock;start=fight and fight.clockStart or diedAt-10
    previous,following=pending.previousClock,pending.nextClock
    -- A reset/backward monotonic clock cannot bound a different clock era.
    if previous and previous>diedAt then previous=nil end
    if following and following<diedAt then following=nil end
   end
   -- Never admit later-life rows through a +1-second tolerance. A payload
   -- crossing a prior death, or two indistinguishable death timestamps, has
   -- no defensible life owner. Reject it without consuming its native ID.
   local fresh=stamp and stamp>=start and stamp<=diedAt and diedAt-stamp<=10
    and(not previous or first>previous or(first==previous and pending.excludedRecap and id~=pending.excludedRecap))
    and(not following or following>diedAt)
   A.db.deathRecapsSeen=A.db.deathRecapsSeen or{}
   if id and id~=pending.excludedRecap and fresh and(pending.recapID==id or not A.db.deathRecapsSeen[id])then
    pending.recapID=id
    local hp=A.Safe(recap.GetRecapMaxHealth,tonumber(id));if type(hp)~='number'or hp<=0 or hp>=math.huge then hp=pending.health end
    if type(hp)=='number'then hp=math.max(hp,pending.health or 0,fight and fight.health or 0)end
    proof,pending.reason=A.GnomeDeathEvidence(events,hp,diedAt,start)
    pending.reason=pending.reason or 'unreadable/missing attribution'
    A.coverage.recap=true
    if proof then proof.time=pending.time;provenRecap=id end
   end
  end
 end
 if not proof then proof=pending.incoming end
 if proof then
  local membership=not pending.memberEligible or pending.guildKey~=A.guildKey or pending.owner~=A.owner
   or pending.ownerGUID~=A.Safe(UnitGUID,'player')
   or not A.guildKey or A.guildUnverified or not(A.members and A.members[A.owner])
  local counted=not membership and A.PlayerDeath('death:'..pending.time,'Gnome',pending.time,proof.source,proof)
  if counted and provenRecap then
   A.db.deathRecapsSeen[provenRecap]=pending.time
   for key,at in pairs(A.db.deathRecapsSeen)do if t-at>86400 then A.db.deathRecapsSeen[key]=nil end end
  end
  deathOutcome(pending,counted and 'counted' or (membership and 'membership rejection' or 'credit rejected (deduplication or validation)'))
  return true
 else deathOutcome(pending,pending.reason or 'pending recap')
 end
end
function A.Recap()
 local queue=A.pendingDeaths or {}
 -- Resolve overlapping windows oldest-first; a later life must not steal
 -- an earlier delayed recap merely because its combat start overlaps.
 local i=1
 while i<=#queue do if recapPending(queue[i])then table.remove(queue,i)else i=i+1 end end
 A.pendingDeath=queue[#queue]
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
 A.InitDeathOutcomes()
 BIHGGKTAccountDB=BIHGGKTAccountDB or {}
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
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' or event=='ZONE_CHANGED_NEW_AREA' then A.RefreshKillLocation(true);A.RefreshDeathLocation() end
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
  if arg1=='player'then A.ObserveOwnDeathHealth()end
  if(event=='UNIT_FLAGS'or event=='UNIT_MAXHEALTH')and A.RefreshGroupActors then A.RefreshGroupActors()end
  A.Scan(arg1,nil,event=='UNIT_AURA')
 end
 elseif event=='PLAYER_REGEN_DISABLED'then
  A.ObserveOwnDeathHealth(true)
  local guid=A.Safe(UnitGUID,'player');if guid and A.groupIncoming then A.groupIncoming[guid]=nil end
  if A.RefreshGroupActors then A.RefreshGroupActors()end
 elseif event=='PLAYER_REGEN_ENABLED'then
  if A.deathFight then A.deathFight.ended=now()end
  if A.CreateNearbyUI and not A.nearbyFrame then A.CreateNearbyUI()end
  if A.RefreshNearby then A.RefreshNearby(now())end
 elseif event=='PLAYER_TARGET_CHANGED' then A.Scan('target')
 elseif event=='UPDATE_MOUSEOVER_UNIT' then A.Scan('mouseover')
 elseif event=='PLAYER_FOCUS_CHANGED' then A.Scan('focus')
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then A.ReadCombatLog()
 elseif event=='PARTY_KILL' then if not A.Secret(arg2)then if A.ForgetNearby then A.ForgetNearby(arg2)end;if A.GroupDeath then A.GroupDeath(arg2,now())else A.Death(arg2,now())end end
 elseif event=='PLAYER_DEAD' then
  if A.deathActive then return end
  A.ObserveOwnDeathHealth();A.deathActive=true
  local f=A.deathFight;local diedAt=now();local incoming,reason
  if A.IncomingDeathEvidence then incoming,reason=A.IncomingDeathEvidence(A.Safe(UnitGUID,'player'),diedAt)end
  A.pendingDeath={time=diedAt,clock=A.Safe(GetTime),health=A.ownHealth,incoming=incoming,reason=reason,excludedRecap=A.deathExcludedRecap,
   guildKey=A.guildKey,owner=A.owner,ownerGUID=A.Safe(UnitGUID,'player'),
   memberEligible=not not(A.guildKey and not A.guildUnverified and A.members and A.members[A.owner]),
   fight=f and {started=f.started,clockStart=f.clockStart,health=f.health,ended=f.ended}}
  local previous=A.lastDeathContext
  if previous then
   A.pendingDeath.previousTime=previous.time;A.pendingDeath.previousClock=previous.clock
   previous.nextTime=diedAt;previous.nextClock=A.pendingDeath.clock
  end
  A.lastDeathContext=A.pendingDeath
  A.pendingDeaths=A.pendingDeaths or {};table.insert(A.pendingDeaths,A.pendingDeath)
  if #A.pendingDeaths>4 then local old=table.remove(A.pendingDeaths,1);deathOutcome(old,old.reason or 'stale/unavailable recap')end
  A.Recap(); if C_Timer then C_Timer.After(0.5,A.Recap);C_Timer.After(2,A.Recap) end
 elseif event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then
  A.killingBlow=nil;A.deathActive=false;A.ownHealth=nil
  local at=now();local clock=A.Safe(GetTime)
  A.deathFight={started=at,clockStart=type(clock)=='number' and clock or nil,health=0}
  A.deathExcludedRecap=recapID()
  local guid=A.Safe(UnitGUID,'player');if guid and A.groupIncoming then A.groupIncoming[guid]=nil end
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
for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','ZONE_CHANGED_NEW_AREA','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE','GROUP_ROSTER_UPDATE','UNIT_PET','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_AURA','UNIT_HEALTH','UNIT_FLAGS','UNIT_MAXHEALTH','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED','PARTY_KILL','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','CHAT_MSG_ADDON'}) do pcall(frame.RegisterEvent,frame,event) end
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt; if elapsed<0.5 or not A.db then return end;elapsed=0
 local ok,err=pcall(function()
  if A.TargetingLocked and not A.TargetingLocked()then if not A.window and A.CreateUI then A.CreateUI()end;if not A.nearbyFrame and A.CreateNearbyUI then A.CreateNearbyUI()end end
  A.ScanVisible();A.Recap();local t=now()
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
