local root=arg[1]or'.'
local t=1700000000
local function fresh()
 local A={Secret=function()return false end};for _,f in ipairs({'Core.lua','Sync.lua'})do assert(loadfile(root..'/'..f))('Test',A)end
 A.Init({},'Self-Realm',t);A.guildKey='Guild-Realm';A.members={Peer=true,Other=true};return A
end
InCombatLockdown=function()return false end;date=function(fmt,now)return os.date(fmt,math.floor(now))end
local sent={};C_ChatInfo={SendAddonMessage=function(_,p)sent[#sent+1]=p;return 0 end}
local A=fresh();local builds=0;local original=A.BuildPackets
A.BuildPackets=function(full,now)if full then builds=builds+1 end;return original(full,now)end
for i=0,3000 do A.Pump(t+i/10)end
assert(builds==1,'idle must not rebuild lifetime history every minute; got '..builds)
local queries=0;for _,p in ipairs(sent)do if p=='2|Q'then queries=queries+1 end end
assert(queries>=5 and queries<=6,'keep light sixty-second queries')
assert(#sent<20,'idle traffic bounded: '..#sent)
print('PASS idle: '..#sent..' packets / 300s, '..builds..' historical build')
A=fresh();sent={}
assert(A.SendPacket('valid',t));assert(not A.SendPacket('same clock',t),'same-clock API spam must be paced')
assert(not A.SendPacket(string.rep('x',256),t+1),'oversize packets rejected before native API')
assert(A.SendPacket('fractional',t+.5),'fractional time refills pacing')
local oldServer,oldTime=GetServerTime,GetTime;GetServerTime=function()return t+2 end;GetTime=function()return 42 end
assert(A.SendPacket('default-clock'),'direct sends use the same epoch domain as Pump')
GetServerTime,GetTime=oldServer,oldTime
local attempts=0;C_ChatInfo.SendAddonMessage=function()attempts=attempts+1;return false end
A=fresh();for i=0,600 do A.Pump(t+i/10)end
assert(attempts<=6,'native failure must exponentially back off: '..attempts)
assert(A.request,'failed query stays queued')
C_ChatInfo.SendAddonMessage=function(_,p)sent[#sent+1]=p;return 0 end
A.Pump(t+121);A.Pump(t+122);assert(not A.request,'retained request eventually retries')
A=fresh();sent={};A.outgoing={string.rep('x',256),'valid'};A.outIndex=1;A.lastRequest=t
for i=0,10 do A.Pump(t+i)end
assert(not A.outgoing and #sent==1 and sent[1]=='valid','poison packet must not block valid queued data')
assert(A.syncRejected and #A.syncRejected==1,'explicit diagnostic retains rejected packet')
assert(A.syncStatus:find('quarantined',1,true),'finishing valid tail must not claim entire rejected batch sent')
print('PASS pacing, validation, exponential retry and poison quarantine')
A=fresh();A.lastRequest=t;local fulls=0;A.QueueShare=function(full)if full then fulls=fulls+1 end end
for i=0,300 do A.Receive('2|Q','GUILD','Peer',t+i)end
assert(fulls==1,'same legacy peer must not force minute history replays: '..fulls)
assert(A.Receive('2|H|session1','GUILD','Other',t+301),'new session hello accepted')
A.Pump(t+301);assert(fulls==2,'new peer gets catchup')
A.Receive('2|H|session1','GUILD','Other',t+370);A.Pump(t+370);assert(fulls==2,'same session does not replay')
A.Receive('2|H|session2','GUILD','Other',t+371);A.Pump(t+371);assert(fulls==3,'reloaded peer gets catchup')
A.Receive('2|H|fast-reload','GUILD','Other',t+372);A.Pump(t+432);assert(fulls==4,'reload inside cooldown must get deferred catchup, not be forgotten')
A.Receive('2|Q','GUILD','Peer',t+901);A.Pump(t+901);assert(fulls==5,'legacy eventually gets periodic catchup')
print('PASS session-aware catchup and legacy compatibility')
A=fresh();sent={};for i=0,30 do A.Pump(t+i/10)end
local hello;for _,p in ipairs(sent)do hello=hello or p:match('^2|H|(.+)$')end
assert(hello,'new session announces catchup token')
assert(sent[1]:match('^2|H|'),'session hello precedes legacy Q to avoid duplicate catchup replies')
A=fresh();sent={};A.Pump(t);A.outgoing={'OLD_NAMESPACE'};A.outIndex=1;A.guildKey='NewGuild'
A.Pump(t+1);for _,p in ipairs(sent)do assert(p~='OLD_NAMESPACE','guild transition clears queued old namespace')end
A=fresh();A.members={};for i=1,10 do A.members['Peer'..i]=true end
local accepted=0;for i=1,1000 do if A.Receive('2|Q','GUILD','Peer'..(i%10+1),t)then accepted=accepted+1 end end
assert(accepted<=900,'aggregate incoming budget must cap multiple peers')
A=fresh();local redraws=0;A.RequestUIRefresh=function()redraws=redraws+1 end;A.RefreshUI=function()error('direct redraw')end
assert(A.Receive('2|S|1|0|'..A.Day(t)..'|1|0','GUILD','Peer',t));assert(redraws==1,'incoming updates use coalesced refresh')
print('PASS hello, guild namespace, aggregate receive budget and coalesced UI')
A=fresh();sent={};local marked={};local priority='new-event';A.PriorityGroupPacket=function()return priority,'event-id'end;A.MarkGroupSent=function(id)marked[id]=true;priority=nil end
A.outgoing={'old-history'};A.outIndex=1;A.lastRequest=t
A.Pump(t);assert(marked['event-id'] and sent[1]=='new-event','fresh event jumps history')
A.Pump(t);assert(#sent==1,'priority and history share same-clock budget')
A.Pump(t+.5);assert(sent[2]=='old-history','history progresses after priority')
priority=string.rep('x',256);A.Pump(t+1);assert(not priority and A.syncRejected,'invalid priority packet explicitly rejected without blocking queue')
A=fresh();A.outgoing={'history'};A.outFull=true;A.QueueShare(true)
assert(A.fullShare and A.dirty,'new catchup during active replay needs one coalesced followup')
print('PASS event priority, shared pacing and catchup overlap')
A=fresh();A.syncSession='old-session';A.lastRequest=t;A.RequestFullSync()
assert(A.request and A.fullShare and A.helloPending and not A.syncSession,'manual refresh requests a new session catchup plus full local share')
A=fresh();sent={};A.lastRequest=t;A.outgoing={'survive-combat'};A.outIndex=1
InCombatLockdown=function()return true end;A.Pump(t+100);assert(A.outIndex==1 and #sent==0,'combat never advances queue')
InCombatLockdown=function()return false end;A.Pump(t+101);A.Pump(t+102);assert(not A.outgoing,'combat resume completes retained queue')
A=fresh();sent={};assert(A.SendPacket(string.rep('x',255),t));assert(A.SendPacket(string.rep('x',255),t+.5))
assert(not A.SendPacket(string.rep('x',255),t+1),'byte allowance independently limits large messages')
assert(not A.SendPacket('clock-reset',t-10),'clock reversal cannot refill a burst')
assert(A.SendPacket('clock-resume',t-9),'clock reversal resumes after paced allowance')
-- Exercise real persisted guild observations, not a synthetic BuildPackets stub.
A=fresh();for _,f in ipairs({'Accounts.lua','GroupTracker.lua'})do assert(loadfile(root..'/'..f))('Test',A)end
A.InitAccount({},'budget-account',t);A.members[A.owner]=true;A.InitGroupTracking(t);A.groupBulk=true
for i=1,500 do assert(A.AddGuildEvent('K',A.owner,'Player-self','Player-history-'..i,t-i,t-i,t))end
A.groupBulk=nil;A.groupPending[A.guildKey]={};A.dirty=true;A.fullShare=true
local countFull=0;local build=A.BuildPackets;A.BuildPackets=function(full,now)if full then countFull=countFull+1 end;return build(full,now)end
sent={};local wire={};C_ChatInfo.SendAddonMessage=function(_,p)assert(#p<=255);sent[#sent+1]=p;wire[#wire+1]=p;return 0 end
for i=0,4000 do local now=t+i/10;if i%600==0 then A.Receive('2|Q','GUILD','Peer',now)end;A.Pump(now)end
assert(not A.outgoing and countFull==1,'500-event catchup finishes once despite repeated peer queries')
local events=0;for _,p in ipairs(wire)do if p:sub(1,4)=='5|E|'then events=events+1 end end
assert(events==500,'each historical event shared once: '..events)
assert(#wire<=530,'bounded 500-event catchup: '..#wire)
local historicalPackets=#wire
A.request=true;A.QueueShare(true);for i=4001,8000 do A.Pump(t+i/10)end
assert(countFull==2 and not A.outgoing,'explicit full refresh still completes')
print('PASS combat/clock/byte guards; 500-event catchup '..historicalPackets..' initial / '..#wire..' with explicit refresh')
local event;for _,p in ipairs(wire)do if p:sub(1,4)=='5|E|'then event=p;break end end
local B=fresh();for _,f in ipairs({'Accounts.lua','GroupTracker.lua'})do assert(loadfile(root..'/'..f))('Test',B)end
B.InitAccount({},'other-account',t);B.members[B.owner]=true;B.InitGroupTracking(t)
assert(B.Receive(event,'GUILD','Peer',t+801),'first incoming observation retained')
for i=0,100 do B.Pump(t+801+i/10)end
assert(not B.dirty and not B.outgoing,'first relay finishes')
for i=1,200 do assert(not B.Receive(event,'GUILD',i%2==0 and'Peer'or'Other',t+812),'duplicate observation cannot become new credit')end
assert(not B.dirty and not B.outgoing and not B.PriorityGroupPacket(),'multiple peer duplicate relays cannot enqueue an echo loop')
print('PASS multiple-peer observation replay has no continuing echo')
-- Full-size history needs more than one half-second refill. A fresh-event
-- stream must not steal its reserved turn when that first refill is too small.
local function historicalTurn(clock)
 local S=fresh();local history=string.rep('h',255);local priority=string.rep('p',255)
 S.lastRequest=t;S.sendBudget={at=t,next=t,bytes=0};S.outgoing={};S.outIndex=1
 for i=1,1000 do S.outgoing[i]=history end
 S.PriorityGroupPacket=function()return priority,'fresh'end
 local freshSent,historySent,querySent,total,last=0,0,0,0,nil
 S.MarkGroupSent=function()freshSent=freshSent+1 end
 C_ChatInfo.SendAddonMessage=function(_,packet)
  local now=clock()
  assert(not last or now-last>=.5,'shared half-second pacing preserved');last=now
  total=total+#packet+#S.PREFIX
  assert(total<=(now-t)*256,'empty shared bucket never overspends')
  if packet==history then historySent=historySent+1 elseif packet=='2|Q'then querySent=querySent+1 end
  return 0
 end
 for i=0,600 do clock(t+i/2);S.Pump(clock())end
 assert(historySent>0 and S.outIndex>1,'full-size historical turn starved after 300 seconds: fresh='..freshSent..', history='..historySent)
 assert(freshSent>100,'historical reservation must preserve fresh-event progress')
 assert(querySent>=4,'light queries must progress during continuous fresh/history traffic: '..querySent)
 return freshSent,historySent,querySent
end
local now=t
local function fractional(value)if value then now=value end;return now end
local f,h,q=historicalTurn(fractional)
print('PASS full-size reserved history: '..f..' fresh / '..h..' history / '..q..' queries')
local function epoch(value)if value then now=math.floor(value)end;return now end
f,h,q=historicalTurn(epoch)
print('PASS repeated epoch reserved history: '..f..' fresh / '..h..' history / '..q..' queries')
A=fresh();A.lastRequest=t;local idleQueries=0
A.PriorityGroupPacket=function()return 'fresh','id'end;A.MarkGroupSent=function()end
C_ChatInfo.SendAddonMessage=function(_,p)if p=='2|Q'then idleQueries=idleQueries+1 end;return 0 end
for i=0,600 do A.Pump(t+i/2)end
assert(idleQueries>=4,'queries must not starve when continuous fresh traffic has no historical work: '..idleQueries)
print('PASS query fairness without historical work')
-- A rejected native history send must retain the same turn and packet through
-- backoff/combat; pending hello/Q cannot consume its refill in the meantime.
A=fresh();A.lastRequest=t;A.groupPriorityBurst=4;A.outgoing={string.rep('h',255)};A.outIndex=1
A.sendBudget={at=t,next=t,bytes=0};A.helloPending=true;A.request=true
local historyAttempts,priorityAttempts,controls=0,0,{}
A.PriorityGroupPacket=function()return 'fresh','id'end;A.MarkGroupSent=function()end
C_ChatInfo.SendAddonMessage=function(_,p)
 if p==A.outgoing[1]then historyAttempts=historyAttempts+1;return historyAttempts>1 end
 if p=='fresh'then priorityAttempts=priorityAttempts+1 else controls[#controls+1]=p end
 return 0
end
A.Pump(t+.5);assert(A.outIndex==1 and historyAttempts==0 and #controls==0,'reserved refill excludes controls')
InCombatLockdown=function()return true end;A.Pump(t+1)
assert(A.outIndex==1 and A.groupPriorityBurst==4 and historyAttempts==0,'combat retains reserved turn')
InCombatLockdown=function()return false end;A.Pump(t+1.5)
assert(A.outIndex==1 and A.groupPriorityBurst==4 and historyAttempts==1,'native rejection retains history and reservation')
A.Pump(t+2);A.Pump(t+2)
assert(historyAttempts==1 and #controls==0 and priorityAttempts==0,'backoff and repeated epoch retain exclusive history turn')
A.Pump(t+3.5);assert(not A.outgoing and historyAttempts==2,'retained history retries successfully')
-- Avoid indexing the completed queue from the native fixture on control turns.
C_ChatInfo.SendAddonMessage=function(_,p)controls[#controls+1]=p;return 0 end
A.Pump(t+4);A.Pump(t+4.5)
assert(controls[1]:match('^2|H|') and controls[2]=='2|Q','hello and query progress after reserved history')
A=fresh();A.lastRequest=t;A.groupPriorityBurst=4;A.outgoing={string.rep('x',256)};A.outIndex=1
A.Pump(t)
assert(not A.outgoing and A.syncRejected[1].packet==string.rep('x',256) and A.groupPriorityBurst==0,'quarantine releases historical turn and retains diagnostics')
A.groupPriorityBurst=4;A.groupControlTurn=true;A.guildKey='NewGuild';A.Pump(t+.5)
assert(A.groupPriorityBurst==0 and not A.groupControlTurn,'guild change clears scheduling reservation')
print('PASS reservation survives refill/combat/backoff; retry, controls, quarantine and guild reset')
