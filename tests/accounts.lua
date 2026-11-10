local root=arg[1] or '.'
-- Parser/account tests explicitly run in the readable native world contract.
function IsInInstance()return false,'none'end
local A={};local function load(f)assert(loadfile(root..'/'..f))('BIHGGnomeKillTracker5000',A)end
load('Core.lua')
local f=io.open(root..'/Accounts.lua');assert(f,'Account-wide aliases are not implemented');f:close();load('Accounts.lua');load('Sync.lua')
local function eq(a,b,msg)assert(a==b,(msg or '')..' expected '..tostring(b)..' got '..tostring(a))end
local now=1700000000;local day=A.Day(now)
A.Init({owners={['First-Realm']={total=3,days={[day]=3}}}},'First-Realm',now)
local account={};A.InitAccount(account,'account-first',now)
eq(account.alias,'First','default alias is first toon')
eq(A.SetAlias('  DoHeal  ',now),true);eq(account.alias,'DoHeal')
eq(A.SetAlias('bad|alias',now),false);eq(A.SetAlias('',now),false)
A.guildKey='Guild-Realm';A.members={['First-Realm']=true,['Second-Realm']=true,['Peer-Realm']=true,['PeerAlt-Realm']=true}
local first=A.db;A.Init({},'Second-Realm',now+1);A.InitAccount(account,'ignored-id',now+1)
eq(account.id,'account-first','same account retains stable ID');eq(account.alias,'DoHeal','alt inherits nickname')
A.Award(now+1);A.PlayerDeath('death1','Gnome',now+1,'Player-gnome',{damage=600,maxHealth=1000,source='Player-gnome',time=now+1})
A.Encounter('Player-unique','Tiny','Gnome','Alliance',now+1);A.Encounter('Player-2','Other','Gnome','Alliance',now+1)
A.SnapshotAccount(now+1)
eq(A.AccountEncounterCount('Lifetime',now+1),2)
first.seen={['Player-unique']={race='Gnome',first=now,last=now,days={[day]=true}}}
account.characters['First-Realm'].seen=first.seen
eq(A.AccountEncounterCount('Lifetime',now+1),2,'same Gnome across alts deduplicates')
local groups=A.LeaderboardGroups('Lifetime',now+1)
eq(#groups,1);eq(groups[1].name,'DoHeal');eq(groups[1].k,4);eq(groups[1].d,1);eq(#groups[1].children,2)
A.Init(first,'First-Realm',now+2);A.InitAccount(account,'ignored',now+2)
eq(A.LeaderboardGroups('Lifetime',now+2)[1].k,4,'migration/relogin does not duplicate totals')
local packets=A.BuildPackets(true,now+2);local identity,unique
for _,p in ipairs(packets)do assert(#p<=255);if p:match('^3|I|')then identity=p elseif p:match('^3|U|')then unique=p end end
assert(identity and unique,'identity and account unique snapshots are sent')
-- A fresh observer learns each character from the guild-authenticated sender.
local B={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',B)end
B.Init({},'Observer-Realm',now);B.guildKey='Guild-Realm';B.members={['First-Realm']=true,['Second-Realm']=true,['Peer-Realm']=true,['PeerAlt-Realm']=true}
eq(B.Receive(identity,'GUILD','First-Realm',now+2),true)
eq(B.Receive('2|S|3|0|'..day..'|3|0','GUILD','First-Realm',now+2),true)
eq(B.Receive(identity,'GUILD','Second-Realm',now+2),true)
eq(B.Receive('2|S|1|1|'..day..'|1|1','GUILD','Second-Realm',now+2),true)
eq(B.Receive(unique,'GUILD','First-Realm',now+2),true)
local found
for _,g in ipairs(B.LeaderboardGroups('Lifetime',now+2))do if g.name=='DoHeal' then found=g end end
assert(found);eq(found.k,4);eq(found.d,1);eq(found.encountered,2);eq(#found.children,2)
eq(B.Receive(identity,'GUILD','Stranger-Realm',now+2),false)
-- Same nickname is cosmetic; a separate identity never joins DoHeal's stats.
local collision='3|I|other-account|'..A.EncodeAlias('DoHeal')..'|'..(now+3)
eq(B.Receive(collision,'GUILD','Peer-Realm',now+3),true)
eq(B.Receive('2|S|99|0|'..day..'|99|0','GUILD','Peer-Realm',now+3),true)
local count=0;for _,g in ipairs(B.LeaderboardGroups('Lifetime',now+3))do if g.name=='DoHeal' then count=count+1 end end;eq(count,2)
-- A renamed alias retains all characters, and old revisions cannot revert it.
A.SetAlias('New Name',now+4);local renamed
for _,p in ipairs(A.BuildPackets(false,now+4))do if p:match('^3|I|')then renamed=p end end
assert(renamed);B.Receive(renamed,'GUILD','First-Realm',now+4);B.Receive(identity,'GUILD','Second-Realm',now+5)
local new
for _,g in ipairs(B.LeaderboardGroups('Lifetime',now+5))do if g.name=='New Name' then new=g end end
assert(new);eq(new.k,4);eq(#new.children,2)
-- One online character must be able to sync its already-known offline alts to a new guildmate.
local C={};for _,name in ipairs({'Core.lua','Accounts.lua','Sync.lua'})do assert(loadfile(root..'/'..name))('BIHGGnomeKillTracker5000',C)end
C.Init({},'NewViewer-Realm',now);C.guildKey='Guild-Realm';C.members=B.members
for _,packet in ipairs(packets)do C.Receive(packet,'GUILD','First-Realm',now+2) end
local combined
for _,g in ipairs(C.LeaderboardGroups('Lifetime',now+2))do if g.name=='DoHeal' then combined=g end end
assert(combined);eq(combined.k,4,'new guildmate receives offline alt totals from account owner');eq(#combined.children,2)
local ownIdentity='3|I|peer-account|'..A.EncodeAlias('Peer')..'|'..now
C.Receive(ownIdentity,'GUILD','Peer-Realm',now+3)
eq(C.Receive('4|R|'..A.EncodeAlias('Peer-Realm')..'|2|S|999|0|'..day..'|999|0','GUILD','First-Realm',now+3),false,'alt relay cannot overwrite another direct account binding')
account.characters['Second-Realm'].days[day-500]=99
A.InitAccount(account,'ignored',now+6)
eq(account.characters['Second-Realm'].days[day-500],nil,'account alt daily history is bounded')
print('PASS account aliases: defaults, alt inheritance, migration, rename, grouping, unique encounters, guild identity sync, nickname collision isolation')
