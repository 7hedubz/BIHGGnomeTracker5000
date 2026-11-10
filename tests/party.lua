local root=arg[1]or'.';local now=1700000000;local grouped=true;local raid=false;local sent={};local outcome=nil
function GetNumSubgroupMembers()return grouped and 2 or 0 end
function IsInRaid()return raid end
function GetNormalizedRealmName()return'Realm'end
function GetRealZoneText()return'Ashenvale'end
function GetSubZoneText()return'Satyrnaar'end
C_Map={GetBestMapForUnit=function()return 1 end,GetPlayerMapPosition=function()return{GetXY=function()return .8,.5 end}end}
function SendChatMessage(text,channel)sent[#sent+1]={text,channel};return outcome end
local A={db={options={}},Safe=function(fn,...)if fn then local ok,v=pcall(fn,...);if ok then return v end end end,Secret=function()return false end}
for _,f in ipairs({'Sounds.lua','Nearby.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
A.InitNearby();assert(A.db.options.partyAllianceAlerts==true,'requested automatic party alerts default on')
local function notice(g,n,r,t)A.NearbyNotice(g,n,r,'Alliance',t,false,true,33,'Druid')end
notice('Player-elf','Raven-Briarclaw','NightElf',now);A.PumpPartyAlerts(now)
assert(#sent==1 and sent[1][2]=='PARTY'and sent[1][1]:find('Raven-Briarclaw',1,true),'new readable Alliance announced only to PARTY')
assert(sent[1][1]:find('Level 33 Night Elf Druid',1,true)and sent[1][1]:find('near me: Satyrnaar, Ashenvale (80,50)',1,true),'readable details and observer location included honestly')
notice('Player-elf','Raven-Briarclaw','NightElf',now+1);A.PumpPartyAlerts(now+2);assert(#sent==1,'continuous rescans do not repeat chat')
notice('Player-gnome','Tiny-Surname','Gnome',now+2);A.PumpPartyAlerts(now+2)
assert(#sent==2 and sent[2][1]:sub(1,17)=='GNOME DETECTED : ','exact Gnome prefix is first in message')
A.ClearNearby();notice('Player-gnome','Tiny-Surname','Gnome',now+3);A.PumpPartyAlerts(now+4);assert(#sent==2,'Clear cannot bypass contact suppression')
A.InitNearby();notice('Player-gnome','Tiny-Surname','Gnome',now+5);A.PumpPartyAlerts(now+5);assert(#sent==2,'reload preserves contact repeat suppression')
notice('Player-gnome','Tiny-Surname','Gnome',now+70);A.PumpPartyAlerts(now+70);assert(#sent==3,'contact rearms after sixty seconds unseen')
grouped=false;notice('Player-solo','Solo-Realm','Human',now+72);A.PumpPartyAlerts(now+72);assert(#sent==3,'solo never posts')
grouped=true;raid=true;notice('Player-raid','Raid-Realm','Human',now+73);A.PumpPartyAlerts(now+74);assert(#sent==3,'no RAID or guild fallback')
raid=false;notice('Player-leave','Leave-Realm','Human',now+74);grouped=false;A.PumpPartyAlerts(now+74);assert(#sent==3,'leaving party cancels queued message')
grouped=true;A.db.options.partyAllianceAlerts=false;notice('Player-off','Off-Realm','Human',now+76);A.PumpPartyAlerts(now+76);assert(#sent==3,'toggle off suppresses sends')
A.db.options.partyAllianceAlerts=true;notice('Player-dead','Dead-Realm','Gnome',now+78);A.ForgetNearby('Player-dead');A.PumpPartyAlerts(now+78);assert(#sent==3,'dead/forgotten contacts do not announce from stale queue')
notice('Player-fail','Fail-Realm','Gnome',now+80);outcome=false;A.PumpPartyAlerts(now+80);local count=#sent
notice('Player-fail','Fail-Realm','Gnome',now+81);A.PumpPartyAlerts(now+82);assert(#sent==count,'failed chat is not spam-retried on each scan')
outcome=nil;SendChatMessage=nil;C_ChatInfo={SendChatMessage=function(t,c)sent[#sent+1]={t,c};return 0 end}
notice('Player-modern','Modern-Realm','Human',now+84);A.PumpPartyAlerts(now+84);assert(#sent==count+1 and sent[#sent][2]=='PARTY','namespaced chat API supported')
assert(not A.PartyAllianceMessage({name='Bad\n/run x',race='Gnome'}),'untrusted control/markup text rejected')
notice('Player-pause-queued','PauseQueued-Realm','Gnome',now+90);local beforePaused=#sent
A.db.options.nearbyEnabled=false;A.PumpPartyAlerts(now+90)
assert(#sent==beforePaused and not next(A.partyAlertPending),'Nearby OFF cancels queued party detection announcements')
A.NotePartyAlliance({guid='Player-paused-direct',name='Paused',race='Gnome',seen=now+91},now+91);assert(not next(A.partyAlertPending),'OFF suppresses direct party detection scheduling')
A.SetNearbyEnabled(true);notice('Player-resume-party','Resume-Realm','Gnome',now+92);A.PumpPartyAlerts(now+92);assert(#sent==beforePaused+1,'party detection can resume normally')
print('PASS party alerts: default/toggle, exact Gnome prefix, readable details/location, GUID suppression across Clear/reload, rearm, solo/raid/party-loss guards, dead contacts, failed-send suppression and modern API')
