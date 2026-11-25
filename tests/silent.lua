-- Actual-TOC local-only mode: every public/addon/audio call is mocked.
local root=arg[1]or'.';local here=arg[0]:match('^(.*)/')or'tests'
local f=assert(io.open(here..'/integration.lua'));local lines={};for line in f:lines()do lines[#lines+1]=line;if #lines==126 then break end end;f:close()
local test=[[
units.target=nil;function GetNumSubgroupMembers()return 1 end;function IsInRaid()return false end
local public={};SendChatMessage=function(text,ch)public[#public+1]={text,ch}end
event('PLAYER_LOGIN');assert(A.db and not A.lastError,A.lastError)
assert(A.nearbySilentCheck and A.nearbySilentLabel.text=='Silent','tracker must expose second checkbox labeled exactly Silent')
assert(not A.nearbySilentCheck:GetChecked(),'broadcast-enabled state is unchecked')
assert(A.nearbyEnableLabel:GetWidth()>=24,'OFF must retain the other thread\'s four-pixel clipping fix')
local right=0
local controls={A.nearbyHeaderText,A.nearbyEnableCheck,A.nearbyEnableLabel,A.nearbySilentCheck,A.nearbySilentLabel}
for _,key in ipairs({'clear','history','lock','collapse','previous','next','close'})do controls[#controls+1]=A.nearbyButtons[key]end
for _,control in ipairs(controls)do local x=control.coords[2];assert(x>=right and x+control:GetWidth()<=340,'header controls must not overlap or exceed original width');right=x+control:GetWidth()end
A.NearbyNotice('Player-before-silent','Before-Realm','Gnome','Alliance',now,false,true,60,'Mage')
assert(next(A.partyAlertPending),'test must queue an eligible party message')
local soundEnabled=A.db.options.allianceSoundEnabled;local extra=A.db.options.extraGnomeSoundEnabled
A.nearbySilentCheck:SetChecked(true);A.nearbySilentCheck.scripts.OnClick(A.nearbySilentCheck)
assert(A.db.options.partyAllianceAlerts==false and not next(A.partyAlertPending),'checking Silent immediately cancels party queue')
assert(A.db.options.nearbyEnabled~=false and A.db.options.allianceSoundEnabled==soundEnabled and A.db.options.extraGnomeSoundEnabled==extra,'Silent must not pause detection or mute sounds')
A.PumpPartyAlerts(now);assert(#public==0,'queued message must not escape after Silent selected')
local beforeSound=#soundCalls;local beforeAddon=#sent
units.target={guid='Player-silent-new',name='Local',race='Gnome',faction='Alliance',hp=1000,enemy=true}
tick();tick();assert(#public==0,'actual timer must not send party chat while Silent checked')
assert(#soundCalls>beforeSound,'Silent still plays local discovery beep')
assert(A.nearbySeen['Player-silent-new']and A.db.seen['Player-silent-new'],'local display and persistent encounter history stay active')
assert(A.guildKey and not A.guildUnverified and A.members[A.owner],'Silent must not revoke guild tracking authority')
assert(#sent>beforeAddon,'silent addon synchronization must advance during Silent-mode ticks')
-- Existing Settings control is the same option, not a competing flag.
A.OpenView('Settings',false);A.partyAlertToggle.scripts.OnClick();A.RefreshNearby(now)
assert(A.db.options.partyAllianceAlerts==true and not A.nearbySilentCheck:GetChecked(),'Settings enabling party alerts unchecks Silent')
A.nearbySilentCheck:SetChecked(true);A.nearbySilentCheck.scripts.OnClick(A.nearbySilentCheck);A.RefreshUI()
assert(A.partyAlertToggle.text:find('OFF',1,true),'Silent updates Settings party-alert status')
combat=true;A.nearbySilentCheck:SetChecked(false);A.nearbySilentCheck.scripts.OnClick(A.nearbySilentCheck)
A.nearbySilentCheck:SetChecked(true);A.nearbySilentCheck.scripts.OnClick(A.nearbySilentCheck);combat=false
assert(not A.db.options.partyAllianceAlerts and A.nearbySilentCheck:GetChecked(),'Silent remains usable during combat without protected targeting writes')
-- Save/reload the existing party option and restore the checked header state.
BIHGGKTDB.options.partyAllianceAlerts=assert(loadstring('return false'))()
local B={};local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',B)end end;toc:close()
B.eventFrame.scripts.OnEvent(B.eventFrame,'PLAYER_LOGIN');assert(B.db and not B.lastError,B.lastError)
assert(B.nearbySilentCheck:GetChecked()and not B.db.options.partyAllianceAlerts,'Silent checked state persists across reload')
B.nearbySilentCheck:SetChecked(false);B.nearbySilentCheck.scripts.OnClick(B.nearbySilentCheck)
B.NearbyNotice('Player-after-silent','After-Realm','Human','Alliance',now+5,false,true,60,'Mage');B.PumpPartyAlerts(now+5)
assert(#public==1 and public[1][2]=='PARTY','unchecking Silent permits normal fresh party announcements')
assert(B.nearbyFrame:GetWidth()==340,'second checkbox must not widen tracker')
print('PASS Silent: checked=no PARTY, queued cancellation, local beep/history/detection/sync, Settings parity, combat, reload and resume')
]]
assert(loadstring(table.concat(lines,'\n')..'\n'..test))()
