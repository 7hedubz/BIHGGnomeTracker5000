local _,A=...
A.PREFIX='BIHGGKT5000'
function A.CommunicationBlocked()
 if type(InCombatLockdown)~='function'then return true end
 local ok,combat=pcall(InCombatLockdown)
 return not ok or A.Secret(combat)or not not combat
end
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
local function refresh()
 if A.RequestUIRefresh then A.RequestUIRefresh()elseif A.RefreshUI then A.RefreshUI()end
end
local function namespace()
 if A.syncNamespaceSet and A.syncNamespace~=A.guildKey then
  A.outgoing=nil;A.outIndex=nil;A.outFull=nil;A.rx={};A.rxGlobal=nil;A.queries={};A.peerSessions={}
  A.catchupPending=nil;A.lastFullReply=nil;A.lastRequest=nil;A.request=true;A.dirty=true;A.fullShare=true
  A.helloPending=nil;A.sendRetryAt=nil;A.sendFailures=0;A.groupPriorityBurst=0;A.groupControlTurn=nil;A.priorityRejected={}
 end
 A.syncNamespaceSet=true;A.syncNamespace=A.guildKey
end
local function catchup(now)
 if not A.lastFullReply or now<A.lastFullReply or now-A.lastFullReply>=60 then
  A.lastFullReply=now;A.catchupPending=nil;A.QueueShare(true)
 else A.catchupPending=true end
end
function A.Receive(msg,channel,sender,now)
 namespace()
 if A.guildUnverified then return false end
 if A.Secret and(A.Secret(msg)or A.Secret(channel)or A.Secret(sender))then return false end
 if A.ResolveGuildSender then sender=A.ResolveGuildSender(msg,channel,sender,now)end
 if A.CanonicalCharacterName and A.guildKey and type(sender)=='string'then
  local old=A.PeerRecords()[sender];sender=A.CanonicalCharacterName(sender,old and old.characterGUID)
 end
 if channel~='GUILD' or not A.guildKey or not A.members or not A.members[sender] or sender==A.owner or type(msg)~='string' or #msg>255 then return false end
 A.rx=A.rx or {}; local limit=A.rx[sender]
 if not limit or now<limit.start or now-limit.start>=60 then limit={start=now,n=0}; A.rx[sender]=limit end
 limit.n=limit.n+1; if limit.n>450 then return false end
 local global=A.rxGlobal
 if not global or now<global.start or now-global.start>=60 then global={start=now,n=0};A.rxGlobal=global end
 global.n=global.n+1;if global.n>900 then return false end
 if msg:sub(1,2)=='6|'then
  local ok=A.ReceiveCharacterIdentity and A.ReceiveCharacterIdentity(msg,sender,now)or false
  if ok then refresh()end;return ok
 end
 if msg:sub(1,2)=='5|'then return A.ReceiveGroup and A.ReceiveGroup(msg,sender,now)or false end
 if msg:sub(1,4)=='4|R|' then return A.ReceiveAlt and A.ReceiveAlt(msg,sender,now) or false end
 if msg:sub(1,2)=='3|' then
  local ok=A.ReceiveAccount and A.ReceiveAccount(msg,sender,now) or false
  if ok then refresh()end
  return ok
 end
 -- Optional session hint: old clients safely ignore H and still receive Q.
 -- Repeated light queries do not request another lifetime replay. Legacy peers
 -- retain a fifteen-minute catchup fallback; new/reloaded peers use a new H token.
 local session=msg:match('^2|H|([%w%.%-]+)$')
 if session and #session<=64 then
  A.peerSessions=A.peerSessions or {};local old=A.peerSessions[sender]
  if not old or old.token~=session then
   A.peerSessions[sender]={token=session,at=now};A.queries=A.queries or {};A.queries[sender]=now;catchup(now)
  end
  return true
 end
 if msg=='2|Q' then
  A.queries=A.queries or {}
  if not A.queries[sender] or now<A.queries[sender] or now-A.queries[sender]>=900 then
   A.queries[sender]=now;catchup(now)
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
  r.updated=now;refresh();return true
 end
 local k,d,day,dk,dd=msg:match('^2|S|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$')
 k=integer(k,1000000000); d=integer(d,1000000000); day=integer(day,1000000); dk=integer(dk,1000000000); dd=integer(dd,1000000000)
 if not k or not d or not day or not dk or not dd or dk>k or dd>d or day>A.Day(now) or day<A.Day(now)-A.RETENTION+1 then return false end
 local peers=A.PeerRecords(); local r=peers[sender] or {total=0,deaths=0,days={},deathDays={}}
 peers[sender]=r;r.observerOnly=false; r.total=math.max(r.total,k); r.deaths=math.max(r.deaths,d)
 r.days[day]=math.max(r.days[day] or 0,dk); r.deathDays[day]=math.max(r.deathDays[day] or 0,dd); r.updated=now
 refresh()
 return true
