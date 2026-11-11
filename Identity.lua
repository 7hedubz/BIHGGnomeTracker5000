local _,A=...
-- Forever's second UnitName return is the surname, not the realm. Do not
-- trim/repair tokens or fall back to a short name when identity is unreadable.
function A.LocalCharacterName()
 A.localCharacterGUID=nil;A.localCharacterName=nil
 if type(UnitName)~='function'or type(UnitGUID)~='function'or type(GetNormalizedRealmName)~='function'then return end
 local ok,first,last=pcall(UnitName,'player');local good,guid=pcall(UnitGUID,'player');local realmOK,realm=pcall(GetNormalizedRealmName)
 local function text(v)return not(A.Secret and A.Secret(v))and type(v)=='string'and v~=''and not v:find('[%c|%-]')and not v:match('^%s')and not v:match('%s$')end
 if not ok or not good or not realmOK or not text(first)or not text(last)or not text(realm)or(A.Secret and A.Secret(guid))or type(guid)~='string'or not guid:match('^Player%-[%w%-]+$')then return end
 A.localCharacterGUID=guid;A.localCharacterName=first..' '..last..'-'..realm
 return A.localCharacterName
end
local function player(g)return type(g)=='string'and g:match('^Player%-[%w%-]+$')~=nil end
local function clone(t,seen)
 if type(t)~='table'then return t end;seen=seen or {};if seen[t]then return seen[t]end
 local out={};seen[t]=out;for k,v in pairs(t)do out[k]=clone(v,seen)end;return out
end
local function mergeCounts(t,s)
 t.total=math.max(t.total or 0,s.total or 0);t.deaths=math.max(t.deaths or 0,s.deaths or 0)
 for _,key in ipairs({'days','deathDays'})do t[key]=t[key]or {};for day,n in pairs(s[key]or {})do t[key][day]=math.max(t[key][day]or 0,n)end end
end
local function merge(t,s,now,skipBaseline)
 if t==s then return end
 -- Archives are created before merging; sanitize every persisted copy before
 -- timestamp arithmetic and before an old spelling can reintroduce history.
 A.PruneEncounters(now,true)
 mergeCounts(t,s)
 local baseline=not skipBaseline and s.guildBase or nil
 if not skipBaseline and not baseline and not s.observerOnly and((s.total or 0)>0 or(s.deaths or 0)>0)then baseline={since=s.updated or now,total=s.total,deaths=s.deaths,days=clone(s.days),deathDays=clone(s.deathDays)}end
 if baseline then
  if not t.guildBase then t.guildBase=clone(baseline)else
   local a,b=t.guildBase,baseline
   local aHas=(a.total or 0)>0 or(a.deaths or 0)>0;local bHas=(b.total or 0)>0 or(b.deaths or 0)>0
   local since=math.max(a.since or 0,b.since or 0)
   -- A newer empty ghost must not move an established baseline forward and
   -- swallow witnessed kills that happened after the real legacy baseline.
   if aHas~=bHas then since=aHas and(a.since or 0)or(b.since or 0)end
   mergeCounts(a,b);a.since=since
  end
 end
 t.seen=t.seen or {}
 for guid,v in pairs(s.seen or {})do
  local old=t.seen[guid]
  if not old then t.seen[guid]=clone(v)else
   A.MergeEncounterMetadata(old,v)
   if v.first then old.first=math.min(old.first or v.first,v.first)end
   if v.last then old.last=math.max(old.last or v.last,v.last)end
   old.race=old.race or v.race;old.name=old.name or v.name;old.days=old.days or {};for day in pairs(v.days or {})do old.days[day]=true end
  end
 end
 if(s.encounterStamp or 0)>(t.encounterStamp or 0)then t.encounterStamp=s.encounterStamp;t.encounterScores=clone(s.encounterScores)end
 if(s.accountEncounterStamp or 0)>(t.accountEncounterStamp or 0)then t.accountEncounterStamp=s.accountEncounterStamp;t.accountEncounterScores=clone(s.accountEncounterScores)end
end
local function root()return A.account or A.db end
local function scope()
 local r=root();if not r or not A.guildKey then return end
 r.guildIdentities=r.guildIdentities or {};r.guildIdentities[A.guildKey]=r.guildIdentities[A.guildKey]or {guids={},names={}}
 return r.guildIdentities[A.guildKey]
