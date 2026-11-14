local _,A=...
local function public(v)return not(A.Secret and A.Secret(v))end
local function copy(t)local out={};for k,v in pairs(t or {})do out[k]=v end;return out end
local function player(g)return type(g)=='string' and g:match('^Player%-[%w%-]+$')~=nil end
-- Fresh correlation is bounded separately from retained credit identities.
local function room(records,key)
 if records[key]then return true end
 local count,oldest,stamp=0,nil,math.huge
 for g,e in pairs(records)do count=count+1;local at=e.time or 0;if at<stamp then oldest,stamp=g,at end end
 if count>=64 then records[oldest]=nil;return false,oldest end
 return true
end
local function record()return {total=0,deaths=0,days={},deathDays={}}end
local function eventPair(kind,actor,target)return kind..':'..actor..':'..(kind=='D'and'death'or target)end
local function number(s,max)local n=type(s)=='string' and s:match('^%d+$') and tonumber(s);if n and n<=max then return n end end
local function store(guildKey)
 guildKey=guildKey or A.guildKey;if not guildKey then return nil end
 local root=A.account or A.db;root.guildObservations=root.guildObservations or {}
 root.guildObservations[guildKey]=root.guildObservations[guildKey] or {events={}}
 local s=root.guildObservations[guildKey]
 A.groupIndexes=A.groupIndexes or {};local index=A.groupIndexes[guildKey]
 if not index then
  index={names={},pairs={}};A.groupIndexes[guildKey]=index
  for _,e in pairs(s.events)do
   local pair=eventPair(e.kind,e.actor,e.target)
   index.names[e.name]=index.names[e.name] or {};table.insert(index.names[e.name],e)
   index.pairs[pair]=index.pairs[pair] or {};table.insert(index.pairs[pair],e)
  end
 end
 return s,index
end
function A.InitKillPolicy(now)
 if A.guildKey and not A.guildUnverified and A.members and A.members[A.owner]then
  local s=store();s.killPolicySince=s.killPolicySince or now
 end
end
function A.InitGroupTracking(now)
 local r=A.db.owners[A.owner]
 if not r.guildBase then r.guildBase={since=now,total=r.total or 0,deaths=r.deaths or 0,days=copy(r.days),deathDays=copy(r.deathDays)} end
 A.groupTargets={};A.groupSources={};A.groupOwners={};A.groupPending=A.groupPending or {};A.groupIncoming={}
 local s=store();if s then s.killPolicySince=s.killPolicySince or now end
 if A.ResetHonorEvidence then A.ResetHonorEvidence(now)end
end
local function unitName(unit)
 local ok,n,realm=pcall(UnitName,unit)
 if not ok or A.Secret(n) or A.Secret(realm) or type(n)~='string' then return nil end
 if type(realm)=='string' and realm~='' then n=n..'-'..realm:gsub('%s','')end
 return A.Name(n)
end
function A.UpdateDeathCombat(guid,unit,t)
 A.groupIncoming=A.groupIncoming or{};local state=A.groupIncoming[guid]
 local dead=A.Safe(UnitIsDeadOrGhost,unit)
 if dead~=false then return state end
 if state and state.dead then state=nil;A.groupIncoming[guid]=nil end
 local fighting=A.Safe(UnitAffectingCombat,unit);local hp=A.Safe(UnitHealthMax,unit)
 if fighting==true then
  if not state or state.ended then state={started=t,events={},health=0};A.groupIncoming[guid]=state end
  state.combat=true
 elseif fighting==false and state and state.combat and not state.ended then state.ended=t end
 if state and type(hp)=='number'and hp>0 and hp<math.huge then state.health=math.max(state.health,hp)end
 return state
end
function A.IncomingDeathEvidence(guid,t)
 local state=(A.groupIncoming or{})[guid]
 if not state or state.dead or(state.ended and t-state.ended>2)then return end
 local health,start=state.health,state.started
 if guid==A.Safe(UnitGUID,'player')and A.deathFight then
  health=math.max(health,A.deathFight.health or 0)
  start=math.max(start,A.deathFight.started or start)
 end
 local harmful=state.harmful
 if harmful and harmful.time>=start and harmful.time<=t and t-harmful.time<=A.WINDOW then
  return {damage=0,maxHealth=health,source=harmful.source,time=t,harmful=true}
 end
 return A.GnomeDeathEvidence(state.events,health,t,start)
end
-- Store the latest validated living harmful observation (one bounded proof).
-- Reinspection is positive current evidence; cache age/failed scans are not.
-- Native combat is optional for this proof, never for collector damage.
function A.IncomingHarmful(guid,source,spell,t,event,auraType,sourceRace,hideCaster,victimUnit)
 local actor=(A.groupOwners or{})[guid]
 local unit=victimUnit or(actor and actor.unit)
 if not actor or A.Safe(UnitExists,unit)~=true or(victimUnit and A.Safe(UnitIsPlayer,unit)~=true)
  or A.Safe(UnitGUID,unit)~=guid or A.Safe(UnitIsDeadOrGhost,unit)~=false then return false end
 local state=A.UpdateDeathCombat(guid,unit,t)
 local row={event=event or 'SPELL_AURA_APPLIED',sourceGUID=source,spellId=spell,timestamp=t,auraType=auraType,hideCaster=hideCaster}
 local proof=A.GnomeHarmfulEvidence(row,t,state and not state.ended and state.started or t,sourceRace)
 if not proof then return false end
 if not state or state.ended then
  state={started=t,events={},health=0};A.groupIncoming[guid]=state
  local hp=A.Safe(UnitHealthMax,unit);if type(hp)=='number'and hp>0 and hp<math.huge then state.health=hp end
 end
 if not state.harmful or proof.time>state.harmful.time then state.harmful=proof end
 if A.EstablishOwnHarmfulContext then A.EstablishOwnHarmfulContext(guid,state)end
 return true
