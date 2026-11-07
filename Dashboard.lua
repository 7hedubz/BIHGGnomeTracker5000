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
 local current=''
 for i,g in ipairs(ranked) do
  local name=(g.name or 'Unknown'):gsub('[%c|]','')
  local entry=string.format('#%d %s: %d kills',i,name,g.k)
  if current~='' and (#current+#entry+3>240 or i%2==1) then lines[#lines+1]=current;current='' end
  current=current=='' and entry or current..' ; '..entry
 end
 if current~='' then lines[#lines+1]=current end
 return lines
end
function A.ActivityTrend(period,now)
 local today=A.Day(now);local first=math.max(today-29,A.FirstDay(period,now));local data={}
 for day=first,today do
  local k,d=0,0
  for _,r in pairs(A.account and A.account.characters or {[A.owner]=A.db.owners[A.owner]}) do k=k+((r.days or {})[day] or 0);d=d+((r.deathDays or {})[day] or 0) end
  data[#data+1]={day=day,kills=k,deaths=d}
 end
 return data
end
function A.StartTopPost(lines,now)
 if not A.guildKey or (IsInGuild and A.Safe(IsInGuild)~=true) then A.postStatus='Join a guild before posting.';return false end
 if A.Safe(IsInInstance)~=false then A.postStatus='Leave the instance before posting to guild.';return false end
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
 if A.guildKey~=job.guild or A.Safe(IsInInstance)~=false or now-job.created>120 then A.postJob=nil;A.postStatus='Guild report stopped: guild/instance changed or report expired.';return end
 local send=SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
 if type(send)~='function' then A.postJob=nil;A.postStatus='Guild report stopped: chat API unavailable.';return end
 local ok,result=pcall(send,job.lines[job.index],'GUILD')
 if not ok or A.Secret(result) or result==false or (type(result)=='number' and result~=0) then A.postJob=nil;A.postStatus='Guild report stopped: chat send failed; no automatic retries.';return end
 job.index=job.index+1;job.next=now+1
 if job.index>#job.lines then A.postStatus='Report handed to guild chat ('..#job.lines..' lines).';A.postJob=nil end
end