end
function A.CanonicalCharacterName(name,guid)
 local r=root();if not r then return name end
 local s=scope()
 if guid then return(r.characterNamesByGUID and r.characterNamesByGUID[guid])or(s and s.guids[guid])or name end
 if(r.ambiguousCharacterNames or{})[name]then return name end
 local g=(r.characterGUIDs and r.characterGUIDs[name])or(s and s.names[name])
 return g and((r.characterNamesByGUID and r.characterNamesByGUID[g])or(s and s.guids[g]))or name
end
local function archive(r,guid,name,record)
 r.identityArchives=r.identityArchives or {};r.identityArchives[guid]=r.identityArchives[guid]or {}
 if not r.identityArchives[guid][name]then r.identityArchives[guid][name]=clone(record)end
end
function A.PrepareLocalIdentity(r,now)
 if A.localCharacterName~=A.owner or not player(A.localCharacterGUID)then return end
 for name,record in pairs(A.db.owners)do if player(record.characterGUID)then
  local other=r.characters[name];local mapped=(r.characterGUIDs or{})[name]
  local conflict=other and other.characterGUID and other.characterGUID~=record.characterGUID or mapped and mapped~=record.characterGUID
  if not conflict then for guid,records in pairs(r.identityArchives or{})do if guid~=record.characterGUID and records[name]then conflict=true;break end end end
  if conflict then r.ambiguousCharacterNames=r.ambiguousCharacterNames or {};r.ambiguousCharacterNames[name]=true end
  if conflict and not record.identityUncertain then
   archive(r,record.characterGUID,name,record)
   if other and player(other.characterGUID)then archive(r,other.characterGUID,name,other)end
   -- A legacy key collision proves neither that its six old kills are new nor
   -- that they belong to this GUID. Keep the original, credit only actor events.
   record.total=0;record.deaths=0;record.days={};record.deathDays={}
   record.guildBase={since=0,total=0,deaths=0,days={},deathDays={}};record.identityUncertain=true
  end
 end end
end
local function rewriteEvents(r,guid,canonical,onlyGuild)
 local aliases={}
 for guild,store in pairs(r.guildObservations or {})do if not onlyGuild or guild==onlyGuild then
  for _,event in pairs(store.events or {})do if event.actor==guid then aliases[event.name]=true;event.name=canonical end end
 end end
 A.groupIndexes={};return aliases
end
function A.BindLocalCharacter(guid,now)
 if not player(guid)or not A.account or A.identityConflict then return false end
 local r=A.account;local canonical=A.owner;local target=A.db.owners[canonical];if not target or(target.characterGUID and target.characterGUID~=guid)then return false end
 r.characterGUIDs=r.characterGUIDs or {};r.characterNamesByGUID=r.characterNamesByGUID or {}
 local aliases=rewriteEvents(r,guid,canonical)
 for name,record in pairs(A.db.owners)do if not record.characterGUID or record.characterGUID==guid then aliases[name]=true end end
 for name,record in pairs(r.characters)do if record.characterGUID==guid or r.characterGUIDs[name]==guid then aliases[name]=true end end
 for _,s in pairs(r.guildIdentities or {})do for name,g in pairs(s.names or {})do if g==guid then aliases[name]=true end end end
 aliases[canonical]=true
 for name in pairs(aliases)do
  -- Inspect both copies: the same legacy key may denote distinct GUIDs in
  -- independently serialized character/account files.
  local copies={r.characters[name],A.db.owners[name]}
  for i=1,2 do local own=copies[i]
   if own and(not own.characterGUID or own.characterGUID==guid)then
    if name~=canonical then
     archive(r,guid,name,own);merge(target,own,now)
     if r.characters[name]==own then r.characters[name]=nil end
     if A.db.owners[name]==own then A.db.owners[name]=nil end
    end
    local other=r.characters[name]
    if not other or not other.characterGUID or other.characterGUID==guid then r.characterGUIDs[name]=guid end
   end
  end
  for _,peers in pairs(r.guilds or {})do
   local peer=peers[name]
   if peer and(not peer.characterGUID or peer.characterGUID==guid)and(not peer.accountID or peer.accountID==r.id)then
    -- A received self-summary is not a new local historical baseline.
    if name~=canonical then archive(r,guid,name,peer);merge(target,peer,now,true);peers[name]=nil end
    peers[canonical]=target;r.characterGUIDs[name]=guid
   end
  end
 end
 r.characterNamesByGUID[guid]=canonical;r.characterGUIDs[canonical]=guid
 target.characterGUID=guid;target.accountID=r.id;target.alias=r.alias;target.aliasRev=r.aliasRev;target.observerOnly=false
 r.characters[canonical]=target;A.db.owners[canonical]=target;A.db.seen=target.seen or A.db.seen or {};target.seen=A.db.seen
 if A.members then
  A.members[canonical]=true
  for name in pairs(r.ambiguousCharacterNames or{})do A.members[name]=nil end
 end
 A.SnapshotAccount(now);A.outgoing=nil;if A.QueueShare then A.QueueShare(true)end;return true
