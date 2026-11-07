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
 local faction=A.Safe(UnitFactionGroup,unit)
 local name,realm
 if UnitName then local good,n,r=pcall(UnitName,unit); if good then name=readable(n);realm=readable(r) end end
 if type(name)=='string' then
  if type(realm)=='string' and realm~='' then name=name..'-'..realm end
  name=A.Name(name)
 end
 local t=now()
 if faction=='Alliance' then
  local fresh=A.Encounter(g,name,race,faction,t)
  if fresh then
   A.QueueShare(true)
   if A.db.options.alerts~=false and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffb347BIHG: Gnome encountered:|r '..A.DisplayName(name)) end
  end
 end
 local hostile=A.Safe(UnitCanAttack,'player',unit)
 local dead=A.Safe(UnitIsDeadOrGhost,unit)
 local hp=A.Safe(UnitHealthMax,unit)
 A.Observe(g,race,hostile,hp,t,dead)
 -- Corpses and mind-controlled targets may no longer be attackable. Preserve
 -- hostility established while alive; never infer hostile credit from a corpse.
 local encounter=A.encounters[g]
 if race~='Gnome' or not (hostile or (encounter and encounter.hostile)) then return end
 if dead then A.Death(g,t); return end
 if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
  for i=1,80 do
   local a=A.Safe(C_UnitAuras.GetAuraDataByIndex,unit,i,'HARMFUL')
   if not a then break end
   if type(a)=='table' and not (issecrettable and issecrettable(a)) then
    local id=readable(a.spellId); local source=readable(a.sourceUnit)
    local instance=readable(a.auraInstanceID); local expires=readable(a.expirationTime)
    if type(id)=='number' and A.CCSpells[id] and type(source)=='string' and own(source) then
     -- Re-observing the same aura is not another successful application.
     local key=tostring(id)..':'..tostring(instance or '')..':'..tostring(expires or '')
     A.auras[g]=A.auras[g] or {}
     if not A.auras[g][key] then A.auras[g][key]=t; A.CC(g,id,true,t) end
     A.coverage.cc=true
    end
   end
  end
 end
end
function A.ScanVisible()
 for _,u in ipairs({'target','focus','mouseover'}) do A.Scan(u) end
 for u in pairs(A.plates) do if A.Safe(UnitExists,u) then A.Scan(u) else A.plates[u]=nil end end
 local t=now()
 for g,e in pairs(A.encounters) do if t-(e.last or e.seen or 0)>A.WINDOW then A.encounters[g]=nil end end
 for g,keys in pairs(A.auras) do
  for k,stamp in pairs(keys) do if t-stamp>600 then keys[k]=nil end end
  if not next(keys) then A.auras[g]=nil end
 end
end
function A.Roster()
 local guild=A.Safe(GetGuildInfo,'player'); local old=A.guildKey
 A.guildKey=type(guild)=='string' and guild..'-'..(A.Safe(GetNormalizedRealmName) or '') or nil
 local count=0
 A.members={}; if A.guildKey then
  A.members[A.owner]=true
  count=A.Safe(GetNumGuildMembers) or 0
  for i=1,math.min(count,1000) do local name=A.Name(A.Safe(GetGuildRosterInfo,i)); if name then A.members[name]=true end end
 end
 if old~=A.guildKey then A.outgoing=nil; A.request=true; A.rx={}; A.queries={}; A.lastRequest=nil; A.syncStatus=nil; A.QueueShare(true) end
 local peers=A.PeerRecords()
 if count>0 then for name in pairs(peers) do if not A.members[name] then peers[name]=nil end end end
 if A.RefreshUI then A.RefreshUI() end
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
 elseif event=='SPELL_AURA_APPLIED' or event=='SPELL_AURA_REFRESH' then A.CC(dst,v[12],true,t) end
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
     A.PlayerDeath('recap:'..id..':'..stamp,A.Race(g),pending.time); A.pendingDeath=nil; return
    end
   end
  end
 end
 local k=A.killingBlow
 if k and math.abs(k.time-pending.time)<=2 then
  A.PlayerDeath('combat:'..pending.time,A.Race(k.guid),pending.time);A.pendingDeath=nil
 end
end
function A.Changed()
 A.QueueShare(false)
 if A.RefreshUI then A.RefreshUI() end
end
local frame=CreateFrame('Frame'); A.eventFrame=frame
local function login()
 if A.db then return end
 local name=A.Safe(UnitName,'player'); if not name then return end
 BIHGGKTDB=BIHGGKTDB or {}; A.Init(BIHGGKTDB,A.Name(name),now())
 A.plates={};A.auras={};A.coverage={};A.syncStatus='Waiting for guild roster'
 if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,A.PREFIX) end
 A.Roster();A.QueueShare(true);A.request=true
 if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
 if A.CreateUI then A.CreateUI() end
end
local function handler(_,event,...)
 local arg1,arg2,arg3,arg4=...
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then login() end
 if not A.db then return end
 if event=='PLAYER_ENTERING_WORLD' then A.Roster();A.QueueShare(true);A.ScanVisible()
 elseif event=='GUILD_ROSTER_UPDATE' or event=='PLAYER_GUILD_UPDATE' then A.Roster()
 elseif event=='NAME_PLATE_UNIT_ADDED' then if not A.Secret(arg1) and type(arg1)=='string' then A.plates[arg1]=true;A.Scan(arg1) end
 elseif event=='NAME_PLATE_UNIT_REMOVED' then if not A.Secret(arg1) then A.plates[arg1]=nil end
 elseif event=='UNIT_AURA' or event=='UNIT_HEALTH' or event=='UNIT_FLAGS' then if not A.Secret(arg1) and type(arg1)=='string' then A.Scan(arg1) end
 elseif event=='PLAYER_TARGET_CHANGED' then A.Scan('target')
 elseif event=='UPDATE_MOUSEOVER_UNIT' then A.Scan('mouseover')
 elseif event=='PLAYER_FOCUS_CHANGED' then A.Scan('focus')
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then A.ReadCombatLog()
 elseif event=='PARTY_KILL' then if not A.Secret(arg2) then A.Death(arg2,now()) end
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
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_AURA','UNIT_HEALTH','UNIT_FLAGS','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED','COMBAT_LOG_EVENT_UNFILTERED','PARTY_KILL','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','CHAT_MSG_ADDON'}) do pcall(frame.RegisterEvent,frame,event) end
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt; if elapsed<0.5 or not A.db then return end;elapsed=0
 local ok,err=pcall(function() A.ScanVisible();A.Pump(now());if A.window and A.window:IsShown() then A.RefreshUI() end end)
 if not ok then A.lastError=tostring(err) end
end)
