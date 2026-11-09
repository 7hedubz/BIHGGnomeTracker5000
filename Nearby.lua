local _,A=...
A.NEARBY_TTL=30;A.NEARBY_ROWS=8
function A.TargetingLocked()
 if type(InCombatLockdown)~='function'then return false end
 local ok,value=pcall(InCombatLockdown)
 return not ok or(A.Secret and A.Secret(value))or not not value
end
function A.TargetMacro(name)
 if(A.Secret and A.Secret(name))or type(name)~='string'or #name>140 or name:match('^%s*$')or name:find('[%c|/;%[%]]')then return nil end
 local names,seen={},{};local function add(n)if n and n~=''and not seen[n]then seen[n]=true;names[#names+1]=n end end
 add(name)
 local realm=A.Safe(GetNormalizedRealmName);local bare=name
 if type(realm)=='string'and realm~=''and name:sub(-#realm-1)=='-'..realm then bare=name:sub(1,#name-#realm-1);add(bare)end
 -- Forever reports a surname in UnitName's realm return. These are targeting
 -- alternatives only, never a rewrite of stored identity or an alias merge.
 local first,surname=bare:match('^([^%-]+)%-(.+)$');if first then add(first..' '..surname)end
 local out={'/cleartarget'};for i,n in ipairs(names)do out[#out+1]='/targetexact '..(i>1 and'[noexists] 'or'')..n end
 return table.concat(out,'\n')
end
function A.AddNameHover(button)
 if A.TargetingLocked()then return false end
 -- Let the native button manage hover/leave visibility, including in combat.
 -- Never replace its secure click script or change target attributes here.
 local highlight=button:CreateTexture(nil,'HIGHLIGHT');highlight:SetAllPoints(button)
 highlight:SetColorTexture(1,0.70,0.25,0.22);highlight:SetBlendMode('ADD')
 button:SetHighlightTexture(highlight)
 return true
end
function A.BindTargetButton(button,name)
 if A.TargetingLocked()then return false end
 name=(A.rosterTargetNames and A.rosterTargetNames[name])or name
 local macro=A.TargetMacro(name)
 button:SetAttribute('type1',macro and'macro'or nil);button:SetAttribute('macrotext1',macro)
 return macro~=nil
end
local function secret(v)return A.Secret and A.Secret(v)end
local function clock()return A.Safe(GetServerTime)or time()end
function A.InitNearby()
 A.nearbySeen={};A.nearbyPage=1
 if A.db.options.nearbyShown==nil then A.db.options.nearbyShown=true end
 if A.InitSoundAlerts then A.InitSoundAlerts()end
 if A.InitPartyAlerts then A.InitPartyAlerts()end
end
function A.NearbyNotice(guid,name,race,faction,now,dead,visible,level,class)
 if secret(guid)or type(guid)~='string'or not guid:match('^Player%-[%w%-]+$')or secret(now)or type(now)~='number'or now~=now or now==math.huge then return false end
 A.nearbySeen=A.nearbySeen or {}
 if not secret(dead)and dead==true then A.nearbySeen[guid]=nil;return false end
 if not secret(faction)and type(faction)=='string'and faction~='Alliance'then A.nearbySeen[guid]=nil;return false end
 if secret(faction)or faction~='Alliance'or secret(visible)or visible==false or secret(name)or secret(race)then return false end
 local old=A.nearbySeen[guid]
 if type(name)~='string'or name==''then if not old then return false end;name=old.name end
 local e=old or {guid=guid};e.name=name;e.race=type(race)=='string'and race or e.race;e.seen=now
 if not secret(level)and type(level)=='number'then e.level=level end
 if not secret(class)and type(class)=='string'then e.class=class end
 if A.NotePartyAlliance then A.NotePartyAlliance(e,now)end
 A.nearbySeen[guid]=e;if A.NoteNearbySound then A.NoteNearbySound(guid,e.race,now)end;return true
end
function A.NearbyList(now)
 local out={};local gnomes=0
 for guid,e in pairs(A.nearbySeen or {})do
  if now-e.seen>A.NEARBY_TTL then A.nearbySeen[guid]=nil
  else out[#out+1]=e;if e.race=='Gnome'then gnomes=gnomes+1 end end
 end
 table.sort(out,function(a,b)
  if(a.race=='Gnome')~=(b.race=='Gnome')then return a.race=='Gnome'end
  if a.seen~=b.seen then return a.seen>b.seen end
  if a.name~=b.name then return a.name<b.name end;return a.guid<b.guid
 end)
 return out,gnomes
end
function A.ClearNearby()
 A.nearbySeen={};A.nearbyPage=1
 A.audioPending={};A.audioExtraDue=nil
 A.partyAlertPending={}
 if A.nearbyFrame then A.RefreshNearby(clock())end
end
function A.ForgetNearby(guid)
 if not secret(guid)and type(guid)=='string'and A.nearbySeen then A.nearbySeen[guid]=nil end
end
local function label(parent,x,y,width)
 local fs=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');fs:SetPoint('TOPLEFT',x,y);fs:SetWidth(width);fs:SetJustifyH('LEFT');fs:SetWordWrap(false);return fs
end
local function tiny(parent,caption,x,fn,tip)
 local b=CreateFrame('Button',nil,parent);b:SetSize(18,18);b:SetPoint('TOPLEFT',x,-3)
 local fs=b:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');fs:SetPoint('CENTER');fs:SetTextColor(0.2,0.8,1);b:SetFontString(fs);b:SetText(caption);b.label=fs
 b:SetScript('OnClick',fn)
 b:SetScript('OnEnter',function(self)if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(type(tip)=='function'and tip()or tip);GameTooltip:Show()end end)
 b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);return b
end
function A.RefreshNearby(now)
 if not A.nearbyFrame then return end
 local entries,gnomes=A.NearbyList(now);A.nearbyCount=#entries
 if A.TargetingLocked()then A.nearbyHeaderText:SetText('Nearby | combat locked');return end
 local opts=A.db.options;local pages=math.max(1,math.ceil(#entries/A.NEARBY_ROWS));A.nearbyPage=math.max(1,math.min(A.nearbyPage or 1,pages))
 A.nearbyHeaderText:SetText('Nearby |cff00bfff'..#entries..'|r  G: |cffffb347'..gnomes..'|r')
 A.nearbyButtons.collapse:SetText(opts.nearbyCollapsed and '+'or'-')
 A.nearbyButtons.lock:SetText(opts.nearbyLocked and 'L'or'U')
 local paged=pages>1 and not opts.nearbyCollapsed
 for _,key in ipairs({'previous','next'})do if paged then A.nearbyButtons[key]:Show()else A.nearbyButtons[key]:Hide()end end
 A.nearbyButtons.previous:SetEnabled(A.nearbyPage>1);A.nearbyButtons.next:SetEnabled(A.nearbyPage<pages)
 local count=0
 for i,row in ipairs(A.nearbyRows)do
  local e=not opts.nearbyCollapsed and entries[(A.nearbyPage-1)*A.NEARBY_ROWS+i]or nil
  row.data=e
  A.BindTargetButton(row.frame,e and e.name)
  if e then
   local age=math.max(0,now-e.seen);local color=e.race=='Gnome'and '|cffffb347'or'|cffffffff'
   row.name:SetText(color..A.DisplayName(e.name)..'|r')
   local race=e.race=='NightElf'and'Night Elf'or(e.race or '?');row.detail:SetText(color..race..'|r  '..age..'s')
   row.frame:SetAlpha(age>5 and 0.65 or 1);row.frame:Show();count=count+1
  else row.name:SetText('');row.detail:SetText('');row.frame:Hide()end
 end
 A.nearbyFrame:SetHeight(count>0 and 28+count*22 or 24)
 if opts.nearbyShown then A.nearbyFrame:Show()else A.nearbyFrame:Hide()end
end
function A.ToggleNearby(force)
 if not A.nearbyFrame then A.CreateNearbyUI()end
 local opts=A.db.options
 if force==nil then opts.nearbyShown=not opts.nearbyShown else opts.nearbyShown=force==true end
 A.RefreshNearby(clock());if A.RefreshUI then A.RefreshUI()end
end
function A.CreateNearbyUI()
 if A.nearbyFrame or not A.db or A.TargetingLocked()then return end
 local w=CreateFrame('Frame','BIHGGKTNearby',UIParent,BackdropTemplateMixin and 'BackdropTemplate'or nil);A.nearbyFrame=w
 w:SetSize(340,24);w:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-30,-190);w:SetFrameStrata('MEDIUM');w:SetClampedToScreen(true);w:SetMovable(true)
 w:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});w:SetBackdropColor(0.02,0.025,0.03,0.93);w:SetBackdropBorderColor(0.65,0.70,0.75,1)
 local pos=A.db.options.nearbyPosition;if pos then w:ClearAllPoints();w:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])end
 local head=CreateFrame('Frame',nil,w);head:SetPoint('TOPLEFT');head:SetSize(340,24);head:EnableMouse(true);head:RegisterForDrag('LeftButton')
 head:SetScript('OnDragStart',function()if not A.TargetingLocked()and not A.db.options.nearbyLocked then w:StartMoving()end end)
 head:SetScript('OnDragStop',function()if A.TargetingLocked()then return end;w:StopMovingOrSizing();local point,_,relative,x,y=w:GetPoint();A.db.options.nearbyPosition={point,relative,x,y}end)
 head:SetScript('OnEnter',function(self)if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('BIHG Nearby Alliance');GameTooltip:AddLine('Gnomes first. Readable visible/recent sightings expire after 30 seconds; this is not an exact-range radar.',0.85,0.9,0.95,true);GameTooltip:Show()end end)
 head:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
 A.nearbyHeader=head;A.nearbyHeaderText=label(head,8,-6,136);A.nearbyButtons={}
 local b=A.nearbyButtons
 b.clear=tiny(head,'Clear',148,function()A.ClearNearby()end,'Clear nearby contacts and queued sounds, not saved history or statistics. Visible players return on the next scan without repeating their alert.');b.clear:SetWidth(38)
 b.history=tiny(head,'H',190,function()A.OpenView('Encounters',false)end,'Open the historical Alliance encounter log')
 b.lock=tiny(head,'U',212,function()A.db.options.nearbyLocked=not A.db.options.nearbyLocked;A.RefreshNearby(clock())end,function()return A.db.options.nearbyLocked and 'Unlock nearby window position'or'Lock nearby window position'end)
 b.collapse=tiny(head,'-',234,function()A.db.options.nearbyCollapsed=not A.db.options.nearbyCollapsed;A.RefreshNearby(clock())end,'Collapse / expand the nearby list (count stays visible)')
 b.previous=tiny(head,'<',256,function()A.nearbyPage=(A.nearbyPage or 1)-1;A.RefreshNearby(clock())end,'Previous nearby-player page')
 b.next=tiny(head,'>',278,function()A.nearbyPage=(A.nearbyPage or 1)+1;A.RefreshNearby(clock())end,'Next nearby-player page')
 b.close=tiny(head,'X',300,function()A.ToggleNearby(false)end,'Hide nearby window; restore with /gkt nearby or Settings');b.close.label:SetTextColor(1,0.35,0.3)
 A.nearbyRows={}
 for i=1,A.NEARBY_ROWS do
  local row={};local f=CreateFrame('Button',nil,w,'SecureActionButtonTemplate');row.frame=f;f:SetSize(332,21);f:SetPoint('TOPLEFT',4,-24-(i-1)*22);f:RegisterForClicks('LeftButtonDown','LeftButtonUp')
  A.AddNameHover(f)
  row.name=label(f,5,-5,206);row.detail=label(f,214,-5,112);row.detail:SetJustifyH('RIGHT')
  f:SetScript('OnEnter',function(self)
   local e=row.data;if e and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetText(A.DisplayName(e.name));GameTooltip:AddLine((e.race or 'Unknown race')..(e.level and e.level>0 and(' | Level '..e.level)or''),1,0.75,0.35);GameTooltip:AddLine('Left-click: try targeting this character. List bindings freeze in combat.',0.8,0.9,1,true);GameTooltip:AddLine('Last seen '..math.max(0,clock()-e.seen)..'s ago. Recently observed, not a measured distance.',0.8,0.85,0.9,true);GameTooltip:Show()end
  end)
  f:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);A.nearbyRows[i]=row
 end
 A.RefreshNearby(clock())
end