end
function A.ReconcileGuildMembership()
 if not A.members then return end
 local s=scope();if s then for name,guid in pairs(s.names)do if A.members[name]then A.members[A.CanonicalCharacterName(name,guid)]=true end end end
end
function A.ObserveGuildCharacter(name,guid,now)
 if not player(guid)then return A.CanonicalCharacterName(name)end
 local r,s=root(),scope();if not s then return name end
 A.rosterGUIDs=A.rosterGUIDs or {};A.rosterGUIDs[A.guildKey]=A.rosterGUIDs[A.guildKey]or {};A.rosterGUIDs[A.guildKey][guid]=name
 local peers=A.PeerRecords();local canonical=(r.characterNamesByGUID or {})[guid]or s.guids[guid]
 if not canonical then for n,record in pairs(peers)do if record.characterGUID==guid and record.bindingDirect then canonical=n;break end end end
 canonical=canonical or name
 local target=(r.characters or {})[canonical]or peers[canonical]
 if target and target.characterGUID and target.characterGUID~=guid then return name end
 local aliases=rewriteEvents(r,guid,canonical,A.guildKey);aliases[name]=true
 for n,g in pairs(s.names)do if g==guid then aliases[n]=true end end
 for n,record in pairs(peers)do if record.characterGUID==guid then aliases[n]=true end end
 for n in pairs(aliases)do
  local old=peers[n]
  if not old or(not old.characterGUID or old.characterGUID==guid)and(not target or not old.accountID or not target.accountID or old.accountID==target.accountID)then
   if old then
    target=target or old
    if n~=canonical then archive(r,guid,n,old);merge(target,old,now,(r.characters or {})[canonical]~=nil);peers[n]=nil end
   end
   s.names[n]=guid
  end
 end
 s.guids[guid]=canonical;s.names[canonical]=guid
 if target then target.characterGUID=guid;peers[canonical]=target end
 return canonical
end
function A.CharacterIdentityPacket()
 local r=A.account and A.account.characters[A.owner]
 if r and player(r.characterGUID)then return'6|C|'..r.characterGUID end
end
-- Validate the literal name before following the claimed GUID: canonicalizing
-- first can hide a conflict by selecting the unrelated GUID's valid record.
local function conflictingClaim(name,guid)
 local r,s=root(),scope()
 if (r.characterGUIDs or{})[name]and r.characterGUIDs[name]~=guid then return true end
 if s and s.names[name]and s.names[name]~=guid then return true end
 for known,rosterName in pairs(A.rosterGUIDs and A.rosterGUIDs[A.guildKey]or{})do if rosterName==name and known~=guid then return true end end
 for _,records in ipairs({A.PeerRecords(),r.characters or{}})do
  local old=records[name];if old and old.characterGUID and old.characterGUID~=guid then return true end
 end
 return false
