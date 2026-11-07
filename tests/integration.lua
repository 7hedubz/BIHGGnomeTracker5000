local root=arg[1] or '.'
local now=1700000000
local frames={}; local timers={}; local sent={}; local inside=false; local result=0
local units={player={guid='Player-me',name='Tester',race='Orc',faction='Horde',hp=1000},target={guid='Player-gnome',name='Tiny',race='Gnome',faction='Alliance',hp=1000,enemy=true}}
local noop=function()end
local methods={SetScript=function(self,k,v)self.scripts[k]=v end,RegisterEvent=function(self,e)self.events[e]=true end,Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end,IsShown=function(self)return self.shown end,SetText=function(self,s)self.text=s end,GetText=function(self)return self.text end,GetPoint=function()return 'CENTER',nil,'CENTER',0,0 end,GetWidth=function()return 800 end,GetHeight=function()return 600 end,GetEffectiveScale=function()return 1 end}
local function obj()return setmetatable({scripts={},events={},shown=true},{__index=function(_,k)return methods[k] or noop end})end
methods.CreateFontString=obj;methods.CreateTexture=obj
methods.CreateLine=obj
methods.SetStartPoint=function(self,...)self.start={...}end
methods.SetEndPoint=function(self,...)self.finish={...}end
methods.SetPoint=function(self,...)self.coords={...}end
methods.SetValue=function(self,v)self.value=v end
methods.SetMinMaxValues=function(self,low,high)self.low=low;self.high=high end
function CreateFrame(_,name)local o=obj();frames[#frames+1]=o;if name then _G[name]=o end;return o end
UIParent=obj();Minimap=obj();UISpecialFrames={};SlashCmdList={};BackdropTemplateMixin={}
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
assert(A.account and A.account.alias=='Tester','account identity initializes with first toon')
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
for i=1,7 do A.periodButtons[i].scripts.OnClick()end
A.window.scripts.OnMouseWheel(nil,-1)
SlashCmdList.BIHGGKT('alerts');SlashCmdList.BIHGGKT('encounters');assert(A.window:IsShown(),'encounter command opens')
A.mode='Encounters';A.RefreshUI()
assert(not A.headers[5]:IsShown(),'unused fifth header must be hidden in encounter log')
A.mode='Leaderboard';A.RefreshUI()
assert(A.headers[5]:IsShown(),'fifth header must return on leaderboard')
local click=BIHGGKTMinimap.scripts.OnClick
A.window:Hide();A.mode='Encounters';click(nil,'LeftButton')
assert(A.window:IsShown() and A.mode=='Leaderboard','left click opens leaderboard regardless of previous tab')
click(nil,'RightButton')
assert(A.window:IsShown() and A.mode=='Encounters','right click switches open window to encounters')
click(nil,'RightButton');assert(not A.window:IsShown(),'same-view minimap click toggles closed')
click(nil,'RightButton');assert(A.window:IsShown() and A.mode=='Encounters','right click opens encounters from hidden')
click(nil,'LeftButton');assert(A.window:IsShown() and A.mode=='Leaderboard','left click switches without closing')
click(nil,'LeftButton');assert(not A.window:IsShown(),'left click toggles leaderboard closed')
assert(A.DisplayName('DoHeal-CAMWOWUS2Realm8PvP')=='DoHeal','hide internal realm suffix')
assert(A.DisplayName('DoHeal')=='DoHeal','preserve bare character names')
assert(A.owner=='Tester-Realm','internal owner key stays realm qualified')
A.mode='Leaderboard';A.RefreshUI()
for _,row in ipairs(A.rows) do assert(not (row[1].text or ''):find('-Realm',1,true),'leaderboard displays character names only') end
A.mode='Encounters';A.RefreshUI()
for _,row in ipairs(A.rows) do assert(not (row[1].text or ''):find('-Realm',1,true),'encounter log displays character names only') end
assert(A.db.seen['Player-gnome'].name=='Tiny-Realm','saved encounter identity remains intact')
A.OpenView('Settings',false);assert(A.settingsPane:IsShown() and not A.tablePane:IsShown(),'settings are separated from table navigation')
A.aliasInput:SetText('Raid Leader');A.aliasSave.scripts.OnClick()
assert(A.account.alias=='Raid Leader','nickname can be changed inside addon UI')
A.account.characters['Alt-Realm']={total=5,deaths=1,days={[A.Day(now)]=5},deathDays={[A.Day(now)]=1},seen={}}
A.members['Alt-Realm']=true;A.mode='Leaderboard';A.sort='name';A.ascending=false;A.page=1;A.RefreshUI()
local groupRow
for _,row in ipairs(A.rows) do if (row[1].text or ''):find('Raid Leader',1,true) then groupRow=row;break end end
assert(groupRow and groupRow.button,'alias row is clickable')
assert(groupRow[2].text=='7','alias adds both character kill totals')
groupRow.button.scripts.OnClick()
local child=false
for _,row in ipairs(A.rows) do if (row[1].text or ''):find('Alt',1,true) then child=true end end
assert(child,'clicking alias expands character breakdown')
groupRow.button.scripts.OnClick()
local collapsed=true
for _,row in ipairs(A.rows) do if (row[1].text or ''):find('   Alt',1,true) then collapsed=false end end
assert(collapsed,'clicking alias again collapses its characters')
A.OpenView('Charts',false)
assert(A.chartsPane:IsShown() and not A.tablePane:IsShown() and not A.settingsPane:IsShown(),'chart view has distinct content pane')
assert(A.chartRows[1].bar.value==7,'native ranking bar uses actual cached alias kills')
A.SelectPeriod('Today')
assert(A.lineDots[1].data.kills==7 and not A.lineDots[2]:IsShown(),'kill line obeys selected period and hides unused points')
assert(A.lineDots[1].coords[4]==175 and not A.lineSegments[1]:IsShown(),'single day is a centered point, not a fictitious time segment')
A.SelectPeriod('7 days')
assert(A.lineSegments[6]:IsShown() and not A.lineSegments[7]:IsShown(),'seven daily points form six connected line segments')
assert(A.lineSegments[1].start[3]==0 and A.lineSegments[6].finish[3]==350,'line runs from earliest to latest date')
assert(A.lineYTicks[1].text=='0' and A.lineXAxis.text:find('Time',1,true),'numeric kill axis and date axis are labeled')
A.OpenView('Leaderboard',false);assert(A.tablePane:IsShown() and not A.chartsPane:IsShown(),'returning from charts restores table')
local chat={};SendChatMessage=function(msg,channel)chat[#chat+1]={msg,channel}end
A.reportButton.scripts.OnClick();assert(A.preview:IsShown() and #chat==0 and not A.postJob,'preview never posts automatically')
A.confirmPostButton.scripts.OnClick();assert(not A.preview:IsShown() and A.postJob,'explicit confirmation starts report queue')
for i=0,10 do tick()end
assert(#chat==#A.previewLines and chat[1][2]=='GUILD','confirmed ranking posts only previewed lines to guild')
assert(A.status.text:find('AUTO SYNC ON',1,true),'automatic sync status is explicit')
assert(not A.lastError,'guarded runtime error: '..tostring(A.lastError))
print('PASS actual TOC integration: lifecycle, visible CC, exact damage, confirmed deaths, encounters, five-column UI, guild sync, secret values, blocked/retry sends')
