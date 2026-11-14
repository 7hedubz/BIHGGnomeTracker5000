local root=arg[1] or '.'
local now=1700000000
local frames={}; local timers={}; local sent={}; local inside=false; local result=0;local forbiddenRegistrations=0
local combat=false;function InCombatLockdown()return combat end
local restricted=false
local stateDrivers={};function RegisterStateDriver(frame,id,condition)stateDrivers[frame]={id=id,condition=condition}end
local soundCalls={};function PlaySoundFile(file,channel)soundCalls[#soundCalls+1]={file,channel};return true,1 end
function GetLocale()return'enUS'end
function GetBuildInfo()return'1.60.1','70291','',16001 end
function IsWindowsClient()return true end
WOW_PROJECT_ID=1;WOW_PROJECT_MAINLINE=1;bit=require('bit')
strmatch=string.match;function securecallfunction(fn,...)return fn(...)end
local playerRank='Council of BIHG'
local units={player={guid='Player-me',name='Tester',race='Orc',faction='Horde',hp=1000},target={guid='Player-gnome',name='Tiny',race='Gnome',faction='Alliance',hp=1000,enemy=true}}
local noop=function()end
local methods={SetScript=function(self,k,v)self.scripts[k]=v end,RegisterEvent=function(self,e)self.events[e]=true end,Show=function(self)self.shown=true end,Hide=function(self)local was=self.shown;self.shown=false;if was and self.scripts.OnHide then self.scripts.OnHide(self)end end,IsShown=function(self)return self.shown end,SetText=function(self,s)self.text=s end,GetText=function(self)return self.text end,GetPoint=function()return 'CENTER',nil,'CENTER',0,0 end,GetWidth=function()return 800 end,GetHeight=function()return 600 end,GetEffectiveScale=function()return 1 end}
local originalRegister=methods.RegisterEvent
methods.RegisterEvent=function(self,e)if e=='COMBAT_LOG_EVENT_UNFILTERED'then forbiddenRegistrations=forbiddenRegistrations+1;error('forbidden native CLEU registration')end;originalRegister(self,e)end
local function obj()return setmetatable({scripts={},events={},shown=true},{__index=function(_,k)return methods[k] or noop end})end
methods.CreateFontString=obj;methods.CreateTexture=obj
methods.SetHighlightTexture=function(self,texture)self.highlightTexture=texture end
methods.SetAllPoints=function(self,relative)self.allPoints=relative end
methods.SetColorTexture=function(self,...)self.color={...}end
methods.SetBlendMode=function(self,mode)self.blend=mode end
methods.SetMultiLine=function(self,value)self.multiline=value end
methods.SetFocus=function(self)self.focused=true end
methods.ClearFocus=function(self)self.focused=false end
methods.HighlightText=function(self)self.selectedAll=true end
methods.HasFocus=function(self)return rawget(self,'focused')or false end
methods.SetSize=function(self,w,h)self.width=w;self.height=h end
methods.SetWidth=function(self,w)self.width=w end
methods.SetWordWrap=function(self,value)self.wordWrap=value end
methods.SetChecked=function(self,value)self.checked=value==true end
methods.GetChecked=function(self)return rawget(self,'checked')or false end
methods.GetWidth=function(self)return rawget(self,'width')or 800 end
methods.GetHeight=function(self)return rawget(self,'height')or 600 end
methods.GetLeft=function(self)return rawget(self,'left')or 0 end
methods.CreateLine=obj
methods.SetStartPoint=function(self,...)self.start={...}end
methods.SetEndPoint=function(self,...)self.finish={...}end
methods.SetPoint=function(self,...)self.coords={...}end
methods.SetValue=function(self,v)self.value=v end
methods.SetMinMaxValues=function(self,low,high)self.low=low;self.high=high end
methods.SetAttribute=function(self,k,v)assert(not combat,'protected attribute mutation during combat');self.attrs=rawget(self,'attrs')or {};self.attrs[k]=v end
methods.RegisterForClicks=function(self,...)self.clickEvents={...}end
methods.HookScript=function(self,k,fn)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;fn(...)end end
methods.SetHeight=function(self,h)self.height=h end
methods.StartMoving=function(self)self.moves=(rawget(self,'moves')or 0)+1;self.moving=true end
methods.StopMovingOrSizing=function(self)self.moving=false;self.stops=(rawget(self,'stops')or 0)+1 end
function CreateFrame(_,name,parent,template)local o=obj();o.parent=parent;o.template=template;if template and template:find('Secure',1,true)then assert(not combat,'secure construction in combat');o.protected=true;local a=parent;while a and a~=UIParent do a.protected=true;a=rawget(a,'parent')end end;if template and template:find('SecureActionButtonTemplate',1,true)then o.scripts.OnClick=noop end;frames[#frames+1]=o;if name then _G[name]=o end;return o end
UIParent=obj();Minimap=obj();UISpecialFrames={};SlashCmdList={};BackdropTemplateMixin={}
methods.GetFrameLevel=function()return 1 end
methods.GetTop=function(self)return rawget(self,'top')or 600 end
methods.EnableMouse=function(self,value)self.mouse=value end
methods.IsVisible=function(self)return self.shown and(not rawget(self,'parent')or self.parent:IsVisible())end
-- Enforce protection on parents and anchor dependencies, not just attributes.
for _,key in ipairs({'Show','Hide','SetSize','SetWidth','SetHeight','SetPoint','ClearAllPoints','SetAlpha','SetScale','SetScript','StartMoving','StopMovingOrSizing'})do
 local original=methods[key]or noop
 methods[key]=function(self,...)
  assert(not(combat and rawget(self,'protected')and not restricted),'locked protected write: '..key)
  if key=='SetPoint'then local _,relative=...;if type(relative)=='table'and rawget(self,'protected')then
   local a=relative;while a and a~=UIParent do a.protected=true;a=rawget(a,'parent')end
  end end
  return original(self,...)
 end
end
local function driverState(value)
 for frame,d in pairs(stateDrivers)do
  local snippet=assert(loadstring(frame.attrs['_onstate-'..d.id]))
  setfenv(snippet,{self=frame,newstate=value});restricted=true;snippet();restricted=false
 end
end
local function transition(value)
 combat=value;driverState(value and'closed'or'available')
end

GameTooltip={
 GetOwner=function(self)return self.owner end,
 SetOwner=function(self,owner,anchor)self.owner=owner;self.anchor=anchor end,
 SetText=function(self,text)self.text=text;self.lines={}end,
 AddLine=function(self,text,...)self.lines[#self.lines+1]={text,...}end,
 Show=function(self)self.shown=true end,
 Hide=function(self)self.shown=false end,
}
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
function GetGuildInfo(u)return units[u or 'player']and(units[u or 'player'].guild or 'Guild'),playerRank,1 end
function IsInGuild()return true end
function GetNumGuildMembers()return units.party1 and 3 or 2 end
function GetGuildRosterInfo(i)if i==1 then return 'Tester Realm-Realm'elseif i==2 then return 'Friend-Realm'else return 'NoAddon-Realm'end end
function GetNumSubgroupMembers()return units.party1 and 2 or 0 end
function GetNumGroupMembers()return units.party1 and 3 or 0 end
function IsInRaid()return false end
C_GuildInfo={GuildRoster=noop}
function IsInInstance()return inside,inside and 'party' or 'none' end
function GetPlayerInfoByGUID(g)if g=='Player-gnome' then return 'Mage','MAGE','Gnome','Gnome',2,'Tiny','Realm' end end
C_UnitAuras={GetAuraDataByIndex=function(u,i)if u=='target' and i==1 and not units.target.dead then return {spellId=118,sourceUnit='player',auraInstanceID=1,expirationTime=now+10} end end}
C_ChatInfo={RegisterAddonMessagePrefix=noop,SendAddonMessage=function(p,m,c)sent[#sent+1]={p,m,c};return result end}
C_DeathRecap={GetRecapLink=function()return '|Hdeath:9|h' end,GetRecapMaxHealth=function()return 1000 end,GetRecapEvents=function()return {{event='SWING_DAMAGE',amount=0,sourceGUID='Player-gnome',timestamp=now,hideCaster=false}} end}
local A={}
local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',A)end end;toc:close()
assert(forbiddenRegistrations==0,'must not attempt native combat-log registration that generates ADDON_ACTION_FORBIDDEN on Forever')
local function event(e,...)
 for _,f in ipairs(frames)do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f,e,...)end end
end
local function tick()
 now=now+1
 for _,f in ipairs(frames)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1)end end
end
local function delayed()local t=timers;timers={};for _,fn in ipairs(t)do fn()end end
event('ADDON_LOADED','BIHGGnomeKillTracker5000');event('PLAYER_LOGIN');event('PLAYER_ENTERING_WORLD');tick()
if arg[2]=='honor_kills' then
 assert(loadfile((arg[0]:match('^(.*)/')or'tests')..'/honor_kills.lua'))()(A,event,tick,function(v)if v then now=v end;return now end,units)
 return
end
if arg[2]=='encounters' then
 assert(loadfile((arg[0]:match('^(.*)/')or'tests')..'/encounters.lua'))()(A,event,tick,function(v)if v then now=v end;return now end,units,transition)
 return
end
if arg[2]=='native_deaths' then
 assert(loadfile((arg[0]:match('^(.*)/')or'tests')..'/native_deaths.lua'))()(A,event,tick,function(v)if v then now=v end;return now end,units,transition)
 return
end
if arg[2]=='notifications' then
 assert(loadfile((arg[0]:match('^(.*)/')or'tests')..'/notifications.lua'))()(A,event,tick,function(v)if v then now=v end;return now end,units,transition,sent)
 return
end
do
 local writes=0;local original=methods.SetText
 methods.SetText=function(...)writes=writes+1;return original(...)end
 A.mode='Charts';A.RefreshUI()
 assert(writes==0,'hidden dashboard must not mutate text or render charts')
 assert(A.uiDirty,'hidden refresh must leave a pending visible redraw')
 methods.SetText=original;A.mode='Leaderboard'
end
do
 local renders=0;local render=A.RenderCharts
 A.RenderCharts=function(...)renders=renders+1;return render(...)end
 A.mode='Charts';A.window:Show();A.RefreshUI();renders=0
 assert(A.AddGuildEvent('K','Friend-Realm','Player-friend','Player-workload',now,now,now))
 assert(A.uiDirty,'new local witnessed score must dirty the visible dashboard without drawing')
 local accepted=0
 for i=1,1000 do if A.Receive('2|S|0|0|'..A.Day(now)..'|0|0','GUILD','Friend-Realm',now)then accepted=accepted+1 end end
 assert(accepted==450,'native receive path enforces its real per-sender packet budget')
 A.Changed()
 assert(renders==0,'incoming refresh requests and runtime changes must coalesce, not draw synchronously')
 tick();assert(renders==1,'dirty visible dashboard draws once on runtime tick')
 tick();assert(renders==1,'clean dashboard must not redraw charts each runtime tick')
 A.window:Hide();A.mode='Leaderboard';A.RenderCharts=render
 now=now+60 -- subsequent transport checks run outside this deliberate receive flood window
end
do
 local calls=0;local original=C_UnitAuras.GetAuraDataByIndex
 C_UnitAuras.GetAuraDataByIndex=function(...)calls=calls+1;return original(...)end
 units.focus=units.target;units.mouseover=units.target;units.nameplate1=units.target;units.playertarget=units.target;A.plates.nameplate1=true
 now=now+1;A.ScanVisible()
 assert(calls==3,'five hostile aliases share one enumeration (2 calls), plus one bounded out-of-combat incoming victim scan; got '..calls)
 calls=0
 for i=1,100 do event('UNIT_HEALTH','target')end
 assert(calls==0,'health bursts must not repeatedly enumerate unchanged auras')
 event('UNIT_AURA','target');assert(calls==2,'explicit aura notification must inspect fresh data immediately')
 print('WORKLOAD duplicate hostile token aura calls: 2 (baseline 6), plus 1 bounded incoming victim poll; 100 health events: 0; fresh target aura event: 2')
 units.focus=nil;units.mouseover=nil;units.nameplate1=nil;units.playertarget=nil;A.plates.nameplate1=nil
 C_UnitAuras.GetAuraDataByIndex=original
end
assert(A.owner==A.LocalCharacterName(),'runtime must initialize with the readable full local character identity')
if arg[2]=='workload'then print('WORKLOAD hidden dashboard writes: 0; 1000 requests: 1 visible chart draw; clean next tick: 0');return end
assert(A.db and A.owner=='Tester Realm-Realm','login initializes persistence')
assert(A.account and A.account.alias=='Tester Realm','account identity initializes with first toon')
local fullSyncCalls=0;local originalFullSync=A.RequestFullSync
A.RequestFullSync=function()fullSyncCalls=fullSyncCalls+1 end
A.syncButton.scripts.OnClick();SlashCmdList.BIHGGKT('sync')
assert(fullSyncCalls==2,'Refresh data and slash sync both request fresh remote catchup through the full-sync API')
A.RequestFullSync=originalFullSync
assert(A.nearbyFrame and A.nearbyFrame:IsShown()and not A.window:IsShown(),'independent Spy-style nearby widget is visible while dashboard is closed')
assert(A.nearbyCount==1 and A.nearbyRows[1].data.race=='Gnome','readable target feeds nearby list')
local nearbyRow=A.nearbyRows[1]
assert(nearbyRow.level and nearbyRow.class,'Nearby shows separate level and class fields around the name')
assert(A.nearbyFrame:GetWidth()==340 and nearbyRow.frame:GetWidth()==332,'Nearby frame and row widths remain unchanged')
assert(nearbyRow.level.coords[2]<nearbyRow.name.coords[2]and nearbyRow.name.coords[2]<nearbyRow.class.coords[2],'level is left of the name and class follows it')
for _,field in ipairs({nearbyRow.level,nearbyRow.name,nearbyRow.class,nearbyRow.detail})do
 assert(field.coords[2]+field:GetWidth()<=332 and field.wordWrap==false,'all nonwrapping fields fit inside the existing row')
end
assert(nearbyRow.level.text:find('?',1,true)and nearbyRow.class.text:find('?',1,true),'unavailable native metadata is not guessed')
assert(A.nearbyEnableCheck and A.nearbyEnableCheck.template=='UICheckButtonTemplate','Nearby header exposes a real checkbox')
assert(A.nearbyEnableCheck:GetChecked()and A.nearbyEnableLabel.text=='ON','enabled detection is checked and explicitly labeled ON')
A.nearbyEnableCheck:SetChecked(false);A.nearbyEnableCheck.scripts.OnClick(A.nearbyEnableCheck);tick()
assert(not A.nearbyEnableCheck:GetChecked()and A.nearbyEnableLabel.text=='OFF'and A.nearbyCount==0 and A.nearbyFrame:IsShown(),'OFF is obvious, prevents detection and keeps the checkbox accessible')
A.nearbyEnableCheck:SetChecked(true);A.nearbyEnableCheck.scripts.OnClick(A.nearbyEnableCheck);tick()
assert(A.nearbyEnableLabel.text=='ON'and A.nearbyCount==1 and A.nearbyFrame:GetWidth()==340,'checkbox resumes real Runtime detection without widening the window')
assert(A.nearbyRows[1].frame.template=='SecureActionButtonTemplate','nearby names use a secure hardware-click targeting button')
assert(A.nearbyRows[1].frame.attrs.type1=='macro'and A.nearbyRows[1].frame.attrs.macrotext1:find('Tiny-Realm',1,true),'nearby click targets full real name rather than shortened display text')
A.window:Show();A.RefreshUI();A.window:Hide() -- initialize dashboard rows only on actual visible draw
local ownTarget
for _,row in ipairs(A.rows)do local attrs=rawget(row.button,'attrs');if attrs and attrs.macrotext1 and attrs.macrotext1:find(A.owner,1,true)then ownTarget=row.button;break end end
assert(ownTarget and ownTarget.template=='SecureActionButtonTemplate','single-character leaderboard header targets its character, not account alias')
for _,b in ipairs({A.rows[1].button,A.chartRows[1].button,A.nearbyRows[1].frame})do
 local highlight=rawget(b,'highlightTexture')
 assert(highlight and highlight.allPoints==b and highlight.color[4]>0 and highlight.color[4]<0.5,'each clickable name uses a full-hit-area translucent native hover highlight')
 assert(b.scripts.OnClick,'native secure click handlers remain attached with hover feedback')
end
assert(#soundCalls==1 and soundCalls[1][1]==A.BundledNearbySounds[1].value,'actual OnUpdate sends the default short Alliance alarm once')
assert(A.EncounterCount('Lifetime',now)==1,'visible Gnome stored uniquely')
assert(A.db.seen['Player-gnome'],'Alliance player memory')
units.target.dead=true;event('UNIT_HEALTH','target');tick()
assert(A.db.owners[A.owner].total==0,'confirmed CC and corpse alone cannot prove personal HK')
COMBATLOG_HONORGAIN_NO_RANK='You killed %s (Honor: %d)'
event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Tiny (Honor: 4)')
assert(A.db.owners[A.owner].total==1,'fresh named local HK confirms observed Gnome credit without CLEU')
tick();event('PARTY_KILL','Player-me','Player-gnome');assert(A.db.owners[A.owner].total==1,'duplicate death ignored')
event('PLAYER_DEAD');delayed();assert((A.db.owners[A.owner].deaths or 0)==0,'zero effective Gnome damage without harmful proof does not qualify')
event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');now=now+1
C_DeathRecap.GetRecapLink=function()return '|Hdeath:10|h'end
C_DeathRecap.GetRecapEvents=function()return{{event='SWING_DAMAGE',amount=100,sourceGUID='Player-human',timestamp=now,hideCaster=false},{event='SPELL_DAMAGE',amount=20,sourceGUID='Player-gnome',timestamp=now-1,hideCaster=false}}end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'exactly two percent health from a Gnome qualifies even when a different race lands the final blow')
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'same actual death and recap ignored')
event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');now=now+2;event('PLAYER_DEAD');delayed()
assert(A.db.owners[A.owner].deaths==1,'a recap already used in a previous life cannot qualify a new death')
event('PLAYER_ALIVE');units.player.hp=2000;event('PLAYER_REGEN_DISABLED');now=now+4;units.player.hp=1000
C_DeathRecap.GetRecapLink=function()return '|Hdeath:11|h'end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==2,'positive attributed damage is independent of max health')
event('PLAYER_ALIVE');local absoluteClock=GetTime;GetTime=function()return now-1700000000 end;event('PLAYER_REGEN_DISABLED');now=now+4
C_DeathRecap.GetRecapLink=function()return '|Hdeath:12|h'end
C_DeathRecap.GetRecapEvents=function()return{{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=GetTime(),hideCaster=false}}end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==3,'fresh monotonic-clock recaps normalize to the persisted server-time death');GetTime=absoluteClock
A.ToggleUI();A.RefreshUI();assert(A.window:IsShown(),'UI opens')
A.mode='Encounters';A.RefreshUI();A.mode='Leaderboard';A.RefreshUI()
A.dirty=true;inside=true;combat=true;local n=#sent;A.Pump(now);assert(#sent==n,'combat prevents sends even in dungeon')
combat=false;result=3;A.request=false;A.lastRequest=now;A.Pump(now);assert(A.outgoing,'client-rejected dungeon send retains queue')
result=0;for i=1,50 do now=now+1;A.Pump(now);if not A.outgoing and not A.dirty and not A.request then break end end;assert(not A.outgoing and not A.dirty,'successful retry flushes complete metadata/history queue')
A.Receive('2|S|7|3|'..A.Day(now)..'|2|1','GUILD','Friend-Realm',now)
A.RefreshUI();assert(A.PeerRecords()['Friend-Realm'].total==7,'guild peer record merged')
-- Return from the explicit dungeon sync test before local PvP parser tests.
inside=false;event('PLAYER_ENTERING_WORLD')
-- Exercise the optional exact-damage path without aura qualification.
C_UnitAuras.GetAuraDataByIndex=function()return nil end
units.target={guid='Player-damage',name='Other',race='Gnome',faction='Alliance',hp=1000,enemy=true}
A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_DAMAGE',false,'Player-me','Tester',0,0,'Player-damage','Other',0,0,133,'Fireball',4,20,0 end
A.ReadCombatLog()
assert(A.groupTargets['Player-damage'] and A.groupTargets['Player-damage'].actors['Player-me'].damage==20,'own contribution damage parsed into group tracker')
CombatLogGetCurrentEventInfo=function()return now,'UNIT_DIED',false,nil,nil,0,0,'Player-damage','Other',0,0 end
A.ReadCombatLog();assert(A.db.owners[A.owner].total==1,'synthetic attributed damage and death alone cannot prove HK; total='..A.db.owners[A.owner].total..' encounter='..tostring(A.encounters['Player-damage'])..' dead='..tostring(A.db.dead['Player-damage']))
-- A cast-success packet must not qualify as landed crowd control.
units.target={guid='Player-miss',name='Missed',race='Gnome',faction='Alliance',hp=1000,enemy=true};A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_CAST_SUCCESS',false,'Player-me','Tester',0,0,'Player-miss','Missed',0,0,118,'Polymorph',64 end
event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Other (Honor: 4)')
assert(A.db.owners[A.owner].total==2,'named local HK confirms synthetic candidate without own CC requirement')
A.ReadCombatLog();A.GroupDeath('Player-miss',now);assert(A.db.owners[A.owner].total==2,'cast success not confirmed CC')
-- Missing or secret values must fail closed without preventing later reads.
local secret={}
issecretvalue=function(v)return v==secret end
local oldGUID=UnitGUID;UnitGUID=function(u)if u=='target' then return secret end;return oldGUID(u)end
assert(pcall(A.Scan,'target'),'secret unit GUID skipped');UnitGUID=oldGUID
now=now+5 -- allow the real transport bucket to refill before this independent send assertion
assert(A.SendPacket('test'),'out-of-combat send is allowed after budget refill')
local oldCombat=InCombatLockdown;InCombatLockdown=function()return secret end
assert(not A.SendPacket('test'),'secret combat state fails closed');InCombatLockdown=oldCombat
InCombatLockdown=function()return 1 end;assert(not A.SendPacket('test'),'numeric truthy combat state blocks direct sends');InCombatLockdown=oldCombat
inside=false
issecretvalue=function()return false end
-- Zero-size roster while loading must not erase the offline peer cache.
local oldRoster=GetNumGuildMembers;GetNumGuildMembers=function()return 0 end
A.Roster();assert(A.PeerRecords()['Friend-Realm'],'unloaded roster preserves cached stats')
GetNumGuildMembers=oldRoster;A.Roster()
-- Leaderboard exposes only kills/deaths; encounter history keeps its own six fields.
A.mode='Leaderboard';A.RefreshUI()
assert(#A.statCards==2,'summary contains only kills and deaths')
assert(A.headers[1].text=='Alias / character'and A.headers[2].text=='Kills'and A.headers[3].text=='Deaths','leaderboard has only character, kills and deaths headings')
assert(not A.headers[4]:IsShown()and not A.headers[5]:IsShown()and not A.headers[6]:IsShown(),'no K/D or Encountered columns remain on the board')
assert(not A.rows[1][4]:IsShown()and A.rows[1][4].text=='','no stale encounter date or removed metric cell is visible on the board')
A.headers[3].scripts.OnClick();assert(A.sort=='deaths','death sorting still works')
A.headers[3].scripts.OnClick();assert(A.ascending,'reverse sort')
for i=1,7 do A.periodButtons[i].scripts.OnClick()end
A.window.scripts.OnMouseWheel(nil,-1)
SlashCmdList.BIHGGKT('alerts');SlashCmdList.BIHGGKT('encounters');assert(A.window:IsShown(),'encounter command opens')
A.mode='Encounters';A.RefreshUI()
assert(A.headers[5]:IsShown()and A.headers[5].text=='Last seen'and A.rows[1][5]:IsShown(),'encounter history retains its Last seen column')
A.mode='Leaderboard';A.RefreshUI()
assert(not A.headers[4]:IsShown()and not A.rows[1][4]:IsShown(),'returning to leaderboard removes the history-only fourth field')
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
assert(A.owner=='Tester Realm-Realm','internal owner key stays realm qualified')
A.mode='Leaderboard';A.RefreshUI()
for _,row in ipairs(A.rows) do assert(not (row[1].text or ''):find('-Realm',1,true),'leaderboard displays character names only') end
A.mode='Encounters';A.RefreshUI()
for _,row in ipairs(A.rows) do assert(not (row[2].text or ''):find('-Realm',1,true),'encounter log displays character names only') end
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
assert(A.chartPersonalButton and A.chartGuildButton,'daily chart exposes Personal and Guild scope buttons')
assert(A.chartScope=='Personal'and A.chartPersonalButton.selected,'daily chart defaults to Personal with a visible selected state')
assert(A.chartRows[1].button and A.chartRows[1].button.template=='SecureActionButtonTemplate','chart names also use real-character secure targeting buttons')
assert(A.chartsPane:IsShown() and not A.tablePane:IsShown() and not A.settingsPane:IsShown(),'chart view has distinct content pane')
assert(A.chartRows[1].bar.value==7,'native ranking bar uses actual cached alias kills')
A.SelectPeriod('Today')
assert(A.lineDots[1].data.kills==7 and not A.lineDots[2]:IsShown(),'kill line obeys selected period and hides unused points')
assert(A.lineDots[1].coords[4]==175 and not A.lineSegments[1]:IsShown(),'single day is a centered point, not a fictitious time segment')
local scopePeers=A.ViewPeerRecords();local scopeDay=A.Day(now)
scopePeers['ChartPeer-Realm']={total=4,deaths=0,days={[scopeDay]=4},deathDays={},seen={}};A.members['ChartPeer-Realm']=true
local beforeScopeHeading=table.concat(A.BuildTopReport(A.period,now),'\n');local beforeScopeSends=#sent
A.chartGuildButton.scripts.OnClick()
assert(A.chartScope=='Guild'and A.db.options.chartScope=='Guild'and A.chartGuildButton.selected and not A.chartPersonalButton.selected,'Guild button selects and saves chart scope')
assert(A.lineDots[1].data.kills==13 and A.trendSubtitle.text:find('Guild',1,true),'Guild daily chart includes local account, existing Friend credit and remote member daily credit')
assert(table.concat(A.BuildTopReport(A.period,now),'\n')==beforeScopeHeading and #sent==beforeScopeSends,'scope selection does not mutate reports or send messages')
A.chartPersonalButton.scripts.OnClick();assert(A.lineDots[1].data.kills==7 and A.chartPersonalButton.selected,'Personal button restores only local account daily credit')
scopePeers['ChartPeer-Realm']=nil;A.members['ChartPeer-Realm']=nil
A.SelectPeriod('7 days')
assert(A.lineSegments[6]:IsShown() and not A.lineSegments[7]:IsShown(),'seven daily points form six connected line segments')
assert(A.lineSegments[1].start[3]==0 and A.lineSegments[6].finish[3]==350,'line runs from earliest to latest date')
assert(A.lineYTicks[1].text=='0' and A.lineXAxis.text:find('Time',1,true),'numeric kill axis and date axis are labeled')
assert(A.chartFromInput and A.chartToInput and A.chartSlider and A.chartStartHandle and A.chartEndHandle,'chart provides typed dates and two independent range handles')
local today=A.Day(now)
local typedStart=date('!%Y-%m-%d',(today-4)*86400)
assert(type(A.chartFromInput.scripts.OnTextChanged)=='function','date editors track user changes independently of keyboard focus')
A.chartFromInput:SetText(typedStart);A.chartFromInput.scripts.OnTextChanged(A.chartFromInput,true);A.chartFromInput:ClearFocus();A.RenderCharts(now)
assert(A.chartFromInput:GetText()==typedStart,'periodic refresh preserves unapplied typed dates after moving focus to the other field')
A.chartFromInput:SetText(date('!%Y-%m-%d',(today-4)*86400));A.chartToInput:SetText(date('!%Y-%m-%d',(today-2)*86400));A.chartApplyButton.scripts.OnClick()
assert(#A.lineData.points==3 and A.lineData.points[1].day==today-4 and A.lineData.points[3].day==today-2,'entered inclusive dates update the visible daily chart')
A.chartGuildButton.scripts.OnClick();assert(#A.lineData.points==3 and A.lineData.points[1].day==today-4 and A.lineData.points[3].day==today-2,'custom date endpoints remain in force for Guild mode')
A.chartPersonalButton.scripts.OnClick();assert(#A.lineData.points==3,'custom date endpoints remain in force when returning to Personal')
A.chartFromInput:SetText('2023-02-30');A.chartApplyButton.scripts.OnClick();assert(A.chartDateError and #A.lineData.points==3,'invalid calendar input shows an error without changing the selected window')
A.SelectPeriod('This year');assert(#A.lineData.points>30 and A.lineData.points[1].day==A.FirstDay('This year',now),'PERIOD sets full calendar bounds without the old thirty-day truncation')
assert(A.lineDots[#A.lineData.points]:IsShown(),'full retained/calendar ranges render every daily point, not just the first thirty')
A.SelectPeriod('7 days');local rangeFirst,rangeLast,minimum,maximum=A.GetChartRange(A.period,now)
assert(rangeFirst==minimum and rangeLast==maximum and minimum==today-6 and maximum==today,'changing PERIOD resets handles to its full outer bounds')
local cursorX,mouseDown=0,true;local oldCursor,oldMouse=GetCursorPosition,IsMouseButtonDown
GetCursorPosition=function()return cursorX,0 end;IsMouseButtonDown=function()return mouseDown end;A.chartSlider.left=100
A.chartStartHandle.scripts.OnMouseDown(A.chartStartHandle,'LeftButton');cursorX=100+350*2/6;A.chartSlider.scripts.OnUpdate()
assert(select(1,A.GetChartRange(A.period,now))==today-4,'dragging start handle updates the left chart date using actual slider coordinates')
local beforeTyping=A.chartFromInput:GetText();A.chartFromInput:SetFocus();A.chartFromInput:SetText('2023-02-30');A.chartFromInput.scripts.OnTextChanged(A.chartFromInput,true);A.chartFromInput.scripts.OnEscapePressed(A.chartFromInput)
assert(not A.chartFromInput.focused and not A.chartDatesDirty and A.chartFromInput:GetText()==beforeTyping,'Escape discards pending date edits and restores the actual graph range')
cursorX=100+700;A.chartSlider.scripts.OnUpdate();local left,right=A.GetChartRange(A.period,now);assert(left==right,'start handle cannot cross the end handle')
mouseDown=false;A.chartSlider.scripts.OnUpdate();assert(not A.chartDragging,'releasing outside the handle stops dragging')
A.SelectPeriod('7 days');mouseDown=true;A.chartSlider.GetEffectiveScale=function()return 0.5 end
A.chartEndHandle.scripts.OnMouseDown(A.chartEndHandle,'LeftButton');cursorX=(100+350*4/6)*0.5;A.chartSlider.scripts.OnUpdate()
assert(select(2,A.GetChartRange(A.period,now))==today-2,'end handle moves independently and accounts for effective UI scale')
cursorX=0;A.chartSlider.scripts.OnUpdate();left,right=A.GetChartRange(A.period,now);assert(left==right and left==today-6,'end handle cannot cross the start handle')
A.chartEndHandle.scripts.OnMouseUp();A.chartSlider.GetEffectiveScale=nil
A.SelectPeriod('Today');assert(#A.lineData.points==1 and A.lineData.points[1].x==175,'single-day PERIOD produces a centered chart point')
A.chartStartHandle.scripts.OnMouseDown(A.chartStartHandle,'LeftButton');assert(not A.chartDragging,'single-day outer bounds cannot initiate a range drag')
GetCursorPosition,IsMouseButtonDown=oldCursor,oldMouse;A.SelectPeriod('7 days')
A.OpenView('Leaderboard',false);assert(A.tablePane:IsShown() and not A.chartsPane:IsShown(),'returning from charts restores table')
local chat={};local clicking=false;local outsideClick=0
SendChatMessage=function(msg,channel)if channel=='GUILD'and not clicking then outsideClick=outsideClick+1;error('guild chat requires player action')end;chat[#chat+1]={msg,channel}end
assert(A.copyReportButton,'copy/cut report is a separate button, not a replacement for direct guild posting')
local beforeCopyCooldown=A.db.options.lastTopPost;local originalReport=table.concat(A.BuildTopReport(A.period,now),'\n')
A.copyReportButton.scripts.OnClick()
assert(A.copyReportFrame:IsShown()and A.copyReportEdit:GetText()==originalReport and A.copyReportEdit.multiline and A.copyReportEdit.focused and A.copyReportEdit.selectedAll,'copy button opens a focused multiline native editable report with one person per line')
assert(#chat==0 and not A.postJob and A.db.options.lastTopPost==beforeCopyCooldown,'copying does not send chat, create posting progress or consume the post cooldown')
A.copyReportEdit:SetText('');assert(table.concat(A.BuildTopReport(A.period,now),'\n')==originalReport,'cutting/editing export text never modifies underlying scores or report data')
A.copyReportFrame:Hide();assert(not A.copyReportEdit.focused,'closing export releases keyboard focus')
A.reportButton.scripts.OnClick();assert(A.preview:IsShown() and #chat==0 and not A.postJob,'preview never posts automatically')
clicking=true;A.confirmPostButton.scripts.OnClick();clicking=false
assert(#chat==1 and chat[1][1]==A.previewLines[1]and A.preview:IsShown()and A.postJob,'first confirmation sends only the heading and keeps progress visible')
local postingSnapshot=A.postJob;local sentBeforeExport=#chat
A.copyReportButton.scripts.OnClick();A.copyReportEdit:SetText('Edited export only');A.copyReportFrame:Hide()
assert(A.postJob==postingSnapshot and A.preview:IsShown()and #chat==sentBeforeExport and postingSnapshot.lines[1]==A.previewLines[1],'copy/cut export remains independent of an in-progress direct guild report')
assert(A.confirmPostButton:GetText():find('Send #1',1,true),'same button labels the next ranked player')
clicking=true;A.confirmPostButton.scripts.OnClick();clicking=false;assert(#chat==1,'rapid duplicate click cannot burst the next line')
for i=0,10 do tick()end
assert(#chat==1 and outsideClick==0,'runtime updates never send or retry a public guild report')
for i=2,#A.previewLines do
 clicking=true;A.confirmPostButton.scripts.OnClick();clicking=false
 assert(#chat==i and chat[i][1]==A.previewLines[i]and chat[i][2]=='GUILD','one explicit click attempts exactly the next previewed line in order');tick()
end
assert(not A.preview:IsShown()and not A.postJob,'final line closes the completed preview')
A.db.options.lastTopPost=nil;A.ShowTopPreview();clicking=true;A.confirmPostButton.scripts.OnClick();clicking=false
assert(A.postJob,'a partially posted report holds manual progress')
local beforeCancel=#chat;A.preview:Hide();assert(not A.postJob,'closing the report preview cancels unsent lines')
for i=1,3 do tick()end;assert(#chat==beforeCancel,'cancelled lines are never sent by update callbacks')
local savedSync,savedRoster=A.syncStatus,A.rosterStatus
A.syncStatus='Send blocked / retrying';A.rosterStatus='guild membership confirmed';A.RefreshUI()
assert(A.status.text=='Send blocked / retrying','footer shows descriptive sync state without policy boilerplate')
assert(A.membershipStatusLabel and A.membershipStatusLabel.text=='guild membership confirmed','footer retains live membership confirmation')
local tocVersion=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc')):read('*a'):match('## Version: ([^\r\n]+)')
assert(A.versionLabel and A.versionLabel.text=='v'..tocVersion and A.versionLabel.coords[1]=='BOTTOMRIGHT','visible bottom-right version matches the loaded package TOC')
assert(not A.coverageLabel and not A.postStatusLabel,'tracking and report-policy boilerplate no longer occupy the footer')
A.syncStatus='Sent 08:05 - member reports unverified';A.RefreshUI();assert(A.status.text=='Sent 08:05','concise sent status omits the old footer disclaimer')
A.syncStatus=savedSync;A.rosterStatus=savedRoster;A.RefreshUI()
playerRank='Member';A.RefreshUI();assert(not A.reportButton:IsShown(),'restricted rank hides report button')
assert(A.copyReportButton:IsShown(),'local copy/cut export remains available without granting direct-post rank permission')
SlashCmdList.BIHGGKT('top');assert(not A.preview:IsShown()and not A.postJob,'slash command cannot bypass rank restriction')
playerRank='The BIHG Cheese';A.RefreshUI();assert(A.reportButton:IsShown(),'second exact allowed rank sees report action')
A.ShowTopPreview();assert(A.preview:IsShown());playerRank='Member';A.RefreshUI()
assert(not A.preview:IsShown(),'rank loss closes an existing confirmation preview')
A.confirmPostButton.scripts.OnClick();assert(not A.postJob and A.postStatus:find('restricted',1,true),'stale confirmation click cannot bypass authorization')
playerRank='Council of BIHG'
-- Party-only observation works without any addon message from the guildmate.
units.party1={name='NoAddon',guid='Player-noaddon',race='Orc',faction='Horde',hp=1000,guild='Guild'}
units.partypet1={guid='Pet-noaddon'}
units.party2={name='Guest',guid='Player-guest',race='Orc',faction='Horde',hp=1000,guild='Other'}
event('GROUP_ROSTER_UPDATE')
assert(A.PeerRecords()['NoAddon-Realm'].observerOnly,'guildmate is discovered on group join without addon handshake')
units.target={guid='Player-party-gnome',name='Victim',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='target'and i==1 and not units.target.dead then return{spellId=118,sourceUnit='party1',auraInstanceID=201,expirationTime=now+10}end end
event('PLAYER_TARGET_CHANGED');units.target.dead=true;event('UNIT_HEALTH','target')
event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Victim (Honor: 4)')
assert(A.GuildEffectiveRecord('NoAddon-Realm',A.PeerRecords()['NoAddon-Realm'],now).total==1,'visible party CC and confirmed death credit guildmate')
units.target={guid='Player-guest-gnome',name='Other victim',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='target'and i==1 and not units.target.dead then return{spellId=118,sourceUnit='party2',auraInstanceID=202,expirationTime=now+10}end end
event('PLAYER_TARGET_CHANGED');units.target.dead=true;event('UNIT_HEALTH','target')
assert(not A.PeerRecords()['Guest-Realm'],'non-guild party CC is never tallied')
A.OpenView('Leaderboard',false);local shown=false
for _,row in ipairs(A.rows)do if(row[1].text or ''):find('NoAddon',1,true)then shown=(row[1].text or ''):find('[observed]',1,true)~=nil end end
assert(shown,'non-addon guildmate is visibly marked as observed')
A.ClearNearby()
units.nameplate1={guid='Player-near-human',name='Tall',race='Human',faction='Alliance',hp=1000,enemy=true}
units.nameplate2={guid='Player-near-gnome',name='Short',race='Gnome',faction='Alliance',hp=1000,enemy=true}
units.nameplate2.level=60;units.nameplate2.class='Mage'
UnitLevel=function(u)return units[u]and units[u].level end;UnitClass=function(u)return units[u]and units[u].class end
units.nameplate3={guid='Creature-npc',name='NPC',race='Gnome',faction='Alliance',hp=1000,enemy=true}
units.nameplate4={guid='Player-near-horde',name='Orc',race='Orc',faction='Horde',hp=1000}
units.nameplate5={guid='Player-far',name='Far',race='Gnome',faction='Alliance',hp=1000,enemy=true,visible=false}
UnitIsVisible=function(u)return units[u]and units[u].visible~=false end
for i=1,5 do event('NAME_PLATE_UNIT_ADDED','nameplate'..i)end;tick()
assert(A.nearbyCount==2 and A.nearbyRows[1].data.guid=='Player-near-gnome','nearby window lists visible Alliance only, Gnomes first')
assert(not A.nearbyRows[1].name.text:find('-Realm',1,true),'nearby names hide realm suffix')
assert(A.nearbyRows[1].level.text:find('60',1,true)and A.nearbyRows[1].class.text:find('Mage',1,true),'actual Runtime scans feed displayed native level and localized class')
local tooltipRow=A.nearbyRows[1];local originalNearbyName=tooltipRow.data.name
A.NearbyNotice(tooltipRow.data.guid,'ReviewName-Surname','Gnome','Alliance',now,false,true,60,'Mage');A.RefreshNearby(now)
assert(tooltipRow.name.text=='|cffffb347ReviewName|r','fixed-width row keeps the shortened name')
local tooltipMacro=tooltipRow.frame.attrs.macrotext1
assert(tooltipMacro:find('/targetexact ReviewName-Surname',1,true),'secure target binding keeps the full stored identity')
tooltipRow.frame.scripts.OnEnter(tooltipRow.frame)
assert(GameTooltip.shown and GameTooltip.owner==tooltipRow.frame and GameTooltip.anchor=='ANCHOR_LEFT','actual row OnEnter opens its tooltip')
assert(GameTooltip.text=='ReviewName-Surname','Nearby tooltip title must retain full stored identity; got '..tostring(GameTooltip.text))
assert(GameTooltip.lines[1][1]=='Level 60 | Mage | Gnome','tooltip includes full level, class and race details')
assert(tooltipRow.frame.attrs.macrotext1==tooltipMacro,'hover must not change secure target bindings')
tooltipRow.frame.scripts.OnLeave(tooltipRow.frame);assert(not GameTooltip.shown,'actual row OnLeave hides its tooltip')
A.NearbyNotice(tooltipRow.data.guid,originalNearbyName,'Gnome','Alliance',now,false,true,60,'Mage');A.RefreshNearby(now)
local frozenMacro=A.nearbyRows[1].frame.attrs.macrotext1
transition(true);A.NearbyNotice('Player-combat-new','NewEnemy-Realm','Gnome','Alliance',now+5,false,true,55,'Rogue');A.RefreshNearby(now+5);A.RefreshUI()
assert(A.nearbyRows[1].data.name=='NewEnemy-Realm','new combat contact must immediately replace the first displayed row')
assert(A.nearbyRows[1].level.text:find('55',1,true)and A.nearbyRows[1].class.text:find('Rogue',1,true),'combat metadata remains live')
assert(A.nearbyRows[1].frame.attrs.macrotext1==frozenMacro,'combat display changes never rebind secure actions')
assert(not rawget(A.nearbyFrame,'protected'),'display root must have no protected descendants or anchor dependents')
for _,row in ipairs(A.nearbyRows)do
 assert(row.displayFrame.parent==A.nearbyFrame and row.displayFrame.mouse==false and not rawget(row.displayFrame,'highlightTexture')and not row.displayFrame.scripts.OnEnter,'display rows have neither mouse nor hover feedback')
 assert(row.hitFrame.parent==A.nearbyClickLayer and not row.hitFrame:IsVisible(),'all old/new native click and highlight areas inherit securely hidden state')
end
assert(not GameTooltip.shown,'combat entry closes the old target tooltip')
GameTooltip:SetOwner(A.nearbyButtons.clear,'ANCHOR_TOP');GameTooltip:SetText('Clear help');GameTooltip:Show();A.RefreshNearby(now+5)
assert(GameTooltip.shown,'combat row refresh must not dismiss unrelated/control tooltips')
GameTooltip:Hide()
transition(false);assert(not A.nearbyClickLayer:IsShown(),'driver must not expose stale targets on combat exit')
event('PLAYER_REGEN_ENABLED')
assert(A.nearbyClickLayer:IsShown()and A.nearbyRows[1].hitFrame.attrs.macrotext1:find('NewEnemy-Realm',1,true),'regen event immediately binds current identities before exposing clicks')
frozenMacro=A.nearbyRows[1].hitFrame.attrs.macrotext1
transition(true)
A.nearbyEnableCheck:SetChecked(false);A.nearbyEnableCheck.scripts.OnClick(A.nearbyEnableCheck)
assert(A.nearbyEnableLabel.text=='OFF'and not A.nearbyEnableCheck:GetChecked()and A.nearbyRows[1].frame.attrs.macrotext1==frozenMacro,'master OFF remains obvious in combat without rebinding protected targets')
A.nearbyEnableCheck:SetChecked(true);A.nearbyEnableCheck.scripts.OnClick(A.nearbyEnableCheck)
transition(false);assert(not A.nearbyClickLayer:IsShown(),'available state never reopens stale actions');A.ForgetNearby('Player-combat-new');A.RefreshNearby(now)
local savedEncounter=A.db.seen['Player-near-gnome'];local savedKills=A.db.owners[A.owner].total
local soundsBeforeClear=#soundCalls
assert(A.nearbyButtons.clear,'Nearby needs an explicit Clear button')
A.nearbyButtons.clear.scripts.OnClick()
assert(A.nearbyCount==0 and A.db.seen['Player-near-gnome']==savedEncounter and A.db.owners[A.owner].total==savedKills,'Clear empties nearby list without deleting history/statistics')
assert(A.nearbyRows[1].level.text==''and A.nearbyRows[1].class.text=='','empty/reused rows clear level and class text')
tick();assert(A.nearbyCount==2,'still-visible players can be detected again after clearing')
assert(#soundCalls==soundsBeforeClear,'Clear cannot cause repeated alerts for already observed contacts')
A.nearbyButtons.collapse.scripts.OnClick()
assert(A.nearbyFrame:IsShown()and A.nearbyFrame.height==24 and not A.nearbyRows[1].frame:IsShown(),'collapse retains compact counted header')
A.nearbyButtons.collapse.scripts.OnClick();assert(A.nearbyRows[1].frame:IsShown(),'expand restores list')
A.nearbyButtons.lock.scripts.OnClick();A.nearbyHeader.scripts.OnDragStart();assert(not rawget(A.nearbyFrame,'moves'),'locked widget cannot drag')
A.nearbyButtons.lock.scripts.OnClick();A.nearbyHeader.scripts.OnDragStart();A.nearbyHeader.scripts.OnDragStop();assert(A.nearbyFrame.moves==1 and A.db.options.nearbyPosition,'drag position persists independently')
A.nearbyButtons.close.scripts.OnClick();assert(not A.nearbyFrame:IsShown(),'close hides nearby widget')
SlashCmdList.BIHGGKT('nearby');assert(A.nearbyFrame:IsShown(),'slash command restores widget')
A.window:Hide();A.nearbyButtons.history.scripts.OnClick();assert(A.window:IsShown()and A.mode=='Encounters','history control opens separate encounter log')
A.OpenView('Settings',false);A.nearbyToggleButton.scripts.OnClick();assert(not A.nearbyFrame:IsShown(),'settings can hide overlay without hiding the dashboard')
A.nearbyToggleButton.scripts.OnClick();assert(A.nearbyFrame:IsShown(),'settings can restore overlay')
assert(A.allianceAudioToggle and A.gnomeAudioToggle,'separate sound controls exist')
A.gnomeAudioToggle.scripts.OnClick();assert(A.db.options.extraGnomeSoundEnabled,'extra Gnome sound is independently configurable')
A.gnomeAudioToggle.scripts.OnClick();assert(not A.db.options.extraGnomeSoundEnabled,'extra Gnome sound can be disabled')
A.allianceToneButton.scripts.OnClick();assert(A.soundPicker:IsShown()and A.soundPickerKind=='alliance','sound picker opens for correct alert type')
assert(#A.soundPickerData>=4 and A.soundPickerRows[1].choice,'downloaded alarm choices are selectable')
local choice=A.soundPickerRows[2].choice.name;A.soundPickerRows[2].select.scripts.OnClick()
assert(A.db.options.allianceTone==choice and not A.soundPicker:IsShown(),'sound choice persists and closes picker')
A.gnomeToneButton.scripts.OnClick();assert(A.soundPickerKind=='gnome','Gnome choice uses independent picker target')
A.soundSearch:SetText('BIHG: Short alarm 4');A.soundSearch.scripts.OnTextChanged()
assert(#A.soundPickerData==1 and A.soundPickerRows[1].choice.name=='BIHG: Short alarm 4','picker supports literal name filtering')
A.soundPicker:Hide()
local media=assert(LibStub('LibSharedMedia-3.0',true),'bundled SharedMedia library must actually load from TOC')
for i=1,15 do assert(media:Register('sound','External sound '..i,A.BundledNearbySounds[3].value))end
assert(media:Register('sound','Third-party warning',A.BundledNearbySounds[4].value))
A.allianceToneButton.scripts.OnClick();local allSounds=A.GetNearbySoundChoices()
assert(#A.soundPickerData>10,'real SharedMedia registry includes all third-party sounds, not just presets')
A.soundPickerNext.scripts.OnClick();assert(A.soundPage==2 and A.soundPickerRows[1].choice.name==allSounds[11].name,'picker pages the complete registry')
A.soundSearch:SetText('__no_such_sound__');A.soundSearch.scripts.OnTextChanged()
assert(#A.soundPickerData==0 and not A.soundPickerRows[1].select:IsShown()and not A.soundPickerRows[1].preview:IsShown(),'empty sound searches have no blank actionable rows')
A.soundSearch:SetText('Third-party warning');A.soundSearch.scripts.OnTextChanged()
local selectedBefore=A.db.options.allianceTone;local previewBefore=#soundCalls;A.soundPickerRows[1].preview.scripts.OnClick()
assert(#soundCalls==previewBefore+1 and soundCalls[#soundCalls][1]==A.BundledNearbySounds[4].value and A.db.options.allianceTone==selectedBefore,'third-party Preview plays the registry value without changing selection')
A.soundPicker:Hide()
A.audioChannelButton.scripts.OnClick();assert(A.db.options.soundChannel=='SFX','audio channel is configurable in Settings')
local beforePreview=#soundCalls;A.alliancePreviewButton.scripts.OnClick()
assert(#soundCalls==beforePreview+1 and soundCalls[#soundCalls][2]=='SFX','Preview uses selected channel through actual UI handler')
for i=1,10 do A.NearbyNotice('Player-page-'..i,'Extra'..i..'-Realm',i<=3 and'Gnome'or'Human','Alliance',now,false,true)end
A.RefreshNearby(now);local all=A.NearbyList(now)
assert(A.nearbyButtons.next:IsShown()and A.nearbyCount==12,'long nearby list exposes paging controls')
A.nearbyButtons.next.scripts.OnClick();assert(A.nearbyPage==2 and A.nearbyRows[1].data.guid==all[9].guid,'next page follows Gnome-first ordering without duplicate rows')
A.nearbyButtons.previous.scripts.OnClick();assert(A.nearbyPage==1,'previous page restores first entries')
for i=1,5 do event('NAME_PLATE_UNIT_REMOVED','nameplate'..i);units['nameplate'..i]=nil end
for i=1,31 do tick()end
assert(A.nearbyCount==0 and A.nearbyFrame.height==24,'expired sightings leave only the Spy-style header')
assert(A.db.seen['Player-near-gnome'],'nearby expiration never deletes historical encounters')
A.NearbyNotice('Player-zone-old','Old zone','Gnome','Alliance',now,false,true)
event('ZONE_CHANGED_NEW_AREA');A.RefreshNearby(now)
assert(A.nearbyCount==0,'changing area clears previous-zone nearby sightings')
local beforeFaerie=A.db.owners[A.owner].total
units.target={guid='Player-faerie-live',name='FaerieVictim',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=770,sourceUnit='player'}end end
tick();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed FaerieVictim (Honor: 4)')
assert(A.db.owners[A.owner].total==beforeFaerie+1,'landed own Faerie Fire aura qualifies with zero damage')
units.target={guid='Player-faerie-miss',name='MissedFaerie',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function()end;tick()
CombatLogGetCurrentEventInfo=function()return now,'SPELL_CAST_SUCCESS',false,UnitGUID('player'),'Tester',0,0,units.target.guid,'MissedFaerie',0,0,770 end
A.ReadCombatLog();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeFaerie+1,'Faerie Fire cast success without a landed aura does not qualify')
units.target={guid='Player-faerie-guild',name='GuildFaerie',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=16857,sourceUnit='party1'}end end
tick();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed GuildFaerie (Honor: 4)')
assert(A.GuildEffectiveRecord('NoAddon-Realm',A.PeerRecords()['NoAddon-Realm'],now).total==2,'guildmate Feral Faerie Fire aura qualifies without addon or damage')
local beforeDebuffs=A.db.owners[A.owner].total
units.target={guid='Player-curse',name='Cursed',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index,filter)assert(filter=='HARMFUL','visible fallback must query harmful auras only');if unit=='target'and index==1 then return {spellId=702,sourceUnit='player',isHarmful=true}end end
tick();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Cursed (Honor: 4)')
assert(A.db.owners[A.owner].total==beforeDebuffs+1,'own landed curse with zero damage qualifies')
units.target={guid='Player-helpful',name='Buffed',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=118,sourceUnit='player',isHelpful=true,isHarmful=false}end end
tick();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeDebuffs+1,'explicit helpful aura cannot qualify')
C_UnitAuras.GetAuraDataByIndex=function()end
for _,kind in ipairs({'BUFF','UNKNOWN','DEBUFF','DOSE'})do
 local guid='Player-log-'..kind;units.target={guid=guid,name='AuraTarget'..kind,race='Gnome',faction='Alliance',hp=1000,enemy=true};tick()
 CombatLogGetCurrentEventInfo=function()return now,kind=='DOSE'and'SPELL_AURA_APPLIED_DOSE'or'SPELL_AURA_APPLIED',false,UnitGUID('party1'),'NoAddon',0,0,guid,'AuraTarget',0,0,702,'Curse',32,kind=='DOSE'and'DEBUFF'or kind end
 A.ReadCombatLog();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed AuraTarget'..kind..' (Honor: 4)')
end
assert(A.GuildEffectiveRecord('NoAddon-Realm',A.PeerRecords()['NoAddon-Realm'],now).total==4,'only explicit DEBUFF combat-log applications, including added stacks, grant guildmate credit')
local beforeLives=A.db.owners[A.owner].total
units.target={guid='Player-debuff-lives',name='Again',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=702,sourceUnit='player'}end end
tick();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Again (Honor: 4)')
units.target.dead=false;tick();tick();tick();units.target.dead=true;tick();event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Again (Honor: 4)')
assert(A.db.owners[A.owner].total==beforeLives+2,'a new life can earn debuff credit again when aura instance/expiry fields are unavailable')
-- Public party alerts run from the actual scan/update path even while secure
-- nearby rows are frozen; they do not require the guild-report officer ranks.
local partyMessages={};SendChatMessage=function(text,channel)partyMessages[#partyMessages+1]={text,channel}end
A.partyAlertPending={};A.db.partyAlertContacts={};A.partyAlertNext=0;A.partySendBudget=nil;A.partyRetryAt=nil
units.target={guid='Player-party-detected',name='Detected',race='Gnome',faction='Alliance',hp=1000,enemy=true}
playerRank='Member';combat=true;tick()
assert(#partyMessages==1 and partyMessages[1][2]=='PARTY'and partyMessages[1][1]:find('GNOME DETECTED : ',1,true)==1,'live scan/timer announces Gnomes to party during combat, independent of guild-report rank')
tick();assert(#partyMessages==1,'actual scan repetition does not spam party')
combat=false;A.OpenView('Settings',false);assert(A.partyAlertToggle.text:find('ON',1,true),'party announcement setting is discoverable')
A.partyAlertToggle.scripts.OnClick();assert(not A.db.options.partyAllianceAlerts and not next(A.partyAlertPending),'UI switch disables and cancels queued party alerts')
local debugOutput={};local originalLocalMessage=DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage=function(_,text)debugOutput[#debugOutput+1]=text end
local publicBefore=#partyMessages;local addonBefore=#sent
event('ADDON_ACTION_BLOCKED','BIHGGnomeKillTracker5000','SendChatMessage()');SlashCmdList.BIHGGKT('debug')
local debugText=table.concat(debugOutput,' ')
assert(A.VERSION=='1.9.1'and tocVersion==A.VERSION,'release metadata matches actual TOC')
assert(debugText:find('BIHG own death outcomes',1,true)and debugText:find('counted',1,true),'actual slash exposes persisted own death diagnostics')
assert(debugText:find('BIHG report status:',1,true)and debugText:find('ADDON_ACTION_BLOCKED',1,true)and debugText:find('SendChatMessage()',1,true),'actual event and slash wiring expose protected-send diagnostics')
assert(#partyMessages==publicBefore and #sent==addonBefore,'debug command is local-only and never posts a test message')
DEFAULT_CHAT_FRAME.AddMessage=originalLocalMessage
assert(A.window.template:find('SecureHandlerStateTemplate',1,true)and stateDrivers[A.window],'main config window installs secure combat state handling')
A.OpenView('Settings',false);A.OpenSoundPicker('alliance');A.preview:Show()
playerRank='Council of BIHG';A.db.options.lastTopPost=nil;assert(A.StartTopPost({'heading','ranked person'},now),'manual progress exists before combat auto-close')
assert(A.ShowCopyReport()and A.copyReportEdit.focused,'export text holds focus before combat auto-close')
A.chartFromInput:SetFocus();A.chartDragging='first';local beforeCombatPeriod=A.period
assert(A.window:IsShown()and A.soundPicker:IsShown(),'settings and picker open before combat')
local secureSnippet=assert(loadstring(A.window.attrs['_onstate-'..stateDrivers[A.window].id]))
transition(true)
assert(not A.window:IsShown()and not A.preview:IsShown()and not A.soundPicker:IsShown(),'entering combat securely closes dashboard, report preview and config picker')
assert(not A.chartFromInput.focused and not A.chartDragging,'combat closure releases date-editor focus and stops range dragging')
A.SelectPeriod('Today');assert(A.period==beforeCombatPeriod,'PERIOD/range controls remain frozen during combat')
local lockedScope=A.chartScope;assert(not A.SelectChartScope(lockedScope=='Guild'and'Personal'or'Guild')and A.chartScope==lockedScope,'chart scope cannot change while protected UI is combat locked')
assert(not A.copyReportFrame:IsShown()and not A.copyReportEdit.focused,'combat/menu closure dismisses export and releases text focus')
assert(not A.postJob,'combat auto-close cancels remaining manual report lines without deferral')
assert(A.nearbyFrame:IsShown(),'combat auto-close leaves independent Nearby overlay available')
transition(false);tick()
assert(not A.window:IsShown(),'leaving combat does not reopen config automatically')
A.OpenView('Settings',false);assert(A.window:IsShown(),'user can reopen normally after combat')
A.account.characters['CacheAlt-Realm']={total=0,deaths=0,days={},deathDays={},seen={['Player-alt-history']={name='SharedAltSight',race='Gnome',first=now-1,last=now,days={[A.Day(now)]=true}}}}
A.OpenView('Encounters',false);local sharedVisible=false
for _,row in ipairs(A.rows)do if row.data and row.data.name=='SharedAltSight'then sharedVisible=true end end
assert(sharedVisible and not A.db.seen['Player-alt-history'],'actual encounter UI reads other local character history without adding personal attribution')
local liveKey,liveMembers=A.guildKey,A.members;A.guildKey=nil;A.members={};A.OpenView('Leaderboard',false)
assert(A.summary.text:find('cached guild history (read-only)',1,true)and not A.reportButton:IsShown()and A.guildKey==nil,'cached-only UI is explicitly labeled and cannot authorize public posting')
A.guildKey=liveKey;A.members=liveMembers;A.RefreshUI()
-- A transient max-health peak must constrain both recap and incoming-event proofs.
event('PLAYER_ALIVE');local oldAffectingCombat=UnitAffectingCombat;UnitAffectingCombat=function()return true end
units.player.hp=1000;event('PLAYER_REGEN_DISABLED');A.RefreshGroupActors();local deathBeforePeak=A.db.owners[A.owner].deaths
units.player.hp=2000;event('UNIT_MAXHEALTH','player');units.player.hp=1000;event('UNIT_MAXHEALTH','player')
local incoming={};incoming[2]='SWING_DAMAGE';incoming[4]='Player-gnome';incoming[8]='Player-me';incoming[12]=39;incoming[13]=0
A.GroupCombat(incoming,now);local ownDied={};ownDied[2]='UNIT_DIED';ownDied[8]='Player-me';A.GroupCombat(ownDied,now)
assert(A.db.owners[A.owner].deaths==deathBeforePeak+1,'positive incoming damage counts independently of max-health peak')
-- Late collector creation at the lower current health still uses the known own peak.
A.RefreshGroupActors();A.GroupCombat(incoming,now);A.GroupCombat(ownDied,now)
assert(A.db.owners[A.owner].deaths==deathBeforePeak+1,'same death still deduplicates independently of health')
UnitAffectingCombat=oldAffectingCombat
A.SetNearbyEnabled(false)
local pausedLocalAlerts=0;local oldLocalMessage=DEFAULT_CHAT_FRAME.AddMessage
local oldLegacyAlerts=A.db.options.alerts;A.db.options.alerts=true
DEFAULT_CHAT_FRAME.AddMessage=function(_,msg)if msg:find('PausedSight',1,true)then pausedLocalAlerts=pausedLocalAlerts+1 end end
units.nameplatePaused={guid='Player-paused-world',name='PausedSight',race='Gnome',faction='Alliance',hp=1000,enemy=true}
A.mode='Encounters';A.window:Show();A.RefreshUI();assert(not A.uiDirty)
local oldFullShare,oldDirty=A.fullShare,A.dirty;A.fullShare=false;A.dirty=false
event('NAME_PLATE_UNIT_ADDED','nameplatePaused')
assert(A.dirty and not A.fullShare,'a fresh sighting queues lightweight metadata, not another lifetime-history replay')
A.fullShare=false;event('PLAYER_ENTERING_WORLD')
assert(not A.fullShare,'same-guild world entry does not force unchanged lifetime-history replay')
A.fullShare=oldFullShare;A.dirty=oldDirty
assert(A.uiDirty,'new encounter must schedule visible history redraw even while Nearby is paused')
assert(pausedLocalAlerts==0 and not A.nearbySeen['Player-paused-world'],'Nearby OFF suppresses local detection chat as well as contacts')
assert(A.db.seen['Player-paused-world'],'pausing Nearby does not disable persistent encounter history')
A.RefreshGroupActors();local killsWhilePaused=A.db.owners[A.owner].total
A.GroupCC('Player-paused-world',770,UnitGUID('player'),now,true)
A.GroupDeath('Player-paused-world',now,true);event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed PausedSight (Honor: 4)')
assert(A.db.owners[A.owner].total==killsWhilePaused+1,'open-world kill recording continues while Nearby is OFF')
DEFAULT_CHAT_FRAME.AddMessage=oldLocalMessage;event('NAME_PLATE_UNIT_REMOVED','nameplatePaused');units.nameplatePaused=nil
A.db.options.alerts=oldLegacyAlerts
A.SetNearbyEnabled(true)
-- Exercise real runtime scheduling: a full history queue must not starve alerts.
local priorScan=A.ScanVisible;A.ScanVisible=function()end
local priorAddonSend=C_ChatInfo.SendAddonMessage;local priorPartySend=SendChatMessage
local priorSubgroup,priorRaid=GetNumSubgroupMembers,IsInRaid
GetNumSubgroupMembers=function()return 2 end;IsInRaid=function()return false end
local fairAddon,fairParty=0,0;C_ChatInfo.SendAddonMessage=function()fairAddon=fairAddon+1;return 0 end
SendChatMessage=function(_,channel)if channel=='PARTY'then fairParty=fairParty+1 end end
A.sendBudget=nil;A.sendRetryAt=nil;A.sendFailures=0;A.sendClock=nil;A.lastRequest=now;A.request=false;A.helloPending=false;A.catchupPending=nil
A.syncNamespaceSet=true;A.syncNamespace=A.guildKey;A.groupPending[A.guildKey]={};A.outgoing={};for i=1,100 do A.outgoing[i]='history-'..i end;A.outIndex=1
A.partyAlertPending={};A.partyAlertNext=0;A.partySendBudget=nil;A.partyRetryAt=nil;A.db.options.partyAllianceAlerts=true
A.NearbyNotice('Player-fair-budget','FairBudget-Realm','Gnome','Alliance',now,false,true,60,'Mage')
for i=1,6 do tick()end
assert(fairParty==1 and fairAddon>0,'runtime must deliver queued party alert without starving paced history, or vice versa')
A.ScanVisible=priorScan;C_ChatInfo.SendAddonMessage=priorAddonSend;SendChatMessage=priorPartySend;GetNumSubgroupMembers=priorSubgroup;IsInRaid=priorRaid
-- Isolated live-overlay transitions through the actual TOC implementation.
A.ClearNearby();A.nearbyPage=1;A.db.options.nearbyCollapsed=false
A.NearbyNotice('Player-live-old','Old-Realm','Human','Alliance',now,false,true,60,'Warrior');A.RefreshNearby(now)
A.nearbyRows[1].hitFrame.scripts.OnEnter(A.nearbyRows[1].hitFrame);assert(GameTooltip.shown)
local oldAttrs=A.nearbyRows[1].hitFrame.attrs.macrotext1
local createdBefore=#frames
transition(true)
for i=1,10 do A.NearbyNotice('Player-live-'..i,'Live'..i..'-Realm',i==10 and'Gnome'or'Human','Alliance',now+i,false,true,40+i,'Mage')end
A.RefreshNearby(now+10)
assert(#frames==createdBefore and A.nearbyRows[1].data.name=='Live10-Realm','combat reuses all precreated rows with live Gnome-first sorting')
A.nearbyButtons.next.scripts.OnClick();assert(A.nearbyPage==2 and A.nearbyRows[1].data,'combat paging remains live')
A.nearbyButtons.collapse.scripts.OnClick();assert(A.nearbyFrame.height==24 and not A.nearbyRows[1].displayFrame:IsShown(),'combat collapse changes only the unprotected display')
A.nearbyButtons.collapse.scripts.OnClick();A.ToggleNearby(false);assert(not A.nearbyFrame:IsShown());A.ToggleNearby(true)
A.NearbyNotice('Player-live-10','Live10-Realm','Gnome','Alliance',now+11,true,true)
A.nearbyPage=1;A.RefreshNearby(now+11);assert(A.nearbyRows[1].data.name=='Live9-Realm','combat corpse removal immediately reorders rows')
A.RefreshNearby(now+50);assert(A.nearbyCount==0 and A.nearbyFrame.height==24,'combat TTL expiration clears the live display')
assert(A.nearbyRows[1].hitFrame.attrs.macrotext1==oldAttrs and not A.nearbyClickLayer:IsVisible(),'expired protected data stays inaccessible and untouched')
A.ClearNearby();A.SetNearbyEnabled(false);A.SetNearbyEnabled(true)
A.NearbyNotice('Player-live-current','Current-Surname','Gnome','Alliance',now,false,true,60,'Rogue');A.RefreshNearby(now)
transition(false);assert(not A.nearbyClickLayer:IsShown(),'no automatic ghost targets on available state')
event('PLAYER_REGEN_ENABLED')
assert(A.nearbyRows[1].hitFrame:IsVisible()and A.nearbyRows[1].hitFrame.attrs.macrotext1:find('Current-Surname',1,true),'only current identity becomes clickable after combat')
for i=2,A.NEARBY_ROWS do local hit=A.nearbyRows[i].hitFrame;assert(not hit:IsVisible()and not hit.attrs.type1 and not hit.attrs.macrotext1,'all unused stale actions cleared before layer shows')end
assert(not rawget(A.nearbyFrame,'protected')and A.nearbyFrame:GetWidth()==340 and A.nearbyRows[1].displayFrame:GetWidth()==332)
A.nearbyFrame.left=73;A.nearbyFrame.top=412;A.nearbyFrame.GetEffectiveScale=function()return 0.5 end
A.RefreshNearby(now)
assert(A.nearbyClickLayer.coords[2]==UIParent and A.nearbyClickLayer.coords[4]==36.5 and A.nearbyClickLayer.coords[5]==206,'secure geometry follows actual post-clamp coordinates and scale')
assert(stateDrivers[A.nearbyClickLayer].condition=='[combat] closed; available','native state driver owns combat concealment')
A.nearbyFrame.GetTop=function()return nil end;A.RefreshNearby(now)
assert(A.nearbyClickLayer.coords[1]=='CENTER'and A.nearbyClickLayer.coords[2]==UIParent and A.nearbyClickLayer.coords[3]=='CENTER','unavailable geometry uses a wellformed UIParent-relative fallback')
A.nearbyFrame.GetTop=nil
A.nearbyHeader.scripts.OnDragStart();assert(not A.nearbyClickLayer:IsVisible(),'dragging removes stale hitboxes before moving')
A.RefreshNearby(now);assert(not A.nearbyClickLayer:IsVisible(),'timer refresh cannot expose mid-drag hitboxes');A.nearbyHeader.scripts.OnDragStop();assert(A.nearbyClickLayer:IsVisible())
-- A drag released after combat starts must finish without touching secure hits.
do
 local w,layer=A.nearbyFrame,A.nearbyClickLayer
 local stops=w.stops;local oldMacro=A.nearbyRows[1].hitFrame.attrs.macrotext1
 A.nearbyHeader.scripts.OnDragStart()
 assert(A.nearbyDragging and w.moving and not layer:IsVisible(),'real drag callback starts movement and conceals hits')
 transition(true);event('PLAYER_REGEN_DISABLED')
 w.left=244;w.top=354
 w.GetPoint=function()return 'TOPLEFT',UIParent,'BOTTOMLEFT',244,354 end
 A.NearbyNotice('Player-drag-current','AfterDrag-Realm','Gnome','Alliance',now+1,false,true,59,'Mage')
 A.RefreshNearby(now+1)
 A.nearbyHeader.scripts.OnDragStop()
 assert(not A.nearbyDragging,'combat-interrupted drag release must clear Nearby dragging state')
 assert(not w.moving and w.stops==stops+1,'combat-interrupted drag release must stop display movement')
 local pos=A.db.options.nearbyPosition
 assert(pos[1]=='TOPLEFT'and pos[2]=='BOTTOMLEFT'and pos[3]==244 and pos[4]==354,'combat drag release persists the final display position')
 assert(not layer:IsVisible()and A.nearbyRows[1].hitFrame.attrs.macrotext1==oldMacro,'combat drag release keeps secure hits hidden and bindings untouched')
 transition(false)
 assert(not layer:IsVisible(),'combat exit cannot auto-show stale pre-drag bindings')
 local shows=0;local show=methods.Show
 layer.Show=function(self)
  shows=shows+1
  assert(self.coords[2]==UIParent and self.coords[4]==122 and self.coords[5]==177,'post-combat hits align to final dragged display geometry before showing')
  for _,row in ipairs(A.nearbyRows)do
   assert(row.hitFrame.attrs.macrotext1==A.TargetMacro(row.data and row.data.name),'every secure identity is fresh before the layer reopens')
  end
  return show(self)
 end
 event('PLAYER_REGEN_ENABLED')
 assert(shows==1 and layer:IsVisible()and A.nearbyRows[1].hitFrame:IsVisible()and A.nearbyRows[1].data.name=='AfterDrag-Realm','regen restores current clickable rows without a second manual drag')
 layer.Show=nil;w.GetPoint=nil
 tick();assert(layer:IsVisible()and not A.nearbyDragging,'runtime refresh retains recovered clickability')
 print('PASS combat-interrupted Nearby drag: release stops movement, clears state, defers protected writes and restores fresh aligned clicks on regen')
end
-- Login-in-combat defers every constructor; unavailable drivers fail closed.
A.nearbyFrame=nil;A.nearbyClickLayer=nil;createdBefore=#frames;transition(true);A.CreateNearbyUI()
assert(not A.nearbyFrame and #frames==createdBefore,'login combat never constructs protected or display rows')
transition(false);event('PLAYER_REGEN_ENABLED');assert(A.nearbyFrame and A.nearbyClickLayer,'regen creates deferred overlay')
local originalDriver=RegisterStateDriver;RegisterStateDriver=nil;A.nearbyFrame=nil;A.nearbyClickLayer=nil
A.CreateNearbyUI();assert(A.nearbyFrame and not A.nearbyClickLayer,'missing driver leaves usable display only')
for _,row in ipairs(A.nearbyRows)do assert(not row.hitFrame and row.frame==row.displayFrame and not row.frame.mouse and not rawget(row.frame,'highlightTexture'),'no driver means no click or highlight targets')end
transition(true);A.ClearNearby();A.NearbyNotice('Player-no-driver','NoDriver','Gnome','Alliance',now,false,true);A.RefreshNearby(now)
assert(A.nearbyRows[1].data.name=='NoDriver','fail-closed display stays live during combat');transition(false);RegisterStateDriver=originalDriver
assert(not A.lastError,'guarded runtime error: '..tostring(A.lastError))
print('PASS actual TOC integration: lifecycle, protected targeting, persistent scores, rank-gated guild reports, independent party detection chat, local-only report diagnostics and guarded APIs')
