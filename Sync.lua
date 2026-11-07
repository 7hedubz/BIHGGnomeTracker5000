local _,A=...
A.PREFIX='BIHGGKT5000'
local function integer(s,max)
 if type(s)~='string' or not s:match('^%d+$') then return nil end
 local n=tonumber(s); if n and n<=max then return n end
end
function A.PeerRecords()
 A.db.guilds=A.db.guilds or {}
 if not A.guildKey then return {} end
 A.db.guilds[A.guildKey]=A.db.guilds[A.guildKey] or {}
 return A.db.guilds[A.guildKey]
end
function A.Receive(msg,channel,sender,now)
 if A.guildUnverified then return false end
 if A.CanonicalCharacterName and A.guildKey and type(sender)=='string'then
  local old=A.PeerRecords()[sender];sender=A.CanonicalCharacterName(sender,old and old.characterGUID)
 end
 if channel~='GUILD' or not A.guildKey or not A.members or not A.members[sender] or sender==A.owner or type(msg)~='string' or #msg>255 then return false end
 A.rx=A.rx or {}; local limit=A.rx[sender]
 if not limit or now-limit.start>=60 then limit={start=now,n=0}; A.rx[sender]=limit end
 limit.n=limit.n+1; if limit.n>450 then return false end
 if msg:sub(1,2)=='6|'then
  local ok=A.ReceiveCharacterIdentity and A.ReceiveCharacterIdentity(msg,sender,now)or false
  if ok and A.RefreshUI then A.RefreshUI()end;return ok
 end
 if msg:sub(1,2)=='5|'then return A.ReceiveGroup and A.ReceiveGroup(msg,sender,now)or false end
 if msg:sub(1,4)=='4|R|' then return A.ReceiveAlt and A.ReceiveAlt(msg,sender,now) or false end
 if msg:sub(1,2)=='3|' then
  local ok=A.ReceiveAccount and A.ReceiveAccount(msg,sender,now) or false
  if ok and A.RefreshUI then A.RefreshUI() end
  return ok
 end
 if msg=='2|Q' then
  A.queries=A.queries or {}
  if not A.queries[sender] or now-A.queries[sender]>=60 then
   A.queries[sender]=now
   if not A.lastFullReply or now-A.lastFullReply>=60 then A.lastFullReply=now;A.QueueShare(true) end
  end
  return true
 end
 if msg:sub(1,4)=='2|E|' then
  local fields={};for s in msg:gmatch('[^|]+') do fields[#fields+1]=s end
  if #fields~=10 then return false end
  local stamp=integer(fields[3],4102444800)
  if not stamp or stamp>now+60 or stamp<now-86400 then return false end
  local scores={}
  for i=1,7 do scores[i]=integer(fields[i+3],1000000000);if not scores[i] or (i>1 and scores[i]>scores[1]) then return false end end
  local peers=A.PeerRecords();local r=peers[sender] or {total=0,deaths=0,days={},deathDays={}};peers[sender]=r
  if not r.encounterStamp or stamp>=r.encounterStamp then r.encounterStamp=stamp;r.encounterScores=scores end
  r.updated=now;if A.RefreshUI then A.RefreshUI() end;return true
 end
 local k,d,day,dk,dd=msg:match('^2|S|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$')
 k=integer(k,1000000000); d=integer(d,1000000000); day=integer(day,1000000); dk=integer(dk,1000000000); dd=integer(dd,1000000000)
 if not k or not d or not day or not dk or not dd or dk>k or dd>d or day>A.Day(now) or day<A.Day(now)-A.RETENTION+1 then return false end
 local peers=A.PeerRecords(); local r=peers[sender] or {total=0,deaths=0,days={},deathDays={}}
 peers[sender]=r;r.observerOnly=false; r.total=math.max(r.total,k); r.deaths=math.max(r.deaths,d)
 r.days[day]=math.max(r.days[day] or 0,dk); r.deathDays[day]=math.max(r.deathDays[day] or 0,dd); r.updated=now
 if A.RefreshUI then A.RefreshUI() end
 return true
end
function A.EncounterScore(r,frame,now)
 if not r.encounterScores then return nil end
 if frame~='Lifetime' and A.Day(r.encounterStamp or 0)~=A.Day(now) then return nil end
 for i,label in ipairs(A.frames) do if label==frame then return r.encounterScores[i] end end
end
function A.QueueShare(full)
 if full and A.outgoing and A.outFull then A.dirty=true;return end
 A.dirty=true; if full then A.fullShare=true end
end
function A.BuildPackets(full,now)
 local r=A.db.owners[A.owner]; local today=A.Day(now); local days={[today]=true}
 if full then
  for day in pairs(r.days) do if day>=today-A.RETENTION+1 then days[day]=true end end
  for day in pairs(r.deathDays or {}) do if day>=today-A.RETENTION+1 then days[day]=true end end
 end
 local sorted={}; for day in pairs(days) do sorted[#sorted+1]=day end; table.sort(sorted,function(a,b)return a>b end)
 local result=A.AccountPackets and A.AccountPackets(now) or {}
 local encounter={'2','E',tostring(now)}
 for _,label in ipairs(A.frames) do encounter[#encounter+1]=tostring(A.EncounterCount(label,now)) end
 result[#result+1]=table.concat(encounter,'|')
 for _,day in ipairs(sorted) do result[#result+1]=string.format('2|S|%d|%d|%d|%d|%d',r.total,r.deaths or 0,day,r.days[day] or 0,(r.deathDays or {})[day] or 0) end
 if full and A.AltPackets then for _,packet in ipairs(A.AltPackets(now)) do result[#result+1]=packet end end
 if A.GroupPackets then for _,packet in ipairs(A.GroupPackets(full,now))do result[#result+1]=packet end end
 return result
end
function A.SendPacket(packet)
 if not A.guildKey or A.guildUnverified or A.Safe(IsInInstance)~=false then return false end
 local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
 if not fn then return false end
 local ok,result=pcall(fn,A.PREFIX,packet,'GUILD')
 if not ok or A.Secret(result) then return false end
 return result==nil or result==true or result==0 or (Enum and Enum.SendAddonMessageResult and result==Enum.SendAddonMessageResult.Success)
end
function A.Pump(now)
 if A.guildUnverified then A.syncStatus='Guild identity pending; cached history only';return end
 if not A.guildKey or A.Safe(IsInInstance) then A.syncStatus='Queued until outside instance / in guild'; return end
 -- Fresh witnessed events should not sit behind a long historical replay.
 if A.PriorityGroupPacket and(A.groupPriorityBurst or 0)<4 then
  local packet,id=A.PriorityGroupPacket()
  if packet then
   if A.SendPacket(packet)then A.MarkGroupSent(id);A.groupPriorityBurst=(A.groupPriorityBurst or 0)+1;A.syncStatus='Witnessed guild event shared'
   else A.syncStatus='Witnessed event waiting / retrying'end
   return
  end
 end
 A.groupPriorityBurst=0
 if not A.lastRequest or now-A.lastRequest>=60 then A.request=true; A.fullShare=true; A.dirty=true; A.lastRequest=now end
 if A.request then
  if A.SendPacket('2|Q') then A.request=false else A.syncStatus='Sync request waiting / retrying'; return end
 end
 if not A.outgoing and A.dirty then A.outFull=A.fullShare;A.outgoing=A.BuildPackets(A.fullShare,now); A.dirty=false; A.fullShare=false; A.outIndex=1 end
 if A.outgoing then
  if A.SendPacket(A.outgoing[A.outIndex]) then
   A.outIndex=A.outIndex+1
   if A.outIndex>#A.outgoing then A.outgoing=nil; A.syncStatus='Sent '..date('%H:%M',now)..' - member reports unverified' end
  else A.syncStatus='Send blocked / retrying' end
 else A.syncStatus=A.syncStatus or 'Waiting for guild peers' end
end
