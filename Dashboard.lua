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
function A.StartTopPost(lines,now)
 if not A.guildKey or (IsInGuild and A.Safe(IsInGuild)~=true) then A.postStatus='Join a guild before posting.';return false end
 if not A.CanPostTopReport()then A.postStatus='Guild reports are restricted to Council of BIHG and The BIHG Cheese.';return false end
 if A.CommunicationBlocked()then A.postStatus='Leave combat before posting to guild.';return false end
 if A.postJob then A.postStatus='A guild report is already being sent.';return false end
 local last=A.db.options.lastTopPost
 if last and now-last<60 then A.postStatus='Please wait 60 seconds between guild reports.';return false end
 if type(lines)~='table' or #lines<1 or #lines>11 then return false end
 local copy={}
 for i,line in ipairs(lines) do if type(line)~='string' or #line>255 or line:find('[\r\n]') then return false end;copy[i]=line end
 A.db.options.lastTopPost=now
 A.postJob={lines=copy,index=1,created=now,next=now,guild=A.guildKey};A.postStatus='Guild report queued: '..#copy..' lines.'
 return true
end
function A.PumpTopPost(now)
 local job=A.postJob;if not job or now<job.next then return end
 if A.guildKey~=job.guild or now-job.created>120 then A.postJob=nil;A.postStatus='Guild report stopped: guild changed or report expired.';return end
 if A.CommunicationBlocked()then A.postStatus='Guild report paused until out of combat.';return end
 if not A.CanPostTopReport()then A.postJob=nil;A.postStatus='Guild report stopped: authorized guild rank unavailable or changed.';return end
 local send=SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
 if type(send)~='function' then A.postJob=nil;A.postStatus='Guild report stopped: chat API unavailable.';return end
 local ok,result=pcall(send,job.lines[job.index],'GUILD')
 if not ok or A.Secret(result) or result==false or (type(result)=='number' and result~=0) then A.postJob=nil;A.postStatus='Guild report stopped: chat send failed; no automatic retries.';return end
 job.index=job.index+1;job.next=now+1
 A.postStatus='Guild report sending: '..(job.index-1)..'/'..#job.lines..' lines handed off.'
 if job.index>#job.lines then A.postStatus='Report handed to guild chat ('..#job.lines..' lines).';A.postJob=nil end
end
