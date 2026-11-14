local root=arg[1]or'.'
if arg[2]~='honor_kills'then arg[2]='honor_kills';dofile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua');return end
return function(A,event,tick,clock,units)
 local function total()return A.db.owners[A.owner].total end
 local before=total()
 units.target.dead=true;event('PARTY_KILL','Player-me','Player-gnome')
 assert(total()==before,'native killing blow plus own harmful debuff is not personal HK confirmation')
 print('PASS native PARTY_KILL never credits without local HK evidence')
 COMBATLOG_HONORGAIN='You killed %s, rank %s (Honor: %d)'
 COMBATLOG_HONORGAIN_NO_RANK='You killed %s (Honor: %d)'
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Tiny (Honor: 4)')
 assert(total()==before+1,'localized named HK must confirm a unique fresh local Gnome candidate')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Tiny (Honor: 4)')
 assert(total()==before+1,'duplicate own honor cannot duplicate credit')
 print('PASS named localized HK confirms own credit once')
 local hk=10
 GetPVPLifetimeStats=function()return hk,0 end
 A.ResetHonorEvidence(clock())
 clock(clock()+10);units.target.dead=false;event('UNIT_FLAGS','target')
 local n=total();event('CHAT_MSG_COMBAT_HONOR_GAIN','You have been awarded 4 Honor.')
 assert(total()==n,'bonus honor cannot count')
 units.target.dead=true;event('PARTY_KILL','Pet-outsider','Player-gnome')
 assert(total()==n,'native candidate alone cannot count')
 hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED');clock(clock()+8);A.HonorProgress(clock())
 assert(total()==n+1,'generic award + independent HK increment + native Gnome death must count even with nonguild pet KB')
 event('PLAYER_PVP_KILLS_CHANGED');assert(total()==n+1,'counter replay cannot count twice')
 print('PASS generic honor requires readable HK increment and native victim, independent of KB actor')
 clock(clock()+10);units.target.dead=false
 units.party1={guid='Player-friend',name='NoAddon',race='Orc',faction='Horde',hp=1000}
 event('GROUP_ROSTER_UPDATE')
 C_UnitAuras.GetAuraDataByIndex=function(u,i)if u=='target'and i==1 then return {spellId=172,sourceUnit='party1',isHarmful=true,isHelpful=false}end end
 event('UNIT_AURA','target')
 local friend='NoAddon-Realm'
 local function assists()return A.GuildEffectiveRecord(friend,A.PeerRecords()[friend],clock()).total end
 local a=assists();units.target.dead=true;event('PARTY_KILL','Player-me','Player-gnome')
 assert(assists()==a,'debuff plus death alone cannot award an assist')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Tiny (Honor: 4)')
 assert(assists()==a+1,'confirmed own HK commits witnessed guild-group debuff assist without addon handshake')
 print('PASS confirmed local HK commits snapshotted non-addon guild-group harmful assist')
 local typed=0
 for _,e in pairs(A.account.guildObservations[A.guildKey].events)do if e.kind=='K'and e.claim then typed=typed+1 end end
 assert(typed>=4,'native own/assist credits must use persisted typed life identities')
 local function fresh(g,race,name)
  clock(clock()+10);units.target={guid=g,race=race,name=name,faction='Alliance',hp=1000,enemy=true}
  event('UNIT_FLAGS','target');return total()
 end
 n=fresh('Player-human','Human','Human')
 units.target.dead=true;event('PARTY_KILL','Player-outsider','Player-human')
 units.focus={guid='Player-uncertain-gnome',race='Gnome',name='Other',faction='Alliance',hp=1000,enemy=true}
 event('UNIT_FLAGS','focus');units.focus.dead=true;event('PARTY_KILL','Player-outsider','Player-uncertain-gnome')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You have been awarded 4 Honor.');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n,'Human HK plus uncertain Gnome must not guess Gnome')
 units.focus=nil
 print('PASS other-race native candidates participate in generic ambiguity before race filtering')
 n=fresh('Player-named-human','Human','NamedHuman')
 units.target.dead=true;event('PARTY_KILL','Player-outsider','Player-named-human')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed NamedHuman (Honor: 4)')
 units.focus={guid='Player-uncertain-2',race='Gnome',name='Other2',faction='Alliance',hp=1000,enemy=true}
 event('UNIT_FLAGS','focus');units.focus.dead=true;event('PARTY_KILL','Player-outsider','Player-uncertain-2')
 hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED');event('CHAT_MSG_COMBAT_HONOR_GAIN','You have been awarded 4 Honor.')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n,'named Human HK counter cannot fund another generic Gnome candidate')
 units.focus=nil
 print('PASS named HK consumes its counter evidence; no cross-victim recycling')
 A.ResetHonorEvidence(clock());n=fresh('Player-window-1','Human','Window1')
 units.target.dead=true;event('PARTY_KILL','Player-other','Player-window-1')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 clock(clock()+7);units.focus={guid='Player-window-2',race='Gnome',name='Window2',faction='Alliance',hp=1000,enemy=true}
 event('UNIT_FLAGS','focus');units.focus.dead=true;event('PARTY_KILL','Player-other','Player-window-2')
 clock(clock()+2);A.HonorProgress(clock());assert(total()==n,'expiring first candidate cannot turn an ambiguous round into a unique second candidate')
 units.focus=nil
 for _,bad in ipairs({false,'13',-1,0/0,math.huge,{}})do
  GetPVPLifetimeStats=function()return bad end;A.ResetHonorEvidence(clock())
  n=fresh('Player-no-counter-'..tostring(clock()),'Gnome','Opaque')
  units.target.dead=true;event('PARTY_KILL','Player-other',units.target.guid)
  event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');clock(clock()+8);A.HonorProgress(clock())
  assert(total()==n,'unreadable/noninteger HK counter cannot confirm generic honor')
 end
 GetPVPLifetimeStats=function()return hk end;A.ResetHonorEvidence(clock())
 print('PASS public finite numeric counter guards and ambiguous-round aging')
 clock(clock()+10);A.ResetHonorEvidence(clock());n=total()
 units.target=nil
 GetPlayerInfoByGUID=function(g)if g=='Player-native-only'then return 'Mage','MAGE','Gnome','Gnome',2,'NativeOnly','Realm'end end
 event('PARTY_KILL','Pet-unknown','Player-native-only')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n+1,'fresh native GUID race plus public native PK confirms victim without target selection')
 print('PASS raw PK candidate accepts fresh native GUID race, never historical name cache')
 assert(#A.KillDebugLines()>1,'read-only kill outcome diagnostics must show native progress')
 for i=1,80 do A.KillOutcome('ambiguous HK',clock()+i)end
 assert(#A.db.killOutcomes<=32,'kill outcome ring bounded at 32')
 units.target={guid='Player-joined-late',name='JoinedLate',race='Gnome',faction='Alliance',hp=1000,enemy=true}
 clock(clock()+10);event('UNIT_FLAGS','target');A.members[A.owner]=nil
 units.target.dead=true;event('UNIT_HEALTH','target');A.members[A.owner]=true;n=total()
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed JoinedLate (Honor: 4)')
 assert(total()==n,'later membership cannot authorize an ineligible death-time candidate')
 for i=1,100 do A.HonorSight('Player-cap-'..i,'Cap'..i..'-Realm','Gnome',true,false,clock())end
 local seen=0;for _ in pairs(A.honorSightings)do seen=seen+1 end
 assert(seen<=64,'fresh local honor correlation registry must stay bounded')
 local oldSecret=issecretvalue;local hidden={};issecretvalue=function(v)return rawequal(v,hidden)end
 A.db.killOutcomes={hidden,{time=hidden,reason='counted'},{time=clock(),reason='raw arbitrary data'}}
 assert(#A.KillDebugLines()==1,'debug cannot render protected or arbitrary saved outcome data')
 A.InitKillOutcomes();assert(#A.db.killOutcomes==0);issecretvalue=oldSecret
 print('PASS death-time authority, bounded fresh identity registry, sanitized read-only diagnostics')
 A.ResetHonorEvidence(clock());n=fresh('Player-named-once','Gnome','Once');units.target.dead=true;event('UNIT_HEALTH','target')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Once (Honor: 4)');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed Once (Honor: 4)');clock(clock()+8);A.HonorProgress(clock())
 n=fresh('Player-after-replay','Gnome','AfterReplay');units.target.dead=true;event('PARTY_KILL','Player-other','Player-after-replay')
 event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED');clock(clock()+8);A.HonorProgress(clock())
 assert(total()==n+1,'replayed named HK must not create counter debt that poisons the next real generic HK')
 C_UnitAuras.GetAuraDataByIndex=function()end
 fresh('Player-stale-debuff','Gnome','StaleDebuff');local a0=assists()
 assert(A.GroupCC('Player-stale-debuff',172,'Player-friend',clock(),true))
 clock(clock()+100);A.GroupDamage('Player-stale-debuff',1,0,'Player-friend',clock())
 clock(clock()+21);A.GroupDamage('Player-stale-debuff',1,0,'Player-friend',clock());event('UNIT_FLAGS','target')
 units.target.dead=true;event('UNIT_HEALTH','target');event('CHAT_MSG_COMBAT_HONOR_GAIN','You killed StaleDebuff (Honor: 4)')
 assert(assists()==a0,'later damage cannot refresh an expired witnessed harmful application')
 A.ResetHonorEvidence(clock());n=fresh('Player-opaque-companion','Gnome','OpaqueCompanion')
 units.target.dead=true;event('PARTY_KILL','Player-other','Player-opaque-companion')
 local hiddenPK={};issecretvalue=function(v)return rawequal(v,hiddenPK)end
 event('PARTY_KILL','Player-other',hiddenPK);issecretvalue=oldSecret
 event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED');clock(clock()+8);A.HonorProgress(clock())
 assert(total()==n,'an opaque second native victim must poison generic assignment, not silently disappear')
 A.ResetHonorEvidence(clock());n=fresh('Player-first-corpse','Gnome','FirstCorpse')
 units.target.dead=true;event('PARTY_KILL','Player-other','Player-first-corpse')
 units.focus={guid='Player-human-corpse',name='HumanCorpse',race='Human',faction='Alliance',hp=1000,enemy=true,dead=true}
 event('UNIT_HEALTH','focus');event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor');hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n,'first-seen Human/uncertain player corpse must compete with a pending Gnome')
 units.focus=nil
 for index,order in ipairs({{'counter','honor','native'},{'honor','counter','native'},{'native','counter','honor'},{'native','honor','counter'}})do
  A.ResetHonorEvidence(clock());n=fresh('Player-order-'..index,'Gnome','Order'..index)
  local started=clock()
  for _,kind in ipairs(order)do
   if kind=='counter'then hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED')
   elseif kind=='honor'then event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor')
   else units.target.dead=true;event('PARTY_KILL','Pet-outsider',units.target.guid)end
   clock(clock()+1)
  end
  clock(started+8);A.HonorProgress(clock());assert(total()==n+1,'delayed/reordered native counter/honor/candidate: '..table.concat(order,','))
 end
 GetPVPLifetimeStats=nil;GetPVPSessionStats=function()return hk end
 A.ResetHonorEvidence(clock());n=fresh('Player-session-fallback','Gnome','Session')
 units.target.dead=true;event('PARTY_KILL','Player-other',units.target.guid);event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n,'bonus honor plus corpse without HK increment cannot count')
 A.ResetHonorEvidence(clock());n=fresh('Player-session-increment','Gnome','SessionIncrement')
 units.target.dead=true;event('PARTY_KILL','Player-other',units.target.guid);hk=hk+1;event('PLAYER_PVP_KILLS_CHANGED');event('CHAT_MSG_COMBAT_HONOR_GAIN','generic honor')
 clock(clock()+8);A.HonorProgress(clock());assert(total()==n+1 and A.honorState.provider=='GetPVPSessionStats','readable session fallback counter is baseline-scoped')
 A.ResetHonorEvidence(clock());n=fresh('Player-localized-assist','Gnome','Lokal')
 COMBATLOG_HONORGAIN_NO_RANK='Ehre: %2$d / %1$s (100%%)'
 event('CHAT_MSG_COMBAT_HONOR_GAIN','Ehre: 4 / Lokal (100%)')
 assert(total()==n+1,'localized positional named HK confirms assist without own killing-blow callback')
 print('PASS all native evidence orderings, bonus-only rejection, session fallback and positional localized named assist')
 local reads=0;GetPVPLifetimeStats=function()reads=reads+1;return hk end;GetPVPSessionStats=nil
 IsInInstance=function()return true,'party'end;event('ZONE_CHANGED_NEW_AREA');reads=0
 A.ScanVisible();assert(reads==0,'stable blocked-location unit scans must not re-read/reset the HK baseline per unit')
 IsInInstance=function()return false,'none'end;event('ZONE_CHANGED_NEW_AREA')
end
