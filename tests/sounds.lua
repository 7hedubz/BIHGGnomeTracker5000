local root=arg[1]or'.';local A={db={options={}},Secret=function()return false end}
local sounds={};PlaySoundFile=function(id,channel)sounds[#sounds+1]={id=id,channel=channel};return true,1 end
assert(loadfile(root..'/Sounds.lua'))('BIHGGnomeKillTracker5000',A)
assert(loadfile(root..'/Nearby.lua'))('BIHGGnomeKillTracker5000',A);A.InitNearby()
assert(A.PumpNearbySounds,'configurable nearby audio not implemented')
local function seen(g,race,t)A.NearbyNotice('Player-'..g,g,race,'Alliance',t,false,true)end
seen('human','Human',0);A.PumpNearbySounds(0);assert(#sounds==1,'new Alliance sighting plays general alert')
seen('human','Human',1);seen('human','Human',2);A.PumpNearbySounds(2);assert(#sounds==1,'repeat scans stay silent')
A.db.options.extraGnomeSoundEnabled=true
seen('gnome','Gnome',4);A.PumpNearbySounds(4);assert(#sounds==2,'Gnome first gets general Alliance sound')
A.PumpNearbySounds(5);assert(#sounds==3 and sounds[3].id==A.BundledNearbySounds[2].value,'optional extra Gnome sound follows separately')
seen('gnome','Gnome',6);A.ClearNearby();seen('gnome','Gnome',7);A.PumpNearbySounds(9)
assert(#sounds==3,'clear preserves contact suppression; still-visible players do not re-beep')
seen('queued','Human',10);A.ClearNearby();A.PumpNearbySounds(10);assert(#sounds==3,'clear cancels queued audio')
seen('human','Human',40);A.PumpNearbySounds(40);assert(#sounds==4,'contact returning after 30 seconds unseen can alert again')
A.db.options.allianceSoundEnabled=false;seen('onlygnome','Gnome',44);A.PumpNearbySounds(44)
assert(#sounds==5 and sounds[5].id==A.BundledNearbySounds[2].value,'extra Gnome alert can be enabled independently')
A.db.options.extraGnomeSoundEnabled=false;seen('silent','Gnome',48);A.PumpNearbySounds(48);assert(#sounds==5,'both toggles off is silent')
A.db.options.allianceSoundEnabled=true;A.db.options.allianceTone=A.BundledNearbySounds[2].name;A.db.options.soundChannel='SFX'
seen('configured','Human',52);A.PumpNearbySounds(52)
assert(#sounds==6 and sounds[6].id==A.BundledNearbySounds[2].value and sounds[6].channel=='SFX','saved tone and output channel used')
assert(A.PlayNearbyTone('gnome')and #sounds==7,'manual Preview bypasses enable toggle without creating a sighting')
for i=1,100 do seen('burst'..i,'Human',56)end;A.PumpNearbySounds(56);assert(#sounds==8,'crowd sightings coalesce into one alert')
seen('later','Human',56.1);A.PumpNearbySounds(56.1);assert(#sounds==8,'global cooldown limits bursts')
A.PumpNearbySounds(58);assert(#sounds==9,'new detection waiting on cooldown is eventually sounded')
A.db.options.allianceTone=9999;A.db.options.soundChannel='Invalid';assert(A.PlayNearbyTone('alliance')and sounds[10].channel=='Master','invalid saved settings safely fall back')
PlaySoundFile=function()error('sound blocked')end
assert(not A.PlayNearbyTone('alliance'),'playback errors are isolated')
seen('stilltracks','Human',70);assert(A.nearbySeen['Player-stilltracks']and not A.lastError,'sound failure cannot break detection')
PlaySoundFile=nil;C_Sound={PlaySoundFile=function()return true end};assert(A.PlayNearbyTone('alliance'),'namespaced sound fallback supported')
local media={['Addon alarm']='Interface\\AddOns\\Other\\alarm.ogg',['Addon numeric']=123456,['None']=1,['Invalid']={}}
local lsm={Register=function(_,_,name,value)media[name]=value end,HashTable=function()return media end}
LibStub=function(name)assert(name=='LibSharedMedia-3.0');return lsm end
A.InitSoundAlerts();local choices=A.GetNearbySoundChoices('Addon');assert(#choices==2,'every valid third-party registered sound appears')
PlaySoundFile=function(id,ch)sounds[#sounds+1]={id=id,channel=ch};return true end
assert(A.SelectNearbySound('alliance','Addon alarm')and A.PlayNearbyTone('alliance')and sounds[#sounds].id==media['Addon alarm'],'SharedMedia path is played unchanged')
assert(A.SelectNearbySound('alliance','Addon numeric')and A.PlayNearbyTone('alliance')and sounds[#sounds].id==123456,'SharedMedia numeric file IDs supported')
media['Addon [late]']='Interface\\AddOns\\Other\\late.ogg';assert(#A.GetNearbySoundChoices('[late]')==1,'late registration and literal search supported')
assert(not A.SelectNearbySound('alliance','Invalid'),'invalid media values excluded')
assert(A.SelectNearbySound('alliance','None'));local before=#sounds;assert(not A.PlayNearbyTone('alliance')and #sounds==before,'standard None choice is silent')
A.SelectNearbySound('alliance','Addon alarm');media['Addon alarm']=nil
assert(A.PlayNearbyTone('alliance')and A.db.options.allianceTone=='Addon alarm','missing media safely falls back without erasing saved choice')
A.db.options.extraGnomeSoundEnabled=true;A.audioPending={alliance=true};A.audioExtraDue=90;A.db.options.nearbyEnabled=false
local beforePaused=#sounds;A.PumpNearbySounds(90)
assert(#sounds==beforePaused and not A.audioExtraDue and not next(A.audioPending),'Nearby OFF cancels delayed and queued sounds even if saved state changes directly')
A.NoteNearbySound('Player-paused-direct','Gnome',91);assert(not next(A.audioPending),'OFF suppresses direct discovery-sound scheduling')
assert(A.PlayNearbyTone('gnome')and #sounds==beforePaused+1,'explicit Preview stays usable while automatic detection is paused')
print('PASS sounds: general/extra toggles, independent sound/channel, delayed extra, GUID rearm, clear suppression, crowd coalescing/cooldown, preview, API failure/fallback, all SharedMedia paths/IDs, search and late registration')