end
function A.EncounterScore(r,frame,now)
 if not r.encounterScores then return nil end
 if frame~='Lifetime' and A.Day(r.encounterStamp or 0)~=A.Day(now) then return nil end
 for i,label in ipairs(A.frames) do if label==frame then return r.encounterScores[i] end end
end
function A.QueueShare(full)
 if full and A.outgoing and A.outFull then A.dirty=true;A.fullShare=true;return end
 A.dirty=true; if full then A.fullShare=true end
end
-- Explicit UI/slash refresh must request remote catchup too; periodic Q stays light.
function A.RequestFullSync()
 A.request=true;A.syncSession=nil;A.helloPending=true;A.QueueShare(true)
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
-- One application budget covers both addon packets and automatic public alerts.
-- No catch-up burst after a pause: at most two calls/sec and 256 bytes/sec.
function A.TrySendBudget(now,bytes)
 local b=A.sendBudget
 if not b then b={at=now,next=now,bytes=512};A.sendBudget=b end
 if now<b.at then b.at=now;b.next=now+.5;b.bytes=0;return false end
 b.bytes=math.min(512,b.bytes+(now-b.at)*256);b.at=now
 if now<b.next or b.bytes<bytes then return false end
 b.bytes=b.bytes-bytes;b.next=now+.5;return true
end
local function validPacket(packet)
 return type(packet)=='string'and #packet>0 and #packet<=255 and not packet:find('[%z\r\n]')and type(A.PREFIX)=='string'and #A.PREFIX>0 and #A.PREFIX<=16