end
function A.RefreshGroupActors()
 A.groupSources={};A.groupOwners={};A.groupUnits={}
 if not A.guildKey or A.guildUnverified then return end
 local function add(unit,pet)
  if not A.Safe(UnitExists,unit) then return end
  local guid=A.Safe(UnitGUID,unit);if not player(guid)then return end
  local name=unitName(unit);if not name then return end;local rawName=name
  if guid==A.Safe(UnitGUID,'player')then name=A.owner elseif A.CanonicalCharacterName then name=A.CanonicalCharacterName(name,guid)end
  local guild=A.Safe(GetGuildInfo,unit)
  if guild and A.guildName and guild~=A.guildName then if A.ForgetGuildMember then A.ForgetGuildMember(name,guid)else A.members[name]=nil end;return end
  if not(A.guildName and guild==A.guildName)and not(A.rosterSeen and A.rosterSeen[name])then return end
  if A.ObserveGuildCharacter then name=A.ObserveGuildCharacter(rawName,guid,A.Safe(GetServerTime)or 0)end
  if A.RememberGuildMember then A.RememberGuildMember(name,guid)else A.members[name]=true end
  local peers=A.PeerRecords()
  if name~=A.owner and not(A.account and A.account.characters[name])and not peers[name]then peers[name]=record();peers[name].observerOnly=true end
  if peers[name]then if peers[name].characterGUID and peers[name].characterGUID~=guid then return end;peers[name].characterGUID=guid end
  local actor={name=name,guid=guid,unit=unit};A.groupOwners[guid]=actor;A.groupSources[guid]=actor;A.groupUnits[#A.groupUnits+1]=unit
  A.UpdateDeathCombat(guid,unit,A.Safe(GetServerTime)or A.now)
  local petGUID=A.Safe(UnitGUID,pet);if type(petGUID)=='string' then A.groupSources[petGUID]=actor end
 end
 add('player','pet')
 if A.Safe(IsInRaid)then
  for i=1,math.min(A.Safe(GetNumGroupMembers)or 0,40)do add('raid'..i,'raidpet'..i)end
 else
  local n=A.Safe(GetNumSubgroupMembers)or math.max(0,(A.Safe(GetNumGroupMembers)or 1)-1)
  for i=1,math.min(n,4)do add('party'..i,'partypet'..i)end
 end
 -- Departed/untracked victims cannot retain session proof for a later visit.
 -- Pending own-death contexts contain independent frozen values.
 for guid in pairs(A.groupIncoming or{})do if not A.groupOwners[guid]then A.groupIncoming[guid]=nil end end
end
function A.GuildEffectiveRecord(name,r,now,guildKey)
 r=r or record();local s,index=store(guildKey);if not s then return r end
 local base=r.guildBase
 local b=base or {since=r.observerOnly and 0 or now+1,total=r.total or 0,deaths=r.deaths or 0,days=r.days or {},deathDays=r.deathDays or {}}
 local result={total=b.total or 0,deaths=b.deaths or 0,days=copy(b.days),deathDays=copy(b.deathDays)}
 local preK,preD,postK,postD={},{},{},{}
 for _,e in ipairs(index.names[name]or {})do
  local day=A.Day(e.time);local t=e.kind=='K' and (e.time<b.since and preK or postK)or(e.time<b.since and preD or postD)
  t[day]=(t[day]or 0)+1
 end
 for _,set in ipairs({{preK,postK,'days','total'},{preD,postD,'deathDays','deaths'}})do
  local pre,post,key,total=set[1],set[2],set[3],set[4]
  -- The lifetime baseline may contain history whose daily buckets expired
  -- before initialization. Allocate that unknown budget against pre-cutoff
  -- evidence before adding anything: missing dates do not prove disjointness.
  -- Keep daily maxima, so genuinely dated disjoint evidence is not discarded.
  local dated,extra=0,0;for _,n in pairs(b[key]or{})do dated=dated+n end
  local unknown=math.max(0,(b[total]or 0)-dated)
  for day,n in pairs(pre)do local old=result[key][day]or 0;extra=extra+math.max(0,n-old);result[key][day]=math.max(old,n)end
  result[total]=result[total]+math.max(0,extra-unknown)
  for day,n in pairs(post)do result[key][day]=(result[key][day]or 0)+n;result[total]=result[total]+n end
 end
 local first=A.Day(now)-A.RETENTION+1
 for _,key in ipairs({'days','deathDays'})do for day in pairs(result[key])do if day<first then result[key][day]=nil end end end
 return result
end
function A.RebuildOwnGuildTotals(now)
 if not A.guildKey or not A.members[A.owner]then return end
 local r=A.db.owners[A.owner];local effective=A.GuildEffectiveRecord(A.owner,r,now)
 r.total=effective.total;r.deaths=effective.deaths;r.days=effective.days;r.deathDays=effective.deathDays
end
function A.AddGuildEvent(kind,name,actor,target,at,contribution,now,lifeAfter,claim,provenance)
 if A.guildUnverified then return false end
 if A.CanonicalCharacterName then name=A.CanonicalCharacterName(name,actor)end
 if not A.guildKey or not A.members[name] or not player(actor)or not player(target)or(kind~='K'and kind~='D')then return false end
 at=math.floor(at);contribution=math.floor(contribution)
 if at>now+5 or at<1000000000 or contribution>at+1 or contribution<at-A.WINDOW then return false end
 local s,index=store();local pair=eventPair(kind,actor,target)
 local id=claim and('H:'..actor..':'..claim)or(pair..':'..at)
 if claim and kind=='K'and not s.events[id]then
  -- Enrich preserved legacy credit without adding a second observation.
  -- Only roots use the legacy clock window; an explicit successor life is
  -- never collapsed merely because it follows its predecessor quickly.
  local life=s.killLives and s.killLives[claim]
  for _,old in ipairs(index.pairs[pair]or{})do
   local exact=old.time==at and old.contribution==contribution
   local compatible=life and life.parent=='root'and math.abs(old.time-at)<=3
    and contribution<=old.time+1 and old.contribution<=at+1
   if not old.claim and(exact or compatible)then
    local previous
    for key,e in pairs(s.events)do if e==old then previous=key;break end end
    if previous then
     s.events[previous]=nil;old.legacyTime=old.time;old.claim=claim;old.provenance=provenance;old.name=name;s.events[id]=old
     A.groupIndexes[A.guildKey]=nil
     A.groupPending[A.guildKey]=A.groupPending[A.guildKey]or{}
     A.groupPending[A.guildKey][previous]=nil;A.groupPending[A.guildKey][id]=true
     if not A.groupBulk then A.RebuildOwnGuildTotals(now);if A.QueueShare then A.QueueShare(false)end end
     if A.RequestUIRefresh then A.RequestUIRefresh()end
     return false
    end
   end
  end
 end
 for _,old in ipairs(claim and {}or index.pairs[pair]or {})do
  local newLocalLife=kind=='K' and lifeAfter==old.time and contribution>old.time
  if not newLocalLife and math.abs(old.time-at)<=3 and (kind=='D' or (contribution<=old.time+1 and old.contribution<=at+1))then
   local life=old.claim and s.killLives and s.killLives[old.claim]
   if not claim and kind=='K'and life and life.parent=='root'and at<(s.killPolicySince or now)
    and(type(old.legacyTime)~='number'or at<old.legacyTime)then
    -- Legacy arrival in the reverse order must preserve the original daily
    -- allocation too, including a clock offset straddling UTC midnight.
    old.time=at;old.contribution=contribution;old.legacyTime=at
    local key='H:'..actor..':'..old.claim
    A.groupPending[A.guildKey]=A.groupPending[A.guildKey]or{};A.groupPending[A.guildKey][key]=true
    if not A.groupBulk then A.RebuildOwnGuildTotals(now);if A.QueueShare then A.QueueShare(false)end end
    if A.RequestUIRefresh then A.RequestUIRefresh()end
   end
   return false
  end
 end
 if s.events[id]then
  if provenance=='H'and s.events[id].provenance=='A'then
   s.events[id].provenance='H';A.groupPending[A.guildKey]=A.groupPending[A.guildKey]or{};A.groupPending[A.guildKey][id]=true
   if A.QueueShare then A.QueueShare(false)end
  end
  return false
 end
 local e={kind=kind,name=name,actor=actor,target=target,time=at,contribution=contribution,claim=claim,provenance=provenance};s.events[id]=e
 index.names[name]=index.names[name]or {};table.insert(index.names[name],e);index.pairs[pair]=index.pairs[pair]or {};table.insert(index.pairs[pair],e)
 local peers=A.PeerRecords();if name~=A.owner and not peers[name]then peers[name]=record();peers[name].observerOnly=true end
 A.groupPending[A.guildKey]=A.groupPending[A.guildKey]or {};A.groupPending[A.guildKey][id]=true
 if not A.groupBulk then A.RebuildOwnGuildTotals(now);if A.QueueShare then A.QueueShare(false)end end
 if A.RequestUIRefresh then A.RequestUIRefresh()end
 return true
end
function A.CarryOwnGuildHistory(now)
 if not A.guildKey or not A.account then return end
 local root=A.account.guildObservations or {};local current=store();if not current then return end
 local oldBulk=A.groupBulk;A.groupBulk=true;local changed=false
 for guild,s in pairs(root)do if guild~=A.guildKey then for _,e in pairs(s.events or {})do
  if A.account.characters[e.name]and A.members[e.name]then
   local added
   if e.claim and s.killLives and s.killLives[e.claim]then
    if A.ImportHonorLineage then A.ImportHonorLineage(s,s.killLives[e.claim].parent)end
    added=A.AddHonorClaim(e.name,e.actor,e.target,e.time,e.contribution,now,e.claim,s.killLives[e.claim].parent,e.provenance)
   else added=A.AddGuildEvent(e.kind,e.name,e.actor,e.target,e.time,e.contribution,now)end
   if added then changed=true end
  end
 end end end
 A.groupBulk=oldBulk;if changed and A.QueueShare then A.QueueShare(true)end
end
function A.GroupObserve(g,race,hostile,hp,now,dead)
 if not A.OpenWorldKillsAllowed() then return end
 if not A.guildKey or not player(g)or race~='Gnome'then return end
 A.ObserveKillLife(g,dead,now)
 if A.db.dead[g]then return end
 local e=A.groupTargets[g]
 if not e and hostile==true and not dead then e={actors={},seen=now};A.groupTargets[g]=e end
 if not e then return end
 if dead==false then e.living=now end
 local active=false;for _,p in pairs(e.actors)do if now-p.last<=A.WINDOW then active=true;break end end
 if not active then e.actors={};e.hp=nil end
 e.seen=now;if type(hp)=='number'and hp>0 then e.hp=math.max(e.hp or 0,hp)end
 if dead then return A.GroupDeath(g,now,true)end
end
local function participant(g,source,now)
 local e=A.groupTargets[g];local actor=A.groupSources[source]
 if not e or not actor or not A.members[actor.name]or A.db.dead[g]then return end
 local p=e.actors[actor.guid]
 if not p or now-(p.last or now)>A.WINDOW then p={name=actor.name,guid=actor.guid,damage=0};e.actors[actor.guid]=p end
 p.last=now;return p
end
function A.GroupDamage(g,amount,overkill,source,now)
 if not A.OpenWorldKillsAllowed() then return false end
 if type(amount)~='number'or amount<0 then return false end
 local p=participant(g,source,now);if not p then return false end
 p.damage=p.damage+math.max(0,amount-math.max(0,tonumber(overkill)or 0));return true
end
function A.GroupCC(g,spell,source,now,harmful)
 if not A.OpenWorldKillsAllowed() then return false end
 if type(spell)~='number'or spell<1 or spell%1~=0 or harmful==false or(not A.CCSpells[spell]and harmful~=true)then return false end
 local p=participant(g,source,now);if not p then return false end
 if not p.cc and A.KillOutcome then A.KillOutcome('participant debuff accepted',now,g)end
 p.cc=true;p.harmfulAt=now;return true
end
function A.GroupDeath(g,now,corpseConfirmed,deathConfirmed,nativePK)
 if not A.OpenWorldKillsAllowed() or not player(g)then return false end
 if corpseConfirmed~=true and A.killLifeAfter and A.killLifeAfter[g]then
  if not(A.ReadableKillCorpse and A.ReadableKillCorpse(g))then if A.KillOutcome then A.KillOutcome('rejected life',now,g)end;return false end
 end
 local e=A.groupTargets[g]
 if A.db.dead[g]then return false end
 if not e and not((A.honorSightings or{})[g])and nativePK~=true then return false end
 A.killCandidates=A.killCandidates or{}
 local s=(A.honorSightings or{})[g]
 local race=s and now>=s.time and now-s.time<=8 and s.race or nil
 if not race and deathConfirmed==true and A.FreshHonorRace then race=A.FreshHonorRace(g)end
 if not room(A.killCandidates,g)and A.honorState then A.honorState.overflow=true end
 A.killCandidates[g]={guid=g,time=now,actors=e and e.actors or{},guild=A.guildKey,
  race=race,parent=(A.honorParents or{})[g]or'root',
  eligible=not A.guildUnverified and A.members and A.members[A.owner]==true,owner=A.owner,ownerGUID=A.Safe and A.Safe(UnitGUID,'player')}
 A.groupTargets[g]=nil;A.encounters[g]=nil;A.db.dead[g]=now
 if A.KillOutcome then A.KillOutcome('native death candidate',now,g)end
 if A.auras then A.auras[g]=nil end
 if A.HonorProgress then A.HonorProgress(now)end
 return false
end
function A.GroupOwnDeath(id,race,now,killer,proof)
 if type(id)~='string'or not A.ValidGnomeDeathEvidence(proof,now)or killer~=proof.source or not A.guildKey or not A.members[A.owner]then return false end
 A.db.recaps=A.db.recaps or {};if A.db.recaps[id]then return false end;A.db.recaps[id]=now
 for key,stamp in pairs(A.db.recaps)do if now-stamp>86400 then A.db.recaps[key]=nil end end
 local guid=A.Safe(UnitGUID,'player');local added=A.AddGuildEvent('D',A.owner,guid,killer,now,now,now)
 if added then A.CreditNotice('D',killer)end
 return added
end
function A.GroupCombat(v,now)
 local event,source,target=v[2],v[4],v[8]
 if event=='UNIT_DIED'or event=='UNIT_DESTROYED'then
  A.GroupDeath(target,now,nil,true)
  local dead=A.groupOwners[target];local proof=A.IncomingDeathEvidence(target,now)
  if dead and proof then
   local added=A.AddGuildEvent('D',dead.name,dead.guid,proof.source,now,now,now)
   if added and dead.name==A.owner then A.CreditNotice('D',proof.source)end
  end
  A.groupIncoming[target]=nil;return
 end
 local amount,overkill
 if event=='SWING_DAMAGE'then amount,overkill=v[12],v[13]
 elseif event=='SPELL_DAMAGE'or event=='SPELL_PERIODIC_DAMAGE'or event=='RANGE_DAMAGE'or event=='DAMAGE_SHIELD'then amount,overkill=v[15],v[16]
 elseif event=='ENVIRONMENTAL_DAMAGE'then amount,overkill=v[13],v[14]end
 if amount then
  A.GroupDamage(target,amount,overkill,source,now)
  if A.groupOwners[target]then
   local actor=A.groupOwners[target];local state=A.UpdateDeathCombat(target,actor.unit,now)
   if state and state.combat and not state.dead and(not state.ended or now-state.ended<=2)then
    local index=event=='SWING_DAMAGE'and 12 or 15
    state.events[#state.events+1]={event=event,sourceGUID=source,amount=amount,overkill=overkill,timestamp=now,
     hideCaster=v[3],resisted=v[index+3],blocked=v[index+4],absorbed=v[index+5]}
    if #state.events>2000 then table.remove(state.events,1)end
   end
  end
 elseif event=='SPELL_AURA_APPLIED'or event=='SPELL_AURA_REFRESH'or event=='SPELL_AURA_APPLIED_DOSE'then if v[15]=='DEBUFF'then
  A.GroupCC(target,v[12],source,now,true)
  A.IncomingHarmful(target,source,v[12],now,event,v[15],nil,v[3])
 end
 end
end
local function claimToken(v)
 return type(v)=='string'and #v<=96 and v:match('^Player%-%w[%w%-]*:%d+$')~=nil
end
function A.ImportHonorLineage(origin,id)
 local current=store();current.killLives=current.killLives or{};current.killAliases=current.killAliases or{};current.killRoots=current.killRoots or{}
 local chain,visited={},{}
 while id~='root'and not current.killAliases[id]do
  local life=origin.killLives[id];if not life or visited[id]then return false end
  visited[id]=true;chain[#chain+1]={id=id,target=life.target,parent=life.parent};id=life.parent
 end
 local parent=id=='root'and'root'or current.killAliases[id]
 for i=#chain,1,-1 do
  local life=chain[i];local existing
  if parent=='root'then existing=current.killRoots[life.target]else existing=current.killLives[parent].next end
  local canonical=existing or life.id
  if not existing then
   current.killLives[canonical]={target=life.target,parent=parent,aliasCount=0}
   if parent=='root'then current.killRoots[life.target]=canonical else current.killLives[parent].next=canonical end
  end
  local mapped=current.killLives[canonical]
  if not current.killAliases[life.id]then
   if (mapped.aliasCount or 0)>=64 then return false end
   mapped.aliasCount=(mapped.aliasCount or 0)+1;mapped.aliasTokens=mapped.aliasTokens or{};mapped.aliasTokens[#mapped.aliasTokens+1]=life.id
  end
  current.killAliases[life.id]=canonical;current.killAliases[canonical]=canonical;parent=canonical
 end
 return true
end
function A.AddHonorClaim(name,actor,target,at,contribution,now,token,parent,provenance)
 if not A.guildKey or not public(name)or type(name)~='string'or #name>128 or name:find('[%c|]')
  or not public(actor)or not public(target)or not public(token)or not public(parent)or not public(provenance)
  or not public(at)or not public(contribution)or not public(now)or type(now)~='number'or now~=now or now>=math.huge then return false end
 -- Check the literal submitted character before following a claimed GUID.
 local root=A.account or A.db
 local identities=(root.guildIdentities or{})[A.guildKey]
 local peer=A.PeerRecords()[name];local own=(root.characters or{})[name]
 local known=(root.characterGUIDs or{})[name]or(identities and identities.names[name])or(peer and peer.characterGUID)or(own and own.characterGUID)
 if known and known~=actor then return false end
 for guid,rosterName in pairs((A.rosterGUIDs or{})[A.guildKey]or{})do if rosterName==name and guid~=actor then return false end end
 if A.CanonicalCharacterName then
  local canonical=A.CanonicalCharacterName(name,actor)
  if canonical~=name and known~=actor then return false end
  name=canonical
 end
 if A.guildUnverified or not A.guildKey or not A.members[name]or not player(actor)or not player(target)
  or not claimToken(token)or(parent~='root'and not claimToken(parent))or token==parent
  or(provenance~='H'and provenance~='A')or type(at)~='number'or type(contribution)~='number'
  or at%1~=0 or contribution%1~=0 or at<1000000000 or at>now+5 or contribution>at+1 or contribution<at-A.WINDOW then return false end
 local s=store();s.killLives=s.killLives or{};s.killAliases=s.killAliases or{};s.killRoots=s.killRoots or{}
 local ancestor=parent~='root'and s.killAliases[parent]or nil
 if parent~='root'and not ancestor then
  A.honorClaimPending=A.honorClaimPending or{};local q=A.honorClaimPending
  for _,v in ipairs(q)do if v[7]==token and v[2]==actor then return false end end
  if #q<64 then q[#q+1]={name,actor,target,at,contribution,now,token,parent,provenance,guild=A.guildKey}end
  return false
 end
 if ancestor and s.killLives[ancestor].target~=target then return false end
 local existing=s.killAliases[token]
 local id=ancestor and s.killLives[ancestor].next or s.killRoots[target]
 if ancestor and not s.killLives[ancestor].next then id=nil end
 if existing and existing~=id then return false end
 if not id then
  id=token;s.killLives[id]={target=target,parent=ancestor or'root'}
  if ancestor then s.killLives[ancestor].next=id else s.killRoots[target]=id end
 end
 local life=s.killLives[id];life.aliasCount=life.aliasCount or 0
 if not s.killAliases[token]then
  if life.aliasCount>=64 then return false end
  life.aliasCount=life.aliasCount+1;life.aliasTokens=life.aliasTokens or{};life.aliasTokens[#life.aliasTokens+1]=token
 end
 s.killAliases[token]=id;s.killAliases[id]=id
 local added=A.AddGuildEvent('K',name,actor,target,at,contribution,now,nil,id,provenance)
 local ancestorID=id;local retained={}
 while ancestorID~='root'and s.killLives[ancestorID]and not retained[ancestorID]do
  retained[ancestorID]=true;s.killLives[ancestorID].contextOnly=nil
  if s.killContexts then s.killContexts[ancestorID]=nil end
  ancestorID=s.killLives[ancestorID].parent
 end
 -- Parent-first resolution is independent of history packet order. Never use
 -- receipt time, clock proximity or a new observer's root as resurrection proof.
 A.DrainHonorClaims(now)
 return added,id
end
function A.DrainHonorClaims(now)
 if not A.honorClaimDraining then
  A.honorClaimDraining=true
  for pass=1,64 do
   local q=A.honorClaimPending or{};A.honorClaimPending={}
   for _,v in ipairs(q)do if v.guild==A.guildKey and now>=v[6]and now-v[6]<=120 then
    A.AddHonorClaim(v[1],v[2],v[3],v[4],v[5],now,v[7],v[8],v[9])
   end end
   if #A.honorClaimPending==0 or #A.honorClaimPending>=#q then break end
  end
  A.honorClaimDraining=nil
 end
end

local function nextClaim()
 local root=A.account or A.db
 local sequence=root.honorSequence
 if type(sequence)~='number'or sequence~=sequence or sequence<0 or sequence%1~=0 or sequence>=1000000000 then sequence=0 end
 root.honorSequence=sequence+1
 return A.Safe(UnitGUID,'player')..':'..root.honorSequence
end

-- Typed lineage carries no actor or credit. It only lets a peer resolve a
-- predecessor whose actor records did not move guild with our own history.
function A.PruneHonorLineage(s,now)
 s.killContexts=s.killContexts or{};local count=0
 for id,at in pairs(s.killContexts)do
  if now<at or now-at>120 then
   local life=s.killLives and s.killLives[id]
   if life and life.contextOnly then
    for _,token in ipairs(life.aliasTokens or{id})do if s.killAliases[token]==id then s.killAliases[token]=nil end end
    if s.killRoots and s.killRoots[life.target]==id then s.killRoots[life.target]=nil end
    local parent=s.killLives[life.parent];if parent and parent.next==id then parent.next=nil end
    s.killLives[id]=nil
   end
   s.killContexts[id]=nil
  else count=count+1 end
 end
 return count
end
function A.ReceiveHonorLineage(target,token,parent,now)
 if not A.guildKey or A.guildUnverified or not public(now)or type(now)~='number'or now~=now or now>=math.huge
  or not public(target)or not player(target)
  or not public(token)or not public(parent)or not claimToken(token)
  or(parent~='root'and not claimToken(parent))or token==parent then return false end
 local s=store();s.killAliases=s.killAliases or{};s.killLives=s.killLives or{}
 local contextCount=A.PruneHonorLineage(s,now)
 local ancestor=parent=='root'and'root'or s.killAliases[parent]
 if not ancestor then
  A.honorLineagePending=A.honorLineagePending or{};local q=A.honorLineagePending
  for _,v in ipairs(q)do if v.token==token and v.guild==A.guildKey then return false end end
  if #q<64 then q[#q+1]={target=target,token=token,parent=parent,time=now,guild=A.guildKey}end
  return false
 end
 if ancestor~='root'and s.killLives[ancestor].target~=target then return false end
 local existing=s.killAliases[token]
 if existing and(s.killLives[existing].target~=target or s.killLives[existing].parent~=ancestor)then return false end
 local canonical
 if ancestor=='root'then canonical=s.killRoots and s.killRoots[target]else canonical=s.killLives[ancestor].next end
 if not canonical and contextCount>=64 then return false end
 local origin={killLives={[token]={target=target,parent=parent}}}
 if not A.ImportHonorLineage(origin,token)then return false end
 if not canonical then
  local id=s.killAliases[token];s.killLives[id].contextOnly=true;s.killContexts[id]=now
 end
 if not A.honorLineageDraining then
  A.honorLineageDraining=true
  for pass=1,64 do
   local q=A.honorLineagePending or{};A.honorLineagePending={}
   for _,v in ipairs(q)do if v.guild==A.guildKey and now>=v.time and now-v.time<=120 then A.ReceiveHonorLineage(v.target,v.token,v.parent,now)end end
   if #A.honorLineagePending==0 or #A.honorLineagePending>=#q then break end
  end
  A.honorLineageDraining=nil
 end
 A.DrainHonorClaims(now)
 return true
end
local function lineagePacket(s,id)
 local life=s.killLives and s.killLives[id]
 if life then return table.concat({'5','L',life.target,id,life.parent},'|')end
end
local function lineageChain(s,id)
 local result,visited={},{}
 while id and id~='root'and not visited[id]and s.killLives and s.killLives[id]do
  visited[id]=true;result[#result+1]=id;id=s.killLives[id].parent
 end
 return result
end
local function eventPacket(e)
 if e.claim then
  local s=store();local life=s.killLives[e.claim]
  return table.concat({'5','H',A.EncodeAlias(e.name),e.actor,e.target,e.time,e.contribution,e.claim,life.parent,e.provenance},'|')
 end
 return table.concat({'5','E',e.kind,A.EncodeAlias(e.name),e.actor,e.target,e.time,e.contribution},'|')
end
function A.PriorityGroupPacket()
 local s=store();if not s then return end
 local pending=A.groupPending[A.guildKey]or {};local chosen
 for id in pairs(pending)do local e=s.events[id];if e and A.members[e.name]and(not chosen or e.time>s.events[chosen].time)then chosen=id end end
 if chosen then
  local e=s.events[chosen];local life=e.claim and s.killLives[e.claim]
  A.groupLifeSent=A.groupLifeSent or{};A.groupLifeSent[A.guildKey]=A.groupLifeSent[A.guildKey]or{}
  local chain=lineageChain(s,life and life.parent)
  for i=#chain,1,-1 do if not A.groupLifeSent[A.guildKey][chain[i]]then return lineagePacket(s,chain[i]),'L:'..chain[i]end end
  return eventPacket(e),chosen
 end
end
function A.MarkGroupSent(id)
 if id:sub(1,2)=='L:'then
  A.groupLifeSent=A.groupLifeSent or{};A.groupLifeSent[A.guildKey]=A.groupLifeSent[A.guildKey]or{};A.groupLifeSent[A.guildKey][id:sub(3)]=true;return
 end
 if A.groupPending[A.guildKey]then A.groupPending[A.guildKey][id]=nil end
end
function A.GroupPackets(full,now)
 local s=store();local out={};if not s then return out end
 if A.account then for name,r in pairs(A.account.characters)do
  if A.members[name]and r.guildBase then
   local b=r.guildBase;local days={[A.Day(now)]=true};if full then for d in pairs(b.days)do days[d]=true end;for d in pairs(b.deathDays)do days[d]=true end end
   for day in pairs(days)do if day<=A.Day(now)then out[#out+1]=table.concat({'5','B',A.EncodeAlias(name),b.since,b.total,b.deaths,day,b.days[day]or 0,b.deathDays[day]or 0},'|')end end
  end
 end end
 local pending=A.groupPending[A.guildKey]or {};local ids={}
 for id,e in pairs(s.events)do if A.members[e.name]and(full or pending[id])then ids[#ids+1]=id end end
 table.sort(ids,function(a,b)if s.events[a].time~=s.events[b].time then return s.events[a].time>s.events[b].time end;return a<b end)
 local emitted={}
 for _,id in ipairs(ids)do
  local e=s.events[id];local life=e.claim and s.killLives[e.claim]
  local chain=lineageChain(s,life and life.parent)
  for i=#chain,1,-1 do if not emitted[chain[i]]then emitted[chain[i]]=true;out[#out+1]=lineagePacket(s,chain[i])end end
  out[#out+1]=eventPacket(e);pending[id]=nil
 end
 return out
end
function A.ReceiveGroup(msg,sender,now)
 local f={};for token in msg:gmatch('[^|]+')do f[#f+1]=token end
 if f[1]~='5'then return false end
 if f[2]=='L'and #f==5 then return A.ReceiveHonorLineage(f[3],f[4],f[5],now)
 elseif f[2]=='H'and #f==10 then
  local name=A.DecodeAlias(f[3]);local at=number(f[6],4102444800);local contribution=number(f[7],4102444800)
  if not name or not at or not contribution then return false end
  return A.AddHonorClaim(name,f[4],f[5],at,contribution,now,f[8],f[9],f[10])
 elseif f[2]=='E'and #f==8 then
  local name=A.DecodeAlias(f[4]);local at=number(f[7],4102444800);local contribution=number(f[8],4102444800)
  if not name or not at or not contribution then return false end
  local s=store()
  if f[3]=='K'and at>=(s.killPolicySince or now)then return false end
  local ok=A.AddGuildEvent(f[3],name,f[5],f[6],at,contribution,now)
  -- Replayed well-formed observations are harmless and acknowledged.
  if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
  return ok
 elseif f[2]=='B'and #f==9 then
  local name=A.DecodeAlias(f[3]);if name and A.CanonicalCharacterName then local old=A.PeerRecords()[name];name=A.CanonicalCharacterName(name,old and old.characterGUID)end
  local since=number(f[4],4102444800);local total=number(f[5],1000000000);local deaths=number(f[6],1000000000)
  local day=number(f[7],1000000);local kills=number(f[8],1000000000);local dd=number(f[9],1000000000)
  if not name or not A.members[name]or not since or since>now+5 or not total or not deaths or not day or day>A.Day(now)or not kills or kills>total or not dd or dd>deaths then return false end
  local peers=A.PeerRecords();local source=peers[sender];local target=peers[name]
  if name~=sender and not(source and target and source.accountID and source.accountID==target.accountID)then return false end
  if A.account and A.account.characters[name]then return false end
  target=target or record();peers[name]=target
  local b=target.guildBase
  if not b then b={since=since,total=0,deaths=0,days={},deathDays={}};target.guildBase=b end
  b.since=math.min(b.since,since);b.total=math.max(b.total,total);b.deaths=math.max(b.deaths,deaths);b.days[day]=math.max(b.days[day]or 0,kills);b.deathDays[day]=math.max(b.deathDays[day]or 0,dd)
  target.observerOnly=false;A.RebuildOwnGuildTotals(now);if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end;return true
 end
 return false
end

-- Personal HK evidence is receiver-local. Historical race is not fresh proof.
local function text(v)return public(v)and type(v)=='string'and #v>0 and #v<=256 and not v:find('[%c|]')end
local killReasons={['Gnome identified']=true,['participant debuff accepted']=true,['participant debuff unknown']=true,
 ['native death candidate']=true,['local HK confirmed']=true,['honor confirmation unavailable']=true,
 ['ambiguous HK']=true,['HK unconfirmed']=true,['credit committed']=true,['credit deduplicated']=true,
 ['rejected guild']=true,['rejected location']=true,['rejected life']=true,['non-Gnome HK']=true}
local function outcomeRecord(e)
 if not public(e)or type(e)~='table'or(issecrettable and issecrettable(e))then return end
 local reason,t=e.reason,e.time
 if public(reason)and type(reason)=='string'and killReasons[reason]and public(t)and type(t)=='number'and t==t and t>0 and t<math.huge then return reason,t end
end
function A.InitKillOutcomes()
 local clean={};local list=A.db.killOutcomes
 if public(list)and type(list)=='table'and not(issecrettable and issecrettable(list))then
  for i=math.max(1,#list-31),#list do local r,t=outcomeRecord(list[i]);if r then clean[#clean+1]={reason=r,time=t}end end
 end
 A.db.killOutcomes=clean
end
function A.KillOutcome(reason,t,g)
 if not killReasons[reason]or not A.db or type(t)~='number'then return end
 local list=A.db.killOutcomes
 if not public(list)or type(list)~='table'or(issecrettable and issecrettable(list))then A.InitKillOutcomes();list=A.db.killOutcomes end
 A.killOutcomeThrottle=A.killOutcomeThrottle or{};local key=reason..':'..(type(g)=='string'and g or'')
 local previous=A.killOutcomeThrottle[key]
 if previous and t>=previous and t-previous<2 then return end
 local count=0;for k,v in pairs(A.killOutcomeThrottle)do if t-v>8 then A.killOutcomeThrottle[k]=nil else count=count+1 end end
 if count<64 then A.killOutcomeThrottle[key]=t end
 list[#list+1]={reason=reason,time=t};while #list>32 do table.remove(list,1)end
 if A.db.options.killVerbose~=false and(not A.killLastNotice or t<A.killLastNotice or t>A.killLastNotice)then
  A.killLastNotice=t;A.LocalNotice('Kill detection: '..reason)
 end
end
function A.KillDebugLines()
 local h=A.honorState or{};local lines={'BIHG kill coverage: localized named parser; generic requires native victim + HK increment; 8s correlation; honorEvent='..tostring(A.coverage and A.coverage.honor or false)..'; counter='..(h.provider or'unavailable')}
 local list=A.db and A.db.killOutcomes
 if public(list)and type(list)=='table'and not(issecrettable and issecrettable(list))then
  for i=math.max(1,#list-31),#list do local r,t=outcomeRecord(list[i]);if r then lines[#lines+1]='BIHG kill '..t..': '..r end end
 end
 return lines
end
function A.FreshHonorRace(g)
 if type(GetPlayerInfoByGUID)~='function'then return end
 local ok,_,_,_,race=pcall(GetPlayerInfoByGUID,g)
 if ok and text(race)then return race end
end
function A.HonorSight(g,name,race,hostile,dead,t)
 if A.killAwardActive or not public(g)or not player(g)then return end
 A.honorSightings=A.honorSightings or{}
 local old=A.honorSightings[g]
 if dead==true and not old and not A.db.dead[g]then
  -- A first-seen player corpse has uncertain life/race provenance. Keep it
  -- as a competing native candidate, never silently assign its HK to a Gnome.
  A.GroupDeath(g,t,true,nil,true);return
 end
 if not text(name)or not text(race)then
  if dead==true and not A.db.dead[g]then A.GroupDeath(g,t,true,nil,true)end
  return
 end
 local available,evicted=room(A.honorSightings,g)
 if not available then A.honorSightOverflowUntil=t+8;if A.honorParents then A.honorParents[evicted]=nil end end
 if dead==false and hostile==true then
  if A.db.dead[g]and(t>A.db.dead[g]or(A.killBoundaryDead and A.killBoundaryDead[g]))then
   local s=store();A.honorParents=A.honorParents or{}
   A.honorParents[g]=s and s.killLocal and s.killLocal[g]or nil
   if A.killCandidates then A.killCandidates[g]=nil end
   A.ObserveKillLife(g,false,t)
  end
  if not old and race=='Gnome'then A.KillOutcome('Gnome identified',t,g)end
  A.honorSightings[g]={name=name,race=race,time=t,living=t}
 elseif old and dead==true and t>=old.living and t-old.living<=A.WINDOW then
  old.time=t;old.race=race;A.GroupDeath(g,t,true)
 end
end
local function namedPattern(format)
 if not text(format)then return end
 local parts,fields={},{};local i=1
 while i<=#format do
  local c=format:sub(i,i)
  if c=='%'then
   if format:sub(i+1,i+1)=='%'then parts[#parts+1]='%%';i=i+2
   else
    local rest=format:sub(i);local token,pos,kind=rest:match('^(%%(%d+)%$([sd]))')
    if not token then token,kind=rest:match('^(%%([sd]))')end
    if not token then return end
    fields[#fields+1]={position=pos and tonumber(pos)or #fields+1,kind=kind}
    parts[#parts+1]=kind=='s'and'(.+)'or'(%d+)';i=i+#token
   end
  else parts[#parts+1]=c:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');i=i+1 end
 end
 return '^'..table.concat(parts)..'$',fields
end
local function namedVictim(message)
 for _,key in ipairs({'COMBATLOG_HONORGAIN','COMBATLOG_HONORGAIN_NO_RANK'})do
  local pattern,fields=namedPattern(_G[key])
  if pattern then
   local matches={message:match(pattern)}
   if #matches>0 then for i,field in ipairs(fields)do if field.position==1 and field.kind=='s'and text(matches[i])then return matches[i]end end end
  end
 end
end
function A.ConfirmHonorCandidate(c,t)
 if c.confirmed then A.KillOutcome('credit deduplicated',t,c.guid);return false end
 if A.killAwardActive then return false end
 c.confirmed=true -- reserve before callbacks; subsequent sources must merge.
 A.killAwardActive=true
 local function finish(result)A.killAwardActive=nil;return result end
 A.KillOutcome('local HK confirmed',t,c.guid)
 if c.race~='Gnome'then A.KillOutcome('non-Gnome HK',t,c.guid);return finish(false)end
 if not A.OpenWorldKillsAllowed()then A.KillOutcome('rejected location',t,c.guid);return finish(false)end
 if c.eligible~=true or c.owner~=A.owner or c.ownerGUID~=(A.Safe and A.Safe(UnitGUID,'player'))
  or c.guild~=A.guildKey or A.guildUnverified or not(A.members and A.members[A.owner])then A.KillOutcome('rejected guild',t,c.guid);return finish(false)end
 local guid=A.Safe(UnitGUID,'player')
 c.claim=c.claim or nextClaim();c.parent=c.parent or(A.honorParents or{})[c.guid]or'root'
 local added,id=A.AddHonorClaim(A.owner,guid,c.guid,c.time,c.time,t,c.claim,c.parent,'H')
 local s=store();s.killLocal=s.killLocal or{};s.killLocal[c.guid]=id or c.claim
 A.KillOutcome(added and'credit committed'or'credit deduplicated',t,c.guid)
 if added then A.CreditNotice('K',c.guid)end
 for _,p in pairs(c.actors or{})do
  if p.guid~=guid and p.cc and p.harmfulAt and c.time>=p.harmfulAt and c.time-p.harmfulAt<=A.WINDOW and A.members[p.name]then
   A.AddHonorClaim(p.name,p.guid,c.guid,c.time,p.harmfulAt,t,c.claim,c.parent,'A')
  end
 end
 return finish(added)
end
function A.HonorMessage(message,t)
 if not text(message)then return false end
 if A.coverage then A.coverage.honor=true end
 A.HonorProgress(t)
 local victim=namedVictim(message);if not victim then
  A.HonorProgress(t)
  local h=A.honorState;h.message=t;h.started=h.started or t
  if not h.provider then A.KillOutcome('honor confirmation unavailable',t)end
  return false
 end
 if A.honorSightOverflowUntil and t<=A.honorSightOverflowUntil then A.KillOutcome('ambiguous HK',t);return false end
 local match
 for g,s in pairs(A.honorSightings or{})do
  if t>=s.time and t-s.time<=8 and(s.name==victim or s.name:match('^([^-]+)')==victim)then
   if match then A.honorState.named=(A.honorState.named or 0)+1;A.honorState.started=A.honorState.started or t;A.KillOutcome('ambiguous HK',t);return false end
   match=g
  end
 end
 if not match then A.honorState.named=(A.honorState.named or 0)+1;A.honorState.started=A.honorState.started or t;A.KillOutcome('rejected life',t);return false end
 local c=(A.killCandidates or{})[match]
 if c and c.confirmed then return A.ConfirmHonorCandidate(c,t)end
 A.honorState.named=(A.honorState.named or 0)+1;A.honorState.started=A.honorState.started or t
 if c and(t<c.time or t-c.time>8)then A.KillOutcome('rejected life',t,match);return false end
 if not c then
  if A.db.dead[match]then A.KillOutcome('rejected life',t,match);return false end
  local s=A.honorSightings[match];local e=(A.groupTargets or{})[match]
  if A.killLifeAfter and A.killLifeAfter[match]and not A.ReadableKillCorpse(match)then A.KillOutcome('rejected life',t,match);return false end
  c={guid=match,time=t,actors=e and e.actors or{},guild=A.guildKey,race=s.race,
   eligible=not A.guildUnverified and A.members and A.members[A.owner]==true,owner=A.owner,ownerGUID=A.Safe(UnitGUID,'player')}
  A.killCandidates=A.killCandidates or{};if not room(A.killCandidates,match)then A.honorState.overflow=true end;A.killCandidates[match]=c
  A.db.dead[match]=t;A.groupTargets[match]=nil
 end
 c.race=c.race or A.honorSightings[match].race
 return A.ConfirmHonorCandidate(c,t)
end

local function counter()
 for _,key in ipairs({'GetPVPLifetimeStats','GetPVPSessionStats'})do
  local fn=_G[key]
  if type(fn)=='function'then
   local ok,n=pcall(fn)
   if ok and public(n)and type(n)=='number'and n==n and n>=0 and n<1000000000 and n%1==0 then return n,key end
  end
 end
end
function A.ResetHonorEvidence(t)
 local n,provider=counter()
 A.honorState={counter=n,provider=provider,last=t,clock=A.Safe and A.Safe(GetTime)}
 A.killCandidates={};A.honorSightings={};A.honorParents={};A.honorSightOverflowUntil=nil
end
function A.MarkHonorUncertainty(t)
 if not A.honorState then A.ResetHonorEvidence(t)end
 A.honorState.overflow=true;A.honorState.started=A.honorState.started or t
 A.KillOutcome('ambiguous HK',t)
end
function A.HonorProgress(t)
 if not A.honorState then A.ResetHonorEvidence(t)end
 local h=A.honorState;local n,provider=counter();local clock=A.Safe and A.Safe(GetTime)
 if t<h.last or(type(clock)=='number'and type(h.clock)=='number'and clock<h.clock)
  or provider~=h.provider or(n and h.counter and n<h.counter)then A.ResetHonorEvidence(t);return end
 h.last=t;h.clock=clock
 if n and h.counter and n>h.counter then
  h.delta=(h.delta or 0)+n-h.counter;h.started=h.started or t
 end
 h.counter=n
 h.candidates=h.candidates or{}
 for g,c in pairs(A.killCandidates or{})do
  if not c.confirmed and not c.genericClosed and t>=c.time and t-c.time<=8 then
   if not room(h.candidates,c)then h.overflow=true end
   h.candidates[c]=c;h.started=h.started or c.time
  end
 end
 local count,chosen=0,nil
 for _,c in pairs(h.candidates)do count=count+1;chosen=c end
 -- Do not resolve by nearest/last target. Close the full bounded correlation
 -- window before selecting: later native Human deaths also make it ambiguous.
 if h.started and t-h.started>=8 then
  if h.message and h.delta==1 and count==1 and not h.named and not h.debt and not h.overflow and t-h.started<=9 then A.ConfirmHonorCandidate(chosen,t)
  elseif not h.named then A.KillOutcome(not h.provider and'honor confirmation unavailable'or((count>1 or(h.delta or 0)>1 or h.overflow)and'ambiguous HK'or'HK unconfirmed'),t)end
  for _,c in pairs(h.candidates)do c.genericClosed=true end
  local debt=math.max(0,(h.debt or 0)+(h.named or 0)-(h.delta or 0))
  A.honorState={counter=n,provider=provider,last=t,clock=clock,debt=debt>0 and debt or nil}
  for g,c in pairs(A.killCandidates or{})do if t-c.time>A.WINDOW then A.killCandidates[g]=nil end end
 end
 for g,s in pairs(A.honorSightings or{})do if t-s.time>A.WINDOW then A.honorSightings[g]=nil;if A.honorParents then A.honorParents[g]=nil end end end
end
