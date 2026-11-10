local _, A = ...
A.VERSION='1.8.1'
A.RETENTION = 400
A.DAMAGE_FRACTION = 0.02
-- IsInInstance has two independent returns; Safe intentionally keeps only one.
-- Never infer world from a missing, protected, or contradictory return.
local function openWorld()
 if type(IsInInstance)~='function' then return false end
 local ok,inside,kind=pcall(IsInInstance)
 if not ok then return false end
 local function readable(v)
  if type(issecretvalue)~='function' then return true end
  local good,hidden=pcall(issecretvalue,v)
  return good and hidden==false
 end
 if not readable(inside) or not readable(kind) then return false end
 return type(inside)=='boolean' and inside==false and type(kind)=='string' and kind=='none'
end
function A.RefreshKillLocation(boundary)
 local allowed=openWorld();local previous=A.killLocation
 if boundary or previous~=allowed or not allowed then
  A.encounters={};A.groupTargets={};A.auras={};A.auraPoll={};A.killLifeAfter={}
  -- Retain saved corpse dedup until a readable living observation proves a
  -- new life. A corpse on login/exit must never rearm the same old death.
  A.killBoundaryDead=A.killBoundaryDead or {}
  for guid in pairs(A.db and A.db.dead or {})do A.killBoundaryDead[guid]=true end
 end
 A.killLocation=allowed
 return allowed
end
function A.OpenWorldKillsAllowed()return A.RefreshKillLocation(false)end
function A.ObserveKillLife(g,dead,now)
 if dead~=false or A.killAwardActive then return end
 local previous=A.db.dead[g]
 if previous and (not now or now<=previous) and not(A.killBoundaryDead and A.killBoundaryDead[g])then return end
 if previous then
  -- Readable living state rearms observation, not credit. A new encounter
  -- starts empty and still needs fresh attributable participation.
  A.killLifeAfter=A.killLifeAfter or {};A.killLifeAfter[g]=previous
  A.db.dead[g]=nil
  if A.auras then A.auras[g]=nil end
  if A.auraPoll then A.auraPoll[g]=nil end
 end
 if A.killBoundaryDead then A.killBoundaryDead[g]=nil end
end
A.frames = {'Lifetime','7 days','30 days','Today','This week','This month','This year'}
function A.Day(t) return math.floor(t / 86400) end
function A.Init(db, owner, now)
 db.version=1; db.owners=db.owners or {}; db.dead=db.dead or {}; db.options=db.options or {}
 A.db=db; A.owner=owner; A.now=now
 db.owners[owner]=db.owners[owner] or {total=0,days={}}
 A.encounters={};A.killLifeAfter={};A.auraPoll={}
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
 if not A.OpenWorldKillsAllowed() then return false end
 local r=A.db.owners[A.owner]; local d=A.Day(now)
 r.total=r.total+1; r.days[d]=(r.days[d] or 0)+1
 if A.Changed then A.Changed() end
 return true
end
local deathDamageEvents={SWING_DAMAGE=true,RANGE_DAMAGE=true,SPELL_DAMAGE=true,SPELL_PERIODIC_DAMAGE=true,DAMAGE_SHIELD=true}
local function deathSecret(v) return A.Secret and A.Secret(v) end
local function deathTable(v)
 return not deathSecret(v) and type(v)=='table' and not (issecrettable and issecrettable(v))
