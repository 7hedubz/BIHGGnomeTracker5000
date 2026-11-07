local _,A=...
local function player(g)return type(g)=='string'and g:match('^Player%-[%w%-]+$')~=nil end
local function clone(t,seen)
 if type(t)~='table'then return t end;seen=seen or {};if seen[t]then return seen[t]end
 local out={};seen[t]=out;for k,v in pairs(t)do out[k]=clone(v,seen)end;return out
end
local function mergeCounts(t,s)
 t.total=math.max(t.total or 0,s.total or 0);t.deaths=math.max(t.deaths or 0,s.deaths or 0)
 for _,key in ipairs({'days','deathDays'})do t[key]=t[key]or {};for day,n in pairs(s[key]or {})do t[key][day]=math.max(t[key][day]or 0,n)end end
end
local function merge(t,s,now)
 if t==s then return end;mergeCounts(t,s)
 local baseline=s.guildBase
 if not baseline and not s.observerOnly and((s.total or 0)>0 or(s.deaths or 0)>0)then baseline={since=s.updated or now,total=s.total,deaths=s.deaths,days=clone(s.days),deathDays=clone(s.deathDays)}end
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
 local g=(r.characterGUIDs and r.characterGUIDs[name])or(s and s.names[name])
 return g and((r.characterNamesByGUID and r.characterNamesByGUID[g])or(s and s.guids[g]))or name
end
local function archive(r,guid,name,record)
 r.identityArchives=r.identityArchives or {};r.identityArchives[guid]=r.identityArchives[guid]or {}
 if not r.identityArchives[guid][name]then r.identityArchives[guid][name]=clone(record)end
end
local function rewriteEvents(r,guid,canonical,onlyGuild)
 local aliases={}
 for guild,store in pairs(r.guildObservations or {})do if not onlyGuild or guild==onlyGuild then
  for _,event in pairs(store.events or {})do if event.actor==guid then aliases[event.name]=true;event.name=canonical end end
 end end
 A.groupIndexes={};return aliases
end
function A.BindLocalCharacter(guid,now)
 if not player(guid)or not A.account then return false end
 local r=A.account;local canonical=A.owner;local target=A.db.owners[canonical];if not target then return false end
 r.characterGUIDs=r.characterGUIDs or {};r.characterNamesByGUID=r.characterNamesByGUID or {}
 local aliases=rewriteEvents(r,guid,canonical)
 for name,record in pairs(A.db.owners)do if not record.characterGUID or record.characterGUID==guid then aliases[name]=true end end
 for name,record in pairs(r.characters)do if record.characterGUID==guid or r.characterGUIDs[name]==guid then aliases[name]=true end end
 aliases[canonical]=true
 for name in pairs(aliases)do
  local own=r.characters[name]or A.db.owners[name]
  if own and(not own.characterGUID or own.characterGUID==guid)then
   if name~=canonical then archive(r,guid,name,own);merge(target,own,now);r.characters[name]=nil;A.db.owners[name]=nil end
   r.characterGUIDs[name]=guid
  end
  for _,peers in pairs(r.guilds or {})do
   local peer=peers[name]
   if peer and(not peer.characterGUID or peer.characterGUID==guid)and(not peer.accountID or peer.accountID==r.id)then
    if name~=canonical then archive(r,guid,name,peer);merge(target,peer,now);peers[name]=nil end
    peers[canonical]=target;r.characterGUIDs[name]=guid
   end
  end
 end
 r.characterNamesByGUID[guid]=canonical;r.characterGUIDs[canonical]=guid
 target.characterGUID=guid;target.accountID=r.id;target.alias=r.alias;target.aliasRev=r.aliasRev;target.observerOnly=false
 r.characters[canonical]=target;A.db.owners[canonical]=target;A.db.seen=target.seen or A.db.seen or {};target.seen=A.db.seen
 if A.members then A.members[canonical]=true end
 A.SnapshotAccount(now);A.outgoing=nil;if A.QueueShare then A.QueueShare(true)end;return true
end
function A.ReconcileGuildMembership()
 if not A.members then return end
 local s=scope();if s then for name,guid in pairs(s.names)do if A.members[name]then A.members[s.guids[guid]]=true end end end
end
function A.CharacterIdentityPacket()
 local r=A.account and A.account.characters[A.owner]
 if r and player(r.characterGUID)then return'6|C|'..r.characterGUID end
end
local function bindGuildCharacter(guid,sender,direct,now,isDirect)
 local peers=A.PeerRecords();local subject=peers[sender]
 if subject and subject.characterGUID and subject.characterGUID~=guid then return false end
 local r=root();local s=scope();if not s then return false end
 local owned=r.characterNamesByGUID and r.characterNamesByGUID[guid]
 if owned and direct.accountID~=r.id then return false end
 local canonical=owned or s.guids[guid]or sender;local previous=peers[canonical]
 if previous and previous.accountID and previous.accountID~=direct.accountID then return false end
 local target=previous or direct;local aliases=rewriteEvents(r,guid,canonical,A.guildKey);aliases[sender]=true
 for name,record in pairs(peers)do if record.characterGUID==guid then aliases[name]=true end end
 for name in pairs(aliases)do
  local old=peers[name]
  if old and(not old.characterGUID or old.characterGUID==guid)and(not old.accountID or old.accountID==direct.accountID)then
   if name~=canonical then archive(r,guid,name,old);merge(target,old,now);peers[name]=nil end
   s.names[name]=guid
  end
 end
 s.guids[guid]=canonical;s.names[canonical]=guid
 target.characterGUID=guid;target.accountID=direct.accountID
 if not target.aliasRev or(direct.aliasRev or 0)>=target.aliasRev then target.alias=direct.alias;target.aliasRev=direct.aliasRev end
 target.bindingDirect=target.bindingDirect or isDirect;target.observerOnly=false;peers[canonical]=target
 A.members[canonical]=true;A.ReconcileGuildMembership();return true
end
function A.ReceiveCharacterIdentity(msg,sender,now)
 local peers=A.PeerRecords();local source=peers[sender]
 if not source or not source.bindingDirect or not source.accountID then return false end
 local guid=msg:match('^6|C|(Player%-[%w%-]+)$')
 if guid then return bindGuildCharacter(guid,sender,source,now,true)end
 local encoded,altGUID=msg:match('^6|R|(%x+)|(Player%-[%w%-]+)$');local name=encoded and A.DecodeAlias(encoded)
 if not name or name==sender or not A.members[name]then return false end
 local target=peers[name]
 if not target or target.accountID~=source.accountID then return false end
 if A.account and A.account.characters[name]and source.accountID~=A.account.id then return false end
 return bindGuildCharacter(altGUID,name,source,now,false)
end
