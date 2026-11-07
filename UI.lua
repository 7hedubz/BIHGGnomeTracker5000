local _,A=...
local function text(parent,size,x,y,width)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlight')
 f:SetFontObject(size=='large' and 'GameFontNormalLarge' or (size=='small' and 'GameFontHighlightSmall' or 'GameFontHighlight'))
 f:SetPoint('TOPLEFT',x,y);f:SetJustifyH('LEFT');f:SetWordWrap(false);if width then f:SetWidth(width) end
 return f
end
local function panel(parent,x,y,w,h,template)
 if BackdropTemplateMixin then template=template and(template..',BackdropTemplate')or'BackdropTemplate'end
 local f=CreateFrame('Frame',nil,parent,template)
 f:SetPoint('TOPLEFT',x,y);f:SetSize(w,h)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
 f:SetBackdropColor(0.065,0.08,0.10,0.98);f:SetBackdropBorderColor(0.19,0.23,0.28,1);return f
end
local function style(b,selected)
 b.selected=selected;b:SetBackdropColor(selected and 0.24 or 0.10,selected and 0.17 or 0.13,selected and 0.065 or 0.16,1)
 b:SetBackdropBorderColor(selected and 0.95 or 0.27,selected and 0.66 or 0.33,selected and 0.22 or 0.39,1)
end
local function button(parent,label,x,y,w,fn,tip)
 local b=CreateFrame('Button',nil,parent,BackdropTemplateMixin and 'BackdropTemplate' or nil);b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y)
 b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
 local fs=b:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');fs:SetPoint('CENTER');b:SetFontString(fs);b.label=fs;b:SetText(label);style(b,false)
 b:SetScript('OnClick',fn)
 b:SetScript('OnEnter',function(self)
  if not self.selected then self:SetBackdropColor(0.17,0.21,0.26,1) end
  if tip and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(label);GameTooltip:AddLine(tip,0.85,0.89,0.94,true);GameTooltip:Show() end
 end)
 b:SetScript('OnLeave',function(self)style(self,self.selected);if GameTooltip then GameTooltip:Hide() end end)
 return b
