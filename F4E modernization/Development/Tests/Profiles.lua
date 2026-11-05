-- Run with the DCS Lua 5.1 interpreter: Profiles.lua <native fixture> <installed fixture>.
local native,installed=assert(arg[1]),assert(arg[2])
local names={'default.lua','CH Fighterstick USB.lua','Joystick - HOTAS Warthog.lua',
 'Saitek Pro Flight X-56 Rhino Stick.lua','Saitek Pro Flight X-56 Rhino Throttle.lua',
 'T.16000M.lua','Throttle - HOTAS Warthog.lua','VPC WarBRD + MT50.lua',
 'WINWING JOYSTICK BASE1 + F18 GRIP.lua','WINWING JOYSTICK BASE2 + F18 GRIP.lua'}
local function profile(file)
 local env={folder=file:match('^(.*[/\\])'),_=function(s)return s end,
  defaultDeviceAssignmentFor=function()return {} end}
 setmetatable(env,{__index=function(t,k)
  if type(k)=='string' and k:match('^iCommand') then return 90000 end
  return _G[k]
 end})
 env._G=env
 env.dofile=function(p)local f=assert(loadfile(p));setfenv(f,env);return f() end
 env.external_profile=function(p)
  if p:find('common_',1,true) then return {keyCommands={},axisCommands={},forceFeedback={}} end
  return profile(p)
 end
 return env.dofile(file)
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local prefix='/Mods/aircraft/F-4E/Input/F-4E-Pilot/'
local cases={'keyboard/default.lua'}
for _,name in ipairs(names) do cases[#cases+1]='joystick/'..name end
for _,rel in ipairs(cases) do
 local before,after=profile(native..prefix..rel),profile(installed..prefix..rel)
 local buttons,axes=0,0
 for _,group in ipairs({'keyCommands','axisCommands'}) do
  assert(#before[group]==#after[group],'Options added or removed: '..rel)
  for i,old in ipairs(before[group]) do
   local new=after[group][i]
   assert(old.name==new.name,'Option renamed or reordered: '..rel)
   assert(equal(old.combos,new.combos),'Default physical binding changed: '..rel)
   if old.cockpit_device_id==20 and old.down==3006 then
    buttons=buttons+1
    assert(new.cockpit_device_id==203 and new.down==3001 and new.up==3001,
     'NWS physical-button route missing: '..rel)
   elseif old.cockpit_device_id==20 and old.action==3014 then
    axes=axes+1
    assert(new.cockpit_device_id==203 and new.action==3007,'NWS SimPit route missing: '..rel)
   end
  end
 end
 assert(buttons==1 and axes>=1,'Unexpected NWS options: '..rel..' buttons='..buttons..' axes='..axes)
 print('PASS '..rel..': one consistent NWS button route; native axis and default combinations preserved')
end
