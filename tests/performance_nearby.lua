local root=arg[1]or'.'
if not arg[2]then
 local function quote(s)return "'"..s:gsub("'","'\\''").."'"end
 for _,case in ipairs({'hidden','unchanged','identity','combat','shortcombat','resize','toggle','callbacks','errors'})do
  local ok=os.execute('luajit '..quote(arg[0])..' '..quote(root)..' '..case)
  assert(ok==true or ok==0,'Nearby performance case failed: '..case)
 end
 return
end
if arg[2]=='errors'then
 -- Reuse the actual-TOC harness's callback entry point without changing its
 -- other scenarios or adding a test-only hook to the addon.
 local testdir=arg[0]:match('^(.*)/')or'tests'
 local function regression(A,event,tick,clock,units,transition)
  units.target=nil;A.ClearNearby();local now=clock()
  A.NearbyNotice('Player-one','One-Realm','Gnome','Alliance',now,false,true,60,'Mage');A.RefreshNearby(now)
  local row=A.nearbyRows[1];local nativeClick=row.hitFrame.scripts.OnClick
  local original=A.nearbyHeaderText.SetText;local failure={reason='one-shot widget failure'}
  A.NearbyNotice('Player-two','New-Realm','Gnome','Alliance',now+1,false,true,50,'Mage')
  A.nearbyHeaderText.SetText=function()error(failure)end
  local ok,err=pcall(A.RefreshNearby,now+1)
  A.nearbyHeaderText.SetText=original
  assert(not ok and err==failure,'render failure must propagate its original error')
  assert(not A.nearbyClickLayer.shown,'failed render must fail closed before exposing stale actions')
  assert(row.data.name=='One-Realm','header failure must not replace row data before old actions are concealed')
  assert(A.nearbyRenderState==nil,'incomplete render state must be invalidated')
  A.RefreshNearby(now+1)
  assert(row.data.name=='New-Realm'and row.hitFrame.attrs.macrotext1:find('New-Realm',1,true),'next refresh must recover and bind the current identity')
  assert(A.nearbyClickLayer.shown,'recovered current actions must be restored')
  assert(row.hitFrame.scripts.OnClick==nativeClick,'recovery preserves native secure click handler')
  -- A failed clear can leave type1 changed while the cached target still
  -- names the old contact. Restoring that exact contact must rewrite BOTH.
  local saved=A.nearbySeen;local setAttribute=row.hitFrame.SetAttribute
  row.hitFrame.SetAttribute=function(self,key,value)
   if key=='macrotext1'then error(failure)end
   return setAttribute(self,key,value)
  end
  A.nearbySeen={};ok,err=pcall(A.RefreshNearby,now+1)
  row.hitFrame.SetAttribute=setAttribute
  assert(not ok and err==failure and row.hitFrame.attrs.type1==nil,'inject a genuinely partial native clear')
  assert(not A.nearbyClickLayer.shown,'partial native clear keeps hits concealed')
  A.nearbySeen=saved;A.RefreshNearby(now+1)
  assert(A.nearbyClickLayer.shown and row.hitFrame.attrs.type1=='macro'and row.hitFrame.attrs.macrotext1:find('New-Realm',1,true),'recovery must rewrite native attributes even when the old cached target matches')
  -- Age-only failures also invalidate and conceal; no full redraw was needed
  -- before the exception. Cleanup failures cannot replace its error object.
  local detail=row.detail.SetText;local hide=A.nearbyClickLayer.Hide
  row.detail.SetText=function()error(failure)end
  A.nearbyClickLayer.Hide=function()error('cleanup failure')end
  ok,err=pcall(A.RefreshNearby,now+2)
  row.detail.SetText=detail;A.nearbyClickLayer.Hide=hide
  assert(not ok and err==failure,'cleanup must preserve the original render exception')
  A.RefreshNearby(now+2);assert(A.nearbyClickLayer.shown,'cleanup failure must not strand the reentrancy guard')
  transition(true)
  local layerWrites=0
  A.nearbyClickLayer.Hide=function(...)layerWrites=layerWrites+1;return hide(...)end
  A.nearbyHeaderText.SetText=function()error(failure)end
  ok,err=pcall(A.RefreshNearby,now+2)
  A.nearbyHeaderText.SetText=original;A.nearbyClickLayer.Hide=hide
  assert(not ok and err==failure and layerWrites==0,'combat error cleanup must never attempt insecure protected visibility writes')
  A.RefreshNearby(now+2);assert(not A.nearbyClickLayer.shown,'combat retry remains display-only')
  transition(false);A.RefreshNearby(now+2)
  assert(A.nearbyClickLayer.shown and row.hitFrame.attrs.type1=='macro','regen restores current native actions after combat error')
  clock(now+A.NEARBY_TTL+2);tick()
  assert(not next(A.nearbySeen)and A.nearbyCount==0,'actual runtime ticks must still expire contacts after render failure')
  assert(not A.nearbyClickLayer.shown and row.hitFrame.attrs.macrotext1==nil,'expiry must conceal and clear stale secure actions')
  print('PASS performance_nearby errors (actual TOC/runtime)')
 end
 local env=setmetatable({arg={[0]=testdir..'/integration.lua',[1]=root,[2]='notifications'}},{__index=_G})
 env.loadfile=function(path)
  if path==testdir..'/notifications.lua'then return function()return regression end end
  local chunk,err=loadfile(path);if chunk then setfenv(chunk,env)end;return chunk,err
 end
 assert(env.loadfile(testdir..'/integration.lua'))();return
