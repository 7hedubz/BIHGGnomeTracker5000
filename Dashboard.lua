local _,A=...
function A.TopKillers(period,now)
 local ranked={}
 for _,g in ipairs(A.LeaderboardGroups(period,now)) do if g.k>0 then ranked[#ranked+1]=g end end
 table.sort(ranked,function(a,b)if a.k~=b.k then return a.k>b.k end;if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
 while #ranked>10 do table.remove(ranked) end
 return ranked
end
function A.BuildTopReport(period,now)
 local ranked=A.TopKillers(period,now)
 if #ranked==0 then return {'BIHG: No recorded Gnome kills for '..period..' (cached addon reports).'} end
 local lines={string.format('BIHG Top %d Gnome killers - %s (cached addon reports)',#ranked,period)}
 for i,g in ipairs(ranked) do
  local name=(g.name or 'Unknown'):gsub('[%c|]','')
  lines[#lines+1]=string.format('#%d %s: %d kills',i,name,g.k)
 end
 return lines
end
function A.ActivityTrend(period,now)
 local today=A.Day(now);local first=math.max(today-29,A.FirstDay(period,now));local data={}
 local records={}
 for name,r in pairs(A.account and A.account.characters or {[A.owner]=A.db.owners[A.owner]})do if A.members and A.members[name]then records[#records+1]=A.GuildEffectiveRecord and A.GuildEffectiveRecord(name,r,now)or r end end
 for day=first,today do
  local k,d=0,0
  for _,r in ipairs(records)do k=k+((r.days or {})[day]or 0);d=d+((r.deathDays or {})[day]or 0)end
  data[#data+1]={day=day,kills=k,deaths=d}
 end
 return data
end
function A.KillsLine(period,now,width,height)
 local data=A.ActivityTrend(period,now);local peak=0
 for _,d in ipairs(data) do peak=math.max(peak,d.kills) end
 local step=math.max(1,math.ceil(peak/4));local ceiling=step*4
 local result={points={},ticks={},peak=peak,ceiling=ceiling}
 for i=0,4 do result.ticks[#result.ticks+1]=i*step end
 for i,d in ipairs(data) do
  result.points[i]={day=d.day,kills=d.kills,x=#data==1 and width/2 or (i-1)/(#data-1)*width,y=d.kills/ceiling*height}
 end
 return result
end
function A.CanPostTopReport()
 if not A.guildKey or A.guildUnverified or (IsInGuild and A.Safe(IsInGuild)~=true)or type(GetGuildInfo)~='function'then return false end
 local ok,guild,rank=pcall(GetGuildInfo,'player')
 if not ok or A.Secret(guild)or A.Secret(rank)or type(guild)~='string'or guild==''or type(rank)~='string'then return false end
 if A.guildName and guild~=A.guildName then return false end
 return rank=='Council of BIHG'or rank=='The BIHG Cheese'
end
local function reportDiagnostic()
 if not A.db then return {}end
 A.db.reportDiagnostics=type(A.db.reportDiagnostics)=='table'and A.db.reportDiagnostics or {}
 return A.db.reportDiagnostics
end
local function reportValue(value)
 if A.Secret(value)then return '<secret>'end
 local kind=type(value)
 if kind=='string'then return value:gsub('[%c|]',' '):sub(1,180)end
 if kind=='nil'or kind=='boolean'or kind=='number'then return tostring(value)end
 return '<'..kind..'>'
end
function A.RecordReportRestriction(event,addon,func,now)
 if A.Secret(addon)or addon~='BIHGGnomeKillTracker5000'then return end
 local value={event=reportValue(event),func=reportValue(func),at=now}
 if A.db then reportDiagnostic().restriction=value else A.pendingReportRestriction=value end
 if A.postJob and A.postJob.sending then A.postJob.blocked=value end
end
function A.ReportDebugLines()
 local d=reportDiagnostic();local job=A.postJob
 local combatValue='unavailable';if type(InCombatLockdown)=='function'then local ok,v=pcall(InCombatLockdown);combatValue=(ok and''or'error: ')..reportValue(v)end
 local guildValue,rankValue='unavailable','unavailable'
 if type(GetGuildInfo)=='function'then local ok,g,r=pcall(GetGuildInfo,'player');guildValue=reportValue(g);rankValue=ok and reportValue(r)or'API error'end
 if A.pendingReportRestriction then d.restriction=A.pendingReportRestriction;A.pendingReportRestriction=nil end
 local restriction=d.restriction
 return{
  'BIHG report status: '..reportValue(A.postStatus or'No request this login'),
  'BIHG report requests='..reportValue(d.requests or 0)..' last='..reportValue(d.requestAt)..' queue=none active='..(job and(job.index..'/'..#job.lines)or'none')..' mode='..reportValue(d.mode or'not called'),
  'BIHG report allowed='..tostring(A.CanPostTopReport())..' combatPaused='..tostring(A.CommunicationBlocked())..' combatAPI='..type(InCombatLockdown)..' raw='..combatValue..' guildVerified='..tostring(A.guildKey~=nil and not A.guildUnverified),
  'BIHG guild='..guildValue..' rank='..rankValue..' IsInGuild='..reportValue(A.Safe(IsInGuild)),
  'BIHG chat APIs: global='..type(SendChatMessage)..' modern='..type(C_ChatInfo and C_ChatInfo.SendChatMessage)..' last='..reportValue(d.api or'not called'),
  'BIHG send calls='..reportValue(d.sendCalls or 0)..' last='..reportValue(d.sendAt)..' line='..reportValue(d.line)..' result='..reportValue(d.result)..' error='..reportValue(d.error),
  'BIHG protected action: '..(restriction and(restriction.event..' '..restriction.func..' at '..reportValue(restriction.at))or'none captured'),
 }
end
function A.StartTopPost(lines,now)
 local diagnostic=reportDiagnostic();diagnostic.requests=(diagnostic.requests or 0)+1;diagnostic.requestAt=now
 if not A.guildKey or (IsInGuild and A.Safe(IsInGuild)~=true) then A.postStatus='Join a guild before posting.';return false end
 if not A.CanPostTopReport()then A.postStatus='Guild reports are restricted to Council of BIHG and The BIHG Cheese.';return false end
 if A.CommunicationBlocked()then A.postStatus='Leave combat before posting to guild.';return false end
 if A.postJob then A.postStatus='A guild report is already being sent.';return false end
 local last=A.db.options.lastTopPost
 if last and now-last<60 then A.postStatus='Please wait 60 seconds between guild reports.';return false end
 if type(lines)~='table' or #lines<1 or #lines>11 then A.postStatus='Guild report rejected: invalid line count.';return false end
 local copy={}
 for i,line in ipairs(lines) do if type(line)~='string' or #line>255 or line:find('[\r\n]') then A.postStatus='Guild report rejected: invalid chat line '..i..'.';return false end;copy[i]=line end
 local send=SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
 diagnostic.api=SendChatMessage and'SendChatMessage'or'C_ChatInfo.SendChatMessage'
 if type(send)~='function'then A.postStatus='Guild report stopped: chat API unavailable.';return false end
 A.db.options.lastTopPost=now
 -- Keep all native chat calls on the confirming click's call stack. This is
 -- an in-flight/reentrancy marker, not a timer queue; nothing resumes later.
 local job={lines=copy,index=1,guild=A.guildKey};A.postJob=job;diagnostic.mode='direct-click'
 for i,line in ipairs(copy)do
  if A.guildKey~=job.guild or A.CommunicationBlocked()or not A.CanPostTopReport()then
   A.postJob=nil;A.postStatus='Guild report stopped: combat, guild or authorized rank changed; no automatic retries.';return false
  end
  job.index=i;diagnostic.sendCalls=(diagnostic.sendCalls or 0)+1;diagnostic.sendAt=now;diagnostic.line=i
  job.sending=true;local ok,result=pcall(send,line,'GUILD');job.sending=nil
  diagnostic.result=ok and reportValue(result)or'threw';diagnostic.error=not ok and reportValue(result)or nil
  if job.blocked then
   diagnostic.error='Native '..job.blocked.event..' '..job.blocked.func
   A.postJob=nil;A.postStatus='Guild report stopped: client blocked chat; no automatic retries.';return false
  end
  if not ok or A.Secret(result)or result==false or(type(result)=='number'and result~=0)then
   A.postJob=nil;A.postStatus='Guild report stopped: chat send failed; no automatic retries.';return false
  end
 end
 A.postJob=nil;A.postStatus='Guild report send attempted directly ('..#copy..' lines); delivery unconfirmed.'
 return true
end
