local root=arg[1] or '.'
local A={}
assert(loadfile(root..'/Core.lua'))('BIHGGnomeKillTracker5000',A)
local passed=0
local function eq(a,b,why) assert(a==b,(why or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) fn(); passed=passed+1; print('PASS '..name) end
local races={['Player-a']='Gnome',['Player-b']='Gnome',['Player-human']='Human',['Creature-a']='Gnome'}
A.Race=function(g) return races[g] end
local function row(amount,source,event,time)
 return {event=event or 'SWING_DAMAGE',timestamp=time or 99,sourceGUID=source or 'Player-a',amount=amount}
end
local function proof(events,hp,death,start) return A.GnomeDeathEvidence(events,hp or 100,death or 100,start or 90) end

test('strict majority aggregates Gnomes without requiring their final blow',function()
 eq(proof({row(49)}),nil)
 eq(proof({row(50)}),nil)
 local p=proof({row(25),row(26,'Player-b'),row(49,'Player-human','SPELL_DAMAGE',100)})
 assert(p,'combined Gnome majority must produce evidence')
 eq(p.damage,51); eq(p.maxHealth,100); eq(p.time,100); eq(p.source,'Player-b')
 eq(proof({row(51)}).damage,51)
end)
test('damage policy whitelists events and subtracts conservative mitigation',function()
 for _,event in ipairs({'SWING_DAMAGE','RANGE_DAMAGE','SPELL_DAMAGE','SPELL_PERIODIC_DAMAGE','DAMAGE_SHIELD'}) do
  eq(proof({row(51,nil,event)}).damage,51,event)
 end
 for _,event in ipairs({'SPELL_HEAL','UNIT_DIED','SPELL_MISSED','ENVIRONMENTAL_DAMAGE',''}) do
  eq(proof({row(999,nil,event)}),nil,event)
 end
 local e=row(100); e.overkill=10;e.absorbed=15;e.resisted=10;e.blocked=14
 eq(proof({e}).damage,51)
 e.blocked=15;eq(proof({e}),nil)
 e=row(51);e.overkill=-1;eq(proof({e}).damage,51)
 e=row(5);e.overkill=100;eq(proof({e,row(51)}).damage,51)
end)
local secret=setmetatable({},{__index=function() error('secret read') end,__pairs=function() error('secret iteration') end})
local secretTables=setmetatable({},{__mode='k'})
A.Secret=function(v) return rawequal(v,secret) end
issecrettable=function(v) return secretTables[v]==true end

test('only readable finite in-combat player Gnome damage is evidence',function()
 eq(proof({row(999,'Creature-a')}),nil)
 eq(proof({row(999,'Player-human')}),nil)
 eq(proof({row(999,'Player-unknown')}),nil)
 eq(proof({row(999,nil,nil,89)}),nil)
 eq(proof({row(999,nil,nil,102)}),nil)
 eq(proof({row(25,nil,nil,90),row(26,nil,nil,101)}).damage,51)
 eq(proof({row(26,'Player-b'),row(26)}).source,'Player-a')
 for _,field in ipairs({'event','timestamp','sourceGUID','amount','overkill','absorbed','resisted','blocked','hideCaster'}) do
  local e=row(999); e[field]=secret;eq(proof({e}),nil,'secret '..field)
 end
 for _,field in ipairs({'timestamp','amount','overkill','absorbed','resisted','blocked'}) do
  for _,v in ipairs({'bad',false,math.huge,-math.huge,0/0}) do
   local e=row(999);e[field]=v;eq(proof({e}),nil,'malformed '..field)
  end
 end
 for _,field in ipairs({'amount','absorbed','resisted','blocked'}) do
  local e=row(999);e[field]=-1;eq(proof({e}),nil,'negative '..field)
 end
 for _,hidden in ipairs({true,'yes',1}) do local e=row(999);e.hideCaster=hidden;eq(proof({e}),nil) end
 local e=row(999);secretTables[e]=true;eq(proof({e}),nil)
 local events={row(999)};secretTables[events]=true;eq(proof(events),nil)
 eq(proof(secret),nil);eq(proof({secret,false,'bad'}),nil)
 for _,v in ipairs({secret,'bad',false,0,-1,math.huge,0/0}) do
  eq(A.GnomeDeathEvidence({row(999)},v,100,90),nil)
 end
 for _,v in ipairs({secret,'bad',false,math.huge,0/0}) do
  eq(A.GnomeDeathEvidence({row(999)},100,v,90),nil)
  eq(A.GnomeDeathEvidence({row(999)},100,100,v),nil)
 end
 eq(A.GnomeDeathEvidence({row(999)},100,100,101),nil)
 eq(A.GnomeDeathEvidence(nil,100,100,90),nil)
 eq(A.GnomeDeathEvidence({row(999)},100,100,nil),nil)
 local old=A.Race;A.Race=function() return secret end;eq(proof({row(999)}),nil);A.Race=old
 eq(proof({row(999),row(math.huge)}).damage,999,'bad rows skipped without discarding readable evidence')
 eq(proof({row(1e308),row(1e308)}),nil,'overflow cannot be proof')
end)
test('proof validation requires readable strict majority and exact death time',function()
 local p=proof({row(51)})
 eq(A.ValidGnomeDeathEvidence(p,100),true)
 eq(A.ValidGnomeDeathEvidence(p,101),false)
 eq(A.ValidGnomeDeathEvidence(p,secret),false)
 eq(A.ValidGnomeDeathEvidence(nil,100),false)
 eq(A.ValidGnomeDeathEvidence(secret,100),false)
 for _,field in ipairs({'damage','maxHealth','source','time'}) do
  local old=p[field]
  for _,bad in ipairs({secret,false,'bad',math.huge,-math.huge,0/0}) do
   p[field]=bad;eq(A.ValidGnomeDeathEvidence(p,100),false,field)
  end
  p[field]=nil;eq(A.ValidGnomeDeathEvidence(p,100),false,field);p[field]=old
 end
 p.damage=50;eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.damage=0;eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.damage=51;p.maxHealth=0;eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.maxHealth=-100;eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.maxHealth=100;p.source='Creature-a';eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.source='Player-';eq(A.ValidGnomeDeathEvidence(p,100),false)
 p.source='Player-a';secretTables[p]=true;eq(A.ValidGnomeDeathEvidence(p,100),false)
end)
test('PlayerDeath gates both group delegation and legacy counters on matching fresh proof',function()
 local db={owners={owner={total=12,days={},deaths=7,deathDays={[0]=7}}}}
 A.Init(db,'owner',100)
 eq(A.PlayerDeath('unproven','Gnome',100,'Player-a'),false,'lethal Gnome alone is not proof')
 eq(db.owners.owner.deaths,7)
 local p=proof({row(51)})
 eq(A.PlayerDeath('mismatch','Gnome',100,'Player-b',p),false)
 eq(A.PlayerDeath('secret','Gnome',100,secret,p),false)
 eq(A.PlayerDeath('stale','Gnome',101,'Player-a',p),false)
 eq(A.PlayerDeath('valid','Gnome',100,'Player-a',p),true)
 eq(A.PlayerDeath('valid','Gnome',100,'Player-a',p),false,'dedup preserved')
 eq(db.owners.owner.deaths,8);eq(db.owners.owner.total,12)
 A.Init(db,'owner',100);eq(db.owners.owner.deaths,8,'history preserved on reload')
 local calls=0
 A.GroupOwnDeath=function(id,race,now,killer,got)
  calls=calls+1;eq(id,'group');eq(race,'Gnome');eq(now,100);eq(killer,p.source);eq(got,p);return true
 end
 eq(A.PlayerDeath('group','Gnome',100,'Player-a'),false)
 eq(A.PlayerDeath('group','Gnome',100,'Player-b',p),false)
 eq(calls,0)
 eq(A.PlayerDeath('group','Gnome',100,'Player-a',p),true);eq(calls,1)
 A.GroupOwnDeath=nil
end)
print(passed..' death policy tests passed')
