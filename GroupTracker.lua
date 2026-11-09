local _,A=...
local function copy(t)local out={};for k,v in pairs(t or {})do out[k]=v end;return out end
local function player(g)return type(g)=='string' and g:match('^Player%-[%w%-]+$')~=nil end
local function record()return {total=0,deaths=0,days={},deathDays={}}end
local function eventPair(kind,actor,target)return kind..':'..actor..':'..(kind=='D'and'death'or target)end
local function number(s,max)local n=type(s)=='string' and s:match('^%d+$') and tonumber(s);if n and n<=max then return n end end
local function store(guildKey)
 guildKey=guildKey or A.guildKey;if not guildKey then return nil end
 local root=A.account or A.db;root.guildObservations=root.guildObservations or {}
 root.guildObservations[guildKey]=root.guildObservations[guildKey] or {events={}}
 local s=root.guildObservations[guildKey];A.groupIndexes=A.groupIndexes or {};local index=A.groupIndexes[guildKey]
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
function A.InitGroupTracking(now)
 local r=A.db.owners[A.owner]
 if not r.guildBase then r.guildBase={since=now,total=r.total or 0,deaths=r.deaths or 0,days=copy(r.days),deathDays=copy(r.deathDays)} end
 A.groupTargets={};A.groupSources={};A.groupOwners={};A.groupPending=A.groupPending or {};A.groupIncoming={}
end
local function unitName(unit)
 local ok,n,realm=pcall(UnitName,unit)
 if not ok or A.Secret(n) or A.Secret(realm) or type(n)~='string' then return nil end
 if type(realm)=='string' and realm~='' then n=n..'-'..realm:gsub('%s','')end
 return A.Name(n)
end
function A.UpdateDeathCombat(guid,unit,t)
 A.groupIncoming=A.groupIncoming or{};local state=A.groupIncoming[guid]
 local fighting=A.Safe(UnitAffectingCombat,unit);local hp=A.Safe(UnitHealthMax,unit)
 if fighting==true then
  if not state or state.ended then state={started=t,events={},health=0};A.groupIncoming[guid]=state end
 elseif fighting==false and state and not state.ended then state.ended=t end
 if state and type(hp)=='number'and hp>0 and hp<math.huge then state.health=math.max(state.health,hp)end
 return state
end
function A.IncomingDeathEvidence(guid,t)
 local state=(A.groupIncoming or{})[guid]
 if not state or(state.ended and t-state.ended>2)then return end
 local health=state.health
 if guid==A.Safe(UnitGUID,'player')and A.deathFight then health=math.max(health,A.deathFight.health or 0)end
 return A.GnomeDeathEvidence(state.events,health,t,state.started)
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
  for day,n in pairs(pre)do local old=result[key][day]or 0;local extra=math.max(0,n-old);result[key][day]=old+extra;result[total]=result[total]+extra end
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
function A.AddGuildEvent(kind,name,actor,target,at,contribution,now)
 if A.guildUnverified then return false end
 if A.CanonicalCharacterName then name=A.CanonicalCharacterName(name,actor)end
 if not A.guildKey or not A.members[name] or not player(actor)or not player(target)or(kind~='K'and kind~='D')then return false end
 at=math.floor(at);contribution=math.floor(contribution)
 if at>now+5 or at<1000000000 or contribution>at+1 or contribution<at-A.WINDOW then return false end
 local s,index=store();local pair=eventPair(kind,actor,target)
 for _,old in ipairs(index.pairs[pair]or {})do
  if math.abs(old.time-at)<=3 and (kind=='D' or (contribution<=old.time+1 and old.contribution<=at+1))then return false end
 end
 local id=pair..':'..at
 if s.events[id]then return false end
 local e={kind=kind,name=name,actor=actor,target=target,time=at,contribution=contribution};s.events[id]=e
 index.names[name]=index.names[name]or {};table.insert(index.names[name],e);index.pairs[pair]=index.pairs[pair]or {};table.insert(index.pairs[pair],e)
 local peers=A.PeerRecords();if name~=A.owner and not peers[name]then peers[name]=record();peers[name].observerOnly=true end
 A.groupPending[A.guildKey]=A.groupPending[A.guildKey]or {};A.groupPending[A.guildKey][id]=true
 if not A.groupBulk then A.RebuildOwnGuildTotals(now);if A.QueueShare then A.QueueShare(false)end end
 return true
end
function A.CarryOwnGuildHistory(now)
 if not A.guildKey or not A.account then return end
 local root=A.account.guildObservations or {};local current=store();if not current then return end
 local oldBulk=A.groupBulk;A.groupBulk=true;local changed=false
 for guild,s in pairs(root)do if guild~=A.guildKey then for _,e in pairs(s.events or {})do
  if A.account.characters[e.name]and A.members[e.name]then if A.AddGuildEvent(e.kind,e.name,e.actor,e.target,e.time,e.contribution,now)then changed=true end end
 end end end
 A.groupBulk=oldBulk;if changed and A.QueueShare then A.QueueShare(true)end