end
local function deathNumber(v)
 return not deathSecret(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function deathPlayer(v)
 return not deathSecret(v) and type(v)=='string' and v:match('^Player%-.+')~=nil
end
local function deathMitigation(v,overkill)
 if deathSecret(v) then return nil end
 if v==nil then return 0 end
 if not deathNumber(v) or (not overkill and v<0) then return nil end
 return math.max(0,v)
end
local function deathRow(e,deathTime,combatStart)
 if not deathTable(e) then return end
 local event,t,g,amount,hidden=e.event,e.timestamp,e.sourceGUID,e.amount,e.hideCaster
 if deathSecret(event) or type(event)~='string' or not deathDamageEvents[event]
  or not deathNumber(t) or t<combatStart or t>deathTime+1
  or not deathPlayer(g) or not deathNumber(amount) or amount<0
  or deathSecret(hidden) or (hidden~=nil and hidden~=false) then return end
 local overkill=deathMitigation(e.overkill,true)
 local absorbed=deathMitigation(e.absorbed)
 local resisted=deathMitigation(e.resisted)
 local blocked=deathMitigation(e.blocked)
 if not overkill or not absorbed or not resisted or not blocked then return end
 if type(A.Race)~='function' then return end
 local ok,race=pcall(A.Race,g)
 if not ok or deathSecret(race) or type(race)~='string' or race=='' then return end
 if race~='Gnome' then return nil,0,true end
 return g,math.max(0,amount-overkill-absorbed-resisted-blocked),true
end
function A.GnomeDeathEvidence(events,maxHealth,deathTime,combatStart)
 if not deathTable(events) or not deathNumber(maxHealth) or maxHealth<=0
  or not deathNumber(deathTime) or not deathNumber(combatStart) or combatStart>deathTime then return nil end
 local total,sources=0,{}
 local rows,unreadable=0,false
 for _,e in pairs(events) do
  local guid,damage,confirmed=deathRow(e,deathTime,combatStart)
  rows=rows+1;if not confirmed then unreadable=true end
  if guid then
   total=total+damage
   if not deathNumber(total) then return nil end
   sources[guid]=(sources[guid] or 0)+damage
  end
 end
 if total<=maxHealth*0.5 then
  if rows==0 then return nil end
  return nil,unreadable and 'unreadable/missing attribution' or 'insufficient confirmed Gnome damage'
 end
 local source,best=nil,0
 for guid,damage in pairs(sources) do
  if damage>best or (damage==best and (not source or guid<source)) then source,best=guid,damage end
 end
 return {damage=total,maxHealth=maxHealth,source=source,time=deathTime}
end
function A.ValidGnomeDeathEvidence(proof,now)
 if not deathTable(proof) or not deathNumber(now) then return false end
 local damage,hp,source,time=proof.damage,proof.maxHealth,proof.source,proof.time
 return deathNumber(damage) and damage>0 and deathNumber(hp) and hp>0
  and damage>hp*0.5 and deathPlayer(source) and deathNumber(time) and time==now
end
function A.PlayerDeath(id,race,now,killer,proof)
 if not A.ValidGnomeDeathEvidence(proof,now) or deathSecret(killer) or killer~=proof.source then return false end
 if A.GroupOwnDeath then return A.GroupOwnDeath(id,race,now,killer,proof)end
 if deathSecret(race) or race~='Gnome' or deathSecret(id) or type(id)~='string' then return false end
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
 if not A.OpenWorldKillsAllowed() then return end
 if type(g)~='string' or not g:match('^Player%-') or race~='Gnome' or hostile~=true then return end
 A.ObserveKillLife(g,dead,now)
 if A.db.dead[g] then return end
 local e=A.encounters[g]
 if not e or (e.last and now-e.last>A.WINDOW) then e={damage=0}; A.encounters[g]=e end
 e.seen=now; e.race=race; e.hostile=true
 if type(hp)=='number' and hp>0 then e.hp=math.max(e.hp or 0,hp) end
end
function A.Damage(g,amount,overkill,own,now)
 if not A.OpenWorldKillsAllowed() then return end
 local e=A.encounters[g]
 if not e or not own or type(amount)~='number' or amount<0 then return end
 if e.last and now-e.last>A.WINDOW then e.damage=0; e.cc=nil end
 e.damage=e.damage+math.max(0,amount-math.max(0,tonumber(overkill) or 0)); e.last=now
end
function A.Death(g,now,corpseConfirmed)
 if not A.OpenWorldKillsAllowed() then return false end
 if not corpseConfirmed and A.killLifeAfter and A.killLifeAfter[g] and now-A.killLifeAfter[g]<=3 then return false end
 local e=A.encounters[g]; A.encounters[g]=nil
 if not e or A.db.dead[g] or not e.last or now-e.last>A.WINDOW then return false end
 if A.auras then A.auras[g]=nil end
 local qualified=e.cc or (e.hp and e.damage>=e.hp*A.DAMAGE_FRACTION)
 -- Reserve the corpse before Award invokes synchronous Changed callbacks.
 A.db.dead[g]=now
 if qualified then
  A.killAwardActive=true;local awarded=A.Award(now);A.killAwardActive=nil
  if not awarded then A.db.dead[g]=nil;return false end
 end
 return qualified and true or false
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
 if not A.OpenWorldKillsAllowed() then return false end
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