end
local function ratio(k,d)if d==0 then return '-' end;return string.format('%.2f',k/d)end
local function clock()return A.Safe(GetServerTime) or time()end
function A.RefreshSoundPicker()
 if not A.soundPicker then return end
 A.soundPickerData=A.GetNearbySoundChoices(A.soundSearch:GetText())
 local data=A.soundPickerData;local pages=math.max(1,math.ceil(#data/10));A.soundPage=math.max(1,math.min(A.soundPage or 1,pages))
 A.soundPickerTitle:SetText(A.soundPickerKind=='gnome'and'EXTRA GNOME ALERT SOUND'or'ALLIANCE ALERT SOUND')
 A.soundPickerPage:SetText(#data..' sounds | Page '..A.soundPage..' / '..pages)
 A.soundPickerPrevious:SetEnabled(A.soundPage>1);A.soundPickerNext:SetEnabled(A.soundPage<pages)
 for i,row in ipairs(A.soundPickerRows)do
  row.choice=data[(A.soundPage-1)*10+i]
  if row.choice then row.select:SetText(row.choice.name);row.select:Show();row.preview:Show();style(row.select,A.db.options[A.soundPickerKind..'Tone']==row.choice.name)
  else row.select:Hide();row.preview:Hide()end
 end
end
function A.OpenSoundPicker(kind)
 if kind~='alliance'and kind~='gnome'then return end
 A.soundPickerKind=kind;A.soundPage=1
 if not A.soundPicker then
  local p=panel(A.window,0,0,620,490);A.soundPicker=p;_G.BIHGGKTSoundPicker=p;p:ClearAllPoints();p:SetPoint('CENTER');p:SetFrameStrata('FULLSCREEN_DIALOG');p:EnableMouse(true)
  A.soundPickerTitle=text(p,'large',20,-18,580)
  text(p,'small',20,-45,580):SetText('Bundled short alarms + all LibSharedMedia sounds registered by loaded addons.')
  text(p,'small',20,-75,55):SetText('Search')
  local search=CreateFrame('EditBox',nil,p,'InputBoxTemplate');A.soundSearch=search;search:SetSize(515,26);search:SetPoint('TOPLEFT',85,-68);search:SetAutoFocus(false);search:SetMaxLetters(128);search:SetText('')
  search:SetScript('OnTextChanged',function()A.soundPage=1;A.RefreshSoundPicker()end)
  search:SetScript('OnEscapePressed',function()search:ClearFocus();p:Hide()end)
  A.soundPickerRows={}
  for i=1,10 do
   local row={};local y=-109-(i-1)*28
   row.select=button(p,'',20,y,478,function()
    if row.choice and A.SelectNearbySound(A.soundPickerKind,row.choice.name)then search:ClearFocus();p:Hide();A.RefreshUI()else A.RefreshSoundPicker()end
   end)
   row.select.label:SetWidth(460);row.select.label:SetWordWrap(false)
   row.select:SetScript('OnEnter',function(self)
    if not self.selected then self:SetBackdropColor(0.17,0.21,0.26,1)end
    if row.choice and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(row.choice.name);GameTooltip:AddLine('Click to select. Preview does not change your selection.',0.85,0.89,0.94,true);GameTooltip:Show()end
   end)
   row.preview=button(p,'Preview',510,y,90,function()if row.choice then A.PlayNearbyTone(A.soundPickerKind,row.choice.name);A.RefreshUI()end end,'Preview through your selected sound channel without changing the saved sound.')
   A.soundPickerRows[i]=row
  end
  A.soundPickerPrevious=button(p,'< Previous',20,-410,105,function()A.soundPage=A.soundPage-1;A.RefreshSoundPicker()end)
  A.soundPickerNext=button(p,'Next >',135,-410,85,function()A.soundPage=A.soundPage+1;A.RefreshSoundPicker()end)
  A.soundPickerPage=text(p,'small',240,-417,360)
  text(p,'small',20,-452,430):SetText('Type to filter. Reopen/refresh the list to include late media registrations.')
  button(p,'Close',480,-445,120,function()search:ClearFocus();p:Hide()end)
  p:EnableMouseWheel(true);p:SetScript('OnMouseWheel',function(_,delta)A.soundPage=A.soundPage-(delta>0 and 1 or -1);A.RefreshSoundPicker()end)
  UISpecialFrames[#UISpecialFrames+1]='BIHGGKTSoundPicker';p:Hide()
 end
 A.soundSearch:SetText('');A.RefreshSoundPicker();A.soundPicker:Show()
end
function A.SelectPeriod(period)
 A.period=period;A.page=1;A.RefreshUI()
end
function A.RenderCharts(now)
 if A.TargetingLocked()then return end
 local top=A.TopKillers(A.period,now);local peak=top[1] and top[1].k or 1
 A.topChartSubtitle:SetText(A.period..' | cached guild aliases | kills')
 A.chartEmpty:SetText(#top==0 and 'No recorded kills for this period.' or '')
 for i,row in ipairs(A.chartRows) do
  local r=top[i]
  row.data=r;A.BindTargetButton(row.button,r and #r.children==1 and r.children[1].name or nil)
  if r then row.button:Show()else row.button:Hide()end
  if r then row.label:SetText(i..'. '..r.name);row.bar:SetMinMaxValues(0,math.max(1,peak));row.bar:SetValue(r.k);row.value:SetText(tostring(r.k));row.label:Show();row.bar:Show();row.value:Show()
  else row.label:Hide();row.bar:Hide();row.value:Hide() end
 end
 local graph=A.KillsLine(A.period,now,350,164);A.lineData=graph
 A.trendSubtitle:SetText('Your account | latest '..#graph.points..' days in '..A.period)
 A.trendPeak:SetText('Y: Kills per day | peak '..graph.peak)
 for i,value in ipairs(graph.ticks) do A.lineYTicks[i]:SetText(tostring(value)) end
 for i,dot in ipairs(A.lineDots) do
  local p=graph.points[i];dot.data=p
  if p then dot:ClearAllPoints();dot:SetPoint('CENTER',A.linePlot,'BOTTOMLEFT',p.x,p.y);dot:Show()else dot:Hide()end
 end
 for i,line in ipairs(A.lineSegments) do
  local p,q=graph.points[i],graph.points[i+1]
  if p and q then line:SetStartPoint('BOTTOMLEFT',A.linePlot,p.x,p.y);line:SetEndPoint('BOTTOMLEFT',A.linePlot,q.x,q.y);line:Show()else line:Hide()end
 end
 local seen={}
 for i,label in ipairs(A.lineXTicks) do
  local index=math.floor((#graph.points-1)*(i-1)/4)+1;local p=graph.points[index]
  if p and not seen[index] then label:ClearAllPoints();label:SetPoint('TOP',A.linePlot,'BOTTOMLEFT',p.x,-10);label:SetText(date('!%d %b',p.day*86400));label:Show();seen[index]=true else label:Hide()end
 end
end
function A.RefreshUI()
 if not A.window or not A.db then return end
 if A.TargetingLocked()then
  if not A.CanPostTopReport()then A.reportButton:Hide();if A.preview then A.preview:Hide()end end
  return
 end
 local now=clock();local period=A.period or 'Lifetime';local me=A.db.owners[A.owner];local kills,deaths=0,0
 if A.RefreshTopPostControls then A.RefreshTopPostControls()end
 for name,r in pairs(A.account and A.account.characters or {[A.owner]=me}) do if A.members and A.members[name]then local effective=A.GuildEffectiveRecord and A.GuildEffectiveRecord(name,r,now)or r;kills=kills+A.Score(effective,period,now);deaths=deaths+A.Score(effective,period,now,'deaths')end end
 local values={tostring(kills),tostring(deaths),ratio(kills,deaths),tostring(A.AccountEncounterCount(period,now))}
 for i,v in ipairs(values) do A.statCards[i].value:SetText(v) end
 A.summary:SetText('YOUR ACCOUNT: '..A.account.alias..' | '..period..' | known guild characters; encounter identities deduplicated')
 for label,b in pairs(A.navButtons) do style(b,A.mode==label) end
 for i,b in ipairs(A.periodButtons) do style(b,A.frames[i]==period) end
 local tabular=A.mode=='Leaderboard' or A.mode=='Encounters';local encounters=A.mode=='Encounters'
 if tabular then A.tablePane:Show();A.previousButton:Show();A.nextButton:Show() else A.tablePane:Hide();A.previousButton:Hide();A.nextButton:Hide() end
 if A.mode=='Charts' then A.chartsPane:Show() else A.chartsPane:Hide() end
 if A.mode=='Settings' then A.settingsPane:Show() else A.settingsPane:Hide() end
 local canPost=A.CanPostTopReport()
 if canPost and(A.mode=='Leaderboard' or A.mode=='Charts')then A.reportButton:Show()else A.reportButton:Hide()end
 if not canPost and A.preview then A.preview:Hide()end
 A.alertButton:SetText(A.db.options.alerts~=false and 'New-Gnome chat messages: ON' or 'New-Gnome chat messages: OFF')
 A.nearbyToggleButton:SetText(A.db.options.nearbyShown and'Nearby overlay: ON'or'Nearby overlay: OFF')
 if A.RefreshSoundSettings then A.RefreshSoundSettings()end
 local c=A.coverage or {}
 A.coverageLabel:SetText(c.log and 'Tracking: guild-only party/raid; readable combat log observed. Scores are client-reported.' or 'Tracking: guild-only party/raid debuff fallback. Exact damage and other players\' killers require readable combat-log data.')
 A.status:SetText((A.guildKey and 'AUTO SYNC ON | out of combat | every 1 min + score/profile changes | ' or 'NO GUILD | ')..(A.syncStatus or 'Waiting for peers'))
 A.postStatusLabel:SetText(A.postStatus or('Manual reports: Council of BIHG / The BIHG Cheese only. | '..(A.rosterStatus or'Guild roster pending.')))
 if A.mode=='Charts' then
  A.heading:SetText('CHARTS | Guild ranking and your recorded daily activity');A.pageLabel:SetText('Recorded data only');A.RenderCharts(now);return
 elseif A.mode=='Settings' then
  A.heading:SetText('SETTINGS | Account identity and local notifications');A.pageLabel:SetText('Account-wide alias');return
 end
 if encounters then A.headers[5]:Hide() else A.headers[5]:Show() end
 A.headers[4]:SetWidth(encounters and 270 or 130)
 for _,row in ipairs(A.rows) do row[4]:SetWidth(encounters and 262 or 122);if encounters then row[5]:Hide() else row[5]:Show() end end
 local data={}
 if encounters then
  A.heading:SetText('ALLIANCE ENCOUNTERS | Personal sighting log; Gnomes highlighted')
  A.headers[1]:SetText('Character');A.headers[2]:SetText('Race');A.headers[3]:SetText('First seen');A.headers[4]:SetText('Last seen')
  local first=A.FirstDay(period,now)
  for guid,r in pairs(A.db.seen or {}) do
   local include=period=='Lifetime'
   for day in pairs(r.days or {}) do if day>=first and day<=A.Day(now) then include=true;break end end
   if include then data[#data+1]={name=r.name or guid,targetName=r.name,race=r.race or '?',first=r.first,last=r.last} end
  end
  table.sort(data,function(a,b)
   if A.sort=='name' then return a.name<b.name end
   if a.race=='Gnome' and b.race~='Gnome' then return true elseif b.race=='Gnome' and a.race~='Gnome' then return false end
   if a.last~=b.last then return a.last>b.last end;return a.name<b.name
  end)
 else
  A.heading:SetText('GUILD LEADERBOARD | Click [+] to expand | [observed] = guildmate witnessed in your party/raid')
  local labels={'Alias / character','Kills','Deaths','K/D','Encountered'};for i,label in ipairs(labels) do A.headers[i]:SetText(label) end
  data=A.LeaderboardGroups(period,now)
  table.sort(data,function(a,b)
   if A.sort=='name' then if a.name~=b.name then return a.name<b.name end;return a.id<b.id end
   local key=A.sort=='deaths' and 'd' or (A.sort=='ratio' and 'kd' or (A.sort=='encounters' and 'encountered' or 'k'))
   if a[key]~=b[key] then return a[key]>b[key] end;if a.name~=b.name then return a.name<b.name end;return a.id<b.id
  end)
 end
 if A.ascending then local reversed={};for i=#data,1,-1 do reversed[#reversed+1]=data[i] end;data=reversed end
 local groupCount=#data
 if not encounters then local flat={};for _,g in ipairs(data) do flat[#flat+1]=g;if A.expanded[g.id] then for _,child in ipairs(g.children) do child.child=true;flat[#flat+1]=child end end end;data=flat end
 local pages=math.max(1,math.ceil(#data/12));A.page=math.max(1,math.min(A.page or 1,pages));A.pageLabel:SetText(string.format('Page %d / %d (%d %s)',A.page,pages,groupCount,encounters and 'players' or 'aliases'))
 for i,row in ipairs(A.rows) do
  local r=data[(A.page-1)*12+i]
  if r then
   local color=(encounters and r.race=='Gnome') and '|cffffb347' or ((r.isOwn or r.name==A.owner) and '|cff66ddff' or '|cffffffff')
   local label=r.isGroup and ((A.expanded[r.id] and '[-] ' or '[+] ')..r.name..' ('..#r.children..')') or ((r.child and '   ' or '')..A.DisplayName(r.name))
   if r.observed then label=label..' [observed]'end
   row.data=r;local targetName
   if encounters then targetName=r.targetName elseif r.isGroup then if #r.children==1 then targetName=r.children[1].name end else targetName=r.name end
   A.BindTargetButton(row.button,targetName);row[1]:SetText(color..label..'|r');row.button:Show()
   if encounters then row[2]:SetText(color..r.race..'|r');row[3]:SetText(date('!%Y-%m-%d',r.first));row[4]:SetText(date('!%m-%d %H:%M',r.last));row[5]:SetText('')
   else row[2]:SetText(tostring(r.k));row[3]:SetText(tostring(r.d));row[4]:SetText(ratio(r.k,r.d));row[5]:SetText(r.encountered>=0 and tostring(r.encountered) or '-') end
  else row.data=nil;A.BindTargetButton(row.button,nil);row.button:Hide();for _,cell in ipairs(row) do cell:SetText('') end end
 end
end
function A.ToggleUI()
 if A.TargetingLocked()then return false end
 if not A.window then A.CreateUI() end
 if A.window:IsShown() then A.window:Hide() else A.window:Show();A.RefreshUI() end
end
function A.OpenView(mode,toggle)
 if A.TargetingLocked()then return false end
 if not A.window then A.CreateUI() end
 if toggle and A.window:IsShown() and A.mode==mode then A.window:Hide();return end
 if A.mode~=mode then A.mode=mode;A.page=1;A.sort=mode=='Encounters' and 'last' or 'kills';A.ascending=false end
 A.window:Show();A.RefreshUI()
end
function A.RefreshTopPostControls()
 if not A.confirmPostButton then return end
 local job=A.postJob;local lines=job and job.lines or A.previewLines or{};local index=job and job.index or 1
 local name=index==1 and'heading'or(lines[index]or'next line'):gsub(': %d+ kills$','')
 A.confirmPostButton:SetText('Send '..name..' ('..index..'/'..#lines..')')
 A.previewExplanation:SetText('One line per click. Wait for the previous line to appear in /guild before the next click. '..(index-1)..'/'..#lines..' attempted; cached totals.')
end
function A.ShowTopPreview()
 if A.TargetingLocked()then A.postStatus='Leave combat before opening the report preview.';return false end
 if not A.CanPostTopReport()then A.postStatus='Guild reports are restricted to Council of BIHG and The BIHG Cheese.';if A.preview then A.preview:Hide()end;A.RefreshUI();return false end
 if not A.window then A.CreateUI() end
 A.previewLines=A.postJob and A.postJob.lines or A.BuildTopReport(A.period or 'Lifetime',clock())
 A.previewText:SetText(table.concat(A.previewLines,'\n\n'))
 A.RefreshTopPostControls()
 A.preview:Show()
end
function A.CreateUI()
 if A.window or not A.db or A.TargetingLocked()then return end
 local w=panel(UIParent,0,0,960,710,'SecureHandlerStateTemplate');A.window=w;_G.BIHGGKTWindow=w
 w:ClearAllPoints();w:SetPoint('CENTER');w:SetFrameStrata('DIALOG');w:SetClampedToScreen(true)
 w:SetScale(math.min(1,(UIParent:GetWidth()-30)/960,(UIParent:GetHeight()-30)/710));w:SetBackdropColor(0.025,0.035,0.048,0.99)
 w:EnableMouse(true);w:SetMovable(true);w:RegisterForDrag('LeftButton');w:SetScript('OnDragStart',function(self)if not A.TargetingLocked()then self:StartMoving()end end)
 w:SetScript('OnDragStop',function(self)if A.TargetingLocked()then return end;self:StopMovingOrSizing();local point,_,relative,x,y=self:GetPoint();A.db.options.position={point,relative,x,y}end)
 local pos=A.db.options.position;if pos then w:ClearAllPoints();w:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])end
 UISpecialFrames[#UISpecialFrames+1]='BIHGGKTWindow'
 text(w,'large',18,-14,850):SetText('|cffffb347BIHG GnomeKillTracker 5000|r  |  DoHeal')
 button(w,'X',918,-10,24,function()if not A.TargetingLocked()then w:Hide()end end)
 text(w,'small',20,-53,60):SetText('VIEW')
 A.navButtons={}
 local modes={{'Leaderboard','Guild leaderboard',85,170},{'Encounters','Alliance encounters',265,180},{'Charts','Charts',455,120},{'Settings','Settings',585,120}}
 for _,entry in ipairs(modes) do local mode=entry[1];A.navButtons[mode]=button(w,entry[2],entry[3],-44,entry[4],function()A.OpenView(mode,false)end,'Switch the content area; this does not sync or post to chat.') end
 local filter=panel(w,18,-84,924,52);text(filter,'small',12,-19,75):SetText('PERIOD UTC')
 A.periodButtons={};for i,label in ipairs(A.frames) do local period=label;A.periodButtons[i]=button(filter,label,92+(i-1)*116,-13,110,function()A.SelectPeriod(period)end,'Applies to statistics, ranking, chart and Top 10 report. Days are UTC calendar days.')end
 A.statCards={};local labels={'YOUR GNOME KILLS','DEATHS TO GNOMES','KILL / DEATH RATIO','UNIQUE GNOMES ENCOUNTERED'}
 for i,label in ipairs(labels) do local card=panel(w,18+(i-1)*234,-149,222,64);text(card,'small',12,-10,202):SetText(label);A.statCards[i]={value=text(card,'large',12,-32,200)} end
 A.summary=text(w,'small',20,-227,920);A.heading=text(w,'small',20,-255,920)
 A.tablePane=CreateFrame('Frame',nil,w);A.tablePane:SetPoint('TOPLEFT',18,-276);A.tablePane:SetSize(924,320)
 A.headers={};local xs={0,350,470,610,760};local widths={340,110,130,130,164};local sorts={'name','kills','deaths','ratio','encounters'}
 for i=1,5 do local idx=i;A.headers[i]=button(A.tablePane,'',xs[i],0,widths[i],function()if A.sort==sorts[idx] then A.ascending=not A.ascending else A.sort=sorts[idx];A.ascending=false end;A.page=1;A.RefreshUI()end,'Click to sort; click again to reverse.')end
 A.rows={};A.expanded={}
 for i=1,12 do
  A.rows[i]={};for j=1,5 do A.rows[i][j]=text(A.tablePane,'small',xs[j]+5,-40-(i-1)*23,widths[j]-10)end
  local row=A.rows[i];local hit=CreateFrame('Button',nil,A.tablePane,'SecureActionButtonTemplate');hit:SetPoint('TOPLEFT',0,-34-(i-1)*23);hit:SetSize(924,23);row.button=hit;hit:RegisterForClicks('LeftButtonDown','LeftButtonUp')
  hit:HookScript('OnClick',function(_,_,down)local r=row.data;if not down and not A.TargetingLocked()and r and r.isGroup then A.expanded[r.id]=not A.expanded[r.id];A.RefreshUI()end end)
 end
 A.chartsPane=CreateFrame('Frame',nil,w);A.chartsPane:SetPoint('TOPLEFT',18,-276);A.chartsPane:SetSize(924,320)
 local top=panel(A.chartsPane,0,0,452,320);A.topChart=top
 text(top,'normal',14,-12,420):SetText('TOP 10 GNOME KILLERS');A.topChartSubtitle=text(top,'small',14,-34,420);A.chartEmpty=text(top,'small',14,-70,420);A.chartRows={}
 for i=1,10 do
  local y=-59-(i-1)*23;local bar=CreateFrame('StatusBar',nil,top);bar:SetPoint('TOPLEFT',162,y);bar:SetSize(218,13);bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8');bar:SetStatusBarColor(0.94,0.62,0.20)
  local row={label=text(top,'small',14,y,142),bar=bar,value=text(top,'small',390,y,50)};A.chartRows[i]=row
  local hit=CreateFrame('Button',nil,top,'SecureActionButtonTemplate');row.button=hit;hit:SetPoint('TOPLEFT',14,y+4);hit:SetSize(142,21);hit:RegisterForClicks('LeftButtonDown','LeftButtonUp')
  hit:HookScript('OnClick',function(_,_,down)local r=row.data;if not down and not A.TargetingLocked()and r and #r.children>1 then A.expanded[r.id]=true;A.OpenView('Leaderboard',false)end end)
 end
 local trend=panel(A.chartsPane,472,0,452,320);A.trendChart=trend
 text(trend,'normal',14,-12,420):SetText('KILLS OVER TIME');A.trendSubtitle=text(trend,'small',14,-34,420);A.trendPeak=text(trend,'small',14,-56,420)
 local plot=CreateFrame('Frame',nil,trend);A.linePlot=plot;plot:SetPoint('TOPLEFT',70,-78);plot:SetSize(350,164)
 A.lineYTicks={};A.lineXTicks={};A.lineDots={};A.lineSegments={}
 for i=0,4 do
  local y=i/4*164;local grid=plot:CreateLine(nil,'BACKGROUND');grid:SetThickness(1);grid:SetColorTexture(0.18,0.23,0.28,1);grid:SetStartPoint('BOTTOMLEFT',plot,0,y);grid:SetEndPoint('BOTTOMLEFT',plot,350,y)
  local tick=text(trend,'small',0,0,52);tick:ClearAllPoints();tick:SetPoint('RIGHT',plot,'BOTTOMLEFT',-10,y);tick:SetJustifyH('RIGHT');A.lineYTicks[i+1]=tick
  local label=text(trend,'small',0,0,62);label:SetJustifyH('CENTER');A.lineXTicks[i+1]=label
 end
 local axis=plot:CreateLine(nil,'BACKGROUND');axis:SetThickness(1);axis:SetColorTexture(0.45,0.50,0.55,1);axis:SetStartPoint('BOTTOMLEFT',plot,0,0);axis:SetEndPoint('BOTTOMLEFT',plot,0,164)
 for i=1,29 do local line=plot:CreateLine(nil,'OVERLAY');line:SetThickness(2);line:SetColorTexture(0.94,0.62,0.20,1);A.lineSegments[i]=line end
 for i=1,30 do
  local dot=CreateFrame('Frame',nil,plot);dot:SetSize(12,12);dot:EnableMouse(true)
  local mark=dot:CreateTexture(nil,'OVERLAY');mark:SetSize(5,5);mark:SetPoint('CENTER');mark:SetColorTexture(1,0.74,0.30,1)
  dot:SetScript('OnEnter',function(self)if self.data and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(date('!%Y-%m-%d',self.data.day*86400)..' UTC');GameTooltip:AddLine(self.data.kills..' kills recorded',1,0.74,0.30);GameTooltip:Show()end end)
  dot:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);A.lineDots[i]=dot
 end
 A.lineXAxis=text(trend,'small',14,-291,420);A.lineXAxis:SetText('X: Time (UTC date) | hover a point for its kill count')
 A.settingsPane=panel(w,18,-276,924,320)
 text(A.settingsPane,'normal',20,-18,880):SetText('ACCOUNT PROFILE')
 text(A.settingsPane,'small',20,-45,880):SetText('One nickname for your known alts. Renaming preserves statistics; identical nicknames do not merge unrelated accounts.')
 text(A.settingsPane,'small',20,-83,90):SetText('Nickname')
 local input=CreateFrame('EditBox',nil,A.settingsPane,'InputBoxTemplate');A.aliasInput=input;input:SetSize(250,26);input:SetPoint('TOPLEFT',120,-76);input:SetAutoFocus(false);input:SetMaxLetters(32);input:SetText(A.account.alias)
 local function saveAlias()if A.SetAlias(input:GetText(),clock()) then input:SetText(A.account.alias);input:ClearFocus()else DEFAULT_CHAT_FRAME:AddMessage('BIHG: Use a nickname of 1-64 bytes without control characters or |.')end end
 A.aliasSave=button(A.settingsPane,'Save nickname',390,-76,150,saveAlias,'Updates your account alias and queues guild synchronization; does not post to chat.')
 input:SetScript('OnEnterPressed',saveAlias);input:SetScript('OnEscapePressed',function()input:SetText(A.account.alias);input:ClearFocus()end)
 text(A.settingsPane,'normal',20,-148,880):SetText('LOCAL NOTIFICATIONS & PARTY ALERTS')
 A.alertButton=button(A.settingsPane,'New-Gnome chat messages',20,-177,290,function()A.db.options.alerts=not (A.db.options.alerts~=false);A.RefreshUI()end,'Only toggles your local new-Gnome chat notification; tracking and guild sync remain active.')
 A.nearbyToggleButton=button(A.settingsPane,'Nearby overlay: ON',330,-177,250,function()A.ToggleNearby()end,'Show/hide the separate Spy-style Nearby Alliance window. Hiding it does not disable detection, statistics or guild synchronization.')
 text(A.settingsPane,'small',20,-115,880):SetText('Log each old alt once to import its history. Enemy nameplates improve detection. /gkt nearby restores the overlay.')
 A.allianceAudioToggle=button(A.settingsPane,'Alliance sound: ON',20,-213,220,function()A.db.options.allianceSoundEnabled=not A.db.options.allianceSoundEnabled;A.RefreshUI()end,'Alert for new Alliance sightings. Repeated scans are silent; crowd sightings are coalesced. Independent of the chat-alert toggle.')
 A.gnomeAudioToggle=button(A.settingsPane,'Extra Gnome sound: OFF',20,-247,220,function()A.db.options.extraGnomeSoundEnabled=not A.db.options.extraGnomeSoundEnabled;A.RefreshUI()end,'Optional additional sound after the Alliance sound for Gnomes. Can also be used alone with the general sound disabled.')
 A.allianceToneButton=button(A.settingsPane,'Choose Alliance sound',250,-213,250,function()A.OpenSoundPicker('alliance')end,'Choose a bundled short alarm or any sound registered with LibSharedMedia by loaded addons.')
 A.gnomeToneButton=button(A.settingsPane,'Choose Gnome sound',250,-247,250,function()A.OpenSoundPicker('gnome')end,'The extra Gnome sound has its own selection.')
 A.allianceToneButton.label:SetWidth(230);A.allianceToneButton.label:SetWordWrap(false);A.gnomeToneButton.label:SetWidth(230);A.gnomeToneButton.label:SetWordWrap(false)
 A.alliancePreviewButton=button(A.settingsPane,'Preview',510,-213,80,function()A.PlayNearbyTone('alliance');A.RefreshUI()end,'Test the selected Alliance sound even if its automatic alerts are disabled.')
 A.gnomePreviewButton=button(A.settingsPane,'Preview',510,-247,80,function()A.PlayNearbyTone('gnome');A.RefreshUI()end,'Test the selected extra Gnome sound even if its automatic alerts are disabled.')
 A.audioChannelButton=button(A.settingsPane,'Sound channel: Master',600,-177,300,function()
  local channels=A.NearbySoundChannels;local index=1;for i,ch in ipairs(channels)do if ch==A.db.options.soundChannel then index=i;break end end
  A.db.options.soundChannel=channels[index%#channels+1];A.RefreshUI()
 end,'Choose Master, SFX, Dialog, Ambience or Music. The game audio settings and volume for that channel still apply.')
 A.audioStatusLabel=text(A.settingsPane,'small',610,-215,290);A.audioStatusLabel:SetWordWrap(true);A.audioStatusLabel:SetHeight(62)
 A.partyAlertToggle=button(A.settingsPane,'Party Alliance alerts: ON',20,-281,300,function()A.db.options.partyAllianceAlerts=not A.db.options.partyAllianceAlerts;A.partyAlertPending={};A.RefreshUI()end,'Automatically announce fresh readable Alliance sightings to PARTY only, with GNOME DETECTED : first for Gnomes. No guild/raid fallback. Repeated contacts are suppressed across Clear/reload until 60s unseen. Each addon client has its own suppression.')
 A.partyAlertStatusLabel=text(A.settingsPane,'small',340,-289,560)
 A.previousButton=button(w,'< Previous',18,-617,105,function()A.page=(A.page or 1)-1;A.RefreshUI()end)
 A.nextButton=button(w,'Next >',133,-617,85,function()A.page=(A.page or 1)+1;A.RefreshUI()end)
 A.pageLabel=text(w,'small',232,-625,255)
 A.syncButton=button(w,'Refresh guild data',500,-617,176,function()A.request=true;A.QueueShare(true);A.syncStatus='Manual refresh queued; automatic sync remains on';A.RefreshUI()end,'Optional manual refresh. Automatic sync already runs at login, on score/profile changes and every minute out of combat. No guild chat messages.')
 A.reportButton=button(w,'Post Top 10 to Guild...',686,-617,256,A.ShowTopPreview,'Preview and confirm a guild-chat ranking for the selected period. Separate from silent automatic addon sync.')
 A.status=text(w,'small',20,-653,920);A.postStatusLabel=text(w,'small',20,-670,920);A.coverageLabel=text(w,'small',20,-688,920)
 local preview=panel(w,0,0,650,390);A.preview=preview;_G.BIHGGKTTopPreview=preview;preview:ClearAllPoints();preview:SetPoint('CENTER');preview:SetFrameStrata('FULLSCREEN_DIALOG');preview:EnableMouse(true)
 text(preview,'large',20,-18,610):SetText('PREVIEW GUILD REPORT')
 A.previewExplanation=text(preview,'small',20,-50,610);A.previewExplanation:SetWordWrap(true);A.previewExplanation:SetHeight(36)
 A.previewText=text(preview,'small',20,-103,610);A.previewText:SetWordWrap(true);A.previewText:SetHeight(210)
 A.confirmPostButton=button(preview,'Send heading',20,-344,410,function()
  local ok;if A.postJob then ok=A.SendNextTopPost(clock())else ok=A.StartTopPost(A.previewLines,clock())end
  if ok and not A.postJob then preview:Hide()end
  DEFAULT_CHAT_FRAME:AddMessage('BIHG report: '..(A.postStatus or'No status; run /gkt debug.'));A.RefreshUI()
 end,'Sends exactly one previewed line per click. Wait for that line in guild chat before clicking again. One-second minimum between lines; no automatic sends or retries.')
 A.confirmPostButton.label:SetWidth(390);A.confirmPostButton.label:SetWordWrap(false)
 button(preview,'Cancel',450,-344,180,function()preview:Hide()end);UISpecialFrames[#UISpecialFrames+1]='BIHGGKTTopPreview'
 preview:SetScript('OnHide',function()A.CancelTopPost()end);preview:Hide()
 w:EnableMouseWheel(true);w:SetScript('OnMouseWheel',function(_,delta)if A.mode=='Leaderboard' or A.mode=='Encounters' then A.page=(A.page or 1)-(delta>0 and 1 or -1);A.RefreshUI()end end)
 A.period='Lifetime';for _,p in ipairs(A.frames)do if p==A.db.options.period then A.period=p end end;A.mode='Leaderboard';A.sort='kills';A.page=1
 w:SetScript('OnHide',function()A.db.options.period=A.period;preview:Hide();if A.soundPicker then A.soundPicker:Hide()end end);w:Hide()
 -- Secure state transitions can hide a window containing protected target
 -- buttons during lockdown; an insecure PLAYER_REGEN_DISABLED Hide cannot.
 if type(RegisterStateDriver)=='function'then
  w:SetAttribute('_onstate-bihgmenu',[[if newstate == 'closed' then self:Hide() end]])
  RegisterStateDriver(w,'bihgmenu','[combat] closed; available')
 end
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
 if msg=='debug' then local c=A.coverage or {};DEFAULT_CHAT_FRAME:AddMessage('BIHG 1.7.6 | coverage log='..tostring(c.log or false)..' CC='..tostring(c.cc or false)..' recap='..tostring(c.recap or false)..' | runtime callback error: '..(A.lastError or'none recorded'));for _,line in ipairs(A.ReportDebugLines())do DEFAULT_CHAT_FRAME:AddMessage(line)end
 elseif msg=='sync' then A.request=true;A.QueueShare(true)
 elseif msg=='alerts' then A.db.options.alerts=not (A.db.options.alerts~=false);A.RefreshUI()
 elseif msg=='top' then A.OpenView('Leaderboard',false);A.ShowTopPreview()
 elseif msg=='encounters' then A.OpenView('Encounters',false)
 elseif msg=='charts' then A.OpenView('Charts',false)
 elseif msg=='settings' then A.OpenView('Settings',false)
 elseif msg=='nearby'then A.ToggleNearby()
 elseif msg=='nearby clear'then A.ClearNearby()
 else A.ToggleUI()end
end
