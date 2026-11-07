local root=arg[1] or '.'
local now=1700000000
local frames={}; local timers={}; local sent={}; local inside=false; local result=0
local units={player={guid='Player-me',name='Tester',race='Orc',faction='Horde',hp=1000},target={guid='Player-gnome',name='Tiny',race='Gnome',faction='Alliance',hp=1000,enemy=true}}
local noop=function()end
local methods={SetScript=function(self,k,v)self.scripts[k]=v end,RegisterEvent=function(self,e)self.events[e]=true end,Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end,IsShown=function(self)return self.shown end,SetText=function(self,s)self.text=s end,GetPoint=function()return 'CENTER',nil,'CENTER',0,0 end,GetWidth=function()return 800 end,GetHeight=function()return 600 end,GetEffectiveScale=function()return 1 end}
local function obj()return setmetatable({scripts={},events={}},{__index=function(_,k)return methods[k] or noop end})end
methods.CreateFontString=obj;methods.CreateTexture=obj
function CreateFrame(_,name)local o=obj();frames[#frames+1]=o;if name then _G[name]=o end;return o end
UIParent=obj();UISpecialFrames={};SlashCmdList={};BackdropTemplateMixin={}
DEFAULT_CHAT_FRAME={AddMessage=noop};C_Timer={After=function(delay,fn)timers[#timers+1]=fn end}
function GetServerTime()return now end;function GetTime()return now end;date=os.date
function issecretvalue()return false end
function UnitGUID(u)return units[u] and units[u].guid end
function UnitExists(u)return units[u]~=nil end
function UnitIsPlayer(u)return units[u]~=nil end
function UnitRace(u)return units[u].race,units[u].race end
function UnitFactionGroup(u)return units[u].faction end
function UnitName(u)return units[u].name,'Realm' end
function UnitHealthMax(u)return units[u].hp end
function UnitHealth(u)return units[u].dead and 0 or units[u].hp end
function UnitIsDeadOrGhost(u)return units[u] and units[u].dead or false end
function UnitCanAttack(_,u)return units[u] and units[u].enemy and not units[u].dead or false end
UnitIsEnemy=UnitCanAttack
function UnitIsUnit(a,b)return a==b end
function GetNormalizedRealmName()return 'Realm' end
function GetRealmName()return 'Realm' end
function GetGuildInfo()return 'Guild' end
function IsInGuild()return true end
function GetNumGuildMembers()return 2 end
function GetGuildRosterInfo(i)if i==1 then return 'Tester-Realm' else return 'Friend-Realm' end end
C_GuildInfo={GuildRoster=noop}
function IsInInstance()return inside,'none' end
function GetPlayerInfoByGUID(g)if g=='Player-gnome' then return 'Mage','MAGE','Gnome','Gnome',2,'Tiny','Realm' end end
C_UnitAuras={GetAuraDataByIndex=function(u,i)if u=='target' and i==1 and not units.target.dead then return {spellId=118,sourceUnit='player',auraInstanceID=1,expirationTime=now+10} end end}
C_ChatInfo={RegisterAddonMessagePrefix=noop,SendAddonMessage=function(p,m,c)sent[#sent+1]={p,m,c};return result end}
C_DeathRecap={GetRecapLink=function()return '|Hdeath:9|h' end,GetRecapEvents=function()return {{sourceGUID='Player-gnome',timestamp=now,hideCaster=false}} end}
local A={}
local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',A)end end;toc:close()
local function event(e,...)
 for _,f in ipairs(frames)do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f,e,...)end end
end
local function tick()
 now=now+1
 for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1)end end
end
local function delayed()local t=timers;timers={};for _,fn in ipairs(t)do fn()end end
event('ADDON_LOADED','BIHGGnomeKillTracker5000');event('PLAYER_LOGIN');event('PLAYER_ENTERING_WORLD');tick()
assert(A.db and A.owner=='Tester-Realm','login initializes persistence')
assert(A.EncounterCount('Lifetime',now)==1,'visible Gnome stored uniquely')
assert(A.db.seen['Player-gnome'],'Alliance player memory')
units.target.dead=true;event('UNIT_HEALTH','target');tick()
assert(A.db.owners[A.owner].total==1,'confirmed own CC + observed death awards kill without CLEU')
tick();event('PARTY_KILL','Player-me','Player-gnome');assert(A.db.owners[A.owner].total==1,'duplicate death ignored')
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'recap Gnome killing blow tracked')
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'same recap ignored')
A.ToggleUI();A.RefreshUI();assert(A.window:IsShown(),'UI opens')
A.mode='Encounters';A.RefreshUI();A.mode='Leaderboard';A.RefreshUI()
A.dirty=true;inside=true;local n=#sent;A.Pump(now);assert(#sent==n,'instance prevents send')
inside=false;result=3;A.request=false;A.lastRequest=now;A.Pump(now);assert(A.outgoing,'failed send retains queue')
result=0;for i=1,10 do A.Pump(now+i)end;assert(not A.outgoing,'successful retry flushes queue')
A.Receive('2|S|7|3|'..A.Day(now)..'|2|1','GUILD','Friend-Realm',now)
A.RefreshUI();assert(A.PeerRecords()['Friend-Realm'].total==7,'guild peer record merged')
-- Exercise the optional exact-damage path without aura qualification.
C_UnitAuras.GetAuraDataByIndex=function()return nil end
units.target={guid='Player-damage',name='Other',race='Gnome',faction='Alliance',hp=1000,enemy=true}
A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_DAMAGE',false,'Player-me','Tester',0,0,'Player-damage','Other',0,0,133,'Fireball',4,100,0 end
A.ReadCombatLog()
assert(A.encounters['Player-damage'] and A.encounters['Player-damage'].damage==100,'damage parsed: '..tostring(A.encounters['Player-damage'] and A.encounters['Player-damage'].damage))
CombatLogGetCurrentEventInfo=function()return now,'UNIT_DIED',false,nil,nil,0,0,'Player-damage','Other',0,0 end
A.ReadCombatLog();assert(A.db.owners[A.owner].total==2,'readable log exact 10% damage path; total='..A.db.owners[A.owner].total..' encounter='..tostring(A.encounters['Player-damage'])..' dead='..tostring(A.db.dead['Player-damage']))
-- A cast-success packet must not qualify as landed crowd control.
units.target={guid='Player-miss',name='Missed',race='Gnome',faction='Alliance',hp=1000,enemy=true};A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_CAST_SUCCESS',false,'Player-me','Tester',0,0,'Player-miss','Missed',0,0,118,'Polymorph',64 end
A.ReadCombatLog();A.Death('Player-miss',now);assert(A.db.owners[A.owner].total==2,'cast success not confirmed CC')
-- Missing or secret values must fail closed without preventing later reads.
local secret={}
issecretvalue=function(v)return v==secret end
local oldGUID=UnitGUID;UnitGUID=function(u)if u=='target' then return secret end;return oldGUID(u)end
assert(pcall(A.Scan,'target'),'secret unit GUID skipped');UnitGUID=oldGUID
assert(A.SendPacket('test'),'normal outside-instance send')
local oldInstance=IsInInstance;IsInInstance=function()return secret end
assert(not A.SendPacket('test'),'secret instance state fails closed');IsInInstance=oldInstance
issecretvalue=function()return false end
-- Zero-size roster while loading must not erase the offline peer cache.
local oldRoster=GetNumGuildMembers;GetNumGuildMembers=function()return 0 end
A.Roster();assert(A.PeerRecords()['Friend-Realm'],'unloaded roster preserves cached stats')
GetNumGuildMembers=oldRoster;A.Roster()
-- The actual five-column board, period cycle, header sorting and paging callbacks run.
A.mode='Leaderboard';A.RefreshUI();assert(A.headers[5].text=='Encountered','encounter leaderboard column')
A.headers[5].scripts.OnClick();assert(A.sort=='encounters','encounter sorting')
A.headers[5].scripts.OnClick();assert(A.ascending,'reverse sort')
for i=1,7 do A.periodButton.scripts.OnClick()end
A.window.scripts.OnMouseWheel(nil,-1)
SlashCmdList.BIHGGKT('alerts');SlashCmdList.BIHGGKT('encounters');assert(A.window:IsShown(),'encounter command opens')
assert(not A.lastError,'guarded runtime error: '..tostring(A.lastError))
print('PASS actual TOC integration: lifecycle, visible CC, exact damage, confirmed deaths, encounters, five-column UI, guild sync, secret values, blocked/retry sends')