end
local function reject(packet)
 A.syncRejected=A.syncRejected or {};if #A.syncRejected>=20 then table.remove(A.syncRejected,1)end
 A.syncRejectedCount=(A.syncRejectedCount or 0)+1;A.outRejected=(A.outRejected or 0)+1
 A.syncRejected[#A.syncRejected+1]={packet=packet,guildKey=A.guildKey,reason='Invalid outgoing packet or prefix'}
 A.syncStatus='Invalid outgoing packet quarantined; inspect syncRejected'
end
function A.SendPacket(packet,now)
 if not validPacket(packet)then return false,'invalid'end
 if not A.guildKey or A.guildUnverified or A.CommunicationBlocked()then return false,'blocked'end
 if now==nil then
  local clock=type(GetServerTime)=='function'and GetServerTime or(type(time)=='function'and time)or(type(GetTime)=='function'and GetTime)or(os and os.time)
  local ok,value=pcall(clock or function()end)
  if not ok or A.Secret(value)or type(value)~='number'or value~=value or value==math.huge or value==-math.huge then return false,'clock'end
  now=value
 end
 if A.sendClock and now<A.sendClock then A.sendRetryAt=nil end;A.sendClock=now
 if A.sendRetryAt and now<A.sendRetryAt then return false,'backoff'end
 local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
 if not A.TrySendBudget(now,#packet+#A.PREFIX)then return false,'budget'end
 local ok,result=false,nil
 if type(fn)=='function'then ok,result=pcall(fn,A.PREFIX,packet,'GUILD')end
 local accepted=ok and not A.Secret(result)and(result==nil or result==true or result==0 or (Enum and Enum.SendAddonMessageResult and result==Enum.SendAddonMessageResult.Success))
 if accepted then A.sendFailures=0;A.sendRetryAt=nil;return true end
 A.sendFailures=math.min((A.sendFailures or 0)+1,6);A.sendRetryAt=now+math.min(60,2^A.sendFailures)
 return false,'retry'
end
function A.Pump(now)
 namespace()
 if A.guildUnverified then A.syncStatus='Guild identity pending; cached history only';return end
 if not A.guildKey then A.syncStatus='Waiting for guild membership';return end
 if A.CommunicationBlocked()then A.syncStatus='Sync paused until out of combat';return end
 if A.catchupPending then catchup(now)end
 if not A.lastRequest or now<A.lastRequest or now-A.lastRequest>=60 then
  A.request=true;if not A.lastRequest then A.QueueShare(true);A.helloPending=true end;A.lastRequest=now
 end
 if not A.outgoing and not A.dirty and(A.groupPriorityBurst or 0)>=4 then
  A.groupPriorityBurst=0;A.groupControlTurn=true
 end
 -- Fresh witnessed events should not sit behind a long historical replay.
 if not A.groupControlTurn and A.PriorityGroupPacket and(A.groupPriorityBurst or 0)<4 then
  local packet,id=A.PriorityGroupPacket()
  if packet then
   local sent,reason=A.SendPacket(packet,now)
   if reason=='invalid'then reject(packet);A.MarkGroupSent(id)
   elseif sent then A.MarkGroupSent(id);A.groupPriorityBurst=(A.groupPriorityBurst or 0)+1;A.syncStatus='Witnessed guild event shared';return
   else A.syncStatus='Witnessed event waiting / retrying';return end
  end
 end
 -- Keep the historical turn until it actually advances, including across
 -- insufficient refills, native backoff and combat. Control packets may not
 -- spend its reserved bytes; they get their own turn after history advances.
 local historicalTurn=(A.groupPriorityBurst or 0)>=4 and(A.outgoing or A.dirty)
 if not historicalTurn then
  if A.helloPending then
   A.syncSession=A.syncSession or(tostring(now)..tostring({}):gsub('[^%w]',''))
   if A.SendPacket('2|H|'..A.syncSession,now)then A.helloPending=nil end
   return
  end
  if A.request then
   if A.SendPacket('2|Q',now) then A.request=false else A.syncStatus='Sync request waiting / retrying'; return end
  end
  A.groupControlTurn=nil
 end
 if not A.outgoing and A.dirty then A.outFull=A.fullShare;A.outgoing=A.BuildPackets(A.fullShare,now); A.dirty=false; A.fullShare=false; A.outIndex=1 end
 if A.outgoing then
  local sent,reason=A.SendPacket(A.outgoing[A.outIndex],now)
  if sent or reason=='invalid'then
   if reason=='invalid'then reject(A.outgoing[A.outIndex])end
   A.groupPriorityBurst=0;if historicalTurn then A.groupControlTurn=true end
   A.outIndex=A.outIndex+1
   if A.outIndex>#A.outgoing then
    A.outgoing=nil
    A.syncStatus=(A.outRejected or 0)>0 and('Queue finished; '..A.outRejected..' invalid packets quarantined (not sent)')or('Sent '..date('%H:%M',math.floor(now))..' - member reports unverified')
    A.outRejected=nil
   end
  else A.syncStatus='Send blocked / retrying' end
 else A.syncStatus=A.syncStatus or 'Waiting for guild peers' end
end
