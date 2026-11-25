local root=arg[1]or'.'
if arg[2]~='native_deaths'then arg[2]='native_deaths';dofile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua');return end
return function(A,event,tick,clock,units)
 assert(not A.eventFrame.events.PLAYER_DEAD,'retired own-death listener must not be registered')
 assert(not A.eventFrame.events.PLAYER_ALIVE and not A.eventFrame.events.PLAYER_UNGHOST,'retired resurrection collectors must not be registered')
 local reads=0;C_DeathRecap=setmetatable({},{__index=function()reads=reads+1;error('retired recap API read')end})
 units.party1={guid='Player-friend',name='Friend',race='Orc',faction='Horde',hp=1000}
 local scans={};C_UnitAuras.GetAuraDataByIndex=function(unit,i)
  scans[unit]=(scans[unit]or 0)+1
  if unit=='target'and i==1 then return{spellId=172,sourceUnit='party1',isHarmful=true}end
 end
 A.RefreshGroupActors();A.ScanVisible()
 for _,ev in ipairs({'UNIT_AURA','UNIT_HEALTH','UNIT_FLAGS','UNIT_MAXHEALTH'})do event(ev,'player');event(ev,'party1')end
 event('PLAYER_REGEN_DISABLED');event('PLAYER_REGEN_ENABLED');event('PLAYER_DEAD');event('PLAYER_ALIVE');event('PLAYER_UNGHOST');tick()
 assert(not A.lastError,A.lastError)
 assert(reads==0,'no recap API access after retirement')
 assert(not scans.player and not scans.party1,'no own/group victim aura scans')
 assert(not next(scans),'all retired contribution aura scans must be absent')
 assert(A.groupTargets['Player-gnome'],'enemy victim identity/life tracking must remain')
 for _,name in ipairs({'PlayerDeath','GroupOwnDeath','GnomeDeathEvidence','ValidGnomeDeathEvidence','GnomeHarmfulEvidence','IncomingHarmful','IncomingDeathEvidence','UpdateDeathCombat','ScanIncomingVictim','ScanIncomingAuras','Recap','InitDeathOutcomes','DeathDebugLines'})do
  assert(A[name]==nil,'retired death API remains callable: '..name)
 end
 assert(not A.AddGuildEvent('D',A.owner,'Player-me','Player-gnome',clock(),clock(),clock()),'direct D events must be rejected')
 assert(not A.ReceiveGroup(table.concat({'5','E','D',A.EncodeAlias(A.owner),'Player-me','Player-gnome',clock(),clock()},'|'),A.owner,clock()),'legacy received D events must be rejected')
 assert(A.db.owners[A.owner].deaths==nil and A.db.owners[A.owner].deathDays==nil,'runtime must not recreate death counters')
 assert(A.groupIncoming==nil and A.pendingDeaths==nil and A.deathFight==nil,'no retired collector state')
 print('PASS death retirement: native listeners/API/collector removed, D rejected, enemy victim identity retained, all contribution aura scans retired')
end
