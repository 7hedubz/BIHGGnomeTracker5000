local _,A=...
local function short(name)return type(name)=='string' and (name:match('^([^-]+)') or name) or 'Unknown' end
function A.EncodeAlias(value)return (value:gsub('.',function(c)return string.format('%02x',string.byte(c))end))end
function A.DecodeAlias(value)
 if type(value)~='string' or #value==0 or #value>128 or #value%2~=0 or value:find('[^%x]') then return nil end
 local alias=value:gsub('%x%x',function(h)return string.char(tonumber(h,16))end)
 if alias:find('[%c|]') or alias:match('^%s*$') then return nil end
 return alias
end
local function clone(t)
 if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out
end
local function merge(target,source)
 target=target or {total=0,deaths=0,days={},deathDays={}}
 target.total=math.max(target.total or 0,source.total or 0);target.deaths=math.max(target.deaths or 0,source.deaths or 0)
 for _,key in ipairs({'days','deathDays'}) do
  target[key]=target[key] or {}
  for day,n in pairs(source[key] or {}) do target[key][day]=math.max(target[key][day] or 0,n) end
 end
 if source.guildBase and target~=source then
  local b=source.guildBase;local a=target.guildBase
  if not a then target.guildBase=clone(b)else
   local aHas=(a.total or 0)>0 or(a.deaths or 0)>0
   local bHas=(b.total or 0)>0 or(b.deaths or 0)>0
   local since=math.max(a.since or 0,b.since or 0)
   if aHas~=bHas then since=aHas and(a.since or 0)or(b.since or 0)end
   merge(a,b);a.since=since
  end
 end
 return target
end
function A.RememberKnownEncounter(guid,entry)
 if not A.account or not A.ValidEncounterRecord(guid,entry)then return end
 local cache=A.account.knownEncounters or{};A.account.knownEncounters=cache
 local old=cache[guid]
 if not old then old={days={}};cache[guid]=old;A.knownEncounterSize=(A.knownEncounterSize or 0)+1 end
 if not old.last or(entry.last or 0)>old.last then
  old.name=entry.name or old.name;old.race=entry.race or old.race
 else old.name=old.name or entry.name;old.race=old.race or entry.race end
 A.MergeEncounterMetadata(old,entry)
 local first=entry.first
 if(A.Secret and A.Secret(first))or type(first)~='number'or first~=first or first<0 or first>entry.last then first=entry.last end
 old.first=math.min(old.first or first,first)
 old.last=math.max(old.last or entry.last,entry.last)
 old.days=old.days or{}
 local days=entry.days
 if not(A.Secret and A.Secret(days))and type(days)=='table'and not(issecrettable and issecrettable(days))then
  for day in pairs(days)do if not(A.Secret and A.Secret(day))and type(day)=='number'and day==day and day>-math.huge and day<math.huge and day%1==0 then old.days[day]=true end end
 end
 if (A.knownEncounterSize or 0)>A.ENCOUNTER_LIMIT then A.PruneEncounters(A.encounterNow or A.now,true)end
end
function A.KnownEncounters()
 if not A.account then return A.db and A.db.seen or{}end
 for _,r in pairs(A.account.characters or{})do for guid,e in pairs(r.seen or{})do A.RememberKnownEncounter(guid,e)end end
 for guid,e in pairs(A.db.seen or{})do A.RememberKnownEncounter(guid,e)end
 return A.account.knownEncounters or{}
