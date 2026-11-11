-- Standalone suite reuses actual TOC/runtime/native-widget harness.
if arg[2]~='encounters' then
 local root=arg[1]or'.';arg[2]='encounters'
 return assert(loadfile((arg[0]:match('^(.*)/')or'tests')..'/integration.lua'))()
end
return function(A,event,tick,clock,units,transition)
 local t=clock();local g='Player-history';local kills=A.db.owners[A.owner].total
 units.target={guid=g,name='History',race='Human',faction='Alliance',hp=1000,enemy=true}
 function UnitLevel()return 72 end;function UnitClass()return 'Death Knight','DEATHKNIGHT'end
 A.db.options.nearbyEnabled=false
 A.Scan('target',{},true)
 A.OpenView('Encounters',false)
 local r=A.db.seen[g]
 assert(r and r.level==72 and r.class=='Death Knight','Runtime Scan persists readable level/class even with Nearby OFF and non-Gnome race')
 local row;for _,v in ipairs(A.rows)do if v.data and v.data.targetName=='History-Realm'then row=v end end
 assert(row and row[1].text:find('72',1,true)and row[2].text:find('History',1,true)and row[3].text:find('Death Knight',1,true),'board renders persisted level/name/class')
 assert(A.window:GetWidth()==960,'encounter metadata does not widen main window')
 assert(row.button.attrs.macrotext1:find('/targetexact History-Realm',1,true),'secure target remains raw full name')
 row.button.scripts.OnEnter(row.button)
 assert(GameTooltip.text=='History-Realm'and GameTooltip.lines[1][1]=='Level 72 | Death Knight | Human','encounter tooltip exposes metadata and full identity')
 local macro=row.button.attrs.macrotext1
 assert(type(row.button.scripts.OnLeave)=='function','encounter row registers mouse-leave tooltip cleanup')
 row.button.scripts.OnLeave(row.button)
 assert(not GameTooltip.shown,'leaving an encounter row hides its tooltip')
 local unrelated={};GameTooltip:SetOwner(unrelated,'ANCHOR_TOP');GameTooltip:Show()
 row.button.scripts.OnLeave(row.button)
 assert(GameTooltip.shown and GameTooltip:GetOwner()==unrelated,'encounter mouse-leave preserves another tooltip owner')
 assert(row.button.attrs.macrotext1==macro,'tooltip cleanup preserves raw secure bindings')
 assert(A.db.owners[A.owner].total==kills,'metadata cannot grant kill credit')
 local secret=setmetatable({},{__tostring=function()error('secret formatted')end,__lt=function()error('secret compared')end})
 issecretvalue=function(v)return rawequal(v,secret)end
 UnitLevel=function()return secret end;UnitClass=function()return secret end
 clock(t+1);A.Scan('target',{},true)
 assert(A.db.seen[g].level==72 and A.db.seen[g].class=='Death Knight','native secret results cannot erase persistent metadata')
 issecretvalue=function()return false end
 -- Kill location is irrelevant to Alliance knowledge; Horde/self are excluded.
 local location=IsInInstance;IsInInstance=function()return true,'pvp'end
 units.target.guid='Player-instance';UnitLevel=function()return -1 end;UnitClass=function()return nil end
 A.Scan('target',{},true);assert(A.db.seen['Player-instance'].level==-1,'instance-side sightings retain sentinel independently of kill policy')
 IsInInstance=location
 units.target.guid='Player-horde-history';units.target.faction='Horde';A.Scan('target',{},true);assert(not A.db.seen['Player-horde-history'],'Horde does not enter Alliance history')
 A.Encounter('Player-old-history','Old-Realm','Human','Alliance',t)
 A.OpenView('Encounters',false);local old
 for _,v in ipairs(A.rows)do if v.data and v.data.targetName=='Old-Realm'then old=v end end
 assert(old and old[1].text:find('?',1,true)and old[3].text:find('?',1,true),'old rows missing metadata show unknown rather than fabricated backfill')
 for _,v in ipairs(A.rows)do if v.data then for j=1,6 do assert(v[j].coords[1]=='TOPLEFT'and v[j].coords[2]+v[j]:GetWidth()<=924,'six columns fit original table width')end else assert(not v.button:IsShown()and not v.button.attrs.macrotext1,'unused rows clear stale secure targets')end end
 for _,mode in ipairs({'Leaderboard','Charts','Settings'})do
  A.OpenView('Encounters',false)
  local hit=A.rows[1].button;hit.scripts.OnEnter(hit)
  assert(GameTooltip.shown and GameTooltip:GetOwner()==hit,'encounter hover opens before view transition')
  A.OpenView(mode,false)
  assert(not GameTooltip.shown,'switching from Encounters to '..mode..' clears stale encounter tooltip')
  GameTooltip:SetOwner(unrelated,'ANCHOR_TOP');GameTooltip:Show();A.RefreshUI()
  assert(GameTooltip.shown and GameTooltip:GetOwner()==unrelated,'view refresh preserves unrelated tooltip')
 end
 A.OpenView('Encounters',false)
 local hit=A.rows[1].button;hit.scripts.OnEnter(hit);A.RefreshUI()
 assert(not GameTooltip.shown,'recycling encounter row data clears stale tooltip without mouse movement')
 hit.scripts.OnEnter(hit);A.window:Hide()
 assert(not GameTooltip.shown,'window hide clears its encounter tooltip')
 A.OpenView('Encounters',false);GameTooltip:SetOwner(unrelated,'ANCHOR_TOP');GameTooltip:Show();A.window:Hide()
 assert(GameTooltip.shown and GameTooltip:GetOwner()==unrelated,'window hide preserves unrelated tooltip')
 A.OpenView('Encounters',false)
 A.OpenView('Leaderboard',false)
 for j=4,6 do assert(not A.headers[j]:IsShown()and not A.rows[1][j]:IsShown()and A.rows[1][j].text=='','mode switch hides and clears every history-only column')end
 A.OpenView('Encounters',false);A.rows[1].button.scripts.OnEnter(A.rows[1].button)
 transition(true);event('PLAYER_REGEN_DISABLED')
 assert(not A.window:IsShown()and not GameTooltip.shown,'secure combat entry closes encounter window and its tooltip')
 transition(false);event('PLAYER_REGEN_ENABLED');A.OpenView('Encounters',false)
 assert(A.rows[1][6]:IsShown(),'encounter layout survives combat close/reopen')
 -- History is strictly newest-last-seen first, regardless of race or the
 -- leaderboard's saved sort choice. Nearby retains its separate Gnome priority.
 local savedSort=A.sort;clock(t+100)
 A.Encounter('Player-sort-gnome','AgedGnome-Realm','Gnome','Alliance',t+10)
 A.Encounter('Player-sort-human','RecentHuman-Realm','Human','Alliance',t+80)
 A.Encounter('Player-sort-elf','NewestElf-Realm','NightElf','Alliance',t+90)
 for _,ascending in ipairs({false,true})do for _,sort in ipairs({'name','kills','deaths'})do
  A.sort=sort;A.ascending=ascending;A.OpenView('Encounters',false)
  local positions={};local previous=math.huge
  for i,v in ipairs(A.rows)do if v.data then
   positions[v.data.targetName]=i
   assert(v.data.last<=previous,'Alliance history must remain chronological under '..sort..' sort');previous=v.data.last
  end end
  assert(positions['NewestElf-Realm']<positions['RecentHuman-Realm']and positions['RecentHuman-Realm']<positions['AgedGnome-Realm'],'newer non-Gnomes must precede older Gnomes')
 end end
 A.sort=savedSort;A.ascending=false
 local beforeHeaderSort=A.sort
 A.headers[2].scripts.OnClick()
 assert(A.sort==beforeHeaderSort and not A.ascending,'fixed chronological encounter headers must not alter leaderboard sorting')
 local savedNearby=A.nearbySeen
 A.nearbySeen={['Player-near-gnome']={guid='Player-near-gnome',name='Older',race='Gnome',seen=t+98},['Player-near-human']={guid='Player-near-human',name='Newer',race='Human',seen=t+99}}
 assert(A.NearbyList(t+100)[1].race=='Gnome','Nearby keeps its independent Gnome-first ordering')
 A.nearbySeen=savedNearby
 print('PASS encounters: runtime scan to persistent history to board and tooltip, Nearby OFF, non-Gnome, raw secure identity, chronological history')
end
