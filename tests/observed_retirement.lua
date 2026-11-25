local root=arg[1]or'.'
if arg[2]~='observed_retirement'then arg[2]='observed_retirement';dofile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua');return end
return function(A,event,tick,clock,units)
 local reads=0
 C_UnitAuras.GetAuraDataByIndex=function()reads=reads+1;return {spellId=172,sourceUnit='party1',isHarmful=true}end
 units.party1={guid='Player-friend-new',name='Unreported',race='Orc',faction='Horde',hp=1000,guild='Guild'}
 event('GROUP_ROSTER_UPDATE')
 assert(not A.PeerRecords()['Unreported-Realm'],'group discovery must not create observed-only score rows')
 local before=A.db.owners[A.owner].total
 clock(clock()+10);units.target={guid='Player-retired',name='Retired',race='Gnome',faction='Alliance',hp=1000,enemy=true}
 event('PLAYER_TARGET_CHANGED');event('UNIT_AURA','target')
 units.target.dead=true;event('UNIT_HEALTH','target')
 COMBATLOG_HONORGAIN_NO_RANK='You killed %s (Honor: %d)'
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Retired (Honor: 4)')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Retired (Honor: 4)')
 assert(A.db.owners[A.owner].total==before+1,'personal named HK must count exactly once without harmful evidence')
 assert(A.GuildEffectiveRecord('Unreported-Realm',nil,clock()).total==0,'own HK must not award witnessed group assists')
 assert(reads==0,'living and corpse scans must perform zero retired aura reads')
 assert(A.GroupCC==nil and A.GroupDamage==nil,'retired contribution collector APIs must be absent')
 print('PASS actual TOC: personal HK once, no witnessed group credit, no discovery-only peer row, zero living/corpse aura reads')
 local hk=20;GetPVPLifetimeStats=function()return hk end
 clock(clock()+10);A.ResetHonorEvidence(clock())
 units.target={guid='Player-counter-retired',name='CounterRetired',race='Gnome',faction='Alliance',hp=1000,enemy=true}
 event('PLAYER_TARGET_CHANGED');local counterBefore=A.db.owners[A.owner].total
 units.target.dead=true;event('PARTY_KILL','Player-outsider','Player-counter-retired')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 clock(clock()+8);A.HonorProgress(clock());event('PLAYER_PVP_KILLS_CHANGED')
 assert(A.db.owners[A.owner].total==counterBefore+1 and reads==0,'uniquely linked native HK-counter confirmation still counts once with zero aura reads')
 assert(A.GuildEffectiveRecord('Unreported-Realm',nil,clock()).total==0,'generic personal HK cannot award guildmate assists')
 print('PASS actual TOC: native counter plus unique victim and honor counts personal credit once with zero aura reads')
 local t=clock();local name='Unreported-Realm'
 local function packet(kind,token,target,parent)
  return table.concat({'5','H',A.EncodeAlias(name),'Player-friend-new',target,t,t,token,parent or'root',kind},'|')
 end
 assert(not A.ReceiveGroup(packet('A','Player-peer:1','Player-peer-victim'),name,t),'old-peer typed A ingress must be rejected')
 assert(not A.AddHonorClaim(name,'Player-friend-new','Player-direct',t,t,t,'Player-peer:2','root','A'),'direct typed A ingress must be rejected')
 A.honorClaimPending={{name,'Player-friend-new','Player-buffered',t,t,t,'Player-peer:3','root','A',guild=A.guildKey}}
 A.DrainHonorClaims(t)
 assert(A.GuildEffectiveRecord(name,{observerOnly=true},t).total==0,'buffer draining cannot restore retired assist credit')
 assert(A.ReceiveGroup(packet('H','Player-peer:4','Player-honor-victim'),name,t),'normal peer honor claim remains accepted')
 local s=A.account.guildObservations[A.guildKey]
 local historical={kind='K',name=name,actor='Player-friend-new',target='Player-saved',time=t-20,contribution=t-20,claim='Player-saved:1',provenance='A'}
 local id='H:Player-friend-new:Player-saved:1'
 s.events[id]=historical;s.killLives[historical.claim]={target=historical.target,parent='root'}
 s.killRoots[historical.target]=historical.claim;s.killAliases[historical.claim]=historical.claim
 A.groupIndexes=nil;A.groupPending[A.guildKey]={[id]=true}
 assert(A.GuildEffectiveRecord(name,{observerOnly=true},t).total==2,'loaded historical A remains effective alongside new H')
 local priority=A.PriorityGroupPacket();assert(not priority or not priority:match('|A$'),'priority cannot relay retained A')
 for _,v in ipairs(A.GroupPackets(true,t))do assert(not v:match('|A$'),'full history cannot relay retained A as new credit')end
 assert(s.events[id]==historical and historical.provenance=='A','historical event identity/provenance is retained unmodified')
 print('PASS typed A ingress/buffer/priority/full relay blocked; peer H and saved historical A retained')
 -- Real serialized saved roots under a fresh actual-TOC namespace.
 local function serialized(v)
  if type(v)=='table'then local out={'{'};for k,x in pairs(v)do out[#out+1]='['..serialized(k)..']='..serialized(x)..',' end;out[#out+1]='}';return table.concat(out)end
  if type(v)=='string'then return string.format('%q',v)end
  return tostring(v)
 end
 local old=t-20;local day=A.Day(t);local owner=A.owner
 local eventID='H:Player-me:Player-oldown:1'
 local oldEvent={kind='K',name=owner,actor='Player-me',target='Player-oldown',time=old,contribution=old,claim='Player-oldown:1',provenance='A'}
 local savedDB={owners={[owner]={total=5,days={[day]=5},guildBase={since=t-10,total=5,days={[day]=5}}}}}
 local savedAccount={characters={[owner]=savedDB.owners[owner]},guildObservations={[A.guildKey]={killPolicySince=t-10,events={[eventID]=oldEvent},killLives={['Player-oldown:1']={target='Player-oldown',parent='root'}},killRoots={['Player-oldown']='Player-oldown:1'},killAliases={['Player-oldown:1']='Player-oldown:1'}}}}
 local B={};local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
 for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',B)end end;toc:close()
 B.Init(assert(loadstring('return '..serialized(savedDB)))(),owner,t)
 B.InitAccount(assert(loadstring('return '..serialized(savedAccount)))(),'serialized-test',t)
 B.guildKey=A.guildKey;B.members={[owner]=true};B.InitGroupTracking(t);B.RebuildOwnGuildTotals(t)
 assert(B.db.owners[owner].total==5,'serialized old A remains inside preserved historical five-kill baseline')
 local legacy=table.concat({'5','E','K',B.EncodeAlias(owner),'Player-me','Player-oldown',old,old},'|')
 B.ReceiveGroup(legacy,owner,t);B.ReceiveGroup(legacy,owner,t)
 assert(B.db.owners[owner].total==5,'old untyped 5E history cannot duplicate a retained A identity/baseline')
 assert(B.account.guildObservations[B.guildKey].events[eventID].provenance=='A','reload does not regrade serialized old A')
 assert(B.AddHonorClaim(owner,'Player-me','Player-freshown',t,t,t,'Player-freshown:1','root','H'))
 assert(B.db.owners[owner].total==6,'new personal H adds once above the preserved old mixed baseline')
 local oldGuild=B.guildKey;B.guildKey='NewGuild-Realm';B.CarryOwnGuildHistory(t);B.RebuildOwnGuildTotals(t)
 assert(B.db.owners[owner].total==6,'guild carry preserves both own historical A and current H without resetting totals')
 assert(B.account.guildObservations[oldGuild].events[eventID].provenance=='A','old-guild saved historical A is not mutated by carry')
 print('PASS serialized actual-TOC reload: old A IDs/baseline retained, 5E replay deduplicated, fresh H counts once, guild carry preserves history')
end
