local root=arg[1]or'.';local A={};local now=1700000000;date=os.date
for _,f in ipairs({'Core.lua','Accounts.lua','Sync.lua','Dashboard.lua'})do assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
A.Init({},'Me-Realm',now);A.InitAccount({},'me-account',now);A.guildKey='Guild-Realm';A.guildName='Guild'
A.Safe=function(fn,...)if fn then local ok,v=pcall(fn,...);if ok then return v end end end;A.Secret=function()return false end
function IsInGuild()return true end;function InCombatLockdown()return false end
local rank='Member';function GetGuildInfo()return'Guild',rank end
assert(type(A.ReportDebugLines)=='function','report diagnostics must expose send state rather than combat coverage only')
assert(not A.StartTopPost({'heading','one person'},now))
assert(table.concat(A.ReportDebugLines(),' '):find('restricted',1,true),'rejected confirmation reason visible in debug')
rank='Council of BIHG';SendChatMessage=function()error('client blocked the send')end
assert(A.StartTopPost({'heading','one person'},now));A.PumpTopPost(now)
local text=table.concat(A.ReportDebugLines(),' ')
assert(text:find('client blocked the send',1,true)and text:find('SendChatMessage',1,true),'caught chat failure and exact selected API visible')
assert(A.db.reportDiagnostics.requests==2 and A.db.reportDiagnostics.sendCalls==1,'request and send counts persisted separately')
A.RecordReportRestriction('ADDON_ACTION_FORBIDDEN','OtherAddon','UNKNOWN()',now);assert(not A.db.reportDiagnostics.restriction,'ignore unrelated addon errors')
A.RecordReportRestriction('ADDON_ACTION_FORBIDDEN','BIHGGnomeKillTracker5000','UNKNOWN()',now)
assert(table.concat(A.ReportDebugLines(),' '):find('ADDON_ACTION_FORBIDDEN',1,true),'native protected-action events survive pcall without pretending they are Lua errors')
SendChatMessage=nil;C_ChatInfo={SendChatMessage=function()return 0 end};A.db.options.lastTopPost=nil
assert(A.StartTopPost({'heading','one person'},now+61));A.PumpTopPost(now+61)
assert(table.concat(A.ReportDebugLines(),' '):find('C_ChatInfo.SendChatMessage',1,true),'modern API selection visible')
assert(A.db.reportDiagnostics.result=='0','actual numeric API result recorded')
assert(A.postJob and A.postJob.index==2,'instrumentation does not change pacing or advance extra lines')
print('PASS report diagnostics: rejected requests, caught API errors, API selection/results, native protected-action events, persisted counters and unchanged queue pacing')
