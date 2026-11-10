local _,A=...
A.BundledNearbySounds={}
for i=1,4 do A.BundledNearbySounds[i]={name='BIHG: Short alarm '..i,value='Interface\\AddOns\\BIHGGnomeKillTracker5000\\Media\\alert-'..i..'.ogg'}end
A.NearbySoundChannels={'Master','SFX','Dialog','Ambience','Music'}
local defaults={alliance=A.BundledNearbySounds[1].name,gnome=A.BundledNearbySounds[2].name}
local function library()
 if not LibStub then return end
 local ok,lib=pcall(function()return LibStub('LibSharedMedia-3.0',true)end)
 if ok and type(lib)=='table'then return lib end
end
local function sharedSounds()
 local lib=library();if not lib then return {}end
 if A.registeredSoundLibrary~=lib and type(lib.Register)=='function'then
  for _,s in ipairs(A.BundledNearbySounds)do pcall(lib.Register,lib,'sound',s.name,s.value)end
  A.registeredSoundLibrary=lib
 end
 if type(lib.HashTable)=='function'then local ok,sounds=pcall(lib.HashTable,lib,'sound');if ok and type(sounds)=='table'then return sounds end end
 return {}
end
local function validValue(v)return(type(v)=='string'and v~='')or(type(v)=='number'and v>0 and v%1==0)end
function A.GetNearbySoundChoices(query)
 local list,seen={},{};query=type(query)=='string'and query:lower()or''
 local function add(name,value,bundled)
  if type(name)=='string'and not seen[name]and validValue(value)then
   seen[name]=true;if name:lower():find(query,1,true)then list[#list+1]={name=name,value=value,bundled=bundled}end
  end
 end
 for _,s in ipairs(A.BundledNearbySounds)do add(s.name,s.value,true)end
 for name,value in pairs(sharedSounds())do add(name,value,false)end
 table.sort(list,function(a,b)if a.bundled~=b.bundled then return a.bundled end;return a.name:lower()<b.name:lower()end)
 return list
end
function A.NearbySoundChoice(kind,override)
 kind=kind=='gnome'and'gnome'or'alliance';local key=override or A.db.options[kind..'Tone']or defaults[kind]
 for _,s in ipairs(A.BundledNearbySounds)do if s.name==key then return s end end
 local value=sharedSounds()[key]
 if type(key)=='string'and validValue(value)then return {name=key,value=value}end
 return A.BundledNearbySounds[kind=='gnome'and 2 or 1],key
end
local function channel()
 local value=A.db.options.soundChannel
 for _,ch in ipairs(A.NearbySoundChannels)do if value==ch then return ch end end
 return'Master'
end
function A.InitSoundAlerts()
 local o=A.db.options
 if o.allianceSoundEnabled==nil then o.allianceSoundEnabled=true end
 if o.extraGnomeSoundEnabled==nil then o.extraGnomeSoundEnabled=false end
 for kind,name in pairs(defaults)do if type(o[kind..'Tone'])~='string'then o[kind..'Tone']=name end end
 o.soundChannel=channel();A.audioContacts={};A.audioPending={};A.audioExtraDue=nil;A.audioNextAt=-math.huge;sharedSounds()
end
function A.PlayNearbyTone(kind,override)
 local choice,missing=A.NearbySoundChoice(kind,override)
 if choice.name=='None'then A.soundStatus='Silent sound selected';return false end
 local play=type(PlaySoundFile)=='function'and PlaySoundFile or(C_Sound and C_Sound.PlaySoundFile)
 if type(play)~='function'then A.soundStatus='Sound playback API unavailable';return false end
 local ok,played=pcall(play,choice.value,channel())
 if ok and played==true then A.soundStatus=(missing and'Selected sound unavailable; fallback: 'or'Sound sent to client: ')..choice.name;return true end
 A.soundStatus='Sound was not accepted; check sound availability and game audio settings';return false
end
function A.NoteNearbySound(guid,race,now)
 if A.db.options.nearbyEnabled==false then return end
 local contacts=A.audioContacts;if not contacts then return end
 local c=contacts[guid];local fresh=not c or now-c.seen>A.NEARBY_TTL
 local isGnome=race=='Gnome';local learnedGnome=isGnome and c and not c.gnome
 contacts[guid]={seen=now,gnome=isGnome};local o=A.db.options
 if fresh and o.allianceSoundEnabled then A.audioPending.alliance=true end
 if(fresh or learnedGnome)and isGnome and o.extraGnomeSoundEnabled then A.audioPending.gnome=true end
end
function A.PumpNearbySounds(now)
 if A.db.options.nearbyEnabled==false then A.audioPending={};A.audioExtraDue=nil;return end
 if not A.audioContacts then return end
 for guid,c in pairs(A.audioContacts)do if now-c.seen>A.NEARBY_TTL then A.audioContacts[guid]=nil end end
 local o=A.db.options
 if A.audioExtraDue then
  if now<A.audioExtraDue then return end
  A.audioExtraDue=nil;if o.extraGnomeSoundEnabled then A.PlayNearbyTone('gnome')end;return
 end
 if now<(A.audioNextAt or 0)then return end
 local all=A.audioPending.alliance and o.allianceSoundEnabled;local gnome=A.audioPending.gnome and o.extraGnomeSoundEnabled;A.audioPending={}
 if not all and not gnome then return end
 A.audioNextAt=now+2
 if all then A.PlayNearbyTone('alliance');if gnome then A.audioExtraDue=now+1 end
 else A.PlayNearbyTone('gnome')end
end
function A.SelectNearbySound(kind,name)
 if kind~='alliance'and kind~='gnome'then return false end
 for _,s in ipairs(A.GetNearbySoundChoices())do if s.name==name then A.db.options[kind..'Tone']=name;return true end end
 return false
end
local function partyReady()
 if type(A.Safe)~='function'or A.Safe(IsInRaid)~=false then return false end
 local count=A.Safe(GetNumSubgroupMembers)
 return type(count)=='number'and count>0 and count<=4
end
local function partyText(v,max)
 if A.Secret and A.Secret(v)then return end
 if type(v)=='string'and v~=''and #v<=(max or 80)and not v:find('[%c|]')then return v end
end
local function partyLocation()
 local zone=partyText(A.Safe(GetRealZoneText));local sub=partyText(A.Safe(GetSubZoneText))
 local location=sub and zone and sub~=zone and(sub..', '..zone)or zone or sub
 if not location then return end
 if C_Map then
  local map=A.Safe(C_Map.GetBestMapForUnit,'player');local pos=map and A.Safe(C_Map.GetPlayerMapPosition,map,'player')
  if pos then local ok,x,y=pcall(function()return pos:GetXY()end)
   if ok and not A.Secret(x)and not A.Secret(y)and type(x)=='number'and type(y)=='number'and x>=0 and x<=1 and y>=0 and y<=1 then location=location..string.format(' (%d,%d)',math.floor(x*100+0.5),math.floor(y*100+0.5))end
  end
 end
 return location
end
function A.InitPartyAlerts()
 if A.db.options.partyAllianceAlerts==nil then A.db.options.partyAllianceAlerts=true end
 A.db.partyAlertContacts=type(A.db.partyAlertContacts)=='table'and A.db.partyAlertContacts or {}
 A.partyAlertPending={};A.partyAlertNext=0
end
function A.PartyAllianceMessage(e,location)
 local name=partyText(e.name,120);if not name then return end
 local realm=A.Safe(GetNormalizedRealmName)
 if type(realm)=='string'and realm~=''and name:sub(-#realm-1)=='-'..realm then name=name:sub(1,#name-#realm-1)end
 local prefix=(e.race=='Gnome'and'GNOME DETECTED : 'or'')..'[BIHG] Alliance detected: '
 local detail={};if type(e.level)=='number'and e.level>0 and e.level<=1000 then detail[#detail+1]='Level '..math.floor(e.level)end
 local race=partyText(e.race,40);if race then detail[#detail+1]=race=='NightElf'and'Night Elf'or race end
 local class=partyText(e.class,40);if class then detail[#detail+1]=class end
 local base=prefix..name;local description=#detail>0 and(' - '..table.concat(detail,' '))or''
 local text=base..description..(location and(' - near me: '..location)or'')
 if #text>255 then text=base..description end;if #text>255 then text=base end
 return text
end
function A.NotePartyAlliance(e,now)
 if A.db.options.nearbyEnabled==false then return end
 if not A.partyAlertPending or not A.db.options.partyAllianceAlerts or not partyReady()then return end
 local c=A.db.partyAlertContacts[e.guid];local fresh=not c or now-c.seen>60
 local upgrade=e.race=='Gnome'and c and not c.gnome
 if c then c.seen=now end
 if not fresh and not upgrade then return end
 if not A.partyAlertPending[e.guid]then
  local count,victim=0,nil
  for guid,p in pairs(A.partyAlertPending)do count=count+1;if p.entry.race~='Gnome'and(not victim or p.at<A.partyAlertPending[victim].at)then victim=guid end end
  if count>=20 then if e.race=='Gnome'and victim then A.partyAlertPending[victim]=nil else return end end
  A.partyAlertPending[e.guid]={entry=e,at=now,location=partyLocation()}
 end
end
function A.PumpPartyAlerts(now)
 if A.db.options.nearbyEnabled==false then A.partyAlertPending={};return end
 if not A.partyAlertPending then return end
 if not A.db.options.partyAllianceAlerts or not partyReady()then A.partyAlertPending={};return end
 for guid,c in pairs(A.db.partyAlertContacts)do if type(c)~='table'or type(c.seen)~='number'or now-c.seen>600 or c.seen>now+120 then A.db.partyAlertContacts[guid]=nil end end
 local pending={}
 for guid,p in pairs(A.partyAlertPending)do
  if not(A.nearbySeen and A.nearbySeen[guid])or now-p.at>30 then A.partyAlertPending[guid]=nil else pending[#pending+1]=p end
 end
 if now<A.partyAlertNext or #pending==0 then return end
 table.sort(pending,function(a,b)if(a.entry.race=='Gnome')~=(b.entry.race=='Gnome')then return a.entry.race=='Gnome'end;if a.at~=b.at then return a.at<b.at end;return a.entry.guid<b.entry.guid end)
 local p=pending[1];local e=p.entry;A.partyAlertPending[e.guid]=nil;A.partyAlertNext=now+2
 A.db.partyAlertContacts[e.guid]={seen=e.seen,gnome=e.race=='Gnome'}
 local message=A.PartyAllianceMessage(e,p.location);local send=SendChatMessage or(C_ChatInfo and C_ChatInfo.SendChatMessage)
 if not message or type(send)~='function'then A.partyAlertStatus='Party alert unavailable; no automatic retry';return end
 local ok,result=pcall(send,message,'PARTY')
 local accepted=ok and not A.Secret(result)and(result==nil or result==true or result==0)
 A.partyAlertStatus=accepted and'Latest sighting handed to party chat'or'Party alert failed; no automatic retry'
end
function A.RefreshSoundSettings()
 if not A.allianceAudioToggle then return end
 local o=A.db.options
 A.allianceAudioToggle:SetText('Alliance sound: '..(o.allianceSoundEnabled and'ON'or'OFF'))
 A.gnomeAudioToggle:SetText('Extra Gnome sound: '..(o.extraGnomeSoundEnabled and'ON'or'OFF'))
 A.allianceToneButton:SetText(o.allianceTone);A.gnomeToneButton:SetText(o.gnomeTone)
 A.audioChannelButton:SetText('Sound channel: '..channel())
 A.audioStatusLabel:SetText(A.soundStatus or'Use Preview to check the chosen sound. Game audio settings still apply.')
 if A.partyAlertToggle then A.partyAlertToggle:SetText('Party Alliance alerts: '..(o.partyAllianceAlerts and'ON'or'OFF'));A.partyAlertStatusLabel:SetText(A.partyAlertStatus or'New sightings only; 60s unseen to repeat. Gnomes are prioritized.')end
end
