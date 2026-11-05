local inputs=dofile(assert(arg[1])..'/HUD/CCIP/inputs.lua')
local station,shells,knob,selected,count,name=0,100,1,false,2,'Mk_82'
local panel=true
local api={
 LoIsOwnshipExportAllowed=function()return true end,
 LoGetSelfData=function()return {Name='F-4E-45MC',Position={x=0,y=1000,z=0}} end,
 LoGetVectorVelocity=function()return {x=200,y=0,z=0} end,
 LoGetVectorWindVelocity=function()return {x=0,y=0,z=0} end,
 LoGetPayloadInfo=function()return {CurrentStation=station,Cannon={shells=shells},Stations={{weapon={4,5,36,1},count=count}}} end,
 LoGetNameByType=function()return name end,
 GetDevice=function()if panel then return {get_argument_value=function(_,n)if n==273 then return knob elseif n==256 then return selected and 1 or 0 else return 0 end end} end end
}
local function expect(weapon,reason)
 local r,status=inputs.capture(api)
 if weapon then assert(r and r.name==weapon and status=='OK',tostring(status))
 else assert(not r and status==reason,tostring(status)) end
end
expect('M61A1') -- Bombs still carried, no station selected.
selected=true;expect('Mk_82') -- Native panel selection takes precedence over gun fallback.
selected=false;station=1;expect('Mk_82') -- Exported selection also takes precedence.
count=0;expect('M61A1')
count=2;station=0;shells=0;expect(nil,'EMPTY')
shells=100;knob=.13;expect(nil,'EXCLUDED_WEAPON')
knob=1;panel=false;expect(nil,'SELECTION_UNAVAILABLE')
panel=true;station=1;name='AGM_65D';expect(nil,'EXCLUDED_WEAPON')
name='UNKNOWN_BOMB';expect('UNKNOWN_BOMB') -- Unsupported selected stores must not silently use gun ballistics.
api.LoIsOwnshipExportAllowed=function()return false end;expect(nil,'EXPORT_BLOCKED')
print('PASS: CCIP no-selection gun fallback; native/exported selection precedence; empty cannon; excluded/unsupported weapons; unavailable data; export permission.')
