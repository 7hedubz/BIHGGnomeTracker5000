local root=arg[1] or '.'
local now=1700000000
local frames={}; local timers={}; local sent={}; local inside=false; local result=0;local forbiddenRegistrations=0
local combat=false;function InCombatLockdown()return combat end
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
methods.StartMoving=function(self)self.moves=(rawget(self,'moves')or 0)+1 end
function CreateFrame(_,name,parent,template)local o=obj();o.template=template;if template and template:find('SecureActionButtonTemplate',1,true)then o.scripts.OnClick=noop end;frames[#frames+1]=o;if name then _G[name]=o end;return o end
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
function GetGuildInfo(u)return units[u or 'player']and(units[u or 'player'].guild or 'Guild'),playerRank,1 end
function IsInGuild()return true end
function GetNumGuildMembers()return units.party1 and 3 or 2 end
function GetGuildRosterInfo(i)if i==1 then return 'Tester-Realm'elseif i==2 then return 'Friend-Realm'else return 'NoAddon-Realm'end end
function GetNumSubgroupMembers()return units.party1 and 2 or 0 end
function GetNumGroupMembers()return units.party1 and 3 or 0 end
function IsInRaid()return false end
C_GuildInfo={GuildRoster=noop}
function IsInInstance()return inside,'none' end
function GetPlayerInfoByGUID(g)if g=='Player-gnome' then return 'Mage','MAGE','Gnome','Gnome',2,'Tiny','Realm' end end
C_UnitAuras={GetAuraDataByIndex=function(u,i)if u=='target' and i==1 and not units.target.dead then return {spellId=118,sourceUnit='player',auraInstanceID=1,expirationTime=now+10} end end}
C_ChatInfo={RegisterAddonMessagePrefix=noop,SendAddonMessage=function(p,m,c)sent[#sent+1]={p,m,c};return result end}
C_DeathRecap={GetRecapLink=function()return '|Hdeath:9|h' end,GetRecapMaxHealth=function()return 1000 end,GetRecapEvents=function()return {{event='SWING_DAMAGE',amount=500,sourceGUID='Player-gnome',timestamp=now,hideCaster=false}} end}
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
assert(A.db and A.owner=='Tester-Realm','login initializes persistence')
assert(A.account and A.account.alias=='Tester','account identity initializes with first toon')
assert(A.nearbyFrame and A.nearbyFrame:IsShown()and not A.window:IsShown(),'independent Spy-style nearby widget is visible while dashboard is closed')
assert(A.nearbyCount==1 and A.nearbyRows[1].data.race=='Gnome','readable target feeds nearby list')
assert(A.nearbyRows[1].frame.template=='SecureActionButtonTemplate','nearby names use a secure hardware-click targeting button')
assert(A.nearbyRows[1].frame.attrs.type1=='macro'and A.nearbyRows[1].frame.attrs.macrotext1:find('Tiny-Realm',1,true),'nearby click targets full real name rather than shortened display text')
assert(A.rows[1].button.template=='SecureActionButtonTemplate'and A.rows[1].button.attrs.macrotext1:find('Tester-Realm',1,true),'single-character leaderboard header targets its character, not account alias')
for _,b in ipairs({A.rows[1].button,A.chartRows[1].button,A.nearbyRows[1].frame})do
 local highlight=rawget(b,'highlightTexture')
 assert(highlight and highlight.allPoints==b and highlight.color[4]>0 and highlight.color[4]<0.5,'each clickable name uses a full-hit-area translucent native hover highlight')
 assert(b.scripts.OnClick,'native secure click handlers remain attached with hover feedback')
end
assert(#soundCalls==1 and soundCalls[1][1]==A.BundledNearbySounds[1].value,'actual OnUpdate sends the default short Alliance alarm once')
assert(A.EncounterCount('Lifetime',now)==1,'visible Gnome stored uniquely')
assert(A.db.seen['Player-gnome'],'Alliance player memory')
units.target.dead=true;event('UNIT_HEALTH','target');tick()
assert(A.db.owners[A.owner].total==1,'confirmed own CC + observed death awards kill without CLEU')
tick();event('PARTY_KILL','Player-me','Player-gnome');assert(A.db.owners[A.owner].total==1,'duplicate death ignored')
event('PLAYER_DEAD');delayed();assert((A.db.owners[A.owner].deaths or 0)==0,'a Gnome final blow with exactly half maximum health damage does not qualify')
event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');now=now+1
C_DeathRecap.GetRecapLink=function()return '|Hdeath:10|h'end
C_DeathRecap.GetRecapEvents=function()return{{event='SWING_DAMAGE',amount=100,sourceGUID='Player-human',timestamp=now,hideCaster=false},{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=now-1,hideCaster=false}}end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'more than half health from a Gnome qualifies even when a different race lands the final blow')
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'same actual death and recap ignored')
event('PLAYER_ALIVE');event('PLAYER_REGEN_DISABLED');now=now+2;event('PLAYER_DEAD');delayed()
assert(A.db.owners[A.owner].deaths==1,'a recap already used in a previous life cannot qualify a new death')
event('PLAYER_ALIVE');units.player.hp=2000;event('PLAYER_REGEN_DISABLED');now=now+1;units.player.hp=1000
C_DeathRecap.GetRecapLink=function()return '|Hdeath:11|h'end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==1,'a maximum-health drop cannot lower the threshold below the observed combat peak')
event('PLAYER_ALIVE');local absoluteClock=GetTime;GetTime=function()return now-1700000000 end;event('PLAYER_REGEN_DISABLED');now=now+1
C_DeathRecap.GetRecapLink=function()return '|Hdeath:12|h'end
C_DeathRecap.GetRecapEvents=function()return{{event='SPELL_DAMAGE',amount=600,sourceGUID='Player-gnome',timestamp=GetTime(),hideCaster=false}}end
event('PLAYER_DEAD');delayed();assert(A.db.owners[A.owner].deaths==2,'fresh monotonic-clock recaps normalize to the persisted server-time death');GetTime=absoluteClock
A.ToggleUI();A.RefreshUI();assert(A.window:IsShown(),'UI opens')
A.mode='Encounters';A.RefreshUI();A.mode='Leaderboard';A.RefreshUI()
A.dirty=true;inside=true;combat=true;local n=#sent;A.Pump(now);assert(#sent==n,'combat prevents sends even in dungeon')
combat=false;result=3;A.request=false;A.lastRequest=now;A.Pump(now);assert(A.outgoing,'client-rejected dungeon send retains queue')
result=0;for i=1,50 do A.Pump(now+i);if not A.outgoing and not A.dirty and not A.request then break end end;assert(not A.outgoing and not A.dirty,'successful retry flushes complete metadata/history queue')
A.Receive('2|S|7|3|'..A.Day(now)..'|2|1','GUILD','Friend-Realm',now)
A.RefreshUI();assert(A.PeerRecords()['Friend-Realm'].total==7,'guild peer record merged')
-- Exercise the optional exact-damage path without aura qualification.
C_UnitAuras.GetAuraDataByIndex=function()return nil end
units.target={guid='Player-damage',name='Other',race='Gnome',faction='Alliance',hp=1000,enemy=true}
A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_DAMAGE',false,'Player-me','Tester',0,0,'Player-damage','Other',0,0,133,'Fireball',4,20,0 end
A.ReadCombatLog()
assert(A.groupTargets['Player-damage'] and A.groupTargets['Player-damage'].actors['Player-me'].damage==20,'own contribution damage parsed into group tracker')
CombatLogGetCurrentEventInfo=function()return now,'UNIT_DIED',false,nil,nil,0,0,'Player-damage','Other',0,0 end
A.ReadCombatLog();assert(A.db.owners[A.owner].total==2,'readable log exact 2% damage path; total='..A.db.owners[A.owner].total..' encounter='..tostring(A.encounters['Player-damage'])..' dead='..tostring(A.db.dead['Player-damage']))
-- A cast-success packet must not qualify as landed crowd control.
units.target={guid='Player-miss',name='Missed',race='Gnome',faction='Alliance',hp=1000,enemy=true};A.Scan('target')
CombatLogGetCurrentEventInfo=function()return now,'SPELL_CAST_SUCCESS',false,'Player-me','Tester',0,0,'Player-miss','Missed',0,0,118,'Polymorph',64 end
A.ReadCombatLog();A.GroupDeath('Player-miss',now);assert(A.db.owners[A.owner].total==2,'cast success not confirmed CC')
-- Missing or secret values must fail closed without preventing later reads.
local secret={}
issecretvalue=function(v)return v==secret end
local oldGUID=UnitGUID;UnitGUID=function(u)if u=='target' then return secret end;return oldGUID(u)end
assert(pcall(A.Scan,'target'),'secret unit GUID skipped');UnitGUID=oldGUID
assert(A.SendPacket('test'),'out-of-combat dungeon send is allowed')
local oldCombat=InCombatLockdown;InCombatLockdown=function()return secret end
assert(not A.SendPacket('test'),'secret combat state fails closed');InCombatLockdown=oldCombat
InCombatLockdown=function()return 1 end;assert(not A.SendPacket('test'),'numeric truthy combat state blocks direct sends');InCombatLockdown=oldCombat
inside=false
issecretvalue=function()return false end
-- Zero-size roster while loading must not erase the offline peer cache.
local oldRoster=GetNumGuildMembers;GetNumGuildMembers=function()return 0 end
A.Roster();assert(A.PeerRecords()['Friend-Realm'],'unloaded roster preserves cached stats')
GetNumGuildMembers=oldRoster;A.Roster()
-- Leaderboard exposes only kills/deaths; encounter history keeps its own four fields.
A.mode='Leaderboard';A.RefreshUI()
assert(#A.statCards==2,'summary contains only kills and deaths')
assert(A.headers[1].text=='Alias / character'and A.headers[2].text=='Kills'and A.headers[3].text=='Deaths','leaderboard has only character, kills and deaths headings')
assert(not A.headers[4]:IsShown()and not A.headers[5],'no K/D or Encountered columns remain on the board')
assert(not A.rows[1][4]:IsShown()and A.rows[1][4].text=='','no stale encounter date or removed metric cell is visible on the board')
A.headers[3].scripts.OnClick();assert(A.sort=='deaths','death sorting still works')
A.headers[3].scripts.OnClick();assert(A.ascending,'reverse sort')
for i=1,7 do A.periodButtons[i].scripts.OnClick()end
A.window.scripts.OnMouseWheel(nil,-1)
SlashCmdList.BIHGGKT('alerts');SlashCmdList.BIHGGKT('encounters');assert(A.window:IsShown(),'encounter command opens')
A.mode='Encounters';A.RefreshUI()
assert(A.headers[4]:IsShown()and A.headers[4].text=='Last seen'and A.rows[1][4]:IsShown(),'encounter history retains its Last seen column')
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
assert(A.chartRows[1].button and A.chartRows[1].button.template=='SecureActionButtonTemplate','chart names also use real-character secure targeting buttons')
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
units.nameplate3={guid='Creature-npc',name='NPC',race='Gnome',faction='Alliance',hp=1000,enemy=true}
units.nameplate4={guid='Player-near-horde',name='Orc',race='Orc',faction='Horde',hp=1000}
units.nameplate5={guid='Player-far',name='Far',race='Gnome',faction='Alliance',hp=1000,enemy=true,visible=false}
UnitIsVisible=function(u)return units[u]and units[u].visible~=false end
for i=1,5 do event('NAME_PLATE_UNIT_ADDED','nameplate'..i)end;tick()
assert(A.nearbyCount==2 and A.nearbyRows[1].data.guid=='Player-near-gnome','nearby window lists visible Alliance only, Gnomes first')
assert(not A.nearbyRows[1].name.text:find('-Realm',1,true),'nearby names hide realm suffix')
local frozenName=A.nearbyRows[1].data.name;local frozenMacro=A.nearbyRows[1].frame.attrs.macrotext1
combat=true;A.NearbyNotice('Player-combat-new','NewEnemy-Realm','Gnome','Alliance',now+5,false,true);A.RefreshNearby(now+5);A.RefreshUI()
assert(A.nearbyRows[1].data.name==frozenName and A.nearbyRows[1].frame.attrs.macrotext1==frozenMacro,'combat cannot reorder displayed names away from protected click bindings')
combat=false;A.ForgetNearby('Player-combat-new');A.RefreshNearby(now)
local savedEncounter=A.db.seen['Player-near-gnome'];local savedKills=A.db.owners[A.owner].total
local soundsBeforeClear=#soundCalls
assert(A.nearbyButtons.clear,'Nearby needs an explicit Clear button')
A.nearbyButtons.clear.scripts.OnClick()
assert(A.nearbyCount==0 and A.db.seen['Player-near-gnome']==savedEncounter and A.db.owners[A.owner].total==savedKills,'Clear empties nearby list without deleting history/statistics')
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
tick();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeFaerie+1,'landed own Faerie Fire aura qualifies with zero damage')
units.target={guid='Player-faerie-miss',name='MissedFaerie',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function()end;tick()
CombatLogGetCurrentEventInfo=function()return now,'SPELL_CAST_SUCCESS',false,UnitGUID('player'),'Tester',0,0,units.target.guid,'MissedFaerie',0,0,770 end
A.ReadCombatLog();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeFaerie+1,'Faerie Fire cast success without a landed aura does not qualify')
units.target={guid='Player-faerie-guild',name='GuildFaerie',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=16857,sourceUnit='party1'}end end
tick();units.target.dead=true;tick()
assert(A.GuildEffectiveRecord('NoAddon-Realm',A.PeerRecords()['NoAddon-Realm'],now).total==2,'guildmate Feral Faerie Fire aura qualifies without addon or damage')
local beforeDebuffs=A.db.owners[A.owner].total
units.target={guid='Player-curse',name='Cursed',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index,filter)assert(filter=='HARMFUL','visible fallback must query harmful auras only');if unit=='target'and index==1 then return {spellId=702,sourceUnit='player',isHarmful=true}end end
tick();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeDebuffs+1,'own landed curse with zero damage qualifies')
units.target={guid='Player-helpful',name='Buffed',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=118,sourceUnit='player',isHelpful=true,isHarmful=false}end end
tick();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeDebuffs+1,'explicit helpful aura cannot qualify')
C_UnitAuras.GetAuraDataByIndex=function()end
for _,kind in ipairs({'BUFF','UNKNOWN','DEBUFF','DOSE'})do
 local guid='Player-log-'..kind;units.target={guid=guid,name='AuraTarget',race='Gnome',faction='Alliance',hp=1000,enemy=true};tick()
 CombatLogGetCurrentEventInfo=function()return now,kind=='DOSE'and'SPELL_AURA_APPLIED_DOSE'or'SPELL_AURA_APPLIED',false,UnitGUID('party1'),'NoAddon',0,0,guid,'AuraTarget',0,0,702,'Curse',32,kind=='DOSE'and'DEBUFF'or kind end
 A.ReadCombatLog();units.target.dead=true;tick()