end
local now,combat,restricted=100,false,false
local counts={};local drivers={};local methods={}
local function count(k)counts[k]=(counts[k]or 0)+1 end
local function object(parent,protected)
 local o={parent=parent,protected=protected,scripts={},shown=true,attrs={}}
 return setmetatable(o,{__index=methods})
end
local function guard(self,k)assert(not(combat and self.protected and not restricted),'combat protected '..k);count(k)end
for _,k in ipairs({'SetSize','SetWidth','SetHeight','SetPoint','ClearAllPoints','SetScale','SetAlpha','SetText','SetTextColor','SetChecked','SetEnabled','SetJustifyH','SetWordWrap','SetFrameStrata','SetFrameLevel','SetClampedToScreen','SetMovable','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','RegisterForDrag','EnableMouse','RegisterForClicks','SetHighlightTexture','SetAllPoints','SetColorTexture','SetBlendMode','SetFontString','StartMoving','StopMovingOrSizing'})do
 methods[k]=function(self,...)guard(self,k);self[k..'Args']={...};if k=='SetText'then self.text=(...)elseif k=='SetHeight'then self.height=(...)elseif k=='SetSize'then self.width,self.height=... elseif k=='EnableMouse'then self.mouse=(...)end end
end
function methods:SetAttribute(k,v)guard(self,'SetAttribute');self.attrs[k]=v end
function methods:SetScript(k,v)guard(self,'SetScript');self.scripts[k]=v end
function methods:Show()guard(self,'Show');local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()guard(self,'Hide');local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.shown end
function methods:GetChecked()return self.SetCheckedArgs and self.SetCheckedArgs[1]end
function methods:GetFrameLevel()return 1 end
function methods:GetHeight()return self.height or 24 end
function methods:GetLeft()return 50 end
function methods:GetTop()return 600 end
function methods:GetEffectiveScale()return 1 end
function methods:GetPoint()return 'TOPRIGHT',UIParent,'TOPRIGHT',-30,-190 end
function methods:CreateFontString()return object(self)end
function methods:CreateTexture()return object(self)end
UIParent=object();BackdropTemplateMixin={}
function CreateFrame(kind,name,parent,template)
 local protected=template and template:find('Secure',1,true)~=nil
 assert(not(combat and protected),'combat construction')
 if protected then local p=parent;while p and p~=UIParent do p.protected=true;p=p.parent end end
 return object(parent,protected)
end
function RegisterStateDriver(frame,id)drivers[frame]=id end
function InCombatLockdown()return combat end
function GetServerTime()return now end
function GetNormalizedRealmName()return 'Realm'end
local A={db={options={}},Secret=function()return false end,Safe=function(fn,...)if type(fn)=='function'then local ok,v=pcall(fn,...);if ok then return v end end end,DisplayName=function(n)return n end}
assert(loadfile(root..'/Nearby.lua'))('test',A)
A.InitNearby();A.NearbyNotice('Player-one','One-Realm','Gnome','Alliance',now,false,true,60,'Mage');A.CreateNearbyUI()
local binds=0;local bind=A.BindTargetButton;A.BindTargetButton=function(...)binds=binds+1;return bind(...)end
local function reset()counts={};binds=0 end
local function transition(v)
 combat=v
 for f,id in pairs(drivers)do local fn=assert(loadstring(f.attrs['_onstate-'..id]));setfenv(fn,{self=f,newstate=v and'closed'or'available'});restricted=true;fn();restricted=false end
end
local which=arg[2]or'hidden'
if which=='hidden'then
 A.ToggleNearby(false);reset()
 for i=1,60 do now=100+i/2;A.RefreshNearby(now)end
 assert(binds==0,'hidden overlay must perform zero row bindings; got '..binds)
 assert(not next(counts),'stable hidden overlay must perform zero widget/geometry writes')
 now=131;A.RefreshNearby(now);assert(not next(A.nearbySeen),'hidden contacts still expire')
 A.NearbyNotice('Player-new','Fresh-Realm','Human','Alliance',now,false,true,42,'Warrior');A.ToggleNearby(true)
 assert(A.nearbyRows[1].data.name=='Fresh-Realm'and A.nearbyRows[1].hitFrame.attrs.macrotext1:find('Fresh-Realm',1,true),'restore binds fresh contacts before clicks show')
 assert(A.nearbyClickLayer.shown,'restore immediately exposes current actions')
