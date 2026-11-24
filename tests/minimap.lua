-- Actual TOC, focused minimap interaction and saved-settings regression.
local root=arg[1]or'.';local here=arg[0]:match('^(.*)/')or'tests'
local f=assert(io.open(here..'/integration.lua'));local lines={};for line in f:lines()do lines[#lines+1]=line;if #lines==126 then break end end;f:close()
local test=[[
Minimap.GetCenter=function()return 100,100 end;Minimap.GetEffectiveScale=function()return 2 end;Minimap:SetSize(140,140)
local px,py=400,200;GetCursorPosition=function()return px,py end
event('PLAYER_LOGIN');assert(A.db and not A.lastError,A.lastError)
local m=BIHGGKTMinimap
assert(type(m.scripts.OnDragStart)=='function'and type(m.scripts.OnDragStop)=='function','minimap must provide native drag handlers')
assert(m.scripts.OnUpdate==nil,'minimap must have no idle polling')
assert(A.minimapCheck and A.minimapCheck:GetChecked(),'settings must expose checked Show minimap icon by default')
local total=A.db.owners[A.owner].total;local nearby=A.db.options.nearbyEnabled
m.scripts.OnDragStart(m,'LeftButton');assert(type(m.scripts.OnUpdate)=='function')
m.scripts.OnUpdate(m);assert(math.abs(A.db.options.minimapAngle)<0.00001,'right cursor should save zero degrees with scale applied')
px,py=200,400;m.scripts.OnUpdate(m)
assert(math.abs(A.db.options.minimapAngle-90)<0.00001,'top cursor saves 90 degrees')
local p=m.coords;assert(p[1]=='CENTER'and p[2]==Minimap and math.abs(p[4])<0.00001 and math.abs(p[5]-78)<0.00001,'drag must orbit the minimap edge rather than move its parent')
m.scripts.OnDragStop(m);assert(m.scripts.OnUpdate==nil,'drag polling must stop immediately')
A.window:Hide();m.scripts.OnClick(m,'LeftButton');assert(not A.window:IsShown(),'release after drag must not open the dashboard')
for _,fn in ipairs(timers)do fn()end
m.scripts.OnClick(m,'LeftButton');assert(A.window:IsShown()and A.mode=='Leaderboard','ordinary left click preserved after drag')
m.scripts.OnClick(m,'RightButton');assert(A.mode=='Encounters','ordinary right click preserved')
A.minimapCheck:SetChecked(false);A.minimapCheck.scripts.OnClick(A.minimapCheck)
assert(A.db.options.minimapShown==false and not m:IsShown(),'checkbox immediately hides icon')
assert(A.db.owners[A.owner].total==total and A.db.options.nearbyEnabled==nearby,'hiding icon must not affect tracking or Nearby')
SlashCmdList.BIHGGKT('settings');assert(A.window:IsShown()and A.mode=='Settings'and not A.minimapCheck:GetChecked(),'slash settings remains reachable while hidden')
A.minimapCheck:SetChecked(true);A.minimapCheck.scripts.OnClick(A.minimapCheck)
assert(m:IsShown()and A.db.options.minimapShown==true and A.db.options.minimapAngle==90,'restore keeps position')
combat=true;m.scripts.OnDragStart(m,'LeftButton');assert(not m.scripts.OnUpdate,'combat drag must not start')
combat=false;m.scripts.OnDragStart(m,'LeftButton');combat=true;m.scripts.OnUpdate(m);assert(not m.scripts.OnUpdate,'combat interrupts drag without leaving a timer')
combat=false;for _,fn in ipairs(timers)do fn()end
-- Reload from serialized minimap options, preserving ordinary character data.
BIHGGKTDB.options=assert(loadstring('return {minimapShown=false,minimapAngle=90}'))()
local B={};local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',B)end end;toc:close()
B.eventFrame.scripts.OnEvent(B.eventFrame,'PLAYER_LOGIN');assert(B.db and not B.lastError,B.lastError)
assert(not BIHGGKTMinimap:IsShown()and B.db.options.minimapAngle==90 and not B.minimapCheck:GetChecked(),'saved hidden position must survive reload')
assert(BIHGGKTMinimap.scripts.OnUpdate==nil,'reloaded hidden icon must not poll')
print('PASS minimap: scaled orbit drag, saved position/visibility, settings restore, click semantics, combat and zero idle polling')
]]
assert(loadstring(table.concat(lines,'\n')..'\n'..test))()