end
function A.GroupObserve(g,race,hostile,hp,now,dead)
 if not A.guildKey or not player(g)or race~='Gnome'then return end
 if dead==false and A.db.dead[g]and now-A.db.dead[g]>2 then A.db.dead[g]=nil end
 if A.db.dead[g]then return end
 local e=A.groupTargets[g]
 if not e and hostile==true and not dead then e={actors={},seen=now};A.groupTargets[g]=e end
 if not e then return end
 local active=false;for _,p in pairs(e.actors)do if now-p.last<=A.WINDOW then active=true;break end end
 if not active then e.actors={};e.hp=nil end
 e.seen=now;if type(hp)=='number'and hp>0 then e.hp=math.max(e.hp or 0,hp)end
 if dead then return A.GroupDeath(g,now)end
end
local function participant(g,source,now)
 local e=A.groupTargets[g];local actor=A.groupSources[source]
 if not e or not actor or not A.members[actor.name]or A.db.dead[g]then return end
 local p=e.actors[actor.guid]
 if not p or now-(p.last or now)>A.WINDOW then p={name=actor.name,guid=actor.guid,damage=0};e.actors[actor.guid]=p end
 p.last=now;return p
end
function A.GroupDamage(g,amount,overkill,source,now)
 if type(amount)~='number'or amount<0 then return false end
 local p=participant(g,source,now);if not p then return false end
 p.damage=p.damage+math.max(0,amount-math.max(0,tonumber(overkill)or 0));return true
end
function A.GroupCC(g,spell,source,now,harmful)
 if type(spell)~='number'or spell<1 or spell%1~=0 or harmful==false or(not A.CCSpells[spell]and harmful~=true)then return false end
 local p=participant(g,source,now);if not p then return false end;p.cc=true;return true
end
function A.GroupDeath(g,now)
 if not player(g)then return false end
 local e=A.groupTargets[g];A.groupTargets[g]=nil
 if not e or A.db.dead[g]then return false end
 if A.auras then A.auras[g]=nil end
 A.db.dead[g]=now;local awarded=false
 for _,p in pairs(e.actors)do
  if now-p.last<=A.WINDOW and(p.cc or(e.hp and p.damage>=e.hp*A.DAMAGE_FRACTION))then if A.AddGuildEvent('K',p.name,p.guid,g,now,p.last,now)then awarded=true end end
 end
 return awarded
end
function A.GroupOwnDeath(id,race,now,killer,proof)
 if type(id)~='string'or not A.ValidGnomeDeathEvidence(proof,now)or killer~=proof.source or not A.guildKey or not A.members[A.owner]then return false end
 A.db.recaps=A.db.recaps or {};if A.db.recaps[id]then return false end;A.db.recaps[id]=now
 for key,stamp in pairs(A.db.recaps)do if now-stamp>86400 then A.db.recaps[key]=nil end end
 local guid=A.Safe(UnitGUID,'player');return A.AddGuildEvent('D',A.owner,guid,killer,now,now,now)
end
function A.GroupCombat(v,now)
 local event,source,target=v[2],v[4],v[8]
 if event=='UNIT_DIED'or event=='UNIT_DESTROYED'then
  A.GroupDeath(target,now)
  local dead=A.groupOwners[target];local proof=A.IncomingDeathEvidence(target,now)
  if dead and proof then A.AddGuildEvent('D',dead.name,dead.guid,proof.source,now,now,now)end
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
   if state and(not state.ended or now-state.ended<=2)then
    state.events[#state.events+1]={event=event,sourceGUID=source,amount=amount,overkill=overkill,timestamp=now}
    if #state.events>2000 then table.remove(state.events,1)end
   end
  end
 elseif event=='SPELL_AURA_APPLIED'or event=='SPELL_AURA_REFRESH'or event=='SPELL_AURA_APPLIED_DOSE'then if v[15]=='DEBUFF'then A.GroupCC(target,v[12],source,now,true)end
 end
end
local function eventPacket(e)return table.concat({'5','E',e.kind,A.EncodeAlias(e.name),e.actor,e.target,e.time,e.contribution},'|')end
function A.PriorityGroupPacket()
 local s=store();if not s then return end
 local pending=A.groupPending[A.guildKey]or {};local chosen
 for id in pairs(pending)do local e=s.events[id];if e and A.members[e.name]and(not chosen or e.time>s.events[chosen].time)then chosen=id end end
 if chosen then return eventPacket(s.events[chosen]),chosen end
end
function A.MarkGroupSent(id)
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
 for _,id in ipairs(ids)do out[#out+1]=eventPacket(s.events[id]);pending[id]=nil end
 return out
end
function A.ReceiveGroup(msg,sender,now)
 local f={};for token in msg:gmatch('[^|]+')do f[#f+1]=token end
 if f[1]~='5'then return false end
 if f[2]=='E'and #f==8 then
  local name=A.DecodeAlias(f[4]);local at=number(f[7],4102444800);local contribution=number(f[8],4102444800)
  if not name or not at or not contribution then return false end
  local ok=A.AddGuildEvent(f[3],name,f[5],f[6],at,contribution,now)
  -- Replayed well-formed observations are harmless and acknowledged.
  if A.RefreshUI then A.RefreshUI()end
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
  target.observerOnly=false;A.RebuildOwnGuildTotals(now);if A.RefreshUI then A.RefreshUI()end;return true
 end
 return false
end
