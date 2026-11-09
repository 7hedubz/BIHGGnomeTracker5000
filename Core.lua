local _, A = ...
A.VERSION='1.7.10'
A.RETENTION = 400
A.DAMAGE_FRACTION = 0.02
A.frames = {'Lifetime','7 days','30 days','Today','This week','This month','This year'}
function A.Day(t) return math.floor(t / 86400) end
function A.Init(db, owner, now)
 db.version=1; db.owners=db.owners or {}; db.dead=db.dead or {}; db.options=db.options or {}
 A.db=db; A.owner=owner; A.now=now
 db.owners[owner]=db.owners[owner] or {total=0,days={}}
 A.encounters={}
 local records={}
 for _,r in pairs(db.owners) do records[#records+1]=r end
 for _,guild in pairs(db.guilds or {}) do for _,r in pairs(guild) do records[#records+1]=r end end
 for _,r in ipairs(records) do
  r.days=r.days or {};r.deathDays=r.deathDays or {}
  for _,buckets in ipairs({r.days,r.deathDays}) do
   for d in pairs(buckets) do if tonumber(d)<A.Day(now)-A.RETENTION+1 then buckets[d]=nil end end
  end
 end
 for g,t in pairs(db.dead) do if now-t>86400 then db.dead[g]=nil end end
 for _,r in pairs(db.seen or {}) do for d in pairs(r.days or {}) do if d<A.Day(now)-A.RETENTION+1 then r.days[d]=nil end end end
end
function A.Award(now)
 local r=A.db.owners[A.owner]; local d=A.Day(now)
 r.total=r.total+1; r.days[d]=(r.days[d] or 0)+1
 if A.Changed then A.Changed() end
end
function A.PlayerDeath(id,race,now,killer)
 if A.GroupOwnDeath then return A.GroupOwnDeath(id,race,now,killer)end
 if race~='Gnome' or type(id)~='string' then return false end
 A.db.recaps=A.db.recaps or {}
 if A.db.recaps[id] then return false end
 A.db.recaps[id]=now
 for k,t in pairs(A.db.recaps) do if now-t>86400 then A.db.recaps[k]=nil end end
 local r=A.db.owners[A.owner]; r.deaths=(r.deaths or 0)+1
 r.deathDays=r.deathDays or {}; local d=A.Day(now)
 r.deathDays[d]=(r.deathDays[d] or 0)+1
 if A.Changed then A.Changed() end
 return true
end
function A.Score(r,frame,now,metric)
 if metric=='deaths' then r={total=r.deaths or 0,days=r.deathDays or {}} end
 if frame=='Lifetime' then return r.total end
 local today=A.Day(now); local first=today
 if frame=='7 days' then first=today-6
 elseif frame=='30 days' then first=today-29
 elseif frame=='This week' then first=today-((today+3)%7)
 elseif frame=='This month' or frame=='This year' then
  local dt=os and os.date and os.date('!*t',now) or date('!*t',now)
  if frame=='This month' then first=today-dt.day+1 else first=today-(tonumber((os and os.date or date)('!%j',now))-1) end
 end
 local n=0; for d,v in pairs(r.days) do if tonumber(d)>=first and tonumber(d)<=today then n=n+v end end; return n
end
A.WINDOW=120
function A.Observe(g,race,hostile,hp,now,dead)
 if type(g)~='string' or not g:match('^Player%-') or race~='Gnome' or hostile~=true then return end
 if dead==false and A.db.dead[g] and now-A.db.dead[g]>2 then A.db.dead[g]=nil end
 if A.db.dead[g] then return end
 local e=A.encounters[g]
 if not e or (e.last and now-e.last>A.WINDOW) then e={damage=0}; A.encounters[g]=e end
 e.seen=now; e.race=race; e.hostile=true
 if type(hp)=='number' and hp>0 then e.hp=math.max(e.hp or 0,hp) end
end
function A.Damage(g,amount,overkill,own,now)
 local e=A.encounters[g]
 if not e or not own or type(amount)~='number' or amount<0 then return end
 if e.last and now-e.last>A.WINDOW then e.damage=0; e.cc=nil end
 e.damage=e.damage+math.max(0,amount-math.max(0,tonumber(overkill) or 0)); e.last=now
end
function A.Death(g,now)
 local e=A.encounters[g]; A.encounters[g]=nil
 if not e or A.db.dead[g] or not e.last or now-e.last>A.WINDOW then return false end
 if A.auras then A.auras[g]=nil end
 A.db.dead[g]=now
 if e.cc or (e.hp and e.damage>=e.hp*A.DAMAGE_FRACTION) then A.Award(now); return true end
 return false
end
-- Legacy known-effect helper; live parsers may confirm any harmful aura.
A.CCSpells={}
for _,id in ipairs({118,12824,12825,12826,28271,28272,61305,61721,61780,20066,
853,5588,5589,10308,408,8643,1833,1776,1777,8629,11285,11286,2094,
6770,2070,11297,3355,14308,14309,19386,24132,24133,19503,1513,14326,14327,
5782,6213,6215,5484,17928,6789,17925,17926,6358,710,18647,
8122,8124,10888,10890,605,10911,10912,9484,9485,10955,
339,1062,5195,5196,9852,9853,2637,18657,18658,5211,6798,8983,
9005,9823,9827,22570,18469,15487,24259,19244,19647,1330,
122,865,6131,10230,12494,33395,16979,20253,20614,20615,11578,7922,
5246,20549,12355,12809,
770,778,9749,9907,16857,17390,17391,17392}) do A.CCSpells[id]=true end
function A.CC(g,id,own,now,harmful)
 local e=A.encounters[g]
 if not e or not own or type(id)~='number'or id<1 or id%1~=0 or harmful==false or(not A.CCSpells[id]and harmful~=true)then return false end
 if e.last and now-e.last>A.WINDOW then e.damage=0 end
 e.cc=true; e.last=now; return true
end
function A.FirstDay(frame,now)
 local today=A.Day(now)
 local date=date or (os and os.date)
 if frame=='Lifetime' then return -1 end
 if frame=='7 days' then return today-6 elseif frame=='30 days' then return today-29 end
 if frame=='This week' then return today-((today+3)%7) end
 if frame=='This month' then return today-tonumber(date('!%d',now))+1 end
 if frame=='This year' then return today-tonumber(date('!%j',now))+1 end
 return today
end
function A.Encounter(g,name,race,faction,now)
 if type(g)~='string' or not g:match('^Player%-') or faction~='Alliance' then return false end
 A.db.seen=A.db.seen or {}; local r=A.db.seen[g]; local fresh=not r
 if not r then r={first=now,days={}}; A.db.seen[g]=r end
 r.name=name or r.name or g; r.race=race or r.race; r.last=now; r.days=r.days or {}; r.days[A.Day(now)]=true
 for d in pairs(r.days) do if d<A.Day(now)-A.RETENTION+1 then r.days[d]=nil end end
 if A.RememberKnownEncounter then A.RememberKnownEncounter(g,r)end
 return fresh and race=='Gnome'
end
function A.EncounterCount(frame,now)
 local n=0; local first=A.FirstDay(frame,now); local today=A.Day(now)
 for _,r in pairs(A.db.seen or {}) do
  if r.race=='Gnome' then
   if frame=='Lifetime' then n=n+1 else
    for d in pairs(r.days or {}) do if d>=first and d<=today then n=n+1; break end end
   end
  end
 end
 return n
end
_G.BIHGGnomeKillTracker5000=A