end
function A.InitAccount(account,id,now)
 account.version=1;account.id=account.id or id;account.alias=account.alias or short(A.owner)
 account.aliasRev=account.aliasRev or now;account.characters=account.characters or {};account.guilds=account.guilds or {}
 A.account=account
 A.PruneEncounters(now,true)
 if A.InitVersionNotice then A.InitVersionNotice(now)end
 if A.PrepareLocalIdentity then A.PrepareLocalIdentity(account,now)end
 local current,source=account.characters[A.owner],A.db.owners[A.owner]
 if current and current.characterGUID and source.characterGUID and current.characterGUID~=source.characterGUID then
  -- Without a readable full local identity there is no safe destination key.
  -- Leave both snapshots untouched rather than overwrite one with the other.
  A.identityConflict=true;return false
 end
 A.identityConflict=nil
 local r=merge(current,source);account.characters[A.owner]=r;A.db.owners[A.owner]=r
 local seen=r.seen or {};for guid,entry in pairs(A.db.seen or {}) do
  local old=seen[guid]
  if not old then seen[guid]=clone(entry) else
   A.MergeEncounterMetadata(old,entry)
   local newer=(entry.last or 0)>=(old.last or 0)
   old.first=math.min(old.first or entry.first,entry.first);old.last=math.max(old.last or entry.last,entry.last)
   if newer then old.name=entry.name or old.name;old.race=entry.race or old.race
   else old.name=old.name or entry.name;old.race=old.race or entry.race end
   old.days=old.days or {}
   for day in pairs(entry.days or {}) do old.days[day]=true end
  end
 end
 A.db.seen=seen;r.seen=seen
 -- Migrate already-known peer totals once without incrementing cumulative figures.
 for guild,records in pairs(A.db.guilds or {}) do
  account.guilds[guild]=account.guilds[guild] or {}
  for name,old in pairs(records) do
   local current=account.guilds[guild][name]
   if not current then account.guilds[guild][name]=old else
    merge(current,old)
    if (old.encounterStamp or 0)>(current.encounterStamp or 0) then current.encounterScores=old.encounterScores;current.encounterStamp=old.encounterStamp end
   end
  end
 end
 A.db.guilds=account.guilds
 local firstDay=A.Day(now)-A.RETENTION+1
 for _,record in pairs(account.characters) do
  for _,key in ipairs({'days','deathDays'}) do for day in pairs(record[key] or {}) do if day<firstDay then record[key][day]=nil end end end
  for _,entry in pairs(record.seen or {}) do for day in pairs(entry.days or {}) do if day<firstDay then entry.days[day]=nil end end end
 end
 A.SnapshotAccount(now)
 for _,entry in pairs(A.KnownEncounters())do for day in pairs(entry.days or{})do if day<firstDay then entry.days[day]=nil end end end
end
function A.SnapshotAccount(now)
 if not A.account or A.identityConflict then return end
 A.PruneEncounters(now,true)
 local r=A.db.owners[A.owner];r.seen=A.db.seen or {};r.updated=now
 A.account.characters[A.owner]=r
 for _,record in pairs(A.account.characters) do
  record.accountID=A.account.id;record.alias=A.account.alias;record.aliasRev=A.account.aliasRev
 end
end
function A.SetAlias(alias,now)
 if not A.account or type(alias)~='string' then return false end
 alias=alias:match('^%s*(.-)%s*$')
 if #alias<1 or #alias>64 or alias:find('[%c|]') then return false end
 A.account.alias=alias;A.account.aliasRev=math.max(now,(A.account.aliasRev or 0)+1)
 A.SnapshotAccount(now)
 A.outgoing=nil -- Rebuild the queue so an old multipart job cannot delay a rename.
 if A.QueueShare then A.QueueShare(true) end
 if A.RefreshUI then A.RefreshUI()end
 return true
end
function A.AccountEncounterCount(period,now,members)
 A.PruneEncounters(now,false)
 members=members or A.members
 local identities={};local first=A.FirstDay(period,now);local today=A.Day(now)
 local chars=A.account and A.account.characters or {[A.owner]={seen=A.db.seen}}
 for name,r in pairs(chars) do
  if not members or members[name] then
   for guid,entry in pairs(r.seen or {}) do if entry.race=='Gnome' then
    if period=='Lifetime' then identities[guid]=true else
     for day in pairs(entry.days or {}) do if day>=first and day<=today then identities[guid]=true;break end end
    end
   end end
  end
 end
 local n=0;for _ in pairs(identities) do n=n+1 end;return n