end
local function bindGuildCharacter(guid,sender,direct,now,isDirect)
 if conflictingClaim(sender,guid)then return false end
 local peers=A.PeerRecords();local subject=peers[sender]
 if subject and subject.characterGUID and subject.characterGUID~=guid then return false end
 local r=root();local s=scope();if not s then return false end
 local owned=r.characterNamesByGUID and r.characterNamesByGUID[guid]
 if owned and direct.accountID~=r.id then return false end
 local canonical=owned or s.guids[guid]or sender;local previous=peers[canonical]
 if conflictingClaim(canonical,guid)then return false end
 if previous and previous.accountID and previous.accountID~=direct.accountID then return false end
 local target=previous or(isDirect and direct)or {total=0,deaths=0,days={},deathDays={}};local aliases=rewriteEvents(r,guid,canonical,A.guildKey);aliases[sender]=true
 for name,record in pairs(peers)do if record.characterGUID==guid then aliases[name]=true end end
 for name in pairs(aliases)do
  local old=peers[name]
  if old and(not old.characterGUID or old.characterGUID==guid)and(not old.accountID or old.accountID==direct.accountID)then
   if name~=canonical then archive(r,guid,name,old);merge(target,old,now);peers[name]=nil end
   s.names[name]=guid
  end
 end
 s.guids[guid]=canonical;s.names[canonical]=guid;s.names[sender]=guid
 target.characterGUID=guid;target.accountID=direct.accountID
 if not target.aliasRev or(direct.aliasRev or 0)>=target.aliasRev then target.alias=direct.alias;target.aliasRev=direct.aliasRev end
 target.bindingDirect=target.bindingDirect or isDirect;target.observerOnly=false;peers[canonical]=target
 A.members[canonical]=true;A.ReconcileGuildMembership();return true
end
function A.ResolveGuildSender(msg,channel,sender,now)
 if channel~='GUILD'or A.guildUnverified or not A.guildKey or type(sender)~='string'or type(msg)~='string'or #msg>255 or not A.members then return sender end
 local canonical=A.CanonicalCharacterName(sender)
 if A.members[canonical]then return canonical end
 local s=scope();local guid=msg:match('^6|C|(Player%-[%w%-]+)$')
 local roster=guid and A.rosterGUIDs and(A.rosterGUIDs[A.guildKey]or{})[guid]
 if roster and A.members[roster]then
  -- The exact two-component Forever spelling is deterministic, not a search
  -- over first names/nicknames. Never link a conflicting existing GUID.
  local first,last=roster:match('^([^%s%-]+) ([^%-]+)%-[^%-]+$')
  local old=A.PeerRecords()[sender]
  if first and sender==first..'-'..last and not(old and old.characterGUID and old.characterGUID~=guid)then
   canonical=A.CanonicalCharacterName(roster,guid)
   if not A.members[canonical]then return sender end
   s.names[sender]=guid
   for _,p in ipairs(A.pendingGuildIdentities or{})do
    if p.sender==sender and p.guild==A.guildKey and now-p.time<=60 then A.ReceiveAccount(p.msg,canonical,now)end
   end
   return canonical
  end
 elseif msg:match('^3|I|[%w_%-]+|%x+|%d+$')then
  local pending={};for _,p in ipairs(A.pendingGuildIdentities or{})do if now-p.time<=60 and p.guild==A.guildKey and p.sender~=sender then pending[#pending+1]=p end end
  while #pending>=32 do table.remove(pending,1)end
  pending[#pending+1]={msg=msg,sender=sender,guild=A.guildKey,time=now};A.pendingGuildIdentities=pending
 end
 return sender
end
function A.ReceiveCharacterIdentity(msg,sender,now)
 local peers=A.PeerRecords();local source=peers[sender]
 if not source or not source.bindingDirect or not source.accountID then return false end
 local guid=msg:match('^6|C|(Player%-[%w%-]+)$')
 if guid then return bindGuildCharacter(guid,sender,source,now,true)end
 local encoded,altGUID=msg:match('^6|R|(%x+)|(Player%-[%w%-]+)$');local name=encoded and A.DecodeAlias(encoded)
 if not name or name==sender or conflictingClaim(name,altGUID)then return false end
 local roster=A.rosterGUIDs and(A.rosterGUIDs[A.guildKey]or{})[altGUID]
 local canonical=A.CanonicalCharacterName(name,altGUID)
 if not A.members[name]and not(roster and A.members[roster]and A.members[canonical])then return false end
 local target=peers[canonical]or peers[name]
 if target and target.accountID and target.accountID~=source.accountID then return false end
 if target and target.characterGUID and target.characterGUID~=altGUID then return false end
 if A.account and A.account.characters[canonical]and source.accountID~=A.account.id then return false end
 if not bindGuildCharacter(altGUID,name,source,now,false)then return false end
 -- Commit buffered score packets only after metadata establishes the GUID link.
 if A.ReplayAltScores then A.ReplayAltScores(sender,name,now)end
 return true
end