end
assert(A.GuildEffectiveRecord('NoAddon-Realm',A.PeerRecords()['NoAddon-Realm'],now).total==4,'only explicit DEBUFF combat-log applications, including added stacks, grant guildmate credit')
local beforeLives=A.db.owners[A.owner].total
units.target={guid='Player-debuff-lives',name='Again',race='Gnome',faction='Alliance',hp=1000,enemy=true}
C_UnitAuras.GetAuraDataByIndex=function(unit,index)if unit=='target'and index==1 then return {spellId=702,sourceUnit='player'}end end
tick();units.target.dead=true;tick()
units.target.dead=false;tick();tick();tick();units.target.dead=true;tick()
assert(A.db.owners[A.owner].total==beforeLives+2,'a new life can earn debuff credit again when aura instance/expiry fields are unavailable')
-- Public party alerts run from the actual scan/update path even while secure
-- nearby rows are frozen; they do not require the guild-report officer ranks.
local partyMessages={};SendChatMessage=function(text,channel)partyMessages[#partyMessages+1]={text,channel}end
A.partyAlertPending={};A.db.partyAlertContacts={};A.partyAlertNext=0
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
assert(debugText:find('BIHG report status:',1,true)and debugText:find('ADDON_ACTION_BLOCKED',1,true)and debugText:find('SendChatMessage()',1,true),'actual event and slash wiring expose protected-send diagnostics')
assert(#partyMessages==publicBefore and #sent==addonBefore,'debug command is local-only and never posts a test message')
DEFAULT_CHAT_FRAME.AddMessage=originalLocalMessage
assert(A.window.template:find('SecureHandlerStateTemplate',1,true)and stateDrivers[A.window],'main config window installs secure combat state handling')
A.OpenView('Settings',false);A.OpenSoundPicker('alliance');A.preview:Show()
playerRank='Council of BIHG';A.db.options.lastTopPost=nil;assert(A.StartTopPost({'heading','ranked person'},now),'manual progress exists before combat auto-close')
assert(A.ShowCopyReport()and A.copyReportEdit.focused,'export text holds focus before combat auto-close')
assert(A.window:IsShown()and A.soundPicker:IsShown(),'settings and picker open before combat')
local secureSnippet=assert(loadstring(A.window.attrs['_onstate-'..stateDrivers[A.window].id]))
combat=true;setfenv(secureSnippet,{self=A.window,newstate='closed'});secureSnippet()
assert(not A.window:IsShown()and not A.preview:IsShown()and not A.soundPicker:IsShown(),'entering combat securely closes dashboard, report preview and config picker')
assert(not A.copyReportFrame:IsShown()and not A.copyReportEdit.focused,'combat/menu closure dismisses export and releases text focus')
assert(not A.postJob,'combat auto-close cancels remaining manual report lines without deferral')
assert(A.nearbyFrame:IsShown(),'combat auto-close leaves independent Nearby overlay available')
combat=false;setfenv(secureSnippet,{self=A.window,newstate='available'});secureSnippet();tick()
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
local incoming={};incoming[2]='SWING_DAMAGE';incoming[4]='Player-gnome';incoming[8]='Player-me';incoming[12]=600;incoming[13]=0
A.GroupCombat(incoming,now);local ownDied={};ownDied[2]='UNIT_DIED';ownDied[8]='Player-me';A.GroupCombat(ownDied,now)
assert(A.db.owners[A.owner].deaths==deathBeforePeak,'incoming UNIT_DIED cannot bypass the observed transient max-health peak')
-- Late collector creation at the lower current health still uses the known own peak.
A.RefreshGroupActors();A.GroupCombat(incoming,now);A.GroupCombat(ownDied,now)
assert(A.db.owners[A.owner].deaths==deathBeforePeak,'late incoming collectors cannot lower the own combat health denominator')
UnitAffectingCombat=oldAffectingCombat
assert(not A.lastError,'guarded runtime error: '..tostring(A.lastError))
print('PASS actual TOC integration: lifecycle, protected targeting, persistent scores, rank-gated guild reports, independent party detection chat, local-only report diagnostics and guarded APIs')