end
function A.AccountPackets(now)
 if not A.account then return {} end
 A.SnapshotAccount(now)
 local out={'3|I|'..A.account.id..'|'..A.EncodeAlias(A.account.alias)..'|'..A.account.aliasRev}
 local unique={'3','U',A.account.id,tostring(now)}
 for _,period in ipairs(A.frames) do unique[#unique+1]=tostring(A.AccountEncounterCount(period,now,A.members)) end
 out[#out+1]=table.concat(unique,'|');if A.CharacterIdentityPacket then local packet=A.CharacterIdentityPacket();if packet then out[#out+1]=packet end end;return out
end
function A.ReceiveAccount(msg,sender,now)
 local id,encoded,rev=msg:match('^3|I|([%w_%-]+)|(%x+)|(%d+)$')
 if id then
  local alias=A.DecodeAlias(encoded);rev=tonumber(rev)
  if #id>80 or not alias or not rev or rev>4102444800 then return false end
  local peers=A.PeerRecords();local r=peers[sender] or {total=0,deaths=0,days={},deathDays={}};peers[sender]=r
  -- A character's direct declaration takes precedence over an inherited alt claim.
  if not r.bindingDirect or not r.aliasRev or rev>=r.aliasRev then
   if r.accountID~=id then r.accountEncounterScores=nil;r.accountEncounterStamp=nil end
   r.accountID=id;r.alias=alias;r.aliasRev=rev
  end
  r.bindingDirect=true;r.observerOnly=false;r.updated=now;return true
 end
 local fields={};for s in msg:gmatch('[^|]+') do fields[#fields+1]=s end
 if fields[1]~='3' or fields[2]~='U' or #fields~=11 then return false end
 local r=A.PeerRecords()[sender];id=fields[3];local stamp=tonumber(fields[4])
 if not r or r.accountID~=id or not fields[4]:match('^%d+$') or not stamp or stamp>now+60 or stamp<now-86400 then return false end
 local scores={}
 for i=1,7 do
  local raw=fields[i+4];local n=tonumber(raw)
  if not raw:match('^%d+$') or not n or n>1000000000 or (i>1 and n>scores[1]) then return false end
  scores[i]=n
 end
 if not r.accountEncounterStamp or stamp>=r.accountEncounterStamp then r.accountEncounterScores=scores;r.accountEncounterStamp=stamp end
 return true
end
-- Read-only selection is deliberately separate from the live guild identity
-- used by transport, contribution tracking and report authorization.
function A.ViewGuildKey()
 if A.guildKey then return A.guildKey end
 if not A.account then return end
 local realm=A.Safe and A.Safe(GetNormalizedRealmName)or nil
 realm=realm or(type(A.owner)=='string'and A.owner:match('%-(.+)$'))
 if type(realm)~='string'or realm==''then return end
 local suffix='-'..realm;local guilds=A.account.guilds or{}
 local preferred=(A.account.viewGuilds or{})[realm]
 if preferred and guilds[preferred]and preferred:sub(-#suffix)==suffix then return preferred end
 local selected
 for key in pairs(guilds)do if key:sub(-#suffix)==suffix then if selected then return end;selected=key end end
 return selected
end
function A.ViewPeerRecords()
 local key=A.ViewGuildKey();if not key then return{}end
 if key==A.guildKey then return A.PeerRecords()end
 return(A.account.guilds or{})[key]or{}
end
function A.ViewGuildMembers()
 if A.guildKey then return A.members or{}end
 local key=A.ViewGuildKey();if not key then return{}end
 local cache=(A.account.guildMembership or{})[key];local members={}
 local identities=(A.account.guildIdentities or{})[key]or{}
 for name,present in pairs(cache and cache.members or A.ViewPeerRecords())do if present then
  local guid=(cache and cache.guids or{})[name]or(identities.names or{})[name]
  local canonical=guid and((A.account.characterNamesByGUID or{})[guid]or(identities.guids or{})[guid])or name
  members[canonical or name]=true
 end end
 return members
end
function A.LeaderboardGroups(period,now)
 if A.account then A.SnapshotAccount(now) end
 local records={}
 local members=A.ViewGuildMembers();local viewKey=A.ViewGuildKey()
 for name,r in pairs(A.ViewPeerRecords()) do if members[name] then records[name]=r end end
 if A.account then for name,r in pairs(A.account.characters) do if members[name] then records[name]=r end end
 elseif A.members and A.members[A.owner] then records[A.owner]=A.db.owners[A.owner] end
 local groups={}
 for name,r in pairs(records) do
  local key=r.accountID and 'account:'..r.accountID or 'character:'..name
  local g=groups[key]
  if not g then g={id=key,name=r.alias or short(name),aliasRev=-1,k=0,d=0,children={},isGroup=true,encountered=-1};groups[key]=g end
  if r.alias and (r.aliasRev or 0)>=g.aliasRev then g.name=r.alias;g.aliasRev=r.aliasRev or 0 end
  local effective=A.GuildEffectiveRecord and A.GuildEffectiveRecord(name,r,now,viewKey)or r
  local k=A.Score(effective,period,now);local d=A.Score(effective,period,now,'deaths')
  local encountered=name==A.owner and A.EncounterCount(period,now) or A.EncounterScore(r,period,now)
  if A.account and A.account.characters[name] then
   local identities={};local first=A.FirstDay(period,now);local today=A.Day(now)
   for guid,e in pairs(r.seen or {}) do if e.race=='Gnome' then
    if period=='Lifetime' then identities[guid]=true else for day in pairs(e.days or {}) do if day>=first and day<=today then identities[guid]=true;break end end end
   end end
   encountered=0;for _ in pairs(identities) do encountered=encountered+1 end
  end
  g.children[#g.children+1]={name=name,k=k,d=d,kd=d>0 and k/d or (k>0 and math.huge or 0),encountered=encountered or -1,isOwn=name==A.owner,observed=r.observerOnly}
  g.observed=g.observed or r.observerOnly
  g.k=g.k+k;g.d=g.d+d;g.isOwn=g.isOwn or name==A.owner
  if r.accountEncounterScores and (period=='Lifetime' or A.Day(r.accountEncounterStamp)==A.Day(now)) and (not g.encounterStamp or r.accountEncounterStamp>g.encounterStamp) then
   for i,label in ipairs(A.frames) do if label==period then g.encountered=r.accountEncounterScores[i];g.encounterStamp=r.accountEncounterStamp end end
  end
 end
 local out={}
 for _,g in pairs(groups) do
  if A.account and g.id=='account:'..A.account.id then g.encountered=A.AccountEncounterCount(period,now,members)
  elseif #g.children==1 and g.encountered<0 then g.encountered=g.children[1].encountered end
  g.kd=g.d>0 and g.k/g.d or (g.k>0 and math.huge or 0)
  table.sort(g.children,function(a,b)return a.name<b.name end);out[#out+1]=g
 end
 return out
end
-- Only the local account's known alts are sent, never arbitrary cached guild peers.
function A.CharacterEncounterCount(r,period,now)
 local n=0;local first=A.FirstDay(period,now);local today=A.Day(now)
 for _,e in pairs(r.seen or {}) do if e.race=='Gnome' then
  local include=period=='Lifetime'
  for day in pairs(e.days or {}) do if day>=first and day<=today then include=true;break end end
  if include then n=n+1 end
 end end
 return n
end
function A.AltPackets(now)
 local packets={};if not A.account then return packets end
 local today=A.Day(now);local names={}
 for name in pairs(A.account.characters) do if name~=A.owner and A.members and A.members[name] then names[#names+1]=name end end
 table.sort(names)
 for _,name in ipairs(names) do
  local r=A.account.characters[name];local prefix='4|R|'..A.EncodeAlias(name)..'|'
  local encounter={'2','E',tostring(now)}
  for _,period in ipairs(A.frames) do encounter[#encounter+1]=tostring(A.CharacterEncounterCount(r,period,now)) end
  packets[#packets+1]=prefix..table.concat(encounter,'|')
  local days={[today]=true}
  for _,key in ipairs({'days','deathDays'}) do for day in pairs(r[key] or {}) do if day>=today-A.RETENTION+1 and day<=today then days[day]=true end end end
  local sorted={};for day in pairs(days) do sorted[#sorted+1]=day end;table.sort(sorted,function(a,b)return a>b end)
  for _,day in ipairs(sorted) do packets[#packets+1]=prefix..string.format('2|S|%d|%d|%d|%d|%d',r.total,r.deaths or 0,day,(r.days or {})[day] or 0,(r.deathDays or {})[day] or 0) end
  if type(r.characterGUID)=='string'and r.characterGUID:match('^Player%-[%w%-]+$')then packets[#packets+1]='6|R|'..A.EncodeAlias(name)..'|'..r.characterGUID end
 end
 return packets
end
function A.ReplayAltScores(sender,name,now)
 local pending=A.pendingAltScores or {};local keep={}
 for _,p in ipairs(pending)do
  if now-p.time<=60 and p.guild==A.guildKey then
   if p.sender==sender and p.name==name then
    local source=A.PeerRecords()[sender]
    if source and source.accountID==p.accountID then A.ReceiveAlt(p.msg,sender,now)end
   else keep[#keep+1]=p end
  end
 end
 A.pendingAltScores=keep
end
function A.ReceiveAlt(msg,sender,now)
 local encoded,payload=msg:match('^4|R|(%x+)|(2|[SE]|.+)$')
 local name=encoded and A.DecodeAlias(encoded)
 if name and A.CanonicalCharacterName then local old=A.PeerRecords()[name];name=A.CanonicalCharacterName(name,old and old.characterGUID)end
 local source=A.PeerRecords()[sender]
 if not name or not source or not source.accountID or not source.bindingDirect then return false end
 if not A.members[name]then
  -- Scores contain no GUID: retain a bounded, short-lived untrusted payload,
  -- never a member/record, until the same validated account supplies metadata.
  local pending={};for _,p in ipairs(A.pendingAltScores or {})do if now-p.time<=60 and p.guild==A.guildKey and p.msg~=msg then pending[#pending+1]=p end end
  while #pending>=64 do table.remove(pending,1)end
  pending[#pending+1]={sender=sender,accountID=source.accountID,name=A.DecodeAlias(encoded),msg=msg,time=now,guild=A.guildKey};A.pendingAltScores=pending
  return false
 end
 if name==A.owner or name==sender then return false end
 if A.account and A.account.characters[name] and source.accountID~=A.account.id then return false end
 local peers=A.PeerRecords();local existing=peers[name]
 if existing and existing.accountID and existing.accountID~=source.accountID then return false end
 local ok=A.Receive(payload,'GUILD',name,now)
 if not ok then return false end
 local r=peers[name];r.accountID=source.accountID
 if not r.aliasRev or (source.aliasRev or 0)>=r.aliasRev then r.alias=source.alias;r.aliasRev=source.aliasRev end
 if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
 return true
end
