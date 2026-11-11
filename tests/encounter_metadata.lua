local root=arg[1]or'.';date=os.date;function IsInInstance()return false,'none'end
local secret=setmetatable({},{__tostring=function()error('secret string conversion')end,__lt=function()error('secret comparison')end})
local function clone(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=clone(v)end;return r end
local function addon(db,account,owner,t)
 local A={};for _,f in ipairs({'Core.lua','Accounts.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
 A.Secret=function(v)return rawequal(v,secret)end;A.Init(db or{},owner or'Main-Realm',t);A.InitAccount(account or{},'account',t);return A
end
local t=1700000000;local A=addon(nil,nil,nil,t);local g='Player-history'
A.Encounter(g,'History-Realm','Gnome','Alliance',t,70,' Mage ')
local stale=clone(A.db)
A.Encounter(g,nil,nil,'Alliance',t+10,71,nil)
A.Encounter(g,nil,nil,'Alliance',t+20,nil,'Death Knight')
A.Encounter(g,nil,nil,'Alliance',t+30,nil,nil)
local B=addon(stale,clone(A.account),'Main-Realm',t+31)
local r=B.KnownEncounters()[g]
assert(r.level==71 and r.class=='Death Knight','stale serialized character snapshot cannot roll back independently newer account metadata')
assert(r.levelAt==t+10 and r.classAt==t+20,'unknown sightings do not advance field freshness')
local C=addon(nil,clone(B.account),'Alt-Realm',t+32)
assert(not C.db.seen[g]and C.KnownEncounters()[g].level==71,'serialized alt sees metadata without fabricated personal sightings')
C.Encounter(g,'History-Realm','Gnome','Alliance',t+40,72,nil)
C.Encounter(g,nil,nil,'Alliance',t+50,nil,'Prêtre sacré')
C.Encounter(g,nil,nil,'Alliance',t+60,secret,secret)
for _,bad in ipairs({0,-2,1.5,math.huge,-math.huge,0/0,'60'})do C.Encounter(g,nil,nil,'Alliance',t+61,bad,'Mage|cffff0000')end
for _,bad in ipairs({'','  ','?','Mage\nRogue',string.rep('x',129)})do C.Encounter(g,nil,nil,'Alliance',t+62,nil,bad)end
r=C.KnownEncounters()[g];assert(r.level==72 and r.class=='Prêtre sacré','unknown secret malformed metadata cannot erase known fields')
assert(r.levelAt==t+40 and r.classAt==t+50,'invalid inputs do not change field timestamps')
local D=addon(clone(C.db),clone(C.account),'Alt-Realm',t+70)
assert(D.KnownEncounters()[g].class=='Prêtre sacré','localized class survives reload')
assert(D.account.knownEncounters[g]~=D.db.seen[g]and D.account.knownEncounters[g].days~=D.db.seen[g].days,'persistent cache must not alias personal SV tables')
local original=clone(D.db.seen[g]);D.RememberKnownEncounter(g,D.db.seen[g]);assert(D.db.seen[g].last==original.last and D.db.seen[g].levelAt==original.levelAt,'cache merging does not mutate source record')
-- Legacy entries with metadata but no field timestamp use their own last sighting.
local e={first=t-100,last=t+45,days={[D.Day(t-86400)]=true},level=73,class='Warrior'}
D.RememberKnownEncounter(g,e);r=D.KnownEncounters()[g]
assert(r.level==73 and r.class=='Prêtre sacré','legacy source freshness is evaluated fieldwise')
assert(e.levelAt==nil and e.classAt==nil,'normalization cannot mutate source snapshot')
D.RememberKnownEncounter(g,{last=t+100,level=0,class='|Hbad',days={}})
assert(D.KnownEncounters()[g].level==73,'later invalid metadata cannot replace real knowledge')
D.Encounter('Player-legacy','Old-Realm','Human','Alliance',t)
assert(D.KnownEncounters()['Player-legacy'].level==nil,'old missing metadata is not fabricated')
D.Encounter('Player-legacy',nil,nil,'Alliance',t+1,-1,'Mage')
assert(D.KnownEncounters()['Player-legacy'].level==-1,'native -1 sentinel is retained')
D.Encounter('Player-legacy',nil,nil,'Alliance',t+2,200,'Mage')
assert(D.KnownEncounters()['Player-legacy'].level==200,'future/custom positive integer levels are not capped at 60')
D.Encounter('Player-legacy',nil,nil,'Alliance',t+3,-1,nil)
assert(D.KnownEncounters()['Player-legacy'].level==200,'later unknown-higher sentinel cannot erase a known numeric level')
-- Equal timestamps must converge independently of merge iteration/login order.
local one={last=t+200,level=80,class='Mage',days={}};local two={last=t+200,level=81,class='Warrior',days={}}
D.RememberKnownEncounter('Player-tie',one);D.RememberKnownEncounter('Player-tie',two)
local E=addon(nil,nil,'Other-Realm',t);E.RememberKnownEncounter('Player-tie',two);E.RememberKnownEncounter('Player-tie',one)
assert(D.KnownEncounters()['Player-tie'].level==E.KnownEncounters()['Player-tie'].level and D.KnownEncounters()['Player-tie'].class==E.KnownEncounters()['Player-tie'].class,'equal timestamp ties converge deterministically')
assert(r.first==t-100 and r.last==t+100 and r.days[D.Day(t-86400)],'metadata preserves first/last and date unions')
assert(D.db.owners[D.owner].total==0 and D.AccountEncounterCount('Lifetime',t+100)==1,'metadata leaves totals and unique Gnome count unchanged')
assert(loadfile(root..'/Identity.lua'))('BIHGGnomeKillTracker5000',D)
D.db.owners[D.owner].characterGUID='Player-owner'
D.account.characters['Legacy-Realm']={characterGUID='Player-owner',total=0,deaths=0,days={},deathDays={},seen={[g]={first=t,last=t+300,level=99,class='Druid',days={}}}}
assert(D.BindLocalCharacter('Player-owner',t+301))
assert(D.db.seen[g].level==99 and D.db.seen[g].class=='Druid','same-character identity reconciliation retains newer metadata fieldwise')
print('PASS encounter metadata: serialized reload/alt/stale snapshot, fieldwise freshness, unknown/secret safety, provenance ties, no aliases, date/count invariants')
