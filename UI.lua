local _,A=...
local function text(parent,size,x,y,width)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
 f:SetPoint('TOPLEFT',x,y);f:SetFontObject(size=='small' and 'GameFontHighlightSmall' or 'GameFontHighlight');f:SetJustifyH('LEFT');if width then f:SetWidth(width) end
 return f
end
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,24);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn);return b
end
local function ratio(k,d)if d==0 then return '-' end;return string.format('%.2f',k/d)end
function A.RefreshUI()
 if not A.window or not A.db then return end
 local t=A.Safe(GetServerTime) or time(); local period=A.period or 'Lifetime'; local me=A.db.owners[A.owner]
 A.summary:SetText(string.format('You: %d kills   |   %d deaths to Gnomes   |   K/D %s   |   %d Gnomes encountered (unique)',A.Score(me,period,t),A.Score(me,period,t,'deaths'),ratio(A.Score(me,period,t),A.Score(me,period,t,'deaths')),A.EncounterCount(period,t)))
 A.periodButton:SetText(period..'  >')
 local c=A.coverage or {}
 A.coverageLabel:SetText('Tracking: '..(c.log and 'readable combat log observed' or 'CC-only fallback; exact 10% damage unavailable without readable combat log')..'\nDeaths: confirmed Gnome killing blows only. Encounters: visible Alliance players. Dates: UTC.')
 A.status:SetText(A.syncStatus or 'Waiting for guild')
 local data={}
 local encounters=A.mode=='Encounters'
 if encounters then A.headers[5]:Hide() else A.headers[5]:Show() end
 A.headers[4]:SetWidth(encounters and 270 or 130)
 for _,row in ipairs(A.rows) do
  row[4]:SetWidth(encounters and 262 or 122)
  if encounters then row[5]:Hide() else row[5]:Show() end
 end
 if A.mode=='Encounters' then
  A.heading:SetText('ALLIANCE ENCOUNTER LOG  |  Gnomes highlighted  |  unique characters seen in selected period')
  A.headers[1]:SetText('Player');A.headers[2]:SetText('Race');A.headers[3]:SetText('First seen');A.headers[4]:SetText('Last seen');A.headers[5]:SetText('')
  local first=A.FirstDay(period,t)
  for guid,r in pairs(A.db.seen or {}) do
   local include=period=='Lifetime'
   for day in pairs(r.days or {}) do if day>=first and day<=A.Day(t) then include=true;break end end
   if include then data[#data+1]={name=r.name or guid,race=r.race or '?',first=r.first,last=r.last} end
  end
  table.sort(data,function(a,b)
   if A.sort=='name' then return a.name<b.name end
   if a.race=='Gnome' and b.race~='Gnome' then return true elseif b.race=='Gnome' and a.race~='Gnome' then return false end
   if a.last~=b.last then return a.last>b.last end;return a.name<b.name
  end)
 else
  A.heading:SetText('GUILD LEADERBOARD  |  current members with this addon  |  client-reported, not server-verified')
  A.headers[1]:SetText('Player');A.headers[2]:SetText('Kills');A.headers[3]:SetText('Deaths');A.headers[4]:SetText('K/D');A.headers[5]:SetText('Encountered')
  local records={[A.owner]=me}
  for name,r in pairs(A.PeerRecords()) do if A.members[name] then records[name]=r end end
  for name,r in pairs(records) do
   local k=A.Score(r,period,t); local d=A.Score(r,period,t,'deaths')
   local encounters=name==A.owner and A.EncounterCount(period,t) or A.EncounterScore(r,period,t)
   data[#data+1]={name=name,k=k,d=d,kd=d>0 and k/d or (k>0 and math.huge or 0),encountered=encounters or -1}
  end
  table.sort(data,function(a,b)
   if A.sort=='name' then return a.name<b.name end
   local key=A.sort=='deaths' and 'd' or (A.sort=='ratio' and 'kd' or (A.sort=='encounters' and 'encountered' or 'k'))
   if a[key]~=b[key] then return a[key]>b[key] end;return a.name<b.name
  end)
 end
 if A.ascending then local reversed={};for i=#data,1,-1 do reversed[#reversed+1]=data[i] end;data=reversed end
 local pages=math.max(1,math.ceil(#data/12));A.page=math.max(1,math.min(A.page or 1,pages))
 A.pageLabel:SetText(string.format('Page %d / %d   (%d players)',A.page,pages,#data))
 for i,row in ipairs(A.rows) do
  local r=data[(A.page-1)*12+i]
  if r then
   local color=(A.mode=='Encounters' and r.race=='Gnome') and '|cffffb347' or (r.name==A.owner and '|cff66ddff' or '|cffffffff')
   row[1]:SetText(color..r.name..'|r')
   if A.mode=='Encounters' then row[2]:SetText(color..r.race..'|r');row[3]:SetText(date('!%Y-%m-%d',r.first));row[4]:SetText(date('!%m-%d %H:%M',r.last));row[5]:SetText('')
   else row[2]:SetText(tostring(r.k));row[3]:SetText(tostring(r.d));row[4]:SetText(ratio(r.k,r.d));row[5]:SetText(r.encountered>=0 and tostring(r.encountered) or '-') end
  else for _,cell in ipairs(row) do cell:SetText('') end end
 end
end
function A.ToggleUI()
 if not A.window then A.CreateUI() end
 if A.window:IsShown() then A.window:Hide() else A.window:Show();A.RefreshUI() end
end
function A.OpenView(mode,toggle)
 if not A.window then A.CreateUI() end
 if toggle and A.window:IsShown() and A.mode==mode then A.window:Hide();return end
 if A.mode~=mode then
  A.mode=mode;A.page=1;A.sort=mode=='Encounters' and 'last' or 'kills';A.ascending=false
 end
 A.window:Show();A.RefreshUI()
end
function A.CreateUI()
 if A.window or not A.db then return end
 local w=CreateFrame('Frame','BIHGGKTWindow',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil);A.window=w
 w:SetSize(830,590);w:SetPoint('CENTER');w:SetFrameStrata('DIALOG');w:SetClampedToScreen(true)
 w:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});w:SetBackdropColor(0.045,0.055,0.065,0.97);w:SetBackdropBorderColor(0.55,0.36,0.12,1)
 w:EnableMouse(true);w:SetMovable(true);w:RegisterForDrag('LeftButton')
 w:SetScript('OnDragStart',function(self)self:StartMoving()end)
 w:SetScript('OnDragStop',function(self)self:StopMovingOrSizing();local point,_,relative,x,y=self:GetPoint();A.db.options.position={point,relative,x,y}end)
 local pos=A.db.options.position;if pos then w:ClearAllPoints();w:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])end
 UISpecialFrames[#UISpecialFrames+1]='BIHGGKTWindow'
 text(w,'normal',18,-16):SetText('|cffffb347BIHG GnomeKillTracker 5000|r  |  by DoHeal')
 button(w,'X',785,-10,28,function()w:Hide()end)
 button(w,'Guild leaderboard',18,-48,170,function()A.mode='Leaderboard';A.page=1;A.RefreshUI()end)
 button(w,'Alliance encounters',194,-48,170,function()A.mode='Encounters';A.page=1;A.RefreshUI()end)
 A.periodButton=button(w,'Lifetime  >',380,-48,140,function()
  local index=1;for i,f in ipairs(A.frames)do if f==A.period then index=i end end
  A.period=A.frames[index%#A.frames+1];A.page=1;A.RefreshUI()
 end)
 button(w,'Sync guild',530,-48,110,function()A.request=true;A.QueueShare(true);A.syncStatus='Sync queued (outside instances only)';A.RefreshUI()end)
 local alerts=button(w,'Gnome alerts',650,-48,145,function(self)A.db.options.alerts=not (A.db.options.alerts~=false);self:SetText(A.db.options.alerts and 'Gnome alerts: ON' or 'Gnome alerts: OFF')end)
 alerts:SetText(A.db.options.alerts~=false and 'Gnome alerts: ON' or 'Gnome alerts: OFF')
 A.summary=text(w,'normal',18,-88,795)
 A.coverageLabel=text(w,'small',18,-115,795)
 A.heading=text(w,'small',18,-162,795)
 A.headers={}
 local xs={18,315,415,540,675};local widths={290,95,120,130,135};local sorts={'name','kills','deaths','ratio','encounters'}
 for i=1,5 do local idx=i;A.headers[i]=button(w,'',xs[i],-184,widths[i],function()if A.sort==sorts[idx] then A.ascending=not A.ascending else A.sort=sorts[idx];A.ascending=false end;A.page=1;A.RefreshUI()end)end
 A.rows={}
 for i=1,12 do
  A.rows[i]={};for j=1,5 do A.rows[i][j]=text(w,'small',xs[j]+4,-220-(i-1)*23,widths[j]-8)end
 end
 button(w,'< Previous',18,-512,105,function()A.page=(A.page or 1)-1;A.RefreshUI()end)
 button(w,'Next >',132,-512,85,function()A.page=(A.page or 1)+1;A.RefreshUI()end)
 A.pageLabel=text(w,'small',236,-519,350)
 A.status=text(w,'small',18,-552,795)
 w:EnableMouseWheel(true);w:SetScript('OnMouseWheel',function(_,delta)A.page=(A.page or 1)-(delta>0 and 1 or -1);A.RefreshUI()end)
 A.period=A.db.options.period or 'Lifetime';A.mode='Leaderboard';A.sort='kills';A.page=1
 w:SetScript('OnHide',function()A.db.options.period=A.period end);w:Hide()
 if Minimap then
  local m=CreateFrame('Button','BIHGGKTMinimap',Minimap);m:SetSize(30,30);m:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-8,-12);m:SetFrameStrata('MEDIUM')
  local icon=m:CreateTexture(nil,'ARTWORK');icon:SetAllPoints();icon:SetTexture('Interface\\Icons\\INV_Misc_Gear_01')
  m:RegisterForClicks('LeftButtonUp','RightButtonUp');m:SetScript('OnClick',function(_,which)A.OpenView(which=='RightButton' and 'Encounters' or 'Leaderboard',true)end)
  m:SetScript('OnEnter',function(self)if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetText('BIHG GnomeKillTracker 5000');GameTooltip:AddLine('Left: leaderboard | Right: Alliance encounters',1,1,1);GameTooltip:Show()end end)
  m:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
 end
end
SLASH_BIHGGKT1='/gkt';SLASH_BIHGGKT2='/gnomekills';SLASH_BIHGGKT3='/bihg'
SlashCmdList.BIHGGKT=function(msg)
 msg=(msg or ''):lower():match('^%s*(.-)%s*$')
 if msg=='debug' then
  local c=A.coverage or {};DEFAULT_CHAT_FRAME:AddMessage('BIHG 1.0.1 | log='..tostring(c.log or false)..' CC='..tostring(c.cc or false)..' recap='..tostring(c.recap or false)..' | '..(A.lastError or 'no Lua errors recorded'))
 elseif msg=='sync' then A.request=true;A.QueueShare(true)
 elseif msg=='alerts' then A.db.options.alerts=not (A.db.options.alerts~=false);DEFAULT_CHAT_FRAME:AddMessage('BIHG Gnome alerts: '..(A.db.options.alerts and 'ON' or 'OFF'))
 elseif msg=='encounters' then if not A.window then A.CreateUI() end;A.window:Show();A.mode='Encounters';A.RefreshUI()
 else A.ToggleUI() end
end
