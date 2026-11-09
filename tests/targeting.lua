local root=arg[1]or'.';local combat=false
function InCombatLockdown()return combat end
function GetNormalizedRealmName()return'Realm'end
local A={Secret=function()return false end,Safe=function(fn,...)if fn then return fn(...)end end}
assert(loadfile(root..'/Nearby.lua'))('BIHGGnomeKillTracker5000',A)
assert(type(A.TargetMacro)=='function','secure name-targeting helpers are required')
local m=A.TargetMacro('Fetto-Vandike')
assert(m:find('/targetexact Fetto-Vandike',1,true)and m:find('/targetexact [noexists] Fetto Vandike',1,true),'Forever first/surname transport uses exact name alternatives')
assert(not m:find('/target [',1,true)and not m:find('/targetexact [noexists] Fetto\n',1,true),'never use fuzzy/first-name-only surname matching')
local n=A.TargetMacro('Guild Mate-Realm');assert(n:find('/targetexact [noexists] Guild Mate',1,true),'known realm suffix has a full-character-name fallback')
for _,bad in ipairs({'Bad\n/run injected','Bad|Hlink','Bad;Other','Bad[exists]','/run injected','  '})do assert(not A.TargetMacro(bad),'macro injection/invalid targeting names rejected')end
local attrs={};local b={SetAttribute=function(_,k,v)assert(not combat,'cannot mutate protected attributes during combat');attrs[k]=v end}
A.rosterTargetNames={['AliasFormat-Realm']='Actual Surname-Realm'}
assert(A.BindTargetButton(b,'AliasFormat-Realm'));assert(attrs.type1=='macro'and attrs.macrotext1:find('Actual Surname',1,true),'target full recorded character identity, not formatted alias')
local old=attrs.macrotext1;combat=true;assert(not A.BindTargetButton(b,'Other-Realm')and attrs.macrotext1==old,'secure combat binding stays fixed')
combat=false;A.BindTargetButton(b,nil);assert(not attrs.type1 and not attrs.macrotext1,'unused rows have no stale targeting action')
combat=1;assert(A.TargetingLocked(),'numeric truthy combat API results also lock protected changes');combat=false
local created=0;local nativeClick=function()end;local nativeEnter=function()end
local hover={scripts={OnClick=nativeClick,OnEnter=nativeEnter},SetAttribute=function()error('hover must not mutate targeting attributes')end}
function hover:CreateTexture()created=created+1;return{SetAllPoints=function()end,SetColorTexture=function()end,SetBlendMode=function()end}end
function hover:SetHighlightTexture(texture)self.highlight=texture end
combat=true;assert(not A.AddNameHover(hover)and created==0,'highlight setup is deferred in combat rather than mutating protected controls')
combat=false;assert(A.AddNameHover(hover)and created==1 and hover.highlight,'hover texture is prepared once during normal frame construction')
assert(hover.scripts.OnClick==nativeClick and hover.scripts.OnEnter==nativeEnter,'hover feedback preserves existing secure clicks and tooltip hooks')
print('PASS targeting: exact names, injection rejection, real character targeting, combat freeze, stale-action cleanup and native hover feedback')
