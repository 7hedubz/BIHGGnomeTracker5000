-- Actual runtime TOC, source-side fixture: also accepts a production-only root.
local root=arg[1]or'.'
local here=arg[0]:match('^(.*)/')or'tests'
local f=assert(io.open(here..'/integration.lua'));local lines={}
for line in f:lines()do lines[#lines+1]=line;if #lines==126 then break end end;f:close()
local scenario=arg[2]or'fresh'
local setup=[[
local realm='';function GetNormalizedRealmName()return realm end
function GetRealmName()error('must not recover hidden realm')end
function UnitName(u)return units[u].name,units[u].surname or 'Surname'end
function GetGuildRosterInfo(i)
 if i==1 then return 'Tester Surname',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,'Player-me' end
 return 'Friend Other',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,'Player-friend'
end
]]
local tests={fresh=[[
event('PLAYER_LOGIN')
assert(A.db and A.window,'blank realm cold login must initialize DB and window')
assert(not A.lastError,A.lastError)
assert(A.owner=='Tester Surname','new identity must use real full name without a fake realm')
assert(A.guildKey=='Guild'and not A.guildUnverified,'readable native guild must authorize blank-realm scope')
assert(A.account.characterNamesByGUID['Player-me']==A.owner)
]],existing=[[
local old='Tester Surname-OldRealm'
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=7,days={[A.Day(now)]=7}}},lastGuild={name='Guild',key='Guild-OldRealm'}}
BIHGGKTAccountDB={id='saved',alias='My alias',characters={[old]={characterGUID='Player-me',total=7,days={[A.Day(now)]=7}}},characterNamesByGUID={['Player-me']=old},characterGUIDs={[old]='Player-me'},guilds={['Guild-OldRealm']={}}}
event('PLAYER_LOGIN')
assert(A.owner==old,'GUID-backed canonical must survive hidden realm login')
assert(A.guildKey=='Guild-OldRealm'and not A.guildUnverified,'physical character provenance must preserve old guild scope')
assert(A.db.owners[old].total==7 and A.account.alias=='My alias')
assert(not A.lastError,A.lastError)
]],transition=[[
realm='OldRealm';event('PLAYER_LOGIN');local owner=A.owner;local guild=A.guildKey
realm='';event('GUILD_ROSTER_UPDATE')
assert(A.owner==owner and A.guildKey==guild and not A.guildUnverified,'active realm blanking must preserve verified scope')
assert(A.members[owner] and A.groupSources['Player-me'],'blank transition must retain local guild participant')
]],transport=[[
event('PLAYER_LOGIN')
assert(A.Receive('3|I|peer|50656572|1700000000','GUILD','Friend-Other',now)==false)
assert(A.Receive('6|C|Player-friend','GUILD','Friend-Other',now),'GUID bootstrap must reconcile realm-free full name and exact transport spelling')
assert(A.PeerRecords()['Friend Other'].accountID=='peer','buffered direct declaration must reach canonical roster member')
assert(not A.Receive('6|C|Player-me','GUILD','Invented-Other',now),'arbitrary names must not claim known GUID')
]],names=[[
event('PLAYER_LOGIN');A.Scan('target')
assert(A.db.seen['Player-gnome'].name=='Tiny-Surname','target must preserve actual transport full name, not append empty realm')
assert(A.Name('Friend Other')=='Friend Other','blank realm must not create a trailing separator')
]],quarantine=[[
BIHGGKTDB={owners={['Tester Surname-One']={total=9,days={}},['Tester Surname-Two']={total=5,days={}}}}
event('PLAYER_LOGIN')
assert(A.owner=='Tester Surname')
assert(A.db.owners[A.owner].total==0,'unproven multiple legacy identities must not merge into current GUID')
assert(A.db.owners['Tester Surname-One'].total==9 and A.db.owners['Tester Surname-Two'].total==5,'unproven history must remain preserved')
]],cached=[[
event('PLAYER_LOGIN');local key=A.guildKey
function GetGuildInfo()return nil end
event('GUILD_ROSTER_UPDATE')
assert(not A.guildKey or A.guildUnverified,'cached guild must never authorize membership')
assert(A.ViewGuildKey()==key,'last proven per-character guild can remain read-only display')
]],cached_guid_view=[[
event('PLAYER_LOGIN');local key=A.guildKey
A.db.lastGuild=nil
function GetGuildInfo()return nil end
function IsInGuild()return false end
event('GUILD_ROSTER_UPDATE')
assert(not A.guildKey and not next(A.groupSources),'unresolved current guild must stop all live participants')
assert(A.ViewGuildKey()==key,'per-GUID last verified scope must remain available for read-only display without realm inference')
assert(not A.Receive('2|V|99.0.0','GUILD','Friend Other',now))
]],guild_conflict=[[
function IsInGuild()return false end
event('PLAYER_LOGIN')
assert(not A.guildKey or A.guildUnverified,'contradictory live guild membership must fail closed')
assert(not A.groupSources['Player-me'])
]],raw_only=[[
local old='Tester-OldRealm'
BIHGGKTDB={owners={[old]={total=7,days={[A.Day(now)]=7}}},lastGuild={name='Guild',key='Guild-OldRealm'}}
event('PLAYER_LOGIN')
assert(A.db.owners[A.owner].total==7,'unique raw per-character SavedVariables owner supplies historical provenance even before GUID metadata existed')
assert(A.guildKey=='Guild-OldRealm')
assert(A.db.owners[A.owner].characterGUID=='Player-me')
]],legacy_raw=[[
local old='Tester-OldRealm'
BIHGGKTDB={owners={[old]={total=7,days={[A.Day(now)]=7}}},lastGuild={name='Guild',key='Guild-OldRealm'}}
BIHGGKTAccountDB={characters={[old]={characterGUID='Player-me',total=7,days={[A.Day(now)]=7}}},characterGUIDs={[old]='Player-me'},characterNamesByGUID={['Player-me']=old}}
event('PLAYER_LOGIN')
assert(A.owner==old and A.db.owners[old].total==7 and A.guildKey=='Guild-OldRealm','raw character snapshot plus exact account GUID must retain history and guild')
]],guild_proven=[[
local old='Tester Surname-OldRealm'
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=7,days={[A.Day(now)]=7}}}}
BIHGGKTAccountDB={characters={[old]={characterGUID='Player-me',total=7,days={[A.Day(now)]=7}}},characterNamesByGUID={['Player-me']=old},guildIdentities={['Guild-OldRealm']={guids={['Player-me']=old},names={[old]='Player-me'}}},guilds={['Guild-OldRealm']={}}}
event('PLAYER_LOGIN')
assert(A.guildKey=='Guild-OldRealm'and not A.guildUnverified,'unique GUID-backed historical guild namespace survives absent lastGuild')
]],guild_ambiguous=[[
local old='Tester Surname-OldRealm'
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=7,days={}}}}
BIHGGKTAccountDB={characters={[old]={characterGUID='Player-me',total=7,days={}}},characterNamesByGUID={['Player-me']=old},guildIdentities={['Guild-One']={guids={['Player-me']=old},names={}},['Guild-Two']={guids={['Player-me']=old},names={}}}}
event('PLAYER_LOGIN')
assert(not A.guildKey or A.guildUnverified,'ambiguous historical guild namespaces must not be chosen or blindly merged')
assert(A.db.owners[old].total==7)
]],serialized=[[
local old='Tester Surname-OldRealm';local alt='Offline Heal-OtherRealm';local d=A.Day(now)
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=7,days={[d]=7},guildBase={since=now,total=7,days={[d]=7}}}},lastGuild={name='Guild',key='Guild-OldRealm'}}
BIHGGKTAccountDB={id='saved',alias='Saved alias',aliasRev=123,characters={[old]={characterGUID='Player-me',total=7,days={[d]=7}},[alt]={characterGUID='Player-alt',total=11,days={[d]=11}}},characterNamesByGUID={['Player-me']=old,['Player-alt']=alt},characterGUIDs={[old]='Player-me',[alt]='Player-alt'},guilds={['Guild-OldRealm']={}},guildObservations={['Guild-OldRealm']={events={},killLives={sentinel={parent='root',victim='Player-enemy'}}}},identityArchives={['Player-me']={original={total=7,days={[d]=7}}}}}
event('PLAYER_LOGIN')
assert(A.owner==old and A.account.characters[alt].total==11)
assert(A.AddGuildEvent('K',old,'Player-me','Player-new',now+1,now,now+1),'blank realm must permit verified guild kill credit')
assert(A.db.owners[old].total==8)
local function dump(v)
 if type(v)~='table'then return type(v)=='string'and string.format('%q',v)or tostring(v)end
 local parts={'{'};for k,x in pairs(v)do parts[#parts+1]='['..dump(k)..']='..dump(x)..','end;parts[#parts+1]='}';return table.concat(parts)
end
local function reload(db)
 BIHGGKTDB=assert(loadstring('return '..dump(db)))()
 BIHGGKTAccountDB=assert(loadstring('return '..dump(BIHGGKTAccountDB)))()
 local B={};local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
 for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',B)end end;toc:close()
 B.eventFrame.scripts.OnEvent(B.eventFrame,'PLAYER_LOGIN');A=B;assert(not A.lastError,A.lastError)
end
local db=BIHGGKTDB
reload(db);assert(A.owner==old and A.db.owners[old].total==8,'serialized reload must not double-add retained witness')
units.player.guid='Player-alt';units.player.name='Offline';units.player.surname='Heal'
reload({owners={[alt]={characterGUID='Player-alt',total=11,days={[d]=11}}},lastGuild={name='Guild',key='Guild-OldRealm'}})
assert(A.owner==alt and A.db.owners[alt].total==11 and A.account.characters[old].total==8)
assert(A.account.alias=='Saved alias'and A.account.aliasRev==123)
assert(A.account.guildObservations['Guild-OldRealm'].killLives.sentinel.victim=='Player-enemy')
assert(A.account.identityArchives['Player-me'].original.total==7)
units.player.guid='Player-me';units.player.name='Tester';units.player.surname='Surname'
reload(db);assert(A.owner==old and A.db.owners[old].total==8 and A.account.characters[alt].total==11)
assert(not A.AddGuildEvent('K',old,'Player-me','Player-new',now+1,now,now+1),'retained event replay must remain idempotent')
]],target_legacy=[[
local old='Tester Surname-OldRealm'
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=0,days={}}},lastGuild={name='Guild',key='Guild-OldRealm'}}
event('PLAYER_LOGIN')
local button=CreateFrame('Button');assert(A.BindTargetButton(button,old))
assert(button.attrs.macrotext1:find('/targetexact Tester Surname',1,true),'legacy opaque key must target fresh roster spelling without hidden realm')
assert(not button.attrs.macrotext1:find('OldRealm',1,true),'legacy realm must not leak into target when fresh roster gives real name')
]],mixed_packets=[[
local old='Friend Other-OldRealm'
BIHGGKTAccountDB={guildIdentities={Guild={guids={['Player-friend']=old},names={[old]='Player-friend'}}}}
event('PLAYER_LOGIN')
assert(A.rosterSeen[old]and A.rosterGUIDs.Guild['Player-friend']=='Friend Other')
assert(not A.Receive('3|I|peer|50656572|1700000000','GUILD','Friend-Other',now))
assert(A.Receive('6|C|Player-friend','GUILD','Friend-Other',now),'historical canonical sender bootstrap')
assert(A.Receive('2|S|5|0|'..A.Day(now)..'|5|0','GUILD','Friend-Other',now))
assert(A.PeerRecords()[old].total==5 and not A.PeerRecords()['Friend-Other'])
assert(A.Receive('2|S|5|0|'..A.Day(now)..'|5|0','GUILD','Friend Other',now))
assert(A.PeerRecords()[old].total==5 and not A.PeerRecords()['Friend Other'])
assert(not A.Receive('6|C|Player-me','GUILD','Friend-Other',now),'established transport identity rejects conflicting GUID')
]],alias_map_conflict=[[
local old='Tester Surname-OldRealm'
-- Independent snapshots: only the authoritative account map identifies its row.
BIHGGKTDB={owners={[old]={characterGUID='Player-me',total=7,days={}}}}
BIHGGKTAccountDB={characters={[old]={total=99,days={}}},characterGUIDs={[old]='Player-other'}}
event('PLAYER_LOGIN')
assert(not A.lastError,A.lastError)
assert(A.owner=='Tester Surname'and A.db.owners[A.owner].total==0,'conflicting map-only alias must not credit foreign history')
assert(A.account.characterGUIDs[old]=='Player-other','conflicting alias map must not be rewritten')
assert(A.account.characters[old].total==99,'contradictory account row must remain preserved')
assert(A.account.ambiguousCharacterNames[old],'contradictory alias must remain quarantined')
assert(A.account.identityArchives['Player-me'][old].total==7,'original personal history must remain archived')
assert(A.db.owners[old].identityUncertain,'personal alias must retain collision quarantine')
]],alias_claim_directions=[[
local old='Tester Surname-OldRealm'
local function dump(v)
 if type(v)~='table'then return type(v)=='string'and string.format('%q',v)or tostring(v)end
 local out={'{'};for k,x in pairs(v)do out[#out+1]='['..dump(k)..']='..dump(x)..','end;out[#out+1]='}';return table.concat(out)
end
local claims={
 {'Player-me','Player-other',nil},
 {'Player-other','Player-me',nil},
 {'Player-other',nil,'Player-me'},
 {nil,'Player-me','Player-other'},
 {'Player-me','Player-me','Player-other'},
 {'Player-me','Player-other','Player-me'},
}
for i,claim in ipairs(claims)do
 -- Serialize each root independently, exactly as separate SavedVariables files.
 BIHGGKTDB=assert(loadstring('return '..dump({owners={[old]={characterGUID=claim[1],total=7,days={}}}})))()
 BIHGGKTAccountDB=assert(loadstring('return '..dump({characters={[old]={characterGUID=claim[2],total=99,days={}}},characterGUIDs={[old]=claim[3]},guilds={Guild={[old]={total=199,days={}}}}})))()
 local B={};local toc=assert(io.open(root..'/BIHGGnomeKillTracker5000.toc'))
 for line in toc:lines()do if line:match('%.lua$')then assert(loadfile(root..'/'..line))('BIHGGnomeKillTracker5000',B)end end;toc:close()
 B.eventFrame.scripts.OnEvent(B.eventFrame,'PLAYER_LOGIN')
 assert(not B.lastError,B.lastError)
 assert(B.owner=='Tester Surname'and B.db.owners[B.owner].total==0,'direction '..i..': contradictory alias must not credit either saved or peer history')
 assert(B.account.characters[old].total==99,'direction '..i..': account history must be preserved')
 assert(B.account.characterGUIDs[old]==claim[3],'direction '..i..': existing mapping must not be rewritten')
 assert(B.account.ambiguousCharacterNames[old],'direction '..i..': conflicting alias must be quarantined')
 assert(B.account.guilds.Guild[old].total==199,'direction '..i..': peer history must be preserved')
 assert(B.db.owners[old],'direction '..i..': personal alias must not be deleted')
end
]],collision=[[
local name='Tester Surname'
BIHGGKTDB={owners={[name]={characterGUID='Player-other',total=19,days={}}}}
BIHGGKTAccountDB={characters={[name]={characterGUID='Player-other',total=19,days={}}}}
event('PLAYER_LOGIN')
assert(not A.db or A.identityConflict,'occupied canonical key with conflicting GUID must not become current player history')
assert(BIHGGKTDB.owners[name].total==19 and BIHGGKTAccountDB.characters[name].total==19)
]]}
if not arg[2]then
 local scenarios={};for name in pairs(tests)do scenarios[#scenarios+1]=name end;table.sort(scenarios)
 local function quote(s)return "'"..s:gsub("'","'\\''").."'"end
 for _,name in ipairs(scenarios)do
  local ok,_,code=os.execute('luajit '..quote(arg[0])..' '..quote(root)..' '..quote(name))
  assert(ok==0 or(ok==true and code==0),'realm regression failed: '..name)
 end
 print('ALL '..#scenarios..' REALM HOTFIX SCENARIOS PASSED');return
end
assert(tests[scenario],'unknown scenario')
assert(loadstring(table.concat(lines,'\n')..'\n'..setup..'\n'..tests[scenario]))()
print('realm_hotfix '..scenario..' passed')