elseif which=='unchanged'then
 reset();A.RefreshNearby(now)
 assert(binds==0 and not counts.SetAttribute,'unchanged visible overlay never rebinds secure rows')
 assert(not next(counts),'unchanged visible overlay does not render')
 now=101;A.RefreshNearby(now)
 assert(not counts.SetHeight and not counts.SetPoint and not counts.SetAttribute,'age-only tick avoids geometry and secure attributes')
 assert(A.nearbyRows[1].detail.text:find('1s',1,true),'age updates at second cadence')
 reset();now=101.5;A.RefreshNearby(now);assert(not next(counts),'fractional tick with unchanged displayed age does no work')
 reset()
 for i=1,60 do
  now=102+i/2;A.NearbyNotice('Player-one','One-Realm','Gnome','Alliance',now,false,true,60,'Mage');A.RefreshNearby(now)
 end
 assert(binds==0 and not counts.SetAttribute and not counts.SetHeight and not counts.SetPoint,'live unchanged sightings never rebind or lay out rows')
 local fresh={guid='Player-one',name='One-Realm',race='Gnome',seen=now,level=60,class='Mage'}
 A.nearbySeen['Player-one']=fresh;A.RefreshNearby(now)
 assert(A.nearbyRows[1].data==fresh,'unchanged row still uses current matching-GUID source data')
elseif which=='identity'then
 A.NearbyNotice('Player-one','Renamed-Realm','Gnome','Alliance',now,false,true,61,'Rogue');A.RefreshNearby(now)
 assert(A.nearbyRows[1].name.text:find('Renamed-Realm',1,true),'same GUID rename updates text')
 assert(A.nearbyRows[1].hitFrame.attrs.macrotext1:find('Renamed-Realm',1,true),'same GUID rename invalidates binding')
 A.rosterTargetNames={['Renamed-Realm']='Renamed Surname-Realm'};A.RefreshNearby(now)
 assert(A.nearbyRows[1].hitFrame.attrs.macrotext1:find('Renamed Surname-Realm',1,true),'roster target spelling invalidates binding')
elseif which=='combat'then
 transition(true);A.NearbyNotice('Player-two','New-Realm','Gnome','Alliance',now+1,false,true,50,'Mage');now=now+1;A.RefreshNearby(now)
 assert(A.nearbyRows[1].data.name=='New-Realm'and not A.nearbyClickLayer.shown,'combat contacts remain live and unclickable')
 transition(false);assert(not A.nearbyClickLayer.shown,'state driver must not auto-show stale bindings');A.RefreshNearby(now)
 assert(A.nearbyClickLayer.shown and A.nearbyRows[1].hitFrame.attrs.macrotext1:find('New-Realm',1,true),'regen restores current contacts')
elseif which=='shortcombat'then
 transition(true);transition(false);A.RefreshNearby(now)
 assert(A.nearbyClickLayer.shown,'combat driver hiding invalidates even without a locked timer tick')
elseif which=='resize'then
 A.nearbyFrame.height=70
 assert(A.nearbyFrame.scripts.OnSizeChanged,'resize must immediately refresh Nearby')
 A.nearbyFrame.scripts.OnSizeChanged(A.nearbyFrame)
 assert(A.nearbyClickLayer.SetSizeArgs[2]==A.nearbyFrame.height,'resize immediately realigns click geometry')
elseif which=='toggle'then
 A.SetNearbyEnabled(false);A.ToggleNearby(false);A.ToggleNearby(true)
 assert(A.db.options.nearbyEnabled==false and not next(A.nearbySeen),'visibility restoration must not auto-enable detection')
elseif which=='callbacks'then
 A.nearbyButtons.collapse.scripts.OnClick();assert(not A.nearbyClickLayer.shown,'collapse hides all actions')
 A.nearbyButtons.collapse.scripts.OnClick();assert(A.nearbyClickLayer.shown,'expand immediately restores bindings')
 A.nearbyHeader.scripts.OnDragStart();assert(not A.nearbyClickLayer.shown,'drag hides hits');A.RefreshNearby(now);assert(not A.nearbyClickLayer.shown,'ticks during drag cannot show hits')
 A.nearbyHeader.scripts.OnDragStop();assert(A.nearbyClickLayer.shown,'drag stop realigns and restores hits')
 assert(not A.nearbyRows[1].displayFrame.mouse,'passive display stays mouse disabled')
end
print('PASS performance_nearby '..which)
